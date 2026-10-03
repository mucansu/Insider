class_name Interactable
extends Area2D
## Interaction component (US-005; S2, S7, KR-018): child (Area2D, interactables layer) of a prop. The prop keeps only its own state and
## connects to `completed` to apply the result; this component carries request RPCs, host validation, occupancy and the timer.
## Rules live in `InteractionRules` (core/, node-free).
## Flow (S7): local player finds the nearest eligible component with `can_start` -> `request_start(seq)` -> host validates (S2 range
## tolerance + requirement + occupancy + repeat cooldown), sets `busy_by` and counts time -> if the player releases, `request_cancel(seq)`
## (completes if within the last TIME_TOLERANCE), host cancels on leaving range (+ tolerance) or disconnect -> on timeout host emits
## `completed`. The requester gets the result via `request_finished(seq, success)` (only on that peer). A client cannot produce results:
## `completed`/`cancelled` are emitted on the host only.
## Actor: node in `ACTOR_GROUP`, authority on the requesting peer, exposing `interaction_position() -> Vector2` (latest host-known
## position); optional `interaction_tags() -> Dictionary`. Replicated state: `busy_by` (0 = free) and `progress` (s), host-authoritative
## MultiplayerSynchronizer (on change, reliable; `SYNC_INTERVAL`). The prop derives `enabled` and `action_key` from its own replicated
## state on every peer. `busy_by` is "who is interacting" on every peer (`held_by`; remote player indicator).
## Host blocker (IS-014): prop may set `start_blocker` as `func() -> bool`; true during host validation rejects with `blocked`
## (client prompt filter ignores it: prompt stays visible). Public host API (`host_start`, `host_cancel`, `step`) is called by RPC
## bodies, local requests and the physics step; tests use the same path (§6: no outside access to `_` members).
## NPC use (US-008, additive): `host_use_by_npc(actor_pos)` - actorless instant action on the host (owner and neighbours open doors);
## only for non-hold, enabled, free components in range (+ S2 tolerance); emits `completed(0)` (peer 0 = NPC). Not counted in player
## request counters (`stats().npc_uses`). Obeys repeat cooldown and `start_blocker`; the prop defines open/close meaning (NPCs only open doors).
## Actor state (US-008 t2): host rejects requests from an actor exposing `is_free()` that is not free (held/caught) with `not_free` and
## cancels their ongoing interaction; the prop may set `actor_filter` as `func(peer_id, actor) -> bool` (false -> `actor` reject;
## e.g. PULL: a held player cannot start their own rescue).
## US-010 additions: `input_action` is which input triggers this component (S5: `interact` E or `intimidate` Q; the player shows a separate
## prompt per action, PlayerInteraction); `innocent` is a social action (buy, talk, send) not counted as tampering in the civilian
## multiplier table; `start_blocker` may take a peer (`func(peer_id: int) -> bool`; 0-arg legacy form valid; peer 0 for NPC use);
## `host_abort()` cancels the ongoing interaction on the host (e.g. owner interrupts a conversation).

## Host only.
signal completed(peer_id: int)
## Host only (release, out of range, no actor).
signal cancelled(peer_id: int)
## Requesting peer only: host's decision (seq is the request's sequence number).
signal request_finished(seq: int, success: bool)

const GROUP := PhysicsLayers.INTERACTABLES_GROUP
## Group of actors able to interact (players add themselves).
const ACTOR_GROUP := PhysicsLayers.ACTORS_GROUP
## Physics layer interactables (architecture §4: layer 4).
const LAYER_BIT := PhysicsLayers.INTERACTABLES
const SYNC_NAME := "InteractableSync"
const SYNC_INTERVAL := 0.1

@export var action_key: String = ""
@export var hold_time: float = 0.0
@export var interact_range: float = 40.0:
	set = _set_interact_range
@export var enabled: bool = true
@export var requirement: InteractionRequirement
## Triggering input action (S5; US-010): &"interact" (E) or &"intimidate" (Q, gamepad X).
@export var input_action: StringName = &"interact"
## Social action (US-010): while running it is not counted as tampering (TAMPER) in the civilian multiplier table.
@export var innocent: bool = false

## Replicated state (host writes).
var busy_by: int = 0
var progress: float = 0.0
## Optional host blocker: `func() -> bool` or `func(peer_id: int) -> bool` (true = cannot apply now; reject reason "blocked").
## Called on the host only, only while validating a new request.
var start_blocker: Callable = Callable()
## Optional host actor filter: `func(peer_id: int, actor: Node) -> bool` (false = reject "actor").
var actor_filter: Callable = Callable()

