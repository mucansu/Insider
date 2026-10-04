class_name ProductGlyph
extends RefCounted
## Placeholder drawing of a shop product (US-045 v0; shelf/product art is US-046): a small shape per product id on any CanvasItem, colours
## from the active tone (S9). Visual only: shelf item points, the damacana on the counter and the product in a player's hand use it.

const OUTLINE_WIDTH := 1.0
## Product id -> [size (px), colour role] (roles: "line", "accent", "fg"); unknown ids draw as a small box.
const SHAPES := {
	&"bread": [Vector2(10.0, 5.0), "line"],
	&"cola": [Vector2(4.0, 9.0), "accent"],
	&"water": [Vector2(9.0, 12.0), "fg"],
}
const DEFAULT_SHAPE: Array = [Vector2(6.0, 6.0), "line"]


## Draws product `id` centred at `at` (local to `canvas`); `faded` = shelf stock hint (half alpha).
static func draw(canvas: CanvasItem, at: Vector2, id: StringName, faded: bool = false) -> void:
	if canvas == null or id.is_empty():
		return
	var shape: Array = SHAPES.get(id, DEFAULT_SHAPE) as Array
	var size: Vector2 = shape[0]
	var tone: Tone = ThemeTokens.tone()
	var fill: Color = tone.line_color
	match str(shape[1]):
		"accent":
			fill = tone.accent_color
		"fg":
			fill = tone.fg_color
	if faded:
		fill.a *= 0.5
	var rect := Rect2(at - size * 0.5, size)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, tone.bg_color, false, OUTLINE_WIDTH)
