extends TestCase
## Job-end session table (US-051): the screen records every result it shows, the header shows the fastest clean getaway, the
## "Session scores" button swaps the body for the table (this job's row on a panel, bests highlighted), a late joiner records
## heist_result(), a level restart (still online) keeps the table and leaving the session (offline) clears it.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const Runs := preload("res://tests/unit/test_session_scores.gd")
const LEVEL_PATH := "res://levels/store_a.tscn"

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var viewport: SubViewport
var hud: Hud
var screen: HeistEnd
var warnings: Array[String] = []


func _open(before_ready: Callable = Callable()) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	net.hosting = true
	var level: Node = autofree(Node.new()) as Node
	level.scene_file_path = LEVEL_PATH
	game.level = level
	if before_ready.is_valid():
		before_ready.call()
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	await _add_hud()


func _add_hud() -> void:
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	viewport.add_child(hud)
	screen = hud.get_node("%HeistEnd") as HeistEnd
	await _settle()


func _settle() -> void:
	for i: int in 3:
		await tree().process_frame


func _rows() -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in screen.get_node("%ScoresTable").get_children():
		out.append(child as Control)
	return out


func _cells(row: Control) -> Array[Label]:
	var out: Array[Label] = []
	for child: Node in row.get_child(0).get_children():
		out.append(child as Label)
	return out


func _play_three_runs() -> void:
	game.heist_finished.emit(Runs.run_result(&"shouted", 38.0, 900, 2, {"1": true}, HeistRules.STRATEGY_NOISE))
	await _settle()
	game.heist_finished.emit(Runs.run_result(&"clean", 55.0, 300, 0, {"1": true}, HeistRules.STRATEGY_BACK_DOOR))
	await _settle()
	game.heist_finished.emit(Runs.run_result(&"caught_all", 20.0, -500, 3, {"1": false}, HeistRules.STRATEGY_COVER))
	await _settle()


func test_table_lists_session_runs_with_current_row_and_bests() -> void:
	await _open()
	await _play_three_runs()
	eq(screen.scores.size(), 3)
	is_false(screen.scores_shown(), "açılışta bu işin ayrıntısı")
	eq((screen.get_node("%BestValue") as Label).text, tr(&"END_BEST_VALUE") % ["0:55", 2], "başlıkta en hızlı temiz")
	var button: Button = screen.get_node("%ScoresButton") as Button
	eq(button.text, tr(&"END_SHOW_SCORES") % 3)
	button.pressed.emit()
	await _settle()
	is_true(screen.scores_shown())
	is_false((screen.get_node("Center/Card/Box/Body") as Control).visible, "gövde gizli")
	is_false((screen.get_node("%NotesBox") as Control).visible, "notlar gizli")
	eq(button.text, tr(&"END_SHOW_RUN"))
	var rows: Array[Control] = _rows()
	eq(rows.size(), 4, "başlık + 3 koşu")
	# Newest first; this job (3) on a panel.
	var current: Array[Label] = _cells(rows[1])
	is_true(rows[1] is PanelContainer and rows[1].theme_type_variation == &"ToastPanel", "bu koşu satırı belirgin")
	is_true(rows[2] is MarginContainer and rows[3] is MarginContainer, "diğer satırlar düz")
	eq(current[0].text, tr(&"END_ROW_CURRENT") % 3)
	eq(current[1].text, tr(&"MAP_STORE_A"), "harita adı seviye yolundan")
	eq(current[2].text, tr(&"END_OUTCOME_CAUGHT_ALL"))
	eq(current[2].theme_type_variation, &"AlertLabel")
	eq(current[4].text, tr(&"END_CLEAN_NO"))
	eq(current[5].theme_type_variation, &"AlertLabel", "eksi kasa uyarı renginde")
	eq(current[6].text, tr(&"END_STRATEGY_ORTU"))
	var clean_run: Array[Label] = _cells(rows[2])
	eq(clean_run[0].text, "2")
	eq(clean_run[3].text, "0:55")
	eq(clean_run[3].theme_type_variation, &"HeadingLabel", "en hızlı temiz vurgulu")
	eq(clean_run[4].text, tr(&"END_CLEAN_YES"))
	var loud_run: Array[Label] = _cells(rows[3])
	eq(loud_run[3].theme_type_variation, &"HeadingLabel", "en hızlı kaçış vurgulu")
	eq(loud_run[4].text, tr(&"END_CLEAN_NO"), "hızlı ama temiz değil: ayrı sütunlar")
	eq(loud_run[5].theme_type_variation, &"CashLabel", "en çok kazanç vurgulu")
	eq(loud_run[5].text, tr(&"END_CASH_GAIN") % (tr(&"HUD_CASH_VALUE") % "900"))
	var summary: String = (screen.get_node("%ScoresBest") as Label).text
	has(summary, tr(&"END_BEST_FASTEST_CLEAN") % (tr(&"END_BEST_VALUE") % ["0:55", 2]))
	has(summary, tr(&"END_BEST_FASTEST") % (tr(&"END_BEST_VALUE") % ["0:38", 1]))
	button.pressed.emit()
	is_false(screen.scores_shown(), "geri: bu iş")
	is_true((screen.get_node("Center/Card/Box/Body") as Control).visible, "gövde geri geldi")
	eq(warnings, [] as Array[String])


func test_no_getaway_yet_shows_dash_and_hint() -> void:
	await _open()
	game.heist_finished.emit(Runs.run_result(&"caught_all", 20.0, -500, 3))
	await _settle()
	eq((screen.get_node("%BestValue") as Label).text, tr(&"END_LOOT_NONE"))
	eq((screen.get_node("%ScoresBest") as Label).text, tr(&"END_BEST_NONE"))


func test_late_joiner_records_existing_result_once() -> void:
	await _open(func() -> void: game.result = Runs.run_result(&"clean", 42.0, 200))
	eq(screen.scores.size(), 1, "geç katılan heist_result()'ı kaydeder")
	is_true(screen.is_open())
	# The same result arriving again (signal after bind) is not a second run.
	game.heist_finished.emit(game.result)
	eq(screen.scores.size(), 1)


func test_restart_keeps_table_and_leaving_clears_it() -> void:
	await _open()
	game.heist_finished.emit(Runs.run_result(&"clean", 42.0, 200))
	await _settle()
	# Level restart: the HUD is freed and re-created with the level while the session is still online.
	hud.queue_free()
	await _settle()
	await _add_hud()
	eq(SessionScores.shared().size(), 1, "yeniden başlatmada tablo kalır")
	game.heist_finished.emit(Runs.run_result(&"hot", 30.0, 100, 3))
	await _settle()
	eq(SessionScores.shared().size(), 2)
	# Menu: leave the session (Net offline), then the level (with the HUD) goes away.
	(screen.get_node("%MenuButton") as Button).pressed.emit()
	hud.queue_free()
	await _settle()
	eq(SessionScores.shared().size(), 0, "oturum bitince tablo sıfırlanır")


func test_unknown_strategy_warns_and_shows_dash() -> void:
	await _open()
	eq(screen.strategy_name("yeni_strateji"), tr(&"END_LOOT_NONE"))
	eq(warnings, ["END_STRATEGY_YENI_STRATEJI"] as Array[String], "geliştiriciye eksik anahtar uyarısı")
	eq(screen.map_name("res://levels/unknown_map.tscn"), "unknown_map", "metni olmayan harita: dosya adı")
	eq(screen.map_name(""), tr(&"END_LOOT_NONE"))
