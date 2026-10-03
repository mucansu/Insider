class_name BotRules
extends RefCounted
## Node-free rules of the closed-loop bot brain (IS-015a; S2, S6). `BotBrain` (entities/player/bot_brain.gd) reads only the replicated
## world of its own peer into a `View` every physics step; `Mind.decide(view)` walks the strategy plan and returns an `Intent` (spot to
## reach, action to hold, movement mode, look). Paths (`build_grid`, `find_path`) and stuck detection (`StuckMeter`) are here too.
## Strategies (`--brain` value; `STRATEGIES`), `+bag` suffix (`window+bag`: after the register also take the back-room cash bag):
##   rush     straight to the register, empty it, escape
##   window   wait outside (front pavement) until the owner is away from the register / facing away, then register, escape
##   send     SEND TO BACKROOM (Q) at the counter, wait for the window it opens, register, escape
##   distract wait at a shelf end until the owner is at the counter, topple it (E), wait at the queue spot for the window, register
##   buy      BUY (E) at the counter (keeps cover, resets loitering; rebuys every REBUY_*, at most MAX_REBUYS), take the window,
##            register, escape
##   team     roles by join slot: 0 lure (counter; SEND once the thief stands at the queue spot or after TEAM_WAIT_S alone, then stays as a
##            customer until the register is emptied), 1 thief (queue spot, window -> register), 2 bagger (outside, owner at the shelves
##            or phone -> back room bag); any free teammate within PULL_RANGE_PX pulls a held one (PULL)
## Global overrides: job over or caught -> done; held -> held (resumes); alert >= ALERT_FLEE -> escape (sprint) unless the register is
## being emptied. Randomness only from the seeded RNG at decision points (wait timeout, reaction delay, retry, rebuy), so the same seed
## and the same view sequence give the same phase log.

enum Phase { START, STAGE, WAIT, LURE, GO_REGISTER, EMPTY, GO_BAG, TAKE_BAG, ESCAPE, PULL, HELD, DONE }
const PHASE_NAMES: Array[String] = ["start", "stage", "wait", "lure", "go_register", "empty", "go_bag", "take_bag", "escape", "pull",
	"held", "done"]
enum Role { SOLO, LURE, THIEF, BAGGER }
const ROLE_NAMES: Array[String] = ["solo", "lure", "thief", "bagger"]
enum Step { GO, USE, WAIT }

const STRATEGIES: Array[String] = ["rush", "window", "send", "distract", "buy", "team"]
const BAG_SUFFIX := "+bag"

## Spots (BotBrain resolves them to world positions from the level and props).
const SPOT_NONE := &""
const SPOT_REGISTER := &"register"   # staff side of the register (EMPTY)
const SPOT_COUNTER := &"counter"     # customer side of the counter (BUY / SEND)
const SPOT_QUEUE := &"queue"         # queue spot in front of the register (customer area)
const SPOT_OUTSIDE := &"outside"     # front pavement, away from the windows
const SPOT_SHELF := &"shelf"         # aisle side of the nearest untoppled shelf end
const SPOT_BAG := &"bag"             # the cash bag
const SPOT_ESCAPE := &"escape"       # escape zone (per-slot offset)
const SPOT_MATE := &"mate"           # held teammate (PULL)

const ACTION_INTERACT := &"interact"
const ACTION_ALT := &"intimidate"

## Conditions (WAIT `until`, USE/GO `skip`).
const COND_NONE := &""
const COND_WINDOW := &"window"
const COND_BAG_WINDOW := &"bag_window"
const COND_SENT := &"sent"
const COND_EMPTIED := &"emptied"
const COND_CARRYING := &"carrying"
const COND_OWNER_AT_COUNTER := &"owner_at_counter"
const COND_TEAM_READY := &"team_ready"
const COND_LURE_HOLD := &"lure_hold"

## Interaction result of the last step (consumed by `Mind.decide`).
const RESULT_NONE := -1
const RESULT_FAIL := 0
const RESULT_OK := 1

