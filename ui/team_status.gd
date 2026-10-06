class_name TeamStatus
extends RefCounted
## Crew status for the HUD (IS-110, GB-12): which player is held (temporary, rescue window counting down), caught (permanent) or
## escaped. Pure display model; no new network field. Inputs:
## - S3 `session_event` kinds `player_held {peer, window}`, `player_caught {peer, by}`, `player_rescued {peer, by}` (every peer),
## - the local player's `status_changed(state)` + `hold_left()` (STATUS_* values; may arrive before or after the event),
## - S3 `heist_finished` result (`players["<peer>"].escaped / caught`).
## The window comes from the event (`window`, the owner's hold setting: 6 s, repeat 3 s) or the local player's `hold_left()`; it is
## counted down locally from the moment the status change is seen (display only, the host decides the catch).

enum Badge { NONE, HELD, CAUGHT, ESCAPED }

const EVENT_HELD := &"player_held"
const EVENT_CAUGHT := &"player_caught"
const EVENT_RESCUED := &"player_rescued"
## The player's status values (US-008 `status_changed(state: int)`: FREE/HELD/CAUGHT); ui does not depend on entities/, so mirrored
## here; tests/unit/test_ui_team_status.gd checks they match.
const STATUS_FREE := 0
const STATUS_HELD := 1
const STATUS_CAUGHT := 2
const PEER_FIELD := "peer"
const WINDOW_FIELD := "window"
## Window not known yet (status seen before the event); the event fills it.
const UNKNOWN_LEFT := -1.0

## peer -> Badge
var _badge: Dictionary = {}
## peer -> seconds left in the hold window (HELD only; UNKNOWN_LEFT if not known yet)
var _left: Dictionary = {}


func badge(peer: int) -> int:
	return int(_badge.get(peer, Badge.NONE))


## Whole seconds left in the hold window, rounded up (6..1); -1 if not held or the window is not known yet.
func seconds_left(peer: int) -> int:
	if badge(peer) != Badge.HELD:
		return -1
	var left: float = float(_left.get(peer, UNKNOWN_LEFT))
	return -1 if left < 0.0 else ceili(left)


## Applies a session event; true if a badge changed. Other kinds are ignored.
func apply_event(kind: StringName, data: Dictionary) -> bool:
	if typeof(data.get(PEER_FIELD)) != TYPE_INT:
		return false
	var peer: int = int(data[PEER_FIELD])
	match kind:
		EVENT_HELD:
			var window: float = float(data.get(WINDOW_FIELD, UNKNOWN_LEFT))
			return _hold(peer, window if window >= 0.0 else UNKNOWN_LEFT)
		EVENT_CAUGHT:
			return _set_badge(peer, Badge.CAUGHT)
		EVENT_RESCUED:
			return _set_badge(peer, Badge.NONE)
	return false


## Applies the local player's status (STATUS_*) with its `hold_left()` (negative if unknown); true if anything changed.
func apply_status(peer: int, state: int, left: float) -> bool:
	match state:
		STATUS_HELD:
			return _hold(peer, left if left > 0.0 else UNKNOWN_LEFT)
		STATUS_CAUGHT:
			return _set_badge(peer, Badge.CAUGHT)
	# FREE: a rescue (an escaped/caught badge from the result stays)
	return _set_badge(peer, Badge.NONE) if badge(peer) == Badge.HELD else false


## Heist result (S3): escaped -> ESCAPED, caught -> CAUGHT; open hold windows end. True if anything changed.
func apply_result(result: Dictionary) -> bool:
	var players: Variant = result.get("players")
	if typeof(players) != TYPE_DICTIONARY:
		return false
	var changed: bool = false
	for key: Variant in players:
		if typeof(players[key]) != TYPE_DICTIONARY or not str(key).is_valid_int():
			continue
		var rec: Dictionary = players[key]
		var peer: int = int(str(key))
		if bool(rec.get("caught", false)):
			changed = _set_badge(peer, Badge.CAUGHT) or changed
		elif bool(rec.get("escaped", false)):
			changed = _set_badge(peer, Badge.ESCAPED) or changed
		elif badge(peer) == Badge.HELD:
			changed = _set_badge(peer, Badge.NONE) or changed
	return changed


## Counts hold windows down; true if a displayed whole second changed.
func advance(delta: float) -> bool:
	var changed: bool = false
	for peer: int in _left.keys():
		var left: float = float(_left[peer])
		if left < 0.0:
			continue
		var before: int = ceili(left)
		left = maxf(left - maxf(delta, 0.0), 0.0)
		_left[peer] = left
		changed = changed or ceili(left) != before
	return changed


func clear() -> void:
	_badge.clear()
	_left.clear()


## HELD from another state starts the window; a repeat (event after status or vice versa) only fills an unknown window.
func _hold(peer: int, left: float) -> bool:
	if badge(peer) == Badge.HELD:
		if float(_left.get(peer, UNKNOWN_LEFT)) < 0.0 and left >= 0.0:
			_left[peer] = left
			return true
		return false
	if badge(peer) == Badge.CAUGHT:
		return false  # caught is permanent; a late hold notice does not undo it
	_badge[peer] = Badge.HELD
	_left[peer] = left
	return true


func _set_badge(peer: int, value: int) -> bool:
	if badge(peer) == value:
		return false
	if value == Badge.NONE:
		_badge.erase(peer)
	else:
		_badge[peer] = value
	_left.erase(peer)
	return true
