class_name CivilianBrain
extends Node
## Civilian brain: customer and passerby (US-016 AC2/AC4/AC5; GDD §9.2; S2, S11). Host only; the Civilian root calls `step(delta)` each
## step and applies the returned velocity. The route uses `Agenda` linear mode (oyun-yz #12); spot reservation lives in the population
## spawner's `SpotRegistry`. States:
## - ROUTE: customer front door -> 1-2 shelf spots (time, faces the shelf) -> (when done) QUEUE; passerby along `StreetRoute1..N`, looks in
##   for `look_sec` at planned windows (cone passes through glass), GONE at route end.
## - QUEUE: holds a free queue spot, requests service from the owner on arrival (`serve_customer(serial)`); leaves when service ends
##   (DONE); gives up and leaves if service does not start within `queue_wait_sec`.
## - WATCH: suspicion >= 30 ("?"): stands, looks at the suspect's last seen spot; resumes its work `watch_release_sec` after dropping below.
## - Witness (100): does not shout. If it sees the owner (line of sight + range) TELL: walks to the owner, after `tell_min_sec` on arrival
##   (at most `tell_max_sec`) adds `tell_suspicion` to the owner's suspicion of that player (inquiry starts), leaves; if not, FLEE: runs out via
##   the front door (passerby: nearest street end).
## - Customer flees when alert is at or above `pause_alert_level` (owner shouted).
## - Front-door crossing (in/out) rings the bell for the owner (`door_bell`): the owner looks at the door for 1 s; on entering
##   `customer_enter`. LEAVE/FLEE route end -> GONE: `gone` -> population spawner deletes it.

## Host only: route finished, the civilian may be deleted.
signal gone()

enum State { ROUTE, QUEUE, WATCH, TELL, FLEE, LEAVE, GONE }

const STATE_NAMES: Array[StringName] = [&"route", &"queue", &"watch", &"tell", &"flee", &"leave", &"gone"]
const EDGES := {
	State.ROUTE: [State.QUEUE, State.WATCH, State.TELL, State.FLEE, State.LEAVE, State.GONE],
	State.QUEUE: [State.WATCH, State.TELL, State.FLEE, State.LEAVE],
	State.WATCH: [State.ROUTE, State.QUEUE, State.TELL, State.FLEE, State.LEAVE],
	State.TELL: [State.LEAVE, State.FLEE],
	State.FLEE: [State.GONE],
	State.LEAVE: [State.GONE],
	State.GONE: [],
}
## Spot arrival margin (px), door crossing (bell) radius (px), queue service request retry (s).
const STAND_PX := 6.0
const DOOR_PX := 48.0
const QUEUE_RETRY_SEC := 0.5
## Turning to the shelf: distances searched for the shelf (a sight-blocking obstacle) (px).
const SHELF_PROBE_PX: Array[float] = [16.0, 24.0, 32.0, 40.0, 48.0]

var tuning: PopulationTuning
var civilian_tuning: CivilianTuning
var fsm := Fsm.new(State.ROUTE, EDGES)
## Records (dump/tests): whether served, what it told (peer, t), window glance count.
var served: bool = false
var tells: Array[Dictionary] = []
var looks: int = 0
## Player witnessed (0 = none) and outcome ("tell" | "flee" | "").
var witness_peer: int = 0
var witness_outcome: StringName = &""

var body: Civilian = null
var perception: Perception = null
var suspicion: Suspicion = null
var agenda: Agenda = null
var mover: NpcMover = null
var senses: CivilianSenses = null

var _speed: float = 0.0
var _resume: int = State.ROUTE
var _watch_low: float = 0.0
var _queue_spot: StringName = &""
var _queue_wait: float = 0.0
var _queue_retry: float = 0.0
var _tell_peer: int = 0
var _tell_where: Vector2 = Vector2.INF
var _tell_t: float = 0.0
var _was_inside: bool = false
## First player to cross the detection (100) threshold (Suspicion `threshold_reached`; 0 = none).
var _detected: int = 0
var _look_counted: int = -1
## Route task index -> whether a look task (passerby).
var _look_tasks: Dictionary = {}


