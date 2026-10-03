class_name EscapePanel
extends PanelContainer
## Kaçış satırları (US-038; GDD §9.3): HUD üst ortası, uyarı merdiveninin altında dar panel.
## - Hedef: uyarı ≥ OBJECTIVE_LEVEL iken "Kaçış noktasına git" + kural ("ekip birlikte oradayken kaçarsınız").
## - Polis sayacı: Game.alert_timer_left() ≥ 0 iken (mahalleli içeride → 60 sn) "Polis gelmesine: d:ss". HUD bu
##   panel varken merdivenin kendi küçük sayacını kapatır (AlertLadder.show_timer).
## - Sayım: bölgede yakalanmamış biri varken "Kaçış noktasında: n/m" (m = yakalanmamış oyuncu); hepsi oradaysa
##   kaçış renginde. Kazanma kuralı (herkes aynı anda bölgede, ganimet > 0) host'ta, HeistRules.
## - Eli boş çekilme (US-040): Game.abort_left() ≥ 0 iken "Eli boş çekiliyorsunuz… n" (n = kalan tam saniye,
##   yukarı yuvarlanır). İsteğe bağlı üye: Game taşımıyorsa satır hiç görünmez. Karar host'ta; sonuç heist_finished.
## Game'den yalnız S3 eki okunur: alert_level(), alert_timer_left(), escape_status() (US-038 adayı), abort_left()
## (US-040). Game ilk üçünü taşımıyorsa panel gizli kalır. HUD `bind(game)` ile bağlar, her karede `advance()`.

## Hedef satırının göründüğü en düşük uyarı kademesi (bakkal: 2 = bağırdı).
const OBJECTIVE_LEVEL := 2

var game: Object = null

@onready var _objective: Label = %Objective
@onready var _rule: Label = %Rule
@onready var _police: Label = %Police
@onready var _count: Label = %Count
## Eli boş çekilme satırı (US-040): sahnede değil, burada kurulur (sayım satırının altında).
var _abort: Label = null


func _ready() -> void:
	_abort = Label.new()
	_abort.name = "Abort"
	_abort.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_abort.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_abort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_abort.visible = false
	_count.get_parent().add_child(_abort)
	hide()


## Game kaçış satırları için gereken S3 eki üyelerini taşıyor mu.
static func supports(source: Object) -> bool:
	return source != null and source.has_method(&"alert_level") and source.has_method(&"alert_timer_left") \
		and source.has_method(&"escape_status")


func bind(source: Object) -> void:
	game = source
	if not supports(game):
		hide()
		return
	refresh()


## Her karede (HUD çağırır); Game kapanışta HUD'dan önce serbest kalırsa işlem yapılmaz.
func advance(_delta: float) -> void:
	if is_instance_valid(game) and supports(game):
		refresh()


## Satırların görünürlüğü: {"objective", "police", "count", "abort"} (bool).
static func lines(alert: int, timer_left: float, in_zone: int, free: int, abort_left: float = -1.0) -> Dictionary:
	return {
		"objective": alert >= OBJECTIVE_LEVEL,
		"police": timer_left >= 0.0,
		"count": in_zone > 0 and free > 0,
		"abort": abort_left >= 0.0,
	}


## Eli boş çekilme satırındaki saniye: kalan süre yukarı yuvarlanır (3 → 2 → 1; dolunca 0).
static func abort_seconds(abort_left: float) -> int:
	return maxi(ceili(abort_left), 0)


func refresh() -> void:
	var left: float = float(game.call(&"alert_timer_left"))
	var status: Dictionary = game.call(&"escape_status")
	var in_zone: int = int(status.get("in_zone", 0))
	var free: int = int(status.get("free", 0))
	var abort_left: float = float(game.call(&"abort_left")) if game.has_method(&"abort_left") else -1.0
	var show: Dictionary = lines(int(game.call(&"alert_level")), left, in_zone, free, abort_left)
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
	visible = _objective.visible or _police.visible or _count.visible or _abort.visible


func objective_label() -> Label:
	return _objective


func police_label() -> Label:
	return _police


func count_label() -> Label:
	return _count


func abort_label() -> Label:
	return _abort
