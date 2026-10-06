class_name FootstepRules
extends RefCounted
## Cosmetic footstep rule (US-047 AC2; KR-040). Node-free: gait from movement mode + speed, and a per-copy cadence that says when a step
## sound is due. Sound only: it never emits to NoiseBus and changes no hearing rule (S8/S11 stay with the player's `_emit_step_noise`).
## Walk = quiet `walk_step`, sneak = no step, sprint = `run_step` on the same 0.35 s cadence as the sprint noise ring (NoiseProfile.step_interval).
## Remote copies feed it their interpolated mode/velocity, so no new network field is needed.

enum Gait { STILL, SNEAK, WALK, RUN }

const WALK_EVENT := &"walk_step"
const RUN_EVENT := &"run_step"
## Below this speed (px/s) a copy is "standing" (same threshold as the sprint noise: NoiseProfile.step_min_speed).
const MIN_SPEED := 40.0
## Seconds between steps. Run matches the noise ring cadence; walk is slower (140 px/s vs 220 px/s).
const WALK_INTERVAL := 0.46
const RUN_INTERVAL := 0.35


static func gait_for(sneaking: bool, sprinting: bool, speed: float) -> Gait:
	if speed < MIN_SPEED:
		return Gait.STILL
	if sneaking:
		return Gait.SNEAK
	return Gait.RUN if sprinting else Gait.WALK


## Sound event of a gait; empty = silent (standing, sneaking).
static func event_for(gait: Gait) -> StringName:
	match gait:
		Gait.WALK:
			return WALK_EVENT
		Gait.RUN:
			return RUN_EVENT
	return &""


static func interval_for(gait: Gait) -> float:
	return RUN_INTERVAL if gait == Gait.RUN else WALK_INTERVAL


## Step clock of one character. `tick` returns the event to play this frame (empty = none). The first step after starting to move comes
## after a quarter interval (the foot lands soon, not instantly on key press); switching gait keeps the phase.
class Cadence:
	extends RefCounted

	var _since: float = 0.0
	var _moving: bool = false

	func tick(delta: float, gait: Gait) -> StringName:
		var event: StringName = FootstepRules.event_for(gait)
		if event.is_empty():
			_moving = false
			return &""
		var interval: float = FootstepRules.interval_for(gait)
		if not _moving:
			_moving = true
			_since = interval * 0.75
		_since += delta
		if _since < interval:
			return &""
		_since = fmod(_since - interval, interval)
		return event
