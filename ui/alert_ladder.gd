class_name AlertLadder
extends PanelContainer
## Uyarı merdiveni (US-013; S3 eki, KR-021; okunabilirlik-2d §5): HUD üst ortası, dar ve yarı saydam
## (haritayı az örter). Kademe kutuları 0-5; mevcut kademe ve altındaki (mekânda olan) kutular dolu
## (GAMEPLAY_ALERT), mekânda olmayan kademe silik. Kademe yalnız renkle verilmez: kutuların yanında
## "sayı · ad" yazılı (ALERT_T<k>_<seviye>). Polis sayacı
## yalnız TIMER_LEVEL'da (alert_timer_left ≥ 0 iken). Kademe değişiminde kısa pop (hareket azaltmada yok).
## Game'den yalnız S3 eki okunur: alert_level_changed, alert_level(), alert_timer_left(), venue_tier(). Game bu API'yi
## taşımıyorsa merdiven gizli kalır. HUD `bind(game)` ile bağlar, `advance()` ile sayacı yeniler.

const LEVEL_MAX := 5
## Game venue_tier() vermiyorsa (Faz 2'de tek mekân: bakkal T1).
const DEFAULT_TIER := 1
## Polis sayacının göründüğü kademe (bakkal: mahalle geldi).
const TIMER_LEVEL := 3
## Mekân kademesi (T) -> o mekânda var olan uyarı kademeleri (GDD §6.1, S3 eki; bakkalda 4 yok).
## Listede olmayan mekânda 0..LEVEL_MAX hepsi vardır.
const VENUE_LEVELS := {1: [0, 1, 2, 3, 5]}
const ALERT_KEY_FORMAT := "ALERT_T%d_%d"
## Kutu boyutu (GDD §14.1: oyun bilgisi işaretleri 1280×720'de ≥ 22 px).
const STEP_SIZE := Vector2(22, 22)
## Mekânda olmayan kademenin kutusu silik.
const LOCKED_ALPHA := 0.3
const POP_SEC := 0.3
const POP_SCALE := 1.3

## Mekân kademesi; `bind` Game.venue_tier()'den okur (S3 eki), Game vermiyorsa DEFAULT_TIER.
var tier: int = DEFAULT_TIER
## Hareket azaltma (GDD §14.1 kural 5): kademe değişiminde pop çalmaz, durum anında görünür.
var reduce_motion: bool = false
## Eksik metin anahtarı bildirimi (HUD bağlar; testler yakalar). Geçersizse push_warning.
var warn: Callable

var game: Object = null
var _level: int = 0
var _pop: Tween = null
var _steps: Array[PanelContainer] = []

@onready var _steps_box: HBoxContainer = %Steps
@onready var _level_label: Label = %LevelLabel
@onready var _timer_label: Label = %TimerLabel


func _ready() -> void:
	for i: int in LEVEL_MAX + 1:
		var step := PanelContainer.new()
		step.name = "Step%d" % i
		step.custom_minimum_size = STEP_SIZE
		step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_steps_box.add_child(step)
		_steps.append(step)
	hide()
	_render()


## Game'e (S3 eki) bağlanır; API yoksa merdiven gizli kalır.
func bind(source: Object) -> void:
	game = source
	var supported: bool = game != null and game.has_signal(&"alert_level_changed") and game.has_method(&"alert_level")
	visible = supported
	if not supported:
		return
	tier = int(game.call(&"venue_tier")) if game.has_method(&"venue_tier") else DEFAULT_TIER
	game.connect(&"alert_level_changed", _on_alert_level_changed)
	set_level(int(game.call(&"alert_level")), false)


## Sayacı yeniler (HUD her karede çağırır).
func advance(_delta: float) -> void:
	if visible and _level == TIMER_LEVEL:
		refresh_timer()


func level() -> int:
	return _level


## Mekânda var olan kademeler.
func venue_levels() -> Array:
	return VENUE_LEVELS.get(tier, range(LEVEL_MAX + 1))


## Kademenin mekâna göre adı; anahtar yoksa genel metin + geliştirici uyarısı.
func level_name(value: int) -> String:
	var key: String = ALERT_KEY_FORMAT % [tier, value]
	var text: String = tr(key)
	if text == key:
		_warn(key)
		return tr(&"ALERT_GENERIC")
	return text


func set_level(value: int, animate: bool = true) -> void:
	var clamped: int = clampi(value, 0, LEVEL_MAX)
	var changed: bool = clamped != _level
	_level = clamped
	_render()
	if animate and changed and not reduce_motion:
		_play_pop(_steps[_level])


## Pop animasyonu sürüyor mu (test ve hareket azaltma denetimi için).
func is_popping() -> bool:
	return _pop != null and _pop.is_valid() and _pop.is_running()


func refresh_timer() -> void:
	var left: float = -1.0
	if _level == TIMER_LEVEL and game != null and game.has_method(&"alert_timer_left"):
		left = float(game.call(&"alert_timer_left"))
	_timer_label.visible = left >= 0.0
	if left >= 0.0:
		_timer_label.text = tr(&"HUD_ALERT_TIMER") % Hud.format_clock(left)


func _on_alert_level_changed(value: int) -> void:
	set_level(value)


func _render() -> void:
	if _steps.is_empty():
		return
	var venue: Array = venue_levels()
	for i: int in _steps.size():
		var step: PanelContainer = _steps[i]
		var filled: bool = i <= _level and venue.has(i)
		step.theme_type_variation = &"LadderStepActive" if filled else &"LadderStep"
		step.modulate.a = 1.0 if venue.has(i) else LOCKED_ALPHA
	_level_label.text = tr(&"HUD_ALERT_LEVEL") % [_level, level_name(_level)]
	_level_label.theme_type_variation = &"AlertLabel" if _level > 0 else &""
	refresh_timer()


func _play_pop(step: Control) -> void:
	if is_popping():
		_pop.kill()
	for s: Control in _steps:
		s.scale = Vector2.ONE
	step.pivot_offset = step.size / 2.0
	_pop = create_tween()
	_pop.tween_property(step, "scale", Vector2.ONE * POP_SCALE, POP_SEC * 0.4)
	_pop.tween_property(step, "scale", Vector2.ONE, POP_SEC * 0.6)


func _warn(key: String) -> void:
	if warn.is_valid():
		warn.call(key)
	else:
		push_warning("AlertLadder: metin anahtarı yok: %s (i18n/texts.csv)" % key)
