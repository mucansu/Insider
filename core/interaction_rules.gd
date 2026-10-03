class_name InteractionRules
extends RefCounted
## Interaction rules (US-005; mimari.md S2, S7). Node-free: plain values only (Vector2, float, int), no scene tree (KR-003, KR-018). Two users:
## - client (local player): target selection and prompt; no tolerance (prompt only when truly in range),
## - host: request validation and hold timing with S2 latency tolerance (range +24 px, side threshold -24 px, time +0.25 s) and only the host-known blocker (`Target.blocked`, e.g. a player in the door gap).
## Target state travels in the `Target` value object (filled by Interactable).

enum Result { OK, DISABLED, BUSY, COOLDOWN, OUT_OF_RANGE, WRONG_SIDE, MISSING_TAG, NO_ACTOR, BLOCKED }

## S2: slack the host gives range when validating a client request (px).
const RANGE_TOLERANCE := 24.0
## S2 principle (GDD §12, favours the player): slack the host subtracts from the side-constraint threshold (px). The host sees the client position ~0.1 s late
## (one-way latency + sync interval); a sprinting player (220 px/s) is ~22 px behind, so someone pressing the moment the prompt appears must not be rejected.
## For the register the threshold goes 16 -> -8: the customer side (counter edge 546 px, radius 12 -> at most -26 px) is still rejected (18 px margin).
const SIDE_TOLERANCE := 24.0
## S2: slack given to time (s). A request released within the last slack of the hold time counts as complete (a player who releases with the bar full locally
## is not penalised for the host filling RTT later).
const TIME_TOLERANCE := 0.25
## Seconds after an interaction ends during which the host rejects a new request on the same target: for instant actions (door) two simultaneous
## presses must not flip it twice; only one gets through (AC4).
const REPEAT_COOLDOWN := 0.25

const _RESULT_NAMES: Dictionary = {
	Result.OK: "ok",
	Result.DISABLED: "disabled",
	Result.BUSY: "busy",
	Result.COOLDOWN: "cooldown",
	Result.OUT_OF_RANGE: "out_of_range",
	Result.WRONG_SIDE: "wrong_side",
	Result.MISSING_TAG: "missing_tag",
	Result.NO_ACTOR: "no_actor",
	Result.BLOCKED: "blocked",
}


## Interaction target state used by the rules (positions in the same 2D space, e.g. global coordinates).
class Target:
	extends RefCounted
	var position: Vector2 = Vector2.ZERO
	var interact_range: float = 40.0
	var enabled: bool = true
	## Peer holding the target (0 = free).
	var busy_by: int = 0
	## Side constraint: the direction the actor must be on (need not be unit; ZERO = no constraint) and how far along it from the target centre they must be (px).
	var side: Vector2 = Vector2.ZERO
	var side_min: float = 0.0
	## Required tag (empty = none) and its minimum tier.
	var tag: StringName = &""
	var tier: int = 0
	## Host validation only: the outcome cannot be applied right now (e.g. the door closing with a player body in the gap).
	## The client filter (`check`) ignores it: the prompt keeps showing and the host rejects with `BLOCKED`.
	var blocked: bool = false


## Whether `actor_pos` is within the target's range (+ tolerance).
static func in_range(actor_pos: Vector2, target_pos: Vector2, interact_range: float, tolerance: float = 0.0) -> bool:
	return actor_pos.distance_to(target_pos) <= interact_range + maxf(tolerance, 0.0)


## Side constraint: whether the actor is at least `min_offset` away from the target centre along `side` (always true if side is ZERO).
static func on_side(actor_pos: Vector2, target_pos: Vector2, side: Vector2, min_offset: float) -> bool:
	if side.is_zero_approx():
		return true
	return (actor_pos - target_pos).dot(side.normalized()) >= min_offset


## Tag constraint: `actor_tags` maps tag -> tier (int); always true if no tag is required.
static func has_tag(tag: StringName, min_tier: int, actor_tags: Dictionary) -> bool:
	if tag == &"":
		return true
	var tier: Variant = actor_tags.get(tag, actor_tags.get(String(tag)))
	return tier != null and int(tier) >= min_tier


