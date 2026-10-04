class_name Chaser
extends CharacterBody2D
## Neighbour (US-008 AC6; GDD §9.3; KR-021, ON-08): when the owner shouts, the shop's alert manager (`StoreAlert`) spawns it at
## `NeighbourSpawn` (MultiplayerSpawner, host; custom spawn_function supplies position and run target). Root CharacterBody2D (layer npcs,
## mask world: does not push players); components `Perception` (line of sight only), `Mover`, `Senses`, `Brain` (ChaserBrain) and `Visual`.
## Host: brain + accelerated movement + replication (15 Hz, position/facing unreliable, state reliable); client follows with smoothing.
## Visual always shows "!". Dump: StoreAlert under the "chasers" key.
## US-043: `Misdirect` Interactable (REDIRECT "they ran that way!"; same tuning as the owner's, tag `cover`); enabled on every peer from
## the owner's `misdirect_open()`; on completion the host calls the owner's `misdirect(peer)`. The neighbour stands still while held (brain
## `listening`). `mislead(point, s)` host API (the owner calls it).
## US-037 (KR-027): `Contact` component (NpcContact, chaser rules): a shove from the front slides it, stops the brain for the stagger, resets
## the catch window (`ChaserBrain.on_pushed`) and makes it immune for a while; contact from its back is not a shove.

const TUNING_PATH := "res://data/npc/chaser_tuning.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const SMOOTHING := 14.0
const SNAP_PX := 96.0

@export var tuning: ChaserTuning
@export var civilian_tuning: CivilianTuning
@export var auto_step: bool = true

## Replicated state (host writes).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.LEFT
var net_state: int = 0

## State the visual reads.
var facing: Vector2 = Vector2.LEFT
var bubble: int = CivilianRules.Bubble.ALARM
## Run target (spawn data; host).
var goal: Vector2 = Vector2.INF

var _contact: NpcContact = null

@onready var _perception: Perception = $Perception
@onready var _mover: NpcMover = $Mover
@onready var _senses: CivilianSenses = $Senses
@onready var _brain: ChaserBrain = $Brain
@onready var _misdirect: Interactable = $Misdirect


func _ready() -> void:
	# IS-106: global default (or the scene's) + the level's per-map overrides.
	tuning = VenueTuning.of(self, VenueTuning.CHASER, tuning) as ChaserTuning
	civilian_tuning = VenueTuning.of(self, VenueTuning.CIVILIAN, civilian_tuning) as CivilianTuning
	net_position = position
	_contact = NpcContact.attach(self, true, _perception, Callable(), _on_pushed)
	StoreOwner.setup_misdirect_item(_misdirect,
		VenueTuning.of(self, VenueTuning.STORE_TOOLS, StoreToolsTuning.load_default()) as StoreToolsTuning)
	_misdirect.completed.connect(_on_misdirect)
	_refresh_misdirect()
	if _host_side():
		_senses.setup(_level(), civilian_tuning, _perception.tuning)
		_brain.tuning = tuning
		_brain.civilian_tuning = civilian_tuning
		_brain.cover_query = _cover_intact
		_brain.setup(self, _perception, _mover, _senses, goal if goal.is_finite() else global_position)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(delta: float) -> void:
	_refresh_misdirect()
	var slide: Vector2 = _contact.step(delta)
	if _host_side():
		_brain.listening = _misdirect.busy_by != 0
		if _contact.is_staggering():
			velocity = Vector2.ZERO  # US-037: stagger stops the brain
		else:
			velocity = velocity.move_toward(_brain.step(delta), tuning.acceleration * delta)
		if not slide.is_zero_approx():
			velocity = slide
		move_and_slide()
		if velocity.length() > 1.0:
			facing = velocity.normalized()
		net_position = position
		net_facing = facing
		net_state = _brain.fsm.state
		return
	if position.distance_to(net_position) > SNAP_PX:
		position = net_position
	else:
		position = position.lerp(net_position, 1.0 - exp(-SMOOTHING * delta))
	if not net_facing.is_zero_approx():
		facing = facing.slerp(net_facing.normalized(), 1.0 - exp(-SMOOTHING * delta)).normalized()


func brain() -> ChaserBrain:
	return _brain


## Host API (US-043): sent running the wrong way; true if accepted.
func mislead(point: Vector2, sec: float) -> bool:
	return _brain.mislead(point, sec) if _host_side() else false


## Contact component (US-037; tests).
func contact() -> NpcContact:
	return _contact


## US-037 shove hook (host): the catch window restarts; never a rescue.
func _on_pushed(_peer_id: int, _calm: bool) -> bool:
	_brain.on_pushed()
	return false


func misdirect_interactable() -> Interactable:
	return _misdirect


## Shop owner (node under S4 `npcs_root` offering `misdirect`); null if none.
func shop_owner() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for node: Node in parent.get_children():
		if node.has_method(&"misdirect"):
			return node
	return null


## Whether the player's cover is intact (from the owner's senses; false if no owner: everyone is chased).
func _cover_intact(peer_id: int) -> bool:
	var o: Node = shop_owner()
	if o == null or not o.has_method(&"senses"):
		return false
	var senses: CivilianSenses = o.call(&"senses") as CivilianSenses
	return senses != null and senses.cover_intact(peer_id)


func _refresh_misdirect() -> void:
	var o: Node = shop_owner()
	_misdirect.enabled = o != null and bool(o.call(&"misdirect_open"))


func _on_misdirect(peer_id: int) -> void:
	var o: Node = shop_owner()
	if o != null:
		o.call(&"misdirect", peer_id)


func state_name() -> StringName:
	return ChaserBrain.STATE_NAMES[clampi(net_state, 0, ChaserBrain.STATE_NAMES.size() - 1)]


func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"marker"):
		node = node.get_parent()
	return node


## Host or offline (S2). Read from Net flags: at disconnect (dump, last frames) asking `multiplayer.is_server()` on a closed transport
## must not print an error (same pattern as Game).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
