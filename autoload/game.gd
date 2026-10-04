extends Node
## Session and players (autoload `Game`, contract S3 — docs/notes/mimari.md).
##
## Session: open while `Net.local_peer_id() != 0` (incl. connecting/handshake); `_sync_session()` catches the transition each frame and at every entry point.
## When it ends (Net.leave(), connection_failed, host_disconnected) the level (with HUD) is removed and player/cash/event state reset. The level is not
## `current_scene`; Game cleans it up. The UI (HUD) returns to the menu; Game and main.gd never change scenes (no double switch; headless/args launch: main.gd quits, AC4).
## Host authority follows S2: host-only work is guarded by `_has_host_authority()` (host or offline); host→all state RPCs are "authority". UI scenes are load()ed, not preloaded.
##
## Level and player order (late-join "node not found" trap):
## - Levels load by hand at `/root/Game/World/Level` on every peer; the root must be `Level` (S4), level nodes are reached only via the Level API (KR-018).
##   A `PlayerSpawner` (MultiplayerSpawner, spawn_path = Level.players_root(), custom spawn_function: player_scene instance, name str(peer_id), authority peer_id) is created under it.
## - A joining client gets the level path from the host during the SceneMultiplayer auth handshake and loads it synchronously before being accepted,
##   so the level and PlayerSpawner exist when the host's replicator sends existing players.
## - Catch-up: players arrive with spawn data (spawn point) and client-side authority sync starts only after path confirmation (~2 RTT). So the host sends known positions
##   at once (reliable) and at 20 Hz (unreliable) for CATCHUP_SEC; the client applies them until that node's synchronizer delivers its first data. Same after an in-session level change.
## - In-session level change: the host despawns players, then sends `_rpc_load_level`, then spawns the new players (same reliable ordered channel, so clients have the path ready).
## - With remote players the host first says "freeze": each client turns off publishing of its authority synchronizers (public_visibility = false) and acks.
##   No despawn until all acks (or FREEZE_TIMEOUT_SEC), so stale sync packets don't hit removed nodes ("Ignoring sync data ... missing node").
##   Hence online `start_level` completes ~1 RTT later and reports via `level_loaded`; it also waits while a peer is in handshake.
## Dump (S6): `collect_dump()` base keys + keys added by `register_dump_provider`; values made JSON-safe (Vector2 -> [x, y], Color -> "#rrggbbaa", StringName -> String).
## Alert ladder (S3 addendum, KR-021; US-008): host-authoritative `alert_level` (0-5; meaning is venue-specific, the venue's alert manager picks transitions — NPCs/StoreAlert in the shop)
## and police timer `alert_timer_left` (−1 if none). The host calls `set_alert_level` / `set_alert_timer`; values go to all by reliable RPC (late joiners on accept); the timer counts down locally per peer.
## Reset to 0 / −1 on level load and session end. Dump "alert": {"level", "timer_left", "history"} (history = ladder steps seen this level; I4 check).

signal players_changed()
signal local_player_changed(player: Node)
signal team_cash_changed(value: int)
signal level_loaded(level: Node)
## Emitted on every peer (e.g. &"police_called").
signal session_event(kind: StringName, data: Dictionary)
## S3 addendum: alert level changed (on every peer).
signal alert_level_changed(level: int)

const DEFAULT_LEVEL := "res://levels/store_a.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
const DEFAULT_PLAYER_SCENE := "res://entities/player/player.tscn"
## Handshake protocol version; mismatched peers are rejected. Bump when the wire layout (RPC/synchronizer/handshake) changes (mimari.md S2).
## 2: US-011b 8-bit look angle in the movement synchronizer + vision mode/exposure RPCs. 4: US-010 counter/shelf-end prop synchronizers, owner's STALL component and `net_shouted`.
## 5: US-043 owner/local-resident REDIRECT components and `net_misdirected`.
const PROTOCOL_VERSION := 5
const AUTH_TIMEOUT_SEC := 10.0
const MAX_NAME_LENGTH := 24
const MAX_EVENTS := 256
const LEVEL_NODE_NAME := "Level"
const SPAWNER_NODE_NAME := "PlayerSpawner"
const HUD_LAYER := 10
## Max time to wait for clients' freeze acks on a level change.
const FREEZE_TIMEOUT_SEC := 1.0
## Duration and interval at which the host sends known positions to late joiners / after a level change.
const CATCHUP_SEC := 2.0
const CATCHUP_INTERVAL_SEC := 0.05
## collect_dump() base keys; providers cannot override them.
const BASE_DUMP_KEYS: Array[String] = [
	"peer_id", "is_host", "peers", "players", "team_cash", "level", "player_nodes", "events", "host_lost",
	"ping_ms", "ping", "alert",
	"vision",  # US-011b vision addendum (S3 addendum; dump built in `_vision_dump` below)
	"session_seed",  # IS-058b (host only)
]
## Max alert levels kept in history.
const MAX_ALERT_HISTORY := 64
const _SYNCED_META := &"_game_synced"

## Default res://entities/player/player.tscn (null if the file is missing); tests may override.
var player_scene: PackedScene

var _world: Node
var _level: Level = null
var _level_path: String = ""
var _spawner: MultiplayerSpawner = null
## peer_id -> {"name": String, "slot": int}; slot = join slot (spawn point order; the visual side picks the team colour from it, Game knows no colours — mimari.md §6).
## The host assigns; a leaver's slot is reused.
var _players: Dictionary = {}
## Remote peers in the session (from Net signals).
var _peer_ids: Array[int] = []
var _local_name: String = ""
var _team_cash: int = 0
var _events: Array[Dictionary] = []
var _dump_providers: Dictionary = {}
var _host_lost: bool = false
var _session_peer: MultiplayerPeer = null
var _pending_level: String = ""
## Host: peers whose "frozen" ack is awaited before a level change, and the deadline (ms).
var _freeze_acks: Dictionary = {}
var _freeze_deadline_ms: int = 0
## Host: peer in handshake -> reported name.
var _auth_names: Dictionary = {}
## Host: peer being caught up on positions -> deadline (ms).
var _catchup: Dictionary = {}
var _catchup_elapsed: float = 0.0
var _players_broadcast_queued: bool = false
var _warned_no_player_scene: bool = false
var _alert_level: int = 0
## Time left on the police timer (s); −1 = no timer.
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


## Reported to the host on connect.
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


## Local player node or null.
func local_player() -> Node:
	var root: Node = _players_root()
	if root == null or Net.local_peer_id() == 0:
		return null
	return root.get_node_or_null(NodePath(str(Net.local_peer_id())))


## Host only; makes everyone load. Immediately with no remote players; otherwise once clients stopped syncing (~1 RTT). Emits `level_loaded` when done.
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


