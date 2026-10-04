class_name ExposureBadge
extends PanelContainer
## Own exposure badge (US-011c; GDD §6.5), HUD bottom-left: hidden / visible (inside an observer's cone) / seen (an observer's suspicion >= 30).
## Shown three ways: eye shape, colour, text (EyeIcon). Reads only S3 addendum (player_exposure(peer), player_exposure_changed(peer, level)); local peer is Net.local_peer_id().
## Hidden if Game lacks the API (no warning). HUD calls `bind(game, net)`.

const STATE_KEYS: Array[StringName] = [&"HUD_EXPOSURE_HIDDEN", &"HUD_EXPOSURE_VISIBLE", &"HUD_EXPOSURE_SEEN"]
const LABEL_VARIATIONS: Array[StringName] = [&"MutedLabel", &"", &"AlertLabel"]
const POP_SEC := 0.3
const POP_SCALE := 1.3

## Reduced motion (GDD §14.1 rule 5): no pop on escalation, state shows instantly.
var reduce_motion: bool = false

var game: Object = null
var net: Object = null
var _level: int = EyeIcon.HIDDEN
var _pop: Tween = null

@onready var _icon: EyeIcon = %EyeIcon
@onready var _label: Label = %ExposureLabel


func _ready() -> void:
	hide()
	_render()


## Whether Game has the exposure API (S3 addendum).
static func supports(source: Object) -> bool:
	return source != null and source.has_signal(&"player_exposure_changed") and source.has_method(&"player_exposure")


## Binds to Game; hidden if the API is missing.
func bind(source_game: Object, source_net: Object) -> void:
	game = source_game
	net = source_net
	visible = supports(game) and net != null
	if not visible:
		return
	game.connect(&"player_exposure_changed", _on_exposure_changed)
	set_level(int(game.call(&"player_exposure", _local_peer())), false)


func level() -> int:
	return _level


func set_level(value: int, animate: bool = true) -> void:
	var clamped: int = clampi(value, EyeIcon.HIDDEN, EyeIcon.SEEN)
	var raised: bool = clamped > _level
	_level = clamped
	_render()
	if animate and raised and not reduce_motion:
		_play_pop()


## Whether the pop animation is running (for tests and the reduced-motion check).
func is_popping() -> bool:
	return _pop != null and _pop.is_valid() and _pop.is_running()


func _local_peer() -> int:
	return int(net.call(&"local_peer_id"))


func _on_exposure_changed(peer: int, value: int) -> void:
	if peer == _local_peer():
		set_level(value)


func _render() -> void:
	if _icon == null:
		return
	_icon.level = _level
	_label.text = tr(STATE_KEYS[_level])
	_label.theme_type_variation = LABEL_VARIATIONS[_level]


func _play_pop() -> void:
	if is_popping():
		_pop.kill()
	_icon.pivot_offset = _icon.size / 2.0
	_icon.scale = Vector2.ONE
	_pop = create_tween()
	_pop.tween_property(_icon, "scale", Vector2.ONE * POP_SCALE, POP_SEC * 0.4)
	_pop.tween_property(_icon, "scale", Vector2.ONE, POP_SEC * 0.6)
