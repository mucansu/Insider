class_name NpcVisual
extends Node2D
## NPC placeholder visual (US-008; KR-003, KR-012): circle body + look triangle + faint vision cone + reaction indicator (drawn "?" / "!"
## glyph; ON-04: derived from the replicated meter on a client) + event balloon (`tr()` key, S9) + link to a held player. Only reads the
## parent's state (duck typing): `facing`, `bubble` (CivilianRules.Bubble), `cone_half_angle()`/`cone_range()`, `last_event`/
## `last_event_age`, `held_position()`. Puppet NPC headgear replaces this in US-014. Colours from ThemeTokens (§6 visual exception).
## Visibility gate (US-011b AC5; GDD §6.5; KR-022/023): drawing only - logic, collision and replication unaffected; every peer (host
## included) draws with its own local vision. If the level has the local player's fog (`Level.fog_layer()`, duck typing), each physics
## step: fully visible = fog's `can_see` (visible tile AND line of sight); peripheral = `is_peripheral_at` AND line of sight (directional
## mode). Decision lives in `SightGate` (core): FULL draws everything; SILHOUETTE a faint silhouette (MUTED alpha 0.5; no cone, indicator,
## balloon, hold link); on leaving vision it holds 0.2 s, then a still ghost at the last seen position for 1.5 s (fades over the last 0.3 s;
## no fade under reduced motion), then hidden. Markers (cone, "?"/"!", balloons) only while FULL. Silhouette and ghost draw above fog
## (VisionRules.ABOVE_FOG_Z). Without fog everything is FULL. The dump's `vision.visible_npcs` lists those with `is_fully_visible()`
## (group VisionRules.NPC_VISUAL_GROUP).
## US-016 addition (additive): customer and passerby roles (body colour), civilian/discovery balloons; a civilian overlapping a player is
## drawn translucent (GDD §9.2 "Obstacle": no collision, stay readable).
## IS-087: while the parent's `is_listening()` is true (owner in LISTEN) and there is no indicator, "?" is drawn.
## US-037 (KR-027): in calm (ContactRules.is_calm) the drawing leans `lean_px` away from the nearest overlapping player (this node's
## position; visual and local on every peer - no logic or replication).
## IS-096 (KR-031; GDD §9.3 "Sahip okunurluğu"): cone fill ThemeTokens.GAMEPLAY_CONE_ALPHA; while the local player (fog observer, else
## `Game.local_player()`) stands inside the drawn cone (PerceptionRules.in_cone: range + half angle; FULL already implies line of sight)
## the fill is GAMEPLAY_CONE_WATCHED_ALPHA plus a GAMEPLAY_CONE_EDGE_* outline. Cone only while FULL (`cone_style`).

enum Role { OWNER, CHASER, CUSTOMER, PASSERBY }

const RADIUS := 12.0
const OUTLINE_WIDTH := 1.5
const INDICATOR_LENGTH := 7.0
const INDICATOR_HALF_WIDTH := 5.0
const CONE_SEGMENTS := 12
const GLYPH_OFFSET := Vector2(0.0, -30.0)
const GLYPH_HEIGHT := 12.0
const GLYPH_WIDTH := 3.0
const BALLOON_SEC := 2.5
const BALLOON_OFFSET := Vector2(0.0, -46.0)
const HOLD_RING := 16.0
## Within this distance of a player (px; two body radii) a civilian is translucent, with this opacity.
const OVERLAP_PX := 24.0
const OVERLAP_ALPHA := 0.5
## Widest half angle of the drawn cone (degrees; 180 = full circle, polygon cannot be triangulated).
const MAX_CONE_DEG := 175.0
## US-037: lean smoothing rate (1/s; visual only).
const LEAN_RATE := 18.0
## Event -> balloon text key (i18n/texts.csv).
const BALLOON_KEYS := {
	&"owner_question": "OWNER_QUESTION",
	&"owner_shrug": "OWNER_SHRUG",
	&"owner_shout": "OWNER_SHOUT",
	&"owner_held": "OWNER_HELD",
	&"owner_discover_register": "OWNER_DISCOVER_REGISTER",
	&"owner_discover_cash": "OWNER_DISCOVER_CASH",
	&"owner_serve": "OWNER_SERVE",
	&"owner_talk": "OWNER_TALK",
	&"owner_sent": "OWNER_SENT",
	&"owner_listen": "OWNER_LISTEN",
	&"owner_again": "OWNER_AGAIN",
	&"owner_phone_found": "OWNER_PHONE_FOUND",
	&"owner_loiter": "OWNER_LOITER",
	&"owner_soothe_refused": "OWNER_SOOTHE_REFUSED",
	&"owner_misdirect": "OWNER_MISDIRECT",
	&"owner_question_window": "OWNER_QUESTION_WINDOW",
	&"customer_tell": "CIVILIAN_TELL",
	&"passerby_tell": "CIVILIAN_TELL",
	&"customer_flee": "CIVILIAN_FLEE",
	&"passerby_flee": "CIVILIAN_FLEE",
}

