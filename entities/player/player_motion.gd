class_name PlayerMotion
extends RefCounted
## Player movement rules (US-004 AC2): mode selection, speed per mode, acceleration and look direction. Node-free, values only (KR-003;
## movable to core/ later). Player calls it each physics step.

enum Mode { WALK, SNEAK, SPRINT }

## Input direction shorter than this counts as "no movement" (the dead zone is in the InputMap; this is only a numeric margin).
const MOVE_EPSILON := 0.01


## Mode selection: sneak beats sprint (both keys held stays quiet).
static func mode_for(sneak: bool, sprint: bool) -> int:
	if sneak:
		return Mode.SNEAK
	if sprint:
		return Mode.SPRINT
	return Mode.WALK


## Full speed of a mode (px/s); an unknown mode counts as walk.
static func speed_for(tuning: PlayerTuning, mode: int) -> float:
	match mode:
		Mode.SNEAK:
			return tuning.sneak_speed
		Mode.SPRINT:
			return tuning.sprint_speed
	return tuning.walk_speed


## Velocity at the end of a physics step. Target = direction (length <= 1: partial speed on an analog stick) x mode speed x
## `speed_scale` (US-037 NPC contact slowdown; 1 = none); approaches with `acceleration` when speeding up, `deceleration` when slowing
## down and with no input.
static func step_velocity(current: Vector2, direction: Vector2, mode: int, tuning: PlayerTuning,
		delta: float, speed_scale: float = 1.0) -> Vector2:
	var dir: Vector2 = direction.limit_length(1.0)
	if dir.length() < MOVE_EPSILON:
		return current.move_toward(Vector2.ZERO, tuning.deceleration * delta)
	var target: Vector2 = dir * speed_for(tuning, mode) * maxf(speed_scale, 0.0)
	var rate: float = tuning.acceleration if target.length() >= current.length() else tuning.deceleration
	return current.move_toward(target, rate * delta)


## Look direction (unit vector): the input direction if any, else the previous direction is kept.
static func facing_for(current: Vector2, direction: Vector2) -> Vector2:
	if direction.length() < MOVE_EPSILON:
		return current
	return direction.normalized()
