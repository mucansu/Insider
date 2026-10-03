class_name SightGate
extends RefCounted
## NPC visibility gate (US-011b AC5; GDD §6.5 "NPC visibility"; KR-022/KR-023). Node-free: decides how an NPC is drawn on this peer from the local player's sight; logic and collision are unaffected (drawing only).
## Per-step inputs: fully visible (visible tile and line of sight), in the peripheral zone (directional mode: peripheral tile and line of sight), NPC position and elapsed time (clock injected in tests).
##
## States and transitions:
## - FULL: full drawing (body, cone, suspicion indicator, bubbles, task icon).
## - SILHOUETTE: only a faint silhouette (MUTED alpha 0.5; no bubble/cone/arc), at the live position.
## - On leaving sight the last draw mode persists at the live position for `hold_sec` (0.2 s, GDD §12 slack; anti-flicker); regaining sight meanwhile ignores the gap.
## - Then GHOST: a still silhouette at the last seen position for `ghost_sec` (1.5 s), fading over the last `fade_sec` (0.3 s) (no fade with reduced motion: vanishes at the end). Regaining sight ends the ghost at once.
## - Then HIDDEN.
## Without fog (ownerless tests, menu) the caller always passes `seen = true`: everything is visible.

enum Mode { HIDDEN, FULL, SILHOUETTE, GHOST }

const HOLD_SEC := 0.2
const GHOST_SEC := 1.5
const FADE_SEC := 0.3
## Ghost and silhouette opacity (MUTED alpha 0.5).
const GHOST_ALPHA := 0.5

var hold_sec: float = HOLD_SEC
var ghost_sec: float = GHOST_SEC
var fade_sec: float = FADE_SEC
var reduce_motion: bool = false

var _mode: Mode = Mode.HIDDEN
## Last draw mode while seen (FULL or SILHOUETTE; persists during the hold time).
var _last_seen_mode: Mode = Mode.HIDDEN
var _ghost_position: Vector2 = Vector2.INF
var _unseen_for: float = INF


## One step. `full`: fully visible; `peripheral`: seen in the peripheral zone; `pos`: the NPC's current position.
## Returns this step's draw mode.
func step(full: bool, peripheral: bool, pos: Vector2, delta: float) -> Mode:
	if full or peripheral:
		_unseen_for = 0.0
		_last_seen_mode = Mode.FULL if full else Mode.SILHOUETTE
		_ghost_position = pos
		_mode = _last_seen_mode
		return _mode
	_unseen_for += maxf(delta, 0.0)
	if _last_seen_mode == Mode.HIDDEN:
		_mode = Mode.HIDDEN
	elif _unseen_for < hold_sec:
		_mode = _last_seen_mode  # drawn at the live position; the ghost still freezes at the last seen position
	elif _unseen_for < hold_sec + ghost_sec:
		_mode = Mode.GHOST
	else:
		_mode = Mode.HIDDEN
		_last_seen_mode = Mode.HIDDEN
	return _mode


func mode() -> Mode:
	return _mode


## Whether fully drawn (markers: cone, suspicion arc, bubbles and task icon only in this state).
func is_full() -> bool:
	return _mode == Mode.FULL


## Last seen position (the ghost freezes here); INF if never seen.
func ghost_position() -> Vector2:
	return _ghost_position


## Draw opacity factor: FULL 1; SILHOUETTE 0.5; GHOST 0.5 -> 0 over the last `fade_sec` (no fade with reduced motion); HIDDEN 0.
func alpha() -> float:
	match _mode:
		Mode.FULL:
			return 1.0
		Mode.SILHOUETTE:
			return GHOST_ALPHA
		Mode.GHOST:
			if reduce_motion or fade_sec <= 0.0:
				return GHOST_ALPHA
			var left: float = hold_sec + ghost_sec - _unseen_for
			return GHOST_ALPHA * clampf(left / fade_sec, 0.0, 1.0)
	return 0.0
