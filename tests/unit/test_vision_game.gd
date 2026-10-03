extends TestCase
## US-011b Game görüş eki (S3 eki "Görüş ekleri"; AC1/AC2/AC7/AC8) tek süreçli host oturumunda: görüş kipi host
## kuralı (varsayılan data/vision_tuning.tres, seviye başlamadan; seviye yüklüyken ve geçersiz değerde etkisiz),
## seviye yüklenince yerel oyuncuya sis bağlanır ve kip verilir, `player_world_position`, maruziyet 0 → 1 (sahibin
## konisinde) → 2 (şüphe ≥ 30) host'ta 10 Hz yazılır ve `player_exposure_changed` yayılır, döküm "vision" anahtarı;
## oturum sonunda maruziyet boşalır. İstemcide yazmanın etkisizliği core `VisionRules.Session` testinde
## (test_vision_rules.gd) ve çok süreçli tests/net/look_sync.json'da.

const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
const STAFF_FRONT := Vector2(560, 400)

var _changes: Array = []
var _previous_scene: PackedScene = null


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _on_exposure(peer: int, level: int) -> void:
	_changes.append([peer, level])


func _frames(n: int = 3) -> void:
	for i: int in n:
		await tree().physics_frame


func test_mode_default_and_host_rule_offline() -> void:
	var tuning: VisionTuning = load(VisionTuning.PATH) as VisionTuning
	var was: int = Game.vision_mode()
	eq(was, tuning.default_mode, "varsayılan data/vision_tuning.tres (--vision-mode yokken)")
	Game.set_vision_mode(VisionGrid.Mode.DIRECTIONAL)
	eq(Game.vision_mode(), VisionGrid.Mode.DIRECTIONAL, "çevrimdışı = host: seviye yokken seçilir")
	Game.set_vision_mode(5)
	eq(Game.vision_mode(), VisionGrid.Mode.DIRECTIONAL, "geçersiz kip etkisiz")
	Game.set_vision_mode(was)
	eq(Game.vision_mode(), was)
	eq(Game.player_world_position(1), Vector2.INF, "oyuncu yok: INF")
	eq(Game.player_exposure(12345), 0)


func test_host_binds_fog_exposure_and_dump() -> void:
	var was: int = Game.vision_mode()
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	_changes.clear()
	Game.player_exposure_changed.connect(_on_exposure)
	if not eq(Net.host(free_udp_port()), OK):
		return
	Game.set_vision_mode(VisionGrid.Mode.DIRECTIONAL)
	Game.start_level(STORE)
	var level: Level = Game.current_level() as Level
	var me: Player = Game.local_player() as Player
	await _frames(2)
	if is_true(level != null and me != null, "seviye ve yerel oyuncu"):
		var fog: FogLayer = level.fog_layer()
		if is_true(fog != null, "yerel oyuncuya sis bağlandı (AC1)"):
			is_true(fog.observer() == me, "gözlemci yerel oyuncu")
			eq(fog.mode(), VisionGrid.Mode.DIRECTIONAL, "kip Game.vision_mode()'dan")
		Game.set_vision_mode(VisionGrid.Mode.PERIPHERAL)
		eq(Game.vision_mode(), VisionGrid.Mode.DIRECTIONAL, "seviye başladıktan sonra etkisiz")
		eq(Game.player_world_position(1), me.global_position)
		eq(Game.player_exposure(1), 0, "doğma noktası (sokak): gizli")
		me.position = STAFF_FRONT
		var level_seen: int = 0
		for i: int in 60:
			await tree().physics_frame
			level_seen = maxi(level_seen, Game.player_exposure(1))
			if level_seen >= 1:
				break
		eq(level_seen, 1, "sahibin konisinde: görünür (şüphe 30 olmadan önce)")
		var owner: StoreOwner = level.npcs_root().get_node("Owner") as StoreOwner
		owner.apply_suspicion(1, 40.0)
		await _frames(8)
		eq(Game.player_exposure(1), 2, "şüphe ≥ 30: görüldü")
		is_true(_changes.size() >= 2 and _changes[0] == [1, 1] and _changes.has([1, 2]),
			"player_exposure_changed 0→1→2, gelen %s" % str(_changes))
		var vision: Dictionary = Game.collect_dump()["vision"]
		eq(vision["mode"], "directional")
		eq(vision["fog"], true)
		is_true(int(vision["visible_tiles"]) > 0 and int(vision["memory_tiles"]) >= 0)
		is_true(vision["look_deg"] is float, "yerel bakış derece")
		eq(vision["exposure"], {"1": 2})
		has(vision["exposure_history"]["1"], 1)
		has(vision["visible_npcs"], "Owner", "sahip yakın halkada: tam görünür")
		eq(vision["remote_look_deg"], {}, "uzak oyuncu yok")
		is_true(Game.BASE_DUMP_KEYS.has("vision"), "taban anahtar")
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	await _frames(2)
	eq(Game.player_exposure(1), 0, "oturum sonunda maruziyet boşalır")
	Game.player_exposure_changed.disconnect(_on_exposure)
	Game.player_scene = _previous_scene
	Game.set_vision_mode(was)
	eq(Game.vision_mode(), was, "seviye kalkınca kip yeniden seçilebilir")


