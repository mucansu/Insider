class_name PuppetRig
extends RefCounted
## Puppet animation computation (US-014; GDD §14.1, KR-017): node-free, values only (KR-003: in a 3D move the same computation can drive a
## toon body). Input = observed state (position, velocity, look direction, mode, interaction); output = pose (squash, lean, bob, hop, step
## phase, hands/feet, eyes, scarf, dust, reaction balloon). No logic, input, collision or network; Puppet calls `update` every frame and draws.
## Fixed step: `update(delta, ...)` accumulates incoming time and advances in 1/120 s steps; springs and smoothing are frame-rate
## independent. Position is spread linearly across steps (the scarf follows smoothly). Teleport: a position jump longer than
## `teleport_distance` in one update (remote buffer reset, level change) silently rebuilds the animation: scarf hangs at the new spot,
## springs at target, dust cleared.
## Units: puppet geometry is in "units" (x tuning.puppet_scale = px); speeds and step lengths in px/s and px. Hop, dust and scarf are also
## units (the test scene draws at puppet scale 2, so its px = 2 units). "Visual overshoot" (GDD §14.1 rule 3): horizontal offset of the
## body center from the collision center (`torso_offset`) and shadow/footprint radius (`footprint_radius`); reaction hop (vertical, short)
## and scarf (secondary cloth) excluded.

## Mode order matches the Vector3 components in tuning: x sneak, y walk, z sprint.
enum Gait { SNEAK, WALK, SPRINT }
enum Reaction { NONE, QUESTION, ALERT }

## Fixed simulation step (s).
const STEP := 1.0 / 120.0
## Longest time handled per update (s): a hitched frame must not blow up the springs.
const MAX_FRAME_DELTA := 0.25
const STEP_EPSILON := 1e-7
## Observed speed below this means "standing" (stand smoothing; px/s).
const STOP_SPEED := 1.0
## Idle pose (breathing, glances) while the moving ratio is below this.
const IDLE_MOVING := 0.2
## Visual cap of observed speed (px/s): a large position delta over a short interval during interpolation (late/lost packet) must not
## blow up the animation.
const MAX_VISUAL_SPEED := 400.0
## Safe range of the squash target (silhouette scale).
const SQUASH_LIMITS := Vector2(0.6, 1.3)

## Widening when squashed: sqx = 1 + (1 - sqy) x ratio.
const SQUASH_WIDTH_RATIO := 0.85
## Drawn back-turned if the look y component is below this.
const BACK_FACING_Y := -0.35
## Head top: this multiple of the head radius (headgear included).
const HEAD_TOP_RATIO := 1.15
## Shadow shrink while hopping: 1 - min(MAX, height / REF).
const SHADOW_HOP_REF := 45.0
const SHADOW_HOP_MAX := 0.45
## Landing squash only after this fall speed (units/s).
const LAND_MIN_SPEED := 60.0
## Scarf anchor from the neck (units): opposite the facing and down.
const SCARF_BACK := 3.0
const SCARF_DEPTH := 1.5
const SCARF_DROP := 2.0


var tuning: PuppetTuning = null
## Reduced motion (GDD §14.1 rule 5): bob, lean and dust off; balloons and rings stay.
var reduced_motion: bool = false
## Whether the look has a scarf (no scarf is computed otherwise).
var has_scarf: bool = true
## Body width multiplier (PuppetLook.width): hand/foot spread and shadow.
var width: float = 1.0

# --- last observed state ---
var target_position: Vector2 = Vector2.ZERO
var target_velocity: Vector2 = Vector2.ZERO
var target_facing: Vector2 = Vector2.DOWN
var gait: Gait = Gait.WALK
var interacting: bool = false
## Teammate to glance at when idle (world px); has_friend false if none.
var friend_position: Vector2 = Vector2.ZERO
var has_friend: bool = false
## Look direction of head and eyes (US-011b, GDD §14.1: head looks, body follows movement); zero = head with the body.
var target_look: Vector2 = Vector2.ZERO

