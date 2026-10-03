extends Node2D
## Shelf end placeholder visual (US-010): stacked goods on the shelf end; scattered on the floor when toppled; small phone if left,
## with two arcs beside it while ringing. Only reads the parent ShelfProp's replicated state (KR-003). Colours from ThemeTokens (S9).

const ITEM := Vector2(7.0, 6.0)
const PHONE := Vector2(5.0, 8.0)
const PHONE_OFFSET := Vector2(9.0, -6.0)
const RING_RADII: Array[float] = [5.0, 9.0]
const OUTLINE_WIDTH := 1.0

var _prop: ShelfProp = null
var _drawn: Array = []


func _ready() -> void:
	_prop = get_parent() as ShelfProp
	if _prop == null:
		push_error("ShelfPropVisual: ebeveyn ShelfProp değil")
		set_process(false)


func _process(_delta: float) -> void:
	var state: Array = [_prop.toppled, _prop.phone_state]
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	if _prop == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var items: Array[Vector2] = [Vector2(-4, -3), Vector2(4, -3), Vector2(0, -9)]
	if _prop.toppled:
		items = [Vector2(-10, 6), Vector2(3, 9), Vector2(11, 2)]
	for at: Vector2 in items:
		var rect := Rect2(at - ITEM * 0.5, ITEM)
		draw_rect(rect, tone.line_color)
		draw_rect(rect, tone.bg_color, false, OUTLINE_WIDTH)
	if _prop.has_phone() and _prop.phone_state != CivilianRules.Phone.FOUND:
		var phone := Rect2(PHONE_OFFSET - PHONE * 0.5, PHONE)
		draw_rect(phone, tone.fg_color)
		if _prop.is_ringing():
			for r: float in RING_RADII:
				draw_arc(PHONE_OFFSET, r, -0.6, 0.6, 6, tone.accent_color, OUTLINE_WIDTH)