## Owner replicated brain state "agenda" (OwnerBrain.State.AGENDA); any other value is a reaction (look, question, shout ...).
const OWNER_STATE_AGENDA := 0
const TASK_COUNTER := &"counter"
## Owner agenda tasks that keep them away from the register (GDD §9.3 windows; `sent` = SEND TO BACKROOM, `listen` = DISTRACT).
const WINDOW_TASKS: Array[StringName] = [&"restock", &"backroom", &"phone", &"sent", &"listen"]
## Tasks during which the back room is free (owner at the west shelves or the phone wall).
const BAG_TASKS: Array[StringName] = [&"restock", &"phone"]

# Tuning (file-top consts; first guesses, IS-015b measures).
## Owner at least this far from the register counts as "away" (4 tiles: GDD §9.3 KAP-KAÇ).
const SAFE_DISTANCE_PX := 128.0
## Owner at least this far from the bag counts as "away from the back room".
const BAG_SAFE_PX := 160.0
## Owner facing . direction(owner -> register) below this = facing away (cone half-angle 25 deg is far above).
const FACING_AWAY_DOT := 0.2
## Owner counts as "at the counter" within this distance of the register.
const AT_COUNTER_PX := 64.0
## Abort the run to the register if the owner is back this close and the bot is still farther than COMMIT_PX from the stand.
const OWNER_BACK_PX := 96.0
const COMMIT_PX := 96.0
const MAX_RETREATS := 2
## Reaction delay after a WAIT condition turns true (s).
const REACTION_MIN_S := 0.3
const REACTION_MAX_S := 1.2
## WAIT gives up after this long and goes anyway (s; the job must end within a test/statistics run).
const WAIT_MAX_MIN_S := 60.0
const WAIT_MAX_MAX_S := 90.0
## Team lure waits this long for a thief before acting alone (s).
const TEAM_WAIT_S := 20.0
## Thief counts as ready within this distance of the queue spot.
const READY_PX := 48.0
## Retry delay after a failed interaction (s) and attempts before giving the step up.
const RETRY_MIN_S := 1.0
const RETRY_MAX_S := 2.5
const MAX_ATTEMPTS := 4
## BUY repeats this often while waiting (s): resets the loitering clock (GDD §9.3 SATIN AL).
const REBUY_MIN_S := 35.0
const REBUY_MAX_S := 50.0
## Rebuys per job (then the WAIT runs to its timeout: the job stays bounded).
const MAX_REBUYS := 2
## Alert level from which everyone flees (owner shouted).
const ALERT_FLEE := 2
## PULL a held teammate only within this distance (px).
const PULL_RANGE_PX := 256.0
## Standing at a spot: within this distance (px); next to a held teammate (PULL range 32 px).
const ARRIVE_PX := 8.0
const MATE_ARRIVE_PX := 24.0

# Path grid (tile layout of `levels/layouts/*.txt`; legend LevelLayout - core may not reference levels/, so the characters are listed here).
const TILE := 32
## Colliding tile characters (border, wall, window, shelf, counter, cooler, crate).
const SOLID_CHARS := "%#wSTIG"
const DOOR_CHAR := "+"
## A* weight of a door cell (a closed door costs an open/close and noise; prefer open routes).
const DOOR_WEIGHT := 3.0

# Stuck detection.
## Moving less than this (px) within STUCK_WINDOW_S while wanting to move counts as stuck.
const STUCK_MIN_PX := 6.0
const STUCK_WINDOW_S := 1.0
## Continuous stuck time after which the brain nudges and replans (s).
const STUCK_REPLAN_S := 0.75