## Host only.
func add_team_cash(amount: int) -> void:
	if not _has_host_authority():
		push_warning("Game.add_team_cash: yalnız host çağırabilir")
		return
	if amount == 0:
		return
	_to_all(&"_rpc_team_cash", [_team_cash + amount])


func team_cash() -> int:
	return _team_cash


## Host only; broadcasts to everyone and records into the dump's "events" list.
func raise_session_event(kind: StringName, data: Dictionary = {}) -> void:
	if not _has_host_authority():
		push_warning("Game.raise_session_event: yalnız host çağırabilir")
		return
	_to_all(&"_rpc_session_event", [kind, data])


## S3 addendum: current alert level (0-5).
func alert_level() -> int:
	return _alert_level


## S3 addendum: time left on the police timer (s); −1 if no timer.
func alert_timer_left() -> float:
	return _alert_timer


## Host only: broadcasts the alert level to everyone (timer kept). The transition rule belongs to the venue's manager.
func set_alert_level(level: int) -> void:
	if not _has_host_authority():
		push_warning("Game.set_alert_level: yalnız host çağırabilir")
		return
	if level == _alert_level:
		return
	_to_all(&"_rpc_alert", [clampi(level, 0, 5), _alert_timer])


## Host only: sets the police timer (s; < 0 removes it) and broadcasts.
func set_alert_timer(seconds: float) -> void:
	if not _has_host_authority():
		push_warning("Game.set_alert_timer: yalnız host çağırabilir")
		return
	_to_all(&"_rpc_alert", [_alert_level, seconds if seconds >= 0.0 else -1.0])


## `key` becomes a top-level dump key; the value is fetched via `provider.call()` at dump time.
## Base keys (BASE_DUMP_KEYS) cannot be overridden; re-registering a key keeps the last one.
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
		"ping": _dump_ping_info(),
		"alert": {"level": _alert_level, "timer_left": _alert_timer, "history": _alert_history.duplicate()},
		"vision": to_json_value(_vision_dump()),  # US-011b
	}
	if _has_host_authority():
		dump["session_seed"] = _session_seed  # IS-058b
	for key: String in _dump_providers:
		var provider: Callable = _dump_providers[key]
		if provider.is_valid():
			dump[key] = to_json_value(provider.call())
	return dump


## Converts a value to a JSON-writable form (incl. nested Dictionary/Array).
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


# --- session ---

## A session is open as long as Net has a transport (host, connecting, handshake or accepted).
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


## Host or offline (standalone). Read from Net flags so a network event never queries `multiplayer.is_server()` on a closed transport (error);
## same meaning as the S2 is_server() guard.
func _has_host_authority() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0


## Host→all state call: RPC if online (call_local), local call otherwise.
func _to_all(method: StringName, args: Array) -> void:
	if Net.is_online():
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


func _authenticating_peers() -> PackedInt32Array:
	var sm: SceneMultiplayer = multiplayer as SceneMultiplayer
	return sm.get_authenticating_peers() if sm != null else PackedInt32Array()


## Applies the pending level change once conditions hold: no peer in handshake and all "frozen" acks arrived (or timed out).
func _try_start_pending_level() -> void:
	if _pending_level.is_empty():
		return
	if Net.is_online():
		if not _authenticating_peers().is_empty():
			return  # a peer in handshake may have received the old path; loads when it finishes
		if not _freeze_acks.is_empty() and Time.get_ticks_msec() < _freeze_deadline_ms:
			return
	var level_path: String = _pending_level
	_pending_level = ""
	_freeze_acks.clear()
	_despawn_all_players()
	_unload_level()
	_session_seed_new_job()  # IS-058b: before the level's NPCs read it
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


# --- Net events ---
# The host's reaction to network events (broadcast, spawn/despawn) is deferred to end of frame: when several peers drop in the same poll, sending to a
# dropped peer whose event is not yet processed gives "Unable to send packet ... max channels: 0". By end of frame the transport has processed all events.

func _on_peer_connected(peer_id: int) -> void:
	_sync_session()
	if not _peer_ids.has(peer_id):
		_peer_ids.append(peer_id)
	if Net.is_host():
		# Target is a freshly accepted, live peer: positions go right after the spawn packets in the same poll.
		var positions: Dictionary = _player_positions()
		if not positions.is_empty():
			_rpc_catchup_positions_reliable.rpc_id(peer_id, positions)
		_start_catchup(peer_id)
		_host_admit_peer.call_deferred(peer_id)


func _host_admit_peer(peer_id: int) -> void:
	if not Net.is_host() or not _peer_ids.has(peer_id) or _players.has(peer_id):
		return  # left meanwhile or the session ended
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
	# On a client the player record and node are removed by the host (players RPC + despawn).
	if Net.is_host():
		_host_drop_peer.call_deferred(peer_id)


func _host_drop_peer(peer_id: int) -> void:
	if not Net.is_host() or _peer_ids.has(peer_id):
		return
	_catchup.erase(peer_id)
	# IS-099: a player leaving mid-job still shows in the job result (`left: true`).
	if _heist != null and _players.has(peer_id):
		_heist.note_left(peer_id, _players[peer_id] as Dictionary)
	if _players.erase(peer_id):
		_broadcast_players()
	_despawn_player(peer_id)
	if _freeze_acks.erase(peer_id):
		_try_start_pending_level()


func _on_connection_failed() -> void:
	_sync_session()  # so a level/state loaded during the handshake is removed at once


func _on_host_disconnected() -> void:
	# State is cleared next frame (_sync_session) so listeners (dump) see the final state first.
	_host_lost = true


# --- handshake (SceneMultiplayer auth) ---
# The host sends the level path before acceptance; the client loads it, replies with its name and loaded path and finishes its side. The host finishes if the path matches,
# else (bad version/format or different path) it disconnects. The host does not change level while a peer is in handshake (see _try_start_pending_level).

func _on_peer_authenticating(peer_id: int) -> void:
	if Net.is_host():
		var hello: Dictionary = {"v": PROTOCOL_VERSION, "level": _level_path}
		(multiplayer as SceneMultiplayer).send_auth(peer_id, var_to_bytes(hello))


func _on_peer_authentication_failed(peer_id: int) -> void:
	_auth_names.erase(peer_id)


func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	var sm: SceneMultiplayer = multiplayer as SceneMultiplayer
	var msg: Variant = bytes_to_var(data)  # objects are not decoded (safe)
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


# --- RPCs (host→all: "authority"; client→host: "any_peer" + sender validation) ---

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
	# with call_local `data` is the caller's dictionary; copy so later changes don't alter the record
	_events.append({"kind": kind, "data": data.duplicate(true)})
	if _events.size() > MAX_EVENTS:
		_events.pop_front()
	session_event.emit(kind, data)


