extends Node
## Oturum ve oyuncular (autoload `Game`, sözleşme S3 — docs/notes/mimari.md).
##
## Oturum: `Net.local_peer_id() != 0` olduğu sürece (bağlanma ve el sıkışması dahil) oturum açık sayılır;
## her karede ve her giriş noktasında `_sync_session()` geçişi yakalar. Oturum bitince (Net.leave(),
## connection_failed ya da host_disconnected) seviye (HUD ile) kaldırılır, oyuncu/nakit/olay durumu sıfırlanır.
## Seviye `current_scene` değildir; temizliği Game yapar. Menüye dönüşü arayüz (HUD) yapar; Game ve main.gd
## sahne değiştirmez (çift geçiş olmasın). Headless/argümanlı açılışta main.gd çıkar (AC4).
## Host lehine yetki S2'ye uyar: host'a özgü işlemler `_has_host_authority()` (host ya da çevrimdışı) ile
## korunur, host→herkes durum RPC'leri "authority". Arayüz sahneleri preload edilmez, load() ile yüklenir.
##
## Seviye ve oyuncu sırası (geç katılan için "node not found" tuzağı):
## - Seviyeler her peer'da `/root/Game/World/Level` yoluna elle yüklenir; altında `PlayerSpawner`
##   (MultiplayerSpawner, spawn_path = ../Players, özel spawn_function: player_scene örneği, ad str(peer_id),
##   yetki peer_id) kurulur.
## - Bağlanan istemci, oturuma kabul edilmeden önce SceneMultiplayer el sıkışmasında (auth) host'tan geçerli
##   seviye yolunu alır ve seviyeyi eşzamanlı yükler; ancak sonra kabul edilir. Kabulde host'un çoğaltıcısı
##   mevcut oyuncuları gönderdiğinde seviye ve PlayerSpawner istemcide zaten vardır.
## - Kabulde çoğaltıcı mevcut oyuncuları ilk spawn verisiyle (doğma noktası) gönderir; istemci yetkili
##   oyuncuların eşitlemesi yol onayından (~2 RTT) sonra başlar. Arada geç katılan onları doğma noktasında ya da
##   donmuş görmesin diye host, bildiği güncel konumları hemen (güvenilir) ve CATCHUP_SEC boyunca 20 Hz
##   (güvenilmez) yollar; istemci bunları yalnız o düğümün eşitleyicisinden ilk veri gelene kadar uygular.
##   Aynısı oturum içi seviye değişiminden sonra herkese yapılır.
## - Oturum içinde seviye değişiminde host önce oyuncuları kaldırır (despawn), sonra `_rpc_load_level` RPC'sini,
##   en son yeni oyuncuları gönderir; hepsi aynı güvenilir sıralı kanalda olduğundan istemci yolu hazırken alır.
## - Uzak oyuncu varken değişimden önce host istemcilere "dondur" der: her istemci kendi yetkisindeki
##   eşitleyicilerin yayınını kapatır (public_visibility = false) ve onay yollar. Bütün onaylar (ya da
##   FREEZE_TIMEOUT_SEC) gelmeden despawn yapılmaz; böylece yolda kalmış eski eşitleme paketleri kaldırılmış
##   düğüme çarpıp "Ignoring sync data ... missing node" hatası üretmez. Bu yüzden çevrimiçi `start_level`
##   ~1 RTT sonra tamamlanabilir; sonucu `level_loaded` bildirir. El sıkışması süren peer varken de bekler.
## Döküm (S6): `collect_dump()` taban anahtarları + `register_dump_provider` ile eklenen anahtarlar; değerler
## JSON'a uygun biçime çevrilir (Vector2 -> [x, y], Color -> "#rrggbbaa", StringName -> String).

signal players_changed()
signal local_player_changed(player: Node)
signal team_cash_changed(value: int)
signal level_loaded(level: Node)
## Herkeste yayılır (ör. &"police_called").
signal session_event(kind: StringName, data: Dictionary)