# --- pose state ---
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var accel: Vector2 = Vector2.ZERO
var face: float = PI * 0.5
## Head angle (rad): turns to `target_look` with `turn_smoothing` if set, else the body angle (`face`).
var head: float = PI * 0.5
var phase: float = 0.0
var clock: float = 0.0
var squash: PuppetSpring = PuppetSpring.new(1.0)
var lean: PuppetSpring = PuppetSpring.new(0.0)
var hop: float = 0.0
var hop_velocity: float = 0.0
var reaction: Reaction = Reaction.NONE
var reaction_age: float = 0.0
## Step landing and teleport counters (diagnostics/test).
var footfalls: int = 0
var rebuilds: int = 0

## Eyes (look, glances, blink) and secondary motion (scarf, dust).
var eyes: PuppetEyes = null
var cloth: PuppetCloth = PuppetCloth.new()

var _accumulator: float = 0.0
var _built: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(values: PuppetTuning, rng_seed: int = 0) -> void:
	tuning = values
	_rng.seed = rng_seed
	eyes = PuppetEyes.new(values, _rng)


## One frame: takes the observed state, processes accumulated time in fixed steps.
func update(delta: float, pos: Vector2, vel: Vector2, facing: Vector2, which: Gait, working: bool) -> void:
	var from: Vector2 = position
	target_velocity = vel.limit_length(MAX_VISUAL_SPEED) if vel.is_finite() else Vector2.ZERO
	if facing.length_squared() > 0.0001:
		target_facing = facing.normalized()
	gait = which
	interacting = working
	target_position = pos
	if not _built or pos.distance_to(from) > tuning.teleport_distance:
		rebuild(pos)
		return
	_accumulator += clampf(delta, 0.0, MAX_FRAME_DELTA)
	var steps: int = int((_accumulator + STEP_EPSILON) / STEP)
	if steps <= 0:
		return
	_accumulator = maxf(0.0, _accumulator - steps * STEP)
	for i: int in steps:
		_step(STEP, from.lerp(pos, float(i + 1) / steps))


## Silently rebuilds the animation at the given position and last observed state (no hop/"pop").
func rebuild(pos: Vector2) -> void:
	position = pos
	velocity = target_velocity
	accel = Vector2.ZERO
	face = target_facing.angle()
	head = _head_target()
	var moving: float = _moving()
	squash.settle(PuppetBody.target_squash(tuning, gait, moving, interacting, _exaggeration()))
	lean.settle(PuppetBody.target_lean(tuning, gait, velocity, accel, _exaggeration(), reduced_motion))
	eyes.settle(head)
	hop = 0.0
	hop_velocity = 0.0
	cloth.clear_dust()
	_accumulator = 0.0
	_reset_scarf()
	_built = true
	rebuilds += 1


## Reaction: "?" (suspicion) or "!" (noticed: hop + eye widen). NONE removes the balloon.
func react(kind: Reaction) -> void:
	if kind == reaction and kind != Reaction.ALERT:
		return
	reaction = kind
	reaction_age = 0.0
	if kind == Reaction.ALERT:
		jump()
		eyes.widen(tuning.alert_eye_impulse)


## Look changed: body width and scarf (scarf is re-hung).
func set_look(body_width: float, scarf: bool) -> void:
	width = body_width
	has_scarf = scarf
	if _built:
		_reset_scarf()


## Hops if on the ground.
func jump() -> void:
	if hop <= 0.01:
		hop_velocity = tuning.jump_speed
		hop = 0.01


# --- read (drawing and tests) ---

func speed() -> float:
	return velocity.length()


## Movement ratio 0..1 (1 at full movement).
func moving() -> float:
	return _moving()


func face_direction() -> Vector2:
	return Vector2.from_angle(face)


## Direction of the head (face, eyes, headgear).
func head_direction() -> Vector2:
	return Vector2.from_angle(head)


## Whether the head is back-turned (looking up; face not drawn).
func head_is_back() -> bool:
	return head_direction().y < BACK_FACING_Y


## Whether back-turned (looking up).
func is_back() -> bool:
	return face_direction().y < BACK_FACING_Y


## Silhouette height scale (squash-stretch spring).
func squash_y() -> float:
	return squash.x


func squash_x() -> float:
	return 1.0 + (1.0 - squash.x) * SQUASH_WIDTH_RATIO


