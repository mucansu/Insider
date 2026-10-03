class_name Puppet
extends Node2D
## Procedural character puppet (US-014; GDD §14.1, KR-017): big head + face (eyes, glint, cheeks), headgear slot, small body, two hands,
## scarf (verlet chain), feet and shadow. Computation is in PuppetRig (node-free); this node only draws. State comes from outside
## (`set_state`): PlayerVisual feeds it for players, NPC visuals later. No logic, input, collision or network (KR-003); never moves itself.
## Drawing: parts collect in a PuppetMesh buffer and go out as one command per puppet (two with run dust) (population: 9+ puppets).
## One draw function per part (`_draw_body`, `_draw_head`, `_draw_headgear`, `_draw_hands` ...); if PuppetLook has a texture for a part
## (`*_texture`) it is drawn into the `part_rect()` frame (eyes stay in code; each texture adds one command).
## Game-info markers (reaction balloon, interaction badge) live in the `Markers` child at a fixed anchor independent of animation
## (GDD §14.1 rule 2). Colours: scarf = given player colour (ThemeTokens.PLAYER_COLORS); shadow, glint and badge from the active tone;
## costume from PuppetLook (S9; costume is S10 cosmetic data).

enum Part { HEAD, HEADGEAR, BODY, HAND }

const TUNING_PATH := "res://data/puppet_tuning.tres"
## Shadow opacity (with the tone's ground colour).
const SHADOW_ALPHA := 0.42
## Highlight curve on top of the body.
const RIM_ALPHA := 0.06
const RIM_WIDTH := 1.0
## Eye glint opacity and eye height ratio when blinking.
const SPARKLE_ALPHA := 0.9
const BLINK_SQUEEZE := 0.12
## Above this eye scale the mouth becomes an "o" (surprise).
const SURPRISED_EYES := 1.2
## Scarf thickness (units): root and per-segment taper; thinnest (px).
const SCARF_WIDTH := 4.4
const SCARF_TAPER := 0.55
const SCARF_MIN_WIDTH := 0.5
## Scarf band wrapped around the neck (units; below the chin): player colour stays visible from every direction (GDD §14.1 rule 4).
const SCARF_WRAP_CENTER := Vector2(0.0, -16.5)
const SCARF_WRAP_RADIUS := Vector2(8.0, 2.6)
## Dust colour opacity and growth.
const DUST_ALPHA := 0.35
const DUST_GROWTH := 1.6
## Screen scale is rounded to this step (zoom oscillation must not shift topology/index cache).
const PIXEL_RATIO_STEP := 0.25
## Dust circle edge point count (fixed: dust is a separate command; the index cache holds even if the count changes).
const DUST_SEGMENTS := 8
## Badge (guard/police) radii (units).
const BODY_BADGE_RADIUS := 1.6
const HAT_BADGE_RADIUS := 1.8

static var _reduced_motion: bool = false

@export var tuning: PuppetTuning = null
@export var look: PuppetLook = null

var _rig: PuppetRig = null
var _mesh: PuppetMesh = PuppetMesh.new()
var _accent: Color = Color.WHITE
var _velocity: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.DOWN
var _gait: PuppetRig.Gait = PuppetRig.Gait.WALK
var _interacting: bool = false
var _look: Vector2 = Vector2.ZERO
## Reaction requested before entering the tree (rig not built); applied in _ready.
var _pending_reaction: PuppetRig.Reaction = PuppetRig.Reaction.NONE
## Command and triangle count of the last draw (measurement/test).
var _stats: Dictionary = {"commands": 0, "textures": 0, "triangles": 0}

@onready var _markers: PuppetMarkers = $Markers


## Reduced motion (settings API; UI wires it later): bob, lean and dust off, balloons stay.
static func set_reduced_motion(on: bool) -> void:
	_reduced_motion = on


static func is_reduced_motion() -> bool:
	return _reduced_motion


## Part frame (units; in body transform). A texture slot is drawn into this frame.
static func part_rect(part: Part, body_width: float = 1.0) -> Rect2:
	match part:
		Part.HEAD:
			var r: float = PuppetBody.HEAD_RADIUS * 1.15
			return Rect2(PuppetBody.HEAD_CENTER - Vector2(r, r), Vector2(r, r) * 2.0)
		Part.HEADGEAR:
			var g: float = PuppetBody.HEAD_RADIUS * 1.6
			return Rect2(PuppetBody.HEAD_CENTER - Vector2(g, g * 1.2), Vector2(g, g) * 2.0)
		Part.BODY:
			var b := Vector2(PuppetBody.BODY_RADIUS.x * body_width, PuppetBody.BODY_RADIUS.y)
			return Rect2(PuppetBody.TORSO_CENTER - b, b * 2.0)
	return Rect2(-Vector2.ONE * PuppetBody.HAND_RADIUS, Vector2.ONE * PuppetBody.HAND_RADIUS * 2.0)


