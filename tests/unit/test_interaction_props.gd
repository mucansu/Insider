extends TestCase
## US-005 bileşen ve prop'lar (tek süreç; çevrimdışı tekil kimlik 1 = host, ya da Net.host oturumu):
## Interactable host doğrulaması (AC1, AC4: taraf, menzil + 24 px, meşguliyet, tekrar beklemesi, aktör yok),
## kasa (AC2: 3 sn → +150, boş, yarıda bırakma sıfırlar, son 0,25 sn payı), kapı (AC3: anında, engel), store_a
## yerleşimi (AC5), PropDef verisi (S10), oyuncu tarafı (PlayerInteraction + Player sinyalleri, S7).
## Kurallar: test_interaction.gd; ağ: tests/net/{register_empty,door_sync,contention}.json.

const REGISTER_SCENE := "res://entities/props/register.tscn"
const DOOR_SCENE := "res://entities/props/door.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const STORE := "res://levels/store_a.tscn"
const REGISTER_DEF := "res://data/props/register.tres"
const DOOR_DEF := "res://data/props/door.tres"
const REG_POS := Vector2(560, 368)
const STAFF := Vector2(588, 368)
const CUSTOMER := Vector2(532, 368)
const DT := 1.0 / 60.0


## Etkileşim aktörü taklidi (oyuncunun S7 arayüzü: grup + interaction_position).
class FakeActor:
	extends Node2D

	func interaction_position() -> Vector2:
		return global_position


## Uzak istemcideki bileşen gibi: istekleri yalnız kaydeder, kararı test yayar (host gecikmesi).
class RemoteInteractable:
	extends Interactable
	var sent: Array = []

	func request_start(seq: int) -> void:
		sent.append(["start", seq])

	func request_cancel(seq: int) -> void:
		sent.append(["cancel", seq])


var _results: Array = []
var _completed: Array[int] = []
var _cancelled: Array[int] = []


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _actor(peer_id: int, at: Vector2) -> FakeActor:
	var actor := FakeActor.new()
	actor.set_multiplayer_authority(peer_id)
	actor.position = at
	actor.add_to_group(Interactable.ACTOR_GROUP)
	tree().root.add_child(actor)
	autofree(actor)
	return actor


func _prop(path: String, at: Vector2) -> Node2D:
	var prop: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	prop.position = at
	tree().root.add_child(prop)
	autofree(prop)
	return prop


func _watch(item: Interactable) -> void:
	item.request_finished.connect(func(seq: int, ok: bool) -> void: _results.append([seq, ok]))
	item.completed.connect(func(peer: int) -> void: _completed.append(peer))
	item.cancelled.connect(func(peer: int) -> void: _cancelled.append(peer))


## Host'un süre sayımını `seconds` kadar ilerletir (fizik adımlarını beklemeden).
func _run(item: Interactable, seconds: float) -> void:
	var steps: int = roundi(seconds / DT)
	for i: int in steps:
		item._physics_process(DT)


func _interactable(prop: Node) -> Interactable:
	return prop.get_node("Interactable") as Interactable


# --- veri (S10) ---

func test_prop_defs() -> void:
	var reg: PropDef = load(REGISTER_DEF) as PropDef
	if not is_true(reg != null, "register.tres PropDef olmalı"):
		return
	eq(reg.id(), &"register", "id = dosya adı")
	eq(reg.hold_time, 3.0, "AC2: 3 sn")
	eq(reg.cash_value, 150, "AC2: +150")
	eq(reg.interact_range, 40.0)
	eq(reg.action_key, "INTERACT_REGISTER_EMPTY")
	is_true(reg.requirement != null and reg.requirement.side == Vector2.RIGHT, "personel tarafı +x")
	var door: PropDef = load(DOOR_DEF) as PropDef
	if is_true(door != null):
		eq(door.hold_time, 0.0, "AC3: anında")
		eq([door.action_key, door.alt_action_key], ["INTERACT_DOOR_OPEN", "INTERACT_DOOR_CLOSE"])
	eq(PropDef.new().hold_time, 0.0, "betik varsayılanları nötr")
	for key: String in ["INTERACT_REGISTER_EMPTY", "INTERACT_DOOR_OPEN", "INTERACT_DOOR_CLOSE"]:
		ne(TranslationServer.translate(key), StringName(key), "i18n anahtarı: " + key)