## Positions known to the host (peer_id -> Vector2): once reliably on accept, then an unreliable stream.
@rpc("authority", "call_remote", "reliable")
func _rpc_catchup_positions_reliable(positions: Dictionary) -> void:
	_apply_catchup(positions)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_catchup_positions(positions: Dictionary) -> void:
	_apply_catchup(positions)


## The host already loaded the level; goes to clients only.
@rpc("authority", "call_remote", "reliable")
func _rpc_load_level(level_path: String) -> void:
	if not _is_level_path(level_path):
		push_warning("Game: geçersiz seviye yolu reddedildi: " + level_path)
		return
	_unload_level()
	_load_level_local(level_path)


## Before a level change: the client turns off publishing of its authority synchronizers and acks.
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


# --- players ---

## Returns the smallest free slot.
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


## Single broadcast at end of frame (no sends inside the poll; name changes in the same frame merge).
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


## PlayerSpawner.spawn_function: runs in spawn() on the host, on spawn packet arrival on clients.
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


## Spawn point of the slot (Players coordinates); lines players up side by side if the level has none.
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
	# Remote player: once its synchronizer's first data arrives, catch-up stops for this node.
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


## Host: every CATCHUP_INTERVAL_SEC sends current positions to peers being caught up.
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


## Client: applies host-known positions to remote players whose synchronizer has not delivered data yet.
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


# --- level ---

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


# --- dump helpers ---

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


## IS-026: source and sample count of the ping measurement ({"<peer_id>": Net.get_ping_info}).
func _dump_ping_info() -> Dictionary:
	var out: Dictionary = {}
	for peer_id: int in _peer_ids:
		var info: Dictionary = Net.get_ping_info(peer_id)
		if info["source"] != "none":
			out[str(peer_id)] = info
	return out


func _dump_pings() -> Dictionary:
	var out: Dictionary = {}
	for peer_id: int in _peer_ids:
		var ping: int = Net.get_ping_ms(peer_id)
		if ping >= 0:
			out[str(peer_id)] = ping
	return out


## Drops invisible characters and trims to MAX_NAME_LENGTH. For long input only the first MAX_NAME_LENGTH x 4 characters are processed
## (a huge name from the network must not freeze the host).
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
# US-012 — Heist result (S3 addendum, KR-021: heist_finished, heist_result, request_restart, venue_tier). This section leaves the code above untouched:
# connections and the physics step come from `_notification` (ENTER_TREE, PHYSICS_PROCESS). Rules and counters live in nodeless `HeistRules` / `HeistRules.Tracker`
# (core/heist_rules.gd); here only scene wiring: player view (escape zone `Level.zone(&"EscapeZone")`, caught/held from the player API, carried bag value), whose vault cash
# it is (component's `completed` signal), result broadcast; when the job ends loot interactions lock on the host (new requests rejected, a late-finishing vault's cash is taken back).
# - The job is tracked only in levels with an `EscapeZone`; the host decides (S2), the result goes to all by RPC and to late joiners on accept. At the end team cash = before + payout
#   (cash that entered instantly from the vault is replaced by the payout). Reset when the level goes away (restart, session end).
# - US-008 hook points (skipped if absent): Game signals `alert_level_changed(level)`, `police_arrived()`, `player_caught(peer_id[, by])`; `alert_level()` (read every step);
#   player `is_caught()` / `is_held()` (HeistRules.CAUGHT_METHODS / HELD_METHODS). The same events are also accepted as session_event:
#   &"alert_level" {"level"}, &"police_arrived", &"player_caught" {"peer", "by"?: &"chaser"}, &"shout".
# - Test hook (automation + host only, net scenario): `--bot` steps {"t": SEC, "heist": "<event>", "data": {...}} — "alert" {"level"}, "police", "caught" {"slot" | "all"}, "shout", "restart" —
#   applied through the session_events above (and request_restart); stands in for owner events until US-008. Time counts from the first local player's first physics step, like the bot timeline.
# - US-040 empty-handed abort: rule and clock in `HeistRules.AbortClock` (inside Tracker, host decides; duration data/heist_tuning.tres). `abort_left()` HUD countdown: on the host the Tracker's clock,
#   on a client derived by the same class from the local copy (escape_status + replicated bag carrier / vault `emptied`) — no RPC; the result still arrives via heist_finished.
# - IS-103 escape settle (KR-034): same pattern — rule and clock `Tracker.settle` (host decides; `escape_settle_s` in data/heist_tuning.tres), `escape_settle_left()` HUD countdown
#   (host: the deciding clock; client: local estimate from escape_status + loot seen + this level's alert peak < 2). No RPC; dump `heist.settle_peak_s`.
# - US-041 bail (KR-029): per caught player `bail_by_tier[venue_tier()]` (data/heist_tuning.tres); team cash = before + payout − bail, may go negative (debt). The result has `bail`, `cash_before`, `cash_after`.
#   "Again" (request_restart) does not reset cash: debt/cash carries to the next job (KR-029, US-042 package).
# - US-042 cover and witness query: rule in `HeistRules` (cover_breaker, associates, witness_released) and Tracker (cover_broken, released). The view gains cover fields: staff side (`StaffArea`/`Backroom` zone),
#   vault/cash holding (cash component's `busy_by`), movement mode (`net_mode`), mask (not yet: false). The owner shouting/holding (`owner_shout`/`owner_held` signal, `player_held` event) marks the friend;
#   a RESCUE (`player_rescued {peer, by}`) or bag handover (previous carrier → receiver) with the marked friend within 48 px where an observer sees it (owner with `report_suspicion` in the level or civilian with
#   `suspicion()`/`perception()`; cone + line of sight) breaks cover, and each observer that sees gives that player +60 suspicion (owner: customer-witness path `report_suspicion`).
#   Broken cover goes to all as `session_event` &"cover_broken" {peer, reason} (HUD silent; local indicator `cover_state()`); wire layout unchanged. When police arrive a player with intact cover, no loot,
#   not held and outside the zone is released (`witness_released`: no bail, recognised +1, team heat +2).
# - IS-099 left player: a peer dropped mid-job (`_host_drop_peer`, before the roster erase) goes to `Tracker.note_left`; the result's `players` lists it with
#   `left: true` and zero share/bail (economy unchanged); roster players carry `left: false`.
# - US-042 strategy label: result `strategy` (Tracker.strategy) and dump `heist.strategy`; interaction count from every level Interactable's `completed` (player) + RESCUE; back door = a player used the `BackDoor` prop.
# Dump (S6 "heist", --dump only): {"active", "max_alert", "elapsed", "result", "history", "abort_peak_s", "settle_peak_s", "cover" {peer: bool}, "strategy"}.
# =====================================================================================================================

