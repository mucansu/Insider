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
## - Seviyeler her peer'da `/root/Game/World/Level` yoluna elle yüklenir; kökü `Level` olmalıdır (S4) ve seviye
##   düğümlerine yalnız Level API'siyle erişilir (ad dizesiyle gezinti yok, KR-018). Kökün altına `PlayerSpawner`
##   (MultiplayerSpawner, spawn_path = Level.players_root(), özel spawn_function: player_scene örneği,
##   ad str(peer_id), yetki peer_id) kurulur.
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
## Uyarı kademesi (S3 eki, KR-021; US-008): host yetkili `alert_level` (0-5; anlamı mekâna bağlı, geçişleri mekânın
## uyarı yöneticisi seçer — bakkalda NPCs/StoreAlert) ve polis sayacı `alert_timer_left` (yoksa −1). Host
## `set_alert_level` / `set_alert_timer` çağırır, değer herkese güvenilir RPC ile gider (geç katılana kabulde);
## sayaç her peer'da yerelde azalır. Seviye yüklenince ve oturum bitince 0 / −1'e döner. Dökümde "alert":
## {"level", "timer_left", "history"} (history = bu seviyede görülen kademe dizisi; I4 denetimi).

signal players_changed()
signal local_player_changed(player: Node)
signal team_cash_changed(value: int)
signal level_loaded(level: Node)
## Herkeste yayılır (ör. &"police_called").
signal session_event(kind: StringName, data: Dictionary)
## S3 eki: uyarı kademesi değişti (her peer'da).
signal alert_level_changed(level: int)

const DEFAULT_LEVEL := "res://levels/store_a.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
const DEFAULT_PLAYER_SCENE := "res://entities/player/player.tscn"
## El sıkışma protokolü sürümü; uyuşmayan peer reddedilir. Kablo (RPC/eşitleyici/handshake) düzeni değişince artar
## (mimari.md S2). 2: US-011b hareket eşitleyicisine 8 bit bakış açısı + görüş kipi/maruziyet RPC'leri.
const PROTOCOL_VERSION := 2
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
	"ping_ms", "alert",
	"vision",  # US-011b görüş eki (S3 eki; döküm aşağıda `_vision_dump`)
]
## Uyarı geçmişinde tutulan en fazla kademe.
const MAX_ALERT_HISTORY := 64
const _SYNCED_META := &"_game_synced"

## Varsayılanı res://entities/player/player.tscn (dosya yoksa null); testler değiştirebilir.
var player_scene: PackedScene

var _world: Node
var _level: Level = null
var _level_path: String = ""
var _spawner: MultiplayerSpawner = null
## peer_id -> {"name": String, "slot": int}; slot = katılım yuvası (doğma noktası sırası; görsel taraf rengi
## slot'tan seçer, Game renk bilmez — mimari.md §6). Host atar, ayrılanın yuvası yeniden kullanılır.
var _players: Dictionary = {}
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
var _alert_level: int = 0
## Polis sayacından kalan (sn); −1 = sayaç yok.
var _alert_timer: float = -1.0
var _alert_history: Array[int] = [0]


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
	if _alert_timer > 0.0:
		_alert_timer = maxf(_alert_timer - delta, 0.0)


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


## peer_id -> {"name": String, "slot": int}
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


## S3 eki: şimdiki uyarı kademesi (0-5).
func alert_level() -> int:
	return _alert_level


## S3 eki: polis sayacından kalan (sn); sayaç yoksa −1.
func alert_timer_left() -> float:
	return _alert_timer


## Yalnız host: uyarı kademesini herkese yayınlar (sayaç korunur). Geçiş kuralı mekânın yöneticisindedir.
func set_alert_level(level: int) -> void:
	if not _has_host_authority():
		push_warning("Game.set_alert_level: yalnız host çağırabilir")
		return
	if level == _alert_level:
		return
	_to_all(&"_rpc_alert", [clampi(level, 0, 5), _alert_timer])


## Yalnız host: polis sayacını kurar (sn; < 0 kaldırır), herkese yayınlar.
func set_alert_timer(seconds: float) -> void:
	if not _has_host_authority():
		push_warning("Game.set_alert_timer: yalnız host çağırabilir")
		return
	_to_all(&"_rpc_alert", [_alert_level, seconds if seconds >= 0.0 else -1.0])


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
		"alert": {"level": _alert_level, "timer_left": _alert_timer, "history": _alert_history.duplicate()},
		"vision": to_json_value(_vision_dump()),  # US-011b
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
		_add_player(1, _local_name)
		players_changed.emit()


func _end_session() -> void:
	_session_peer = null
	_pending_level = ""
	_freeze_acks.clear()
	_catchup.clear()
	_unload_level()
	_players.clear()
	_peer_ids.clear()
	_auth_names.clear()
	_events.clear()
	_set_team_cash(0)
	_apply_alert(0, -1.0, true)
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
	_rpc_alert.rpc_id(peer_id, _alert_level, _alert_timer)
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
		var slot: int = maxi(0, int(e["slot"])) if typeof(e.get("slot")) == TYPE_INT else 0
		clean[key] = {"name": _sanitize_name(e.get("name", "")), "slot": slot}
	_players = clean
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_team_cash(value: int) -> void:
	_set_team_cash(value)