# --- Interactable bileşeni (AC1, AC4) ---

func test_component_setup() -> void:
	var reg: Node2D = _prop(REGISTER_SCENE, REG_POS)
	var item: Interactable = _interactable(reg)
	is_true(item.is_in_group(Interactable.GROUP))
	eq(item.collision_layer, 1 << 3, "katman interactables (§4)")
	eq(item.hold_time, 3.0, "tanımdan aktarılır")
	eq(item.action_key, "INTERACT_REGISTER_EMPTY")
	var sync: MultiplayerSynchronizer = item.get_node_or_null(Interactable.SYNC_NAME) as MultiplayerSynchronizer
	if is_true(sync != null, "busy_by/progress eşitleyicisi"):
		var props: Array = sync.replication_config.get_properties()
		has(props, NodePath(".:busy_by"))
		has(props, NodePath(".:progress"))
		eq(sync.get_multiplayer_authority(), 1, "host yetkili")
	for sig: String in ["completed", "cancelled", "request_finished"]:
		is_true(item.has_signal(sig), sig)


func test_host_rejects_customer_side_and_out_of_range() -> void:
	var item: Interactable = _interactable(_prop(REGISTER_SCENE, REG_POS))
	_watch(item)
	var actor: FakeActor = _actor(1, CUSTOMER)
	is_true(CUSTOMER.distance_to(REG_POS) <= item.interact_range, "müşteri tarafı menzil içinde")
	is_false(item.can_start(1, CUSTOMER), "istemci de hedef saymaz")
	item.request_start(1)
	eq(item.busy_by, 0)
	eq(_results, [[1, false]], "AC2: müşteri tarafı reddedilir")
	actor.position = REG_POS + Vector2(65, 0)
	item.request_start(2)
	eq(item.stats()["rejected"], {"wrong_side": 1, "out_of_range": 1}, "AC4: +24 px üstü reddedilir")
	# İstemcinin bayat konumu: menzil dışı ama +24 px içinde → host kabul eder (S2).
	actor.position = REG_POS + Vector2(60, 0)
	is_false(item.can_start(1, actor.position))
	item.request_start(3)
	eq(item.busy_by, 1, "tolerans içinde kabul")
	eq(_completed, [])


func test_host_accepts_lagging_staff_side_position() -> void:
	var item: Interactable = _interactable(_prop(REGISTER_SCENE, REG_POS))
	_watch(item)
	# İstemci personel tarafına doğuya yürürken istem görür; host konumu ~14 px geriden bilir (S2 taraf payı).
	var client_sees := Vector2(576.5, 395)
	is_true(item.can_start(1, client_sees))
	var actor: FakeActor = _actor(1, client_sees - Vector2(14, 0))
	item.request_start(1)
	eq(item.busy_by, 1, "geriden görülen personel tarafı konumu kabul")
	item.request_cancel(1)
	# Müşteri tarafının en yakın konumu (tezgâha yaslanmış) yine reddedilir.
	actor.position = Vector2(534, 368)
	_run(item, InteractionRules.REPEAT_COOLDOWN + DT)
	item.request_start(2)
	eq(item.busy_by, 0)
	eq(item.stats()["rejected"], {"wrong_side": 1})
	eq(_results, [[1, false], [2, false]])


func test_duplicate_request_adopts_new_seq_and_range_shape_follows() -> void:
	var reg: Node2D = _prop(REGISTER_SCENE, REG_POS)
	var item: Interactable = _interactable(reg)
	_watch(item)
	_actor(1, STAFF)
	item.request_start(1)
	item.request_start(2)  # aynı peer'ın yinelenen isteği
	eq(item.busy_by, 1)
	eq(item.stats()["requests"], 1, "yineleme yeni istek sayılmaz")
	_run(item, 3.1)
	eq(_results, [[2, true]], "karar yeni sıra numarasıyla gider (istemcinin süre aşımı işler)")
	var shapes: Array[Node] = item.find_children("*", "CollisionShape2D", false, false)
	if is_true(shapes.size() == 1):
		eq(((shapes[0] as CollisionShape2D).shape as CircleShape2D).radius, item.interact_range)
		item.interact_range = 55.0
		eq(((shapes[0] as CollisionShape2D).shape as CircleShape2D).radius, 55.0, "menzil değişince daire de")
	var stats: Dictionary = item.stats()
	eq([stats["accepted"], stats["completed"], stats["rejected_total"]], [1, 1, 0])


