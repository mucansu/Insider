class_name Civilian
extends CharacterBody2D
## Civilian (US-016; GDD §9.2 "Venue population"; S2, S11): customer or passerby. The population spawner (`Population`, host only) spawns
## and deletes it via `PopulationSpawner` (MultiplayerSpawner, spawn_path = NPCs); clients get it from the spawner (a late joiner sees
## existing civilians in the first packet). Root CharacterBody2D (layer npcs, mask world: does not push players and players do not push it -
## AC7; visual goes translucent on overlap). Components `Perception` + `Suspicion` (civilian multiplier table, `CivilianSenses.factor_for`),
## `Agenda` (linear route mode), `Mover`, `Senses`, `Brain` (CivilianBrain) and visual `Visual` (NpcVisual; "?"/"!" and balloon).
## Host: brain + movement + replication. Replication (S11 pattern, 15 Hz): position/facing/meter unreliable continuous, state reliable on
## change; role and serial number in spawn data. Result events (`customer_enter`, `customer_tell`, `customer_flee`, `passerby_tell`,
## `passerby_flee`; AC5, SFX names) become the `event_raised` signal in the same order on every peer via reliable RPC (Population collects
## the dump). The client follows the position with smoothing.
## US-037 (KR-027): `Contact` component (NpcContact): a shove slides it (physics, out of walls) and stops the brain while it staggers; a
## calm shove adds suspicion to the pusher, and it observes others' shoves (range + line of sight).

## On every peer: result event (kind, related player; 0 if none).
signal event_raised(civilian: Civilian, kind: StringName, peer_id: int)

const TUNING_PATH := "res://data/npc/population.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const EVENT_KINDS: Array[StringName] = [&"customer_enter", &"customer_tell", &"customer_flee", &"passerby_tell",
	&"passerby_flee"]
const SMOOTHING := 14.0
const SNAP_PX := 96.0
const MAX_EVENTS := 32

@export var tuning: PopulationTuning
@export var civilian_tuning: CivilianTuning
## False: tests drive `step()` by hand.
@export var auto_step: bool = true

## Spawn data (every peer): role (PopulationRules.Role) and serial number (registry owner id).
var role: int = PopulationRules.Role.CUSTOMER
var serial: int = 0
## Host only: spawn order and plan (Population supplies), owner and population spawner.
var order: PopulationRules.Order = null
var shop_spots: Array[StringName] = []
var population: Node = null
var store_owner: Node = null

## Replicated state (host writes).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.DOWN
var net_meter: float = 0.0
var net_state: int = 0

## State the visual reads (on every peer).
var facing: Vector2 = Vector2.DOWN
var bubble: int = CivilianRules.Bubble.NONE
var last_event: StringName = &""
var last_event_age: float = INF

var _rules: CivilianRules.Params = null
var _events: Array[StringName] = []
var _bubbles: Array[int] = []
var _contact: NpcContact = null

@onready var _perception: Perception = $Perception
@onready var _suspicion: Suspicion = $Suspicion
@onready var _agenda: Agenda = $Agenda
@onready var _mover: NpcMover = $Mover
@onready var _senses: CivilianSenses = $Senses
@onready var _brain: CivilianBrain = $Brain
@onready var _visual: NpcVisual = $Visual


func _ready() -> void:
	_suspicion.set_physics_process(false)  # the brain runs it in order
	if tuning == null:
		tuning = load(TUNING_PATH) as PopulationTuning
	if civilian_tuning == null:
		civilian_tuning = load(CIVILIAN_TUNING_PATH) as CivilianTuning
	_rules = civilian_tuning.rules_params(_perception.tuning)
	_visual.role = NpcVisual.Role.PASSERBY if role == PopulationRules.Role.PASSERBY else NpcVisual.Role.CUSTOMER
	_contact = NpcContact.attach(self, false, _perception, _add_suspicion, Callable())
	net_position = position
	if _host_side():
		_perception.set_cone(cone_half_angle(), cone_range())
		_senses.setup(_level(), civilian_tuning, _perception.tuning)
		_brain.tuning = tuning
		_brain.civilian_tuning = civilian_tuning
		_brain.setup(self, _perception, _suspicion, _agenda, _mover, _senses)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(delta: float) -> void:
	var slide: Vector2 = _contact.step(delta)
	if _host_side():
		velocity = Vector2.ZERO if _contact.is_staggering() else _brain.step(delta)  # US-037: stagger stops the brain
		if not slide.is_zero_approx():
			velocity = slide
		move_and_slide()
		net_position = position
		facing = _perception.facing
		net_facing = facing
		net_state = _brain.fsm.state
		var top: float = 0.0
		for peer_id: int in _suspicion.peers():
			top = maxf(top, _suspicion.value_of(peer_id))
		net_meter = top
	else:
		if position.distance_to(net_position) > SNAP_PX:
			position = net_position
		else:
			position = position.lerp(net_position, 1.0 - exp(-SMOOTHING * delta))
		if not net_facing.is_zero_approx():
			facing = facing.slerp(net_facing.normalized(), 1.0 - exp(-SMOOTHING * delta)).normalized()
	last_event_age += delta
	var next: int = CivilianRules.bubble(_rules, net_meter, false, bubble)
	if next != bubble:
		bubble = next
		_bubbles.append(next)


func brain() -> CivilianBrain:
	return _brain


func agenda() -> Agenda:
	return _agenda


func perception() -> Perception:
	return _perception


func suspicion() -> Suspicion:
	return _suspicion


func senses() -> CivilianSenses:
	return _senses


## Contact component (US-037; tests).
func contact() -> NpcContact:
	return _contact


## US-037 suspicion sink (host): a shove's calm cost; the shove spot becomes the last seen position.
func _add_suspicion(peer_id: int, amount: float, where: Vector2) -> void:
	_suspicion.apply_delta(peer_id, amount)
	_suspicion.hint_position(peer_id, where)


func role_name() -> StringName:
	return PopulationRules.role_name(role)


## Name of the replicated state (CivilianBrain.State).
func state_name() -> StringName:
	return CivilianBrain.STATE_NAMES[clampi(net_state, 0, CivilianBrain.STATE_NAMES.size() - 1)]


func is_customer() -> bool:
	return role == PopulationRules.Role.CUSTOMER


## The visual's cone (degrees, px): the role's cone.
func cone_half_angle() -> float:
	return tuning.passerby_half_angle_deg if role == PopulationRules.Role.PASSERBY else tuning.customer_half_angle_deg


func cone_range() -> float:
	return tuning.passerby_view_range if role == PopulationRules.Role.PASSERBY else tuning.customer_view_range


## Host: broadcasts the result event to everyone (same order on every peer).
func host_event(kind: StringName, peer_id: int) -> void:
	if not _host_side() or not EVENT_KINDS.has(kind):
		return
	if Net.is_online() and is_inside_tree():
		_rpc_event.rpc(kind, peer_id)
	else:
		_rpc_event(kind, peer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_event(kind: StringName, peer_id: int) -> void:
	if not EVENT_KINDS.has(kind):
		return
	if _events.size() < MAX_EVENTS:
		_events.append(kind)
	last_event = kind
	last_event_age = 0.0
	event_raised.emit(self, kind, peer_id)


func events() -> Array[StringName]:
	return _events.duplicate()


func dump_row() -> Dictionary:
	return {"name": String(name), "role": role_name(), "state": state_name(), "events": _events.duplicate()}


## Nearest ancestor with the Level API (S4; duck typing).
func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"marker"):
		node = node.get_parent()
	return node


## Host or offline (S2; from Net flags, same pattern as Game).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
