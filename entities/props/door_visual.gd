extends Node2D
## Door placeholder visual (US-005): closed = leaf covering the gap, open = thin leaf rotated 90 deg around the hinge. Only reads the
## parent Door's state (KR-003). Colours from the active tone (S9: wood = counter colour). Memory (US-011b AC5; GDD §6.5 item 7): with
## local fog the door updates only while its tile is seen (visible or peripheral); otherwise frozen at the last seen state
## (VisionRules.Latch). Logic and collision unaffected. No fog: live state.

## Leaf length (1 tile) and thickness; hinge at the -x end.
const LENGTH := 32.0
const THICKNESS := 6.0
const OPEN_THICKNESS := 3.0
const OUTLINE_WIDTH := 1.0

var _door: Door = null
var _drawn: Variant = null
var _memory := VisionRules.Latch.new()


func _ready() -> void:
	_door = get_parent() as Door
	if _door == null:
		push_error("DoorVisual: ebeveyn Door değil")
		set_process(false)


func _process(_delta: float) -> void:
	_memory.update(FogView.is_seen(self, _door.global_position), _door.is_open)
	if _drawn != shown_open():
		_drawn = shown_open()
		queue_redraw()


## Drawn state: live while seen, last seen otherwise (live if never seen).
func shown_open() -> bool:
	return bool(_memory.value()) if _memory.has_value() else _door.is_open


func _draw() -> void:
	if _door == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var half: float = LENGTH * 0.5
	var rect: Rect2
	if shown_open():
		# Hinge at the -x end; the open leaf rests against the wall gap edge (frame).
		rect = Rect2(Vector2(-half, -half), Vector2(OPEN_THICKNESS, LENGTH))
	else:
		rect = Rect2(Vector2(-half, -THICKNESS * 0.5), Vector2(LENGTH, THICKNESS))
	draw_rect(rect, tone.level_counter_color)
	draw_rect(rect, tone.level_counter_edge_color, false, OUTLINE_WIDTH)
