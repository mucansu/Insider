class_name Agenda
extends Node
## Agenda component (US-008 AC1/AC2; GDD §9.2-9.3, S11): NPC task list ({marker, duration range, look direction, cone narrowing};
## `AgendaTask`) ordered by a seeded RNG: home task (counter) alternating with one of the other tasks (same window task never repeats).
## Task time counts after the NPC reaches the marker. Meaningful on the host only; the brain calls `step()` each step and reads target
## position/direction/cone from here. No network, no nodes.
## Interrupts: `interrupt(kind, ...)` pauses the running task (remaining time kept); when it ends or `cancel_interrupt()` is called the
## task resumes. Priority (proposed): SENT > CUSTOMER > TALK > LISTEN > BELL; a lower-priority interrupt does not cut a higher one, an equal
## one renews. The door bell does not interrupt a task with `bell_interrupts = false` (phone). TALK (US-010 STALL): lasts while the player
## talks; the look point is updated to the talker with `retarget_look`. Determinism (I6): same task list + seed + same arrival times ->
## same task sequence (`sequence`).
## Linear route mode (US-016; oyun-yz round 2 #12): `setup_route(tasks, ...)` runs tasks once each in the given order (customer: door ->
## shelf spots -> queue -> door; passerby: street points + window-gazing looks), emits `finished` after the last task and stops. A task
## with duration 0 is a waypoint (moves on at arrival). Spot reservation is the caller's job (`SpotRegistry`); route tasks carry full
## marker names. Interrupts and `advance()` (end the running task) also work in route mode. Home <-> away mode (owner) is unchanged.
## US-039 additions: `begin_task(name)` starts a named task at once (backroom check after alarm), `arrived_for()` / `interrupt_elapsed()`
## time since arrival, `interrupt_ended(kind, completed)` interrupt over (time elapsed or dropped; service result).

signal task_changed(task_name: StringName)
## Route mode: last task finished.
signal finished()
## Interrupt ended: `completed` = time elapsed (false: dropped/restarted).
signal interrupt_ended(kind: Interrupt, completed: bool)

enum Interrupt { NONE, BELL, LISTEN, TALK, CUSTOMER, SENT }

const INTERRUPT_NAMES: Array[StringName] = [&"", &"bell", &"listen", &"talk", &"customer", &"sent"]
## Maximum task names kept in the `sequence` history.
const MAX_SEQUENCE := 512

## IS-106 (KR-037): task facing resolver `func(spot: Vector2, hint: Vector2) -> Vector2` (the owner: MapGrid.face_block - face the
## adjacent shelf/counter/wall, the task's `facing` is the preference). Unset: the task's facing as written.
var facing_resolver: Callable = Callable()

## Task names passed (interrupts included; at most MAX_SEQUENCE).
var sequence: Array[StringName] = []

var _tasks: Array[AgendaTask] = []
## func(marker: StringName) -> Array[Vector2]: marker or sequence positions (global).
var _resolver: Callable = Callable()
var _rng := RandomNumberGenerator.new()
var _task: AgendaTask = null
var _spot: Vector2 = Vector2.INF
var _time_left: float = 0.0
var _arrived: bool = false
var _last_away: AgendaTask = null
## Facing of the current task at its chosen spot (IS-106; `facing_resolver`).
var _facing: Vector2 = Vector2.ZERO

var _interrupt: Interrupt = Interrupt.NONE
var _int_left: float = 0.0
var _int_spot: Vector2 = Vector2.INF
var _int_look: Vector2 = Vector2.INF
var _int_on_arrival: bool = false
var _int_arrived: bool = false
## Agenda sound (US-011b): tempo of the current task (rebuilt when the task changes).
var _noise_task: AgendaTask = null
var _noise_cadence: NoiseRules.Cadence = null
## Linear route mode (US-016): index of the next task; -1 = home <-> away mode.
var _route_index: int = -1
var _route_done: bool = false
## Time since arrival: task and interrupt (US-039).
var _arrived_time: float = 0.0
var _int_elapsed: float = 0.0


## Sets up the list and seed, starts at the home task. `resolver`: func(marker) -> Array[Vector2].
func setup(tasks: Array[AgendaTask], agenda_seed: int, resolver: Callable) -> void:
	_tasks = tasks.duplicate()
	_resolver = resolver
	_rng.seed = agenda_seed
	_last_away = null
	_interrupt = Interrupt.NONE
	_route_index = -1
	_route_done = false
	sequence.clear()
	_begin(_home())


