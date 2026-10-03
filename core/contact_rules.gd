class_name ContactRules
extends RefCounted
## Player-NPC contact and shove rules (US-037; KR-027; GDD §9.2 "Obstacle", §12). Node-free: plain values only (Vector2, float, int);
## no scene tree (KR-003, KR-018). Numbers come from `data/npc/contact_tuning.tres` (ContactTuning.rules_params); defaults are neutral.
##
## - Calm contact (alert <= `calm_max_alert`): no physical collision; while the player's circle overlaps an NPC's (< `contact_px`) the
##   player's speed is scaled by `calm_speed_factor`; the NPC does not move; its drawing leans `lean_px` away (visual, local).
## - SHOVE: sprinting (mode sprint, speed >= `min_push_speed`) into an NPC within +-`push_half_angle_deg` of the heading = a shove (no key).
##   The NPC slides `slide_px` over `slide_sec` (physics keeps it out of walls), staggers (brain stopped); the pusher is scaled by
##   `pusher_speed_factor` for `pusher_slow_sec`; the same NPC cannot be shoved again for `repush_sec`.
## - Calm cost: shoved NPC +`pushed_suspicion` x n, observers with line of sight +`observer_suspicion` x n; n = the pusher's shoves in the
##   last `push_window_sec` (this one included), capped at `push_count_cap`. Hot (alert above calm): no cost.
## - Chaser: staggers `chaser_stagger_sec`, then immune `chaser_immune_sec`; contact from its back (within `back_half_angle_deg` of its rear)
##   is not a shove. Hot contacts get `hot_slack_px` host slack (S2: in the player's favour; calm costs get none).
## - The host decides shoves (NpcState, PushHistory); a client predicts only its own slowdown (Predictor; S2).

## Float comparison margin.
const EPSILON := 0.0001


## Tuning values (value object; filled from ContactTuning).
class Params:
	extends RefCounted
	## Circle overlap distance (px; two body radii).
	var contact_px: float = 0.0
	## Highest alert level that counts as calm (contact slowdown, shove costs).
	var calm_max_alert: int = 0
	## Player speed factor while overlapping an NPC in calm.
	var calm_speed_factor: float = 1.0
	## How far the NPC drawing leans away from an overlapping player (px; visual).
	var lean_px: float = 0.0
	## Shove cone: half angle around the pusher's heading (degrees).
	var push_half_angle_deg: float = 0.0
	## Minimum speed of a sprinting player that can shove (px/s).
	var min_push_speed: float = 0.0
	## NPC slide distance (px) and duration (s).
	var slide_px: float = 0.0
	var slide_sec: float = 0.0
	## NPC stagger (brain stopped; s, from the shove).
	var stagger_sec: float = 0.0
	## Same NPC cannot be shoved again within this (s).
	var repush_sec: float = 0.0
	## Pusher slowdown: duration (s) and speed factor.
	var pusher_slow_sec: float = 0.0
	var pusher_speed_factor: float = 1.0
	## Shove counter window (s) and cap.
	var push_window_sec: float = 0.0
	var push_count_cap: int = 1
	## Calm costs per shove count unit.
	var pushed_suspicion: float = 0.0
	var observer_suspicion: float = 0.0
	## Chaser: stagger (s) and shove immunity afterwards (s; counted from the shove).
	var chaser_stagger_sec: float = 0.0
	var chaser_immune_sec: float = 0.0
	## Rear sector of a chaser where contact is not a shove (half angle around its back, degrees).
	var back_half_angle_deg: float = 0.0
	## Host-side contact slack in hot alert (px; S2 tolerance in the player's favour).
	var hot_slack_px: float = 0.0


## Whether the alert level counts as calm (contact slowdown, shove costs).
static func is_calm(p: Params, alert_level: int) -> bool:
	return alert_level <= p.calm_max_alert


## Whether two circles overlap: distance < contact + slack.
static func overlaps(p: Params, a: Vector2, b: Vector2, slack: float = 0.0) -> bool:
	return a.distance_to(b) < p.contact_px + maxf(slack, 0.0)


## Shove heading of a player: unit `direction` if sprinting at >= `min_push_speed`, else ZERO (no shove).
static func push_heading(p: Params, sprinting: bool, speed: float, direction: Vector2) -> Vector2:
	if not sprinting or speed < p.min_push_speed - EPSILON or direction.is_zero_approx():
		return Vector2.ZERO
	return direction.normalized()


## Whether the NPC is within the shove cone (+-half angle around `heading`) of the pusher. Dead centre counts.
static func in_front(p: Params, pusher_pos: Vector2, heading: Vector2, npc_pos: Vector2) -> bool:
	if heading.is_zero_approx():
		return false
	var to: Vector2 = npc_pos - pusher_pos
	if to.is_zero_approx():
		return true
	return absf(heading.angle_to(to)) <= deg_to_rad(p.push_half_angle_deg) + EPSILON


## Whether the pusher is in the NPC's rear sector (within `back_half_angle_deg` of the direction opposite its facing).
static func from_behind(p: Params, npc_pos: Vector2, npc_facing: Vector2, pusher_pos: Vector2) -> bool:
	var to: Vector2 = pusher_pos - npc_pos
	if npc_facing.is_zero_approx() or to.is_zero_approx():
		return false
	return absf((-npc_facing).angle_to(to)) < deg_to_rad(p.back_half_angle_deg) - EPSILON


