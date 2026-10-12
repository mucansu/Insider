class_name HeistStartMarker
extends Control
## Job start marker (IS-114, GB-13): during the job's prep phase a ring on the ground at the start point (`Level/HeistStart`, the
## host's spawn slot) with a "START" tag above it, in GAMEPLAY_START, on every peer (clients see where the job starts too). Drawn by
## the HUD's CanvasLayer, so it sits above the vision fog. When the point is off-screen and `arrow_enabled` (host), an edge arrow
## points at it (same pattern as EscapeArrow / TeamMarkers). Gone once the job starts.
## Reads only S3 addendum heist_prep_s() / heist_start_position() from Game; hidden if missing. HUD calls `bind()` and `advance()`.

## World radius of the ring (px): the start point's interaction range (Game HEIST_START_RANGE; ui does not reference the autoload's
## private constants, test_ui_heist_start.gd checks they match).
const RING_WORLD_RADIUS := 48.0
## Smallest on-screen ring radius (px) whatever the camera zoom.
const RING_MIN_RADIUS := 18.0
const RING_WIDTH := 4.0
## Fill opacity inside the ring (the floor still shows through).
const RING_FILL_ALPHA := 0.18
## Gap between the ring and the tag, below/above (px) and beside it (wider: clears the van's yellow zone border, KR-045).
const TAG_GAP := 8.0
const TAG_SIDE_GAP := 32.0
const TAG_OUTLINE := 6
## Arrow length (screen px): same as the escape arrow.
const ARROW_SIZE := 30.0
const DOT_RADIUS := 6.0
const DOT_GAP := 24.0

## World -> screen transform for tests; falls back to the viewport canvas transform if invalid.
var world_to_screen: Callable
## HUD blocks the arrow must not cover (set by HUD).
var avoid: Array[Control] = []
## Edge arrow when the point is off-screen (HUD: host only - the host is the one who has to walk there).
var arrow_enabled: bool = false

var game: Object = null
## Last computed ring {"pos", "radius"} (screen) and arrow {"pos", "angle"}; empty if none.
var _ring: Dictionary = {}
var _arrow: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


static func supports(source: Object) -> bool:
	return source != null and source.has_method(&"heist_prep_s") and source.has_method(&"heist_start_position")


func bind(source: Object) -> void:
	game = source
	visible = supports(game)
	if visible:
		refresh()


func advance(_delta: float) -> void:
	if visible and is_instance_valid(game):
		refresh()


## Last ring ({"pos", "radius"}); empty when not drawn (not in prep, no start point, or wholly off-screen).
func ring() -> Dictionary:
	return _ring


## Last edge arrow ({"pos", "angle"}); empty when not drawn.
func arrow() -> Dictionary:
	return _arrow


## Tag text drawn above the ring.
func tag_text() -> String:
	return tr(&"HUD_START_MARKER")


func refresh() -> void:
	_ring = {}
	_arrow = {}
	var world: Vector2 = game.call(&"heist_start_position")
	if float(game.call(&"heist_prep_s")) >= 0.0 and world.is_finite():
		var at: Vector2 = _to_screen(world)
		var radius: float = maxf((_to_screen(world + Vector2(RING_WORLD_RADIUS, 0.0)) - at).length(), RING_MIN_RADIUS)
		var screen := Rect2(Vector2.ZERO, size)
		if screen.grow(radius).has_point(at):
			_ring = {"pos": at, "radius": radius}
		# Arrow unless the whole ring is on screen (a ring cut by the edge still gets one, so its half-hidden tag is not the only hint).
		if arrow_enabled and not screen.grow(-radius).has_point(at):
			var inner: Rect2 = screen.grow(-TeamMarkers.EDGE_MARGIN)
			var blocks: Array[Rect2] = []
			for c: Control in avoid:
				if is_instance_valid(c) and c.is_visible_in_tree():
					blocks.append(Rect2(c.global_position - global_position, c.size))
			var pos: Vector2 = TeamMarkers.push_clear(TeamMarkers.edge_point(at, inner), inner, blocks,
				ARROW_SIZE / 2.0 + TeamMarkers.ARROW_CLEARANCE)
			_arrow = {"pos": pos, "angle": (at - inner.get_center()).angle()}
	queue_redraw()


func _draw() -> void:
	var outline: Color = ThemeTokens.tone().bg_color
	if not _ring.is_empty():
		var pos: Vector2 = _ring["pos"]
		var radius: float = _ring["radius"]
		var fill: Color = ThemeTokens.GAMEPLAY_START
		fill.a = RING_FILL_ALPHA
		draw_circle(pos, radius, fill)
		draw_arc(pos, radius, 0.0, TAU, 48, outline, RING_WIDTH + TeamMarkers.OUTLINE_WIDTH, true)
		draw_arc(pos, radius, 0.0, TAU, 48, ThemeTokens.GAMEPLAY_START, RING_WIDTH, true)
		var font: Font = get_theme_font(&"font", &"Label")
		var font_size: int = ThemeTokens.tone().font_size_heading
		var text: String = tag_text()
		var tag: Rect2 = tag_rect(pos, radius, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size),
			Rect2(Vector2.ZERO, size))
		var base := Vector2(tag.position.x, tag.position.y + font.get_ascent(font_size))
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TAG_OUTLINE, outline)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeTokens.GAMEPLAY_START)
	if not _arrow.is_empty():
		var pos: Vector2 = _arrow["pos"]
		var dir := Vector2.from_angle(float(_arrow["angle"]))
		var dot: Vector2 = pos - dir * DOT_GAP
		draw_circle(dot, DOT_RADIUS + TeamMarkers.OUTLINE_WIDTH, outline)
		draw_circle(dot, DOT_RADIUS, ThemeTokens.GAMEPLAY_START)
		TeamMarkers.draw_arrow(self, pos, dir, ThemeTokens.GAMEPLAY_START, ARROW_SIZE)


## Screen rect of the "START" tag for a ring at `center`: below the ring (player name tags sit above heads, so above would collide
## with whoever stands in it), else left of it, else right, else above - the first that fits on `screen`.
static func tag_rect(center: Vector2, radius: float, text_size: Vector2, screen: Rect2) -> Rect2:
	var options: Array[Vector2] = [
		Vector2(center.x - text_size.x / 2.0, center.y + radius + TAG_GAP),
		Vector2(center.x - radius - TAG_SIDE_GAP - text_size.x, center.y - text_size.y / 2.0),
		Vector2(center.x + radius + TAG_SIDE_GAP, center.y - text_size.y / 2.0),
		Vector2(center.x - text_size.x / 2.0, center.y - radius - TAG_GAP - text_size.y),
	]
	for at: Vector2 in options:
		var rect := Rect2(at, text_size)
		if screen.encloses(rect):
			return rect
	return Rect2(options[0], text_size)


func _to_screen(world: Vector2) -> Vector2:
	if world_to_screen.is_valid():
		return world_to_screen.call(world)
	return get_viewport().get_canvas_transform() * world
