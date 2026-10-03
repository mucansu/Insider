extends Node
## Network layer (autoload `Net`, contract S1 — docs/notes/mimari.md).
## Host/join/leave on top of Godot's high-level multiplayer (SceneMultiplayer). The transport (ENet today, Steam in Phase 5) is visible
## only in `_create_peer()` and the `_transport_*` helpers of this file; no other file touches transport classes.
##
## Signal semantics:
## - `peer_connected` / `peer_disconnected`: a remote peer admitted to the session (handshake done) arrived/left;
##   emitted on a client for the host (1) and other clients too.
## - `connected_to_host`: the client was accepted (incl. Game handshake); `is_online()` is now true.
## - `connection_failed`: a join attempt ended without being accepted (bad address, timeout, rejection).
## - `host_disconnected`: an accepted client lost the host. While emitted `local_peer_id()` still returns the old id (for the dump);
##   right after the signal the session goes offline.
## `leave()` emits no signal; Game notices the end of the session from the `is_online()` transition.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_host()
signal connection_failed()
signal host_disconnected()

## Upper bound of a join attempt (ms). ENet rounds it to its retry steps (0.5/1.5/3.5/7.5 s...): 5000 -> connection_failed after ~7.5 s
## on an unresponsive address. Once accepted, the transport's default timeouts are restored.
var connect_timeout_ms: int = 5000

## ENet packet throttle (interval ms, acceleration, deceleration). ENet treats RTT jitter as congestion and dropped unreliable packets
## (position sync); at low latency throttle fell 32 -> 0 and cut sync for seconds (US-001 t2). Deceleration 0 = throttle never rises;
## ENet's reliable-channel control and the game's low bandwidth (20 Hz positions) cover congestion.
const THROTTLE_INTERVAL_MS := 5000
const THROTTLE_ACCELERATION := 32
const THROTTLE_DECELERATION := 0

## Ping measurement (IS-026): every PING_INTERVAL_USEC the host sends each peer, and a client the host, a timestamped echo RPC. The app polls the
## network once per frame, so each sample includes a frame wait (+30-60 ms at windowed 30 fps, 100+ ms on a hitch). Displayed value (_ping_estimate_ms):
##   max(median of the last PING_WINDOW samples, age of the second-oldest unanswered request)
## - Median: gives the middle of the real RTT under jitter (min showed below RTT on a harsh network and suppressed the HUD warning);
##   outlier (hitch) samples making up less than half the window do not inflate it.
## Timestamp: stamped at rpc_id time; request and reply each wait for the next poll, so two frame waits add up (~+17-33 ms at 60 fps) but never go
## below network RTT. The queue is not flushed by hand: a mid-frame flush split the frame's packets into separate datagrams and made auth ERRORs
## on a newly joined client more frequent on a harsh network (IS-026 t3 measurement).
## - Unanswered age raises the value when the far end (or path) stalls, so the HUD does not freeze without samples.
## - Second-oldest request: ping/pong is unreliable; a single lost request stays oldest but later ones are answered on time, so the value does not
##   jump. On a healthy link its age cannot exceed RTT (even if RTT > interval); only two consecutive requests unanswered longer than RTT trigger it.
##   A reply drops the pending requests older than it as lost.
## Start-up: an unreliable ping reaching the far end before its SceneMultiplayer handshake (auth) finishes makes the engine print an ERROR
## (an unordered ping can overtake a retransmitted auth packet). So on peer_connected the host sends a reliable "ready" RPC (same ordered channel as auth);
## the client starts pinging on receiving it, and the host pings a peer only after that peer's first valid ping request.
## Channel: ping messages use a separate unordered unreliable channel (on the reliable ordered one a lost ping would stall the game events behind it; Steam turns unreliable_ordered into reliable).
const PING_INTERVAL_USEC := 250_000
const PING_WINDOW := 16
## Max pending requests (per peer). When exceeded the two oldest are kept (age measure) and the third is dropped.
const PING_PENDING_MAX := 8
## The host does not answer ping requests from a peer arriving more often than this (flood protection).
const PING_MIN_REQUEST_GAP_USEC := 100_000
## Ping/pong transport channel (game RPCs use 0). Steam lanes: only 0-2 usable (docs/arastirma/
## steam-ag.md; steam/multiplayer_peer/max_channels >= channel + 2).
const PING_CHANNEL := 2

