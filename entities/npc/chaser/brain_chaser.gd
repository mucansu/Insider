class_name ChaserBrain
extends Node
## Mahalleli (chaser) beyni (US-008 AC6/AC7; GDD §9.3; KR-019 K3). Yalnız host'ta; Chaser kökü her adımda
## `step(delta)` çağırır, istenen hızı uygular. Durumlar: RUN (bağırış yerine koşar) → CHASE (en yakın görünen
## serbest ya da tutulan oyuncu; 28 px + 0,5 sn temas, oyuncu konumu ON-03 ile ileri alınır → kalıcı yakalama,
## kurtarma yok) → SEARCH (görüş yoksa son görülen konum, 15 sn) → WAIT (ön kapıda bekler). Görüş: koni yok
## (aranan kişiye bakar), görüş hattı (world + vision_block, camlar geçirir) + menzil.

enum State { RUN, CHASE, SEARCH, WAIT }

const STATE_NAMES: Array[StringName] = [&"run", &"chase", &"search", &"wait"]
const EDGES := {
	State.RUN: [State.CHASE, State.SEARCH],
	State.CHASE: [State.SEARCH],
	State.SEARCH: [State.CHASE, State.WAIT],
	State.WAIT: [State.CHASE],
}
const ARRIVE_PX := 8.0
## `player_caught {peer, by}` olayında yakalayan.
const CATCHER := &"chaser"

var tuning: ChaserTuning
var civilian_tuning: CivilianTuning
var fsm := Fsm.new(State.RUN, EDGES)
## Yakalanan peer'lar (döküm).
var catches: Array[int] = []

var _body: CharacterBody2D = null
var _perception: Perception = null
var _mover: NpcMover = null
var _senses: CivilianSenses = null
var _goal: Vector2 = Vector2.INF
var _target: int = 0
var _last_seen: Vector2 = Vector2.INF
var _contact: float = 0.0


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


func step(delta: float) -> Vector2:
	fsm.step(delta)
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


## Hedefe git; varınca (ya da gidilemezse) `then` durumuna geç (−1 = kal).
func _go(point: Vector2, delta: float, then: int) -> Vector2:
	if not point.is_finite():
		return Vector2.ZERO
	_mover.move_to(point, tuning.speed, ARRIVE_PX)
	if _mover.arrived() or _mover.failed():
		if then >= 0:
			fsm.go(then)
		return Vector2.ZERO
	return _mover.desired_velocity(delta)


## En yakın görünen (menzil + görüş hattı) serbest ya da tutulan oyuncu; yoksa 0. Süren hedef önceliklidir.
func _visible_target() -> int:
	var best: int = 0
	var best_dist: float = INF
	var here: Vector2 = _body.global_position
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		var player: Node2D = node as Node2D
		if player == null or not player.has_method(&"is_caught") or bool(player.call(&"is_caught")):
			continue
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
