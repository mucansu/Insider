class_name StoreAlert
extends Node
## Shop alert manager (US-008 AC5/AC6/AC9; GDD §6.2, §9.1 T1 alert mapping; S3 addendum). Static node under `NPCs` in the level; siblings
## `Owner` (StoreOwner) and `ChaserSpawner` (MultiplayerSpawner, spawn_path = NPCs). Only the host decides; the result is written to Game's
## replicated alert API.
## - Ladder (I4, shop cluster): {0->1, 1->2, 2->3, 3->5, 2->1, 1->0} (`Fsm`; jumps walk through the intermediate tier). The owner's requested tier
##   (`OwnerBrain.alarm_want`: 1 suspicion/question, 2 shouted) goes up at once; 2 -> 1 when the owner calms down (30 s without sight), 1 -> 0
##   after `alert_calm_sec` of calm. When the first neighbour reaches the front/back door or enters: 3 (no return) + police timer
##   (`police_timer_sec`, Game.alert_timer_left); when it ends 5 and `police_arrived` (session_event; US-012 result).
## - Neighbour: on every shout (first and repeat) `neighbour_delay_sec` later one neighbour at `NeighbourSpawn` (at most `max_neighbours`);
##   run target is the owner's position at the shout. `chaser_spawn` is emitted on every peer.
## - US-016 additions: NPC cap (`room_query`, population spawner connects it; unlimited if empty): a due neighbour waits for room when full;
##   passerby -> neighbour conversion `spawn_chaser_at` (population spawner calls it on a shout; not counted in neighbours). Neighbour names use
##   a single counter (`Chaser<n>`). Dump "chasers": {spawned, states, catches (host)}.

## On every peer: neighbour spawned (AC10).
signal chaser_spawn(chaser: Node)
## On every peer: police arrived (alert 5; AC10).
signal police_arrived()

const CHASER_SCENE := "res://entities/npc/chaser/chaser.tscn"
const OWNER_TUNING_PATH := "res://data/npc/owner_tuning.tres"
const EDGES := {0: [1], 1: [2, 0], 2: [3, 1], 3: [5]}
const POLICE_LEVEL := 5
const INSIDE_LEVEL := 3
const DUMP_KEY := "chasers"
const POLICE_EVENT := &"police_arrived"

@export var owner_path: NodePath = ^"../Owner"
@export var spawner_path: NodePath = ^"../ChaserSpawner"
@export var tuning: OwnerTuning
@export var auto_step: bool = true
## False: the alert manager does not run (fixture without NPCs).
@export var active: bool = true
## Whether there is room under the NPC cap (US-016; func() -> bool). Unlimited if empty.
var room_query: Callable = Callable()

var ladder := Fsm.new(0, EDGES)

var _owner: StoreOwner = null
var _spawner: MultiplayerSpawner = null
var _chaser_scene: PackedScene = null
var _pending: Array[float] = []
var _spawned: int = 0
var _serial: int = 0
var _converted: int = 0
var _seen_spawns: int = 0
var _calm_for: float = 0.0
var _shout_at: Vector2 = Vector2.INF


func _ready() -> void:
	if tuning == null:
		tuning = load(OWNER_TUNING_PATH) as OwnerTuning
	_owner = get_node_or_null(owner_path) as StoreOwner
	_spawner = get_node_or_null(spawner_path) as MultiplayerSpawner
	_chaser_scene = load(CHASER_SCENE) as PackedScene
	if _spawner != null:
		_spawner.spawn_function = _spawn_chaser
		_spawner.spawned.connect(_on_spawned)
	Game.session_event.connect(_on_session_event)
	if active and _host_side() and _owner != null and _owner.active:
		_owner.brain().shouted.connect(_on_shouted)
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, dump_state)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


## One step (host only): neighbour counters, requested tier, police timer.
func step(delta: float) -> void:
	if not active or not _host_side() or _owner == null or not _owner.active:
		return
	for i: int in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] <= 0.0 and _has_room():
			_pending.remove_at(i)
			_spawn_neighbour()
	var want: int = _owner.brain().alarm_want()
	if _any_chaser_inside():
		want = maxi(want, INSIDE_LEVEL)
	if ladder.state == INSIDE_LEVEL and Game.alert_timer_left() == 0.0:
		want = POLICE_LEVEL
	_calm_for = _calm_for + delta if want == 0 else 0.0
	ladder.step(delta)
	_apply(want)


func level() -> int:
	return ladder.state