signal heist_finished(result: Dictionary)

const HEIST_DUMP_KEY := "heist"
const HEIST_ESCAPE_ZONE := &"EscapeZone"
## Venue tier (a single venue in Phase 2: grocery T1).
const HEIST_VENUE_TIER := 1
const HEIST_SIG_ALERT := &"alert_level_changed"
const HEIST_SIG_POLICE := &"police_arrived"
const HEIST_SIG_CAUGHT := &"player_caught"
const HEIST_EVENT_ALERT := &"alert_level"
const HEIST_EVENT_POLICE := &"police_arrived"
const HEIST_EVENT_CAUGHT := &"player_caught"
const HEIST_EVENT_SHOUT := &"shout"
## US-042: cover broken {peer, reason} (the host emits; each peer keeps it for its local indicator; silent in the HUD).
const HEIST_EVENT_COVER := &"cover_broken"
const HEIST_EVENT_HELD := &"player_held"
const HEIST_EVENT_RESCUED := &"player_rescued"
## Signals where the owner marks a player (peer_id): shouted, held.
const HEIST_MARK_SIGNALS: Array[StringName] = [&"owner_shout", &"owner_held"]
## US-010/US-043/US-044 (host): owner's player-tool hook ("social" strategy), recognition (showcase query) and counter purchase as a session event
## (cost deducted from end-of-job cash).
const HEIST_SOCIAL_SIGNAL := &"social_action"
const HEIST_RECOGNIZED_SIGNAL := &"recognized"
const HEIST_EVENT_PURCHASE := &"purchase"
## Staff-side zones that break cover (S4 addendum).
const HEIST_STAFF_ZONES: Array[StringName] = [&"StaffArea", &"Backroom"]
## Back door prop (back-door strategy label).
const HEIST_BACK_DOOR := &"BackDoor"
const HEIST_HOOK_KEY := "heist"
const HEIST_HISTORY_MAX := 16
## Group of interaction components: same value as Interactable.GROUP (= PhysicsLayers.INTERACTABLES_GROUP, IS-037; bound to it on merge). So the autoload does not bind to entities/ classes at
## compile time (§6), components are touched by duck typing only (has_signal/has_method/"x" in).
const HEIST_INTERACTABLES_GROUP := PhysicsLayers.INTERACTABLES_GROUP

var _heist: HeistRules.Tracker = null
var _heist_result: Dictionary = {}
var _heist_history: Array[Dictionary] = []
var _heist_hook_steps: Array[Dictionary] = []
var _heist_hook_next: int = 0
var _heist_hook_t: float = 0.0
var _heist_hook_started: bool = false
## Optional signals connected (US-008; name -> true): retried on every level load.
var _heist_bound: Dictionary = {}
## US-042: players whose cover broke (peer -> reason), on every peer from the `cover_broken` event; reset with the level.
var _heist_cover_lost: Dictionary = {}
## Host: bag node (instance id) -> carrier in the last step (to find the previous carrier on a handover).
var _heist_bag_carrier: Dictionary = {}
## Host: cash interaction components (vault; `busy_by` = holding player).
var _heist_cash_items: Array[Node] = []
## US-040: client's local empty-handed abort counter (HUD only; the decision is the host's Tracker.abort).
var _heist_abort_view: HeistRules.AbortClock = null
## Cash props in the level (vault; `emptied` is replicated): for the client's local loot estimate.
var _heist_cash_props: Array[Node] = []
## IS-103: client's local escape settle counter (HUD only; the decision is the host's Tracker.settle).
var _heist_settle_view: HeistRules.AbortClock = null


## Result of a finished job (S3 addendum; late joiners get it too); empty if the job is running or absent.
func heist_result() -> Dictionary:
	return _heist_result.duplicate(true)


## Host only: reloads the same level (Game level path); props reset with the level. Team cash (incl. debt) carries over:
## the next job's payout settles the debt (KR-029).
func request_restart() -> void:
	if not _has_host_authority():
		push_warning("Game.request_restart: yalnız host çağırabilir")
		return
	if _level_path.is_empty():
		push_warning("Game.request_restart: yüklü seviye yok")
		return
	start_level(_level_path)


## Venue tier (alert ladder texts `ALERT_T<k>_<level>`).
func venue_tier() -> int:
	return HEIST_VENUE_TIER


## US-040 (S3 addendum): time left on the empty-handed abort countdown (s); −1 if no counter or the job finished. On the host the deciding counter;
## on a client an estimate derived from the local copy (display only).
func abort_left() -> float:
	if _heist == null or _heist.finished:
		return -1.0
	if _has_host_authority():
		return _heist.abort.left()
	return _heist_abort_view.left() if _heist_abort_view != null else -1.0


## IS-103 (S3 addendum): time left on the escape settle countdown ("van leaving… n", s); −1 if no countdown or the job finished. On the host the deciding counter;
## on a client an estimate derived from the local copy (display only). Never runs together with `abort_left()` (abort needs loot 0, settle loot > 0).
func escape_settle_left() -> float:
	if _heist == null or _heist.finished:
		return -1.0
	if _has_host_authority():
		return _heist.settle.left()
	return _heist_settle_view.left() if _heist_settle_view != null else -1.0


## US-042 (S3 addendum): the local player's cover — 1 intact ("you look like a customer"), 0 broken, −1 no job/finished or no local player.
## Every peer reads it from `cover_broken` events (the host too).
func cover_state() -> int:
	if _heist == null or _heist.finished or local_player() == null:
		return -1
	return 0 if _heist_cover_lost.has(local_player().get_multiplayer_authority()) else 1


## The section's single engine entry: `_enter_tree`/`_physics_process` are not defined so other sections (US-008) can add their own virtuals without clashing.
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
	_heist_end_quit_bind()  # IS-015a (block at the end of the file)
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
	if _heist == null or _heist.finished or _level == null:
		return
	if not _has_host_authority():
		_heist_client_abort(delta)
		return
	var views: Dictionary = _heist_views()
	if views.is_empty():
		return
	if has_method(&"alert_level"):
		_heist.set_alert(int(call(&"alert_level")))
	_heist.observe(views, delta)
	_heist_flush_cover()
	_heist_drop_caught_bags()
	var decision: StringName = _heist.evaluate(views)
	if decision != HeistRules.DECISION_NONE:
		_heist_finish(decision, views)


