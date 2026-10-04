class_name ShelfProp
extends Node2D
## Shelf end (US-010 AC5 DISTRACT; GDD §9.3, KR-026; S2, S7, S8). At store_a `ShelfProp1..3` markers (`Props/ShelfProp<n>`). Two Interactables:
## - `Topple` (E, `interact`, instant, single use): knocks goods over -> host `NoiseBus` noise `StoreToolsTuning.KIND_TOPPLE`
##   (`topple_radius` 320 px). The owner hears it while at the counter (ClerkSpot) -> LISTEN (walks to the sound, direction = this prop);
##   not heard from the backroom or phone spot (wall x0.5 / distance).
## - `Phone` (Q, `intimidate`, hold 0.5 s): player leaves their phone on the shelf (1 phone per heist across all shelf ends; every peer
##   derives it from sibling props' replicated state) -> rings after `phone_delay_sec` (`KIND_CELLPHONE`, `phone_radius` 240 px; at
##   `phone_ring_interval_sec` intervals, at most `phone_ring_max` times) -> owner walks to the sound; on reaching the LISTEN point
##   they find the phone (`host_take_phone`) and ringing stops.
## State (host writes, replicated): `toppled`, `phone_state` (CivilianRules.Phone). Clock in `CivilianRules.PhoneClock` (node-free).
## Responsible peers only on the host (`distraction_peer(kind)`; the owner's "again?" cost). Dump (S6 "props"):
## {"toppled", "phone", "rings", "topple", "phone_drop"}.

const TOPPLE_DEF_PATH := "res://data/props/shelf_topple.tres"
const PHONE_DEF_PATH := "res://data/props/shelf_phone.tres"
const GROUP := &"shelf_props"

@export var topple_def: PropDef
@export var phone_def: PropDef
@export var tuning: StoreToolsTuning

## Replicated state (host writes).
var toppled: bool = false
var phone_state: int = CivilianRules.Phone.NONE

var _topple_peer: int = 0
var _clock: CivilianRules.PhoneClock = null

@onready var _topple: Interactable = $Topple
@onready var _phone: Interactable = $Phone


func _ready() -> void:
	if topple_def == null:
		topple_def = load(TOPPLE_DEF_PATH) as PropDef
	if phone_def == null:
		phone_def = load(PHONE_DEF_PATH) as PropDef
	if tuning == null:
		tuning = StoreToolsTuning.load_default()
	_setup(_topple, topple_def)
	_setup(_phone, phone_def)
	_phone.input_action = &"intimidate"
	_topple.completed.connect(_on_topple)
	_phone.completed.connect(_on_phone)
	_clock = CivilianRules.PhoneClock.new(tuning.phone_delay_sec, tuning.phone_ring_interval_sec, tuning.phone_ring_max)
	add_to_group(GROUP)
	_refresh()
	add_to_group(PropDump.GROUP)
	PropDump.register()


func _physics_process(delta: float) -> void:
	step(delta)


## One step: phone clock on the host; prompt lines on every peer.
func step(delta: float) -> void:
	if multiplayer.is_server() and _clock.state != CivilianRules.Phone.NONE:
		if _clock.step(delta):
			NoiseBus.emit_noise(global_position, tuning.phone_radius, StoreToolsTuning.KIND_CELLPHONE, _clock.peer)
		phone_state = _clock.state
	_refresh()


## Whether a phone was left on this shelf end (every peer; replicated state).
func has_phone() -> bool:
	return phone_state != CivilianRules.Phone.NONE


## Whether the phone is ringing (every peer).
func is_ringing() -> bool:
	return phone_state == CivilianRules.Phone.RINGING


## Host only: who is responsible for the distraction (kind: KIND_TOPPLE / KIND_CELLPHONE); 0 if none.
func distraction_peer(kind: StringName) -> int:
	if kind == StoreToolsTuning.KIND_TOPPLE:
		return _topple_peer
	if kind == StoreToolsTuning.KIND_CELLPHONE and _clock != null:
		return _clock.peer
	return 0


## Host only: owner found the phone (while ringing or after it finished ringing). True if taken.
func host_take_phone() -> bool:
	if not multiplayer.is_server() or not _clock.take():
		return false
	phone_state = _clock.state
	return true


func dump_state() -> Dictionary:
	return {
		"toppled": toppled,
		"phone": CivilianRules.PHONE_NAMES[clampi(phone_state, 0, CivilianRules.PHONE_NAMES.size() - 1)],
		"rings": _clock.rings if _clock != null else 0,
		"topple": _topple.stats(),
		"phone_drop": _phone.stats(),
	}


## Prompt lines (every peer): topple is single use; phone is one per heist (while no shelf end has one).
func _refresh() -> void:
	_topple.enabled = not toppled
	_phone.enabled = not _any_phone()


func _any_phone() -> bool:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method(&"has_phone") and bool(node.call(&"has_phone")):
			return true
	return false


## Host only (Interactable.completed).
func _on_topple(peer_id: int) -> void:
	if toppled:
		return
	toppled = true
	_topple_peer = peer_id
	_refresh()
	NoiseBus.emit_noise(global_position, tuning.topple_radius, StoreToolsTuning.KIND_TOPPLE, peer_id)


## Host only (Interactable.completed).
func _on_phone(peer_id: int) -> void:
	if _any_phone() or not _clock.plant(peer_id):
		return
	phone_state = _clock.state
	_refresh()


static func _setup(item: Interactable, def: PropDef) -> void:
	item.action_key = def.action_key
	item.hold_time = def.hold_time
	item.interact_range = def.interact_range
	item.requirement = def.requirement
