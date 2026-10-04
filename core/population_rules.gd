class_name PopulationRules
extends RefCounted
## Venue population rules (US-016 AC1/AC2/AC4/AC5; GDD §9.2 table; oyun-yz round 2 #13). Node-free: arrival times, caps, customer/passer-by plans and street route maths; no scene tree (KR-003).
## The population spawner (`entities/npc/population.gd`, host only) calls `Schedule.tick` each step and spawns the returned orders. Deterministic (I6): same seed + same counts -> same arrivals and plans
## (single RNG, fixed order: customer first, then passer-by; the plan is drawn from the same RNG at arrival).
##
## - Customer: first arrival in [first_min, first_max], then interval +/- jitter. At arrival, if the inside cap (active customers) or NPC cap is full or alert >= `pause_alert_level`, nobody comes and the route is cancelled: the next interval is drawn.
## - Passer-by: interval +/- jitter (the first arrival is also an interval), street cap; same cancel rule.
## - NPC cap: total NPCs (owner, customers, passers-by, neighbours) + space reserved for the neighbour < `max_npcs`.
## - Customer plan: stay [stay_min, stay_max]; 1-2 shelf spots ([min_spots, max_spots]), each [shop_min, shop_max] s; if two spots + service + walk margin exceed the stay, one spot.
## - Passer-by plan: for each window pane, a `look_chance` chance of a `look_sec` look inside.

enum Role { CUSTOMER, PASSERBY }

const ROLE_NAMES: Array[StringName] = [&"customer", &"passerby"]


## Seed input of the schedule (IS-058b): the data seed (`population_tuning.population_seed`) mixed with the session seed
## (`Game.session_seed()`); session seed 0 -> the data seed unchanged (SessionSeed.derive).
static func schedule_seed(session_seed: int, data_seed: int) -> int:
	return SessionSeed.derive(session_seed, data_seed, SessionSeed.SALT_POPULATION)


## Settings (value object; `data/npc/population.tres` fills it, defaults neutral).
class Params:
	extends RefCounted
	var customer_first_min: float = 0.0
	var customer_first_max: float = 0.0
	var customer_interval: float = 0.0
	var customer_jitter: float = 0.0
	var customer_max: int = 0
	var stay_min: float = 0.0
	var stay_max: float = 0.0
	var min_spots: int = 1
	var max_spots: int = 1
	var shop_min: float = 0.0
	var shop_max: float = 0.0
	var serve_sec: float = 0.0
	var walk_margin_sec: float = 0.0
	var passerby_interval: float = 0.0
	var passerby_jitter: float = 0.0
	var passerby_max: int = 0
	var look_chance: float = 0.0
	var look_sec: float = 0.0
	## Window pane (WindowLook*) count: the passer-by plan carries this many look dice.
	var window_count: int = 0
	var max_npcs: int = 0
	## Space reserved for the neighbour (chaser): the population stays this far below the cap.
	var reserve: int = 0
	## From this alert level on no new civilians arrive (0 = never pauses).
	var pause_alert_level: int = 0


## Current counts (the spawner fills them each step).
class Counts:
	extends RefCounted
	var customers: int = 0
	var passersby: int = 0
	## All NPCs (owner + civilians + neighbour).
	var npcs: int = 0
	var alert_level: int = 0


## A spawn order: role + plan + arrival time.
class Order:
	extends RefCounted
	var role: Role = Role.CUSTOMER
	var at: float = 0.0
	## Customer: stay (s), shelf spot durations (s) and pick dice (0..1, turned into a free spot by `pick`).
	var stay_sec: float = 0.0
	var dwell: Array[float] = []
	var picks: Array[float] = []
	## Passer-by: look per window pane (true = looks).
	var looks: Array[bool] = []


