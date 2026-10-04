class_name AlertLadder
extends PanelContainer
## Alert ladder (US-013; S3 addendum, KR-021): narrow translucent HUD strip, boxes 0-5; current tier and below (present at the venue) are filled (GAMEPLAY_ALERT), absent tiers dim.
## Tier is never colour-only: each box has a "number · name" label (ALERT_T<k>_<level>). Police timer only at TIMER_LEVEL (alert_timer_left >= 0); short pop on change (none under reduced motion).
## Reads only the S3 addendum from Game (alert_level_changed, alert_level(), alert_timer_left(), venue_tier()); hidden if Game lacks it. HUD calls `bind(game)` and `advance()`.

const LEVEL_MAX := 5
## Used when Game has no venue_tier() (single venue in Phase 2: shop T1).
const DEFAULT_TIER := 1
## Tier at which the police timer shows.
const TIMER_LEVEL := 3
## Venue tier (T) -> alert tiers present there (GDD §6.1, S3 addendum); venues not listed have all 0..LEVEL_MAX.
const VENUE_LEVELS := {1: [0, 1, 2, 3, 5]}
const ALERT_KEY_FORMAT := "ALERT_T%d_%d"
## Box size (GDD §14.1: gameplay markers >= 22 px at 1280x720).
const STEP_SIZE := Vector2(22, 22)
## Boxes of tiers absent at the venue are dimmed.
const LOCKED_ALPHA := 0.3
const POP_SEC := 0.3
const POP_SCALE := 1.3
## Sound catalogue events (data/sfx_catalog.tres; IS-024).
const SFX_STEP := &"alert_step"
const SFX_HIGH := &"alert_high"

## Venue tier; `bind` reads Game.venue_tier() (S3 addendum), else DEFAULT_TIER.
var tier: int = DEFAULT_TIER
## Reduced motion (GDD §14.1 rule 5): no pop on tier change, state shows instantly.
var reduce_motion: bool = false
## false: the ladder hides the police timer (US-038: the HUD escape panel shows it large).
var show_timer: bool = true
## Missing-text-key notification (HUD binds; tests catch it); push_warning if unhandled.
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


## Binds to Game (S3 addendum); hidden if the API is missing.
func bind(source: Object) -> void:
	game = source
	var supported: bool = game != null and game.has_signal(&"alert_level_changed") and game.has_method(&"alert_level")
	visible = supported
	if not supported:
		return
	tier = int(game.call(&"venue_tier")) if game.has_method(&"venue_tier") else DEFAULT_TIER
	game.connect(&"alert_level_changed", _on_alert_level_changed)
	set_level(int(game.call(&"alert_level")), false)


## Refreshes the timer (HUD calls it every frame).
func advance(_delta: float) -> void:
	if visible and _level == TIMER_LEVEL:
		refresh_timer()


func level() -> int:
	return _level


## Tiers present at the venue.
func venue_levels() -> Array:
	return VENUE_LEVELS.get(tier, range(LEVEL_MAX + 1))


## Tier name per venue; falls back to generic text + a developer warning if the key is missing.
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
	if animate and changed:
		UiSfx.of(self).play_event(step_event(_level))  # IS-024: sound plays regardless of reduced motion
	if animate and changed and not reduce_motion:
		_play_pop(_steps[_level])


## Sound for a tier change (ses-ve-sfx §2 #12): soft tick for 1-2, short tension hit from TIMER_LEVEL up.
static func step_event(value: int) -> StringName:
	return SFX_HIGH if value >= TIMER_LEVEL else SFX_STEP


## Whether the pop animation is running (for tests and the reduced-motion check).
func is_popping() -> bool:
	return _pop != null and _pop.is_valid() and _pop.is_running()


func refresh_timer() -> void:
	var left: float = -1.0
	if show_timer and _level == TIMER_LEVEL and game != null and game.has_method(&"alert_timer_left"):
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
