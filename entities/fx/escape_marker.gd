class_name EscapeMarker
extends Node2D
## World marker for the escape zone (US-038 AC1; GDD §9.3): a separate visual node at the level root; level layout
## is untouched (S4 `Zones/<zone_name>` stays generator-owned; this node is a preserved hand-added node).
## Position and size come from the zone rect (Level API, duck-typed `zone(name)`; no entities -> levels build dependency, §6).
## Ground layer (z 0): translucent fill + hatching + edge, fill pulses (static under reduce_motion); obeys fog rules.
## Sketch layer (`Kroki` child, z = VisionRules.ABOVE_FOG_Z - 1): thin edge + van silhouette, no pulse, above fog so the team-known
## escape point stays visible in fogged areas. Colour: ThemeTokens.GAMEPLAY_ESCAPE (same in every tone).

## Marked zone (Level.zone name).
@export var zone_name: StringName = &"EscapeZone"
## Reduced motion (GDD §14.1 rule 5): no pulse, fill stays static.
var reduce_motion: bool = false

const KROKI_Z := VisionRules.ABOVE_FOG_Z - 1
## Pulse: fill alpha base +/- amplitude, period (s).
const FILL_ALPHA := 0.22
const PULSE_AMPLITUDE := 0.12
const PULSE_PERIOD := 1.6
const EDGE_WIDTH := 3.0
const KROKI_EDGE_WIDTH := 2.0
const HATCH_ALPHA := 0.35
const HATCH_STEP := 16.0
const HATCH_WIDTH := 2.0
## Escape vehicle silhouette: ratio to zone height (body aspect ~2.2).
const VAN_HEIGHT_RATIO := 0.5
const VAN_ASPECT := 2.2
const SILHOUETTE_ALPHA := 0.85

## Zone rect in this node's local space; zero area if the zone is missing.
var rect: Rect2 = Rect2()
var _t: float = 0.0
var _kroki: Node2D = null


func _ready() -> void:
	_kroki = Node2D.new()
	_kroki.name = "Kroki"
	_kroki.z_index = KROKI_Z
	_kroki.z_as_relative = false
	add_child(_kroki)
	_kroki.draw.connect(_draw_kroki)
	rect = read_zone_rect()
	queue_redraw()
	_kroki.queue_redraw()


func _process(delta: float) -> void:
	if is_motion_reduced():
		return
	_t = fmod(_t + delta, PULSE_PERIOD)
	queue_redraw()


func is_motion_reduced() -> bool:
	return reduce_motion or Puppet.is_reduced_motion()


## Fill alpha at `t` seconds (static base under reduced motion).
static func fill_alpha(t: float, reduced: bool) -> float:
	if reduced:
		return FILL_ALPHA
	return FILL_ALPHA + PULSE_AMPLITUDE * sin(TAU * t / PULSE_PERIOD)


## Current fill alpha.
func current_fill_alpha() -> float:
	return fill_alpha(_t, is_motion_reduced())


func kroki() -> Node2D:
	return _kroki


## Zone's first rect shape in this node's space; Rect2() if zone or shape is missing.
func read_zone_rect() -> Rect2:
	var level: Node = get_parent()
	if level == null or not level.has_method(&"zone"):
		return Rect2()
	var zone: Area2D = level.call(&"zone", zone_name) as Area2D
	if zone == null:
		return Rect2()
	for child: Node in zone.get_children():
		var holder: CollisionShape2D = child as CollisionShape2D
		var shape: RectangleShape2D = holder.shape as RectangleShape2D if holder != null else null
		if shape == null:
			continue
		var center: Vector2 = to_local(holder.global_position) if holder.is_inside_tree() and is_inside_tree() \
			else zone.position + holder.position - position
		return Rect2(center - shape.size / 2.0, shape.size)
	return Rect2()


func _draw() -> void:
	if not rect.has_area():
		return
	var color: Color = ThemeTokens.GAMEPLAY_ESCAPE
	draw_rect(rect, Color(color, current_fill_alpha()))
	# Hatching (45 deg), clipped to the rect.
	var hatch := Color(color, HATCH_ALPHA)
	var span: float = rect.size.x + rect.size.y
	var x: float = 0.0
	while x < span:
		var a := Vector2(rect.position.x + x, rect.position.y)
		var b := Vector2(rect.position.x + x - rect.size.y, rect.end.y)
		var clipped: PackedVector2Array = _clip_segment(a, b, rect)
		if clipped.size() == 2:
			draw_line(clipped[0], clipped[1], hatch, HATCH_WIDTH)
		x += HATCH_STEP
	draw_rect(rect, color, false, EDGE_WIDTH)


func _draw_kroki() -> void:
	if not rect.has_area():
		return
	var color: Color = ThemeTokens.GAMEPLAY_ESCAPE
	_kroki.draw_rect(rect.grow(-EDGE_WIDTH), color, false, KROKI_EDGE_WIDTH)
	# Escape vehicle silhouette (placeholder): body, cabin window, two wheels.
	var h: float = rect.size.y * VAN_HEIGHT_RATIO
	var body := Rect2(rect.get_center() - Vector2(h * VAN_ASPECT, h) / 2.0, Vector2(h * VAN_ASPECT, h))
	var ink := Color(color, SILHOUETTE_ALPHA)
	_kroki.draw_rect(body, ink)
	var glass := Rect2(body.end.x - body.size.x * 0.28, body.position.y + h * 0.15, body.size.x * 0.2, h * 0.35)
	_kroki.draw_rect(glass, ThemeTokens.tone().bg_color)
	var wheel_r: float = h * 0.2
	for fx: float in [0.22, 0.78]:
		var c := Vector2(body.position.x + body.size.x * fx, body.end.y)
		_kroki.draw_circle(c, wheel_r + 1.0, ThemeTokens.tone().bg_color)
		_kroki.draw_circle(c, wheel_r, ink)


## Part of segment `a`-`b` inside `r` (Liang-Barsky); empty if outside.
static func _clip_segment(a: Vector2, b: Vector2, r: Rect2) -> PackedVector2Array:
	var d: Vector2 = b - a
	var t0: float = 0.0
	var t1: float = 1.0
	var checks: Array = [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y],
		[d.y, r.end.y - a.y]]
	for pq: Array in checks:
		var p: float = pq[0]
		var q: float = pq[1]
		if is_zero_approx(p):
			if q < 0.0:
				return PackedVector2Array()
			continue
		var t: float = q / p
		if p < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])