@export var role: Role = Role.OWNER

var _drawn: Array = []
var _gate := SightGate.new()
var _seen_face: Vector2 = Vector2.LEFT
var _contact_params: ContactRules.Params = null


func _ready() -> void:
	add_to_group(VisionRules.NPC_VISUAL_GROUP)


func _physics_process(delta: float) -> void:
	var p: Node2D = get_parent() as Node2D
	if p == null:
		return
	var at: Vector2 = p.global_position
	var full: bool = true
	var peripheral: bool = false
	var fog: Object = FogView.fog_of(self)
	if fog != null:
		full = bool(fog.call(&"can_see", at))
		if not full and bool(fog.call(&"is_peripheral_at", at)):
			peripheral = bool(fog.call(&"line_clear", FogView.observer_of(fog).global_position, at))
	_gate.reduce_motion = Puppet.is_reduced_motion()
	_gate.step(full, peripheral, at, delta)
	if role == Role.CUSTOMER or role == Role.PASSERBY:
		modulate.a = OVERLAP_ALPHA if _overlaps_player(at) else 1.0
	_lean(at, delta)
	if full or peripheral:
		var face_v: Variant = p.get(&"facing")
		if face_v is Vector2 and not (face_v as Vector2).is_zero_approx():
			_seen_face = (face_v as Vector2).normalized()
	z_index = 0 if _gate.is_full() else VisionRules.ABOVE_FOG_Z


## Whether overlapping a player body (civilian translucency; drawing only).
func _overlaps_player(at: Vector2) -> bool:
	for node: Node in get_tree().get_nodes_in_group(PhysicsLayers.ACTORS_GROUP):
		var p: Node2D = node as Node2D
		if p != null and p.global_position.distance_to(at) < OVERLAP_PX:
			return true
	return false


## US-037 calm contact lean: offset toward `lean_offset` of the nearest player (smoothed; instant under reduced motion).
func _lean(at: Vector2, delta: float) -> void:
	if _contact_params == null:
		_contact_params = ContactTuning.load_default().rules_params()
	var target: Vector2 = Vector2.ZERO
	if ContactRules.is_calm(_contact_params, Game.alert_level()):
		var best: float = INF
		for node: Node in get_tree().get_nodes_in_group(PhysicsLayers.ACTORS_GROUP):
			var player: Node2D = node as Node2D
			if player != null and player.global_position.distance_to(at) < best:
				best = player.global_position.distance_to(at)
				target = ContactRules.lean_offset(_contact_params, at, player.global_position)
	if Puppet.is_reduced_motion():
		position = target
	else:
		position = position.lerp(target, 1.0 - exp(-LEAN_RATE * delta))


## Whether fully drawn on this peer (markers included; dump `visible_npcs`).
func is_fully_visible() -> bool:
	return _gate.is_full()


## Draw mode of the visibility gate (SightGate.Mode).
func sight_mode() -> SightGate.Mode:
	return _gate.mode()


func gate() -> SightGate:
	return _gate


func _process(_delta: float) -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var age: Variant = p.get(&"last_event_age")
	var balloon: bool = age is float and float(age) < BALLOON_SEC
	var state: Array = [p.get(&"facing"), p.get(&"bubble"), p.get(&"last_event"), balloon, _held_point(),
		_gate.mode(), _gate.alpha()]
	if _gate.mode() == SightGate.Mode.GHOST:
		state.append(to_local(_gate.ghost_position()))
	if p.has_method(&"cone_half_angle"):
		state.append(p.call(&"cone_half_angle"))
	state.append(_listening(p))
	state.append(_watched(p))
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	var tone: Tone = ThemeTokens.tone()
	match _gate.mode():
		SightGate.Mode.HIDDEN:
			return
		SightGate.Mode.SILHOUETTE:
			_draw_silhouette(Vector2.ZERO, _seen_face.rotated(-global_rotation), tone)
			return
		SightGate.Mode.GHOST:
			_draw_silhouette(to_local(_gate.ghost_position()), _seen_face.rotated(-global_rotation), tone)
			return
	var face_v: Variant = p.get(&"facing")
	var face: Vector2 = (face_v as Vector2).normalized() if face_v is Vector2 and not (face_v as Vector2).is_zero_approx() \
		else Vector2.LEFT
	face = face.rotated(-global_rotation)
	if p.has_method(&"cone_half_angle") and p.has_method(&"cone_range"):
		var style: Vector2 = cone_style(_gate.is_full(), _watched(p))
		_draw_cone(face, float(p.call(&"cone_half_angle")), float(p.call(&"cone_range")), tone.fg_color, style)
	var body: Color = _body_color(tone)
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
	var bubble: int = int(bubble_v) if bubble_v is int else CivilianRules.Bubble.NONE
	match bubble:
		CivilianRules.Bubble.NOTICE:
			_draw_question(tone.fg_color)
		CivilianRules.Bubble.ALARM:
			_draw_exclaim(ThemeTokens.GAMEPLAY_ALERT)
		_:
			if _listening(p):
				_draw_question(tone.fg_color)  # IS-087 AC4: "?" while in LISTEN (GDD §9.3)
	_draw_balloon(p, tone)


