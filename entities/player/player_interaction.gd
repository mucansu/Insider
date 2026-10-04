class_name PlayerInteraction
extends Node
## Player's interaction side (US-005; S7): runs on the local player only. Player calls `tick` each physics step; this node finds the nearest
## eligible nearby Interactable (rules in InteractionRules, no tolerance), sends a request to the host on `interact` press (leading edge of
## the hold; bot `hold` step too), and a cancel on release or on leaving the target (+ S2 tolerance). The result comes from the host (S2):
## the client produces no result itself. Progress shows locally at once (GDD §12): `started` fires on press; if the host rejects or
## cancels, `finished(false)` (no penalty, zero progress). A release in the last TIME_TOLERANCE of the duration waits for the host's
## decision (may count as done); an earlier release emits `finished(false)` at once. Each request carries a sequence number: a late old
## decision does not finish a new request. Player signals (interaction_*; HUD contract) are emitted from these.
## US-010 (prompt lines): each Interactable is bound to an input action (`input_action`: `interact` E, `intimidate` Q). The target is picked
## per action (nearest eligible); `target_changed` reports the E line, `alt_target_changed` the Q line (two lines). One interaction runs at
## a time; a running interaction ends when its own action's key is released.
## US-045: an own component marked `self_only` (the hand's Q "Bırak") is a target for this player only; another player's never is.

signal target_changed(action_key: String)
## Target of the Q (`intimidate`) line changed (empty = none; US-010).
signal alt_target_changed(action_key: String)
signal started(action_key: String, duration: float)
signal finished(success: bool)

## If the host decision is this late after release (connection trouble) the interaction counts as failed.
const VERDICT_TIMEOUT_SEC := 2.0
## Extra wait for the decision on release, on top of TIME_TOLERANCE (s): the host's progress may lead the local time by network jitter;
## at the boundary local "aborted" must not contradict the host's "done".
const RELEASE_MARGIN := 0.1
## Input action of the Q line (S5; Interactable.input_action); every other action is the E line.
const ALT_ACTION := &"intimidate"

var _target: Interactable = null
var _target_key: String = ""
var _alt_target: Interactable = null
var _alt_target_key: String = ""
## Whether the running interaction was started with Q (release is checked on that key).
var _active_alt: bool = false
var _was_alt_held: bool = false
var _active: Interactable = null
var _seq: int = 0
var _elapsed: float = 0.0
var _hold_time: float = 0.0
var _released: bool = false
var _waited: float = 0.0
var _was_held: bool = false
var _started_at: float = 0.0
## Dump (S6 "interaction"): requests sent, successes, failures; result latency of the last success
## (time from press to host decision minus hold time ~ RTT; ms).
var _requests: int = 0
var _successes: int = 0
var _failures: int = 0
var _result_delay_ms: float = -1.0


## One physics step of the local player: `held` = interact held, `actor_pos` = global position; `alt_held` = intimidate
## (Q) held (US-010).
func tick(delta: float, held: bool, actor_pos: Vector2, peer_id: int, actor_tags: Dictionary = {},
		alt_held: bool = false) -> void:
	if _active != null and not is_instance_valid(_active):
		_active = null
		_finish(false)
	if _active != null:
		_elapsed += delta
		var still: bool = alt_held if _active_alt else held
		if _released:
			_waited += delta
			if _waited > VERDICT_TIMEOUT_SEC:
				_finish(false)
		elif not still or not _active.in_reach(actor_pos):
			_release()
	if _active == null:
		_select_target(actor_pos, peer_id, actor_tags)
		if held and not _was_held and _target != null:
			_start(_target, false)
		elif alt_held and not _was_alt_held and _alt_target != null:
			_start(_alt_target, true)
	_was_held = held
	_was_alt_held = alt_held


## Whether an interaction is running (request sent, no decision yet).
func is_active() -> bool:
	return _active != null


## Action key of the current target (empty = no target).
func target_key() -> String:
	return _target_key


## Action key of the Q line's target (empty = none; US-010).
func alt_target_key() -> String:
	return _alt_target_key


func stats() -> Dictionary:
	return {
		"requests": _requests,
		"successes": _successes,
		"failures": _failures,
		"result_delay_ms": _result_delay_ms,
	}


func _select_target(actor_pos: Vector2, peer_id: int, actor_tags: Dictionary) -> void:
	var candidates: Array[Interactable] = []
	var positions := PackedVector2Array()
	var alt_candidates: Array[Interactable] = []
	var alt_positions := PackedVector2Array()
	var actor: Node = get_parent()
	if actor != null and not actor.is_in_group(Interactable.ACTOR_GROUP):
		actor = null
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var item: Interactable = node as Interactable
		if item == null:
			continue
		var own: bool = actor != null and actor.is_ancestor_of(item)
		if own != item.self_only:
			continue  # own components (PULL, US-008) are never targets, except the actor's own tools (US-045 drop); never others' tools
		if item.can_start(peer_id, actor_pos, actor_tags):
			if item.input_action == ALT_ACTION:
				alt_candidates.append(item)
				alt_positions.append(item.global_position)
			else:
				candidates.append(item)
				positions.append(item.global_position)
	var index: int = InteractionRules.nearest(actor_pos, positions)
	var target: Interactable = candidates[index] if index >= 0 else null
	var key: String = target.action_key if target != null else ""
	_target = target
	if key != _target_key:
		_target_key = key
		target_changed.emit(key)
	var alt_index: int = InteractionRules.nearest(actor_pos, alt_positions)
	var alt_target: Interactable = alt_candidates[alt_index] if alt_index >= 0 else null
	var alt_key: String = alt_target.action_key if alt_target != null else ""
	_alt_target = alt_target
	if alt_key != _alt_target_key:
		_alt_target_key = alt_key
		alt_target_changed.emit(alt_key)


func _start(target: Interactable, alt: bool) -> void:
	_seq += 1
	_active = target
	_active_alt = alt
	_elapsed = 0.0
	_hold_time = target.hold_time
	_released = false
	_waited = 0.0
	_started_at = Time.get_ticks_usec() / 1_000_000.0
	_requests += 1
	target.request_finished.connect(_on_verdict)
	started.emit(target.action_key, maxf(target.hold_time, 0.0))
	target.request_start(_seq)  # on the host the decision can come in the same call (instant action)


func _release() -> void:
	if _hold_time > 0.0:
		_active.request_cancel(_seq)
		if _active == null:
			return  # on the host the decision came in the same call
	if InteractionRules.release_completes(_elapsed + RELEASE_MARGIN, _hold_time):
		_released = true  # last margin: host may count it done, wait for the decision
		_waited = 0.0
	else:
		_finish(false)


func _on_verdict(seq: int, success: bool) -> void:
	if seq != _seq or _active == null:
		return
	if success:
		_result_delay_ms = (Time.get_ticks_usec() / 1_000_000.0 - _started_at - _hold_time) * 1000.0
	_finish(success)


func _finish(success: bool) -> void:
	if _active != null and is_instance_valid(_active) and _active.request_finished.is_connected(_on_verdict):
		_active.request_finished.disconnect(_on_verdict)
	_active = null
	if success:
		_successes += 1
	else:
		_failures += 1
	finished.emit(success)