var _peer: MultiplayerPeer = null
var _local_id: int = 0
var _hosting: bool = false
## Whether the client was admitted to the session (connected_to_server received).
var _connected: bool = false
var _hostname_re: RegEx = RegEx.create_from_string(
		"^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$")
var _ping_next_usec: int = 0
var _ping_seq: int = 0
## peer -> {seq: send usec}
var _ping_pending: Dictionary[int, Dictionary] = {}
## peer -> last PING_WINDOW round trips (usec)
var _ping_samples: Dictionary[int, Array] = {}
## Host: peer -> time of its last answered request (usec)
var _ping_last_request: Dictionary[int, int] = {}
## Peers that can be pinged (see "Start-up").
var _ping_ready: Dictionary[int, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Opens a session; `max_peers` is the total player count including the host (at least 1).
func host(port: int = 7777, max_peers: int = 4) -> Error:
	if _peer != null:
		push_warning("Net.host: zaten bir oturum var; önce leave()")
		return ERR_ALREADY_IN_USE
	if port < 1 or port > 65535 or max_peers < 1:
		push_warning("Net.host: geçersiz port/max_peers (%d, %d)" % [port, max_peers])
		return ERR_INVALID_PARAMETER
	var peer: MultiplayerPeer = _create_peer()
	var err: Error = _transport_listen(peer, port, max_peers)
	if err != OK:
		push_warning("Net.host: %d portu açılamadı (%s)" % [port, error_string(err)])
		return err
	_peer = peer
	_hosting = true
	_connected = false
	_local_id = 1
	multiplayer.multiplayer_peer = peer
	return OK


## Starts connecting to the host. The result arrives as `connected_to_host` or `connection_failed`; on an invalid address
## or transport failure an error is returned and `connection_failed` is still emitted one frame later.
func join(address: String, port: int = 7777) -> Error:
	if _peer != null:
		push_warning("Net.join: zaten bir oturum var; önce leave()")
		return ERR_ALREADY_IN_USE
	var ip: String = _resolve(address)
	if ip.is_empty() or port < 1 or port > 65535:
		push_warning("Net.join: geçersiz adres '%s:%d'" % [address, port])
		connection_failed.emit.call_deferred()
		return ERR_CANT_RESOLVE if port >= 1 and port <= 65535 else ERR_INVALID_PARAMETER
	var peer: MultiplayerPeer = _create_peer()
	var err: Error = _transport_connect(peer, ip, port)
	if err != OK:
		push_warning("Net.join: bağlantı başlatılamadı (%s)" % error_string(err))
		connection_failed.emit.call_deferred()
		return err
	_peer = peer
	_hosting = false
	_connected = false
	_local_id = peer.get_unique_id()
	multiplayer.multiplayer_peer = peer
	return OK


## Leaves the session (a host closes it; clients get host_disconnected). Emits no signal.
func leave() -> void:
	if _peer == null:
		return
	var peer: MultiplayerPeer = _peer
	_reset()
	peer.close()
	# Closing and replacing in the same call keeps SceneMultiplayer from emitting server_disconnected locally.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_host() -> bool:
	return _peer != null and _hosting


## Whether a host session is open or a client was accepted.
func is_online() -> bool:
	return _peer != null and (_hosting or _connected)


## Id in the session (host 1); 0 when no session.
func local_peer_id() -> int:
	return _local_id if _peer != null else 0


## 0 for the host; -1 if unknown. A client knows only its latency to the host (other clients -1).
## The value is the network round trip (ms, at least 1; see PING_* and _ping_estimate_ms); until the first reply (~quarter second)
## it is the transport's smoothed RTT.
func get_ping_ms(peer_id: int = 1) -> int:
	if not is_online():
		return -1
	if peer_id == _local_id:
		return 0
	if _hosting and not multiplayer.get_peers().has(peer_id):
		return -1
	if not _hosting and peer_id != 1:
		return -1
	var estimate: int = _ping_estimate_ms(
			_ping_samples.get(peer_id, []), _ping_pending.get(peer_id, {}), Time.get_ticks_usec())
	if (_ping_samples.get(peer_id, []) as Array).is_empty():
		return maxi(estimate, _transport_rtt_ms(peer_id))
	return estimate


## Ping to display (ms, at least 1): max(median of the sample window, age of the unanswered second-oldest request);
## -1 if neither exists. `samples` in usec; `pending` {seq: send usec}, ascending by sequence number.
static func _ping_estimate_ms(samples: Array, pending: Dictionary, now_usec: int) -> int:
	var value: int = -1
	if not samples.is_empty():
		value = _median_usec(samples)
	if pending.size() >= 2:
		var second_oldest: int = int(pending[pending.keys()[1]])
		value = maxi(value, now_usec - second_oldest)
	if value < 0:
		return -1
	return maxi(1, roundi(float(value) / 1000.0))


## Median; for an even count the mean of the two middle values (unbiased under symmetric jitter; the lower middle would pull down).
@warning_ignore("integer_division")
static func _median_usec(samples: Array) -> int:
	var sorted: Array = samples.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	if sorted.size() % 2 == 1:
		return int(sorted[mid])
	return (int(sorted[mid - 1]) + int(sorted[mid])) / 2


## Source of the measurement (for dump and tests): {"source": "ping" (echo samples) | "transport" (transport RTT until the first reply)
## | "self" | "none", "samples": number of echo samples in the window}.
func get_ping_info(peer_id: int = 1) -> Dictionary:
	if get_ping_ms(peer_id) < 0:
		return {"source": "none", "samples": 0}
	if peer_id == _local_id:
		return {"source": "self", "samples": 0}
	var count: int = (_ping_samples.get(peer_id, []) as Array).size()
	return {"source": "ping" if count > 0 else "transport", "samples": count}


# --- ping measurement ---

func _process(_delta: float) -> void:
	if not is_online():
		return
	var now: int = Time.get_ticks_usec()
	if now < _ping_next_usec:
		return
	_ping_next_usec = now + PING_INTERVAL_USEC
	for peer_id: int in multiplayer.get_peers():
		if _ping_ready.has(peer_id) and (_hosting or peer_id == 1):
			_ping_seq += 1
			_note_ping_request(peer_id, _ping_seq, Time.get_ticks_usec())
			_rpc_ping.rpc_id(peer_id, _ping_seq)


## Adds a sent request to the pending ones; if the table is full the two oldest (age measure) are kept and the third is dropped.
func _note_ping_request(peer_id: int, seq: int, now_usec: int) -> void:
	var pending: Dictionary = _ping_pending.get_or_add(peer_id, {})
	pending[seq] = now_usec
	while pending.size() > PING_PENDING_MAX:
		pending.erase(pending.keys()[2])


## Adds a sample if the reply belongs to a pending request (true); pending requests older than it are treated as lost and removed.
func _note_ping_reply(peer_id: int, seq: int, now_usec: int) -> bool:
	if not _ping_pending.has(peer_id):
		return false
	var pending: Dictionary = _ping_pending[peer_id]
	if not pending.has(seq):
		return false
	var sent_usec: int = int(pending[seq])
	for key: Variant in pending.keys():
		if int(key) <= seq:
			pending.erase(key)
	var samples: Array = _ping_samples.get_or_add(peer_id, [])
	samples.push_back(maxi(0, now_usec - sent_usec))
	while samples.size() > PING_WINDOW:
		samples.pop_front()
	return true


## Whether an echo request is answered: the host accepts it from any peer in the session (rate-limited by PING_MIN_REQUEST_GAP_USEC),
## a client only from the host (1).
func _accept_ping_request(sender: int, peers: PackedInt32Array, hosting: bool, now_usec: int) -> bool:
	if not peers.has(sender):
		return false
	if not hosting:
		return sender == 1
	if _ping_last_request.has(sender) and now_usec - _ping_last_request[sender] < PING_MIN_REQUEST_GAP_USEC:
		return false
	_ping_last_request[sender] = now_usec
	return true


@rpc("any_peer", "call_remote", "unreliable", PING_CHANNEL)
func _rpc_ping(seq: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _peer == null:
		return
	if not _accept_ping_request(sender, multiplayer.get_peers(), _hosting, Time.get_ticks_usec()):
		return
	if _hosting:
		_ping_ready[sender] = true
	_rpc_pong.rpc_id(sender, seq)


## Echo reply: counts only if it was sent to that peer and the reply was awaited.
@rpc("any_peer", "call_remote", "unreliable", PING_CHANNEL)
func _rpc_pong(seq: int) -> void:
	_note_ping_reply(multiplayer.get_remote_sender_id(), seq, Time.get_ticks_usec())


## Host to client: the handshake finished on both ends, pinging may start (reliable: arrives after auth).
@rpc("authority", "call_remote", "reliable")
func _rpc_ping_hello() -> void:
	if _peer != null and not _hosting and multiplayer.get_remote_sender_id() == 1:
		_ping_ready[1] = true


func _forget_ping(peer_id: int) -> void:
	_ping_ready.erase(peer_id)
	_ping_pending.erase(peer_id)
	_ping_samples.erase(peer_id)
	_ping_last_request.erase(peer_id)


# --- signal bridges ---

func _on_peer_connected(peer_id: int) -> void:
	if _peer == null:
		return
	if _hosting:
		_transport_tune_peer(peer_id)
		_rpc_ping_hello.rpc_id(peer_id)
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_forget_ping(peer_id)
	if _peer != null:
		peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	if _peer == null or _hosting:
		return
	_connected = true
	_transport_restore_timeouts(_peer)
	_transport_tune_peer(1)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	if _peer == null:
		return
	_drop_peer()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	if _peer == null:
		return
	if _hosting:
		push_warning("Net: host taşıması beklenmedik biçimde kapandı")
		_drop_peer()
		return
	var was_connected: bool = _connected
	_connected = false
	# The id is released after the signal, for the signal listeners (dump).
	if was_connected:
		host_disconnected.emit()
	else:
		connection_failed.emit()
	_drop_peer()


func _drop_peer() -> void:
	_reset()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _reset() -> void:
	_peer = null
	_hosting = false
	_connected = false
	_local_id = 0
	_ping_pending.clear()
	_ping_samples.clear()
	_ping_last_request.clear()
	_ping_ready.clear()
	_ping_next_usec = 0


## An IP as is, a valid hostname resolved to its IP; otherwise "".
func _resolve(address: String) -> String:
	var addr: String = address.strip_edges()
	if addr.is_valid_ip_address():
		return addr
	if addr.is_empty() or _hostname_re.search(addr) == null:
		return ""
	return IP.resolve_hostname(addr, IP.TYPE_ANY)


# --- transport (only here; in Phase 5 Steam is added behind these helpers) ---

func _create_peer() -> MultiplayerPeer:
	return ENetMultiplayerPeer.new()


func _transport_listen(peer: MultiplayerPeer, port: int, max_peers: int) -> Error:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	var err: Error = enet.create_server(port, maxi(1, max_peers - 1))
	if err == OK and max_peers == 1:
		enet.refuse_new_connections = true
	return err


func _transport_connect(peer: MultiplayerPeer, ip: String, port: int) -> Error:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	var err: Error = enet.create_client(ip, port)
	if err != OK:
		return err
	var server: ENetPacketPeer = enet.get_peer(1)
	if server != null and connect_timeout_ms > 0:
		# (limit, min, max) ms: for an unresponsive host the wait is bounded by connect_timeout_ms
		server.set_timeout(0, connect_timeout_ms, connect_timeout_ms)
	return OK


func _transport_restore_timeouts(peer: MultiplayerPeer) -> void:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	if enet == null:
		return
	var server: ENetPacketPeer = enet.get_peer(1)
	if server != null:
		server.set_timeout(0, 0, 0)  # 0 = ENet defaults


## Disables the connected peer's packet throttle (see THROTTLE_*); the setting is also sent to the far end via an ENet command.
func _transport_tune_peer(peer_id: int) -> void:
	var enet: ENetMultiplayerPeer = _peer as ENetMultiplayerPeer
	if enet == null:
		return
	var remote: ENetPacketPeer = enet.get_peer(peer_id)
	if remote != null:
		remote.throttle_configure(THROTTLE_INTERVAL_MS, THROTTLE_ACCELERATION, THROTTLE_DECELERATION)


func _transport_rtt_ms(peer_id: int) -> int:
	var enet: ENetMultiplayerPeer = _peer as ENetMultiplayerPeer
	if enet == null:
		return -1
	var remote: ENetPacketPeer = enet.get_peer(peer_id)
	if remote == null:
		return -1
	return roundi(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

