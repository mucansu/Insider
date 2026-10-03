class_name EyeIcon
extends Control
## Exposure eye icon (US-011c; GDD §6.5, §14.1), shared by the HUD badge and the team "seen" marker.
## State is never colour-only: 0 hidden = closed eye (lashed lid), 1 visible = open eye, 2 seen = open eye + three rays. Colours: dim tone colour / tone foreground / GAMEPLAY_ALERT (same in every tone);
## a dark outline (tone background) keeps it readable over the map.

const HIDDEN := 0
const VISIBLE := 1
const SEEN := 2
## Eye width and open-eye height derived from the icon box width.
const EYE_WIDTH := 0.9
const EYE_HEIGHT := 0.5
const PUPIL_RATIO := 0.28
const LINE_RATIO := 0.09
const OUTLINE_EXTRA := 2.0
const ARC_POINTS := 12

## Displayed state (0..2).
var level: int = HIDDEN:
	set(value):
		level = clampi(value, HIDDEN, SEEN)
		queue_redraw()


func _draw() -> void:
	draw_eye(self, size / 2.0, minf(size.x, size.y), level)


## Colour for the state.
static func color_for(value: int) -> Color:
	match value:
		SEEN:
			return ThemeTokens.GAMEPLAY_ALERT
		VISIBLE:
			return ThemeTokens.tone().fg_color
		_:
			return ThemeTokens.tone().muted_color


## Draws the eye centred on `center`, fitting an `extent` px box (outline first, then colour).
static func draw_eye(canvas: CanvasItem, center: Vector2, extent: float, value: int) -> void:
	var outline: Color = ThemeTokens.tone().bg_color
	var color: Color = color_for(value)
	var line: float = maxf(extent * LINE_RATIO, 1.5)
	_draw_shape(canvas, center, extent, value, outline, line + OUTLINE_EXTRA, true)
	_draw_shape(canvas, center, extent, value, color, line, false)


static func _draw_shape(canvas: CanvasItem, center: Vector2, extent: float, value: int, color: Color,
		width: float, is_outline: bool) -> void:
	var w: float = extent * EYE_WIDTH
	var h: float = extent * EYE_HEIGHT
	# When seen, the eye sits lower to leave room for the rays.
	var eye_center: Vector2 = center + Vector2(0.0, extent * 0.12 if value == SEEN else 0.0)
	if value == HIDDEN:
		# Closed lid: downward arc + three lashes.
		var lid: PackedVector2Array = _arc(eye_center, w, h * 0.35, 1.0)
		canvas.draw_polyline(lid, color, width, true)
		for i: int in 3:
			var p: Vector2 = lid[int(round((i + 1) * ARC_POINTS / 4.0))]
			var dir: Vector2 = (p - (eye_center - Vector2(0.0, h * 0.6))).normalized()
			canvas.draw_line(p, p + dir * h * 0.4, color, width, true)
		return
	var outline_pts: PackedVector2Array = _arc(eye_center, w, h, -1.0)
	var lower: PackedVector2Array = _arc(eye_center, w, h, 1.0)
	lower.reverse()
	outline_pts.append_array(lower.slice(1))
	canvas.draw_polyline(outline_pts, color, width, true)
	var pupil: float = extent * PUPIL_RATIO * 0.5
	canvas.draw_circle(eye_center, pupil + (width * 0.5 if is_outline else 0.0), color)
	if value == SEEN:
		var top: Vector2 = eye_center - Vector2(0.0, h * 0.5)
		for i: int in 3:
			var angle: float = -PI / 2.0 + (i - 1) * 0.6
			var dir := Vector2.from_angle(angle)
			canvas.draw_line(top + dir * extent * 0.12, top + dir * extent * 0.3, color, width, true)


## Arc from left corner to right corner; `side` -1 top, +1 bottom (closed lid curves down).
static func _arc(center: Vector2, w: float, h: float, side: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i: int in ARC_POINTS + 1:
		var t: float = float(i) / ARC_POINTS
		out.append(center + Vector2(-w / 2.0 + w * t, side * h / 2.0 * sin(PI * t)))
	return out