const DEFAULT_LEVEL := "res://levels/store_a.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
const DEFAULT_PLAYER_SCENE := "res://entities/player/player.tscn"
## El sıkışma protokolü sürümü; uyuşmayan peer reddedilir.
const PROTOCOL_VERSION := 1
const AUTH_TIMEOUT_SEC := 10.0
const MAX_NAME_LENGTH := 24
const MAX_EVENTS := 256
const LEVEL_NODE_NAME := "Level"
const SPAWNER_NODE_NAME := "PlayerSpawner"
const HUD_LAYER := 10
## Seviye değişiminde istemcilerin eşitlemeyi durdurma onayı için üst süre.
const FREEZE_TIMEOUT_SEC := 1.0
## Geç katılana / seviye değişiminden sonra host'un bildiği konumların yollandığı süre ve aralık.
const CATCHUP_SEC := 2.0
const CATCHUP_INTERVAL_SEC := 0.05
## collect_dump() taban anahtarları; sağlayıcılar bunları ezemez.
const BASE_DUMP_KEYS: Array[String] = [
	"peer_id", "is_host", "peers", "players", "team_cash", "level", "player_nodes", "events", "host_lost",
	"ping_ms",
]
const _SYNCED_META := &"_game_synced"

## Varsayılanı res://entities/player/player.tscn (dosya yoksa null); testler değiştirebilir.
var player_scene: PackedScene

var _world: Node
var _level: Node = null
var _level_path: String = ""
var _spawner: MultiplayerSpawner = null
## peer_id -> {"name": String, "color": Color}
var _players: Dictionary = {}
## Host: peer_id -> katılım yuvası (renk ve doğma noktası sırası).
var _slots: Dictionary = {}
## Oturumdaki uzak peer'lar (Net sinyallerinden).
var _peer_ids: Array[int] = []
var _local_name: String = ""
var _team_cash: int = 0
var _events: Array[Dictionary] = []
var _dump_providers: Dictionary = {}
var _host_lost: bool = false
var _session_peer: MultiplayerPeer = null
var _pending_level: String = ""
## Host: seviye değişimi öncesi "donduruldu" onayı beklenen peer'lar ve son tarih (ms).
var _freeze_acks: Dictionary = {}
var _freeze_deadline_ms: int = 0
## Host: el sıkışması süren peer -> bildirdiği ad.
var _auth_names: Dictionary = {}
## Host: konum yetiştirmesi süren peer -> son tarih (ms).
var _catchup: Dictionary = {}
var _catchup_elapsed: float = 0.0
var _players_broadcast_queued: bool = false
var _warned_no_player_scene: bool = false


