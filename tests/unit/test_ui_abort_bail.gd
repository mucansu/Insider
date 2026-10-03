extends TestCase
## US-040 empty-handed retreat + US-041 bail (KR-029) UI: on the escape panel the retreat countdown line (Game.abort_left), at job end
## an `aborted` title + description (not the loss colour), bail on the caught row, "- Bail" under the payout and the team register
## a -> b line (negative in the warning colour; a late joiner sees it too), HUD team cash in the warning token colour and "-$"
## format when negative, new text keys TR + EN.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const NEW_KEYS: Array[String] = [
	"HUD_ESCAPE_ABORT", "END_OUTCOME_ABORTED", "END_OUTCOME_ABORTED_NOTE",
	"END_BAIL", "END_TEAM_CASH", "END_TEAM_CASH_CHANGE", "END_STATUS_WITH_BAIL",
]

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var hud: Hud
var panel: EscapePanel
var screen: HeistEnd
var warnings: Array[String] = []


func _open(before_ready: Callable = Callable()) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	net.hosting = true
	if before_ready.is_valid():
		before_ready.call()
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	viewport.add_child(hud)
	panel = hud.get_node("%EscapePanel") as EscapePanel
	screen = hud.get_node("%HeistEnd") as HeistEnd
	for i: int in 3:
		await tree().process_frame


static func _result(outcome: StringName) -> Dictionary:
	return {
		"outcome": outcome,
		"loot_total": 0,
		"payout_ratio": 0.0,
		"payout": 0,
		"duration_s": 95.0,
		"players": {
			"1": {"name": "Ayşe", "slot": 0, "escaped": true, "caught": false, "loot": 0, "bail": 0},
			"2": {"name": "Bora", "slot": 1, "escaped": false, "caught": true, "loot": 0, "bail": 100},
		},
		"notes": [],
		"bail": 100,
		"cash_before": 40,
		"cash_after": -60,
	}


func _texts(container: String) -> Array[String]:
	var out: Array[String] = []
	for child: Node in screen.get_node("%" + container).get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


# --- US-040 AC3: countdown line ---

func test_abort_line_rule() -> void:
	eq(EscapePanel.lines(0, -1.0, 2, 2)["abort"], false, "sayaç yok (-1)")
	eq(EscapePanel.lines(0, -1.0, 2, 2, 2.5)["abort"], true, "sayaç varken satır")
	eq(EscapePanel.lines(0, -1.0, 2, 2, 0.0)["abort"], true)
	eq(EscapePanel.abort_seconds(3.0), 3)
	eq(EscapePanel.abort_seconds(2.01), 3, "yukarı yuvarlanır")
	eq(EscapePanel.abort_seconds(0.4), 1)
	eq(EscapePanel.abort_seconds(0.0), 0)


func test_panel_shows_abort_countdown() -> void:
	await _open()
	is_false(panel.visible)
	game.escape = {"in_zone": 2, "free": 2}
	game.abort = 2.4
	hud.advance(0.1)
	is_true(panel.visible and panel.abort_label().visible, "sayaç sırasında satır görünür")
	eq(panel.abort_label().text, tr("HUD_ESCAPE_ABORT") % 3)
	is_true(panel.count_label().visible, "sayım satırı da kalır")
	game.abort = 0.7
	hud.advance(0.1)
	eq(panel.abort_label().text, tr("HUD_ESCAPE_ABORT") % 1, "her karede yenilenir")
	game.abort = -1.0
	hud.advance(0.1)
	is_false(panel.abort_label().visible, "biri çıktı: satır gider")
	game.escape = {"in_zone": 0, "free": 2}
	hud.advance(0.1)
	is_false(panel.visible)
	var screen_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	game.escape = {"in_zone": 2, "free": 2}
	game.abort = 3.0
	game.alert = 3
	game.timer_left = 50.0
	hud.advance(0.1)
	await tree().process_frame
	is_true(screen_rect.encloses(panel.get_global_rect()), "dört satırla 1280×720 taşma yok")
	is_true(panel.abort_label().get_theme_font_size(&"font_size") >= ThemeTokens.FONT_SIZE_BODY, "≥ 18 px")
	eq(warnings, [] as Array[String])


# --- US-040 AC3: job end ---

func test_end_screen_aborted() -> void:
	await _open()
	var r: Dictionary = _result(&"aborted")
	r["players"]["2"] = {"name": "Bora", "slot": 1, "escaped": true, "caught": false, "loot": 0, "bail": 0}
	r["bail"] = 0
	r["cash_after"] = 40
	game.heist_finished.emit(r)
	is_true(screen.is_open())
	eq((screen.get_node("%OutcomeTitle") as Label).text, tr("END_OUTCOME_ABORTED"))
	eq((screen.get_node("%OutcomeTitle") as Label).theme_type_variation, &"TitleLabel", "kayıp rengi değil")
	eq((screen.get_node("%OutcomeNote") as Label).text, tr("END_OUTCOME_ABORTED_NOTE"))
	is_false(_texts("PayoutGrid").has(tr("END_BAIL")), "kefalet yoksa satırı yok")
	has(_texts("PayoutGrid"), tr("END_TEAM_CASH_CHANGE") % [tr("HUD_CASH_VALUE") % "40", tr("HUD_CASH_VALUE") % "40"])
	eq(warnings, [] as Array[String])