func test_busy_and_missing_actor() -> void:
	var item: Interactable = _interactable(_prop(REGISTER_SCENE, REG_POS))
	_watch(item)
	_actor(1, STAFF)
	_actor(2, STAFF + Vector2(0, 8))
	item.request_start(1)
	eq(item.busy_by, 1)
	item._host_start(2, 7)  # uzak peer'ın isteği (RPC gövdesi)
	eq(item.busy_by, 1, "AC4: yalnız biri")
	eq(item.stats()["rejected"], {"busy": 1})
	item._host_cancel(2, 7)
	eq(item.busy_by, 1, "başkasının iptali etkisiz")
	item.request_cancel(99)
	eq(item.busy_by, 1, "eski sıra numaralı iptal etkisiz")
	item._host_start(3, 1)
	eq(item.stats()["rejected"], {"busy": 1, "no_actor": 1}, "aktörü olmayan peer")
	# Tutan aktör kaybolursa (ayrıldı) host iptal eder.
	for node: Node in tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == 1:
			node.remove_from_group(Interactable.ACTOR_GROUP)
	_run(item, DT)
	eq(item.busy_by, 0)
	eq(_cancelled, [1])


# --- kasa (AC2) ---

func test_register_full_hold_pays_once() -> void:
	eq(Net.host(free_udp_port()), OK)
	var start_cash: int = Game.team_cash()
	var reg: Register = _prop(REGISTER_SCENE, REG_POS) as Register
	var item: Interactable = _interactable(reg)
	_watch(item)
	_actor(1, STAFF)
	is_true(item.can_start(1, STAFF))
	item.request_start(1)
	_run(item, 2.9)
	is_false(reg.emptied, "3 sn dolmadan boşalmaz")
	near(reg.progress_ratio(), 2.9 / 3.0, 0.01)
	_run(item, 0.2)
	is_true(reg.emptied, "AC2: 3 sn → boş")
	eq(Game.team_cash(), start_cash + 150, "AC2: host ekip nakdine +150")
	eq(_completed, [1])
	eq(_results, [[1, true]])
	eq(item.busy_by, 0)
	is_false(item.enabled, "boş kasa bir daha etkileşilmez")
	is_false(item.can_start(1, STAFF))
	item.request_start(2)
	eq(_results.back(), [2, false])
	eq(Game.team_cash(), start_cash + 150, "ikinci kez ödeme yok")
	var dump: Dictionary = reg.dump_state()
	eq(dump["emptied"], true)
	near(float(dump["visible_delay_ms"]), 0.0, 1.0, "host'ta görünme gecikmesi ~0")
	Net.leave()
	await tree().process_frame
	await tree().process_frame


func test_register_partial_hold_resets() -> void:
	eq(Net.host(free_udp_port()), OK)
	var start_cash: int = Game.team_cash()
	var reg: Register = _prop(REGISTER_SCENE, REG_POS) as Register
	var item: Interactable = _interactable(reg)
	_watch(item)
	var actor: FakeActor = _actor(1, STAFF)
	item.request_start(1)
	_run(item, 2.0)
	item.request_cancel(1)
	eq(_results, [[1, false]], "yarıda bırakma iptal")
	eq(item.progress, 0.0, "ilerleme sıfırlanır")
	item.request_start(2)
	_run(item, 1.5)
	item.request_cancel(2)
	is_false(reg.emptied, "2 + 1,5 sn: sıfırlandığı için tamamlanmaz")
	eq(Game.team_cash(), start_cash)
	# Son 0,25 sn payında bırakma tamam sayılır (S2 zaman toleransı).
	item.request_start(3)
	_run(item, 2.8)
	item.request_cancel(3)
	eq(_results.back(), [3, true])
	is_true(reg.emptied)
	eq(Game.team_cash(), start_cash + 150)
	# Menzilden (+ tolerans) çıkınca host iptal eder.
	var reg2: Register = _prop(REGISTER_SCENE, REG_POS + Vector2(0, 200)) as Register
	var item2: Interactable = _interactable(reg2)
	_watch(item2)
	actor.position = reg2.position + Vector2(28, 0)
	item2.request_start(4)
	_run(item2, 1.0)
	actor.position = reg2.position + Vector2(28 + 40, 0)
	_run(item2, DT)
	eq(item2.busy_by, 0, "uzaklaşınca iptal")
	eq(_results.back(), [4, false])
	is_false(reg2.emptied)
	Net.leave()
	await tree().process_frame
	await tree().process_frame