## US-008 signals (skipped if absent; retried on every level load): alert (1 arg), police (0), caught (1-2 args: peer_id[, by]); extra args are dropped (HeistRules.adapt_callable).
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
	_heist_cover_lost.clear()
	_heist_bag_carrier.clear()
	_heist_cash_items.clear()
	var lvl: Level = level as Level
	if lvl == null or lvl.zone(HEIST_ESCAPE_ZONE) == null:
		return
	_heist = HeistRules.Tracker.new()
	var tuning: HeistTuning = HeistTuning.load_default()
	_heist.abort.hold_s = tuning.abort_hold_s
	_heist.cover_mark_window_s = tuning.cover_mark_window_s
	_heist.witness_heat = tuning.witness_heat
	_heist_abort_view = HeistRules.AbortClock.new(tuning.abort_hold_s)
	_heist.settle.hold_s = tuning.escape_settle_s
	_heist_settle_view = HeistRules.AbortClock.new(tuning.escape_settle_s)
	_heist_cash_props.clear()
	if not level.tree_exiting.is_connected(_heist_on_level_exiting):
		level.tree_exiting.connect(_heist_on_level_exiting, CONNECT_ONE_SHOT)
	for node: Node in get_tree().get_nodes_in_group(HEIST_INTERACTABLES_GROUP):
		var prop: Node = node.get_parent()
		# US-042 strategy label: prop interactions (a RESCUE on a player is counted from the `player_rescued` event).
		if level.is_ancestor_of(node) and prop != null and node.has_signal(&"completed") 				and not prop.has_method(&"interaction_position"):
			node.connect(&"completed", _heist_on_interaction.bind(prop))
		if not level.is_ancestor_of(node) or prop == null or prop.is_in_group(HeistRules.BAG_GROUP) \
				or not node.has_signal(&"completed"):
			continue
		var def: Resource = prop.get(&"def") as Resource
		var cash: int = int(def.get(&"cash_value")) if def != null and "cash_value" in def else 0
		if cash <= 0:
			continue
		_heist_cash_props.append(prop)
		_heist_cash_items.append(node)
		node.connect(&"completed", _heist_on_cash_taken.bind(cash))
		# After the job ends the host rejects new loot interactions (unless the component blocks itself; the bag locks itself).
		if "start_blocker" in node and not (node.get(&"start_blocker") as Callable).is_valid():
			node.set(&"start_blocker", _heist_loot_locked)
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		if level.is_ancestor_of(bag) and bag.has_signal(&"taken"):
			bag.connect(&"taken", _heist_on_bag_taken.bind(bag))
	# US-042: a player marked by the owner (shouted/held) opens the association window.
	var npcs: Node = lvl.npcs_root()
	if npcs != null:
		for node: Node in npcs.find_children("*", "", true, false):
			for sig: StringName in HEIST_MARK_SIGNALS:
				if node.has_signal(sig):
					node.connect(sig, _heist_on_marked)
			if node.has_signal(HEIST_SOCIAL_SIGNAL):
				node.connect(HEIST_SOCIAL_SIGNAL, _heist_on_social)
			if node.has_signal(HEIST_RECOGNIZED_SIGNAL):
				node.connect(HEIST_RECOGNIZED_SIGNAL, _heist_on_recognized)


## When the level goes away (restart, level change, session end): job and result reset, before loading so the new level's HUD does not see the old result.
func _heist_on_level_exiting() -> void:
	_heist = null
	_heist_result = {}
	_heist_abort_view = null
	_heist_settle_view = null
	_heist_cash_props.clear()


## Client (US-040 HUD): local estimate of the empty-handed abort condition — everyone not caught is in the zone (escape_status, the host's `_heist_views` rule) and no loot is visible
## (no carried bag, no un-emptied cash prop). If someone caught later emptied the vault the host counts it but the client does not: then the countdown shows only on the host.
func _heist_client_abort(delta: float) -> void:
	if _heist_abort_view == null:
		return
	var status: Dictionary = escape_status()
	var free: int = int(status.get("free", 0))
	var together: bool = free > 0 and int(status.get("in_zone", 0)) >= free
	var loot_seen: bool = _heist_loot_seen()
	_heist_abort_view.step(together and not loot_seen, delta, free)  # free count changed (a catch): restart
	# IS-103: escape settle estimate — together with loot and nobody shouted this level (alert peak < ALERT_SHOUTED; police is alert 5).
	if _heist_settle_view != null and _heist_settle_view.hold_s > HeistRules.ABORT_EPS:
		_heist_settle_view.step(together and loot_seen and _heist_alert_peak() < HeistRules.ALERT_SHOUTED, delta, free)


## Highest alert level seen on this level (the alert history resets on level load; the ladder can step 2 -> 1).
func _heist_alert_peak() -> int:
	var peak: int = _alert_level
	for level: int in _alert_history:
		peak = maxi(peak, level)
	return peak


## Loot as the client sees it: a replicated bag carrier or an emptied cash prop.
func _heist_loot_seen() -> bool:
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		if _level != null and _level.is_ancestor_of(bag) and int(bag.get(&"carrier")) != 0:
			return true
	for prop: Node in _heist_cash_props:
		if is_instance_valid(prop) and "emptied" in prop and bool(prop.get(&"emptied")):
			return true
	return false


## Whose vault cash it is (the prop added it to team cash in its own handler). Cash from an emptying that started before the job ended but finished after the result is taken back: the payout is final.
func _heist_on_cash_taken(peer_id: int, cash: int) -> void:
	if _heist == null:
		return
	if not _heist.finished:
		_heist.add_cash(peer_id, cash)
	elif _has_host_authority():
		add_team_cash(-cash)


func _heist_loot_locked() -> bool:
	return _heist != null and _heist.finished


func _heist_on_bag_taken(peer_id: int, bag: Node) -> void:
	if _heist == null or _heist.finished:
		return
	var previous: int = int(_heist_bag_carrier.get(bag.get_instance_id(), 0))
	_heist_bag_carrier[bag.get_instance_id()] = peer_id
	_heist.note_bag(peer_id)
	if previous != 0 and previous != peer_id and _has_host_authority():
		_heist_associate(peer_id, previous)  # bag handover: the receiver may be associated with the giver


# --- US-042 cover ---

## An interaction in the level completed (host; player > 0): strategy label counter and back door.
func _heist_on_interaction(peer_id: int, prop: Node) -> void:
	if _heist == null or _heist.finished or peer_id <= 0:
		return
	_heist.note_interaction(peer_id)
	if is_instance_valid(prop) and StringName(prop.name) == HEIST_BACK_DOOR:
		_heist.back_door_used = true


## Owner's player tool (host; US-010 BUY/STALL/SEND/DISTRACT, US-043 REDIRECT): "social" strategy.
func _heist_on_social(peer_id: int, _kind: StringName) -> void:
	if _heist != null and not _heist.finished and _has_host_authority():
		_heist.note_social(peer_id)


