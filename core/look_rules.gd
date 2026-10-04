class_name LookRules
extends RefCounted
## Look direction rules (US-011b AC3; GDD §6.5, §2b; mimari.md S2). Node-free, angle values only (KR-003). `Player` updates its local look with these and
## broadcasts it as an 8-bit angle; the remote copy follows the angle interpolated under the same turn cap.
##
## - Turning: the shortest way to the target angle; `smoothing` > 0 gives exponential approach (keyboard-only player: toward the movement direction, k = 9, ~0.33 s; same as puppet turning), always capped per step by `max_rate` (rad/s; 240 deg/s).
## - Quantisation: angle [-π, π) -> 0..255 (1.4 deg steps); converting back yields the step itself (rounding, no drift).

## Number of angle steps (8-bit).
const STEPS := 256
## Smoothing coefficient for turning toward the movement direction for keyboard-only players (1/s; same as puppet `turn_smoothing`).
const KEYBOARD_SMOOTHING := 9.0
## Look input shorter than this is ignored (the dead zone is in the InputMap; this is only a numeric margin).
const INPUT_EPSILON := 0.01


## Converts an angle (rad) to a step 0..255.
static func quantize(angle: float) -> int:
	var step: float = TAU / STEPS
	return posmod(roundi(wrapf(angle, -PI, PI) / step), STEPS)


## Converts a step back to an angle (rad, [-π, π)).
static func dequantize(step_index: int) -> float:
	return wrapf(posmod(step_index, STEPS) * TAU / STEPS, -PI, PI)


## Quantised angle (the angle the remote side will see for the broadcast value).
static func snap(angle: float) -> float:
	return dequantize(quantize(angle))


## One step from `current` toward `target` (rad). `max_rate` caps rad/s (<= 0: no cap); `smoothing` > 0 is the exponential approach
## coefficient (1/s), 0 goes straight to the target (still capped).
static func turn(current: float, target: float, delta: float, max_rate: float, smoothing: float = 0.0) -> float:
	var diff: float = angle_difference(current, target)
	var step: float = diff
	if smoothing > 0.0:
		step = diff * (1.0 - exp(-smoothing * maxf(delta, 0.0)))
	if max_rate > 0.0:
		var cap: float = max_rate * maxf(delta, 0.0)
		step = clampf(step, -cap, cap)
	return wrapf(current + step, -PI, PI)


## One look step: toward the explicit look input (`look`, world direction; mouse/right stick/bot) with the cap if present,
## else toward the movement direction (`facing`) with keyboard smoothing.
static func step_look(current: float, look: Vector2, facing: Vector2, delta: float, max_rate: float) -> float:
	if look.length() >= INPUT_EPSILON:
		return turn(current, look.angle(), delta, max_rate)
	if facing.length() < INPUT_EPSILON:
		return current
	return turn(current, facing.angle(), delta, max_rate, KEYBOARD_SMOOTHING)