func setup(civilian: Civilian, civ_perception: Perception, civ_suspicion: Suspicion, civ_agenda: Agenda,
		civ_mover: NpcMover, civ_senses: CivilianSenses) -> void:
	body = civilian
	perception = civ_perception
	suspicion = civ_suspicion
	agenda = civ_agenda
	mover = civ_mover
	senses = civ_senses
	perception.set_hysteresis(civilian_tuning.hysteresis_angle_deg, civilian_tuning.hysteresis_range)
	perception.factor_query = senses.factor_for
	suspicion.innocent_decay_per_sec = civilian_tuning.innocent_decay_per_sec
	suspicion.threshold_reached.connect(_on_threshold)
	agenda.finished.connect(_on_route_finished)
	_was_inside = CivilianRules.is_inside(senses.zone_of(body.global_position))
	if body.is_customer():
		_speed = tuning.customer_speed
		agenda.setup_route(_customer_route(), _route_seed(), senses.marker_positions)
	else:
		_speed = tuning.passerby_speed
		agenda.setup_route(_passerby_route(), _route_seed(), senses.marker_positions)


func state() -> int:
	return fsm.state


func state_name() -> StringName:
	return STATE_NAMES[fsm.state]


func queue_spot() -> StringName:
	return _queue_spot


## One step (host): senses -> suspicion -> reaction -> the state's desired velocity (global px/s).
func step(delta: float) -> Vector2:
	fsm.step(delta)
	if fsm.state == State.GONE:
		return Vector2.ZERO
	suspicion.tick(delta)
	_bell()
	_react()
	match fsm.state:
		State.ROUTE:
			return _route(delta)
		State.QUEUE:
			return _queue(delta)
		State.WATCH:
			return _watch(delta)
		State.TELL:
			return _tell(delta)
		State.FLEE, State.LEAVE:
			return _route(delta)
	return Vector2.ZERO


## --- reaction ---

func _react() -> void:
	if fsm.state in [State.TELL, State.FLEE, State.LEAVE, State.GONE]:
		return
	if body.is_customer() and tuning.pause_alert_level > 0 and Game.alert_level() >= tuning.pause_alert_level:
		_flee(0)
		return
	if _detected != 0 and witness_peer == 0:
		witness_peer = _detected
		if _sees_owner():
			_start_tell(witness_peer)
		else:
			_flee(witness_peer)
		return
	var peer: int = _top_peer()
	var level: int = suspicion.level_of(peer) if peer != 0 else Suspicion.Level.CALM
	if level >= Suspicion.Level.NOTICE and fsm.state != State.WATCH:
		_resume = fsm.state
		_watch_low = 0.0
		mover.stop()
		fsm.go(State.WATCH)


func _on_threshold(peer_id: int, level: int) -> void:
	if level >= Suspicion.Level.DETECT and _detected == 0:
		var player: Node = senses.player(peer_id)
		if player == null or not player.has_method(&"is_free") or bool(player.call(&"is_free")):
			_detected = peer_id


func _watch(delta: float) -> Vector2:
	var peer: int = _top_peer()
	var level: int = suspicion.level_of(peer) if peer != 0 else Suspicion.Level.CALM
	if level < Suspicion.Level.NOTICE:
		_watch_low += maxf(delta, 0.0)
		if _watch_low >= tuning.watch_release_sec:
			fsm.go(_resume)
	else:
		_watch_low = 0.0
	mover.stop()
	var at: Vector2 = suspicion.last_seen_position(peer) if peer != 0 else Vector2.INF
	if at.is_finite():
		perception.turn_toward(at - body.global_position, delta)
	return Vector2.ZERO


## Whether it sees the owner: the active owner is in range and either line of sight is clear (windows pass) or both are on the sales
## floor (customer zone / staff side: the counter is low and can be seen over; an owner in the backroom is not seen).
func _sees_owner() -> bool:
	var o: Node2D = body.store_owner as Node2D
	if o == null or not is_instance_valid(o) or not bool(o.get(&"active")):
		return false
	var here: Vector2 = body.global_position
	if here.distance_to(o.global_position) > tuning.owner_sight_range:
		return false
	if _on_sales_floor(here) and _on_sales_floor(o.global_position):
		return true
	return perception.has_line_of_sight(here, o.global_position)


func _on_sales_floor(pos: Vector2) -> bool:
	var zone: CivilianRules.Zone = senses.zone_of(pos)
	return zone == CivilianRules.Zone.CUSTOMER or zone == CivilianRules.Zone.STAFF


func _start_tell(peer: int) -> void:
	_tell_peer = peer
	_tell_where = suspicion.last_seen_position(peer)
	_tell_t = 0.0
	witness_outcome = &"tell"
	fsm.go(State.TELL)


