class_name CivilianRules
extends RefCounted
## Civilian observer rules (US-008 AC1/AC3/AC7/AC8; GDD §6.1, §9.3, §12; KR-020/021).
## Node-free: works on plain values only (Vector2, float, int, Rect2); no scene tree (KR-003, KR-018).
##
## - Behaviour factor: replaces the guard's mode factor; the player's single most suspicious current behaviour wins (max, not product).
##   Fill = base x band x factor (PerceptionRules); decay when unseen, `innocent_decay` when seen but innocent.
## - Cover (US-016 AC6, GDD §9.2): with customers inside, customer-zone factors are scaled by `cover_factor`; staff side and cash rows are exempt.
## - Reaction bubble ("?"/"!"): derived client-side from the replicated meter (ON-04); "?" has hysteresis, "!" locks while the brain is alarmed.
## - Contact (hold/catch): host position is led by `velocity x min(RTT/2, lead_cap)` (ON-03, favours the player); needs `contact_time` uninterrupted within `reach`.
## - Grocery interactions (US-010): purchase cost, loiter threshold moment, distraction log, planted-phone clock (end of file).

enum Zone { OUTSIDE, CUSTOMER, STAFF, BACKROOM }
## Row that supplies the factor (dump `behaviour`).
enum Behaviour { INNOCENT, LOITER, SNEAK, SPRINT, STAFF_SIDE, BAG_OR_LOCK, CASH, ALARM, WINDOW_STARE }
## Kind of interaction the player is sustaining (busy_by).
enum Interaction { NONE, TAMPER, CASH }
## Client-side bubble.
enum Bubble { NONE, NOTICE, ALARM }

const BEHAVIOUR_NAMES: Array[StringName] = [&"innocent", &"loiter", &"sneak", &"sprint", &"staff_side",
	&"bag_or_lock", &"cash", &"alarm", &"window_stare"]
const ZONE_NAMES: Array[StringName] = [&"outside", &"customer", &"staff", &"backroom"]


## Factor table (value object; filled from `data/npc/civilian_tuning.tres`, defaults neutral).
class Params:
	extends RefCounted
	## Seconds in the customer zone treated as innocent; the loiter factor applies afterwards.
	var loiter_grace: float = 0.0
	var loiter_factor: float = 0.0
	var sneak_factor: float = 0.0
	var sprint_factor: float = 0.0
	var staff_factor: float = 0.0
	var bag_or_lock_factor: float = 0.0
	var cash_factor: float = 0.0
	var alarm_factor: float = 0.0
	## From this alert level on every player with broken cover uses `alarm_factor` (grocery: 2 = owner shouted; US-048: an intact
	## cover keeps the normal rows).
	var alarm_level: int = 0
	## Decay while seen but innocent (units/s).
	var innocent_decay: float = 0.0
	## Bubble thresholds for "?" and "!" (meter units); "?" clears below `notice_at - bubble_hysteresis`.
	var notice_at: float = 0.0
	var detect_at: float = 0.0
	var bubble_hysteresis: float = 0.0
	## Cover factor (US-016): customer-zone rows while customers are inside; 1 = no cover.
	var cover_factor: float = 1.0
	## Window stare (US-044): seconds of looking in from outside treated as innocent, then the slow-fill factor
	## (passers-by and short glances are free).
	var window_stare_grace: float = 0.0
	var window_stare_factor: float = 0.0


## A target's state this step.
class Context:
	extends RefCounted
	var zone: Zone = Zone.OUTSIDE
	var stance: PerceptionRules.Stance = PerceptionRules.Stance.WALK
	var interaction: Interaction = Interaction.NONE
	var carrying_bag: bool = false
	var alert_level: int = 0
	## Total seconds spent inside the shop (BUY resets it, US-010).
	var loiter_time: float = 0.0
	## Customers inside (US-016 cover; only the owner's context fills this).
	var customers_inside: int = 0
	## Uninterrupted seconds staring in through the window from outside (US-044; owner's context only).
	var window_stare: float = 0.0
	## US-048 (GB-12, KR-041): the player's cover is intact (heist running, not broken); the ALARM row applies only to a broken cover.
	var cover_intact: bool = false


static func is_inside(zone: Zone) -> bool:
	return zone != Zone.OUTSIDE


## Factor of the most suspicious behaviour (max, not product).
static func factor(p: Params, ctx: Context) -> float:
	var b: Behaviour = behaviour(p, ctx)
	var f: float = factor_of(p, b)
	return f * p.cover_factor if covered(ctx, b) else f


## Whether cover applies (US-016 AC6): customers inside, target in customer zone, row is not staff/cash.
static func covered(ctx: Context, b: Behaviour) -> bool:
	return ctx.customers_inside > 0 and ctx.zone == Zone.CUSTOMER and b != Behaviour.STAFF_SIDE 		and b != Behaviour.CASH


