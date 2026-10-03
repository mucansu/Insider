class_name NoiseRules
extends RefCounted
## Noise rules (US-009; mimari.md S8, S2, §6): audibility (distance), attenuation behind walls, whether a ray hit cuts the sound,
## host validation of client requests, and emit cadence. Node-free; plain values only (the physics ray lives in the listener component on the host and feeds its result in; KR-003).
## Numeric settings (radii, attenuation factor, cadence) live in `data/noise_profile.tres`; constants here are only rule margins.

## Reasons the host rejects a client noise request (OK = accepted).
enum Result { OK, BAD_POSITION, FOREIGN_PEER, KIND_NOT_ALLOWED, NO_ACTOR, TOO_FAR, SILENT, RATE }

## Max difference (px) between the sound position the client reports and the actor position the host knows. The host knows the actor's latest synced position (S7 `interaction_position`);
## between the reliable RPC and the 20 Hz unreliable sync there is at most ~1 sync interval + frame skew: sprint 220 px/s x (0.05 + 0.05) s ~ 22 px (a small margin above the S2 range slack of 24 px).
## Requests beyond it are rejected: a client cannot make sound at a distant position.
const POSITION_TOLERANCE := 32.0
## A ray hit this close to the sound source (px) does not cut the sound: the source's own body (e.g. a closing door leaf, a sound emitted at the door point) does not muffle it.
## Half a tile (1 tile = 32 px, S4); a player leaning on a wall is >= wall thickness + body radius = 44 px from a listener behind it, so attenuation still applies.
const SOURCE_MARGIN := 16.0
## Minimum interval per sender for client requests = step interval x this factor. A client sends its step once per `step_interval`; half of it leaves room for the reliable
## channel bunching packets on resend (~175 ms). Requests beyond it are rejected with `RATE` (the sound is dropped; favours the player).
const CLIENT_RATE_FACTOR := 0.5
## For ongoing work noise (register emptying) the tick is suppressed this fraction of an interval before the end: the finish sound is emitted anyway,
## so two sounds in a row at the same point (double suspicion in US-008) are avoided.
const WORK_TICK_END_FACTOR := 0.5


## Without line of sight (world/vision_block in between) the radius is multiplied by `wall_factor` (S8: x0.5).
static func effective_radius(radius: float, line_of_sight: bool, wall_factor: float) -> float:
	if radius <= 0.0:
		return 0.0
	return radius if line_of_sight else radius * clampf(wall_factor, 0.0, 1.0)


## Whether the listener is within the (effective) radius; a zero-radius sound (walking, sneaking) is never heard.
static func can_hear(distance: float, radius: float) -> bool:
	return radius > 0.0 and distance <= radius


## Whether a ray hit cuts the sound: a hit closer than SOURCE_MARGIN to the source is the source itself and does not.
static func hit_blocks(hit_point: Vector2, source: Vector2) -> bool:
	return hit_point.distance_to(source) > SOURCE_MARGIN


## Host: validates `sender`'s (RPC sender id) noise request. `source_peer` is the source the client claims (must be 0 or itself; no sound on behalf of another peer);
## `kind_allowed`: whether the client may produce this kind (only its own movement sound); `radius`: the host's radius from the definition (the client's radius is not trusted);
## `known`: the actor position the host knows (no actor if `has_actor` is false).
static func check_client(sender: int, source_peer: int, kind_allowed: bool, radius: float, claimed: Vector2,
		known: Vector2, has_actor: bool, tolerance: float = POSITION_TOLERANCE) -> Result:
	if not claimed.is_finite():
		return Result.BAD_POSITION
	if sender <= 0 or (source_peer != 0 and source_peer != sender):
		return Result.FOREIGN_PEER
	if not kind_allowed:
		return Result.KIND_NOT_ALLOWED
	if radius <= 0.0:
		return Result.SILENT
	if not has_actor or not known.is_finite():
		return Result.NO_ACTOR
	if claimed.distance_to(known) > tolerance:
		return Result.TOO_FAR
	return Result.OK


## Host: `since_last` seconds have passed since the same sender's last accepted request; whether it is within the rate limit.
static func within_rate(since_last: float, step_interval: float) -> bool:
	return since_last >= step_interval * CLIENT_RATE_FACTOR


## Whether the ongoing work's tick sound (e.g. register emptying; `progress`/`hold_time` in s) may be emitted this step: not if less than
## `interval x WORK_TICK_END_FACTOR` remains to the end (the finish sound replaces it).
static func work_tick_allowed(progress: float, hold_time: float, interval: float) -> bool:
	return hold_time <= 0.0 or progress + interval * WORK_TICK_END_FACTOR < hold_time


## Name of the rejection reason for dumps and logs.
static func result_name(result: Result) -> String:
	return str(Result.keys()[result]).to_lower()


## Emit cadence (sprint steps, register-emptying sound): at most one event per `interval` s while active.
## `lead`: time to wait after activation before the first event (0 = immediately). Time while inactive counts too, so toggling on/off in short intervals cannot exceed the cadence limit.
class Cadence:
	extends RefCounted

	var interval: float = 0.0
	var lead: float = 0.0
	var _since_last: float = INF
	var _active_for: float = 0.0

	func _init(interval_sec: float, lead_sec: float = 0.0) -> void:
		interval = maxf(interval_sec, 0.0)
		lead = maxf(lead_sec, 0.0)

	## Advances time by `delta`; true if an event should be emitted this step.
	func tick(delta: float, active: bool) -> bool:
		_since_last += delta
		if not active:
			_active_for = 0.0
			return false
		_active_for += delta
		if _active_for < lead or _since_last < interval:
			return false
		_since_last = 0.0
		return true