## One step of the world as the local peer sees it (replicated state only).
class View:
	extends RefCounted
	var t: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var held: bool = false
	var caught: bool = false
	var heist_over: bool = false
	var alert: int = 0
	## Spot -> world position (resolved by BotBrain; a missing spot cannot be reached).
	var spots: Dictionary = {}
	var interacting: bool = false
	## Result of the Mind's own interaction finished since the last decide (RESULT_*).
	var result: int = RESULT_NONE
	var owner_present: bool = false
	var owner_pos: Vector2 = Vector2.INF
	var owner_facing: Vector2 = Vector2.LEFT
	var owner_state: int = OWNER_STATE_AGENDA
	var owner_task: StringName = &""
	var owner_shouted: bool = false
	var register_pos: Vector2 = Vector2.INF
	var register_emptied: bool = false
	var send_used: bool = false
	var shelf_left: int = 0
	var bag_present: bool = false
	var bag_pos: Vector2 = Vector2.INF
	var bag_carrier: int = 0
	var carrying: bool = false
	var team_size: int = 1
	## Own join slot; < 0 while the session has not listed the local peer yet (the Mind waits).
	var slot: int = 0
	var thief_ready: bool = false
	## Position of a held teammate (INF = none).
	var mate_held_pos: Vector2 = Vector2.INF

	## Whether the bot stands at `spot` (within ARRIVE_PX; MATE_ARRIVE_PX next to a held teammate).
	func at(spot: StringName) -> bool:
		if not spots.has(spot):
			return false
		var radius: float = BotRules.MATE_ARRIVE_PX if spot == BotRules.SPOT_MATE else BotRules.ARRIVE_PX
		return pos.distance_to(spots[spot] as Vector2) <= radius


## What the Mind wants this step.
class Intent:
	extends RefCounted
	var spot: StringName = SPOT_NONE
	## Action to hold at the spot (empty = none); BotBrain turns it into press/hold/release.
	var action: StringName = &""
	var sprint: bool = false
	## Explicit look (world direction) or ZERO (follow movement).
	var look: Vector2 = Vector2.ZERO


## Strategy name -> {"base": String, "bag": bool, "valid": bool}.
static func parse_strategy(strategy_name: String) -> Dictionary:
	var text: String = strategy_name.strip_edges().to_lower()
	var bag: bool = text.ends_with(BAG_SUFFIX)
	var base: String = text.trim_suffix(BAG_SUFFIX) if bag else text
	return {"base": base, "bag": bag, "valid": STRATEGIES.has(base)}


static func is_valid_strategy(strategy_name: String) -> bool:
	return bool(parse_strategy(strategy_name)["valid"])


## Role of a peer in strategy `base` by join slot (team: 0 lure, 1 thief, 2 bagger, more thieves); other strategies are solo.
static func role_for(base: String, slot: int) -> Role:
	if base != "team":
		return Role.SOLO
	match slot:
		0:
			return Role.LURE
		2:
			return Role.BAGGER
	return Role.THIEF


## Whether the register is unwatched: no owner, or the owner on the agenda (not reacting, not shouted), at least SAFE_DISTANCE_PX away
## and on a window task or facing away from the register.
static func window_open(v: View) -> bool:
	if not v.owner_present:
		return true
	if v.owner_shouted or v.owner_state != OWNER_STATE_AGENDA or v.register_pos == Vector2.INF:
		return false
	if v.owner_pos.distance_to(v.register_pos) < SAFE_DISTANCE_PX:
		return false
	if WINDOW_TASKS.has(v.owner_task):
		return true
	var to_register: Vector2 = (v.register_pos - v.owner_pos).normalized()
	return v.owner_facing.normalized().dot(to_register) < FACING_AWAY_DOT


## Whether the back room is unwatched (owner at the shelves or the phone, far from the bag).
static func bag_window_open(v: View) -> bool:
	if not v.owner_present:
		return true
	if v.owner_shouted or v.owner_state != OWNER_STATE_AGENDA or not BAG_TASKS.has(v.owner_task):
		return false
	return v.bag_pos == Vector2.INF or v.owner_pos.distance_to(v.bag_pos) >= BAG_SAFE_PX