## Arrival scheduler (seeded).
class Schedule:
	extends RefCounted
	var params: Params
	var clock: float = 0.0
	var next_customer: float = INF
	var next_passerby: float = INF
	## Arrivals spawned and cancelled (dump, tests).
	var spawned: Array[Order] = []
	var cancelled: Array[Dictionary] = []
	var _rng := RandomNumberGenerator.new()

	func _init(p: Params, seed_value: int) -> void:
		params = p
		_rng.seed = seed_value
		if p.customer_interval > 0.0 or p.customer_first_max > 0.0:
			next_customer = _rng.randf_range(minf(p.customer_first_min, p.customer_first_max),
				maxf(p.customer_first_min, p.customer_first_max))
		if p.passerby_interval > 0.0:
			next_passerby = _interval(p.passerby_interval, p.passerby_jitter)

	## Time advances by `delta`; returns orders for due arrivals (customer first). `counts` is updated per order
	## (two arrivals in one step must not exceed the cap together).
	func tick(delta: float, counts: Counts) -> Array[Order]:
		var out: Array[Order] = []
		clock += maxf(delta, 0.0)
		if clock >= next_customer:
			if PopulationRules.may_spawn(params, counts, Role.CUSTOMER):
				var order: Order = _customer_order()
				out.append(order)
				spawned.append(order)
				counts.customers += 1
				counts.npcs += 1
			else:
				cancelled.append({"role": Role.CUSTOMER, "at": clock})
			next_customer = clock + _interval(params.customer_interval, params.customer_jitter) \
				if params.customer_interval > 0.0 else INF
		if clock >= next_passerby:
			if PopulationRules.may_spawn(params, counts, Role.PASSERBY):
				var order: Order = _passerby_order()
				out.append(order)
				spawned.append(order)
				counts.passersby += 1
				counts.npcs += 1
			else:
				cancelled.append({"role": Role.PASSERBY, "at": clock})
			next_passerby = clock + _interval(params.passerby_interval, params.passerby_jitter)
		return out

	func _interval(mean: float, jitter: float) -> float:
		var j: float = absf(jitter)
		return maxf(_rng.randf_range(mean - j, mean + j), 0.5)

	func _customer_order() -> Order:
		var o := Order.new()
		o.role = Role.CUSTOMER
		o.at = clock
		o.stay_sec = _rng.randf_range(minf(params.stay_min, params.stay_max), maxf(params.stay_min, params.stay_max))
		var lo: int = maxi(mini(params.min_spots, params.max_spots), 0)
		var hi: int = maxi(params.min_spots, params.max_spots)
		var count: int = _rng.randi_range(lo, hi)
		for i: int in count:
			o.dwell.append(_rng.randf_range(minf(params.shop_min, params.shop_max), maxf(params.shop_min, params.shop_max)))
			o.picks.append(_rng.randf())
		PopulationRules.fit_stay(o, params)
		return o

	func _passerby_order() -> Order:
		var o := Order.new()
		o.role = Role.PASSERBY
		o.at = clock
		for i: int in maxi(params.window_count, 0):
			o.looks.append(_rng.randf() < params.look_chance)
		return o


## Whether an arrival may happen: role cap, NPC cap (neighbour reserve included) and alert pause.
static func may_spawn(p: Params, counts: Counts, role: Role) -> bool:
	if p.pause_alert_level > 0 and counts.alert_level >= p.pause_alert_level:
		return false
	if counts.npcs + 1 + maxi(p.reserve, 0) > p.max_npcs:
		return false
	match role:
		Role.CUSTOMER:
			return counts.customers < p.customer_max
		Role.PASSERBY:
			return counts.passersby < p.passerby_max
	return false


## If two shelf spots + service + walk margin exceed the stay, spots are dropped from the end (at least one remains).
static func fit_stay(o: Order, p: Params) -> void:
	while o.dwell.size() > 1 and _sum(o.dwell) + p.serve_sec + p.walk_margin_sec > o.stay_sec:
		o.dwell.pop_back()
		o.picks.pop_back()


## Roll (0..1) -> one of the free candidates (empty if none).
static func pick(free: Array[StringName], roll: float) -> StringName:
	if free.is_empty():
		return &""
	return free[clampi(floori(clampf(roll, 0.0, 0.999999) * free.size()), 0, free.size() - 1)]


## Street route: route points in order; each look point goes onto the route segment it is nearest to, ordered by projection along the segment.
## Returns [{"pos": Vector2, "look": int}] (look = look index, -1 at a route point).
static func street_route(route: Array[Vector2], looks: Array[Vector2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if route.is_empty():
		return out
	## segment index -> [[t, look index], ...]
	var on_segment: Dictionary = {}
	for li: int in looks.size():
		var best: int = -1
		var best_d: float = INF
		var best_t: float = 0.0
		for si: int in route.size() - 1:
			var a: Vector2 = route[si]
			var b: Vector2 = route[si + 1]
			var ab: Vector2 = b - a
			var t: float = clampf((looks[li] - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d: float = looks[li].distance_to(a + ab * t)
			if d < best_d:
				best_d = d
				best = si
				best_t = t
		if best >= 0:
			if not on_segment.has(best):
				on_segment[best] = []
			(on_segment[best] as Array).append([best_t, li])
	for si: int in route.size():
		out.append({"pos": route[si], "look": -1})
		if on_segment.has(si):
			var items: Array = on_segment[si]
			items.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
			for item: Array in items:
				out.append({"pos": looks[int(item[1])], "look": int(item[1])})
	return out


## Direction to look inside from a window: unit direction from the look point to the nearest point of the inside (zone rects);
## zero if the point is inside or there are no zones.
static func look_facing(from: Vector2, inside: Array[Rect2]) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for r: Rect2 in inside:
		var p := Vector2(clampf(from.x, r.position.x, r.end.x), clampf(from.y, r.position.y, r.end.y))
		var d: float = from.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	if not best.is_finite() or best_d <= 0.001:
		return Vector2.ZERO
	return (best - from).normalized()


static func role_name(role: int) -> StringName:
	return ROLE_NAMES[role] if role >= 0 and role < ROLE_NAMES.size() else &""


static func _sum(values: Array[float]) -> float:
	var s: float = 0.0
	for v: float in values:
		s += v
	return s
