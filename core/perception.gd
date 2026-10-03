class_name PerceptionRules
extends RefCounted
## Perception rules (US-006 AC1; mimari.md S11, GDD §6.1, KR-019). Node-free: plain values (Vector2, float, int, bool); no scene tree, physics space or project dirs (KR-003, KR-018).
## Line of sight (raycast) is done in the component and enters here as `visible: bool`.
##
## Model (KR-019, "digital" readability): the observer's view cone (position, facing, half angle, range) splits into two bands: near (distance <= range x near_ratio) x near_factor, far x far_factor.
## A visible target's suspicion fill (units/s) = base_fill x band factor x state factor; state = movement mode (sprint/walk/sneak) or a dark zone (binary light/shadow: dark_factor in the dark, 0 initially).
## `SuspicionMeter` (core/suspicion.gd) applies the fill to the meter; numbers reach `Params` from `data/npc/perception_tuning.tres` via the component (defaults here are neutral).

enum Band { NONE, FAR, NEAR }
## Target movement state that enters perception (the component maps it from the player mode).
enum Stance { WALK, SNEAK, SPRINT }

## Float margin on cone bounds (angle cosine and px).
const EPSILON := 0.0001


## Perception settings (value object; the component fills it from tuning).
class Params:
	extends RefCounted
	## Cone half angle (degrees) and range (px).
	var half_angle_deg: float = 0.0
	var view_range: float = 0.0
	## Near band limit: this fraction of the range (KR-019: R/2).
	var near_ratio: float = 0.0
	var near_factor: float = 0.0
	var far_factor: float = 0.0
	## Base fill (units/s) and state factors.
	var base_fill: float = 0.0
	var sprint_factor: float = 0.0
	var walk_factor: float = 0.0
	var sneak_factor: float = 0.0
	var dark_factor: float = 0.0


## Whether the target is inside the cone: range (inclusive) and half angle (inclusive). Zero facing = no cone (false);
## a target exactly on the observer counts as inside.
static func in_cone(observer_pos: Vector2, facing: Vector2, half_angle_deg: float, view_range: float,
		target_pos: Vector2) -> bool:
	if facing.is_zero_approx() or view_range <= 0.0:
		return false
	var offset: Vector2 = target_pos - observer_pos
	var dist: float = offset.length()
	if dist > view_range + EPSILON:
		return false
	if dist <= EPSILON:
		return true
	var cos_limit: float = cos(deg_to_rad(clampf(half_angle_deg, 0.0, 180.0)))
	return offset.dot(facing.normalized()) / dist >= cos_limit - EPSILON


## Target's band: NONE outside the cone; inside, NEAR if distance <= range x near_ratio, else FAR.
static func band(params: Params, observer_pos: Vector2, facing: Vector2, target_pos: Vector2) -> Band:
	if not in_cone(observer_pos, facing, params.half_angle_deg, params.view_range, target_pos):
		return Band.NONE
	if observer_pos.distance_to(target_pos) <= params.view_range * params.near_ratio + EPSILON:
		return Band.NEAR
	return Band.FAR


static func band_factor(params: Params, which: Band) -> float:
	match which:
		Band.NEAR:
			return params.near_factor
		Band.FAR:
			return params.far_factor
	return 0.0


## State factor: a dark zone overrides every mode (binary light/shadow); an unknown mode counts as walking.
static func stance_factor(params: Params, stance: Stance, in_dark: bool) -> float:
	if in_dark:
		return params.dark_factor
	match stance:
		Stance.SPRINT:
			return params.sprint_factor
		Stance.SNEAK:
			return params.sneak_factor
	return params.walk_factor


## Suspicion fill (units/s): 0 if line of sight is cut or outside the cone.
static func fill_rate(params: Params, which: Band, stance: Stance, in_dark: bool, visible: bool) -> float:
	if not visible or which == Band.NONE:
		return 0.0
	return maxf(0.0, params.base_fill * band_factor(params, which) * stance_factor(params, stance, in_dark))


## In one call: position/facing + line-of-sight result + target state -> fill (units/s).
static func rate_for(params: Params, observer_pos: Vector2, facing: Vector2, target_pos: Vector2,
		visible: bool, stance: Stance, in_dark: bool) -> float:
	return fill_rate(params, band(params, observer_pos, facing, target_pos), stance, in_dark, visible)


## Turns the facing toward `desired` by at most `max_turn_deg_per_sec x delta` degrees (KR-019: guard turn cap).
## Returns a unit vector; keeps the direction if `desired` is zero, jumps straight to `desired` if `current` is zero.
static func turn_toward(current: Vector2, desired: Vector2, max_turn_deg_per_sec: float, delta: float) -> Vector2:
	if desired.is_zero_approx():
		return current.normalized() if not current.is_zero_approx() else current
	var want: Vector2 = desired.normalized()
	if current.is_zero_approx():
		return want
	var from: Vector2 = current.normalized()
	var angle: float = from.angle_to(want)
	var step: float = deg_to_rad(maxf(max_turn_deg_per_sec, 0.0)) * maxf(delta, 0.0)
	if absf(angle) <= step:
		return want
	return from.rotated(signf(angle) * step)