## Owner standing at the counter on the agenda (DISTRACT target: the topple is heard from there).
static func owner_at_counter(v: View) -> bool:
	if not v.owner_present:
		return true
	return not v.owner_shouted and v.owner_state == OWNER_STATE_AGENDA and v.owner_task == TASK_COUNTER \
		and v.owner_pos.distance_to(v.register_pos) <= AT_COUNTER_PX


## Owner came back to the counter (abort a run to the register that has not committed yet).
static func owner_back(v: View) -> bool:
	return v.owner_present and not v.owner_shouted and v.owner_task == TASK_COUNTER \
		and v.owner_pos.distance_to(v.register_pos) <= OWNER_BACK_PX


static func condition(cond: StringName, v: View) -> bool:
	match cond:
		COND_WINDOW:
			return window_open(v)
		COND_BAG_WINDOW:
			return bag_window_open(v)
		COND_SENT:
			return v.send_used
		COND_EMPTIED:
			return v.register_emptied
		COND_CARRYING:
			return v.carrying or not v.bag_present or (v.bag_carrier != 0 and not v.carrying)
		COND_OWNER_AT_COUNTER:
			return owner_at_counter(v)
		COND_TEAM_READY:
			return v.team_size >= 2 and v.thief_ready
		COND_LURE_HOLD:
			return v.register_emptied if v.team_size >= 2 else window_open(v)
	return false


## Plan of a strategy/role: list of steps {"kind": Step, "phase": Phase, "spot", "action", "until", "skip", "abort_to", "loop_to"}.
static func plan_for(base: String, bag: bool, role: Role) -> Array[Dictionary]:
	var p: Array[Dictionary] = []
	var wait_at: int = -1
	match base:
		"window":
			p.append(_go(Phase.STAGE, SPOT_OUTSIDE))
			wait_at = p.size()
			p.append(_wait(SPOT_OUTSIDE, COND_WINDOW))
		"send":
			p.append(_go(Phase.STAGE, SPOT_COUNTER))
			p.append(_use(Phase.LURE, SPOT_COUNTER, ACTION_ALT, COND_SENT))
			wait_at = p.size()
			p.append(_wait(SPOT_COUNTER, COND_WINDOW))
		"distract":
			p.append(_go(Phase.STAGE, SPOT_SHELF))
			p.append(_wait(SPOT_SHELF, COND_OWNER_AT_COUNTER))
			p.append(_use(Phase.LURE, SPOT_SHELF, ACTION_INTERACT, COND_NONE))
			p.append(_go(Phase.STAGE, SPOT_QUEUE))
			wait_at = p.size()
			p.append(_wait(SPOT_QUEUE, COND_WINDOW))
		"buy":
			p.append(_go(Phase.STAGE, SPOT_COUNTER))
			var buy_at: int = p.size()
			p.append(_use(Phase.LURE, SPOT_COUNTER, ACTION_INTERACT, COND_NONE))
			wait_at = p.size()
			var w: Dictionary = _wait(SPOT_COUNTER, COND_WINDOW)
			w["loop_to"] = buy_at
			p.append(w)
		"team":
			match role:
				Role.LURE:
					p.append(_go(Phase.STAGE, SPOT_COUNTER))
					p.append(_wait(SPOT_COUNTER, COND_TEAM_READY, TEAM_WAIT_S))
					p.append(_use(Phase.LURE, SPOT_COUNTER, ACTION_ALT, COND_SENT))
					wait_at = p.size()
					p.append(_wait(SPOT_COUNTER, COND_LURE_HOLD))
				Role.THIEF:
					p.append(_go(Phase.STAGE, SPOT_QUEUE))
					wait_at = p.size()
					p.append(_wait(SPOT_QUEUE, COND_WINDOW))
				Role.BAGGER:
					p.append(_go(Phase.STAGE, SPOT_OUTSIDE))
					p.append(_wait(SPOT_OUTSIDE, COND_BAG_WINDOW))
					_append_bag(p)
					p.append(_go(Phase.ESCAPE, SPOT_ESCAPE))
					return p
	var go_register: Dictionary = _go(Phase.GO_REGISTER, SPOT_REGISTER, COND_EMPTIED)
	go_register["abort_to"] = wait_at
	p.append(go_register)
	p.append(_use(Phase.EMPTY, SPOT_REGISTER, ACTION_INTERACT, COND_EMPTIED))
	if bag:
		_append_bag(p)
	p.append(_go(Phase.ESCAPE, SPOT_ESCAPE))
	return p