## The owner recognised a player (host; US-044 showcase query): `recognized` +1 in the result.
func _heist_on_recognized(peer_id: int) -> void:
	if _heist != null and not _heist.finished and _has_host_authority():
		_heist.note_recognized(peer_id)


## The owner shouted at / held a player (host): opens the association window.
func _heist_on_marked(peer_id: int) -> void:
	if _heist != null and not _heist.finished and _has_host_authority():
		_heist.mark_target(peer_id)


## Host: newly broken covers go to everyone as an event (local indicator; silent in the HUD).
func _heist_flush_cover() -> void:
	var pending: Array[Dictionary] = _heist.cover_events.duplicate()
	_heist.cover_events.clear()
	for e: Dictionary in pending:
		raise_session_event(HEIST_EVENT_COVER, {"peer": int(e["peer"]), "reason": String(e["reason"])})


## `actor` interacted with `other`, who may be marked (RESCUE, bag handover): tried using player positions.
func _heist_associate(actor: int, other: int) -> void:
	var a: Node2D = _heist_player(actor)
	var b: Node2D = _heist_player(other)
	if a == null or b == null:
		return
	_heist_associate_at(actor, other, _heist_position(a), _heist_position(b))


## Association (host): rule `Tracker.associate`; each observer that sees gives `actor` +60 suspicion (tuning). Returns how many observers gave suspicion (tests call it directly).
func _heist_associate_at(actor: int, other: int, actor_pos: Vector2, other_pos: Vector2) -> int:
	if _heist == null or _heist.finished or not _has_host_authority():
		return 0
	var tuning: HeistTuning = HeistTuning.load_default()
	var seeing: Array[Node] = _heist_observers_seeing(actor_pos)
	if not _heist.associate(actor, other, actor_pos.distance_to(other_pos), not seeing.is_empty(),
			tuning.association_radius_px):
		return 0
	for observer: Node in seeing:
		if observer.has_method(&"report_suspicion"):
			observer.call(&"report_suspicion", actor, tuning.association_suspicion, actor_pos)
		elif observer.has_method(&"suspicion"):
			var meter: Object = observer.call(&"suspicion") as Object
			if meter != null and meter.has_method(&"apply_delta"):
				meter.call(&"apply_delta", actor, tuning.association_suspicion)
	return seeing.size()


## Active observers (owner, civilians; under the level's NPCs) that see the position in their cone and line of sight.
func _heist_observers_seeing(pos: Vector2) -> Array[Node]:
	var out: Array[Node] = []
	var npcs: Node = _level.npcs_root() if _level != null else null
	if npcs == null:
		return out
	for node: Node in npcs.find_children("*", "", true, false):
		if not (node.has_method(&"report_suspicion") or node.has_method(&"suspicion")):
			continue
		if "active" in node and not bool(node.get(&"active")):
			continue
		var eye: Node2D = null
		if node.has_method(&"perception"):
			eye = node.call(&"perception") as Node2D
		if eye == null:
			eye = node.get_node_or_null(^"Perception") as Node2D
		if eye == null or not eye.has_method(&"params") or not eye.has_method(&"has_line_of_sight"):
			continue
		var params: PerceptionRules.Params = eye.call(&"params") as PerceptionRules.Params
		var facing: Variant = eye.get(&"facing")
		if params == null or not facing is Vector2:
			continue
		if PerceptionRules.band(params, eye.global_position, facing, pos) == PerceptionRules.Band.NONE:
			continue
		if bool(eye.call(&"has_line_of_sight", eye.global_position, pos)):
			out.append(node)
	return out


func _heist_player(peer_id: int) -> Node2D:
	var root: Node2D = _players_root()
	return root.get_node_or_null(NodePath(str(peer_id))) as Node2D if root != null and peer_id > 0 else null


static func _heist_position(node: Node2D) -> Vector2:
	if node.has_method(&"interaction_position"):
		return node.call(&"interaction_position")
	return node.global_position


func _heist_on_alert(level: int) -> void:
	if _heist != null and _has_host_authority():
		_heist.set_alert(level)


## Police arrived (US-008 timer): everyone outside the escape zone is caught; decided on the next step.
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
	if _heist != null and kind == HEIST_EVENT_COVER and typeof(data.get("peer")) == TYPE_INT:
		_heist_cover_lost[int(data["peer"])] = StringName(str(data.get("reason", "")))
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
		HEIST_EVENT_PURCHASE:
			_heist.note_purchase(int(data.get("cost", 0)))
		HEIST_EVENT_HELD:
			_heist.mark_target(int(data.get("peer", 0)))
		HEIST_EVENT_RESCUED:
			var rescuer: int = int(data.get("by", 0))
			_heist.note_interaction(rescuer)
			_heist_associate(rescuer, int(data.get("peer", 0)))


## Host: player view (HeistRules.Tracker): peer -> {"in_zone", "caught", "held", "bag_value", "sprinting",
## "staff_side", "holding_cash", "move_mode", "masked"} (the last four are the US-042 cover).
func _heist_views() -> Dictionary:
	var out: Dictionary = {}
	var root: Node2D = _players_root()
	if root == null or _level == null:
		return out
	var zone: Area2D = _level.zone(HEIST_ESCAPE_ZONE)
	var bag_values: Dictionary = {}
	for bag: Node in get_tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		var carrier: int = int(bag.get(&"carrier"))
		_heist_bag_carrier[bag.get_instance_id()] = carrier
		if carrier != 0:
			bag_values[carrier] = int(bag_values.get(carrier, 0)) + int(bag.get(&"value"))
	var staff: Array[Area2D] = []
	for zone_name: StringName in HEIST_STAFF_ZONES:
		var area: Area2D = _level.zone(zone_name)
		if area != null:
			staff.append(area)
	var cash_holders: Dictionary = {}
	for item: Node in _heist_cash_items:
		if is_instance_valid(item) and "busy_by" in item:
			cash_holders[int(item.get(&"busy_by"))] = true
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
			"staff_side": staff.any(func(area: Area2D) -> bool: return _heist_in_zone(area, pos)),
			"holding_cash": cash_holders.has(peer_id),
			"move_mode": int(node.get(&"net_mode")) if typeof(node.get(&"net_mode")) == TYPE_INT else HeistRules.MOVE_WALK,
			"masked": false,
		}
	return out


## Whether a (global) point is inside one of the zone's shapes.
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


## A caught carrier's bag drops (a teammate can pick it up).
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
	var bail_each: int = HeistRules.bail_for_tier(HeistTuning.load_default().bail_by_tier, venue_tier())
	# Pre-job vault: raw cash that entered instantly from the vault is removed and in-job purchases (deducted instantly) are added back; the result formula deducts purchases separately
	# (US-010: cash_after = before + payout − bail − purchases).
	var cash_before: int = _team_cash - _heist.cash_grabbed() + _heist.purchases_paid
	var result: Dictionary = _heist.build_result(decision, views, _players, bail_each, cash_before)
	# Team cash = before + payout − bail (KR-029: may go negative); raw cash that entered instantly from the vault changes.
	var cash_delta: int = int(result["cash_after"]) - _team_cash
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


