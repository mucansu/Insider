class_name ChaserBrain
extends Node
## Neighbour (chaser) brain (US-008 AC6/AC7; GDD §9.3; KR-019 K3). Host only; the Chaser root calls `step(delta)` each step and applies the
## desired velocity. States: RUN (runs where the shout came from) -> CHASE (nearest visible free or held player; 28 px + 0.5 s contact, player
## position advanced with ON-03 -> permanent catch, no rescue) -> SEARCH (last seen position if no sight, 15 s) -> WAIT (waits at the front
## door). Sight: no cone (looks at the target), line of sight (world + vision_block, windows pass) + range.
## US-043 additions: while the heist runs (cover tracked) the neighbour chases only players with broken cover - intact cover is a
## "customer-like" bystander (US-042). REDIRECT: `mislead(point, s)` -> MISLED (runs to the shown point, chases nobody), then SEARCH at that
## point. While `listening` is true (someone is telling them "they ran that way") it stands still and does not catch.

enum State { RUN, CHASE, SEARCH, WAIT, MISLED }

const STATE_NAMES: Array[StringName] = [&"run", &"chase", &"search", &"wait", &"misled"]
const EDGES := {
	State.RUN: [State.CHASE, State.SEARCH, State.MISLED],
	State.CHASE: [State.SEARCH, State.MISLED],
	State.SEARCH: [State.CHASE, State.WAIT, State.MISLED],
	State.WAIT: [State.CHASE, State.MISLED],
	State.MISLED: [State.SEARCH],
}
const ARRIVE_PX := 8.0
## Catcher in the `player_caught {peer, by}` event.
const CATCHER := &"chaser"

var tuning: ChaserTuning
var civilian_tuning: CivilianTuning
var fsm := Fsm.new(State.RUN, EDGES)
## Peers caught (dump).
var catches: Array[int] = []
## US-043: someone is holding REDIRECT (stands, does not catch); count of wrong-way runs (dump).
var listening: bool = false
## Cover query `func(peer_id) -> bool` (intact?; Chaser connects the owner's senses - listens to cover events since heist start).
## Everyone is chased if empty.
var cover_query: Callable = Callable()
var misled_count: int = 0

var _body: CharacterBody2D = null
var _perception: Perception = null
var _mover: NpcMover = null
var _senses: CivilianSenses = null
var _goal: Vector2 = Vector2.INF
var _target: int = 0
var _last_seen: Vector2 = Vector2.INF
var _contact: float = 0.0
var _misled_left: float = 0.0
var _misled_point: Vector2 = Vector2.INF


func setup(body: CharacterBody2D, perception: Perception, mover: NpcMover, senses: CivilianSenses,
		goal: Vector2) -> void:
	_body = body
	_perception = perception
	_mover = mover
	_senses = senses
	_goal = goal
	_last_seen = goal


func state_name() -> StringName:
	return STATE_NAMES[fsm.state]


func target_peer() -> int:
	return _target


## US-043 REDIRECT: runs to `point` (nearest nav point) for `sec` s, chases nobody.
func mislead(point: Vector2, sec: float) -> bool:
	if not point.is_finite() or sec <= 0.0:
		return false
	_misled_point = _mover.closest_reachable(point)
	_misled_left = sec
	_target = 0
	_contact = 0.0
	misled_count += 1
	fsm.go(State.MISLED)
	return true


func step(delta: float) -> Vector2:
	fsm.step(delta)
	if listening:
		_contact = 0.0
		_mover.stop()
		return Vector2.ZERO
	if fsm.state == State.MISLED:
		_misled_left -= maxf(delta, 0.0)
		if _misled_left > 0.0:
			return _go(_misled_point, delta, -1)
		_last_seen = _misled_point
		fsm.go(State.SEARCH)
		return Vector2.ZERO
	var peer: int = _visible_target()
	if peer != 0:
		_target = peer
		_last_seen = CivilianSenses.position_of(_senses.player(peer))
		if fsm.state != State.CHASE:
			fsm.go(State.CHASE)
	match fsm.state:
		State.RUN:
			return _go(_goal, delta, State.SEARCH)
		State.CHASE:
			if peer == 0:
				_contact = 0.0
				fsm.go(State.SEARCH)
				return Vector2.ZERO
			return _chase(peer, delta)
		State.SEARCH:
			if fsm.time_in_state >= tuning.search_sec:
				fsm.go(State.WAIT)
				return Vector2.ZERO
			return _go(_last_seen, delta, -1)
		State.WAIT:
			return _go(_senses.marker_position(tuning.wait_marker), delta, -1)
	return Vector2.ZERO


func _chase(peer: int, delta: float) -> Vector2:
	var player: Node2D = _senses.player(peer)
	var spot: Vector2 = _senses.predicted(player, civilian_tuning.lead_cap_sec)
	var dist: float = _body.global_position.distance_to(spot)
	_contact = CivilianRules.contact_step(_contact, dist, civilian_tuning.contact_reach, delta)
	if _contact >= civilian_tuning.contact_time - 0.0001:
		_contact = 0.0
		if bool(player.call(&"host_catch", CATCHER)):
			catches.append(peer)
		_target = 0
		return Vector2.ZERO
	_mover.move_to(_last_seen, tuning.speed, civilian_tuning.contact_reach * 0.5)
	return _mover.desired_velocity(delta)


## Go to the target; on arrival (or if unreachable) switch to state `then` (-1 = stay).
func _go(point: Vector2, delta: float, then: int) -> Vector2:
	if not point.is_finite():
		return Vector2.ZERO
	_mover.move_to(point, tuning.speed, ARRIVE_PX)
	if _mover.arrived() or _mover.failed():
		if then >= 0:
			fsm.go(then)
		return Vector2.ZERO
	return _mover.desired_velocity(delta)


## Nearest visible (range + line of sight) free or held player; 0 if none. An ongoing target takes priority.
func _visible_target() -> int:
	var best: int = 0
	var best_dist: float = INF
	var here: Vector2 = _body.global_position
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		var player: Node2D = node as Node2D
		if player == null or not player.has_method(&"is_caught") or bool(player.call(&"is_caught")):
			continue
		if cover_query.is_valid() and bool(cover_query.call(player.get_multiplayer_authority())):
			continue  # US-043: intact cover = bystander (no heist: cover_intact false: everyone is chased)
		var pos: Vector2 = CivilianSenses.position_of(player)
		var dist: float = here.distance_to(pos)
		if dist > tuning.sight_range or not _perception.has_line_of_sight(here, pos):
			continue
		if player.get_multiplayer_authority() == _target:
			dist -= tuning.sight_range
		if dist < best_dist:
			best_dist = dist
			best = player.get_multiplayer_authority()
	return best