func _tell(delta: float) -> Vector2:
	_tell_t += maxf(delta, 0.0)
	var o: Node2D = body.store_owner as Node2D
	if o == null or not is_instance_valid(o):
		_flee(_tell_peer)
		return Vector2.ZERO
	var at: Vector2 = o.global_position
	var near: bool = body.global_position.distance_to(at) <= tuning.tell_reach + STAND_PX
	if (near and _tell_t >= tuning.tell_min_sec) or _tell_t >= tuning.tell_max_sec:
		if o.has_method(&"report_suspicion"):
			o.call(&"report_suspicion", _tell_peer, tuning.tell_suspicion, _tell_where)
		tells.append({"peer": _tell_peer, "t": snappedf(fsm.clock, 0.01)})
		body.host_event(StringName("%s_tell" % body.role_name()), _tell_peer)
		_leave(State.LEAVE, _speed)
		return Vector2.ZERO
	if near:
		mover.stop()
		perception.turn_toward(at - body.global_position, delta)
		return Vector2.ZERO
	mover.move_to(at, tuning.tell_speed, tuning.tell_reach)
	return _walk(delta)


func _flee(peer: int) -> void:
	if witness_outcome.is_empty() and peer != 0:
		witness_outcome = &"flee"
	body.host_event(StringName("%s_flee" % body.role_name()), peer)
	_leave(State.FLEE, tuning.flee_speed)


## Exit route: via the front door if inside, then to the customer exit point / the passerby's nearest street end.
func _leave(next_state: int, speed: float) -> void:
	_release_spots()
	_speed = speed
	mover.stop()
	fsm.go(next_state)
	var tasks: Array[AgendaTask] = []
	if CivilianRules.is_inside(senses.zone_of(body.global_position)):
		tasks.append(_task(&"door", tuning.front_door_marker, 0.0, Vector2.ZERO))
	var exit: StringName = tuning.customer_exit_marker if body.is_customer() else _nearest_route_end()
	if not exit.is_empty():
		tasks.append(_task(&"exit", exit, 0.0, Vector2.ZERO))
	agenda.setup_route(tasks, _route_seed(), senses.marker_positions)


func _top_peer() -> int:
	var best: int = 0
	var best_value: float = 0.0
	for peer_id: int in suspicion.peers():
		var player: Node = senses.player(peer_id)
		if player != null and player.has_method(&"is_free") and not bool(player.call(&"is_free")):
			continue
		var value: float = suspicion.value_of(peer_id)
		if value > best_value:
			best_value = value
			best = peer_id
	return best


## --- route ---

func _route(delta: float) -> Vector2:
	var goal: Vector2 = agenda.goal_position()
	if goal.is_finite():
		mover.move_to(goal, _speed, STAND_PX)
	else:
		mover.stop()
	agenda.step(delta, mover.arrived() or mover.failed())
	if fsm.state == State.GONE or fsm.state == State.QUEUE:
		return Vector2.ZERO
	var index: int = agenda.route_index()
	if _look_tasks.has(index) and agenda.has_arrived() and _look_counted != index and fsm.state == State.ROUTE:
		_look_counted = index
		looks += 1
	return _walk(delta)


func _walk(delta: float) -> Vector2:
	var velocity: Vector2 = mover.desired_velocity(delta)
	if velocity.length() > 1.0:
		perception.turn_toward(velocity, delta)
	else:
		var look: Vector2 = agenda.goal_facing(body.global_position)
		if not look.is_zero_approx():
			perception.turn_toward(look, delta)
	return velocity


func _on_route_finished() -> void:
	match fsm.state:
		State.ROUTE:
			if body.is_customer():
				_release_spots()
				_queue_spot = _claim_queue()
				_queue_wait = 0.0
				_queue_retry = 0.0
				fsm.go(State.QUEUE)
			else:
				_go_gone()
		State.FLEE, State.LEAVE:
			_go_gone()


func _go_gone() -> void:
	_release_spots()
	if fsm.go(State.GONE):
		mover.stop()
		gone.emit()


## --- queue ---

func _queue(delta: float) -> Vector2:
	if _queue_spot.is_empty():
		_queue_spot = _claim_queue()
	var spot: Vector2 = senses.marker_position(_queue_spot) if not _queue_spot.is_empty() else Vector2.INF
	if spot.is_finite():
		mover.move_to(spot, _speed, STAND_PX)
	var arrived: bool = spot.is_finite() and (mover.arrived() or mover.failed())
	var o: Node = body.store_owner
	var serve: int = int(o.call(&"serve_state", body.serial)) if o != null and is_instance_valid(o) \
		else OwnerBrain.Serve.NONE
	if serve == OwnerBrain.Serve.DONE:
		served = true
		_leave(State.LEAVE, _speed)
		return Vector2.ZERO
	if arrived and serve != OwnerBrain.Serve.ACTIVE and serve != OwnerBrain.Serve.PENDING:
		_queue_retry -= maxf(delta, 0.0)
		if _queue_retry <= 0.0 and o != null and is_instance_valid(o):
			_queue_retry = QUEUE_RETRY_SEC
			o.call(&"serve_customer", body.serial)
	if arrived and serve != OwnerBrain.Serve.ACTIVE:
		_queue_wait += maxf(delta, 0.0)
		if _queue_wait >= tuning.queue_wait_sec:
			_leave(State.LEAVE, _speed)
			return Vector2.ZERO
	if arrived:
		var look: Vector2 = senses.marker_position(tuning.queue_look_marker)
		if look.is_finite():
			perception.turn_toward(look - body.global_position, delta)
		return Vector2.ZERO
	return _walk(delta)