static func _append_bag(p: Array[Dictionary]) -> void:
	p.append(_go(Phase.GO_BAG, SPOT_BAG, COND_CARRYING))
	p.append(_use(Phase.TAKE_BAG, SPOT_BAG, ACTION_INTERACT, COND_CARRYING))


static func _go(phase: Phase, spot: StringName, skip: StringName = COND_NONE) -> Dictionary:
	return {"kind": Step.GO, "phase": phase, "spot": spot, "action": &"", "until": COND_NONE, "skip": skip, "abort_to": -1,
		"loop_to": -1, "timeout": -1.0}


static func _use(phase: Phase, spot: StringName, action: StringName, skip: StringName) -> Dictionary:
	return {"kind": Step.USE, "phase": phase, "spot": spot, "action": action, "until": COND_NONE, "skip": skip, "abort_to": -1,
		"loop_to": -1, "timeout": -1.0}


## `timeout` < 0: drawn from WAIT_MAX_MIN_S..WAIT_MAX_MAX_S.
static func _wait(spot: StringName, until: StringName, timeout: float = -1.0) -> Dictionary:
	return {"kind": Step.WAIT, "phase": Phase.WAIT, "spot": spot, "action": &"", "until": until, "skip": COND_NONE, "abort_to": -1,
		"loop_to": -1, "timeout": timeout}