# --- US-041 AC6: bail and register ---

func test_end_screen_bail_and_team_cash() -> void:
	await _open(func() -> void: net.my_peer_id = 1)
	game.heist_finished.emit(_result(&"caught_all"))
	var cash: String = tr("HUD_CASH_VALUE")
	eq(_texts("PlayerGrid"), [
		tr("HUD_PLAYER_YOU") % "Ayşe", tr("END_STATUS_ESCAPED"), cash % "0",
		"Bora", tr("END_STATUS_WITH_BAIL") % [tr("END_STATUS_CAUGHT"), cash % "100"], cash % "0",
	] as Array[String], "yakalanan satırında kefalet")
	var payout: Array[String] = _texts("PayoutGrid")
	eq(payout.slice(6), [
		tr("END_BAIL"), "-" + cash % "100",
		tr("END_TEAM_CASH"), tr("END_TEAM_CASH_CHANGE") % [cash % "40", "-" + cash % "60"],
	] as Array[String], "ödeme altında kefalet ve kasa değişimi")
	var grid: Node = screen.get_node("%PayoutGrid")
	eq((grid.get_child(7) as Label).theme_type_variation, &"AlertLabel", "kefalet uyarı renginde")
	eq((grid.get_child(9) as Label).theme_type_variation, &"AlertLabel", "eksi kasa uyarı renginde")
	var r: Dictionary = _result(&"clean")
	r["cash_after"] = 500
	game.heist_finished.emit(r)
	eq(((screen.get_node("%PayoutGrid") as Node).get_child(9) as Label).theme_type_variation, &"CashLabel",
		"artı kasa nakit renginde")
	eq(warnings, [] as Array[String])


func test_late_joiner_sees_bail() -> void:
	await _open(func() -> void: game.result = _result(&"police"))
	is_true(screen.is_open(), "geç katılan heist_result() ile görür")
	has(_texts("PayoutGrid"), tr("END_BAIL"))
	has(_texts("PlayerGrid"), tr("END_STATUS_WITH_BAIL") % [tr("END_STATUS_CAUGHT_POLICE"), tr("HUD_CASH_VALUE") % "100"])


func test_old_result_without_bail_fields() -> void:
	await _open()
	var r: Dictionary = _result(&"clean")
	r.erase("bail")
	r.erase("cash_before")
	r.erase("cash_after")
	var bora: Dictionary = (r["players"] as Dictionary)["2"]
	bora.erase("bail")
	game.heist_finished.emit(r)
	eq(_texts("PayoutGrid").size(), 6, "alanlar yoksa yalnız ganimet/oran/ödeme")


# --- US-041 AC5: HUD team cash ---

func test_hud_negative_cash_in_alert_color() -> void:
	await _open(func() -> void: game.cash = -100)
	var label: Label = hud.get_node("%CashValue") as Label
	eq(label.text, "-" + tr("HUD_CASH_VALUE") % "100", "eksi işaret para biriminin önünde")
	eq(label.theme_type_variation, &"AlertLabel")
	eq(label.get_theme_color(&"font_color"), ThemeTokens.GAMEPLAY_ALERT, "borç uyarı token renginde")
	game.team_cash_changed.emit(35)
	eq(label.text, tr("HUD_CASH_VALUE") % "35")
	eq(label.theme_type_variation, &"CashLabel")
	eq(label.get_theme_color(&"font_color"), ThemeTokens.GAMEPLAY_CASH, "artıda temanın nakit rengi")
	game.team_cash_changed.emit(-1500)
	eq(label.text, "-" + tr("HUD_CASH_VALUE") % ("1" + tr("NUMBER_GROUP_SEPARATOR") + "500"))
	eq(label.get_theme_color(&"font_color"), ThemeTokens.GAMEPLAY_ALERT)


# --- texts ---

func test_new_keys_have_tr_and_en() -> void:
	var previous: String = TranslationServer.get_locale()
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in NEW_KEYS:
			ne(TranslationServer.translate(key), key, "%s [%s]" % [key, locale])
		eq(TranslationServer.translate("HUD_ESCAPE_ABORT").count("%d"), 1, "saniye yer tutucusu [%s]" % locale)
		eq(TranslationServer.translate("END_TEAM_CASH_CHANGE").count("%s"), 2, "a → b [%s]" % locale)
		eq(TranslationServer.translate("END_STATUS_WITH_BAIL").count("%s"), 2, "durum + tutar [%s]" % locale)
	TranslationServer.set_locale(previous)
	has(NEW_KEYS, HeistEnd.OUTCOME_KEY_PREFIX + String(HeistRules.OUTCOME_ABORTED).to_upper(), "sonuç anahtarı listede")
