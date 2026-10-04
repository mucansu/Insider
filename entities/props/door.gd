class_name Door
extends Node2D
## Door (US-005 AC3; S7, S4): `data/props/door.tres`. Instant open/close (no hold); when closed `Body` (StaticBody2D, world layer) blocks
## passage, open has no blocker. Position = S4 door marker (center of the 1-tile gap); rotation 0 deg on horizontal walls, 90 on vertical.
## State (`is_open`, `changed_at` host wall clock) replicates via host-authoritative MultiplayerSynchronizer on change; initial state is
## the scene's `is_open`. Visual only reads state.
## Close blocker (IS-014): an open door will not close if the leaf (Body shape) would overlap an actor body on the players layer: host
## rejects with `blocked` (prompt stays visible). Player body is tested at the latest host-known position (`interaction_position()`;
## the ~100 ms delayed drawn position is not used); radius from the body's circle shape (0 if none). NPC bodies (npcs layer; positions
## host-authoritative) also block (US-008). Opening is always free. Rule: InteractionRules.circle_overlaps_box.
## Navigation link (US-008, S4 addendum): door state is written to the level's same-named `door_link` (no path through closed doors);
## skipped if the level has no such API (test_arena or no level).
## Dump (S6 "props"): {"open", "flips" (state changes seen in this process), "visible_delay_ms" (last change from host decision to
## visible in this process; -1 if none), "consistent" (final state = initial state + parity of seen changes: this process saw every
## change), "interact": Interactable.stats()}. Noise (US-009, S8): host emits `NoiseProfile.KIND_DOOR` at the door on every open/close.
## NPC close (IS-087 AC2): NPCs close doors only via `host_close_by_npc(actor_pos)` (interior door behind them); same Interactable NPC
## path (range + S2 margin, repeat cooldown, leaf blocker `is_closing_blocked`).
## Spring door (IS-108, KR-039): with `autoclose_sec` > 0 (set by the owner's senses for the back-bell door from
## `OwnerTuning.back_door_autoclose_sec`) the host closes an open door by itself once nobody has been in the leaf for that long - the NPC
## close path (peer 0: no bell, the usual door sound). Dump `autocloses`.

const DEF_PATH := "res://data/props/door.tres"
## Physics layer of bodies that block closing: players (architecture §4, layer 2).
const BLOCKER_LAYERS := PhysicsLayers.PLAYERS
## NPC bodies that block closing: npcs (architecture §4, layer 3; US-008).
const NPC_LAYERS := PhysicsLayers.NPCS

@export var def: PropDef

## Replicated state (host writes); the scene value is the initial state.
@export var is_open: bool = false:
	set = _set_open
var changed_at: float = 0.0
## Host: spring close delay (s; 0 = stays open). IS-108.
var autoclose_sec: float = 0.0

var _flips: int = 0
## True while host_close_by_npc runs: NPC completion (peer 0) may close.
var _npc_closing: bool = false
var _start_open: bool = false
var _seen_at: float = -1.0
var _open_idle: float = 0.0
var _autocloses: int = 0

@onready var _interactable: Interactable = $Interactable
@onready var _shape: CollisionShape2D = $Body/CollisionShape2D


func _ready() -> void:
	if def == null:
		push_error("Door: def atanmamış; %s yükleniyor" % DEF_PATH)
		def = load(DEF_PATH) as PropDef
	_interactable.hold_time = def.hold_time
	_interactable.interact_range = def.interact_range
	_interactable.requirement = def.requirement
	_interactable.completed.connect(_on_completed)
	_interactable.start_blocker = is_closing_blocked
	_start_open = is_open
	SfxEmitter.of(self)  # IS-024: create the player up front so the first sync (baseline state) stays silent
	_apply(false)
	add_to_group(PropDump.GROUP)
	PropDump.register()


func _physics_process(delta: float) -> void:
	step_autoclose(delta)


## Host only (IS-108): counts the time the open door has had nobody in its leaf; at `autoclose_sec` it closes like an NPC would.
func step_autoclose(delta: float) -> void:
	if autoclose_sec <= 0.0 or not is_open or not _is_host() or is_closing_blocked():
		_open_idle = 0.0
		return
	_open_idle += maxf(delta, 0.0)
	if _open_idle >= autoclose_sec:
		_open_idle = 0.0
		if host_close_by_npc(global_position):
			_autocloses += 1