# --- kapı (AC3) ---

func test_door_toggles_instantly_and_blocks() -> void:
	var door: Door = _prop(DOOR_SCENE, Vector2(368, 464)) as Door
	var item: Interactable = _interactable(door)
	_watch(item)
	is_false(door.is_open, "varsayılan kapalı")
	is_true(door.is_blocking(), "kapalıyken engel")
	var body: StaticBody2D = door.get_node("Body") as StaticBody2D
	eq(body.collision_layer, 1, "engel world katmanında (§4)")
	eq(item.action_key, "INTERACT_DOOR_OPEN")
	eq(item.hold_time, 0.0)
	var actor: FakeActor = _actor(1, Vector2(368, 498))
	is_true(item.can_start(1, actor.position))
	item.request_start(1)
	is_true(door.is_open, "AC3: anında açılır")
	eq(_results, [[1, true]])
	eq(item.busy_by, 0, "anlık eylem meşgul bırakmaz")
	eq(item.action_key, "INTERACT_DOOR_CLOSE")
	await tree().process_frame
	is_false(door.is_blocking(), "açıkken engel yok")
	# Tekrar beklemesi: aynı anda basan ikinci oyuncu kapıyı geri çevirmez (AC4).
	_actor(2, Vector2(368, 430))
	item._host_start(2, 1)
	is_true(door.is_open)
	eq(item.stats()["rejected"], {"cooldown": 1})
	_run(item, InteractionRules.REPEAT_COOLDOWN + DT)
	item._host_start(2, 2)
	is_false(door.is_open, "bekleme sonrası kapanır")
	await tree().process_frame
	is_true(door.is_blocking())
	var dump: Dictionary = door.dump_state()
	eq(dump["open"], false)
	eq(dump["flips"], 2)
	eq(dump["consistent"], true)
	eq(dump["interact"]["completed"], 2)
	eq(dump["interact"]["requests"], 3)
	eq(dump["interact"]["rejected_total"], 1)
	eq(dump["interact"]["accepted"], 2)


func test_door_physically_blocks_body() -> void:
	var door: Door = _prop(DOOR_SCENE, Vector2(0, 0)) as Door
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	body.add_child(shape)
	body.collision_mask = 1
	body.position = Vector2(0, 30)
	tree().root.add_child(body)
	autofree(body)
	await tree().physics_frame
	is_true(body.test_move(body.global_transform, Vector2(0, -40)), "kapalı kapı yolu keser")
	_actor(1, Vector2(0, 30))
	_interactable(door).request_start(1)
	await tree().process_frame
	await tree().physics_frame
	is_false(body.test_move(body.global_transform, Vector2(0, -40)), "açık kapı geçirir")


func test_door_start_state_from_scene() -> void:
	var door: Door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	door.is_open = true
	tree().root.add_child(door)
	autofree(door)
	is_false(door.is_blocking(), "sahnede açık başlayan kapı engellemez")
	eq(door.dump_state()["flips"], 0, "başlangıç değeri değişim sayılmaz")
	eq(_interactable(door).action_key, "INTERACT_DOOR_CLOSE")


# --- store_a yerleşimi (AC5) ---