## Stateful decider of one bot (one per process; the plan is built on the first decide, when the join slot is known).
class Mind:
	extends RefCounted
	var strategy: String = ""
	var base: String = ""
	var bag: bool = false
	var seed_value: int = 0
	var role: Role = Role.SOLO
	var phase: Phase = Phase.START
	## [[t, phase name], ...] (t rounded to 0.01 s; dump).
	var phase_log: Array = []
	## Counters (dump): WAIT timeouts, retreats, failed interactions.
	var wait_timeouts: int = 0
	var retreats: int = 0
	var failures: int = 0
	var rng := RandomNumberGenerator.new()
	var _plan: Array[Dictionary] = []
	var _index: int = -1
	var _step_t: float = 0.0
	var _cond_since: float = -1.0
	var _react: float = 0.0
	var _timeout: float = INF
	var _loop_after: float = INF
	var _attempts: int = 0
	var _retry_at: float = 0.0
	var _escaping: bool = false
	## A WAIT timed out ("go anyway"): the following run does not retreat (keeps the job bounded in time).
	var _committed: bool = false
	var _loops: int = 0

	func _init(strategy_name: String, run_seed: int) -> void:
		var parsed: Dictionary = BotRules.parse_strategy(strategy_name)
		strategy = strategy_name.strip_edges().to_lower()
		base = str(parsed["base"])
		bag = bool(parsed["bag"])
		seed_value = run_seed
		rng.seed = hash("%d:%s" % [run_seed, strategy])

	func phase_name() -> String:
		return BotRules.PHASE_NAMES[phase]

	func is_done() -> bool:
		return phase == Phase.DONE

	func decide(v: View) -> Intent:
		var intent := Intent.new()
		if phase == Phase.DONE:
			return intent
		if v.heist_over or v.caught:
			_set_phase(Phase.DONE, v.t)
			return intent
		if _plan.is_empty():
			if v.slot < 0:
				return intent  # session has not listed the local peer yet: role unknown
			role = BotRules.role_for(base, v.slot)
			_plan = BotRules.plan_for(base, bag, role)
			_enter(0, v)
		if v.held:
			_set_phase(Phase.HELD, v.t)
			return intent
		if base == "team" and v.mate_held_pos != Vector2.INF and v.pos.distance_to(v.mate_held_pos) <= BotRules.PULL_RANGE_PX \
				and not _emptying(v):
			_set_phase(Phase.PULL, v.t)
			intent.spot = BotRules.SPOT_MATE
			intent.action = BotRules.ACTION_INTERACT if v.at(BotRules.SPOT_MATE) else &""
			intent.sprint = true
			return intent
		if not _escaping and v.alert >= BotRules.ALERT_FLEE and not _emptying(v):
			_escaping = true
			_enter(_plan.size() - 1, v)
		return _run(v, intent)

	func _emptying(v: View) -> bool:
		return v.interacting and _index >= 0 and int(_plan[_index]["phase"]) == Phase.EMPTY

	func _run(v: View, intent: Intent) -> Intent:
		for _guard: int in _plan.size() + 1:
			var step: Dictionary = _plan[_index]
			var skip: StringName = step["skip"]
			if skip != BotRules.COND_NONE and BotRules.condition(skip, v) and _index < _plan.size() - 1:
				_enter(_index + 1, v)
				continue
			_set_phase(int(step["phase"]) as Phase, v.t)
			intent.spot = step["spot"]
			intent.sprint = _escaping or (int(step["phase"]) == Phase.ESCAPE and v.alert >= BotRules.ALERT_FLEE)
			match int(step["kind"]):
				Step.GO:
					if int(step["phase"]) == Phase.ESCAPE:
						return intent  # terminal: stay at the escape spot
					var abort_to: int = int(step["abort_to"])
					if abort_to >= 0 and not _committed and retreats < BotRules.MAX_RETREATS and BotRules.owner_back(v) \
							and not v.at(intent.spot) and v.pos.distance_to(v.register_pos) > BotRules.COMMIT_PX:
						retreats += 1
						_enter(abort_to, v)
						continue
					if v.at(intent.spot):
						_enter(_index + 1, v)
						continue
					return intent
				Step.USE:
					if v.result == BotRules.RESULT_OK:
						v.result = BotRules.RESULT_NONE
						_enter(_index + 1, v)
						continue
					if v.result == BotRules.RESULT_FAIL:
						v.result = BotRules.RESULT_NONE
						failures += 1
						_attempts += 1
						if _attempts >= BotRules.MAX_ATTEMPTS:
							_enter(_index + 1, v)
							continue
						_retry_at = v.t + rng.randf_range(BotRules.RETRY_MIN_S, BotRules.RETRY_MAX_S)
					if v.at(intent.spot) and v.t >= _retry_at:
						intent.action = step["action"]
					return intent
				Step.WAIT:
					if intent.spot == BotRules.SPOT_OUTSIDE:
						intent.look = Vector2.DOWN  # away from the shop windows
					if BotRules.condition(step["until"], v):
						if _cond_since < 0.0:
							_cond_since = v.t
							_react = rng.randf_range(BotRules.REACTION_MIN_S, BotRules.REACTION_MAX_S)
						if v.t - _cond_since >= _react:
							_enter(_index + 1, v)
							continue
					else:
						_cond_since = -1.0
					if v.t - _step_t >= _timeout:
						wait_timeouts += 1
						_enter(_index + 1, v)
						_committed = true
						continue
					var loop_to: int = int(step["loop_to"])
					if loop_to >= 0 and _loops < BotRules.MAX_REBUYS and v.t - _step_t >= _loop_after:
						_loops += 1
						_enter(loop_to, v)
						continue
					return intent
		return intent

	func _enter(index: int, v: View) -> void:
		_index = clampi(index, 0, _plan.size() - 1)
		_step_t = v.t
		_cond_since = -1.0
		_attempts = 0
		_retry_at = 0.0
		var step: Dictionary = _plan[_index]
		_timeout = INF
		_loop_after = INF
		if int(step["kind"]) == Step.WAIT:
			_committed = false
			var fixed: float = float(step["timeout"])
			_timeout = fixed if fixed >= 0.0 else rng.randf_range(BotRules.WAIT_MAX_MIN_S, BotRules.WAIT_MAX_MAX_S)
			if int(step["loop_to"]) >= 0:
				_loop_after = rng.randf_range(BotRules.REBUY_MIN_S, BotRules.REBUY_MAX_S)
		# The phase is logged by _run once the step is really active (skipped steps leave no trace).

	func _set_phase(value: Phase, t: float) -> void:
		if value == phase:
			return
		phase = value
		phase_log.append([snappedf(t, 0.01), BotRules.PHASE_NAMES[value]])