func _ready() -> void:
	if player_scene == null and ResourceLoader.exists(DEFAULT_PLAYER_SCENE):
		player_scene = load(DEFAULT_PLAYER_SCENE) as PackedScene
	_world = Node.new()
	_world.name = "World"
	add_child(_world)
	var sm: SceneMultiplayer = multiplayer as SceneMultiplayer
	if sm != null:
		sm.auth_callback = _on_auth_data
		sm.auth_timeout = AUTH_TIMEOUT_SEC
		sm.peer_authenticating.connect(_on_peer_authenticating)
		sm.peer_authentication_failed.connect(_on_peer_authentication_failed)
	else:
		push_error("Game: SceneMultiplayer bekleniyordu; el sıkışması kurulamadı")
	Net.peer_connected.connect(_on_peer_connected)
	Net.peer_disconnected.connect(_on_peer_disconnected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.host_disconnected.connect(_on_host_disconnected)


func _process(delta: float) -> void:
	_sync_session()
	_try_start_pending_level()
	_send_catchup(delta)


## Bağlanınca host'a bildirilir.
func set_local_name(player_name: String) -> void:
	_local_name = _sanitize_name(player_name)
	_sync_session()
	if not Net.is_online():
		return
	if Net.is_host():
		if _players.has(1):
			(_players[1] as Dictionary)["name"] = _local_name
			_broadcast_players()
	else:
		_rpc_set_name.rpc_id(1, _local_name)


## peer_id -> {"name": String, "color": Color}
func players() -> Dictionary:
	return _players.duplicate(true)


## Yerel oyuncu düğümü ya da null.
func local_player() -> Node:
	var root: Node = _players_root()
	if root == null or Net.local_peer_id() == 0:
		return null
	return root.get_node_or_null(NodePath(str(Net.local_peer_id())))


## Yalnız host; herkese yükletir. Uzak oyuncu yokken hemen; varken istemciler eşitlemeyi durdurunca
## (~1 RTT) yüklenir. Bitince `level_loaded` yayılır.
func start_level(level_path: String) -> void:
	if not _has_host_authority():
		push_warning("Game.start_level: yalnız host çağırabilir")
		return
	if not _is_level_path(level_path) or not ResourceLoader.exists(level_path):
		push_error("Game.start_level: seviye bulunamadı: " + level_path)
		return
	_sync_session()
	_pending_level = level_path
	_freeze_acks.clear()
	if Net.is_online() and _has_remote_players():
		for peer_id: int in multiplayer.get_peers():
			_freeze_acks[peer_id] = true
		_freeze_deadline_ms = Time.get_ticks_msec() + int(FREEZE_TIMEOUT_SEC * 1000.0)
		_rpc_freeze_players.rpc()
	_try_start_pending_level()


func current_level() -> Node:
	return _level


## Yalnız host.
func add_team_cash(amount: int) -> void:
	if not _has_host_authority():
		push_warning("Game.add_team_cash: yalnız host çağırabilir")
		return
	if amount == 0:
		return
	_to_all(&"_rpc_team_cash", [_team_cash + amount])


func team_cash() -> int:
	return _team_cash


## Yalnız host; herkese yayınlar, dökümde "events" listesine girer.
func raise_session_event(kind: StringName, data: Dictionary = {}) -> void:
	if not _has_host_authority():
		push_warning("Game.raise_session_event: yalnız host çağırabilir")
		return
	_to_all(&"_rpc_session_event", [kind, data])


## `key` dökümde üst düzey anahtar olur; değer döküm anında `provider.call()` ile alınır.
## Taban anahtarlar (BASE_DUMP_KEYS) ezilemez; aynı anahtar yeniden kaydedilirse son kayıt geçerlidir.
func register_dump_provider(key: String, provider: Callable) -> void:
	if key.is_empty() or not provider.is_valid():
		push_warning("Game.register_dump_provider: geçersiz anahtar ya da çağrılabilir")
		return
	if BASE_DUMP_KEYS.has(key):
		push_warning("Game.register_dump_provider: taban anahtar ezilemez: " + key)
		return
	_dump_providers[key] = provider


func collect_dump() -> Dictionary:
	var local_id: int = Net.local_peer_id()
	var peers: Array[int] = []
	if local_id != 0:
		peers.append(local_id)
		for peer_id: int in _peer_ids:
			if not peers.has(peer_id):
				peers.append(peer_id)
	peers.sort()
	var dump: Dictionary = {
		"peer_id": local_id,
		"is_host": Net.is_host(),
		"peers": peers,
		"players": _dump_players(),
		"team_cash": _team_cash,
		"level": _level_path,
		"player_nodes": _player_node_ids(),
		"events": to_json_value(_events),
		"host_lost": _host_lost,
		"ping_ms": _dump_pings(),
	}
	for key: String in _dump_providers:
		var provider: Callable = _dump_providers[key]
		if provider.is_valid():
			dump[key] = to_json_value(provider.call())
	return dump


## Değeri JSON'a yazılabilir biçime çevirir (iç içe Dictionary/Array dahil).
static func to_json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			var src: Dictionary = value
			for key: Variant in src:
				out[str(key)] = to_json_value(src[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var arr: Array = []
			for item: Variant in value:
				arr.append(to_json_value(item))
			return arr
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_COLOR:
			return "#" + (value as Color).to_html(true)
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			return str(value) if value != null else null
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_NIL:
			return value
	return str(value)


# --- oturum ---

## Oturum, Net'te bir taşıma (host, bağlanma, el sıkışması ya da kabul) olduğu sürece açıktır.
func _sync_session() -> void:
	var current: MultiplayerPeer = multiplayer.multiplayer_peer if Net.local_peer_id() != 0 else null
	if current == _session_peer:
		return
	if _session_peer != null:
		_end_session()
	_session_peer = current
	if current != null:
		_begin_session()


func _begin_session() -> void:
	_host_lost = false
	if Net.is_host():
		_events.clear()
		_set_team_cash(0)
		_players.clear()
		_slots.clear()
		_add_player(1, _local_name)
		players_changed.emit()


func _end_session() -> void:
	_session_peer = null
	_pending_level = ""
	_freeze_acks.clear()
	_catchup.clear()
	_unload_level()
	_players.clear()
	_slots.clear()
	_peer_ids.clear()
	_auth_names.clear()
	_events.clear()
	_set_team_cash(0)
	players_changed.emit()


## Host ya da çevrimdışı (tek başına). Ağ olay anında `multiplayer.is_server()`'ın kapanmış taşımaya
## sorup hata basmaması için Net bayraklarından okunur; anlamı S2'deki is_server() korumasıyla aynıdır.
func _has_host_authority() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0


## Host→herkes durum çağrısı: çevrimiçiyse RPC (call_local), değilse yerel çağrı.
func _to_all(method: StringName, args: Array) -> void:
	if Net.is_online():
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


func _authenticating_peers() -> PackedInt32Array:
	var sm: SceneMultiplayer = multiplayer as SceneMultiplayer
	return sm.get_authenticating_peers() if sm != null else PackedInt32Array()


## Bekleyen seviye değişimini koşullar sağlandıysa uygular: el sıkışması süren peer yok ve bütün
## "donduruldu" onayları geldi (ya da süre doldu).
func _try_start_pending_level() -> void:
	if _pending_level.is_empty():
		return
	if Net.is_online():
		if not _authenticating_peers().is_empty():
			return  # el sıkışması süren peer eski yolu almış olabilir; bitince yüklenir
		if not _freeze_acks.is_empty() and Time.get_ticks_msec() < _freeze_deadline_ms:
			return
	var level_path: String = _pending_level
	_pending_level = ""
	_freeze_acks.clear()
	_despawn_all_players()
	_unload_level()
	if not _load_level_local(level_path):
		return
	if Net.is_online():
		_rpc_load_level.rpc(level_path)
	var ids: Array = _players.keys()
	ids.sort()
	for peer_id: int in ids:
		_spawn_player(peer_id)
	if Net.is_online():
		for peer_id: int in multiplayer.get_peers():
			_start_catchup(peer_id)


# --- Net olayları ---
# Host'un ağ olaylarına tepkisi (yayın, spawn/despawn) kare sonuna ertelenir: aynı poll'da birden çok peer
# koptuğunda, olayı henüz işlenmemiş kopuk peer'a gönderim "Unable to send packet ... max channels: 0"
# hatası verir. Kare sonunda taşımanın bütün olayları işlenmiş olur.

func _on_peer_connected(peer_id: int) -> void:
	_sync_session()
	if not _peer_ids.has(peer_id):
		_peer_ids.append(peer_id)
	if Net.is_host():
		# Hedef yeni kabul edilmiş, canlı peer: konumlar aynı poll'da spawn paketlerinin hemen ardından gider.
		var positions: Dictionary = _player_positions()
		if not positions.is_empty():
			_rpc_catchup_positions_reliable.rpc_id(peer_id, positions)
		_start_catchup(peer_id)
		_host_admit_peer.call_deferred(peer_id)


func _host_admit_peer(peer_id: int) -> void:
	if not Net.is_host() or not _peer_ids.has(peer_id) or _players.has(peer_id):
		return  # bu arada ayrıldı ya da oturum bitti
	var player_name: String = str(_auth_names.get(peer_id, ""))
	_auth_names.erase(peer_id)
	_add_player(peer_id, player_name)
	_broadcast_players()
	_rpc_team_cash.rpc_id(peer_id, _team_cash)
	if _level != null:
		_spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_peer_ids.erase(peer_id)
	# İstemcide oyuncu kaydı ve düğümü host'tan silinir (players RPC'si + despawn).
	if Net.is_host():
		_host_drop_peer.call_deferred(peer_id)


func _host_drop_peer(peer_id: int) -> void:
	if not Net.is_host() or _peer_ids.has(peer_id):
		return
	_slots.erase(peer_id)
	_catchup.erase(peer_id)
	if _players.erase(peer_id):
		_broadcast_players()
	_despawn_player(peer_id)
	if _freeze_acks.erase(peer_id):
		_try_start_pending_level()


func _on_connection_failed() -> void:
	_sync_session()  # el sıkışmasında yüklenmiş seviye ve durum hemen kalksın


func _on_host_disconnected() -> void:
	# Durum bir sonraki karede (_sync_session) temizlenir: dinleyiciler (döküm) önce son durumu görür.
	_host_lost = true


# --- el sıkışması (SceneMultiplayer auth) ---
# Host kabul öncesi seviye yolunu yollar; istemci yükler, adını ve yüklediği yolu yanıtlar ve el sıkışmasını
# kendi tarafında bitirir. Host yol eşleşirse bitirir, eşleşmezse (sürüm/biçim bozuk ya da yol farklı)
# bağlantıyı keser. Host el sıkışması süren peer varken seviye değiştirmez (bkz. _try_start_pending_level).

func _on_peer_authenticating(peer_id: int) -> void:
	if Net.is_host():
		var hello: Dictionary = {"v": PROTOCOL_VERSION, "level": _level_path}
		(multiplayer as SceneMultiplayer).send_auth(peer_id, var_to_bytes(hello))


func _on_peer_authentication_failed(peer_id: int) -> void:
	_auth_names.erase(peer_id)


func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	var sm: SceneMultiplayer = multiplayer as SceneMultiplayer
	var msg: Variant = bytes_to_var(data)  # nesne çözülmez (güvenli)
	if typeof(msg) != TYPE_DICTIONARY or typeof((msg as Dictionary).get("v")) != TYPE_INT \
			or int((msg as Dictionary)["v"]) != PROTOCOL_VERSION:
		push_warning("Game: peer %d el sıkışması reddedildi (sürüm/biçim uyuşmuyor)" % peer_id)
		sm.disconnect_peer(peer_id)
		return
	var d: Dictionary = msg
	var level_path: String = str(d.get("level", ""))
	if Net.is_host():
		if level_path != _level_path:
			push_warning("Game: peer %d el sıkışması reddedildi (seviye uyuşmuyor)" % peer_id)
			sm.disconnect_peer(peer_id)
			return
		_auth_names[peer_id] = _sanitize_name(d.get("name", ""))
		sm.complete_auth(peer_id)
		return
	if peer_id != 1:
		return
	if level_path != _level_path:
		var ok: bool = level_path.is_empty() or (_is_level_path(level_path) and ResourceLoader.exists(level_path))
		if ok:
			_unload_level()
			ok = level_path.is_empty() or _load_level_local(level_path)
		if not ok:
			push_error("Game: host'un seviyesi yüklenemedi: " + level_path)
			sm.disconnect_peer(1)
			return
	sm.send_auth(1, var_to_bytes({"v": PROTOCOL_VERSION, "name": _local_name, "level": _level_path}))
	sm.complete_auth(1)


# --- RPC'ler (host→herkes: "authority"; istemci→host: "any_peer" + gönderen doğrulaması) ---

@rpc("authority", "call_local", "reliable")
func _rpc_players(data: Dictionary) -> void:
	var clean: Dictionary = {}
	for key: Variant in data:
		var entry: Variant = data[key]
		if typeof(key) != TYPE_INT or typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		var color: Color = e["color"] if typeof(e.get("color")) == TYPE_COLOR else Color.WHITE
		clean[key] = {"name": _sanitize_name(e.get("name", "")), "color": color}
	_players = clean
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_team_cash(value: int) -> void:
	_set_team_cash(value)


@rpc("authority", "call_local", "reliable")
func _rpc_session_event(kind: StringName, data: Dictionary) -> void:
	# call_local'da `data` çağıranın sözlüğüdür; sonradan değişirse kayıt değişmesin.
	_events.append({"kind": kind, "data": data.duplicate(true)})
	if _events.size() > MAX_EVENTS:
		_events.pop_front()
	session_event.emit(kind, data)


## Host'un bildiği oyuncu konumları (peer_id -> Vector2): kabulde bir kez güvenilir, sonra akış güvenilmez.
@rpc("authority", "call_remote", "reliable")
func _rpc_catchup_positions_reliable(positions: Dictionary) -> void:
	_apply_catchup(positions)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_catchup_positions(positions: Dictionary) -> void:
	_apply_catchup(positions)


## Seviyeyi host zaten yükledi; yalnız istemcilere gider.
@rpc("authority", "call_remote", "reliable")
func _rpc_load_level(level_path: String) -> void:
	if not _is_level_path(level_path):
		push_warning("Game: geçersiz seviye yolu reddedildi: " + level_path)
		return
	_unload_level()
	_load_level_local(level_path)


## Seviye değişimi öncesi: istemci kendi yetkisindeki eşitleyicilerin yayınını kapatır ve onaylar.
@rpc("authority", "call_remote", "reliable")
func _rpc_freeze_players() -> void:
	if _level != null:
		var me: int = Net.local_peer_id()
		for node: Node in _level.find_children("*", "MultiplayerSynchronizer", true, false):
			var sync: MultiplayerSynchronizer = node as MultiplayerSynchronizer
			if sync.get_multiplayer_authority() == me:
				sync.public_visibility = false
	_rpc_players_frozen.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_players_frozen() -> void:
	if not Net.is_host():
		return
	if _freeze_acks.erase(multiplayer.get_remote_sender_id()):
		_try_start_pending_level.call_deferred()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_name(player_name: String) -> void:
	if not Net.is_host():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _players.has(sender):
		push_warning("Game: bilinmeyen peer %d ad değiştirmeye çalıştı" % sender)
		return
	(_players[sender] as Dictionary)["name"] = _sanitize_name(player_name)
	_queue_players_broadcast()


# --- oyuncular ---

func _add_player(peer_id: int, player_name: String) -> void:
	var slot: int = 0
	while _slots.values().has(slot):
		slot += 1
	_slots[peer_id] = slot
	var colors: Array[Color] = ThemeTokens.PLAYER_COLORS
	_players[peer_id] = {"name": player_name, "color": colors[slot % colors.size()]}


func _broadcast_players() -> void:
	_to_all(&"_rpc_players", [_players.duplicate(true)])


## Kare sonunda tek yayın (poll içinde gönderim yok; aynı karedeki ad değişiklikleri birleşir).
func _queue_players_broadcast() -> void:
	if _players_broadcast_queued:
		return
	_players_broadcast_queued = true
	_flush_players_broadcast.call_deferred()


func _flush_players_broadcast() -> void:
	_players_broadcast_queued = false
	if _has_host_authority():
		_broadcast_players()


func _set_team_cash(value: int) -> void:
	if value == _team_cash:
		return
	_team_cash = value
	team_cash_changed.emit(value)


func _spawn_player(peer_id: int) -> void:
	if _spawner == null or not _spawner.is_inside_tree():
		return
	if player_scene == null:
		if not _warned_no_player_scene:
			_warned_no_player_scene = true
			push_error("Game: player_scene yok; oyuncu üretilemedi (%s)" % DEFAULT_PLAYER_SCENE)
		return
	var root: Node = _players_root()
	if root == null or root.has_node(NodePath(str(peer_id))):
		return
	_spawner.spawn({"id": peer_id, "pos": _spawn_position(int(_slots.get(peer_id, 0)))})


## PlayerSpawner.spawn_function: host'ta spawn() içinde, istemcilerde spawn paketi gelince çalışır.
func _spawn_player_node(data: Variant) -> Node:
	var d: Dictionary = data if typeof(data) == TYPE_DICTIONARY else {}
	var peer_id: int = int(d["id"]) if typeof(d.get("id")) == TYPE_INT else 0
	var node: Node = null
	if player_scene != null:
		node = player_scene.instantiate()
	else:
		push_error("Game: player_scene yok; yer tutucu düğüm üretildi")
		node = Node2D.new()
	node.name = str(peer_id)
	node.set_multiplayer_authority(peer_id, true)
	if node is Node2D and typeof(d.get("pos")) == TYPE_VECTOR2:
		(node as Node2D).position = d["pos"]
	return node


func _despawn_player(peer_id: int) -> void:
	var root: Node = _players_root()
	if root == null:
		return
	var node: Node = root.get_node_or_null(NodePath(str(peer_id)))
	if node != null:
		root.remove_child(node)
		node.queue_free()


func _despawn_all_players() -> void:
	var root: Node = _players_root()
	if root == null:
		return
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()


func _has_remote_players() -> bool:
	var root: Node = _players_root()
	if root == null:
		return false
	for child: Node in root.get_children():
		if str(child.name) != str(Net.local_peer_id()):
			return true
	return false


func _spawn_position(slot: int) -> Vector2:
	var root: Node2D = _players_root() as Node2D
	var points: Node = _level.get_node_or_null("SpawnPoints") if _level != null else null
	var markers: Array[Node2D] = []
	if points != null:
		for child: Node in points.get_children():
			if child is Node2D:
				markers.append(child as Node2D)
	if markers.is_empty() or root == null:
		return Vector2(32.0 * slot, 0.0)
	return root.to_local(markers[slot % markers.size()].global_position)


func _player_positions() -> Dictionary:
	var out: Dictionary = {}
	var root: Node = _players_root()
	if root != null:
		for child: Node in root.get_children():
			if child is Node2D and str(child.name).is_valid_int():
				out[str(child.name).to_int()] = (child as Node2D).position
	return out


func _players_root() -> Node:
	return _level.get_node_or_null("Players") if _level != null else null


func _on_player_node_added(node: Node) -> void:
	var local_id: int = Net.local_peer_id()
	if local_id != 0 and str(node.name) == str(local_id):
		local_player_changed.emit(node)
		return
	# Uzak oyuncu: eşitleyicisinden ilk veri gelince konum yetiştirmesi bu düğüm için durur.
	for found: Node in node.find_children("*", "MultiplayerSynchronizer", true, false):
		var sync: MultiplayerSynchronizer = found as MultiplayerSynchronizer
		sync.synchronized.connect(_mark_synced.bind(node), CONNECT_ONE_SHOT)
		sync.delta_synchronized.connect(_mark_synced.bind(node), CONNECT_ONE_SHOT)


func _on_player_node_removed(node: Node) -> void:
	if Net.local_peer_id() != 0 and str(node.name) == str(Net.local_peer_id()):
		local_player_changed.emit(null)


func _mark_synced(node: Node) -> void:
	if is_instance_valid(node):
		node.set_meta(_SYNCED_META, true)


func _start_catchup(peer_id: int) -> void:
	_catchup[peer_id] = Time.get_ticks_msec() + int(CATCHUP_SEC * 1000.0)


## Host: konum yetiştirmesi süren peer'lara CATCHUP_INTERVAL_SEC'te bir güncel konumları yollar.
func _send_catchup(delta: float) -> void:
	if _catchup.is_empty():
		return
	if not Net.is_host():
		_catchup.clear()
		return
	_catchup_elapsed += delta
	if _catchup_elapsed < CATCHUP_INTERVAL_SEC:
		return
	_catchup_elapsed = 0.0
	var now: int = Time.get_ticks_msec()
	var peers: PackedInt32Array = multiplayer.get_peers()
	var positions: Dictionary = _player_positions()
	for peer_id: int in _catchup.keys():
		if now > int(_catchup[peer_id]) or not peers.has(peer_id):
			_catchup.erase(peer_id)
		elif not positions.is_empty():
			_rpc_catchup_positions.rpc_id(peer_id, positions)


## İstemci: host'un bildiği konumları, eşitleyicisinden henüz veri gelmemiş uzak oyunculara uygular.
func _apply_catchup(positions: Dictionary) -> void:
	var root: Node = _players_root()
	if root == null:
		return
	var local_id: int = Net.local_peer_id()
	for key: Variant in positions:
		var pos: Variant = positions[key]
		if typeof(key) != TYPE_INT or typeof(pos) != TYPE_VECTOR2 or int(key) == local_id:
			continue
		var node: Node2D = root.get_node_or_null(NodePath(str(key))) as Node2D
		if node != null and not node.has_meta(_SYNCED_META) and node.get_multiplayer_authority() != local_id:
			node.position = pos


# --- seviye ---

func _load_level_local(level_path: String) -> bool:
	var scene: PackedScene = load(level_path) as PackedScene
	if scene == null:
		push_error("Game: seviye yüklenemedi: " + level_path)
		return false
	var level: Node = scene.instantiate()
	level.name = LEVEL_NODE_NAME
	var players_root: Node = level.get_node_or_null("Players")
	if players_root == null:
		push_warning("Game: seviyede Players düğümü yok (S4); ekleniyor: " + level_path)
		players_root = Node2D.new()
		players_root.name = "Players"
		level.add_child(players_root)
	var spawner: MultiplayerSpawner = MultiplayerSpawner.new()
	spawner.name = SPAWNER_NODE_NAME
	spawner.spawn_function = _spawn_player_node
	spawner.spawn_path = NodePath("../Players")
	level.add_child(spawner)
	players_root.child_entered_tree.connect(_on_player_node_added)
	players_root.child_exiting_tree.connect(_on_player_node_removed)
	_world.add_child(level)
	_level = level
	_level_path = level_path
	_spawner = spawner
	_attach_hud(level)
	level_loaded.emit(level)
	return true


func _unload_level() -> void:
	if _level == null:
		return
	var level: Node = _level
	var had_local: bool = local_player() != null
	var players_root: Node = _players_root()
	if players_root != null:
		players_root.child_entered_tree.disconnect(_on_player_node_added)
		players_root.child_exiting_tree.disconnect(_on_player_node_removed)
	_level = null
	_level_path = ""
	_spawner = null
	_world.remove_child(level)
	level.queue_free()
	if had_local:
		local_player_changed.emit(null)


func _attach_hud(level: Node) -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(HUD_SCENE):
		return
	var scene: PackedScene = load(HUD_SCENE) as PackedScene
	if scene == null:
		return
	var hud: Node = scene.instantiate()
	if hud is CanvasLayer:
		level.add_child(hud)
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = HUD_LAYER
	layer.add_child(hud)
	level.add_child(layer)


static func _is_level_path(path: String) -> bool:
	return path.begins_with("res://") and not path.contains("..")


# --- döküm yardımcıları ---

func _dump_players() -> Dictionary:
	var out: Dictionary = {}
	var root: Node = _players_root()
	for peer_id: int in _players:
		var entry: Dictionary = _players[peer_id]
		var pos: Variant = null
		var node: Node2D = root.get_node_or_null(NodePath(str(peer_id))) as Node2D if root != null else null
		if node != null:
			pos = [node.position.x, node.position.y]
		out[str(peer_id)] = {"name": entry["name"], "color": to_json_value(entry["color"]), "pos": pos}
	return out


func _player_node_ids() -> Array[int]:
	var out: Array[int] = []
	var root: Node = _players_root()
	if root != null:
		for child: Node in root.get_children():
			if str(child.name).is_valid_int():
				out.append(str(child.name).to_int())
	out.sort()
	return out


func _dump_pings() -> Dictionary:
	var out: Dictionary = {}
	for peer_id: int in _peer_ids:
		var ping: int = Net.get_ping_ms(peer_id)
		if ping >= 0:
			out[str(peer_id)] = ping
	return out


## Görünmeyen karakterleri atar, MAX_NAME_LENGTH'e kırpar. Uzun girdide yalnız baştaki
## MAX_NAME_LENGTH x 4 karakter işlenir (ağdan gelen dev ad host'u dondurmasın).
static func _sanitize_name(value: Variant) -> String:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return ""
	var text: String = str(value).left(MAX_NAME_LENGTH * 4).strip_edges()
	var out: String = ""
	for ch: String in text:
		if out.length() >= MAX_NAME_LENGTH:
			break
		var code: int = ch.unicode_at(0)
		if code >= 32 and code != 127:
			out += ch
	return out.strip_edges()