@rpc("authority", "call_local", "reliable")
func _rpc_alert(level: int, timer: float) -> void:
	_apply_alert(level, timer, false)


func _apply_alert(level: int, timer: float, reset_history: bool) -> void:
	_alert_timer = timer
	if reset_history:
		_alert_history = [level]
	if level == _alert_level:
		return
	_alert_level = level
	if not reset_history:
		_alert_history.append(level)
		if _alert_history.size() > MAX_ALERT_HISTORY:
			_alert_history.pop_front()
	alert_level_changed.emit(level)


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
	var root: Node2D = _players_root()
	if root != null:
		var me: int = Net.local_peer_id()
		for node: Node in root.find_children("*", "MultiplayerSynchronizer", true, false):
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

## Boştaki en küçük yuvayı verir.
func _add_player(peer_id: int, player_name: String) -> void:
	var used: Array[int] = []
	for entry: Dictionary in _players.values():
		used.append(int(entry["slot"]))
	var slot: int = 0
	while used.has(slot):
		slot += 1
	_players[peer_id] = {"name": player_name, "slot": slot}


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
	var slot: int = int((_players.get(peer_id, {}) as Dictionary).get("slot", 0))
	_spawner.spawn({"id": peer_id, "pos": _spawn_position(slot)})


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


## Yuvanın doğma noktası (Players koordinatında); seviyede doğma noktası yoksa yan yana dizer.
func _spawn_position(slot: int) -> Vector2:
	if _level == null or _level.spawn_count() == 0:
		return Vector2(32.0 * slot, 0.0)
	return _level.spawn_position(slot)


func _player_positions() -> Dictionary:
	var out: Dictionary = {}
	var root: Node = _players_root()
	if root != null:
		for child: Node in root.get_children():
			if child is Node2D and str(child.name).is_valid_int():
				out[str(child.name).to_int()] = (child as Node2D).position
	return out


func _players_root() -> Node2D:
	return _level.players_root() if _level != null else null


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
	var node: Node = scene.instantiate()
	var level: Level = node as Level
	var players_root: Node2D = level.players_root() if level != null else null
	if players_root == null:
		push_error("Game: seviye kökü Level değil ya da Players yok (S4): " + level_path)
		if node != null:
			node.free()
		return false
	level.name = LEVEL_NODE_NAME
	var spawner: MultiplayerSpawner = MultiplayerSpawner.new()
	spawner.name = SPAWNER_NODE_NAME
	spawner.spawn_function = _spawn_player_node
	level.add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players_root)
	players_root.child_entered_tree.connect(_on_player_node_added)
	players_root.child_exiting_tree.connect(_on_player_node_removed)
	_apply_alert(0, -1.0, true)
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
		out[str(peer_id)] = {"name": entry["name"], "slot": entry["slot"], "pos": pos}
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


# =====================================================================================================================
# US-012 — Soygun sonucu (S3 eki, KR-021: heist_finished, heist_result, request_restart, venue_tier).
# Bu bölüm yukarıdaki koda dokunmaz: bağlantılar ve fizik adımı `_notification`'dan (ENTER_TREE, PHYSICS_PROCESS).
# Kurallar ve sayaçlar düğümsüz `HeistRules` / `HeistRules.Tracker`'da (core/heist_rules.gd); burada yalnız
# sahne bağlama: oyuncu görünümü (kaçış bölgesi `Level.zone(&"EscapeZone")`, yakalanma/tutulma oyuncu
# API'sinden okunur, taşınan çanta değeri), kasa nakdinin kimin olduğu (bileşenin `completed` sinyali), sonuç
# yayını; iş bitince ganimet etkileşimleri host'ta kilitlenir (yeni istek reddi, geç biten kasanın nakdi geri alınır).
# - İş yalnız `EscapeZone` taşıyan seviyelerde izlenir; host karar verir (S2), sonuç herkese RPC ile gider ve
#   geç katılana kabulde yollanır. Bitişte ekip nakdi = iş öncesi + ödeme (kasadan anında giren nakit ödemeyle
#   değiştirilir). Seviye kalkınca (yeniden başlatma, oturum sonu) sonuç sıfırlanır.
# - US-008 bağlanma noktaları (yoksa atlanır): Game sinyalleri `alert_level_changed(level)`, `police_arrived()`,
#   `player_caught(peer_id[, by])`; `alert_level()` (her adımda okunur); oyuncu `is_caught()` / `is_held()`
#   (HeistRules.CAUGHT_METHODS / HELD_METHODS). Aynı olaylar session_event olarak da kabul edilir:
#   &"alert_level" {"level"}, &"police_arrived", &"player_caught" {"peer", "by"?: &"chaser"}, &"shout".
# - Test kancası (yalnız otomasyon + host, ağ senaryosu): `--bot` dosyasındaki {"t": SN, "heist": "<olay>",
#   "data": {...}} adımları — "alert" {"level"}, "police", "caught" {"slot" | "all"}, "shout", "restart" —
#   yukarıdaki session_event'lerle (ve request_restart ile) uygulanır; US-008 gelene dek sahip olaylarının
#   yerine geçer. Zaman, bot zaman çizelgesi gibi ilk yerel oyuncunun ilk fizik adımından sayılır.
# Döküm (S6 "heist", yalnız --dump): {"active", "max_alert", "elapsed", "result", "history"}.
# =====================================================================================================================