## Late joiner: if the job finished the result is sent after accept (at end of frame).
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
		"abort_peak_s": snappedf(_heist_abort_peak(), 0.01),
		"settle_peak_s": snappedf(_heist_settle_peak(), 0.01),
		"cover": _heist_cover_dump(),
		"strategy": _heist_result.get("strategy", {}),
		"events_main": _heist_events_main(),
		"recognized": _heist_recognized_dump(),
	}


## Dump (US-044): in-job recognitions (showcase query) peer -> count (host; empty on a client).
func _heist_recognized_dump() -> Dictionary:
	var out: Dictionary = {}
	if _heist != null:
		for peer: Variant in _heist.recognized_extra:
			out[str(int(peer))] = int(_heist.recognized_extra[peer])
	return out


## Dump (IS-094): session events excluding US-042 cover events (`cover_broken`), so scenarios check owner/caught event order independently of cover events.
func _heist_events_main() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events:
		if StringName(str(e.get("kind", ""))) != HEIST_EVENT_COVER:
			out.append(e)
	return out


## Covers this peer knows: peer -> intact (those in the player list).
func _heist_cover_dump() -> Dictionary:
	var out: Dictionary = {}
	for peer_id: int in _players:
		out[str(peer_id)] = not _heist_cover_lost.has(peer_id)
	return out


## Longest empty-handed abort counter seen on this peer (s): the deciding counter on the host, the local estimate on a client.
func _heist_abort_peak() -> float:
	if _has_host_authority():
		return _heist.abort.peak_s if _heist != null else 0.0
	return _heist_abort_view.peak_s if _heist_abort_view != null else 0.0


## Longest escape settle counter seen on this peer (s; IS-103): the deciding counter on the host, the local estimate on a client.
func _heist_settle_peak() -> float:
	if _has_host_authority():
		return _heist.settle.peak_s if _heist != null else 0.0
	return _heist_settle_view.peak_s if _heist_settle_view != null else 0.0


# --- test hook (automation + host only) ---

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
# US-011b — Vision addendum (mimari.md S3 addendum "Vision addenda", KR-022/KR-023; GDD §6.5). This section leaves the code above untouched: entries are `_notification`
# (ENTER_TREE, PHYSICS_PROCESS) and signals; rules live in nodeless `VisionRules.Session` (core/vision_rules.gd).
# - Vision mode (`vision_mode`, 0 peripheral 360° / 1 directional): a host game rule. Default data/vision_tuning.tres `default_mode`; `--vision-mode=` (Args, US-011d) overrides;
#   the main menu (US-011c) sets it via `set_vision_mode` when hosting. Host only, before the level starts; replicated by reliable RPC (late joiners on accept, before their player spawns),
#   same for everyone. `set_vision_mode` on a client is a no-op (warning).
# - Fog wiring: when the local player spawns (`local_player_changed`; incl. level change and late join) the level's fog is set up in this order: layer without observer (`attach_fog(null)`) →
#   session mode + the local player's real `look_dir` → `follow(player)` (first compute). If the mode is replicated later, mode + look come first and memory is cleared and recomputed at once.
#   Each physics step the fog gets the local player's `look_dir`. A leaving peer's exposure record and history are removed. No fog without a local player (menu, playerless test).
#   Visibility is decided on the client (the host draws with its own local view); the host makes no visibility decision.
# - Exposure (`player_exposure`, 0 hidden / 1 visible / 2 seen): host only, 10 Hz, from NPC perception/suspicion summaries (duck typing: components with `last_observations()` + `value_of(peer)` — Suspicion):
#   1 = in an observer's cone and line of sight (last observation: band ≠ NONE ∧ line of sight clear), 2 = suspicion ≥ 30. On change the full table goes to all by reliable RPC (call_local);
#   `player_exposure_changed` on every peer. The table empties on level change and session end (when the local player goes away); the host republishes next round.
# - Test hook (automation only, when `--vision-mode` is not given): a `--bot` step {"t": 0, "vision_mode": "directional"} is applied at start like `--vision-mode`
#   (net_smoke cannot pass process args; the host's applies and is replicated to clients).
# Dump (S6 base key "vision"): {mode, fog, visible_tiles, peripheral_tiles, memory_tiles, visible_npcs:[name], look_deg, exposure:{peer: level},
# exposure_history:{peer: [levels]}, remote_look_deg:{peer: degrees}}.
# =====================================================================================================================

signal player_exposure_changed(peer: int, level: int)

const VISION_HOOK_KEY := "vision_mode"

var _vision: VisionRules.Session = null
var _vision_elapsed: float = 0.0


## S3 addendum: vision mode (0 peripheral 360°, 1 directional; VisionGrid.Mode).
func vision_mode() -> int:
	return _vision_session().mode()


## S3 addendum: host only, before the level starts; replicated to clients. No-op on a client or while a level is loaded.
func set_vision_mode(mode: int) -> void:
	if not _has_host_authority():
		push_warning("Game.set_vision_mode: yalnız host çağırabilir")
		return
	if not _vision_session().set_mode(mode, true, _level != null):
		push_warning("Game.set_vision_mode: kip yalnız seviye başlamadan ve geçerli değerle seçilir (%d)" % mode)
		return
	if Net.is_online() and not multiplayer.get_peers().is_empty():
		_rpc_vision_mode.rpc(mode)


## S3 addendum: player exposure (0 hidden, 1 visible, 2 seen); the host writes, everyone reads.
func player_exposure(peer: int) -> int:
	return _vision_session().exposure(peer)


## S3 addendum: player's world position (global); INF if there is no player node.
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


## Startup mode: --vision-mode > (in automation) bot hook > data/vision_tuning.tres.
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
		_vision_clear_exposures()  # session end / no level: the table empties
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


## Host: per-player exposure from NPC perception/suspicion components' summaries (duck typing).
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


## To a newly accepted peer: mode and exposure table (before spawn, on the same reliable channel).
func _vision_on_peer_connected(peer_id: int) -> void:
	if not Net.is_host():
		return
	_rpc_vision_mode.rpc_id(peer_id, _vision_session().mode())
	_rpc_exposure.rpc_id(peer_id, _vision_session().exposures())


## Peer left (every peer): its exposure and history are removed. Deferred: on the host the player record (`_host_drop_peer`) drops in the same deferred flush;
## no physics step in between, so the computed table cannot reopen the leaver.
func _vision_on_peer_disconnected(peer_id: int) -> void:
	_vision_forget_peer.call_deferred(peer_id)