## Linear route mode: tasks once each in order; `finished` after the last. Seed only affects the duration range.
func setup_route(tasks: Array[AgendaTask], agenda_seed: int, resolver: Callable) -> void:
	_tasks = tasks.duplicate()
	_resolver = resolver
	_rng.seed = agenda_seed
	_last_away = null
	_interrupt = Interrupt.NONE
	_route_index = -1
	_route_done = false
	sequence.clear()
	_advance_route()


## Whether in route mode.
func is_route() -> bool:
	return _route_index >= 0 or _route_done


## Whether the route is done (false if not in route mode).
func is_finished() -> bool:
	return _route_done


## Route index (position of the next task in the list; -1 if not a route).
func route_index() -> int:
	return _route_index


## Ends the running task now: moves to the next route task in route mode, else to the agenda's next task (interrupt continues).
func advance() -> void:
	if _route_index >= 0:
		_advance_route()
	elif _task != null:
		_begin(_next())


## Starts the named task at once (interrupt dropped; home <-> away order continues). False if missing.
func begin_task(task_name: StringName) -> bool:
	for t: AgendaTask in _tasks:
		if t != null and t.name == task_name:
			if _interrupt != Interrupt.NONE:
				_end_interrupt(false)
			_begin(t)
			return true
	return false


## Time since reaching the task point (0 if not arrived; the interrupt's during an interrupt).
func arrived_for() -> float:
	return _int_elapsed if _interrupt != Interrupt.NONE else _arrived_time


## Counted time of the interrupt (since arrival for arrival-started interrupts; 0 if none).
func interrupt_elapsed() -> float:
	return _int_elapsed if _interrupt != Interrupt.NONE else 0.0


## Whether the task point is reached (the interrupt's point during an interrupt).
func has_arrived() -> bool:
	return _int_arrived if _interrupt != Interrupt.NONE else _arrived


## One step: `at_goal` = NPC reached the goal (or cannot move: counts as reached so the brain does not freeze, I7).
func step(delta: float, at_goal: bool) -> void:
	var dt: float = maxf(delta, 0.0)
	if _interrupt != Interrupt.NONE:
		if at_goal:
			_int_arrived = true
		if not _int_on_arrival or _int_arrived:
			_int_left -= dt
			_int_elapsed += dt
		if _int_left <= 0.0:
			_end_interrupt(true)
		return
	if _task == null:
		return
	if at_goal:
		_arrived = true
	if _arrived:
		_time_left -= dt
		_arrived_time += dt
		if _time_left <= 0.0:
			if _route_index >= 0:
				_advance_route()
			else:
				_begin(_next())


## Agenda sound produced this step (US-011b; task point reached, no interrupt, task has `noise_kind`, every `noise_interval_sec`;
## first sound one interval after arrival). Empty if none. Call after `step`.
func take_noise(delta: float) -> StringName:
	var task: AgendaTask = _task if _interrupt == Interrupt.NONE and _arrived else null
	var active: bool = task != null and not task.noise_kind.is_empty() and task.noise_interval_sec > 0.0
	if active and task != _noise_task:
		_noise_task = task
		_noise_cadence = NoiseRules.Cadence.new(task.noise_interval_sec, task.noise_interval_sec)
	if _noise_cadence == null:
		return &""
	if not _noise_cadence.tick(maxf(delta, 0.0), active):
		return &""
	return _noise_task.noise_kind


## Position to go to now (global); INF = stay where you are.
func goal_position() -> Vector2:
	if _interrupt != Interrupt.NONE:
		return _int_spot
	return _spot


## Direction to look on arrival (`from` NPC position): the interrupt's look point, else the task's direction; zero = keep.
func goal_facing(from: Vector2) -> Vector2:
	if _interrupt != Interrupt.NONE:
		if _int_look.is_finite() and not from.is_equal_approx(_int_look):
			return (_int_look - from).normalized()
		return Vector2.ZERO
	return _facing if _task != null else Vector2.ZERO


## Cone half angle (degrees); 0 = NPC default.
func half_angle_deg() -> float:
	if _interrupt != Interrupt.NONE or _task == null:
		return 0.0
	return _task.half_angle_deg


## Name of the current task (the interrupt's if any).
func task_name() -> StringName:
	if _interrupt != Interrupt.NONE:
		return INTERRUPT_NAMES[_interrupt]
	return _task.name if _task != null else &""


func current_task() -> AgendaTask:
	return _task


func current_interrupt() -> Interrupt:
	return _interrupt