signal heist_finished(result: Dictionary)

const HEIST_DUMP_KEY := "heist"
const HEIST_ESCAPE_ZONE := &"EscapeZone"
## Mekân kademesi (Faz 2'de tek mekân: bakkal T1).
const HEIST_VENUE_TIER := 1
const HEIST_SIG_ALERT := &"alert_level_changed"
const HEIST_SIG_POLICE := &"police_arrived"
const HEIST_SIG_CAUGHT := &"player_caught"
const HEIST_EVENT_ALERT := &"alert_level"
const HEIST_EVENT_POLICE := &"police_arrived"
const HEIST_EVENT_CAUGHT := &"player_caught"
const HEIST_EVENT_SHOUT := &"shout"
const HEIST_HOOK_KEY := "heist"
const HEIST_HISTORY_MAX := 16
## Etkileşim bileşenlerinin grubu: Interactable.GROUP ile aynı değer (= PhysicsLayers.INTERACTABLES_GROUP, IS-037;
## birleştirmede ona bağlanır). Autoload entities/ sınıflarına derlemede bağlanmasın diye (§6) bileşenlere
## yalnız ördek tiplemeyle (has_signal/has_method/"x" in) dokunulur.
const HEIST_INTERACTABLES_GROUP := PhysicsLayers.INTERACTABLES_GROUP

var _heist: HeistRules.Tracker = null
var _heist_result: Dictionary = {}
var _heist_history: Array[Dictionary] = []
var _heist_hook_steps: Array[Dictionary] = []
var _heist_hook_next: int = 0
var _heist_hook_t: float = 0.0
var _heist_hook_started: bool = false
## Bağlanan isteğe bağlı sinyaller (US-008; adı -> true): her seviye yüklemesinde yeniden denenir.
var _heist_bound: Dictionary = {}
## request_restart: ekip nakdi yeni seviye yüklenince sıfırlanır.
var _heist_reset_cash: bool = false


## Bitmiş işin sonucu (S3 eki; geç katılan da alır); iş sürüyorsa ya da yoksa boş.
func heist_result() -> Dictionary:
	return _heist_result.duplicate(true)


## Yalnız host: aynı seviyeyi yeniden yükler (Game seviye yolu); prop'lar seviyeyle sıfırlanır, ekip nakdi yeni
## seviye yüklendikten sonra sıfırlanır (Faz 2'de kalıcı ekonomi yok).
func request_restart() -> void:
	if not _has_host_authority():
		push_warning("Game.request_restart: yalnız host çağırabilir")
		return
	if _level_path.is_empty():
		push_warning("Game.request_restart: yüklü seviye yok")
		return
	_heist_reset_cash = true
	start_level(_level_path)


## Mekân kademesi (uyarı merdiveni metinleri `ALERT_T<k>_<level>`).
func venue_tier() -> int:
	return HEIST_VENUE_TIER


## Bölümün tek motor girişi: `_enter_tree`/`_physics_process` tanımlanmaz ki başka bölümler (US-008) kendi
## sanal yöntemlerini çakışmadan ekleyebilsin.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_heist_setup()
			_vision_setup()  # US-011b
		NOTIFICATION_PHYSICS_PROCESS:
			_heist_physics(get_physics_process_delta_time())
			_vision_physics(get_physics_process_delta_time())  # US-011b


func _heist_setup() -> void:
	set_physics_process(true)
	_heist_bind_optional()
	if level_loaded.is_connected(_heist_on_level_loaded):
		return
	level_loaded.connect(_heist_on_level_loaded)
	session_event.connect(_heist_on_session_event)
	Net.peer_connected.connect(_heist_on_peer_connected)
	if not Args.dump_path.is_empty():
		register_dump_provider(HEIST_DUMP_KEY, _heist_dump)
	_heist_load_hook()


func _heist_physics(delta: float) -> void:
	_heist_run_hook(delta)
	if _heist == null or _heist.finished or _level == null or not _has_host_authority():
		return
	var views: Dictionary = _heist_views()
	if views.is_empty():
		return
	if has_method(&"alert_level"):
		_heist.set_alert(int(call(&"alert_level")))
	_heist.observe(views, delta)
	_heist_drop_caught_bags()
	var decision: StringName = _heist.evaluate(views)
	if decision != HeistRules.DECISION_NONE:
		_heist_finish(decision, views)


