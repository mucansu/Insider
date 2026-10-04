class_name PuppetBody
extends RefCounted
## Puppet geometry and pose rules (US-014; GDD §14.1, docs/tasarim/kukla-denemesi.html): part sizes (puppet units; x PuppetTuning.puppet_scale
## = px), hand/foot positions from step phase, mode -> silhouette scale and lean targets, reaction balloon timing. Node-free, stateless;
## PuppetRig calls it, Puppet uses the sizes for drawing. Near-chibi proportions: head diameter ~ body height, total ~44 units.

const NECK_HEIGHT := 22.0
const TORSO_CENTER := Vector2(0.0, -12.0)
const BODY_RADIUS := Vector2(9.6, 10.6)
const HEAD_CENTER := Vector2(0.0, -30.0)
const HEAD_RADIUS := 12.5
const HAND_RADIUS := 3.1
const SHADOW_RADIUS := Vector2(12.0, 4.2)
const FOOT_RADIUS := Vector2(3.2, 2.2)
## Feet: side spread, depth, lift; step swing shortens in depth; height above ground.
const FOOT_SIDE := 3.6
const FOOT_DEPTH := 1.6
const FOOT_LIFT := 2.2
const FOOT_DEPTH_SWING := 0.55
const FOOT_GROUND := 1.2
## Hands: walk (side, height, depth, opposed swing).
const HAND_SIDE := 10.5
const HAND_Y := -9.0
const HAND_DEPTH := 1.2
const HAND_SWING := 3.2
## Hands reach forward when sneaking.
const SNEAK_HAND_SIDE := 7.0
const SNEAK_HAND_FORWARD := 6.0
const SNEAK_HAND_Y := -11.0
const SNEAK_HAND_DEPTH := 3.0
## While interacting the hands meet in front and tremble.
const WORK_HAND_SIDE := 4.0
const WORK_HAND_FORWARD := 9.0
const WORK_HAND_Y := -10.0
const WORK_HAND_DEPTH := 4.0
const WORK_JITTER := 1.3
const WORK_JITTER_RATE := 18.0
## Angular speed of the "!" tremble (rad/s) and easeOutBack overshoot coefficient (test scene).
const SHAKE_RATE := 60.0
const BACK_OVERSHOOT := 1.9


## Center of the two feet (units; in ground transform): left, right. `face` unit facing, `swing` mode swing amplitude
## (units), `moving` 0..1, `hop` hop height (units).
static func feet(face: Vector2, phase: float, moving: float, swing: float, width: float,
		hop: float) -> PackedVector2Array:
	var side_dir := Vector2(-face.y, face.x)
	var out: PackedVector2Array = []
	for side: float in [-1.0, 1.0]:
		var ph: float = phase + (0.0 if side > 0.0 else PI)
		var along: float = sin(ph) * swing * moving
		var lift: float = maxf(0.0, cos(ph)) * FOOT_LIFT * moving
		out.append(Vector2(side_dir.x * side * FOOT_SIDE * width + face.x * along,
			side_dir.y * side * FOOT_DEPTH + face.y * along * FOOT_DEPTH_SWING - lift - hop - FOOT_GROUND))
	return out


## Center of the two hands (units; in body transform): opposed swing when walking, forward when sneaking, meeting in front and
## trembling when interacting (`clock` s).
static func hands(face: Vector2, phase: float, moving: float, width: float, sneaking: bool, working: bool,
		clock: float) -> PackedVector2Array:
	var side_dir := Vector2(-face.y, face.x)
	var swing: float = sin(phase) * HAND_SWING * moving
	var out: PackedVector2Array = []
	for side: float in [-1.0, 1.0]:
		var p := Vector2(side_dir.x * side * HAND_SIDE * width + face.x * swing * side,
			HAND_Y + side_dir.y * side * HAND_DEPTH + face.y * swing * side * 0.5)
		if working:
			var r: float = sin(clock * WORK_JITTER_RATE + side) * WORK_JITTER
			p = Vector2(side_dir.x * side * WORK_HAND_SIDE + face.x * WORK_HAND_FORWARD + r,
				WORK_HAND_Y + face.y * WORK_HAND_DEPTH + r * 0.5)
		elif sneaking:
			p = Vector2(side_dir.x * side * SNEAK_HAND_SIDE + face.x * SNEAK_HAND_FORWARD,
				SNEAK_HAND_Y + face.y * SNEAK_HAND_DEPTH)
		out.append(p)
	return out


## Per-mode tuning value (Vector3: x sneak, y walk, z sprint).
static func per_gait(values: Vector3, which: PuppetRig.Gait) -> float:
	match which:
		PuppetRig.Gait.SNEAK:
			return values.x
		PuppetRig.Gait.SPRINT:
			return values.z
	return values.y


## Squash-stretch target (silhouette scale): by mode, blended by movement ratio; constant while interacting.
static func target_squash(values: PuppetTuning, which: PuppetRig.Gait, moving: float, working: bool,
		exaggeration: float) -> float:
	if working:
		return values.interact_scale
	return 1.0 + (per_gait(values.body_scale, which) - 1.0) * clampf(moving, 0.0, 1.0) * exaggeration


## Lean target (rad): toward travel direction by horizontal speed, against acceleration (overshoot at stop); more when sprinting.
static func target_lean(values: PuppetTuning, which: PuppetRig.Gait, vel: Vector2, acc: Vector2, exaggeration: float,
		reduced: bool) -> float:
	if reduced:
		return 0.0
	var t: float = (vel.x / values.lean_reference_speed) * values.lean_gain * exaggeration \
		- acc.x * values.lean_accel_gain * exaggeration
	if which == PuppetRig.Gait.SPRINT:
		t *= values.lean_sprint_factor
	return clampf(t, -values.lean_max, values.lean_max)


## Reaction balloon pop scale (easeOutBack; 0 for NONE).
static func bubble_scale(values: PuppetTuning, kind: PuppetRig.Reaction, age: float) -> float:
	if kind == PuppetRig.Reaction.NONE:
		return 0.0
	var t: float = 1.0 if values.bubble_pop_time <= 0.0 else minf(1.0, age / values.bubble_pop_time)
	return ease_out_back(t)


## Horizontal tremble of the "!" balloon (px); decays over its duration.
static func bubble_shake(values: PuppetTuning, kind: PuppetRig.Reaction, age: float) -> float:
	if kind != PuppetRig.Reaction.ALERT or values.alert_shake_time <= 0.0:
		return 0.0
	var left: float = maxf(0.0, 1.0 - age / values.alert_shake_time)
	return sin(age * SHAKE_RATE) * left * values.alert_shake_amplitude


static func ease_out_back(t: float) -> float:
	return 1.0 + (BACK_OVERSHOOT + 1.0) * pow(t - 1.0, 3.0) + BACK_OVERSHOOT * pow(t - 1.0, 2.0)