## --- front door (bell) ---

func _bell() -> void:
	var here: Vector2 = body.global_position
	var inside: bool = CivilianRules.is_inside(senses.zone_of(here))
	if inside == _was_inside:
		return
	_was_inside = inside
	var door: Vector2 = senses.marker_position(tuning.front_door_marker)
	if not door.is_finite() or here.distance_to(door) > DOOR_PX:
		return
	var o: Node = body.store_owner
	if o != null and is_instance_valid(o) and o.has_method(&"door_bell"):
		o.call(&"door_bell", door)
	if inside and body.is_customer():
		body.host_event(&"customer_enter", 0)


## --- route setup ---

## Route agenda seed: the civilian's serial mixed with the session seed (IS-058b; session seed 0 -> the serial, today's behaviour).
func _route_seed() -> int:
	return SessionSeed.derive(Game.session_seed(), body.serial, SessionSeed.SALT_CIVILIAN_ROUTE)


func _customer_route() -> Array[AgendaTask]:
	var tasks: Array[AgendaTask] = [_task(&"door", tuning.front_door_marker, 0.0, Vector2.ZERO)]
	var dwell: Array[float] = body.order.dwell if body.order != null else ([] as Array[float])
	for i: int in body.shop_spots.size():
		var spot: StringName = body.shop_spots[i]
		var sec: float = dwell[i] if i < dwell.size() else 0.0
		tasks.append(_task(&"shop", spot, sec, _shelf_facing(senses.marker_position(spot))))
	return tasks


func _passerby_route() -> Array[AgendaTask]:
	var tasks: Array[AgendaTask] = []
	var names: Array[StringName] = senses.marker_names(tuning.route_prefix)
	var windows: Array[StringName] = senses.marker_names(tuning.window_prefix)
	var route: Array[Vector2] = []
	for n: StringName in names:
		route.append(senses.marker_position(n))
	var look_points: Array[Vector2] = []
	for n: StringName in windows:
		look_points.append(senses.marker_position(n))
	var inside: Array[Rect2] = senses.inside_rects()
	for item: Dictionary in PopulationRules.street_route(route, look_points):
		var li: int = int(item["look"])
		if li < 0:
			tasks.append(_task(&"street", names[route.find(item["pos"] as Vector2)], 0.0, Vector2.ZERO))
			continue
		var looks_here: bool = body.order != null and li < body.order.looks.size() and body.order.looks[li]
		if looks_here:
			_look_tasks[tasks.size()] = true
			tasks.append(_task(&"look", windows[li], tuning.look_sec,
				PopulationRules.look_facing(look_points[li], inside)))
	return tasks


func _task(task_name: StringName, marker: StringName, sec: float, look: Vector2) -> AgendaTask:
	var t := AgendaTask.new()
	t.name = task_name
	t.marker = marker
	t.min_sec = sec
	t.max_sec = sec
	t.facing = look
	return t


## Turning to the shelf at a shelf spot: direction of the nearest sight-blocking obstacle (order: up, down, left, right).
func _shelf_facing(at: Vector2) -> Vector2:
	if not at.is_finite():
		return Vector2.ZERO
	for d: float in SHELF_PROBE_PX:
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			if not perception.has_line_of_sight(at, at + dir * d):
				return dir
	return Vector2.ZERO


func _nearest_route_end() -> StringName:
	var names: Array[StringName] = senses.marker_names(tuning.route_prefix)
	if names.is_empty():
		return tuning.customer_exit_marker
	var here: Vector2 = body.global_position
	var first: StringName = names[0]
	var last: StringName = names[names.size() - 1]
	return first if here.distance_to(senses.marker_position(first)) <= here.distance_to(senses.marker_position(last)) \
		else last


func _claim_queue() -> StringName:
	var p: Node = body.population
	if p == null or not is_instance_valid(p) or not p.has_method(&"claim_queue"):
		return &""
	return StringName(p.call(&"claim_queue", body.serial))


func _release_spots() -> void:
	var p: Node = body.population
	if p != null and is_instance_valid(p) and p.has_method(&"release_spots"):
		p.call(&"release_spots", body.serial)
	_queue_spot = &""