## US-008 sinyalleri (yoksa atlanır; her seviye yüklemesinde yeniden denenir): uyarı (1 arg), polis (0),
## yakalanma (1-2 arg: peer_id[, by]); fazla argüman atılır (HeistRules.adapt_callable).
func _heist_bind_optional() -> void:
	_heist_bind(HEIST_SIG_ALERT, _heist_on_alert, 1, 1)
	_heist_bind(HEIST_SIG_POLICE, _heist_on_police, 0, 0)
	_heist_bind(HEIST_SIG_CAUGHT, _heist_on_caught, 1, 2)


func _heist_bind(signal_name: StringName, target: Callable, min_args: int, max_args: int) -> void:
	if _heist_bound.has(signal_name) or not has_signal(signal_name):
		return
	_heist_bound[signal_name] = true
	var argc: int = -1
	for s: Dictionary in get_signal_list():
		if StringName(str(s["name"])) == signal_name:
			argc = (s["args"] as Array).size()
	var adapted: Callable = HeistRules.adapt_callable(target, argc, min_args, max_args)
	if not adapted.is_valid():
		push_warning("Game: %s sinyali beklenen argümanı taşımıyor; soygun sonucu bağlanmadı" % signal_name)
		return
	connect(signal_name, adapted)


func _heist_on_level_loaded(level: Node) -> void:
	_heist = null
	_heist_bind_optional()
	if _heist_reset_cash and _has_host_authority():
		_heist_reset_cash = false
		add_team_cash(-_team_cash)
	var lvl: Level = level as Level
	if lvl == null or lvl.zone(HEIST_ESCAPE_ZONE) == null:
		return
	_heist = HeistRules.Tracker.new()
	if not level.tree_exiting.is_connected(_heist_on_level_exiting):
		level.tree_exiting.connect(_heist_on_level_exiting, CONNECT_ONE_SHOT)
	for node: Node in get_tree().get_nodes_in_group(HEIST_INTERACTABLES_GROUP):
		var prop: Node = node.get_parent()
		if not level.is_ancestor_of(node) or prop == null or prop.is_in_group(HeistRules.BAG_GROUP) \
				or not node.has_signal(&"completed"):
			continue
		var def: Resource = prop.get(&"def") as Resource
		var cash: int = int(def.get(&"cash_value")) if def != null and "cash_value" in def else 0
		if cash <= 0:
			continue
		node.connect(&"completed", _heist_on_cash_taken.bind(cash))
		# İş bitince host yeni ganimet etkileşimini reddeder (bileşenin kendi engeli yoksa; çanta kendi kilitlenir).
		if "start_blocker" in node and not (node.get(&"start_blocker") as Callable).is_valid():
			node.set(&"start_blocker", _heist_loot_locked)
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		if level.is_ancestor_of(bag) and bag.has_signal(&"taken"):
			bag.connect(&"taken", _heist_on_bag_taken)


## Seviye kalkarken (yeniden başlatma, seviye değişimi, oturum sonu): iş ve sonucu sıfırlanır. Yeni seviyenin
## HUD'u eski sonucu görmesin diye yükleme öncesinde.
func _heist_on_level_exiting() -> void:
	_heist = null
	_heist_result = {}


## Kasa nakdi kimin (prop kendi işleyicisinde ekip nakdine ekledi). Sonuçtan sonra biten (iş bitmeden başlamış)
## boşaltmanın nakdi geri alınır: ödeme kesinleşti.
func _heist_on_cash_taken(peer_id: int, cash: int) -> void:
	if _heist == null:
		return
	if not _heist.finished:
		_heist.add_cash(peer_id, cash)
	elif _has_host_authority():
		add_team_cash(-cash)


func _heist_loot_locked() -> bool:
	return _heist != null and _heist.finished


func _heist_on_bag_taken(peer_id: int) -> void:
	if _heist != null and not _heist.finished:
		_heist.note_bag(peer_id)


func _heist_on_alert(level: int) -> void:
	if _heist != null and _has_host_authority():
		_heist.set_alert(level)


## Polis geldi (US-008 sayacı): kaçış bölgesi dışındaki herkes yakalanır; karar bir sonraki adımda.
func _heist_on_police() -> void:
	if _heist == null or _heist.finished or not _has_host_authority():
		return
	_heist.arrive_police(_heist_views())


func _heist_on_caught(peer_id: int, by: StringName = &"") -> void:
	_heist_mark_caught(peer_id, by)


func _heist_mark_caught(peer_id: int, cause: StringName) -> void:
	if _heist != null and not _heist.finished and _has_host_authority():
		_heist.mark_caught(peer_id, cause)


func _heist_on_session_event(kind: StringName, data: Dictionary) -> void:
	if _heist == null or _heist.finished or not _has_host_authority():
		return
	match kind:
		HEIST_EVENT_ALERT:
			_heist.set_alert(int(data.get("level", 0)))
		HEIST_EVENT_POLICE:
			_heist_on_police()
		HEIST_EVENT_CAUGHT:
			_heist_mark_caught(int(data.get("peer", 0)), StringName(str(data.get("by", ""))))
		HEIST_EVENT_SHOUT:
			_heist.note_shout()