## Remaining task or interrupt time (s; full duration if not arrived).
func time_left() -> float:
	return _int_left if _interrupt != Interrupt.NONE else _time_left


## Interrupt: `duration` s; `spot` where to go (INF = stay), `look_at` point to look at (INF = none); if `count_on_arrival` the time
## starts on arrival. False if not accepted (priority, task that ignores the bell).
func interrupt(kind: Interrupt, duration: float, spot: Vector2 = Vector2.INF, look_at: Vector2 = Vector2.INF,
		count_on_arrival: bool = false) -> bool:
	if kind == Interrupt.NONE or kind < _interrupt:
		return false
	if kind == Interrupt.BELL and _interrupt == Interrupt.NONE and _task != null and not _task.bell_interrupts:
		return false
	var before: StringName = task_name()
	_interrupt = kind
	_int_left = maxf(duration, 0.0)
	_int_spot = spot
	_int_look = look_at
	_int_on_arrival = count_on_arrival
	_int_arrived = false
	_int_elapsed = 0.0
	_note(before)
	return true


## Changes the running interrupt's look point (TALK: the talker is looked at even as they walk). No effect without an interrupt.
func retarget_look(look_at: Vector2) -> void:
	if _interrupt != Interrupt.NONE:
		_int_look = look_at


## Drops the running interrupt; the task resumes where it left off.
func cancel_interrupt() -> void:
	if _interrupt != Interrupt.NONE:
		_end_interrupt(false)


## Restarts the agenda from the home task (return after alarm); seed sequence continues. A running interrupt counts as dropped.
func restart_home() -> void:
	if _interrupt != Interrupt.NONE:
		var kind: Interrupt = _interrupt
		_interrupt = Interrupt.NONE
		_int_elapsed = 0.0
		interrupt_ended.emit(kind, false)
	_begin(_home())


func _end_interrupt(completed: bool) -> void:
	var before: StringName = task_name()
	var kind: Interrupt = _interrupt
	_interrupt = Interrupt.NONE
	_int_elapsed = 0.0
	_int_left = 0.0
	_int_spot = Vector2.INF
	_int_look = Vector2.INF
	_arrived = false  # walks back to the task point; remaining time kept
	_note(before)
	interrupt_ended.emit(kind, completed)


func _advance_route() -> void:
	_route_index += 1
	if _route_index >= _tasks.size():
		_route_index = -1
		_route_done = true
		_begin(null)
		finished.emit()
		return
	_begin(_tasks[_route_index])


func _begin(task: AgendaTask) -> void:
	var before: StringName = task_name()
	_task = task
	_arrived = false
	_arrived_time = 0.0
	_spot = Vector2.INF
	_time_left = 0.0
	if task == null:
		_note(before)
		return
	var spots: Array[Vector2] = _spots_for(task.marker)
	if not spots.is_empty():
		_spot = spots[_rng.randi_range(0, spots.size() - 1)] if spots.size() > 1 else spots[0]
	_time_left = _rng.randf_range(minf(task.min_sec, task.max_sec), maxf(task.min_sec, task.max_sec))
	_facing = task.facing.normalized()
	if facing_resolver.is_valid() and _spot.is_finite():
		_facing = facing_resolver.call(_spot, task.facing) as Vector2
	if not task.home:
		_last_away = task
	_note(before, true)


func _note(before: StringName, force: bool = false) -> void:
	var now: StringName = task_name()
	if now == before and not force:
		return
	sequence.append(now)
	if sequence.size() > MAX_SEQUENCE:
		sequence.pop_front()
	task_changed.emit(now)


func _next() -> AgendaTask:
	if _task != null and not _task.home:
		return _home()
	var away: Array[AgendaTask] = []
	for t: AgendaTask in _tasks:
		if t != null and not t.home and (t != _last_away or _away_count() == 1):
			away.append(t)
	if away.is_empty():
		return _home()
	return away[_rng.randi_range(0, away.size() - 1)]


func _home() -> AgendaTask:
	for t: AgendaTask in _tasks:
		if t != null and t.home:
			return t
	return _tasks[0] if not _tasks.is_empty() else null


func _away_count() -> int:
	var n: int = 0
	for t: AgendaTask in _tasks:
		if t != null and not t.home:
			n += 1
	return n


func _spots_for(marker: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not _resolver.is_valid() or marker.is_empty():
		return out
	var got: Variant = _resolver.call(marker)
	if got is Array:
		for v: Variant in got:
			if v is Vector2:
				out.append(v)
	return out