func chasers() -> Array[Chaser]:
	var out: Array[Chaser] = []
	var root: Node = get_parent()
	if root != null:
		for child: Node in root.get_children():
			if child is Chaser:
				out.append(child as Chaser)
	return out


func dump_state() -> Dictionary:
	var states: Array[StringName] = []
	var catches: Array[int] = []
	for c: Chaser in chasers():
		states.append(c.state_name())
		if _host_side():
			catches.append_array(c.brain().catches)
	var out := {"spawned": _seen_spawns, "states": states}
	if _host_side():
		out["catches"] = catches
		var misled: int = 0
		for c: Chaser in chasers():
			misled += c.brain().misled_count
		out["misled"] = misled  # US-043: neighbours running the wrong way via REDIRECT
		out["ladder"] = ladder.history_rows()  # [tier, entry time]; I4 evidence (on a client Game "alert.history")
	return out


func _apply(want: int) -> void:
	var current: int = ladder.state
	if want > current:
		for next: int in ladder.route(want):
			_enter(next)
		return
	if current == 2 and want <= 1:
		_enter(1)
	elif current == 1 and want == 0 and _calm_for >= tuning.alert_calm_sec:
		_enter(0)


func _enter(next: int) -> void:
	if not ladder.go(next):
		return
	Game.set_alert_level(next)
	if next == INSIDE_LEVEL:
		Game.set_alert_timer(tuning.police_timer_sec)
	elif next == POLICE_LEVEL:
		if Net.is_online():
			Game.raise_session_event(POLICE_EVENT, {})  # session_event on every peer -> police_arrived
		else:
			police_arrived.emit()  # offline: no session event


func _on_shouted(_recheck: bool) -> void:
	_shout_at = _owner.global_position
	if _spawned + _pending.size() < tuning.max_neighbours:
		_pending.append(tuning.neighbour_delay_sec)


func _spawn_neighbour() -> void:
	if _spawner == null or _owner == null:
		return
	var at: Vector2 = _owner.senses().marker_position(tuning.neighbour_marker)
	if not at.is_finite():
		push_warning("StoreAlert: %s işareti yok; komşu üretilmedi" % tuning.neighbour_marker)
		return
	_spawned += 1
	_spawn(at, _shout_at)


## Host (US-016 conversion): spawns a neighbour at `at` (global) with run target `goal`; not counted in neighbours.
func spawn_chaser_at(at: Vector2, goal: Vector2) -> Node:
	if not active or not _host_side() or _spawner == null or not at.is_finite():
		return null
	_converted += 1
	return _spawn(at, goal)


func converted_count() -> int:
	return _converted


func _spawn(at: Vector2, goal: Vector2) -> Node:
	_serial += 1
	var root: Node2D = get_parent() as Node2D
	var data := {"n": _serial, "pos": root.to_local(at) if root != null else at, "goal": goal}
	var node: Node = _spawner.spawn(data)
	if node != null:
		_on_spawned(node)
	return node


func _has_room() -> bool:
	return not room_query.is_valid() or bool(room_query.call())


## Spawner's spawn_function (in spawn() on the host, when the packet arrives on a client).
func _spawn_chaser(data: Variant) -> Node:
	var d: Dictionary = data if data is Dictionary else {}
	var chaser: Chaser = _chaser_scene.instantiate() as Chaser
	chaser.name = "Chaser%d" % int(d.get("n", 0))
	if d.get("pos") is Vector2:
		chaser.position = d["pos"]
	if d.get("goal") is Vector2:
		chaser.goal = d["goal"]
	return chaser


func _on_spawned(node: Node) -> void:
	_seen_spawns += 1
	chaser_spawn.emit(node)


func _on_session_event(kind: StringName, _data: Dictionary) -> void:
	if kind == POLICE_EVENT:
		police_arrived.emit()


## A neighbour reached the front/back door or is inside (alert 3).
func _any_chaser_inside() -> bool:
	var senses: CivilianSenses = _owner.senses()
	for c: Chaser in chasers():
		var pos: Vector2 = c.global_position
		if CivilianRules.is_inside(senses.zone_of(pos)):
			return true
		for marker_name: StringName in tuning.entry_markers:
			var door: Vector2 = senses.marker_position(marker_name)
			if door.is_finite() and pos.distance_to(door) <= tuning.entry_radius:
				return true
	return false


## Host or offline (S2). Read from Net flags: at disconnect (dump, last frames) asking `multiplayer.is_server()` on a closed transport
## must not print an error (same pattern as Game).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