## Host: oyuncu görünümü (HeistRules.Tracker): peer -> {"in_zone", "caught", "held", "bag_value", "sprinting"}.
func _heist_views() -> Dictionary:
	var out: Dictionary = {}
	var root: Node2D = _players_root()
	if root == null or _level == null:
		return out
	var zone: Area2D = _level.zone(HEIST_ESCAPE_ZONE)
	var bag_values: Dictionary = {}
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		var carrier: int = int(bag.get(&"carrier"))
		if carrier != 0:
			bag_values[carrier] = int(bag_values.get(carrier, 0)) + int(bag.get(&"value"))
	for child: Node in root.get_children():
		var node: Node2D = child as Node2D
		if node == null or not str(node.name).is_valid_int():
			continue
		var peer_id: int = str(node.name).to_int()
		var pos: Vector2 = node.global_position
		if node.has_method(&"interaction_position"):
			pos = node.call(&"interaction_position")
		out[peer_id] = {
			"in_zone": _heist_in_zone(zone, pos),
			"caught": HeistRules.node_flag(node, HeistRules.CAUGHT_METHODS),
			"held": HeistRules.node_flag(node, HeistRules.HELD_METHODS),
			"bag_value": int(bag_values.get(peer_id, 0)),
			"sprinting": HeistRules.node_flag(node, HeistRules.SPRINT_METHODS),
		}
	return out


## Nokta (global) bölgenin şekillerinden birinin içinde mi.
static func _heist_in_zone(zone: Area2D, point: Vector2) -> bool:
	if zone == null:
		return false
	for child: Node in zone.get_children():
		var holder: CollisionShape2D = child as CollisionShape2D
		if holder == null or holder.disabled or holder.shape == null:
			continue
		var local: Vector2 = holder.global_transform.affine_inverse() * point
		var rect: RectangleShape2D = holder.shape as RectangleShape2D
		var circle: CircleShape2D = holder.shape as CircleShape2D
		if rect != null:
			if Rect2(-rect.size * 0.5, rect.size).has_point(local):
				return true
		elif circle != null:
			if local.length() <= circle.radius:
				return true
		elif holder.shape.get_rect().has_point(local):
			return true
	return false


## Yakalanan taşıyıcının çantası düşer (ekip arkadaşı alabilir).
func _heist_drop_caught_bags() -> void:
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		var carrier: int = int(bag.get(&"carrier"))
		if carrier != 0 and _heist.is_caught(carrier) and bag.has_method(&"host_drop"):
			bag.call(&"host_drop")


func _heist_finish(decision: StringName, views: Dictionary) -> void:
	_heist.finished = true
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		if bag.has_method(&"host_lock"):
			bag.call(&"host_lock")
	var result: Dictionary = _heist.build_result(decision, views, _players)
	var cash_delta: int = maxi(int(result["payout"]) - _heist.cash_grabbed(), -_team_cash)
	if cash_delta != 0:
		add_team_cash(cash_delta)
	_to_all(&"_rpc_heist_finished", [result])


@rpc("authority", "call_local", "reliable")
func _rpc_heist_finished(result: Dictionary) -> void:
	_heist_result = result.duplicate(true)
	_heist_history.append(_heist_result.duplicate(true))
	if _heist_history.size() > HEIST_HISTORY_MAX:
		_heist_history.pop_front()
	if _heist != null:
		_heist.finished = true
	heist_finished.emit(heist_result())


## Geç katılan: iş bittiyse sonuç kabulden sonra (kare sonunda) yollanır.
func _heist_on_peer_connected(peer_id: int) -> void:
	if Net.is_host() and not _heist_result.is_empty():
		_heist_send_result.call_deferred(peer_id)


func _heist_send_result(peer_id: int) -> void:
	if Net.is_host() and not _heist_result.is_empty() and multiplayer.get_peers().has(peer_id):
		_rpc_heist_finished.rpc_id(peer_id, _heist_result)


func _heist_dump() -> Dictionary:
	return {
		"active": _heist != null and not _heist.finished,
		"max_alert": _heist.max_alert if _heist != null else 0,
		"elapsed": snappedf(_heist.elapsed, 0.01) if _heist != null else 0.0,
		"result": _heist_result,
		"history": _heist_history,
	}


# --- test kancası (yalnız otomasyon + host) ---

func _heist_load_hook() -> void:
	_heist_hook_steps.clear()
	if not Args.is_automated() or Args.bot_path.is_empty():
		return
	for step: Dictionary in Args.bot_steps():
		if step.has(HEIST_HOOK_KEY):
			_heist_hook_steps.append(step)