var _seq: int = 0
var _cooldown_left: float = 0.0
var _target := InteractionRules.Target.new()
## Range circle built by the component itself (null if the scene supplies its own shape); updated when range changes.
var _range_shape: CircleShape2D = null
## Host statistics (dump): requests, accepted (busy_by set), completed, cancelled and reject counts by reason.
var _requests: int = 0
var _accepted: int = 0
var _completed: int = 0
var _cancelled: int = 0
var _rejected: Dictionary = {}
var _npc_uses: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	if find_children("*", "CollisionShape2D", false, false).is_empty():
		_range_shape = CircleShape2D.new()
		_range_shape.radius = interact_range
		var holder := CollisionShape2D.new()
		holder.shape = _range_shape
		add_child(holder)
	add_child(_make_sync())


func _physics_process(delta: float) -> void:
	step(delta)


## Component held by `peer_id` (host-replicated `busy_by`); null if none. Works on every peer.
static func held_by(tree: SceneTree, peer_id: int) -> Interactable:
	if tree == null or peer_id <= 0:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var item: Interactable = node as Interactable
		if item != null and item.busy_by == peer_id:
			return item
	return null


## One time step: repeat cooldown decreases; on the host the ongoing interaction's time counts, and it is cancelled if the actor leaves
## range (+ S2 tolerance) or disconnects. Called by the physics step.
func step(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if busy_by == 0 or not _is_host():
		return
	var actor: Node = _actor(busy_by)
	if actor == null or not _actor_free(actor) or not InteractionRules.keeps_going(_spec(), _actor_position(actor)):
		_finish(false)
		return
	progress = InteractionRules.advance(progress, delta)
	if InteractionRules.is_complete(progress, hold_time):
		_finish(true)


## Client-side eligibility (no tolerance; for prompt and target selection). Host validates again.
func can_start(peer_id: int, actor_pos: Vector2, actor_tags: Dictionary = {}) -> bool:
	return InteractionRules.check(_spec(), peer_id, actor_pos, actor_tags) == InteractionRules.Result.OK


## Whether the actor is still in reach for the ongoing interaction (with S2 tolerance).
func in_reach(actor_pos: Vector2) -> bool:
	return InteractionRules.keeps_going(_spec(), actor_pos)


## 0..1 progress (from replicated state; visuals read it).
func progress_ratio() -> float:
	return InteractionRules.ratio(progress, hold_time) if busy_by != 0 else 0.0


## Local player: interaction request (direct on the host, RPC on a client).
func request_start(seq: int) -> void:
	if _is_host():
		host_start(multiplayer.get_unique_id(), seq)
	else:
		_rpc_start.rpc_id(1, seq)


## Local player: released or moved away.
func request_cancel(seq: int) -> void:
	if _is_host():
		host_cancel(multiplayer.get_unique_id(), seq)
	else:
		_rpc_cancel.rpc_id(1, seq)


## Host statistics (S6 dump; zero on a client). Invariants: requests = accepted + rejected_total;
## accepted = completed + cancelled + (1 if an interaction is ongoing).
func stats() -> Dictionary:
	var rejected_total: int = 0
	for reason: String in _rejected:
		rejected_total += int(_rejected[reason])
	return {
		"busy_by": busy_by,
		"requests": _requests,
		"accepted": _accepted,
		"completed": _completed,
		"cancelled": _cancelled,
		"rejected": _rejected.duplicate(),
		"rejected_total": rejected_total,
		"npc_uses": _npc_uses,
	}


# --- RPC (S2: client->host any_peer + sender validation; host->requester authority) ---

@rpc("any_peer", "call_remote", "reliable")
func _rpc_start(seq: int) -> void:
	host_start(multiplayer.get_remote_sender_id(), seq)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel(seq: int) -> void:
	host_cancel(multiplayer.get_remote_sender_id(), seq)


@rpc("authority", "call_remote", "reliable")
func _rpc_result(seq: int, success: bool) -> void:
	request_finished.emit(seq, success)


# --- host ---

## Host only (ignored otherwise): validates `peer_id`'s start request numbered `seq`, accepting or rejecting (RPC body; the host's own
## request goes through here too).
func host_start(peer_id: int, seq: int) -> void:
	if peer_id <= 0 or not _is_host():
		return
	if busy_by == peer_id:
		_seq = seq  # duplicate request from the same peer: ongoing interaction continues, decision goes out with the new sequence number
		return
	_requests += 1
	var actor: Node = _actor(peer_id)
	var refusal: String = _actor_refusal(peer_id, actor)
	if not refusal.is_empty():
		_rejected[refusal] = int(_rejected.get(refusal, 0)) + 1
		_send_result(peer_id, seq, false)
		return
	var result: InteractionRules.Result = InteractionRules.Result.NO_ACTOR
	if actor != null:
		var spec: InteractionRules.Target = _spec()
		spec.blocked = is_blocked_for(peer_id)
		result = InteractionRules.host_check(spec, peer_id, _actor_position(actor), _actor_tags(actor),
			_cooldown_left)
	if result != InteractionRules.Result.OK:
		var reason: String = InteractionRules.result_name(result)
		_rejected[reason] = int(_rejected.get(reason, 0)) + 1
		_send_result(peer_id, seq, false)
		return
	busy_by = peer_id
	progress = 0.0
	_seq = seq
	_accepted += 1
	if InteractionRules.is_complete(progress, hold_time):
		_finish(true)


## Host only: `peer_id` released. No effect unless it is that peer's ongoing interaction with the same sequence number; completes if within
## the last TIME_TOLERANCE, else cancels.
func host_cancel(peer_id: int, seq: int) -> void:
	if not _is_host() or busy_by != peer_id or seq != _seq:
		return  # already finished or someone else's interaction
	_finish(InteractionRules.release_completes(progress, hold_time))


## Host only: NPC's (actorless) instant use; if applied, emits `completed(0)` and returns true.
func host_use_by_npc(actor_pos: Vector2) -> bool:
	if not _is_host() or busy_by != 0 or hold_time > 0.0 or not enabled or _cooldown_left > 0.0:
		return false
	if not InteractionRules.keeps_going(_spec(), actor_pos):
		return false
	if is_blocked_for(0):
		return false
	_npc_uses += 1
	_cooldown_left = InteractionRules.REPEAT_COOLDOWN
	completed.emit(0)
	return true


## Host only: cancels the ongoing interaction (`cancelled` + failure result to the requester); no effect if idle.
func host_abort() -> void:
	if _is_host() and busy_by != 0:
		_finish(false)


## Host blocker for this peer (peer 0 = NPC): `start_blocker` may take 0 or 1 argument.
func is_blocked_for(peer_id: int) -> bool:
	if not start_blocker.is_valid():
		return false
	if start_blocker.get_argument_count() >= 1:
		return bool(start_blocker.call(peer_id))
	return bool(start_blocker.call())


## Finishes the interaction: progress reset (including aborted), signal emitted, result sent to the requester.
func _finish(success: bool) -> void:
	var peer_id: int = busy_by
	var seq: int = _seq
	busy_by = 0
	progress = 0.0
	if success:
		_completed += 1
		_cooldown_left = InteractionRules.REPEAT_COOLDOWN
		completed.emit(peer_id)
	else:
		_cancelled += 1
		cancelled.emit(peer_id)
	_send_result(peer_id, seq, success)


func _send_result(peer_id: int, seq: int, success: bool) -> void:
	if peer_id == multiplayer.get_unique_id():
		request_finished.emit(seq, success)
	elif multiplayer.get_peers().has(peer_id):
		_rpc_result.rpc_id(peer_id, seq, success)


func _set_interact_range(value: float) -> void:
	interact_range = value
	if _range_shape != null:
		_range_shape.radius = value


func _is_host() -> bool:
	return multiplayer.is_server()


func _actor(peer_id: int) -> Node:
	for node: Node in get_tree().get_nodes_in_group(ACTOR_GROUP):
		if node.get_multiplayer_authority() == peer_id and node.has_method(&"interaction_position"):
			return node
	return null


## Host actor check: empty = accept; else reject reason (`not_free`, `actor`).
func _actor_refusal(peer_id: int, actor: Node) -> String:
	if actor == null:
		return ""
	if not _actor_free(actor):
		return "not_free"
	if actor_filter.is_valid() and not bool(actor_filter.call(peer_id, actor)):
		return "actor"
	return ""


## Whether the actor is free (US-008: an actor without `is_free()` counts as free; duck typing).
static func _actor_free(actor: Node) -> bool:
	return not actor.has_method(&"is_free") or bool(actor.call(&"is_free"))


static func _actor_position(actor: Node) -> Vector2:
	var pos: Variant = actor.call(&"interaction_position")
	return pos if pos is Vector2 else Vector2.INF


static func _actor_tags(actor: Node) -> Dictionary:
	if not actor.has_method(&"interaction_tags"):
		return {}
	var tags: Variant = actor.call(&"interaction_tags")
	return tags if tags is Dictionary else {}


## Target state as the rules see it (side constraint comes back with the prop).
func _spec() -> InteractionRules.Target:
	_target.position = global_position
	_target.interact_range = interact_range
	_target.enabled = enabled
	_target.busy_by = busy_by
	_target.blocked = false
	if requirement != null:
		_target.side = requirement.side.rotated(global_rotation)
		_target.side_min = requirement.side_min
		_target.tag = requirement.required_tag
		_target.tier = requirement.min_tier
	else:
		_target.side = Vector2.ZERO
		_target.side_min = 0.0
		_target.tag = &""
		_target.tier = 0
	return _target


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:busy_by", ".:progress"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.delta_interval = SYNC_INTERVAL
	sync.replication_config = config
	return sync