## Shove count used for the cost: `recent` shoves in the window (this one included), clamped to [1, cap].
static func push_count(p: Params, recent: int) -> int:
	return clampi(recent, 1, maxi(p.push_count_cap, 1))


## Calm cost to the shoved NPC (suspicion units); 0 when hot.
static func pushed_cost(p: Params, count: int, calm: bool) -> float:
	return p.pushed_suspicion * count if calm else 0.0


## Calm cost to each observer with line of sight; 0 when hot.
static func observer_cost(p: Params, count: int, calm: bool) -> float:
	return p.observer_suspicion * count if calm else 0.0


## Slide velocity of a shoved NPC (px/s along the heading).
static func slide_velocity(p: Params, heading: Vector2) -> Vector2:
	if p.slide_sec <= 0.0 or heading.is_zero_approx():
		return Vector2.ZERO
	return heading.normalized() * (p.slide_px / p.slide_sec)


## Lean offset of an NPC drawing (visual): `lean_px` away from an overlapping player, else ZERO.
static func lean_offset(p: Params, npc_pos: Vector2, player_pos: Vector2) -> Vector2:
	var away: Vector2 = npc_pos - player_pos
	if not overlaps(p, npc_pos, player_pos) or away.is_zero_approx():
		return Vector2.ZERO
	return away.normalized() * p.lean_px


## Host: a shoved NPC's response (slide, stagger, re-shove cooldown, immunity). `step` returns the slide velocity while sliding.
class NpcState:
	extends RefCounted
	var slide_left: float = 0.0
	var stagger_left: float = 0.0
	var cooldown_left: float = 0.0
	var immune_left: float = 0.0
	var velocity: Vector2 = Vector2.ZERO

	func can_be_pushed() -> bool:
		return cooldown_left <= EPSILON and immune_left <= EPSILON

	## Starts a shove response. `stagger` 0 = slide only (brain keeps running); `immune` 0 = only the re-shove cooldown.
	func start(p: Params, heading: Vector2, stagger: float, immune: float) -> void:
		velocity = ContactRules.slide_velocity(p, heading)
		slide_left = p.slide_sec if not velocity.is_zero_approx() else 0.0
		stagger_left = maxf(stagger, 0.0)
		cooldown_left = maxf(p.repush_sec, 0.0)
		immune_left = maxf(immune, 0.0)

	## Advances timers by `delta`; slide velocity for this step (ZERO when not sliding).
	func step(delta: float) -> Vector2:
		var out: Vector2 = velocity if slide_left > EPSILON else Vector2.ZERO
		var dt: float = maxf(delta, 0.0)
		slide_left = maxf(slide_left - dt, 0.0)
		stagger_left = maxf(stagger_left - dt, 0.0)
		cooldown_left = maxf(cooldown_left - dt, 0.0)
		immune_left = maxf(immune_left - dt, 0.0)
		return out

	func is_sliding() -> bool:
		return slide_left > EPSILON

	func is_staggering() -> bool:
		return stagger_left > EPSILON


## Host: recent shoves received by one NPC (peer, age). The counter n sums these over all NPCs.
class PushHistory:
	extends RefCounted
	var _peers: PackedInt32Array = PackedInt32Array()
	var _ages: PackedFloat64Array = PackedFloat64Array()

	func add(peer_id: int) -> void:
		_peers.append(peer_id)
		_ages.append(0.0)

	## Ages entries by `delta` and drops those older than `window` s.
	func step(delta: float, window: float) -> void:
		var i: int = 0
		while i < _ages.size():
			_ages[i] += maxf(delta, 0.0)
			if _ages[i] > window + EPSILON:
				_ages.remove_at(i)
				_peers.remove_at(i)
			else:
				i += 1

	func count(peer_id: int) -> int:
		var n: int = 0
		for peer: int in _peers:
			if peer == peer_id:
				n += 1
		return n


## Client: local prediction of the player's own contact slowdown (S2: movement is client-authoritative; the host decides outcomes).
## Keys are NPC identities (instance ids); cooldowns mirror the host's re-shove/immunity times as far as the client knows them.
class Predictor:
	extends RefCounted
	## Shoves predicted by this player (dump).
	var predicted: int = 0
	var slow_left: float = 0.0
	var _cooldowns: Dictionary = {}

	func can_push(key: int) -> bool:
		return float(_cooldowns.get(key, 0.0)) <= EPSILON

	## Own predicted shove: pusher slowdown starts, the NPC is on cooldown for `cooldown` s.
	func note_push(p: Params, key: int, cooldown: float) -> void:
		predicted += 1
		slow_left = p.pusher_slow_sec
		note_cooldown(key, cooldown)

	## Host-confirmed shove by anyone (session event): the NPC is on cooldown for `cooldown` s.
	func note_cooldown(key: int, cooldown: float) -> void:
		_cooldowns[key] = maxf(float(_cooldowns.get(key, 0.0)), cooldown)

	## Speed factor this step: shove slowdown first, else calm overlap, else 1.
	func speed_factor(p: Params, calm_overlap: bool) -> float:
		if slow_left > EPSILON:
			return p.pusher_speed_factor
		if calm_overlap:
			return p.calm_speed_factor
		return 1.0

	func step(delta: float) -> void:
		var dt: float = maxf(delta, 0.0)
		slow_left = maxf(slow_left - dt, 0.0)
		for key: int in _cooldowns.keys():
			var left: float = float(_cooldowns[key]) - dt
			if left <= EPSILON:
				_cooldowns.erase(key)
			else:
				_cooldowns[key] = left
