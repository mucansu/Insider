class_name EscapePanel
extends PanelContainer
## Escape lines (US-038; GDD §9.3): narrow HUD panel under the alert ladder. Rows: objective (alert >= OBJECTIVE_LEVEL, with the team-together rule),
## police timer (Game.alert_timer_left() >= 0; the HUD then hides the ladder's own small timer, AlertLadder.show_timer),
## count of uncaught players at the escape point (escape colour when all are there; win rule is host-side, HeistRules),
## empty-handed retreat (US-040: Game.abort_left() >= 0, whole seconds rounded up; optional, row absent if Game lacks it; result via heist_finished),
## escape settle countdown (IS-103, KR-034: Game.escape_settle_left() >= 0, "van leaving… n" in the escape colour, whole seconds rounded up;
## optional, never together with the retreat row — retreat wins if both are >= 0),
## cover (US-042: Game.cover_state() >= 0 shows "like a customer" (dim) or "cover blown" (alert colour); optional, -1 hides the row).
## Reads only the S3 addendum from Game (alert_level(), alert_timer_left(), escape_status(), abort_left(), escape_settle_left(), cover_state()); hidden if the first three are missing. HUD calls `bind(game)` and `advance()` per frame.

## Lowest alert tier at which the objective row shows (shop: 2 = shouted).
const OBJECTIVE_LEVEL := 2

var game: Object = null

@onready var _objective: Label = %Objective
@onready var _rule: Label = %Rule
@onready var _police: Label = %Police
@onready var _count: Label = %Count
## Empty-handed retreat row (US-040): built here, not in the scene (below the count row).
var _abort: Label = null
## Escape settle row (IS-103): built here, right after the retreat row.
var _settle: Label = null
## Cover row (US-042): built here (bottom).
var _cover: Label = null


func _ready() -> void:
	_abort = Label.new()
	_abort.name = "Abort"
	_abort.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_abort.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_abort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_abort.visible = false
	_count.get_parent().add_child(_abort)
	_settle = Label.new()
	_settle.name = "Settle"
	_settle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_settle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settle.theme_type_variation = &"EscapeLabel"
	_settle.visible = false
	_count.get_parent().add_child(_settle)
	_cover = Label.new()
	_cover.name = "Cover"
	_cover.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_cover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.visible = false
	_count.get_parent().add_child(_cover)
	hide()


## Whether Game has the S3 addendum members the escape rows need.
static func supports(source: Object) -> bool:
	return source != null and source.has_method(&"alert_level") and source.has_method(&"alert_timer_left") \
		and source.has_method(&"escape_status")


func bind(source: Object) -> void:
	game = source
	if not supports(game):
		hide()
		return
	refresh()


## Called every frame by the HUD; does nothing if Game was freed before the HUD on shutdown.
func advance(_delta: float) -> void:
	if is_instance_valid(game) and supports(game):
		refresh()


## Row visibility: {"objective", "police", "count", "abort", "settle"} (bool). Settle and retreat are exclusive (retreat wins).
static func lines(alert: int, timer_left: float, in_zone: int, free: int, abort_left: float = -1.0,
		settle_left: float = -1.0) -> Dictionary:
	return {
		"objective": alert >= OBJECTIVE_LEVEL,
		"police": timer_left >= 0.0,
		"count": in_zone > 0 and free > 0,
		"abort": abort_left >= 0.0,
		"settle": settle_left >= 0.0 and abort_left < 0.0,
	}


## Cover row (US-042): [text key, theme variation]; empty key when state is -1 (no job).
static func cover_line(state: int) -> Array[StringName]:
	var out: Array[StringName] = [&"", &""]
	if state > 0:
		out = [&"HUD_COVER_INTACT", &"MutedLabel"]
	elif state == 0:
		out = [&"HUD_COVER_BROKEN", &"AlertLabel"]
	return out


## Seconds on the retreat and settle rows: remaining time rounded up (3 -> 2 -> 1; 0 when elapsed).
static func abort_seconds(abort_left: float) -> int:
	return maxi(ceili(abort_left), 0)


func refresh() -> void:
	var left: float = float(game.call(&"alert_timer_left"))
	var status: Dictionary = game.call(&"escape_status")
	var in_zone: int = int(status.get("in_zone", 0))
	var free: int = int(status.get("free", 0))
	var abort_left: float = float(game.call(&"abort_left")) if game.has_method(&"abort_left") else -1.0
	var settle_left: float = float(game.call(&"escape_settle_left")) if game.has_method(&"escape_settle_left") else -1.0
	var show: Dictionary = lines(int(game.call(&"alert_level")), left, in_zone, free, abort_left, settle_left)
	_objective.visible = show["objective"]
	_rule.visible = show["objective"]
	if _objective.visible:
		_objective.text = tr(&"HUD_ESCAPE_OBJECTIVE")
		_rule.text = tr(&"HUD_ESCAPE_RULE")
	_police.visible = show["police"]
	if _police.visible:
		_police.text = tr(&"HUD_ESCAPE_POLICE") % Hud.format_clock(left)
	_count.visible = show["count"]
	if _count.visible:
		_count.text = tr(&"HUD_ESCAPE_COUNT") % [in_zone, free]
		_count.theme_type_variation = &"EscapeLabel" if in_zone >= free else &""
	_abort.visible = show["abort"]
	if _abort.visible:
		_abort.text = tr(&"HUD_ESCAPE_ABORT") % abort_seconds(abort_left)
	_settle.visible = show["settle"]
	if _settle.visible:
		_settle.text = tr(&"HUD_ESCAPE_SETTLE") % abort_seconds(settle_left)
	var cover: Array[StringName] = cover_line(int(game.call(&"cover_state")) if game.has_method(&"cover_state") else -1)
	_cover.visible = not cover[0].is_empty()
	if _cover.visible:
		_cover.text = tr(cover[0])
		_cover.theme_type_variation = cover[1]
	visible = _objective.visible or _police.visible or _count.visible or _abort.visible or _settle.visible or _cover.visible


func objective_label() -> Label:
	return _objective


func police_label() -> Label:
	return _police


func count_label() -> Label:
	return _count


func abort_label() -> Label:
	return _abort


func settle_label() -> Label:
	return _settle


func cover_label() -> Label:
	return _cover