## Row supplying the factor: the candidate with the largest factor (the later table row wins ties).
static func behaviour(p: Params, ctx: Context) -> Behaviour:
	var best: Behaviour = Behaviour.INNOCENT
	for b: Behaviour in candidates(p, ctx):
		if factor_of(p, b) >= factor_of(p, best):
			best = b
	return best


## Rows valid in this context (innocent excluded).
static func candidates(p: Params, ctx: Context) -> Array[Behaviour]:
	var out: Array[Behaviour] = []
	var inside: bool = is_inside(ctx.zone)
	if inside and ctx.loiter_time > p.loiter_grace:
		out.append(Behaviour.LOITER)
	if inside and ctx.stance == PerceptionRules.Stance.SNEAK:
		out.append(Behaviour.SNEAK)
	if inside and ctx.stance == PerceptionRules.Stance.SPRINT:
		out.append(Behaviour.SPRINT)
	if ctx.zone == Zone.STAFF or ctx.zone == Zone.BACKROOM:
		out.append(Behaviour.STAFF_SIDE)
	if ctx.carrying_bag or ctx.interaction == Interaction.TAMPER:
		out.append(Behaviour.BAG_OR_LOCK)
	if ctx.interaction == Interaction.CASH:
		out.append(Behaviour.CASH)
	if p.alarm_level > 0 and ctx.alert_level >= p.alarm_level and not ctx.cover_intact:
		out.append(Behaviour.ALARM)
	if not inside and p.window_stare_factor > 0.0 and ctx.window_stare > p.window_stare_grace:
		out.append(Behaviour.WINDOW_STARE)
	return out


static func factor_of(p: Params, b: Behaviour) -> float:
	match b:
		Behaviour.LOITER:
			return p.loiter_factor
		Behaviour.SNEAK:
			return p.sneak_factor
		Behaviour.SPRINT:
			return p.sprint_factor
		Behaviour.STAFF_SIDE:
			return p.staff_factor
		Behaviour.BAG_OR_LOCK:
			return p.bag_or_lock_factor
		Behaviour.CASH:
			return p.cash_factor
		Behaviour.ALARM:
			return p.alarm_factor
		Behaviour.WINDOW_STARE:
			return p.window_stare_factor
	return 0.0


static func behaviour_name(b: Behaviour) -> StringName:
	return BEHAVIOUR_NAMES[b] if b >= 0 and b < BEHAVIOUR_NAMES.size() else &""


static func zone_name(z: Zone) -> StringName:
	return ZONE_NAMES[z] if z >= 0 and z < ZONE_NAMES.size() else &""


## Zone of a point: `rects` Zone -> Array[Rect2] (same coordinate space); edges inclusive, outside if none match.
## Zones do not overlap (IS-023); if they do, staff/backroom dominate customer.
static func zone_at(pos: Vector2, rects: Dictionary) -> Zone:
	var found: Zone = Zone.OUTSIDE
	for z: Zone in [Zone.CUSTOMER, Zone.STAFF, Zone.BACKROOM]:
		for r: Rect2 in rects.get(z, []):
			if r.grow(0.001).has_point(pos):
				found = z
	return found


## ON-03: for hold/catch decisions the player's position is led along velocity by `min(RTT/2, cap)`.
static func predicted_position(pos: Vector2, velocity: Vector2, rtt_ms: float, cap_sec: float) -> Vector2:
	var lead: float = clampf(maxf(rtt_ms, 0.0) * 0.0005, 0.0, maxf(cap_sec, 0.0))
	return pos + velocity * lead


## One contact step: accumulates while within reach (`dist <= reach`), resets outside.
static func contact_step(contact: float, dist: float, reach: float, delta: float) -> float:
	return contact + maxf(delta, 0.0) if dist <= reach else 0.0


## Hold window: `first` on the first hold, `repeat` afterwards (GDD §9.3: 6 s, then 3 s).
static func hold_window(times_held_before: int, first: float, repeat: float) -> float:
	return first if times_held_before <= 0 else repeat


## Client bubble: alarm lock or meter >= detect -> "!"; meter >= notice -> "?"; a shown "?" persists until
## the meter drops below `notice_at - bubble_hysteresis` (no flicker at the threshold).
static func bubble(p: Params, meter: float, alarmed: bool, previous: Bubble) -> Bubble:
	if alarmed or meter >= p.detect_at - SuspicionMeter.EPSILON:
		return Bubble.ALARM
	if meter >= p.notice_at - SuspicionMeter.EPSILON:
		return Bubble.NOTICE
	if previous != Bubble.NONE and meter >= p.notice_at - p.bubble_hysteresis:
		return Bubble.NOTICE
	return Bubble.NONE


## --- Search after the shout (US-048; GB-12, KR-041) ---

