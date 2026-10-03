class_name BotBrain
extends RefCounted
## Closed-loop bot brain (IS-015a; S2, S5/S6). Input source `PlayerInput.Source.BRAIN`: every physics step `tick` reads the local peer's
## replicated world into a `BotRules.View` (owner pose/agenda task/state/shout, register/bag/counter/shelf/door state, alert level, job
## result, team slots and held teammates), `BotRules.Mind` decides an `Intent`, and the brain turns it into movement (tile A* path from the
## level layout, closed doors on the path are opened with E), look and actions (press -> hold while the interaction runs -> release).
## It never reads host-only state (brain internals, suspicion meters, host decisions): host and client run it the same way (S2).
## Selection: `--brain=STRATEGY [--seed=N]` (Args) or a `--bot` file of the form {"brain": "window+bag", "seed": 3, "steps": []}
## ("steps" keeps the timeline loader quiet; net_smoke passes only --bot). Strategies and roles: core/bot_rules.gd.
## Seeds: decisions use the Mind's RNG (hash(seed, strategy)), movement noise (path jitter, unstick nudges) a separate RNG; same seed +
## same strategy + same observed world = same decision sequence. Stops when the job ends (`Game.heist_result()` not empty).
## Dump (S6, only with `--dump`): "brain" = {"strategy", "seed", "role", "phase", "phase_log": [[t, phase], ...], "stuck_s", "unsticks",
## "wait_timeouts", "retreats", "failures", "time_s"} (t = brain clock, s since the first step with a local player).

const DUMP_KEY := "brain"
## Bot file keys selecting a brain.
const SPEC_BRAIN_KEY := "brain"
const SPEC_SEED_KEY := "seed"
## Waypoint switch distance (px) and slow-down radius before the final spot.
const WAYPOINT_PX := 10.0
const SLOW_PX := 24.0
## Stop distance at the final spot (px; BotRules.ARRIVE_PX counts as arrived).
const STOP_PX := 2.0
## Seeded jitter of intermediate waypoints (px; "path deviation"; a 24 px body in a 32 px door keeps clear).
const PATH_JITTER_PX := 4.0
## Escape spot offsets by join slot (px) so teammates do not stack; plus a seeded jitter.
const ESCAPE_OFFSETS: Array[Vector2] = [Vector2.ZERO, Vector2(-28.0, -12.0), Vector2(28.0, 12.0), Vector2(0.0, 20.0)]
const ESCAPE_JITTER_PX := 6.0
## Unstick nudge length (s).
const NUDGE_S := 0.4
## Press cycles without an interaction starting before the press counts as failed.
const NO_START_TRIES := 15
## Within this distance of a closed door on the path the brain stops and opens it (door interact range 40 px).
const DOOR_PRESS_PX := 38.0
## Press tag of door presses (results are not passed to the Mind).
const PRESS_DOOR := -2
## Marker names (S4) and stand offsets (store_a geometry: register staff side east, counter customer side west).
const MARKER_FRONT_DOOR := &"FrontDoor"
const MARKER_QUEUE := &"QueueSpot1"
const REGISTER_STAND := Vector2(BotRules.TILE, 0.0)
const COUNTER_STAND := Vector2(-BotRules.TILE, 0.0)
const QUEUE_FALLBACK := Vector2(-BotRules.TILE, BotRules.TILE)
const OUTSIDE_FROM_DOOR := Vector2(0.0, 2.0 * BotRules.TILE)
const SHELF_STAND := Vector2(BotRules.TILE, 0.0)