## Step bob (units, up); 0 under reduced motion.
func bob() -> float:
	if reduced_motion:
		return 0.0
	return absf(sin(phase)) * PuppetBody.per_gait(tuning.bob_amplitude, gait) * _moving() * tuning.bounce


## Body transform: moves unit-coordinate body/head parts to node-local px.
## Order: hop -> lean (about the foot point) -> squash x scale -> bob.
func body_transform(include_hop: bool = true) -> Transform2D:
	var s: float = tuning.puppet_scale
	var lift: float = hop * s if include_hop else 0.0
	return Transform2D(lean.x, Vector2(0.0, -lift)) \
		.scaled_local(Vector2(squash_x() * s, squash_y() * s)) \
		.translated_local(Vector2(0.0, -bob()))


## Ground transform (shadow and feet; no lean or squash).
func ground_transform() -> Transform2D:
	var s: float = tuning.puppet_scale
	return Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)


## Shadow scale while hopping.
func shadow_scale() -> float:
	return 1.0 - minf(SHADOW_HOP_MAX, hop / SHADOW_HOP_REF)


## Center of the two feet (units, in ground transform): left, right.
func foot_offsets() -> PackedVector2Array:
	return PuppetBody.feet(face_direction(), phase, _moving(), PuppetBody.per_gait(tuning.foot_swing, gait), width, hop)


## Center of the two hands (units, in body transform).
func hand_offsets() -> PackedVector2Array:
	var m: float = _moving()
	return PuppetBody.hands(face_direction(), phase, m, width, gait == Gait.SNEAK and m > IDLE_MOVING,
		interacting, clock)


## Pupil offset (units) and scale; closed while blinking.
func eye_offset() -> Vector2:
	return eyes.offset()


func eye_size() -> float:
	return eyes.size.x


func is_blinking() -> bool:
	return eyes.is_blinking()


## Scarf points (world px; first point is the neck anchor). Empty if no scarf.
func scarf_points() -> PackedVector2Array:
	return cloth.scarf_points()


## Scarf points to draw (world px). At high frame rates (144/240 Hz) some frames get no fixed step: the simulated position lags the
## observed one while the body draws at the observed position. The scarf is shifted by the same offset; its root is always at the body's
## anchor point.
func scarf_draw_points() -> PackedVector2Array:
	var pts: PackedVector2Array = cloth.scarf_points()
	var lag: Vector2 = target_position - position
	if lag == Vector2.ZERO or pts.is_empty():
		return pts
	var out: PackedVector2Array = pts.duplicate()
	for i: int in out.size():
		out[i] += lag
	return out


## Scarf anchor on the body, at the observed (drawn) position (world px).
func scarf_anchor() -> Vector2:
	return _anchor_at(target_position)


func dust_particles() -> Array[PuppetCloth.Dust]:
	return cloth.dust_particles()


## Balloon pop scale (easeOutBack) and "!" tremble (px).
func bubble_scale() -> float:
	return PuppetBody.bubble_scale(tuning, reaction, reaction_age)


func bubble_shake() -> float:
	return PuppetBody.bubble_shake(tuning, reaction, reaction_age)


## Horizontal offset of the body center from the collision center (px; hop excluded).
func torso_offset() -> float:
	return absf((body_transform(false) * PuppetBody.TORSO_CENTER).x)


## Horizontal extreme of shadow and footprint from the center (px).
func footprint_radius() -> float:
	var s: float = tuning.puppet_scale
	var r: float = PuppetBody.SHADOW_RADIUS.x * width * shadow_scale()
	for foot: Vector2 in foot_offsets():
		r = maxf(r, absf(foot.x) + PuppetBody.FOOT_RADIUS.x)
	return r * s


## Head top in node-local px; markers attach to the fixed anchor, NOT to this.
func head_top() -> Vector2:
	return body_transform() * (PuppetBody.HEAD_CENTER - Vector2(0.0, PuppetBody.HEAD_RADIUS * HEAD_TOP_RATIO))


# --- step ---