## Sight fill stops here: while the owner is alarmed an intact-cover player's meter reached `cap` (perception's factor becomes 0,
## `outside_stare_cap` pattern). A meter already at detection is not held back (a player detected by the normal rows keeps the chain).
static func cover_cap_reached(value: float, cap: float, detect_at: float) -> bool:
	return value >= cap and value < detect_at - SuspicionMeter.EPSILON


## A direct suspicion gain limited by the cap (misdirect +30 on an intact cover while alarmed); 0 at or above the cap.
static func capped_gain(value: float, gain: float, cap: float) -> float:
	if gain <= 0.0:
		return gain
	return clampf(cap - value, 0.0, gain)


## SORGU-2 due: intact cover, free, meter >= `at` (0 = off) and not asked within `cooldown` s (`last_at` < 0 = never asked).
static func search_question_due(value: float, at: float, cover_intact: bool, free: bool, last_at: float, now: float,
		cooldown: float) -> bool:
	if at <= 0.0 or not cover_intact or not free or value < at - SuspicionMeter.EPSILON:
		return false
	return last_at < 0.0 or now - last_at >= cooldown


## --- Grocery interactions (US-010; GDD §9.3 "player tools", KR-026) ---

## State of the phone planted at a shelf end (replicated int; ShelfProp).
enum Phone { NONE, PLANTED, RINGING, FOUND, SILENT }
const PHONE_NAMES: Array[StringName] = [&"none", &"planted", &"ringing", &"found", &"silent"]


## BUY cost: the price if team cash covers it, else 0 (free; GDD §9.3, Phase 2).
static func purchase_cost(team_cash: int, price: int) -> int:
	return price if price > 0 and team_cash >= price else 0


## Whether the loiter threshold was crossed this step (before < threshold <= now; the "what does he want" moment).
static func loiter_crossed(before: float, now: float, grace: float) -> bool:
	return before < grace and now >= grace


## OYALA soothe (GDD §9.3): suspicion removed on the player's `uses`-th soothe (beyond `steps` = 0, "never again").
static func soothe_amount(uses: int, steps: Array[float]) -> float:
	return maxf(steps[uses], 0.0) if uses >= 0 and uses < steps.size() else 0.0


## MISDIRECT (US-043): shown direction = away from the speaker's escape point (`fallback` if none or on top of it);
## target = speaker + direction x `run_px`.
static func misdirect_point(speaker: Vector2, escape: Vector2, run_px: float, fallback: Vector2 = Vector2.UP) -> Vector2:
	var dir: Vector2 = fallback.normalized()
	if escape.is_finite() and not speaker.is_equal_approx(escape):
		dir = (speaker - escape).normalized()
	return speaker + dir * maxf(run_px, 0.0)


## Distraction log (per job): each source (prop + kind) counts once, so a still-ringing phone is one distraction;
## the second and later sources are "again?" (suspicion on the one in charge at the owner).
class DistractionLog:
	extends RefCounted
	var count: int = 0
	var _seen: Dictionary = {}

	## Counts a new source and returns true; a known source (or empty key) returns false.
	func note(key: String) -> bool:
		if key.is_empty() or _seen.has(key):
			return false
		_seen[key] = true
		count += 1
		return true

	## Whether the last counted source was the second or later.
	func is_again() -> bool:
		return count >= 2


## Phone clock (shelf end; host): waits `delay` s after planting, rings every `interval` up to `max_rings` times, then goes
## silent; FOUND when the owner finds it (ringing or silent). One use per clock.
class PhoneClock:
	extends RefCounted
	var state: int = Phone.NONE
	## Planting player (in charge) and ring count.
	var peer: int = 0
	var rings: int = 0
	var delay: float = 0.0
	var interval: float = 1.0
	var max_rings: int = 1
	var _left: float = 0.0

	func _init(delay_sec: float, interval_sec: float, ring_max: int) -> void:
		delay = maxf(delay_sec, 0.0)
		interval = maxf(interval_sec, 0.01)
		max_rings = maxi(ring_max, 1)

	## Plant the phone (only when idle). True if accepted.
	func plant(peer_id: int) -> bool:
		if state != Phone.NONE:
			return false
		state = Phone.PLANTED
		peer = peer_id
		_left = delay
		return true

	## One step; true if it rang this step.
	func step(delta: float) -> bool:
		var dt: float = maxf(delta, 0.0)
		match state:
			Phone.PLANTED:
				_left -= dt
				if _left <= 0.0:
					state = Phone.RINGING
					rings = 1
					_left += interval
					return true
			Phone.RINGING:
				_left -= dt
				if _left <= 0.0:
					if rings >= max_rings:
						state = Phone.SILENT
						return false
					rings += 1
					_left += interval
					return true
		return false

	## Owner found it: taken if ringing or silent (true).
	func take() -> bool:
		if state != Phone.RINGING and state != Phone.SILENT:
			return false
		state = Phone.FOUND
		return true