var _strategy: String = ""
var _seed: int = 0
var _mind: BotRules.Mind = null
var _rng := RandomNumberGenerator.new()
var _player: Player = null
var _level: Node = null
var _grid: AStarGrid2D = null
var _doors: Dictionary = {}
var _register: Register = null
var _counter: ShopCounter = null
var _bag: Bag = null
var _owner: StoreOwner = null
var _time: float = 0.0
var _last_frame: int = -1
var _move: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
var _held: Dictionary = {}
var _pressed: Dictionary = {}
var _pressing: bool = false
var _press_tag: int = -1
var _finished_since_press: bool = false
var _no_start: int = 0
var _result: int = BotRules.RESULT_NONE
var _path: Array[Vector2] = []
var _path_cells: Array[Vector2i] = []
var _wp: int = 0
var _path_goal: Vector2i = Vector2i(-1, -1)
var _nudge_until: float = -1.0
var _nudge_dir: Vector2 = Vector2.ZERO
var _stuck := BotRules.StuckMeter.new()
var _unsticks: int = 0
var _escape_jitter: Vector2 = Vector2.ZERO
var _dump_registered: bool = false


func _init(strategy_name: String, seed_value: int) -> void:
	_strategy = strategy_name.strip_edges().to_lower()
	_seed = seed_value
	_mind = BotRules.Mind.new(_strategy, seed_value)
	_rng.seed = hash("%d:%s:move" % [seed_value, _strategy])
	_escape_jitter = Vector2(_rng.randf_range(-ESCAPE_JITTER_PX, ESCAPE_JITTER_PX),
		_rng.randf_range(-ESCAPE_JITTER_PX, ESCAPE_JITTER_PX))


## Whether the process asked for a brain (`--brain`, or a `--bot` file that selects one).
static func requested() -> bool:
	return not Args.brain.is_empty() or not spec_from_file(Args.bot_path).is_empty()


## Brain from the arguments: `--brain` (+ `--seed`), else the bot file's spec (`--seed` overrides the file's seed). Null if none.
static func from_args() -> BotBrain:
	if not Args.brain.is_empty():
		return BotBrain.new(Args.brain, Args.run_seed)
	var spec: Dictionary = spec_from_file(Args.bot_path)
	if spec.is_empty():
		return null
	var seed_value: int = Args.run_seed if Args.run_seed_given else int(spec[SPEC_SEED_KEY])
	return BotBrain.new(str(spec[SPEC_BRAIN_KEY]), seed_value)


