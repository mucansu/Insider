class_name EscapeArrow
extends Control
## Escape-point edge arrow (US-038 AC2; same pattern as the US-011c team arrow: TeamMarkers.edge_point / push_clear / draw_arrow).
## When alert >= EscapePanel.OBJECTIVE_LEVEL and the point is off-screen, draws an arrow on the screen edge in GAMEPLAY_ESCAPE with a target dot behind it; none when on-screen (world marker: entities/fx/escape_marker.gd).
## Reads only S3 addendum alert_level() / escape_point() from Game; hidden if missing. HUD calls `bind()` and `advance()` per frame.

## Arrow length (screen px): slightly larger than the team arrow (26); GDD §14.1 marker >= 22 px.
const ARROW_SIZE := 30.0
## Radius of the target dot behind the arrow and its offset from the arrow centre (inward).
const DOT_RADIUS := 6.0
const DOT_GAP := 24.0

## World -> screen transform for tests; falls back to the viewport canvas transform if invalid.
var world_to_screen: Callable
## HUD blocks the arrow must not cover (set by HUD).
var avoid: Array[Control] = []

var game: Object = null
## Last computed arrow: {"pos" (screen), "angle" (rad)}; empty if none.
var _marker: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


static func supports(source: Object) -> bool:
	return source != null and source.has_method(&"alert_level") and source.has_method(&"escape_point")


func bind(source: Object) -> void:
	game = source
	visible = supports(game)
	if visible:
		refresh()


func advance(_delta: float) -> void:
	if visible and is_instance_valid(game):
		refresh()


## Last computed arrow ({"pos", "angle"}); empty if none.
func marker() -> Dictionary:
	return _marker


func refresh() -> void:
	_marker = {}
	var world: Vector2 = game.call(&"escape_point")
	if int(game.call(&"alert_level")) >= EscapePanel.OBJECTIVE_LEVEL and world.is_finite():
		var at: Vector2 = _to_screen(world)
		var screen := Rect2(Vector2.ZERO, size)
		if not screen.has_point(at):
			var inner: Rect2 = screen.grow(-TeamMarkers.EDGE_MARGIN)
			var blocks: Array[Rect2] = []
			for c: Control in avoid:
				if is_instance_valid(c) and c.is_visible_in_tree():
					blocks.append(Rect2(c.global_position - global_position, c.size))
			var pos: Vector2 = TeamMarkers.push_clear(TeamMarkers.edge_point(at, inner), inner, blocks,
				ARROW_SIZE / 2.0 + TeamMarkers.ARROW_CLEARANCE)
			_marker = {"pos": pos, "angle": (at - inner.get_center()).angle()}
	queue_redraw()


func _draw() -> void:
	if _marker.is_empty():
		return
	var pos: Vector2 = _marker["pos"]
	var dir := Vector2.from_angle(float(_marker["angle"]))
	var dot: Vector2 = pos - dir * DOT_GAP
	draw_circle(dot, DOT_RADIUS + TeamMarkers.OUTLINE_WIDTH, ThemeTokens.tone().bg_color)
	draw_circle(dot, DOT_RADIUS, ThemeTokens.GAMEPLAY_ESCAPE)
	TeamMarkers.draw_arrow(self, pos, dir, ThemeTokens.GAMEPLAY_ESCAPE, ARROW_SIZE)


func _to_screen(world: Vector2) -> Vector2:
	if world_to_screen.is_valid():
		return world_to_screen.call(world)
	return get_viewport().get_canvas_transform() * world