## t2 (nit): peer ayrılma yolu (Net.peer_disconnected) Game'de oturum görüş kaydını siler: maruziyet 0'a düşer
## (`player_exposure_changed` yayılır), döküm geçmişi ayrılanı taşımaz; kalan peer'ınki korunur.
func test_departed_peer_exposure_and_history_forgotten() -> void:
	_changes.clear()
	Game.player_exposure_changed.connect(_on_exposure)
	Game._rpc_exposure({7: 2, 8: 1})
	eq(Game.player_exposure(7), 2)
	Net.peer_disconnected.emit(7)
	await tree().process_frame
	eq(Game.player_exposure(7), 0, "ayrılanın maruziyeti silindi")
	is_true(_changes.has([7, 0]), "0'a düşüş yayıldı, gelen %s" % str(_changes))
	var history: Dictionary = Game.collect_dump()["vision"]["exposure_history"]
	is_false(history.has("7"), "döküm geçmişi ayrılanı taşımaz")
	is_true(history.has("8"), "kalanın geçmişi korunur")
	Net.peer_disconnected.emit(8)
	await tree().process_frame
	var after: Dictionary = Game.collect_dump()["vision"]["exposure_history"]
	is_false(after.has("8"), "ikinci ayrılan da silindi")
	Game.player_exposure_changed.disconnect(_on_exposure)


## t2 (çürütmeli inceleme should-fix): sis ilk hesaplamadan ÖNCE oturum kipini ve yerel oyuncunun gerçek bakışını
## alır. Yönlü kipte doğuşta oyuncunun arkası (bakış aşağı; yukarısı 128-256 px, görüş hattı açık sütun) hiç
## görünür/hafıza olmaz; arkasındaki NPC hiç tam/siluet/hayalet çizilmez.
func test_directional_spawn_never_reveals_behind() -> void:
	var was: int = Game.vision_mode()
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	if not eq(Net.host(free_udp_port()), OK):
		return
	Game.set_vision_mode(VisionGrid.Mode.DIRECTIONAL)
	Game.start_level(STORE)
	var level: Level = Game.current_level() as Level
	var me: Player = Game.local_player() as Player
	if is_true(level != null and me != null, "seviye ve yerel oyuncu"):
		# store_a sütun 3 (satır 4-13) açık koridor: oyuncu (3,13), bakış aşağı (kapı/sokak); arkası yukarı.
		me.global_position = Vector2(112, 432)
		var owner: StoreOwner = level.npcs_root().get_node("Owner") as StoreOwner
		owner.global_position = Vector2(112, 272)  # (3,8): 160 px arkada, yakın halkanın (64) dışında
		var visual: NpcVisual = owner.get_node("Visual") as NpcVisual
		var behind: Array[Vector2i] = [Vector2i(3, 9), Vector2i(3, 7), Vector2i(3, 5)]
		var revealed: Array = []
		var npc_modes: Array = []
		for i: int in 30:
			await tree().physics_frame
			var fog: FogLayer = level.fog_layer()
			if fog == null:
				continue
			for cell: Vector2i in behind:
				if fog.state_at(cell) != VisionGrid.State.UNKNOWN and not revealed.has(cell):
					revealed.append(cell)
			if visual.sight_mode() != SightGate.Mode.HIDDEN and not npc_modes.has(visual.sight_mode()):
				npc_modes.append(visual.sight_mode())
		var fog_now: FogLayer = level.fog_layer()
		if is_true(fog_now != null, "sis bağlı"):
			eq(fog_now.mode(), VisionGrid.Mode.DIRECTIONAL)
			near(fog_now.look_dir, me.look_dir, 0.001, "sis bakışı yerel oyuncununki")
			is_true(fog_now.state_at(Vector2i(3, 15)) == VisionGrid.State.VISIBLE, "önü (aşağı) görünür")
		eq(revealed, [], "arkadaki karolar hiç görünür/hafıza olmadı")
		eq(npc_modes, [], "arkadaki NPC hiç görünür/hayalet olmadı")
		# Kip sonradan değişirse (istemciye çoğaltılan kip yolu) aynı sıra: kip + bakış önce, hafıza silinip hemen
		# yeniden hesap. Çevresel → arkası görünür; yönlüye dönünce arkası hafıza değil bilinmeyen.
		if fog_now != null:
			Game._rpc_vision_mode(VisionGrid.Mode.PERIPHERAL)
			eq(fog_now.mode(), VisionGrid.Mode.PERIPHERAL, "çoğaltılan kip sise hemen geçer")
			eq(fog_now.state_at(Vector2i(3, 7)), VisionGrid.State.VISIBLE, "çevresel: arkası görünür (hemen)")
			Game._rpc_vision_mode(VisionGrid.Mode.DIRECTIONAL)
			eq(fog_now.state_at(Vector2i(3, 7)), VisionGrid.State.UNKNOWN, "yönlüye dönüş: eski kipin hafızası silinir")
			eq(fog_now.state_at(Vector2i(3, 15)), VisionGrid.State.VISIBLE, "önü yeniden hesaplandı")
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	await _frames(2)
	Game.player_scene = _previous_scene
	Game.set_vision_mode(was)