func _heist_run_hook(delta: float) -> void:
	if _heist_hook_next >= _heist_hook_steps.size() or not Net.is_host():
		return
	if not _heist_hook_started:
		if local_player() == null:
			return
		_heist_hook_started = true
	_heist_hook_t += delta
	while _heist_hook_next < _heist_hook_steps.size() \
			and float(_heist_hook_steps[_heist_hook_next]["t"]) <= _heist_hook_t:
		_heist_apply_hook(_heist_hook_steps[_heist_hook_next])
		_heist_hook_next += 1


func _heist_apply_hook(step: Dictionary) -> void:
	var data: Dictionary = step.get("data", {}) if typeof(step.get("data")) == TYPE_DICTIONARY else {}
	match str(step[HEIST_HOOK_KEY]):
		"alert":
			raise_session_event(HEIST_EVENT_ALERT, {"level": int(data.get("level", 0))})
		"police":
			raise_session_event(HEIST_EVENT_POLICE)
		"shout":
			raise_session_event(HEIST_EVENT_SHOUT)
		"caught":
			var by: String = str(data.get("by", ""))
			for peer_id: int in _players:
				var slot: int = int((_players[peer_id] as Dictionary)["slot"])
				if bool(data.get("all", false)) or (data.has("slot") and int(data["slot"]) == slot):
					raise_session_event(HEIST_EVENT_CAUGHT, {"peer": peer_id, "by": by})
		"restart":
			request_restart()
		_:
			push_warning("Game: bilinmeyen soygun test adımı: %s" % str(step[HEIST_HOOK_KEY]))


# =====================================================================================================================
# US-011b — Görüş eki (mimari.md S3 eki "Görüş ekleri", KR-022/KR-023; GDD §6.5). Bu bölüm yukarıdaki koda
# dokunmaz: girişleri `_notification` (ENTER_TREE, PHYSICS_PROCESS) ve sinyaller; kurallar düğümsüz
# `VisionRules.Session`'da (core/vision_rules.gd).
# - Görüş kipi (`vision_mode`, 0 çevresel 360° / 1 yönlü): host'un oyun kuralı. Varsayılan data/vision_tuning.tres
#   `default_mode`; `--vision-mode=` (Args, US-011d) ezer; ana menü (US-011c) host açılınca `set_vision_mode` ile
#   seçer. Yalnız host, seviye başlamadan; değer istemcilere güvenilir RPC ile gider (geç katılana kabulde, oyuncusu
#   doğmadan önce), herkes aynı. İstemcide `set_vision_mode` etkisizdir (uyarı).
# - Sis bağlama: yerel oyuncu doğunca (`local_player_changed`; seviye değişimi ve geç katılan dahil) seviyenin
#   sisi kurulur; sıra: katman gözlemcisiz (`attach_fog(null)`) → oturum kipi + yerel oyuncunun gerçek `look_dir`'i
#   → `follow(oyuncu)` (ilk hesap). Kip sonradan çoğaltılırsa da kip + bakış önce, hafıza silinip hemen yeniden
#   hesap. Her fizik adımında sise yerel oyuncunun `look_dir`'i verilir. Peer ayrılınca maruziyet kaydı ve geçmişi
#   silinir. Yerel oyuncu yoksa (menü, oyuncusuz test) sis kurulmaz. Görünürlük kararı istemcide (host da kendi
#   yerel görüşüyle çizer); host hiçbir görünürlük kararı vermez.
# - Maruziyet (`player_exposure`, 0 gizli / 1 görünür / 2 görüldü): yalnız host, 10 Hz, NPC'lerin algı/şüphe
#   özetinden (duck typing: `last_observations()` + `value_of(peer)` taşıyan bileşenler — Suspicion): 1 = bir
#   gözlemcinin konisinde ve görüş hattında (son gözlem: bant ≠ NONE ∧ görüş hattı açık), 2 = şüphesi ≥ 30.
#   Değişince tam tablo herkese güvenilir RPC (call_local); `player_exposure_changed` her peer'da. Seviye
#   değişiminde ve oturum sonunda (yerel oyuncu kalkınca) tablo boşalır; host bir sonraki turda yeniden yayar.
# - Test kancası (yalnız otomasyon, `--vision-mode` verilmemişse): `--bot` dosyasındaki {"t": 0, "vision_mode":
#   "directional"} adımı açılışta `--vision-mode` gibi uygulanır (net_smoke süreç argümanı veremiyor; host'unki
#   geçerlidir, istemcilere çoğaltılır).
# Döküm (S6 taban anahtar "vision"): {mode, fog, visible_tiles, peripheral_tiles, memory_tiles, visible_npcs:[ad],
# look_deg, exposure:{peer: düzey}, exposure_history:{peer: [düzeyler]}, remote_look_deg:{peer: derece}}.
# =====================================================================================================================

signal player_exposure_changed(peer: int, level: int)

const VISION_HOOK_KEY := "vision_mode"

var _vision: VisionRules.Session = null
var _vision_elapsed: float = 0.0


## S3 eki: görüş kipi (0 çevresel 360°, 1 yönlü; VisionGrid.Mode).
func vision_mode() -> int:
	return _vision_session().mode()


