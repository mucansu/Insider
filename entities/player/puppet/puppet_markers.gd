class_name PuppetMarkers
extends Node2D
## Puppet's game-info markers (US-014; GDD §14.1 rule 2): reaction balloon ("?" suspicion, "!" noticed) and interaction badge (IS-014: same on
## every peer while a player interacts). Drawn above the puppet at a fixed anchor (`PuppetTuning.marker_anchor_height`) independent of
## animation, >= 22 px at 1280x720; bob, lean and hop do not move them (except the balloon's own pop/tremble). Glyphs are shapes, not text.
## Colours from the active tone and ThemeTokens.GAMEPLAY_ALERT (S9); badge ring is the player colour. Only draws the state Puppet gives it.

## Balloon and badge position relative to the anchor (px): on both sides of the head, below the name label.
const BUBBLE_OFFSET := Vector2(26.0, 12.0)
const BADGE_OFFSET := Vector2(-26.0, 12.0)
## Balloon box (px): side 28, corner radius 8, tail toward the head.
const BUBBLE_SIZE := 28.0
const BUBBLE_CORNER := 8.0
const BUBBLE_TAIL := [Vector2(-8.0, 12.0), Vector2(-15.0, 21.0), Vector2(0.0, 13.0)]
const GLYPH_WIDTH := 4.0
const GLYPH_DOT := 2.4
## Badge: radius 12 (24 px), ring thickness, inner dots.
const BADGE_RADIUS := 12.0
const BADGE_RING := 2.0
const BADGE_DOT := 1.8
const BADGE_DOT_GAP := 5.0
const CORNER_POINTS := 5

var _reaction: PuppetRig.Reaction = PuppetRig.Reaction.NONE
var _bubble_scale: float = 0.0
var _shake: float = 0.0
var _interacting: bool = false
var _accent: Color = Color.WHITE
var _anchor: Vector2 = Vector2.ZERO


func update_state(rig: PuppetRig, interacting: bool, accent: Color) -> void:
	_reaction = rig.reaction
	_bubble_scale = rig.bubble_scale()
	_shake = rig.bubble_shake()
	_interacting = interacting
	_accent = accent
	_anchor = Vector2(0.0, -rig.tuning.marker_anchor_height)
	queue_redraw()


func shows_interaction() -> bool:
	return _interacting


## Badge fill colour (active tone's ground colour; ring in player colour).
func interaction_marker_color() -> Color:
	return ThemeTokens.tone().bg_color


## Balloon center (local px; tremble excluded) - from the fixed anchor.
func bubble_center() -> Vector2:
	return _anchor + BUBBLE_OFFSET


func badge_center() -> Vector2:
	return _anchor + BADGE_OFFSET


func _draw() -> void:
	var tone: Tone = ThemeTokens.tone()
	if _interacting:
		var c: Vector2 = badge_center()
		draw_circle(c, BADGE_RADIUS, interaction_marker_color(), true, -1.0, true)
		draw_circle(c, BADGE_RADIUS - BADGE_RING * 0.5, _accent, false, BADGE_RING, true)
		for i: int in 3:
			draw_circle(c + Vector2((i - 1) * BADGE_DOT_GAP, 0.0), BADGE_DOT, tone.fg_color, true, -1.0, true)
	if _reaction == PuppetRig.Reaction.NONE or _bubble_scale <= 0.0:
		return
	var alert: bool = _reaction == PuppetRig.Reaction.ALERT
	var fill: Color = ThemeTokens.GAMEPLAY_ALERT if alert else tone.fg_color
	var ink: Color = tone.fg_color if alert else tone.bg_color
	draw_set_transform(bubble_center() + Vector2(_shake, 0.0), 0.0, Vector2.ONE * _bubble_scale)
	var half: float = BUBBLE_SIZE * 0.5
	var box: PackedVector2Array = _rounded_rect(Rect2(-half, -half, BUBBLE_SIZE, BUBBLE_SIZE), BUBBLE_CORNER)
	draw_colored_polygon(box, fill)
	draw_colored_polygon(PackedVector2Array(BUBBLE_TAIL), fill)
	if alert:
		draw_line(Vector2(0.0, -8.0), Vector2(0.0, 2.5), ink, GLYPH_WIDTH, true)
		draw_circle(Vector2(0.0, 7.5), GLYPH_DOT, ink, true, -1.0, true)
	else:
		var hook: PackedVector2Array = []
		for i: int in 13:
			var a: float = deg_to_rad(200.0 + 205.0 * i / 12.0)
			hook.append(Vector2(0.0, -4.5) + Vector2(cos(a), sin(a)) * 5.0)
		hook.append(Vector2(0.0, 1.0))
		hook.append(Vector2(0.0, 3.0))
		draw_polyline(hook, ink, GLYPH_WIDTH * 0.85, true)
		draw_circle(Vector2(0.0, 8.0), GLYPH_DOT, ink, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


static func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var corners: Array[Vector2] = [
		rect.position + Vector2(rect.size.x - radius, radius),
		rect.end - Vector2(radius, radius),
		rect.position + Vector2(radius, rect.size.y - radius),
		rect.position + Vector2(radius, radius),
	]
	for k: int in 4:
		for i: int in CORNER_POINTS:
			var a: float = -PI * 0.5 + PI * 0.5 * (k + float(i) / float(CORNER_POINTS - 1))
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * radius)
	return pts