func _step(h: float, pos: Vector2) -> void:
	position = pos
	var k: float = tuning.speed_smoothing_start if target_velocity.length() > STOP_SPEED \
		else tuning.speed_smoothing_stop
	var prev: Vector2 = velocity
	velocity += (target_velocity - velocity) * (1.0 - exp(-k * h))
	accel += ((velocity - prev) / h - accel) * (1.0 - exp(-tuning.accel_smoothing * h))
	var spd: float = velocity.length()
	face += angle_difference(face, target_facing.angle()) * (1.0 - exp(-tuning.turn_smoothing * h))
	if target_look.length_squared() > 0.0001:
		head += angle_difference(head, target_look.angle()) * (1.0 - exp(-tuning.turn_smoothing * h))
	else:
		head = face

	var half: float = floorf(phase / PI)
	phase += spd * h / maxf(1.0, PuppetBody.per_gait(tuning.stride, gait)) * PI
	if floorf(phase / PI) != half and spd > tuning.footfall_min_speed:
		_footfall()
	clock += h

	var m: float = _moving()
	var ex: float = _exaggeration()
	var sq_target: float = PuppetBody.target_squash(tuning, gait, m, interacting, ex)
	if m < IDLE_MOVING and tuning.breath_period > 0.0:
		sq_target += tuning.breath_amount * sin(clock * TAU / tuning.breath_period) * (1.0 - m / IDLE_MOVING)
	sq_target -= maxf(0.0, accel.dot(face_direction())) * tuning.squash_accel_gain * ex  # takeoff dip
	sq_target = clampf(sq_target, SQUASH_LIMITS.x, SQUASH_LIMITS.y)
	squash.step(sq_target, tuning.spring_frequency, tuning.squash_damping, h)
	lean.step(PuppetBody.target_lean(tuning, gait, velocity, accel, ex, reduced_motion),
		tuning.spring_frequency * tuning.lean_frequency_ratio, tuning.lean_damping, h)

	if hop > 0.0 or hop_velocity > 0.0:
		hop_velocity -= tuning.gravity * h
		hop += hop_velocity * h
		if hop <= 0.0:
			hop = 0.0
			if hop_velocity < -LAND_MIN_SPEED:
				squash.v -= tuning.land_impulse * tuning.bounce
			hop_velocity = 0.0

	eyes.step(h, head, m < IDLE_MOVING, gait == Gait.SNEAK and m > IDLE_MOVING, position, friend_position,
		has_friend)
	if reaction != Reaction.NONE:
		reaction_age += h
	if has_scarf:
		cloth.step_scarf(_anchor_at(position), tuning.scarf_segments, _scarf_segment(), tuning.scarf_damping,
			tuning.scarf_gravity * tuning.puppet_scale * h * h)
	cloth.step_dust(h)


func _footfall() -> void:
	footfalls += 1
	if reduced_motion:
		return
	squash.v -= tuning.footfall_impulse * tuning.bounce * PuppetBody.per_gait(tuning.footfall_factor, gait)
	if gait != Gait.SPRINT:
		return
	cloth.emit_dust(position, face_direction(), tuning.dust_per_step, tuning.dust_life, tuning.puppet_scale, _rng)


## Scarf anchor at the neck when the body is drawn at `base` (world px).
func _anchor_at(base: Vector2) -> Vector2:
	var s: float = tuning.puppet_scale
	var f: Vector2 = face_direction()
	var neck: Vector2 = base + Vector2(sin(lean.x), -cos(lean.x)) * PuppetBody.NECK_HEIGHT * s * squash.x \
		- Vector2(0.0, hop * s)
	return neck + Vector2(-f.x * SCARF_BACK, -f.y * SCARF_DEPTH + SCARF_DROP) * s


func _scarf_segment() -> float:
	return tuning.scarf_segment_length * tuning.puppet_scale


func _reset_scarf() -> void:
	cloth.reset_scarf(_anchor_at(position), tuning.scarf_segments if has_scarf else 0, _scarf_segment())


func _head_target() -> float:
	return target_look.angle() if target_look.length_squared() > 0.0001 else face


func _moving() -> float:
	return minf(1.0, velocity.length() / maxf(1.0, tuning.moving_reference_speed))


func _exaggeration() -> float:
	return tuning.exaggeration
