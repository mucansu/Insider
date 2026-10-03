extends Node
## Noise (autoload `NoiseBus`, contract S8 — docs/notes/mimari.md; US-009). Radii and kinds come from
## `data/noise_profile.tres` (NoiseProfile), rules from `core/noise_rules.gd` (NoiseRules, nodeless).
##
## Flow: `emit_noise` spreads directly on the host; a client forwards it to the host via reliable RPC (S2). The host validates it in
## `host_request`: sender = `get_remote_sender_id()`, source 0 or the sender itself, movement kinds only, radius taken from the host's
## definition, position within NoiseRules.POSITION_TOLERANCE of the host-known actor position, rate-limited per sender.
## Spreading: the host calls `hear_noise(pos, radius, kind)` on `noise_listener` group nodes (duck typing) and sends a visual ring event to
## everyone (`authority`, unreliable, visual only); each peer emits `noise_shown` and adds a ring visual (`RING_SCENE`, loaded by path).
## Dump (S6, `--dump` only): "noise" key — `stats()`.

## Ring event (on every peer; on the host together with local spreading).
signal noise_shown(pos: Vector2, radius: float, kind: StringName)

const LISTENER_GROUP := PhysicsLayers.NOISE_LISTENER_GROUP
const LISTENER_METHOD := &"hear_noise"
## Interaction actor group (S7 `Interactable.ACTOR_GROUP`): `interaction_position()` gives the host's latest known position.
## The autoload does not know entities/; the name comes from the single source in core/ (PhysicsLayers, §6, duck typing).
const ACTOR_GROUP := PhysicsLayers.ACTORS_GROUP
const ACTOR_POSITION_METHOD := &"interaction_position"
const RING_SCENE := "res://entities/fx/noise_ring.tscn"
const DUMP_KEY := "noise"

var _profile: NoiseProfile = null
var _ring_scene: PackedScene = null
## Counters (dump): sounds requested locally, client requests accepted/rejected-by-reason on the host,
## sounds dispatched to listeners and listener calls on the host, ring events seen on this peer.
var _emitted: int = 0
var _accepted: int = 0
var _rejected: Dictionary = {}
var _dispatched: int = 0
var _delivered: int = 0
var _rings: int = 0
var _ring_kinds: Dictionary = {}
## Host: sender peer -> time of its last accepted request (seconds; rate limit).
var _last_accept: Dictionary = {}


func _ready() -> void:
	_profile = NoiseProfile.load_default()
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, stats)


## Called on a client it forwards to the host; the host calls `hear_noise(pos, radius, kind)` on `noise_listener`
## group nodes and sends a visual ring event to everyone.
## Zero-radius sounds are not spread. On a client `radius` is only a local pre-filter: the host uses the kind's radius from the profile.
## `source_peer` is the emitter's peer id (0 = world).
func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void:
	if radius <= 0.0 or not pos.is_finite():
		return
	if _is_host():
		_emitted += 1
		_dispatch(pos, radius, kind)
	elif _is_connected():
		_emitted += 1
		_rpc_request.rpc_id(1, pos, kind, source_peer)


## Host only: validates `sender`'s noise request and spreads it if accepted (RPC body; tests use this path too).
## No-op returning NO_ACTOR if not the host. `now`: request time (seconds; < 0 = use the clock; tests pass it).
func host_request(sender: int, pos: Vector2, kind: StringName, source_peer: int,
		now: float = -1.0) -> NoiseRules.Result:
	if not _is_host():
		return NoiseRules.Result.NO_ACTOR
	if now < 0.0:
		now = Time.get_ticks_usec() / 1_000_000.0
	var radius: float = _profile.radius_for(kind)
	var actor: Node = _actor(sender)
	var known: Vector2 = Vector2.INF
	if actor != null:
		var at: Variant = actor.call(ACTOR_POSITION_METHOD)
		if at is Vector2:
			known = at
	var result: NoiseRules.Result = NoiseRules.check_client(sender, source_peer,
		NoiseProfile.is_movement_kind(kind), radius, pos, known, actor != null)
	if result == NoiseRules.Result.OK and _last_accept.has(sender):
		if not NoiseRules.within_rate(now - float(_last_accept[sender]), _profile.step_interval):
			result = NoiseRules.Result.RATE
	if result != NoiseRules.Result.OK:
		var reason: String = NoiseRules.result_name(result)
		_rejected[reason] = int(_rejected.get(reason, 0)) + 1
		return result
	_last_accept[sender] = now
	_accepted += 1
	_dispatch(pos, radius, kind)
	return result


## Dump/diagnostic counters (S6 "noise").
func stats() -> Dictionary:
	var rejected_total: int = 0
	for reason: String in _rejected:
		rejected_total += int(_rejected[reason])
	return {
		"emitted": _emitted,
		"accepted": _accepted,
		"rejected": _rejected.duplicate(),
		"rejected_total": rejected_total,
		"dispatched": _dispatched,
		"delivered": _delivered,
		"rings": _rings,
		"ring_kinds": _ring_kinds.duplicate(),
	}


# --- RPC (S2: client→host any_peer + sender validation; host→all authority, visual: unreliable) ---

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(pos: Vector2, kind: StringName, source_peer: int) -> void:
	host_request(multiplayer.get_remote_sender_id(), pos, kind, source_peer)


@rpc("authority", "call_remote", "unreliable")
func _rpc_ring(pos: Vector2, radius: float, kind: StringName) -> void:
	_show_ring(pos, radius, kind)


# --- host ---

func _dispatch(pos: Vector2, radius: float, kind: StringName) -> void:
	_dispatched += 1
	for node: Node in get_tree().get_nodes_in_group(LISTENER_GROUP):
		if node.has_method(LISTENER_METHOD):
			_delivered += 1
			node.call(LISTENER_METHOD, pos, radius, kind)
	_show_ring(pos, radius, kind)
	if not multiplayer.get_peers().is_empty():
		_rpc_ring.rpc(pos, radius, kind)


func _actor(peer_id: int) -> Node:
	if peer_id <= 0:
		return null
	for node: Node in get_tree().get_nodes_in_group(ACTOR_GROUP):
		if node.get_multiplayer_authority() == peer_id and node.has_method(ACTOR_POSITION_METHOD):
			return node
	return null


# --- every peer ---

func _show_ring(pos: Vector2, radius: float, kind: StringName) -> void:
	_rings += 1
	var key: String = str(kind)
	_ring_kinds[key] = int(_ring_kinds.get(key, 0)) + 1
	noise_shown.emit(pos, radius, kind)
	var level: Node = Game.current_level()
	if level == null or not level.is_inside_tree():
		return
	if _ring_scene == null:
		_ring_scene = load(RING_SCENE) as PackedScene
		if _ring_scene == null:
			push_error("NoiseBus: halka sahnesi yüklenemedi: " + RING_SCENE)
			return
	var ring: Node2D = _ring_scene.instantiate() as Node2D
	if ring == null:
		return
	level.add_child(ring)
	ring.global_position = pos
	if ring.has_method(&"setup"):
		ring.call(&"setup", radius)


func _is_host() -> bool:
	return multiplayer.is_server()


func _is_connected() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