func test_store_props_on_markers() -> void:
	var level: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	var props: Node2D = level.props_root()
	if not is_true(props != null):
		return
	var expected: Dictionary = {"Register": REGISTER_SCENE, "FrontDoor": DOOR_SCENE, "BackDoor": DOOR_SCENE}
	for prop_name: String in expected:
		var prop: Node2D = props.get_node_or_null(prop_name) as Node2D
		if not is_true(prop != null, "Props/%s yok" % prop_name):
			continue
		eq(prop.scene_file_path, expected[prop_name], prop_name)
		var marker: Node2D = level.marker(StringName(prop_name))
		if is_true(marker != null, "Markers/%s" % prop_name):
			eq(prop.position, marker.position, "%s işaret konumunda" % prop_name)
			eq(prop.rotation, marker.rotation, "%s işaret yönünde" % prop_name)
	eq((props.get_node("FrontDoor") as Door).is_open, true, "ön kapı mesai saatinde açık")
	eq((props.get_node("BackDoor") as Door).is_open, false, "arka kapı kapalı")
	# Personel tarafı: tezgâhtar yerinden boşaltılır; aynı uzaklıkta müşteri tarafından değil.
	tree().root.add_child(level)
	var item: Interactable = _interactable(props.get_node("Register"))
	var clerk: Vector2 = level.marker(&"ClerkSpot").global_position
	var reg: Vector2 = item.global_position
	is_true(item.can_start(1, clerk), "tezgâhtar yerinden")
	is_false(item.can_start(1, reg - (clerk - reg)), "müşteri tarafı aynı uzaklıkta")


# --- oyuncu tarafı (S7) ---

func test_player_interaction_flow() -> void:
	var interaction := PlayerInteraction.new()
	tree().root.add_child(interaction)
	autofree(interaction)
	var keys: Array[String] = []
	var started: Array = []
	var finished: Array[bool] = []
	interaction.target_changed.connect(func(k: String) -> void: keys.append(k))
	interaction.started.connect(func(k: String, d: float) -> void: started.append([k, d]))
	interaction.finished.connect(func(ok: bool) -> void: finished.append(ok))
	var reg: Register = _prop(REGISTER_SCENE, REG_POS) as Register
	var door: Door = _prop(DOOR_SCENE, REG_POS + Vector2(0, 80)) as Door
	var actor: FakeActor = _actor(1, CUSTOMER)
	# Müşteri tarafında kasa hedef değil; kapı menzil dışında.
	interaction.tick(DT, false, actor.position, 1)
	eq(keys, [] as Array[String], "hedef yok")
	# Personel tarafı: en yakın uygun hedef kasa.
	actor.position = STAFF
	interaction.tick(DT, false, actor.position, 1)
	eq(keys, ["INTERACT_REGISTER_EMPTY"] as Array[String])
	# Basılı tutma: ön kenarda istek; erken bırakmada hemen başarısız (host da iptal eder).
	interaction.tick(DT, true, actor.position, 1)
	eq(started, [["INTERACT_REGISTER_EMPTY", 3.0]])
	is_true(interaction.is_active())
	eq(_interactable(reg).busy_by, 1)
	interaction.tick(DT, false, actor.position, 1)
	eq(finished, [false] as Array[bool])
	eq(_interactable(reg).busy_by, 0)
	# Basılı kalmak yeniden başlatmaz: bırakıp yeniden basmak gerekir.
	interaction.tick(DT, true, actor.position, 1)
	interaction.tick(DT, true, actor.position, 1)
	eq(started.size(), 2)
	interaction.tick(DT, false, actor.position, 1)
	interaction.tick(DT, true, actor.position, 1)
	eq(started.size(), 3)
	interaction.tick(DT, false, actor.position, 1)
	# Kapıya yaklaş: hedef değişir; anlık eylem host kararıyla biter.
	actor.position = door.position + Vector2(0, 30)
	interaction.tick(DT, false, actor.position, 1)
	eq(keys.back(), "INTERACT_DOOR_OPEN")
	interaction.tick(DT, true, actor.position, 1)
	eq(finished.back(), true)
	is_true(door.is_open)
	interaction.tick(DT, false, actor.position, 1)
	eq(keys.back(), "INTERACT_DOOR_CLOSE", "durum değişince istem güncellenir")
	var stats: Dictionary = interaction.stats()
	eq([stats["requests"], stats["successes"], stats["failures"]], [4, 1, 3])


