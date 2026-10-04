class_name PlayerVisual
extends Node2D
## Player visual (US-004 AC1, US-014): procedural puppet (`Puppet`, KR-017) + name label + interaction badge. Only reads the parent
## Player's state (velocity, facing, mode, interaction, slot, name) and feeds the puppet; no logic, input or network (KR-003). On a remote
## copy Player produces this state from the interpolated buffer; the puppet animates the same way (not from input).
## Mode -> puppet gait mapping lives here (PlayerMotion.Mode -> PuppetRig.Gait); the puppet does not know player scripts.
## Colours: scarf = player colour ThemeTokens.PLAYER_COLORS[slot] (same in every tone), look (hood) per slot from PuppetTuning.player_looks
## (until role/loadout exists), label from the active tone (§6 visual exception, S9). Name label and badges sit at a fixed anchor above the
## puppet, independent of animation (GDD §14.1 rule 2). The label is the player's name: dynamic text, auto-translate off; if empty, the
## same fallback as the HUD, tr("HUD_PLAYER_UNNAMED").
## Vision (US-011b AC4; GDD §6.5, §14.1): puppet head and eyes follow `Player.look_dir` (body follows movement); the teammate is always fully
## drawn above fog (`z_index` = VisionRules.ABOVE_FOG_Z > FogLayer 50); in directional mode (`Player.is_directional_view()`) a thin 32 px /
## 90 deg look arc in the scarf colour (alpha 0.25) surrounds the teammate; no arc on the local player or in 360 deg mode.

const LABEL_WIDTH := 160.0
const LABEL_GAP := 2.0
const LABEL_OUTLINE := 4
## While idle, the puppet may look at the nearest teammate within this distance (px).
const FRIEND_RANGE := 260.0
## Teammate look arc (GDD §6.5): radius, angle, opacity, thickness.
const LOOK_ARC_RADIUS := 32.0
const LOOK_ARC_DEG := 90.0
const LOOK_ARC_ALPHA := 0.25
const LOOK_ARC_WIDTH := 2.0
const LOOK_ARC_SEGMENTS := 12

var _player: Player = null
var _color: Color = Color.WHITE
var _arc_angle: float = INF

@onready var _puppet: Puppet = $Puppet
@onready var _label: Label = $NameLabel


## Puppet equivalent of the player's movement mode.
static func gait_for(mode: int) -> PuppetRig.Gait:
	match mode:
		PlayerMotion.Mode.SNEAK:
			return PuppetRig.Gait.SNEAK
		PlayerMotion.Mode.SPRINT:
			return PuppetRig.Gait.SPRINT
	return PuppetRig.Gait.WALK


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerVisual: ebeveyn Player değil")
		set_process(false)
		return
	z_index = VisionRules.ABOVE_FOG_Z
	var tone: Tone = ThemeTokens.tone()
	if tone.font != null:
		_label.add_theme_font_override(&"font", tone.font)
	_label.add_theme_font_size_override(&"font_size", tone.font_size_small)
	_label.add_theme_color_override(&"font_color", tone.fg_color)
	_label.add_theme_color_override(&"font_outline_color", tone.bg_color)
	_label.add_theme_constant_override(&"outline_size", LABEL_OUTLINE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(LABEL_WIDTH, _label.get_minimum_size().y)
	_label.position = Vector2(-LABEL_WIDTH * 0.5, _puppet.marker_anchor().y - LABEL_GAP - _label.size.y)
	_player.identity_changed.connect(_refresh_identity)
	_refresh_identity()


func _process(_delta: float) -> void:
	_puppet.set_state(_player.velocity, _player.facing, gait_for(_player.move_mode), _player.is_interacting())
	_puppet.set_look(_player.look_dir)
	var arc: float = _player.look_angle() if shows_look_arc() else INF
	if arc != _arc_angle:
		_arc_angle = arc
		queue_redraw()
	var friend: Node2D = _nearest_friend()
	_puppet.set_friend(friend.global_position if friend != null else Vector2.ZERO, friend != null)


## Reaction balloon and reaction (e.g. "!" when the player is noticed: hop + eye widen); NPCs use the same API
## (Puppet.react).
func react(kind: PuppetRig.Reaction) -> void:
	_puppet.react(kind)


func puppet() -> Puppet:
	return _puppet


## Whether the look arc is drawn: teammate (not local) and directional vision mode.
func shows_look_arc() -> bool:
	return _player != null and not _player.is_local() and _player.is_directional_view()


func _draw() -> void:
	if not is_finite(_arc_angle):
		return
	var half: float = deg_to_rad(LOOK_ARC_DEG) * 0.5
	draw_arc(Vector2.ZERO, LOOK_ARC_RADIUS, _arc_angle - half, _arc_angle + half, LOOK_ARC_SEGMENTS,
		Color(_color, LOOK_ARC_ALPHA), LOOK_ARC_WIDTH, true)


## Whether the interaction indicator (badge above the puppet) exists in the last drawn state; same path for local and remote players
## (Player.is_interacting()).
func shows_interaction() -> bool:
	return _puppet.shows_interaction()


## Fill colour of the interaction badge (from the active tone; S9).
func interaction_marker_color() -> Color:
	return _puppet.interaction_marker_color()


## Player colour used for drawing (scarf and badge ring).
func body_color() -> Color:
	return _color


## Text on the name label.
func label_text() -> String:
	return _label.text


## Colour, look and name from the Player's slot/name info (Game.players(), S3).
func _refresh_identity() -> void:
	var colors: Array[Color] = ThemeTokens.PLAYER_COLORS
	_color = colors[posmod(_player.slot(), colors.size())]
	var looks: Array[PuppetLook] = _puppet.tuning.player_looks
	var look: PuppetLook = looks[posmod(_player.slot(), looks.size())] if not looks.is_empty() else null
	_puppet.configure(look, _color)
	var player_name: String = _player.display_name()
	if player_name.is_empty():
		player_name = tr(&"HUD_PLAYER_UNNAMED") % _player.peer_id()
	_label.text = player_name
	queue_redraw()


## Nearest sibling player copy (within FRIEND_RANGE); only position is read.
func _nearest_friend() -> Node2D:
	var root: Node = _player.get_parent()
	if root == null:
		return null
	var best: Node2D = null
	var best_d: float = FRIEND_RANGE * FRIEND_RANGE
	for child: Node in root.get_children():
		var other: Player = child as Player
		if other == null or other == _player:
			continue
		var d: float = other.global_position.distance_squared_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best