func _vision_forget_peer(peer_id: int) -> void:
	var changed: Dictionary = _vision_session().forget(peer_id)
	for gone: int in changed:
		player_exposure_changed.emit(gone, int(changed[gone]))


## Local player spawned (level load, level change, late join): fog attaches to it (end of frame, so the player is fully in the tree).
## Player gone (level change, session end): the exposure table empties.
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


## Order (t2): layer built without observer (no compute) → session mode and the local player's real look given → tracking starts (first compute). Otherwise the first update runs with default
## mode/look; in directional mode the player's back is written to memory and the NPC behind appears briefly and ghosts. If the layer already exists its memory is kept.
func _vision_attach_fog() -> void:
	var me: Node2D = local_player() as Node2D
	if _level == null or me == null or not me.is_inside_tree() or not _level.is_inside_tree():
		return
	var fog: Object = _level.attach_fog(null)
	_vision_prime_fog(fog, me)
	fog.call(&"follow", me)


## Mode changed (replicated to the client): same order — mode and look first; if the fog follows an observer the old mode's memory is cleared and recomputed at once.
func _vision_apply_fog_mode() -> void:
	var fog: Object = _vision_fog()
	if fog == null:
		return
	var changed: bool = int(fog.call(&"mode")) != _vision_session().mode()
	_vision_prime_fog(fog, local_player())
	if changed and is_instance_valid(fog.call(&"observer")):
		fog.call(&"reset_memory")
		fog.call(&"update_now")


## Gives the fog the session mode and (if any) the local player's look; does not compute.
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


# =====================================================================================================================
# US-038 — Escape legibility: read-only helpers (S3 addendum candidate; HUD escape rows and edge arrow). They change no state and have no RPC: each peer computes from its local copy
# (replicated player positions and Status state); the rule is the same as the host's `_heist_views` (zone shape `_heist_in_zone`, position `interaction_position`).
# =====================================================================================================================

## World position of the escape point (centre of EscapeZone's first shape, global); Vector2.INF if the level has no zone.
func escape_point() -> Vector2:
	var zone: Area2D = _level.zone(HEIST_ESCAPE_ZONE) if _level != null else null
	if zone == null or not zone.is_inside_tree():
		return Vector2.INF
	for child: Node in zone.get_children():
		var holder: CollisionShape2D = child as CollisionShape2D
		if holder != null and not holder.disabled and holder.shape != null:
			return holder.global_position
	return zone.global_position


## Escape status: {"in_zone": int, "free": int} — number of not-caught (incl. held) players and how many of them are in the escape zone now.
## Win: in_zone == free (and loot > 0; HeistRules.decide). in_zone 0 if there is no zone.
func escape_status() -> Dictionary:
	var free: int = 0
	var in_zone: int = 0
	var root: Node2D = _players_root()
	if root != null and root.is_inside_tree():
		var zone: Area2D = _level.zone(HEIST_ESCAPE_ZONE)
		for child: Node in root.get_children():
			var node: Node2D = child as Node2D
			if node == null or not str(node.name).is_valid_int():
				continue
			if HeistRules.node_flag(node, HeistRules.CAUGHT_METHODS) \
					or (_heist != null and _heist.is_caught(str(node.name).to_int())):
				continue
			free += 1
			var pos: Vector2 = node.global_position
			if node.has_method(&"interaction_position"):
				pos = node.call(&"interaction_position")
			if _heist_in_zone(zone, pos):
				in_zone += 1
	return {"in_zone": in_zone, "free": free}


# =====================================================================================================================
# IS-015a — `--quit-on-heist-end=SEC` (S6 test arg; statistics runner). SEC seconds after `heist_finished` the process writes the dump
# (`--dump`; "exit_reason": "heist_end") and exits 0, like main.gd's `--quit-after` exit. Without the arg nothing is connected.
# =====================================================================================================================

const HEIST_END_EXIT_REASON := "heist_end"
var _heist_end_quit_armed: bool = false


func _heist_end_quit_bind() -> void:
	if Args.quit_on_heist_end < 0.0 or heist_finished.is_connected(_heist_end_quit_arm):
		return
	heist_finished.connect(_heist_end_quit_arm)


func _heist_end_quit_arm(_result: Dictionary) -> void:
	if _heist_end_quit_armed:
		return
	_heist_end_quit_armed = true
	get_tree().create_timer(Args.quit_on_heist_end).timeout.connect(_heist_end_quit)


func _heist_end_quit() -> void:
	register_dump_provider("exit_reason", func() -> String: return HEIST_END_EXIT_REASON)
	if not Args.dump_path.is_empty():
		var file: FileAccess = FileAccess.open(Args.dump_path, FileAccess.WRITE)
		if file == null:
			push_error("Game: döküm yazılamadı: %s (%s)" % [Args.dump_path, error_string(FileAccess.get_open_error())])
		else:
			file.store_string(JSON.stringify(collect_dump(), "  ", true))
			file.close()
	Net.leave()
	get_tree().quit(0)


# =====================================================================================================================
# IS-058b — session seed (S3 addendum). The host picks a seed for every job (each level start: first load, "Again" / restart, level
# change) right before the level is instantiated; NPC code on the host derives its random streams from it (SessionSeed.derive: owner
# agenda, population schedule, civilian routes). Policy (core/session_seed.gd): `--seed=N` -> N (later jobs of the process: derived
# from N and the job index); automation (`--bot`, `--brain`, `--dump`, `--quit-after`, or a script main loop such as the unit test
# runner) -> 0 = today's behaviour; otherwise a new random seed per job. Clients do not need it (NPC randomness runs on the host only):
# not replicated, a client reads 0. Dump key "session_seed" (host only).
# =====================================================================================================================

var _session_seed: int = 0
var _session_jobs: int = 0
var _session_rng := RandomNumberGenerator.new()


## Seed of the current job (host); 0 = data seeds unchanged. A client reads 0 (not replicated).
func session_seed() -> int:
	return _session_seed


## Whether this process is an automation/test run for the seed policy.
func _session_seed_automated() -> bool:
	if Args.is_automated() or not Args.bot_path.is_empty() or not Args.brain.is_empty():
		return true
	var loop: MainLoop = Engine.get_main_loop()
	return loop != null and loop.get_script() != null  # `-s` script (unit test runner, tools)


func _session_seed_new_job() -> void:
	if _session_jobs == 0:
		_session_rng.randomize()
	_session_seed = SessionSeed.pick(_session_jobs, Args.run_seed_given, Args.run_seed, _session_seed_automated(), _session_rng)
	_session_jobs += 1