## S3 eki: yalnız host, seviye başlamadan; istemcilere çoğaltılır. İstemcide ya da seviye yüklüyken etkisiz.
func set_vision_mode(mode: int) -> void:
	if not _has_host_authority():
		push_warning("Game.set_vision_mode: yalnız host çağırabilir")
		return
	if not _vision_session().set_mode(mode, true, _level != null):
		push_warning("Game.set_vision_mode: kip yalnız seviye başlamadan ve geçerli değerle seçilir (%d)" % mode)
		return
	if Net.is_online() and not multiplayer.get_peers().is_empty():
		_rpc_vision_mode.rpc(mode)


## S3 eki: oyuncunun maruziyeti (0 gizli, 1 görünür, 2 görüldü); host yazar, herkes okur.
func player_exposure(peer: int) -> int:
	return _vision_session().exposure(peer)


## S3 eki: oyuncunun dünya konumu (global); oyuncu düğümü yoksa INF.
func player_world_position(peer: int) -> Vector2:
	var root: Node2D = _players_root()
	var node: Node2D = root.get_node_or_null(NodePath(str(peer))) as Node2D if root != null else null
	if node == null or not node.is_inside_tree():
		return Vector2.INF
	return node.global_position


func _vision_session() -> VisionRules.Session:
	if _vision == null:
		_vision = VisionRules.Session.new(_vision_default_mode())
	return _vision


## Açılış kipi: --vision-mode > (otomasyonda) bot kancası > data/vision_tuning.tres.
func _vision_default_mode() -> int:
	if Args.vision_mode_given:
		return VisionGrid.mode_from_name(StringName(Args.vision_mode))
	if Args.is_automated():
		for step: Dictionary in Args.bot_steps():
			if step.has(VISION_HOOK_KEY) and float(step["t"]) <= 0.0:
				return VisionGrid.mode_from_name(StringName(str(step[VISION_HOOK_KEY])))
	var tuning: VisionTuning = load(VisionTuning.PATH) as VisionTuning
	return tuning.default_mode if tuning != null else VisionGrid.Mode.PERIPHERAL


func _vision_setup() -> void:
	_vision_session()
	if local_player_changed.is_connected(_vision_on_local_player):
		return
	local_player_changed.connect(_vision_on_local_player)
	Net.peer_connected.connect(_vision_on_peer_connected)
	Net.peer_disconnected.connect(_vision_on_peer_disconnected)


func _vision_physics(delta: float) -> void:
	var fog: Object = _vision_fog()
	var me: Node = local_player()
	if fog != null and me != null:
		var look: Variant = me.get(&"look_dir")
		if look is Vector2:
			fog.call(&"set_look_dir", look)
	if _level == null:
		_vision_clear_exposures()  # oturum sonu / seviye yok: tablo boşalır
		return
	if not _has_host_authority():
		return
	_vision_elapsed += delta
	if _vision_elapsed + 0.000001 < VisionRules.EXPOSURE_INTERVAL_SEC:
		return
	_vision_elapsed = 0.0
	var table: Dictionary = _vision_compute_exposure()
	if table != _vision_session().exposures():
		_to_all(&"_rpc_exposure", [table])


## Host: oyuncu başına maruziyet, NPC algı/şüphe bileşenlerinin özetinden (duck typing).
func _vision_compute_exposure() -> Dictionary:
	var out: Dictionary = {}
	for peer_id: int in _players:
		out[peer_id] = VisionRules.Exposure.HIDDEN
	var npcs: Node = _level.npcs_root() if _level != null else null
	if npcs == null or out.is_empty():
		return out
	for node: Node in npcs.find_children("*", "", true, false):
		if not (node.has_method(&"last_observations") and node.has_method(&"value_of")):
			continue
		var observations: Dictionary = node.call(&"last_observations")
		for peer_id: int in out:
			var obs: Object = observations.get(peer_id) as Object
			var in_view: bool = obs != null and int(obs.get(&"band")) != PerceptionRules.Band.NONE \
				and bool(obs.get(&"line_clear"))
			var level: int = VisionRules.exposure_level(in_view, float(node.call(&"value_of", peer_id)))
			out[peer_id] = VisionRules.combine(int(out[peer_id]), level)
	return out


@rpc("authority", "call_local", "reliable")
func _rpc_exposure(table: Dictionary) -> void:
	var clean: Dictionary = {}
	for key: Variant in table:
		if typeof(key) == TYPE_INT and typeof(table[key]) == TYPE_INT:
			clean[key] = table[key]
	var changed: Dictionary = _vision_session().apply(clean)
	for peer_id: int in changed:
		player_exposure_changed.emit(peer_id, int(changed[peer_id]))


@rpc("authority", "call_remote", "reliable")
func _rpc_vision_mode(mode: int) -> void:
	if _vision_session().apply_mode(mode):
		_vision_apply_fog_mode()


