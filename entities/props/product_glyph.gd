class_name ProductGlyph
extends RefCounted
## Placeholder drawing of a shop product (US-045 v0; shelf/product art is US-046): a small shape per product id on any CanvasItem, colours
## from the active tone (S9). Visual only: shelf item points, the damacana on the counter and the product in a player's hand use it.

const OUTLINE_WIDTH := 1.0
const LETTER_SIZE := 9
## Product id -> [size (px), colour role (roles: "muted", "accent", "fg"), one-letter mark]; unknown ids draw as a small box, no letter.
## Shapes/colours/letters are distinct per product so a shelf or a hand reads at 1280x720 (US-046 lite); "muted" not "line": LINE is near the floor colour.
const SHAPES := {
	&"bread": [Vector2(16.0, 11.0), "muted", "E"],
	&"cola": [Vector2(9.0, 15.0), "accent", "K"],
	&"water": [Vector2(14.0, 17.0), "fg", "D"],
}
const DEFAULT_SHAPE: Array = [Vector2(8.0, 8.0), "line", ""]


## Size of product `id` (px).
static func size_of(id: StringName) -> Vector2:
	return (SHAPES.get(id, DEFAULT_SHAPE) as Array)[0]


## Letter drawn on product `id` ("" for unknown ids).
static func letter_of(id: StringName) -> String:
	return str((SHAPES.get(id, DEFAULT_SHAPE) as Array)[2])


## Fill colour of product `id` in `tone` (tone colours only, S9).
static func fill_of(id: StringName, tone: Tone) -> Color:
	match str((SHAPES.get(id, DEFAULT_SHAPE) as Array)[1]):
		"accent":
			return tone.accent_color
		"fg":
			return tone.fg_color
		"muted":
			return tone.muted_color
	return tone.line_color


## Draws product `id` centred at `at` (local to `canvas`); `faded` = half alpha (a stock hint or a dimmed mark).
static func draw(canvas: CanvasItem, at: Vector2, id: StringName, faded: bool = false) -> void:
	if canvas == null or id.is_empty():
		return
	var size: Vector2 = size_of(id)
	var tone: Tone = ThemeTokens.tone()
	var fill: Color = fill_of(id, tone)
	if faded:
		fill.a *= 0.5
	var rect := Rect2(at - size * 0.5, size)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, tone.fg_color, false, OUTLINE_WIDTH)
	var letter: String = letter_of(id)
	if letter.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LETTER_SIZE)
	var ink: Color = tone.bg_color
	if faded:
		ink.a *= 0.5
	canvas.draw_string(font, at + Vector2(-text_size.x * 0.5, text_size.y * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1,
			LETTER_SIZE, ink)
