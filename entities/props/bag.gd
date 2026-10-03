class_name Bag
extends Node2D
## Cash bag (US-012; GDD §9.3; S7, S8, S10): `data/props/bag.tres`. Backroom cash (BackroomCash). Two Interactable components (S7):
## - `Take`: hold to pick up a floor bag (definition time, 2 s); empty-handed players only (tag `free_hands`).
## - `Handoff`: an empty-handed teammate next to the carrier takes it over by holding 0.3 s; the bag moves with the carrier.
## Host rules (HeistRules): while the carrier sprints, each full second rolls a 25% drop; a dropped bag lands at the carrier's last
## known position and emits 160 px noise (S8). It also drops if the carrier leaves or Game reports a catch (`host_drop`); a dropped bag
## cannot be re-taken for 0.3 s (KR-026). At heist end Game calls `host_lock`: host rejects new take/handoff (`blocked`).
## `value` comes from the definition and counts as the carrier's loot on escape (Game reads it).
## Replicated state (host writes, MultiplayerSynchronizer, on change): `carrier` (0 = on floor), `floor_position` (Props space), `drops`.
## Position is derived from state on every peer. Visual (`Visual`) only reads state (KR-003). Dump (S6 "props"): `dump_state()`.

## Host only: bag picked up or taken over (note: "Hamal").
signal taken(peer_id: int)
## Host only: bag dropped (sprint, catch, leave).
signal dropped(peer_id: int)

const DEF_PATH := "res://data/props/bag.tres"
## Node position relative to the carrier's center while carried (handoff component, fog memory, dump). Drawn grip is separate:
## BagVisual derives it from the carrier's puppet hand via BagCarry (IS-085).
const CARRY_OFFSET := Vector2(10.0, 6.0)

@export var def: PropDef

## Replicated state (host writes).
var carrier: int = 0:
	set = _set_carrier
var floor_position: Vector2 = Vector2.ZERO
var drops: int = 0
## Loot value (from definition; fixed until the GDD 300-600 seed lands).
var value: int = 0

## Host: drop roll `func() -> float` (0..1); own RandomNumberGenerator if invalid. Tests override.
var roll_source: Callable = Callable()
## Host: noise output, S8 signature `func(pos: Vector2, radius: float, kind: StringName, source_peer: int)`;
## NoiseBus if invalid. Tests override.
var noise_sink: Callable = Callable()

var _run_s: float = 0.0
var _takes: int = 0
## Host: heist over (new take/handoff rejected) and the re-take lock remaining after a drop (s).
var _locked: bool = false
var _retake_left: float = 0.0
## Carriers seen on this peer (from replicated `carrier`; dump/diagnostics only).
var _seen_carriers: Array[int] = []
var _rng := RandomNumberGenerator.new()

@onready var _take: Interactable = $Take
@onready var _handoff: Interactable = $Handoff


func _ready() -> void:
	if def == null:
		push_error("Bag: def atanmamış; %s yükleniyor" % DEF_PATH)
		def = load(DEF_PATH) as PropDef
	add_to_group(HeistRules.BAG_GROUP)
	value = def.cash_value
	floor_position = position
	_take.action_key = def.action_key
	_take.hold_time = def.hold_time
	_take.interact_range = def.interact_range
	_take.requirement = def.requirement
	_handoff.action_key = def.alt_action_key if not def.alt_action_key.is_empty() else def.action_key
	_handoff.hold_time = HeistRules.HANDOFF_HOLD_TIME
	_handoff.interact_range = def.interact_range
	_handoff.requirement = def.requirement
	_take.completed.connect(_on_take_completed)
	_handoff.completed.connect(_on_handoff_completed)
	_take.start_blocker = _take_blocked
	_handoff.start_blocker = _handoff_blocked
	_rng.randomize()
	_apply()
	add_to_group(PropDump.GROUP)
	PropDump.register()


## Bag carried by `peer_id` (on every peer, from replicated state); null if none.
static func carried_by(tree: SceneTree, peer_id: int) -> Bag:
	if tree == null or peer_id <= 0:
		return null
	for node: Node in tree.get_nodes_in_group(HeistRules.BAG_GROUP):
		var bag: Bag = node as Bag
		if bag != null and bag.carrier == peer_id:
			return bag
	return null


func is_carried() -> bool:
	return carrier != 0


