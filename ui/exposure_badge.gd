class_name ExposureBadge
extends PanelContainer
## Kendi maruziyet rozeti (US-011c; GDD §6.5): HUD sol alt. Gizli / görünür (bir gözlemcinin konisinde) /
## görüldü (bir gözlemcinin şüphesi ≥ 30). Durum üç yoldan okunur: göz şekli, renk, yazı (EyeIcon).
## Game'den yalnız S3 eki (mimari.md, US-011b/c) üyeleri okunur: player_exposure(peer) -> int, player_exposure_changed(peer, level);
## yerel peer Net.local_peer_id(). Game bunları taşımıyorsa rozet gizli kalır (uyarı yok).
## HUD `bind(game, net)` ile bağlar.

const STATE_KEYS: Array[StringName] = [&"HUD_EXPOSURE_HIDDEN", &"HUD_EXPOSURE_VISIBLE", &"HUD_EXPOSURE_SEEN"]
const LABEL_VARIATIONS: Array[StringName] = [&"MutedLabel", &"", &"AlertLabel"]
const POP_SEC := 0.3
const POP_SCALE := 1.3

## Hareket azaltma (GDD §14.1 kural 5): durum yükselince pop çalmaz, durum anında görünür.
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


## Game'in maruziyet API'si (S3 eki; mimari.md, US-011b/c) var mı.
static func supports(source: Object) -> bool:
	return source != null and source.has_signal(&"player_exposure_changed") and source.has_method(&"player_exposure")


## Game'e bağlanır; API yoksa rozet gizli kalır.
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


## Pop animasyonu sürüyor mu (test ve hareket azaltma denetimi için).
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
