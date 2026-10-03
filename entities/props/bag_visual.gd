class_name BagVisual
extends Node2D
## Bag placeholder visual (US-012): small sack in cash colour (slightly smaller when carried) with a take/handoff progress line below.
## Only reads the parent Bag's state (KR-003). Colours from ThemeTokens (S9; cash colour is GAMEPLAY_CASH in every tone).
## Memory (US-011b AC5; GDD §6.5 item 7): with local fog, bag state updates only while the bag or its last seen spot is seen
## (visible/peripheral tile); otherwise frozen at the last seen state (VisionRules.Latch). Never-seen bags are not drawn. Logic unaffected.
## No fog: live state. Carry (IS-085; KR-017): a carried bag hangs from the carrier's puppet hand (Puppet.hand_points); side, smoothing
## and sway live in BagCarry (node-free). Back-turned carrier: bag behind the puppet, else in front (z = ABOVE_FOG_Z -/+ 1).
## Under reduced motion (Puppet.is_reduced_motion) no sway. Carrier without a puppet: bag at the node position (Bag.CARRY_OFFSET).
## Each peer derives it locally; network and rules unchanged.

const SIZE := Vector2(14.0, 12.0)
const CARRIED_SCALE := 0.8
const NECK := Vector2(6.0, 3.0)
const OUTLINE_WIDTH := 1.5
const BAR_GAP := 4.0
const BAR_HEIGHT := 3.0
## z offset relative to the carrier while carried: front / behind (both above fog).
const CARRY_FRONT_Z := 1
const CARRY_BACK_Z := -1

var _bag: Bag = null
var _drawn: Array = []
var _memory := VisionRules.Latch.new()
var _carry := BagCarry.new()
## Whether the grip was computed this frame (carrier has a puppet).
var _gripped: bool = false


func _ready() -> void:
	_bag = get_parent() as Bag
	if _bag == null:
		push_error("BagVisual: ebeveyn Bag değil")
		set_process(false)


func _process(delta: float) -> void:
	refresh(delta)


## One frame (_process each frame; tests call it directly): fog memory, grip, layer, redraw.
func refresh(delta: float) -> void:
	var live: Array = [_bag.global_position, _bag.is_carried()]
	var seen: bool = FogView.is_seen(self, _bag.global_position)
	if not seen and _memory.has_value() and not bool((_memory.value() as Array)[1]):
		seen = FogView.is_seen(self, (_memory.value() as Array)[0] as Vector2)  # last seen spot is visible
	_memory.update(seen, live)
	_update_carry(delta)
	var at: Vector2 = shown_position()
	z_index = carry_z() if shown_carried() else 0
	var state: Array = [shown_carried(), snappedf(_bag.progress_ratio(), 0.01), to_local(at) if at.is_finite() else at,
		snappedf(_carry.angle, 0.005) if _gripped else 0.0]
	if state != _drawn:
		_drawn = state
		queue_redraw()


## z while carried: in front of or behind the carrier (both above fog).
func carry_z() -> int:
	if not _gripped:
		return VisionRules.ABOVE_FOG_Z
	return VisionRules.ABOVE_FOG_Z + (CARRY_FRONT_Z if _carry.front else CARRY_BACK_Z)


## Grip computation (read/test).
func carry() -> BagCarry:
	return _carry


## Whether the drawn grip is on the puppet hand (carried and carrier has a puppet).
func is_gripped() -> bool:
	return _gripped


## Drawn position (global): last seen spot on the floor, live position when carried; INF if not drawn.
func shown_position() -> Vector2:
	if not _memory.has_value():
		return Vector2.INF
	var memory: Array = _memory.value()
	if bool(memory[1]):
		if not _bag.is_carried():
			return Vector2.INF
		return _grip_world() if _gripped else _bag.global_position
	return memory[0] as Vector2


## Whether the drawn state is carried.
func shown_carried() -> bool:
	return _memory.has_value() and bool((_memory.value() as Array)[1]) and _bag.is_carried()


func _draw() -> void:
	if _bag == null:
		return
	var at: Vector2 = shown_position()
	if not at.is_finite():
		return
	var tone: Tone = ThemeTokens.tone()
	var carried: bool = shown_carried()
	var size: Vector2 = SIZE * (CARRIED_SCALE if carried else 1.0)
	var origin: Vector2 = to_local(at)
	var rect := Rect2(origin - size * 0.5, size)
	if carried and _gripped:
		# Grip point at the sack mouth (neck on top, sack below; the hand holds this area); rotates with the pendulum angle.
		draw_set_transform(origin, _carry.angle)
		rect = Rect2(Vector2(-size.x * 0.5, 0.0), size)
	var neck := Rect2(Vector2(rect.position.x + (rect.size.x - NECK.x) * 0.5, rect.position.y - NECK.y), NECK)
	draw_rect(rect, ThemeTokens.GAMEPLAY_CASH)
	draw_rect(neck, ThemeTokens.GAMEPLAY_CASH)
	draw_rect(rect, tone.bg_color, false, OUTLINE_WIDTH)
	draw_set_transform(Vector2.ZERO)
	var ratio: float = _bag.progress_ratio()
	if ratio > 0.0:
		var below: Vector2 = origin + Vector2(-size.x * 0.5, size.y if carried and _gripped else size.y * 0.5)
		draw_rect(Rect2(below + Vector2(0.0, BAR_GAP), Vector2(size.x * ratio, BAR_HEIGHT)), tone.fg_color)


## Updates the grip from the carrier's puppet; resets if no puppet or not carried (snaps for a new carrier).
func _update_carry(delta: float) -> void:
	_gripped = false
	var actor: Node2D = _bag.carrier_node() if _bag.is_carried() else null
	var puppet: Puppet = _puppet_of(actor)
	if puppet == null or puppet.rig() == null:
		_carry.reset()
		return
	var reduced: bool = Puppet.is_reduced_motion()
	var hands: PackedVector2Array = puppet.hand_points(reduced)
	if hands.size() < 2:
		_carry.reset()
		return
	for i: int in hands.size():
		hands[i] -= actor.global_position
	var rig: PuppetRig = puppet.rig()
	var player: Player = actor as Player
	var velocity: Vector2 = player.velocity if player != null else Vector2.ZERO
	_carry.update(delta, rig.face_direction(), hands, rig.is_back(), velocity, reduced)
	_gripped = _carry.is_built()


func _grip_world() -> Vector2:
	var actor: Node2D = _bag.carrier_node()
	return actor.global_position + _carry.grip if actor != null else _bag.global_position


## Carrier's puppet (Player -> Visual -> Puppet); null if none.
static func _puppet_of(actor: Node2D) -> Puppet:
	if actor == null:
		return null
	var visual: PlayerVisual = actor.get_node_or_null(^"Visual") as PlayerVisual
	return visual.puppet() if visual != null else null