func _body_color(tone: Tone) -> Color:
	match role:
		Role.OWNER:
			return tone.accent_color
		Role.CUSTOMER:
			return tone.fg_color.darkened(0.3)
		Role.PASSERBY:
			return tone.line_color
	return ThemeTokens.GAMEPLAY_ALERT.darkened(0.25)


## Faint silhouette (peripheral area and ghost): body + look triangle, MUTED, with the gate's opacity; no markers.
func _draw_silhouette(center: Vector2, face: Vector2, tone: Tone) -> void:
	var color := Color(tone.muted_color, _gate.alpha())
	if color.a <= 0.0:
		return
	draw_circle(center, RADIUS, color)
	var tip: Vector2 = center + face * (RADIUS + INDICATOR_LENGTH)
	var side: Vector2 = face.orthogonal() * INDICATOR_HALF_WIDTH
	draw_colored_polygon(PackedVector2Array([tip, center + face * RADIUS + side, center + face * RADIUS - side]), color)


## Whether the parent is listening to a sound (duck typing `is_listening()`; owner, IS-087 AC4).
static func _listening(p: Node) -> bool:
	return p.has_method(&"is_listening") and bool(p.call(&"is_listening"))


func _held_point() -> Vector2:
	var p: Node = get_parent()
	if p != null and p.has_method(&"held_position"):
		return p.call(&"held_position")
	return Vector2.INF


## IS-096 AC1: cone opacity (x = fill, y = edge line; 0 = not drawn). Only while FULL; calm fill, or the watched fill + edge while the
## local player is inside the cone.
static func cone_style(full: bool, watched: bool) -> Vector2:
	if not full:
		return Vector2.ZERO
	if watched:
		return Vector2(ThemeTokens.GAMEPLAY_CONE_WATCHED_ALPHA, ThemeTokens.GAMEPLAY_CONE_EDGE_ALPHA)
	return Vector2(ThemeTokens.GAMEPLAY_CONE_ALPHA, 0.0)


## Whether `point` is inside the drawn cone of an NPC at `at` facing `face` (same geometry the cone is drawn with).
static func in_drawn_cone(at: Vector2, face: Vector2, half_deg: float, reach: float, point: Vector2) -> bool:
	if half_deg <= 0.0 or reach <= 0.0 or not point.is_finite():
		return false
	return PerceptionRules.in_cone(at, face, minf(half_deg, MAX_CONE_DEG), reach, point)


## Whether the local player stands inside the parent's cone (drawing only; local on every peer).
func _watched(p: Node) -> bool:
	var body: Node2D = p as Node2D
	if body == null or not p.has_method(&"cone_half_angle") or not p.has_method(&"cone_range"):
		return false
	var face_v: Variant = p.get(&"facing")
	if not face_v is Vector2:
		return false
	return in_drawn_cone(body.global_position, face_v as Vector2, float(p.call(&"cone_half_angle")),
		float(p.call(&"cone_range")), _local_player_position())


## Local player's position: the fog observer, else `Game.local_player()`; INF if none (menu, offline test).
func _local_player_position() -> Vector2:
	var fog: Object = FogView.fog_of(self)
	var observer: Node2D = FogView.observer_of(fog) if fog != null else Game.local_player() as Node2D
	return observer.global_position if observer != null else Vector2.INF


func _draw_cone(face: Vector2, half_deg: float, reach: float, color: Color, style: Vector2) -> void:
	if half_deg <= 0.0 or reach <= 0.0 or style.x <= 0.0:
		return
	var points := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(minf(half_deg, MAX_CONE_DEG))  # a full circle cannot be triangulated
	for i: int in CONE_SEGMENTS + 1:
		points.append(face.rotated(-half + 2.0 * half * i / CONE_SEGMENTS) * reach)
	draw_colored_polygon(points, Color(color, style.x))
	if style.y > 0.0:
		points.append(Vector2.ZERO)
		draw_polyline(points, Color(color, style.y), ThemeTokens.GAMEPLAY_CONE_EDGE_WIDTH)


## "!": vertical bar + dot.
func _draw_exclaim(color: Color) -> void:
	var top: Vector2 = GLYPH_OFFSET - Vector2(0.0, GLYPH_HEIGHT * 0.5)
	draw_line(top, GLYPH_OFFSET + Vector2(0.0, GLYPH_HEIGHT * 0.2), color, GLYPH_WIDTH)
	draw_circle(GLYPH_OFFSET + Vector2(0.0, GLYPH_HEIGHT * 0.5), GLYPH_WIDTH * 0.6, color)


## "?": half arc + short stem + dot.
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