## Stuck detector: wanting to move but staying within STUCK_MIN_PX for longer than STUCK_WINDOW_S.
class StuckMeter:
	extends RefCounted
	## Total stuck time (s; beyond the window; dump `stuck_s`).
	var total_s: float = 0.0
	var streak_s: float = 0.0
	var _anchor: Vector2 = Vector2.INF
	var _anchor_t: float = 0.0

	## One step; true when the streak reached STUCK_REPLAN_S (the caller nudges and replans; the streak restarts).
	func feed(t: float, dt: float, pos: Vector2, wants_move: bool) -> bool:
		if not wants_move or _anchor == Vector2.INF or pos.distance_to(_anchor) >= BotRules.STUCK_MIN_PX:
			_anchor = pos
			_anchor_t = t
			streak_s = 0.0
			return false
		if t - _anchor_t < BotRules.STUCK_WINDOW_S:
			return false
		streak_s += dt
		total_s += dt
		if streak_s >= BotRules.STUCK_REPLAN_S:
			streak_s = 0.0
			_anchor_t = t
			return true
		return false


## A* grid of a tile layout (rows of LevelLayout characters): solid characters blocked, door cells weighted DOOR_WEIGHT.
static func build_grid(rows: PackedStringArray) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	var width: int = rows[0].length() if not rows.is_empty() else 0
	grid.region = Rect2i(0, 0, width, rows.size())
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in mini(row.length(), width):
			var ch: String = row[x]
			if SOLID_CHARS.contains(ch):
				grid.set_point_solid(Vector2i(x, y), true)
			elif ch == DOOR_CHAR:
				grid.set_point_weight_scale(Vector2i(x, y), DOOR_WEIGHT)
	return grid


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Nearest walkable cell to `cell` (itself if walkable; ring search up to `radius`); (-1, -1) if none.
static func nearest_open(grid: AStarGrid2D, cell: Vector2i, radius: int = 3) -> Vector2i:
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
		return cell
	for r: int in range(1, radius + 1):
		var best: Vector2i = Vector2i(-1, -1)
		var best_d: float = INF
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if grid.is_in_boundsv(c) and not grid.is_point_solid(c):
					var d: float = Vector2(dx, dy).length()
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Cell path from `from` to `to` (both snapped to the nearest walkable cell); empty if unreachable.
static func find_path(grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a: Vector2i = nearest_open(grid, from)
	var b: Vector2i = nearest_open(grid, to)
	if a.x < 0 or b.x < 0:
		return out
	for c: Vector2i in grid.get_id_path(a, b):
		out.append(c)
	return out


## Movement toward `target`: unit direction, slowed linearly inside `slow_px` (never below `min_scale`); ZERO within `arrive_px`.
static func steer(pos: Vector2, target: Vector2, arrive_px: float, slow_px: float, min_scale: float = 0.35) -> Vector2:
	var to: Vector2 = target - pos
	var d: float = to.length()
	if d <= arrive_px:
		return Vector2.ZERO
	var scale: float = clampf(d / slow_px, min_scale, 1.0) if slow_px > 0.0 else 1.0
	return to / d * scale