func _ready() -> void:
	if tuning == null:
		push_error("Puppet: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PuppetTuning
	if look == null and not tuning.player_looks.is_empty():
		look = tuning.player_looks[0]
	_rig = PuppetRig.new(tuning, get_instance_id())
	if look != null:
		_rig.set_look(look.width, look.has_scarf)
	if _pending_reaction != PuppetRig.Reaction.NONE:
		_rig.react(_pending_reaction)


func _process(delta: float) -> void:
	_rig.reduced_motion = _reduced_motion
	_rig.target_look = _look
	_rig.update(delta, global_position, _velocity, _facing, _gait, _interacting)
	_markers.update_state(_rig, _interacting, _accent)
	queue_redraw()


## Look and accent (scarf) colour.
func configure(new_look: PuppetLook, accent: Color) -> void:
	look = new_look
	_accent = accent
	if _rig != null and look != null:
		_rig.set_look(look.width, look.has_scarf)
	queue_redraw()


## Observed state (every frame): velocity (px/s), look direction, mode, interaction.
func set_state(velocity: Vector2, facing: Vector2, gait: PuppetRig.Gait, interacting: bool) -> void:
	_velocity = velocity
	_facing = facing
	_gait = gait
	_interacting = interacting


## Look direction of head and eyes (US-011b; world direction). ZERO: head faces the same way as the body (NPCs, old behaviour).
func set_look(direction: Vector2) -> void:
	_look = direction


## Teammate to glance at while idle (world px); none if `active` is false.
func set_friend(world_position: Vector2, active: bool) -> void:
	if _rig == null:
		return
	_rig.friend_position = world_position
	_rig.has_friend = active


## Reaction balloon: QUESTION "?" (suspicion), ALERT "!" (noticed: hop + eye widen), NONE removes it.
func react(kind: PuppetRig.Reaction) -> void:
	if _rig == null:
		_pending_reaction = kind
		return
	_rig.react(kind)


func reaction() -> PuppetRig.Reaction:
	return _rig.reaction if _rig != null else _pending_reaction


func rig() -> PuppetRig:
	return _rig


func accent_color() -> Color:
	return _accent


## Fixed anchor of game-info markers (local px).
func marker_anchor() -> Vector2:
	return Vector2(0.0, -tuning.marker_anchor_height)


## Carry anchors (IS-085): world positions of both hands (px), in PuppetBody.hands order [left, right]. If `rest` is true, the standing hand
## without walk sway or work/sneak pose (reduced motion). Empty if no rig.
func hand_points(rest: bool = false) -> PackedVector2Array:
	var out: PackedVector2Array = []
	if _rig == null:
		return out
	var hands: PackedVector2Array = _rig.hand_offsets() if not rest \
		else PuppetBody.hands(_rig.face_direction(), 0.0, 0.0, _rig.width, false, false, 0.0)
	var to_world: Transform2D = global_transform * _rig.body_transform()
	for hand: Vector2 in hands:
		out.append(to_world * hand)
	return out


## Whether the interaction badge is drawn in the last state.
func shows_interaction() -> bool:
	return _markers.shows_interaction()


func interaction_marker_color() -> Color:
	return _markers.interaction_marker_color()


## Last draw: {"commands": commands sent (buffer + textures), "textures": textures, "triangles": triangles}.
func draw_stats() -> Dictionary:
	return _stats.duplicate()


func _draw() -> void:
	_mesh.begin()
	var screen: Vector2 = get_global_transform_with_canvas().get_scale().abs()
	_mesh.pixel_ratio = snappedf(maxf(0.25, (screen.x + screen.y) * 0.5), PIXEL_RATIO_STEP)
	var textures: int = 0
	if _rig != null and look != null:
		var tone: Tone = ThemeTokens.tone()
		_draw_dust(tone)
		_mesh.transform = _rig.ground_transform()
		_draw_shadow(tone)
		_draw_feet()
		var back: bool = _rig.is_back()
		var head_back: bool = _rig.head_is_back()
		if not back:
			_draw_scarf()
		_mesh.transform = _rig.body_transform()
		if back:
			textures += _draw_hands()
		textures += _draw_body(tone, back)
		if not back:
			textures += _draw_hands()
		textures += _draw_head(head_back)
		if not head_back:
			_draw_face(tone)
		_draw_scarf_wrap()
		textures += _draw_headgear(head_back, tone)
		if back:
			_draw_scarf()
		_mesh.flush(get_canvas_item())
	_stats = {"commands": _mesh.submissions() + textures, "textures": textures, "triangles": _mesh.triangles()}


# --- parts (unit coordinates; transform via _mesh.transform) ---

func _draw_dust(tone: Tone) -> void:
	_mesh.transform = Transform2D.IDENTITY
	for d: PuppetCloth.Dust in _rig.dust_particles():
		var t: float = d.life / d.max_life
		_mesh.circle(to_local(d.position), d.radius * (1.0 + t * DUST_GROWTH), Color(tone.muted_color, DUST_ALPHA * (1.0 - t)),
			DUST_SEGMENTS)
	_mesh.flush(get_canvas_item())


func _draw_shadow(tone: Tone) -> void:
	_mesh.ellipse(Vector2(0.0, 0.5), PuppetBody.SHADOW_RADIUS * Vector2(_rig.width, 1.0) * _rig.shadow_scale(),
		Color(tone.bg_color, SHADOW_ALPHA))


func _draw_feet() -> void:
	for foot: Vector2 in _rig.foot_offsets():
		_mesh.ellipse(foot, PuppetBody.FOOT_RADIUS, look.shoe_color)


func _draw_scarf() -> void:
	var pts: PackedVector2Array = _rig.scarf_draw_points()
	if pts.size() < 2:
		return
	var s: float = tuning.puppet_scale
	var local: PackedVector2Array = []
	var widths: PackedFloat32Array = []
	for i: int in pts.size():
		local.append(to_local(pts[i]))
		widths.append(maxf(SCARF_MIN_WIDTH, (SCARF_WIDTH - i * SCARF_TAPER) * s))
	var keep: Transform2D = _mesh.transform
	_mesh.transform = Transform2D.IDENTITY
	_mesh.ribbon(local, widths, _accent)
	_mesh.circle(local[0], SCARF_WIDTH * s * 0.5, _accent)
	_mesh.transform = keep


func _draw_scarf_wrap() -> void:
	if look.has_scarf:
		_mesh.ellipse(SCARF_WRAP_CENTER, SCARF_WRAP_RADIUS * Vector2(_rig.width, 1.0), _accent)


## Returns 1 if a texture was drawn (command count).
func _draw_body(tone: Tone, back: bool) -> int:
	var used: int = 0
	if look.body_texture != null:
		used = _texture(look.body_texture, part_rect(Part.BODY, _rig.width))
	else:
		var radius := Vector2(PuppetBody.BODY_RADIUS.x * _rig.width, PuppetBody.BODY_RADIUS.y)
		_mesh.ellipse(PuppetBody.TORSO_CENTER, radius, look.coat_color)
		_mesh.stroke(PuppetMesh.arc_points(PuppetBody.TORSO_CENTER, radius, PI * 1.1, PI * 1.9),
			Color(tone.fg_color, RIM_ALPHA), RIM_WIDTH)
	if look.badge and not back:
		var f: Vector2 = _rig.face_direction()
		_mesh.circle(Vector2(-f.y * 3.0 + f.x * 3.0, -15.0), BODY_BADGE_RADIUS, tone.accent_color)
	return used


func _draw_hands() -> int:
	var used: int = 0
	for hand: Vector2 in _rig.hand_offsets():
		if look.hand_texture != null:
			var rect: Rect2 = part_rect(Part.HAND)
			used += _texture(look.hand_texture, Rect2(rect.position + hand, rect.size))
		else:
			_mesh.circle(hand, PuppetBody.HAND_RADIUS, look.skin_color)
	return used


func _draw_head(back: bool) -> int:
	var c: Vector2 = PuppetBody.HEAD_CENTER
	var r: float = PuppetBody.HEAD_RADIUS
	var f: Vector2 = _rig.head_direction()
	if look.head_texture != null:
		return _texture(look.head_texture, part_rect(Part.HEAD))
	if look.gear == PuppetLook.Gear.HOOD:
		_mesh.circle(c, r * 1.13, look.gear_color)
		if back:
			_mesh.fill(PuppetMesh.bezier(c + Vector2(-4.0, -r * 0.95), c + Vector2(0.0, -r * 1.55),
				c + Vector2(4.0, -r * 0.95)), look.gear_color)
		else:
			_mesh.ellipse(c + Vector2(f.x * 1.8, 2.2 + f.y * 0.8), Vector2(r * 0.8, r * 0.76), look.skin_color)
		return 0
	_mesh.circle(c, r, look.hair_color if back else look.skin_color)
	if not back:
		_mesh.ellipse(c + Vector2(-f.x * 1.5, -r * 0.55), Vector2(r * 0.95, r * 0.5), look.hair_color, PI, TAU)
	return 0


func _draw_face(tone: Tone) -> void:
	var c: Vector2 = PuppetBody.HEAD_CENTER
	var f: Vector2 = _rig.head_direction()
	var e: Vector2 = _rig.eye_offset()
	var es: float = _rig.eye_size()
	var squeeze: float = BLINK_SQUEEZE if _rig.is_blinking() else 1.0
	for side: float in [-1.0, 1.0]:
		var far: float = maxf(0.0, -side * f.x)
		var eye := Vector2(c.x + side * 4.3 * (1.0 - far * 0.25) + e.x, c.y + 1.4 + e.y)
		_mesh.ellipse(eye, Vector2(1.8 * es * (1.0 - far * 0.25), 2.55 * es * squeeze), look.eye_color)
		if squeeze > 0.5:
			_mesh.circle(eye + Vector2(0.6, -1.0 * es), 0.65, Color(tone.fg_color, SPARKLE_ALPHA))
		_mesh.ellipse(Vector2(c.x + side * 7.2 + e.x * 0.6, c.y + 5.0 + e.y * 0.5), Vector2(2.3, 1.2), look.blush_color)
	if es > SURPRISED_EYES:
		_mesh.ellipse(Vector2(c.x + e.x * 0.7, c.y + 6.4 + e.y * 0.5), Vector2(1.2, 1.6), look.eye_color)
	else:
		_mesh.stroke(PuppetMesh.arc_points(Vector2(c.x + e.x * 0.7, c.y + 5.4 + e.y * 0.5), Vector2(1.4, 1.4),
			0.2 * PI, 0.8 * PI), look.eye_color, 0.9)


func _draw_headgear(back: bool, tone: Tone) -> int:
	var c: Vector2 = PuppetBody.HEAD_CENTER
	var r: float = PuppetBody.HEAD_RADIUS
	var f: Vector2 = _rig.head_direction()
	if look.headgear_texture != null:
		return _texture(look.headgear_texture, part_rect(Part.HEADGEAR))
	match look.gear:
		PuppetLook.Gear.BEANIE:
			_mesh.ellipse(c + Vector2(0.0, -r * 0.12), Vector2(r, r) * 1.04, look.gear_color, PI, TAU)
			_mesh.rect(Rect2(c.x - r * 1.04, c.y - r * 0.2, r * 2.08, r * 0.28), look.gear_accent_color)
			_mesh.stroke(PuppetMesh.arc_points(c + Vector2(0.0, -r * 0.05), Vector2(r, r) * 1.08, PI * 1.08, PI * 1.92),
				look.gear_dark_color, 2.2)
			for side: float in [-1.0, 1.0]:
				_mesh.ellipse(c + Vector2(side * r * 1.05, 1.0), Vector2(2.4, 3.4), look.gear_dark_color)
			if not back:
				_mesh.stroke(PuppetMesh.bezier(c + Vector2(r * (1.05 if f.x >= 0.0 else -1.05), 2.0),
					c + Vector2(f.x * 6.0, 10.0), c + Vector2(f.x * 3.0 + 2.0, 8.0)), look.gear_dark_color, 1.1)
		PuppetLook.Gear.CAP:
			_mesh.ellipse(c + Vector2(0.0, -r * 0.55), Vector2(r * 0.98, r * 0.52), look.gear_color)
			if not back or absf(f.x) > 0.5:
				_mesh.ellipse(c + Vector2(f.x * r * 0.62, -r * 0.3 + f.y * r * 0.25), Vector2(r * 0.78, r * 0.26),
					look.gear_dark_color)
		PuppetLook.Gear.POLICE:
			_mesh.ellipse(c + Vector2(0.0, -r * 0.66), Vector2(r * 1.04, r * 0.44), look.gear_color)
			_mesh.rect(Rect2(c.x - r * 0.92, c.y - r * 0.62, r * 1.84, r * 0.3), look.gear_dark_color)
			if not back:
				_mesh.ellipse(c + Vector2(f.x * r * 0.5, -r * 0.32 + f.y * r * 0.2), Vector2(r * 0.82, r * 0.24),
					look.gear_dark_color)
				_mesh.circle(c + Vector2(f.x * r * 0.45, -r * 0.62), HAT_BADGE_RADIUS, tone.accent_color)
	return 0


## Texture slot: flushes the buffer (order kept), draws the texture into the part frame with the current transform; returns 1.
func _texture(texture: Texture2D, rect: Rect2) -> int:
	_mesh.flush(get_canvas_item())
	draw_set_transform_matrix(_mesh.transform)
	draw_texture_rect(texture, rect, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	return 1