## Host: yeni kabul edilen peer'a kip ve maruziyet tablosu (spawn'dan önce, aynı güvenilir kanalda).
func _vision_on_peer_connected(peer_id: int) -> void:
	if not Net.is_host():
		return
	_rpc_vision_mode.rpc_id(peer_id, _vision_session().mode())
	_rpc_exposure.rpc_id(peer_id, _vision_session().exposures())


## Peer ayrıldı (her peer'da): maruziyeti ve geçmişi silinir. Ertelenir: host'ta oyuncu kaydı da (`_host_drop_peer`)
## aynı ertelenmiş boşaltmada düşer; arada fizik adımı olmadığından hesaplanan tablo ayrılanı yeniden açamaz.
func _vision_on_peer_disconnected(peer_id: int) -> void:
	_vision_forget_peer.call_deferred(peer_id)


func _vision_forget_peer(peer_id: int) -> void:
	var changed: Dictionary = _vision_session().forget(peer_id)
	for gone: int in changed:
		player_exposure_changed.emit(gone, int(changed[gone]))


## Yerel oyuncu doğdu (seviye yüklemesi, seviye değişimi, geç katılım): sis ona bağlanır (kare sonunda; oyuncu
## ağaca tam girmiş olsun). Oyuncu kalktı (seviye değişimi, oturum sonu): maruziyet tablosu boşalır.
func _vision_on_local_player(player: Node) -> void:
	if player != null:
		_vision_attach_fog.call_deferred()
		return
	_vision_clear_exposures()


func _vision_clear_exposures() -> void:
	if _vision_session().exposures().is_empty():
		return
	var changed: Dictionary = _vision_session().clear_exposures()
	for peer_id: int in changed:
		player_exposure_changed.emit(peer_id, int(changed[peer_id]))


## Sıra (t2): katman gözlemcisiz kurulur (hesap yok) → oturum kipi ve yerel oyuncunun gerçek bakışı verilir →
## izleme başlar (ilk hesap). Aksi halde ilk güncelleme varsayılan kip/bakışla koşar; yönlü kipte oyuncunun arkası
## hafızaya yazılır, arkadaki NPC bir an görünüp hayalet kalır. Katman zaten varsa hafızası korunur.
func _vision_attach_fog() -> void:
	var me: Node2D = local_player() as Node2D
	if _level == null or me == null or not me.is_inside_tree() or not _level.is_inside_tree():
		return
	var fog: Object = _level.attach_fog(null)
	_vision_prime_fog(fog, me)
	fog.call(&"follow", me)


## Kip değişti (istemciye çoğaltılan kip): aynı sıra — kip ve bakış önce; sis bir gözlemciyi izliyorsa eski kipin
## hafızası silinip hemen yeniden hesaplanır.
func _vision_apply_fog_mode() -> void:
	var fog: Object = _vision_fog()
	if fog == null:
		return
	var changed: bool = int(fog.call(&"mode")) != _vision_session().mode()
	_vision_prime_fog(fog, local_player())
	if changed and is_instance_valid(fog.call(&"observer")):
		fog.call(&"reset_memory")
		fog.call(&"update_now")


## Sise oturum kipini ve (varsa) yerel oyuncunun bakışını verir; hesaplamaz.
func _vision_prime_fog(fog: Object, me: Node) -> void:
	fog.call(&"set_mode", _vision_session().mode())
	var look: Variant = me.get(&"look_dir") if me != null else null
	if look is Vector2:
		fog.call(&"set_look_dir", look)


func _vision_fog() -> Object:
	return _level.fog_layer() as Object if _level != null else null


func _vision_dump() -> Dictionary:
	var fog: Object = _vision_fog()
	var stats: Dictionary = fog.call(&"stats") if fog != null else {}
	var me: Node = local_player()
	var remote: Dictionary = {}
	var root: Node2D = _players_root()
	if root != null:
		for child: Node in root.get_children():
			if child != me and child.has_method(&"look_angle"):
				remote[str(child.name)] = snappedf(rad_to_deg(float(child.call(&"look_angle"))), 0.1)
	var npcs: Array[String] = []
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(VisionRules.NPC_VISUAL_GROUP):
			var visual: CanvasItem = node as CanvasItem
			if visual != null and visual.is_visible_in_tree() and bool(node.call(&"is_fully_visible")):
				npcs.append(str(node.get_parent().name))
	npcs.sort()
	var look: Variant = null
	if me != null and me.has_method(&"look_angle"):
		look = snappedf(rad_to_deg(float(me.call(&"look_angle"))), 0.1)
	return {
		"mode": str(stats.get("mode", VisionGrid.mode_name(_vision_session().mode()))),
		"fog": fog != null,
		"visible_tiles": int(stats.get("visible_tiles", 0)),
		"peripheral_tiles": int(stats.get("peripheral_tiles", 0)),
		"memory_tiles": int(stats.get("memory_tiles", 0)),
		"visible_npcs": npcs,
		"look_deg": look,
		"exposure": _vision_session().exposures(),
		"exposure_history": _vision_session().history(),
		"remote_look_deg": remote,
	}