## Whether the leaf currently blocks passage (physics state; open/close takes effect next physics step).
func is_blocking() -> bool:
	return not _shape.disabled


## Whether closing the open door now would hit a player body (always false when closed: opening is free).
func is_closing_blocked() -> bool:
	if not is_open:
		return false
	var leaf: RectangleShape2D = _shape.shape as RectangleShape2D
	if leaf == null:
		return false
	var half: Vector2 = leaf.size * 0.5 * _shape.global_scale.abs()
	var center: Vector2 = _shape.global_position
	var angle: float = _shape.global_rotation
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		var body: CollisionObject2D = node as CollisionObject2D
		if body == null or (body.collision_layer & BLOCKER_LAYERS) == 0:
			continue
		var spot: Vector2 = body.global_position
		if body.has_method(&"interaction_position"):
			var latest: Variant = body.call(&"interaction_position")
			if latest is Vector2:
				spot = latest
		if InteractionRules.circle_overlaps_box(spot, _body_radius(body), center, half, angle):
			return true
	return _npc_in_leaf(leaf, center, angle)


## Whether a body on the npcs layer is where the leaf is (physics query; NPC position is host-authoritative).
func _npc_in_leaf(leaf: RectangleShape2D, center: Vector2, angle: float) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = leaf
	query.transform = Transform2D(angle, _shape.global_scale.abs(), 0.0, center)
	query.collision_mask = NPC_LAYERS
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Radius of the body's first circle shape (public physics API: shape owners); 0 (point) if none.
static func _body_radius(body: CollisionObject2D) -> float:
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		for i: int in body.shape_owner_get_shape_count(owner_id):
			var circle: CircleShape2D = body.shape_owner_get_shape(owner_id, i) as CircleShape2D
			if circle != null:
				return circle.radius
	return 0.0


func dump_state() -> Dictionary:
	return {
		"open": is_open,
		"flips": _flips,
		"consistent": is_open == (_start_open != (_flips % 2 == 1)),
		"visible_delay_ms": (_seen_at - changed_at) * 1000.0 if _seen_at >= 0.0 else -1.0,
		"interact": _interactable.stats(),
		"sfx": SfxEmitter.of(self).stats(),
		"autocloses": _autocloses,
	}


## Host only: NPC closes an open door (IS-087 AC2; `actor_pos` NPC position). True if closed; false if already closed,
## NPC out of range, or the leaf would touch a body.
func host_close_by_npc(actor_pos: Vector2) -> bool:
	if not is_open:
		return false
	_npc_closing = true
	var done: bool = _interactable.host_use_by_npc(actor_pos)
	_npc_closing = false
	return done and not is_open


## Host only (Interactable.completed). NPC (peer 0) opens the door; touches an open door only inside host_close_by_npc (US-008 t2, IS-087).
func _on_completed(peer_id: int) -> void:
	if peer_id == 0 and is_open and not _npc_closing:
		return
	changed_at = PropDump.wall_time()
	is_open = not is_open
	var noise: NoiseProfile = NoiseProfile.load_default()
	NoiseBus.emit_noise(global_position, noise.radius_for(NoiseProfile.KIND_DOOR), NoiseProfile.KIND_DOOR, peer_id)


func _set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if not is_node_ready():
		return  # initial value while the scene loads: not counted as a change
	_flips += 1
	_seen_at = PropDump.wall_time()
	_apply(true)
	SfxEmitter.play_on_change(self, &"door_open" if is_open else &"door_close")  # IS-024: local sound


static func _is_host() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0


## `deferred`: during a physics callback or network sync the shape changes at the next idle.
func _apply(deferred: bool) -> void:
	if deferred:
		_shape.set_deferred(&"disabled", is_open)
	else:
		_shape.disabled = is_open
	var alt: String = def.alt_action_key if not def.alt_action_key.is_empty() else def.action_key
	_interactable.action_key = alt if is_open else def.action_key
	_sync_nav_link()


## Writes door state to the level's navigation link (Level.door_link, S4 addendum; duck typing: entities does not know levels/).
func _sync_nav_link() -> void:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"door_link"):
		node = node.get_parent()
	if node == null:
		return
	var link: NavigationLink2D = node.call(&"door_link", StringName(name)) as NavigationLink2D
	if link != null:
		link.enabled = is_open
