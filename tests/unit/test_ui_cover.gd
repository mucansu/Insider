extends TestCase
## US-042 cover and witness-check UI: the local cover line on the escape panel (a faded "you look like a customer" / warning-colour
## "your cover is blown"; Game.cover_state, no line when no job), the `cover_broken` session event silent in the HUD, the witness
## line on the end screen (END_STATUS_WITNESS) and the local player's "questioned as a witness" line (a late joiner sees it too),
## new text keys TR + EN.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const NEW_KEYS: Array[String] = ["HUD_COVER_INTACT", "HUD_COVER_BROKEN", "END_STATUS_WITNESS", "END_WITNESS_RELEASED"]

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


static func _result() -> Dictionary:
	return {
		"outcome": &"police",
		"loot_total": 0,
		"payout_ratio": 0.0,
		"payout": 0,
		"duration_s": 80.0,
		"players": {
			"1": {"name": "Ayşe", "slot": 0, "escaped": false, "caught": false, "loot": 0, "bail": 0,
				"witness_released": true, "recognized": 1},
			"2": {"name": "Bora", "slot": 1, "escaped": false, "caught": true, "loot": 0, "bail": 100,
				"witness_released": false, "recognized": 0},
		},
		"notes": [],
		"bail": 100,
		"cash_before": 0,
		"cash_after": -100,
	}


func test_cover_line_rule() -> void:
	eq(EscapePanel.cover_line(-1), [&"", &""] as Array[StringName], "iş yok: satır yok")
	eq(EscapePanel.cover_line(1), [&"HUD_COVER_INTACT", &"MutedLabel"] as Array[StringName])
	eq(EscapePanel.cover_line(0), [&"HUD_COVER_BROKEN", &"AlertLabel"] as Array[StringName])


func test_panel_shows_local_cover() -> void:
	await _open()
	is_false(panel.visible, "iş yok (-1): panel gizli")
	game.cover = 1
	hud.advance(0.1)
	is_true(panel.visible and panel.cover_label().visible, "iş sürerken örtü satırı")
	eq(panel.cover_label().text, tr("HUD_COVER_INTACT"))
	eq(panel.cover_label().get_theme_color(&"font_color"), ThemeTokens.theme().get_color(&"font_color", &"MutedLabel"))
	game.cover = 0
	hud.advance(0.1)
	eq(panel.cover_label().text, tr("HUD_COVER_BROKEN"))
	eq(panel.cover_label().get_theme_color(&"font_color"), ThemeTokens.GAMEPLAY_ALERT, "bozuk: uyarı rengi")
	game.cover = -1
	hud.advance(0.1)
	is_false(panel.visible, "iş bitti: satır gider")
	eq(warnings, [] as Array[String])


func test_cover_event_is_silent_in_hud() -> void:
	has(Hud.SILENT_EVENTS, &"cover_broken", "kaçış panelindeki satır gösterir; bildirim yok")
	await _open()
	game.session_event.emit(&"cover_broken", {"peer": 1, "reason": "staff"})
	await tree().process_frame
	eq((hud.get_node("%Toasts") as Node).get_child_count(), 0, "bildirim kutusu boş")
	eq(warnings, [] as Array[String])


func test_end_screen_witness_rows() -> void:
	await _open(func() -> void: net.my_peer_id = 1)
	game.heist_finished.emit(_result())
	var texts: Array[String] = []
	for child: Node in screen.get_node("%PlayerGrid").get_children():
		if child is Label:
			texts.append((child as Label).text)
	eq(texts[1], tr("END_STATUS_WITNESS"), "tanık satırı")
	var cause: Label = screen.get_node("%CauseNote") as Label
	is_true(cause.visible)
	eq(cause.text, tr("END_WITNESS_RELEASED"), "yerel oyuncuya tanık açıklaması")
	eq(cause.theme_type_variation, &"MutedLabel", "uyarı değil")
	eq(warnings, [] as Array[String])


func test_end_screen_caught_player_keeps_alert_cause() -> void:
	await _open(func() -> void: net.my_peer_id = 2)
	game.heist_finished.emit(_result())
	var cause: Label = screen.get_node("%CauseNote") as Label
	eq(cause.text, tr("END_CAUSE_POLICE"), "yakalanan için yakalanma nedeni")
	eq(cause.theme_type_variation, &"AlertLabel")


func test_late_joiner_sees_witness() -> void:
	await _open(func() -> void:
		net.my_peer_id = 1
		game.result = _result())
	is_true(screen.is_open())
	eq((screen.get_node("%CauseNote") as Label).text, tr("END_WITNESS_RELEASED"))


func test_new_keys_have_tr_and_en() -> void:
	var previous: String = TranslationServer.get_locale()
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in NEW_KEYS:
			ne(TranslationServer.translate(key), key, "%s [%s]" % [key, locale])
	TranslationServer.set_locale(previous)