## Brain spec of a bot file: {"brain": String, "seed": int} if the file has a valid "brain" key, else {} (timeline file or unreadable).
static func spec_from_file(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has(SPEC_BRAIN_KEY):
		return {}
	var data: Dictionary = parsed
	var strategy_name: String = str(data[SPEC_BRAIN_KEY])
	if not BotRules.is_valid_strategy(strategy_name):
		push_warning("BotBrain: bot dosyasında geçersiz strateji '%s': %s" % [strategy_name, path])
		return {}
	var seed_raw: Variant = data.get(SPEC_SEED_KEY, 0)
	var seed_value: int = int(seed_raw) if typeof(seed_raw) == TYPE_INT or typeof(seed_raw) == TYPE_FLOAT else 0
	return {SPEC_BRAIN_KEY: strategy_name, SPEC_SEED_KEY: seed_value}


func strategy() -> String:
	return _strategy


func seed_value() -> int:
	return _seed


func mind() -> BotRules.Mind:
	return _mind


## Brain clock (s since the first step with a local player).
func time() -> float:
	return _time


## One physics step (once per frame; the brain is process-wide). `player`: the local player (null -> no input).
func tick(player: Player, frame: int, delta: float) -> void:
	if frame == _last_frame:
		return
	_last_frame = frame
	_move = Vector2.ZERO
	_look = Vector2.ZERO
	_held.clear()
	_pressed.clear()
	if player == null or not player.is_inside_tree():
		return
	if player != _player:
		_bind(player)
	_time += delta
	if not _ensure_world():
		return
	var view: BotRules.View = _view()
	var intent: BotRules.Intent = _mind.decide(view)
	_act(view, intent, delta)


func move_vector() -> Vector2:
	return _move


func look_vector() -> Vector2:
	return _look


func is_held(action: StringName) -> bool:
	return bool(_held.get(action, false))


func is_just_pressed(action: StringName) -> bool:
	return bool(_pressed.get(action, false))


## S6 dump section "brain".
func dump_state() -> Dictionary:
	return {
		"strategy": _strategy,
		"seed": _seed,
		"role": BotRules.ROLE_NAMES[_mind.role],
		"phase": _mind.phase_name(),
		"phase_log": _mind.phase_log.duplicate(true),
		"stuck_s": snappedf(_stuck.total_s, 0.01),
		"unsticks": _unsticks,
		"wait_timeouts": _mind.wait_timeouts,
		"retreats": _mind.retreats,
		"failures": _mind.failures,
		"time_s": snappedf(_time, 0.01),
	}


func _bind(player: Player) -> void:
	if _player != null and is_instance_valid(_player) and _player.interaction_finished.is_connected(_on_finished):
		_player.interaction_finished.disconnect(_on_finished)
	_player = player
	_player.interaction_finished.connect(_on_finished)
	_pressing = false
	_clear_path()
	if not _dump_registered and not Args.dump_path.is_empty():
		_dump_registered = true
		Game.register_dump_provider(DUMP_KEY, dump_state)


## Level, path grid and props of the current level (rebuilt when the level changes); false while there is none.
func _ensure_world() -> bool:
	var level: Node = Game.current_level()
	if level == null or not level.is_inside_tree():
		return false
	if level == _level and _grid != null:
		return true
	_level = level
	_grid = null
	_doors.clear()
	_register = null
	_counter = null
	_bag = null
	_owner = null
	_clear_path()
	var layout: Node = level.call(&"layout") as Node if level.has_method(&"layout") else null
	var rows: Variant = layout.get(&"rows") if layout != null else null
	if typeof(rows) != TYPE_PACKED_STRING_ARRAY or (rows as PackedStringArray).is_empty():
		return false
	_grid = BotRules.build_grid(rows)
	var props: Node = level.call(&"props_root") as Node
	if props != null:
		for child: Node in props.get_children():
			if child is Register and _register == null:
				_register = child
			elif child is ShopCounter and _counter == null:
				_counter = child
			elif child is Bag and _bag == null:
				_bag = child
			elif child is Door:
				_doors[BotRules.cell_of((child as Door).global_position)] = child
	var npcs: Node = level.call(&"npcs_root") as Node
	if npcs != null:
		for child: Node in npcs.get_children():
			if child is StoreOwner and (child as StoreOwner).is_active():
				_owner = child
				break
	return true


func _view() -> BotRules.View:
	var v := BotRules.View.new()
	v.t = _time
	v.pos = _player.global_position
	v.held = _player.is_held()
	v.caught = _player.is_caught()
	v.heist_over = not Game.heist_result().is_empty()
	v.alert = Game.alert_level()
	v.interacting = _player.is_interacting()
	v.result = _result
	_result = BotRules.RESULT_NONE
	if _owner != null and is_instance_valid(_owner):
		v.owner_present = true
		v.owner_pos = _owner.global_position
		v.owner_facing = _owner.net_facing
		v.owner_state = _owner.net_state
		v.owner_task = _owner.net_task
		v.owner_shouted = _owner.net_shouted
	if _register != null and is_instance_valid(_register):
		v.register_pos = _register.global_position
		v.register_emptied = _register.emptied
		v.spots[BotRules.SPOT_REGISTER] = _register.global_position + REGISTER_STAND
	if _counter != null and is_instance_valid(_counter):
		v.send_used = _counter.sent_used
		v.spots[BotRules.SPOT_COUNTER] = _counter.global_position + COUNTER_STAND
	var me: int = _player.peer_id()
	if _bag != null and is_instance_valid(_bag):
		v.bag_present = true
		v.bag_pos = _bag.global_position
		v.bag_carrier = _bag.carrier
		v.carrying = _bag.carrier == me
		if _bag.carrier == 0:
			v.spots[BotRules.SPOT_BAG] = _bag.global_position
	var shelf: Vector2 = _nearest_shelf(v)
	if shelf != Vector2.INF:
		v.spots[BotRules.SPOT_SHELF] = shelf + SHELF_STAND
	var queue: Vector2 = _marker_pos(MARKER_QUEUE)
	if queue == Vector2.INF and v.spots.has(BotRules.SPOT_COUNTER):
		queue = (v.spots[BotRules.SPOT_COUNTER] as Vector2) - COUNTER_STAND + QUEUE_FALLBACK
	if queue != Vector2.INF:
		v.spots[BotRules.SPOT_QUEUE] = queue
	var front: Vector2 = _marker_pos(MARKER_FRONT_DOOR)
	if front != Vector2.INF:
		v.spots[BotRules.SPOT_OUTSIDE] = front + OUTSIDE_FROM_DOOR
	_read_team(v, me)
	var escape: Vector2 = Game.escape_point()
	if escape != Vector2.INF:
		v.spots[BotRules.SPOT_ESCAPE] = escape + ESCAPE_OFFSETS[maxi(v.slot, 0) % ESCAPE_OFFSETS.size()] + _escape_jitter
	if v.mate_held_pos != Vector2.INF:
		v.spots[BotRules.SPOT_MATE] = v.mate_held_pos
	return v


## Team (replicated session list and player nodes): size, own slot (-1 until listed), thief at the queue spot, nearest held teammate.
func _read_team(v: BotRules.View, me: int) -> void:
	var players: Dictionary = Game.players()
	v.team_size = maxi(players.size(), 1)
	v.slot = int((players[me] as Dictionary).get("slot", 0)) if players.has(me) else -1
	var root: Node = _level.call(&"players_root") as Node
	if root == null:
		return
	var queue: Vector2 = v.spots.get(BotRules.SPOT_QUEUE, Vector2.INF)
	var best: float = INF
	for child: Node in root.get_children():
		var mate: Player = child as Player
		if mate == null or mate == _player:
			continue
		var entry: Dictionary = players.get(mate.peer_id(), {})
		if int(entry.get("slot", -1)) == 1 and queue != Vector2.INF \
				and mate.global_position.distance_to(queue) <= BotRules.READY_PX:
			v.thief_ready = true
		if mate.is_held() and not mate.is_caught():
			var d: float = mate.global_position.distance_to(v.pos)
			if d < best:
				best = d
				v.mate_held_pos = mate.global_position


func _nearest_shelf(v: BotRules.View) -> Vector2:
	var best: Vector2 = Vector2.INF
	for node: Node in _player.get_tree().get_nodes_in_group(ShelfProp.GROUP):
		var shelf: ShelfProp = node as ShelfProp
		if shelf == null or shelf.toppled:
			continue
		v.shelf_left += 1
		if best == Vector2.INF or shelf.global_position.distance_to(v.pos) < best.distance_to(v.pos):
			best = shelf.global_position
	return best


func _marker_pos(marker_name: StringName) -> Vector2:
	var marker: Node2D = _level.call(&"marker", marker_name) as Node2D if _level.has_method(&"marker") else null
	return marker.global_position if marker != null else Vector2.INF


func _act(v: BotRules.View, intent: BotRules.Intent, delta: float) -> void:
	_look = intent.look
	if _mind.is_done() or intent.spot == BotRules.SPOT_NONE or not v.spots.has(intent.spot):
		_release()
		_stuck.feed(_time, delta, v.pos, false)
		return
	var goal: Vector2 = v.spots[intent.spot]
	if v.at(intent.spot):
		_clear_path()
		_move = BotRules.steer(v.pos, goal, STOP_PX, SLOW_PX) if intent.spot != BotRules.SPOT_MATE else Vector2.ZERO
		_stuck.feed(_time, delta, v.pos, false)
		if intent.action != &"":
			_press(intent.action, int(_mind.phase))
		else:
			_release()
		return
	if _follow_path(v.pos, goal):
		_stuck.feed(_time, delta, v.pos, false)  # waiting for a door: not stuck
		return
	_release()
	if _stuck.feed(_time, delta, v.pos, true):
		_unsticks += 1
		var away: Vector2 = _move.orthogonal() if not _move.is_zero_approx() else Vector2.RIGHT
		_nudge_dir = (away * (1.0 if _rng.randf() < 0.5 else -1.0) - _move * 0.5).normalized()
		_nudge_until = _time + NUDGE_S
		_clear_path()
	if _time < _nudge_until:
		_move = _nudge_dir
	_held[&"sprint"] = intent.sprint


## Moves along the A* path to `goal`; true while it stopped to open a closed door on the path.
func _follow_path(pos: Vector2, goal: Vector2) -> bool:
	var goal_cell: Vector2i = BotRules.cell_of(goal)
	if goal_cell != _path_goal or _path.is_empty():
		_plan_path(pos, goal)
	if _path.is_empty():
		_move = BotRules.steer(pos, goal, STOP_PX, SLOW_PX)
		return false
	while _wp < _path.size() - 1 and pos.distance_to(_path[_wp]) <= WAYPOINT_PX:
		_wp += 1
	if _wp < _path_cells.size() and _doors.has(_path_cells[_wp]):
		var door: Door = _doors[_path_cells[_wp]] as Door
		if door != null and is_instance_valid(door) and not door.is_open \
				and pos.distance_to(door.global_position) <= DOOR_PRESS_PX:
			_move = Vector2.ZERO
			_press(BotRules.ACTION_INTERACT, PRESS_DOOR)
			return true
	var last: bool = _wp == _path.size() - 1
	_move = BotRules.steer(pos, _path[_wp], STOP_PX if last else 0.0, SLOW_PX if last else 0.0)
	return false


func _plan_path(pos: Vector2, goal: Vector2) -> void:
	_clear_path()
	_path_goal = BotRules.cell_of(goal)
	var cells: Array[Vector2i] = BotRules.find_path(_grid, BotRules.cell_of(pos), _path_goal)
	if cells.is_empty():
		return
	cells.remove_at(0)  # the current cell
	for i: int in cells.size():
		var cell: Vector2i = cells[i]
		var point: Vector2 = BotRules.cell_center(cell)
		if i == cells.size() - 1:
			point = goal
		elif not _doors.has(cell):
			point += Vector2(_rng.randf_range(-PATH_JITTER_PX, PATH_JITTER_PX), _rng.randf_range(-PATH_JITTER_PX, PATH_JITTER_PX))
		_path.append(point)
		_path_cells.append(cell)
	if _path.is_empty():
		_path.append(goal)
		_path_cells.append(_path_goal)


func _clear_path() -> void:
	_path.clear()
	_path_cells.clear()
	_wp = 0
	_path_goal = Vector2i(-1, -1)


## Press/hold cycle of `action`: press (rising edge) -> hold while the player's interaction runs -> release for one step after it ends
## (or if nothing started) so the next press is a new edge. `tag`: Mind phase of the press (its result goes to the Mind only if the phase
## is unchanged) or PRESS_DOOR.
func _press(action: StringName, tag: int) -> void:
	if _player.is_interacting():
		_held[action] = true
		_pressing = true
		_no_start = 0
		return
	if _pressing:
		_pressing = false  # ended (result via signal) or never started: release one step
		if not _finished_since_press:
			_no_start += 1
			if _no_start >= NO_START_TRIES:
				_no_start = 0
				if _press_tag == int(_mind.phase):
					_result = BotRules.RESULT_FAIL
		return
	_held[action] = true
	_pressed[action] = true
	_pressing = true
	_press_tag = tag
	_finished_since_press = false


func _release() -> void:
	_pressing = false


func _on_finished(success: bool) -> void:
	_finished_since_press = true
	_no_start = 0
	if _press_tag != PRESS_DOOR and _press_tag == int(_mind.phase):
		_result = BotRules.RESULT_OK if success else BotRules.RESULT_FAIL
