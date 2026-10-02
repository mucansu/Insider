class_name NpcVisual
extends Node2D
## NPC yer tutucu görseli (US-008; KR-003, KR-012): daire gövde + bakış üçgeni + soluk görüş konisi + tepki
## göstergesi ("?" / "!" çizilmiş işaret; ON-04: istemcide çoğaltılan ölçerden türetilir) + olay balonu
## (`tr()` anahtarı, S9) + tutulan oyuncuya bağ. Yalnız ebeveynin durumunu okur (duck typing): `facing`,
## `bubble` (CivilianRules.Bubble), `cone_half_angle()`/`cone_range()`, `last_event`/`last_event_age`,
## `held_position()`. Kukla NPC başlıkları US-014'te bunun yerini alır. Renkler ThemeTokens'tan (§6 görsel istisnası).

enum Role { OWNER, CHASER }

const RADIUS := 12.0
const OUTLINE_WIDTH := 1.5
const INDICATOR_LENGTH := 7.0
const INDICATOR_HALF_WIDTH := 5.0
const CONE_ALPHA := 0.07
const CONE_SEGMENTS := 12
const GLYPH_OFFSET := Vector2(0.0, -30.0)
const GLYPH_HEIGHT := 12.0
const GLYPH_WIDTH := 3.0
const BALLOON_SEC := 2.5
const BALLOON_OFFSET := Vector2(0.0, -46.0)
const HOLD_RING := 16.0
## Olay → balon metni anahtarı (i18n/texts.csv).
const BALLOON_KEYS := {
	&"owner_question": "OWNER_QUESTION",
	&"owner_shrug": "OWNER_SHRUG",
	&"owner_shout": "OWNER_SHOUT",
	&"owner_held": "OWNER_HELD",
}

@export var role: Role = Role.OWNER

var _drawn: Array = []


func _process(_delta: float) -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var age: Variant = p.get(&"last_event_age")
	var balloon: bool = age is float and float(age) < BALLOON_SEC
	var state: Array = [p.get(&"facing"), p.get(&"bubble"), p.get(&"last_event"), balloon, _held_point()]
	if p.has_method(&"cone_half_angle"):
		state.append(p.call(&"cone_half_angle"))
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var face_v: Variant = p.get(&"facing")
	var face: Vector2 = (face_v as Vector2).normalized() if face_v is Vector2 and not (face_v as Vector2).is_zero_approx() \
		else Vector2.LEFT
	face = face.rotated(-global_rotation)
	if p.has_method(&"cone_half_angle") and p.has_method(&"cone_range"):
		_draw_cone(face, float(p.call(&"cone_half_angle")), float(p.call(&"cone_range")), tone.fg_color)
	var body: Color = tone.accent_color if role == Role.OWNER else ThemeTokens.GAMEPLAY_ALERT.darkened(0.25)
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, tone.bg_color, OUTLINE_WIDTH)
	var tip: Vector2 = face * (RADIUS + INDICATOR_LENGTH)
	var side: Vector2 = face.orthogonal() * INDICATOR_HALF_WIDTH
	draw_colored_polygon(PackedVector2Array([tip, face * RADIUS + side, face * RADIUS - side]), body)
	var held: Vector2 = _held_point()
	if held.is_finite():
		var local: Vector2 = to_local(held)
		draw_line(Vector2.ZERO, local, ThemeTokens.GAMEPLAY_ALERT, 2.0)
		draw_arc(local, HOLD_RING, 0.0, TAU, 24, ThemeTokens.GAMEPLAY_ALERT, 2.0)
	var bubble_v: Variant = p.get(&"bubble")
	if bubble_v is int:
		match int(bubble_v):
			CivilianRules.Bubble.NOTICE:
				_draw_question(tone.fg_color)
			CivilianRules.Bubble.ALARM:
				_draw_exclaim(ThemeTokens.GAMEPLAY_ALERT)
	_draw_balloon(p, tone)


func _held_point() -> Vector2:
	var p: Node = get_parent()
	if p != null and p.has_method(&"held_position"):
		return p.call(&"held_position")
	return Vector2.INF


func _draw_cone(face: Vector2, half_deg: float, reach: float, color: Color) -> void:
	if half_deg <= 0.0 or reach <= 0.0:
		return
	var points := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(half_deg)
	for i: int in CONE_SEGMENTS + 1:
		points.append(face.rotated(-half + 2.0 * half * i / CONE_SEGMENTS) * reach)
	draw_colored_polygon(points, Color(color, CONE_ALPHA))


## "!": dikey çubuk + nokta.
func _draw_exclaim(color: Color) -> void:
	var top: Vector2 = GLYPH_OFFSET - Vector2(0.0, GLYPH_HEIGHT * 0.5)
	draw_line(top, GLYPH_OFFSET + Vector2(0.0, GLYPH_HEIGHT * 0.2), color, GLYPH_WIDTH)
	draw_circle(GLYPH_OFFSET + Vector2(0.0, GLYPH_HEIGHT * 0.5), GLYPH_WIDTH * 0.6, color)


## "?": yarım yay + kısa sap + nokta.
func _draw_question(color: Color) -> void:
	var r: float = GLYPH_HEIGHT * 0.3
	var center: Vector2 = GLYPH_OFFSET - Vector2(0.0, GLYPH_HEIGHT * 0.25)
	draw_arc(center, r, PI, TAU + PI * 0.5, 10, color, GLYPH_WIDTH * 0.8)
	draw_line(center + Vector2(0.0, r), GLYPH_OFFSET + Vector2(0.0, GLYPH_HEIGHT * 0.2), color, GLYPH_WIDTH * 0.8)
	draw_circle(GLYPH_OFFSET + Vector2(0.0, GLYPH_HEIGHT * 0.5), GLYPH_WIDTH * 0.6, color)


func _draw_balloon(p: Node, tone: Tone) -> void:
	var age: Variant = p.get(&"last_event_age")
	var kind: Variant = p.get(&"last_event")
	if not age is float or float(age) >= BALLOON_SEC or not BALLOON_KEYS.has(kind):
		return
	var font: Font = tone.font if tone.font != null else ThemeDB.fallback_font
	var text: String = tr(str(BALLOON_KEYS[kind]))
	var size: int = tone.font_size_small
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin: Vector2 = BALLOON_OFFSET - Vector2(width * 0.5, 0.0)
	var box := Rect2(origin - Vector2(6.0, size + 2.0), Vector2(width + 12.0, size + 10.0))
	draw_rect(box, tone.raised_color)
	draw_rect(box, tone.line_color, false, 1.0)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tone.fg_color)