## Whether `peer_id` may start interacting with this target. Order: disabled -> busy -> range -> side -> tag.
## The client calls with no tolerance (0), the host with RANGE_TOLERANCE and SIDE_TOLERANCE. Not busy if this peer already holds the target.
static func check(target: Target, peer_id: int, actor_pos: Vector2, actor_tags: Dictionary,
		tolerance: float = 0.0, side_tolerance: float = 0.0) -> Result:
	if not target.enabled:
		return Result.DISABLED
	if target.busy_by != 0 and target.busy_by != peer_id:
		return Result.BUSY
	if not in_range(actor_pos, target.position, target.interact_range, tolerance):
		return Result.OUT_OF_RANGE
	if not on_side(actor_pos, target.position, target.side, target.side_min - maxf(side_tolerance, 0.0)):
		return Result.WRONG_SIDE
	if not has_tag(target.tag, target.tier, actor_tags):
		return Result.MISSING_TAG
	return Result.OK


## Host validation: cooldown before a new interaction, then `check` (with S2 range and side tolerance), finally the host's blocker (`Target.blocked`).
static func host_check(target: Target, peer_id: int, actor_pos: Vector2, actor_tags: Dictionary,
		cooldown_left: float) -> Result:
	if cooldown_left > 0.0 and target.busy_by != peer_id:
		return Result.COOLDOWN
	var result: Result = check(target, peer_id, actor_pos, actor_tags, RANGE_TOLERANCE, SIDE_TOLERANCE)
	if result == Result.OK and target.blocked:
		return Result.BLOCKED
	return result


## Whether a circle (body: centre + radius) overlaps a rotated rectangle (centre, half size, rotation rad); tangent contact is not overlap.
## Door: whether the closing leaf would hit a body in the gap.
static func circle_overlaps_box(center: Vector2, radius: float, box_center: Vector2, half_size: Vector2,
		box_rotation: float) -> bool:
	var local: Vector2 = (center - box_center).rotated(-box_rotation)
	var closest := Vector2(clampf(local.x, -half_size.x, half_size.x), clampf(local.y, -half_size.y, half_size.y))
	return local.distance_squared_to(closest) < radius * radius


## Whether an ongoing interaction may continue (host and client; with the S2 range tolerance).
static func keeps_going(target: Target, actor_pos: Vector2) -> bool:
	return in_range(actor_pos, target.position, target.interact_range, RANGE_TOLERANCE)


## Advances progress one step (negative values are clamped to zero).
static func advance(progress: float, delta: float) -> float:
	return maxf(progress, 0.0) + maxf(delta, 0.0)


## Whether the hold time has elapsed (hold time 0 or negative = instant action: complete at once).
static func is_complete(progress: float, hold_time: float) -> bool:
	return progress >= hold_time


## On release: counts as complete if progress is within the last TIME_TOLERANCE of the hold time, else cancelled
## (partial progress resets; the caller does the reset).
static func release_completes(progress: float, hold_time: float) -> bool:
	return progress >= hold_time - TIME_TOLERANCE


## Progress ratio 0..1 (1 if there is progress when hold time is 0).
static func ratio(progress: float, hold_time: float) -> float:
	if hold_time <= 0.0:
		return 1.0 if progress > 0.0 else 0.0
	return clampf(progress / hold_time, 0.0, 1.0)


## Index of the position in `positions` nearest to `actor_pos` (first on ties); -1 if the list is empty.
static func nearest(actor_pos: Vector2, positions: PackedVector2Array) -> int:
	var best: int = -1
	var best_dist: float = INF
	for i: int in positions.size():
		var d: float = actor_pos.distance_squared_to(positions[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best


## Dump/log name of the result ("busy", "out_of_range", ...).
static func result_name(result: Result) -> String:
	return str(_RESULT_NAMES.get(result, "unknown"))