func test_player_ignores_stale_verdict_and_waits_in_tolerance_window() -> void:
	var interaction := PlayerInteraction.new()
	tree().root.add_child(interaction)
	autofree(interaction)
	var finished: Array[bool] = []
	interaction.finished.connect(func(ok: bool) -> void: finished.append(ok))
	var item := RemoteInteractable.new()
	item.hold_time = 3.0
	item.action_key = "INTERACT_REGISTER_EMPTY"
	item.position = Vector2(1000, 1000)
	tree().root.add_child(item)
	autofree(item)
	var at: Vector2 = item.position + Vector2(20, 0)
	interaction.tick(DT, false, at, 1)
	eq(interaction.target_key(), "INTERACT_REGISTER_EMPTY")
	# 1) Erken bırakma: iptal yollanır, sonuç beklenmeden başarısız; geç gelen eski karar yok sayılır.
	interaction.tick(DT, true, at, 1)
	eq(item.sent, [["start", 1]])
	item.request_finished.emit(0, true)  # başka isteğin kararı
	is_true(interaction.is_active())
	_hold(interaction, 2.0, at)
	interaction.tick(DT, false, at, 1)
	eq(item.sent.back(), ["cancel", 1])
	eq(finished, [false] as Array[bool])
	item.request_finished.emit(1, true)
	eq(finished, [false] as Array[bool], "bitmiş isteğin kararı uygulanmaz")
	# 2) Son payda bırakma: host kararı beklenir ve uygulanır (S2 zaman toleransı).
	interaction.tick(DT, true, at, 1)
	_hold(interaction, 2.7, at)
	interaction.tick(DT, false, at, 1)
	eq(item.sent.back(), ["cancel", 2])
	is_true(interaction.is_active(), "karar bekleniyor")
	eq(finished.size(), 1)
	item.request_finished.emit(2, true)
	eq(finished, [false, true] as Array[bool])
	# 3) Karar hiç gelmezse (bağlantı sorunu) süre aşımında başarısız.
	interaction.tick(DT, true, at, 1)
	_hold(interaction, 2.9, at)
	interaction.tick(DT, false, at, 1)
	_hold(interaction, PlayerInteraction.VERDICT_TIMEOUT_SEC + 0.1, at, false)
	eq(finished, [false, true, false] as Array[bool])
	is_false(interaction.is_active())


func _hold(interaction: PlayerInteraction, seconds: float, at: Vector2, held: bool = true) -> void:
	for i: int in roundi(seconds / DT):
		interaction.tick(DT, held, at, 1)


func test_player_scene_emits_s7_signals() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.set_multiplayer_authority(1, true)
	player.position = Vector2(368, 498)
	var door: Door = _prop(DOOR_SCENE, Vector2(368, 464)) as Door
	var keys: Array[String] = []
	var finished: Array[bool] = []
	player.interaction_target_changed.connect(func(k: String) -> void: keys.append(k))
	player.interaction_finished.connect(func(ok: bool) -> void: finished.append(ok))
	tree().root.add_child(player)
	autofree(player)
	is_true(player.is_in_group(Interactable.ACTOR_GROUP))
	eq(player.interaction_position(), player.global_position)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.05, "press": "interact"}]))
	for i: int in 8:
		await tree().physics_frame
	eq(keys.front() if not keys.is_empty() else "", "INTERACT_DOOR_OPEN", "istem: kapıyı aç")
	eq(finished, [true] as Array[bool])
	is_true(door.is_open, "oyuncu girdisiyle (PlayerInput, bot) kapı açıldı")
	is_false(player.is_interacting())


func test_remote_player_reports_latest_synced_position() -> void:
	var root := Node2D.new()
	root.position = Vector2(10, 20)
	tree().root.add_child(root)
	autofree(root)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "7"
	player.set_multiplayer_authority(7, true)
	root.add_child(player)
	eq(player.interaction_position(), player.global_position, "veri gelmeden çizilen konum")
	player.net_position = Vector2(100, 50)
	player.net_time = 1.0
	eq(player.interaction_position(), Vector2(110, 70), "eşitleyicinin en güncel konumu (global)")
