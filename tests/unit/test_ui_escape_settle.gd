extends TestCase
## IS-103 escape settle countdown UI (KR-034): on the escape panel "van leaving… n" (Game.escape_settle_left, rounded up) in the
## escape colour; hidden at -1; never shown together with the retreat row (US-040); new text key TR + EN.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var hud: Hud
var panel: EscapePanel
var warnings: Array[String] = []


func _open() -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	net.hosting = true
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
	for i: int in 3:
		await tree().process_frame


func test_settle_line_rule() -> void:
	eq(EscapePanel.lines(0, -1.0, 2, 2)["settle"], false, "varsayılan: yok")
	eq(EscapePanel.lines(0, -1.0, 2, 2, -1.0, 2.4)["settle"], true, "geri sayım varken satır")
	eq(EscapePanel.lines(0, -1.0, 2, 2, -1.0, 0.0)["settle"], true)
	eq(EscapePanel.lines(0, -1.0, 2, 2, -1.0, -1.0)["settle"], false, "-1: gizli")
	eq(EscapePanel.lines(0, -1.0, 2, 2, 1.5, 2.0)["settle"], false, "eli boş sayacıyla birlikte gösterilmez")
	eq(EscapePanel.lines(0, -1.0, 2, 2, 1.5, 2.0)["abort"], true, "eli boş satırı kazanır")


func test_panel_shows_settle_countdown() -> void:
	await _open()
	is_false(panel.visible)
	game.escape = {"in_zone": 2, "free": 2}
	game.settle = 2.4
	hud.advance(0.1)
	is_true(panel.visible and panel.settle_label().visible, "geri sayım sırasında satır görünür")
	eq(panel.settle_label().text, tr("HUD_ESCAPE_SETTLE") % 3, "yukarı yuvarlanır")
	eq(panel.settle_label().theme_type_variation, &"EscapeLabel")
	eq(panel.settle_label().get_theme_color(&"font_color"), ThemeTokens.GAMEPLAY_ESCAPE, "kaçış token rengi")
	is_false(panel.abort_label().visible)
	game.settle = 0.3
	hud.advance(0.1)
	eq(panel.settle_label().text, tr("HUD_ESCAPE_SETTLE") % 1, "her karede yenilenir")
	game.settle = -1.0
	hud.advance(0.1)
	is_false(panel.settle_label().visible, "-1: satır gider")
	game.settle = 2.0
	game.abort = 2.0
	hud.advance(0.1)
	is_true(panel.abort_label().visible, "eli boş satırı")
	is_false(panel.settle_label().visible, "ikisi birlikte gösterilmez")
	game.abort = -1.0
	game.alert = 3
	game.timer_left = 50.0
	hud.advance(0.1)
	await tree().process_frame
	is_true(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.get_global_rect()), "1280×720 taşma yok")
	is_true(panel.settle_label().get_theme_font_size(&"font_size") >= ThemeTokens.FONT_SIZE_BODY, "≥ 18 px")
	eq(warnings, [] as Array[String])


func test_settle_key_has_tr_and_en() -> void:
	var previous: String = TranslationServer.get_locale()
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		ne(TranslationServer.translate("HUD_ESCAPE_SETTLE"), "HUD_ESCAPE_SETTLE", "anahtar [%s]" % locale)
		eq(TranslationServer.translate("HUD_ESCAPE_SETTLE").count("%d"), 1, "saniye yer tutucusu [%s]" % locale)
	TranslationServer.set_locale(previous)