## 0..1 take/handoff progress (visual).
func progress_ratio() -> float:
	return maxf(_take.progress_ratio(), _handoff.progress_ratio())


func _physics_process(delta: float) -> void:
	step(delta)


## One time step (called by the physics step; tests use the same path): position follows state; on the host, each full second the
## carrier sprinted rolls the drop; if the carrier is gone (left) the bag drops.
func step(delta: float) -> void:
	_follow()
	_retake_left = maxf(_retake_left - delta, 0.0)
	if carrier == 0 or not multiplayer.is_server():
		return
	var actor: Node = _carrier_node()
	if actor == null:
		host_drop()
		return
	if HeistRules.node_flag(actor, HeistRules.SPRINT_METHODS):
		var before: float = _run_s
		_run_s += delta
		for i: int in HeistRules.rolls_due(before, _run_s):
			if HeistRules.drops(_roll()):
				host_drop()
				return


func _process(_delta: float) -> void:
	_follow()


## Host only (ignored otherwise): bag drops at the carrier's last known position and emits noise.
func host_drop() -> void:
	if carrier == 0 or not multiplayer.is_server():
		return
	var peer: int = carrier
	var actor: Node = _carrier_node()
	var at: Vector2 = global_position
	if actor != null and actor.has_method(&"interaction_position"):
		at = actor.call(&"interaction_position")
	var parent: Node2D = get_parent() as Node2D
	floor_position = parent.to_local(at) if parent != null else at
	drops += 1
	_run_s = 0.0
	_retake_left = HeistRules.BAG_RETAKE_DELAY
	carrier = 0
	_emit_noise(at, peer)
	dropped.emit(peer)


## Host only: heist over; new take/handoff requests are rejected.
func host_lock() -> void:
	if multiplayer.is_server():
		_locked = true


func dump_state() -> Dictionary:
	return {
		"carrier": carrier,
		"seen_carriers": _seen_carriers,
		"drops": drops,
		"takes": _takes,
		"value": value,
		"pos": global_position,
		"take": _take.stats(),
		"handoff": _handoff.stats(),
	}


# --- host ---

func _on_take_completed(peer_id: int) -> void:
	if carrier == 0:
		_give(peer_id)


func _on_handoff_completed(peer_id: int) -> void:
	if carrier != 0 and carrier != peer_id:
		_give(peer_id)


func _take_blocked() -> bool:
	return _locked or _retake_left > 0.0


func _handoff_blocked() -> bool:
	return _locked


func _give(peer_id: int) -> void:
	if _locked or peer_id <= 0 or carried_by(get_tree(), peer_id) != null:
		return  # hands full (another bag)
	_run_s = 0.0
	_takes += 1
	carrier = peer_id
	taken.emit(peer_id)


func _roll() -> float:
	if roll_source.is_valid():
		return float(roll_source.call())
	return _rng.randf()


func _emit_noise(at: Vector2, peer: int) -> void:
	if noise_sink.is_valid():
		noise_sink.call(at, HeistRules.BAG_DROP_NOISE_RADIUS, HeistRules.BAG_DROP_NOISE_KIND, peer)
	else:
		NoiseBus.emit_noise(at, HeistRules.BAG_DROP_NOISE_RADIUS, HeistRules.BAG_DROP_NOISE_KIND, peer)


## Carrier player node (from replicated `carrier` on every peer); null if none. Visual reads it.
func carrier_node() -> Node2D:
	return _carrier_node()


# --- state ---

## Carrier player node (S7 actor: authority is on the carrier); null if none.
func _carrier_node() -> Node2D:
	if carrier == 0 or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == carrier and node is Node2D:
			return node as Node2D
	return null


## Position from state: on the carrier while carried, floor_position when on the floor.
func _follow() -> void:
	var actor: Node2D = _carrier_node()
	if actor != null:
		global_position = actor.global_position + CARRY_OFFSET
	elif position != floor_position:
		position = floor_position


func _set_carrier(new_carrier: int) -> void:
	if new_carrier == carrier:
		return
	carrier = new_carrier
	if new_carrier != 0 and not _seen_carriers.has(new_carrier):
		_seen_carriers.append(new_carrier)
	_apply()


func _apply() -> void:
	if _take != null:
		_take.enabled = carrier == 0
	if _handoff != null:
		_handoff.enabled = carrier != 0
	if is_inside_tree():
		_follow()
