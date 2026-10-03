extends TestCase
## Job-end screen (US-013 minimum 2a; S3 addition heist_finished/heist_result, KR-021): with the fake Game's result, the title,
## time, payout rows, player rows, notes (generic text + warning on a missing key), late joining, host/client buttons, gamepad/
## keyboard focus order, the "again" signal and the "Menu" exit.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var journal: Fakes.CallLog
var viewport: SubViewport
var hud: Hud
var screen: HeistEnd
var menu_requests: Array[StringName] = []
var warnings: Array[String] = []


static func sample_result() -> Dictionary:
	return {
		"outcome": &"shouted",
		"loot_total": 1250,
		"payout_ratio": 0.85,
		"payout": 1063,
		"duration_s": 221.4,
		"players": {
			"7": {"name": "Cem", "slot": 2, "escaped": false, "caught": true, "loot": 0},
			"1": {"name": "Ayşe", "slot": 0, "escaped": true, "caught": false, "loot": 900},
			"2": {"name": "", "slot": 1, "escaped": true, "caught": false, "loot": 350},
		},
		"notes": [
			{"kind": &"owner_favourite", "peer": 2},
			{"kind": &"slipper", "peer": 7},
			{"kind": &"ghost_crew", "peer": 0},
		],
	}


func _open(before_ready: Callable = Callable(), game_override: Node = null) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	journal = pair[2]
	net.hosting = true
	if before_ready.is_valid():
		before_ready.call()
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game if game_override == null else game_override
	hud.menu_override = func(error_key: StringName) -> void: menu_requests.append(error_key)
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	viewport.add_child(hud)
	screen = hud.get_node("%HeistEnd") as HeistEnd
	await _settle()


func _settle() -> void:
	for i: int in 3:
		await tree().process_frame


func _texts(container: String) -> Array[String]:
	var out: Array[String] = []
	for child: Node in screen.get_node("%" + container).get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


func _label(unique_name: String) -> Label:
	return screen.get_node("%" + unique_name) as Label


func _focused() -> String:
	var owner: Control = viewport.gui_get_focus_owner()
	return "" if owner == null else str(owner.name)


func _push_joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		viewport.push_input(e)


func _push_key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.shift_pressed = shift
		e.pressed = pressed
		viewport.push_input(e)


func test_closed_until_heist_finished() -> void:
	await _open()
	is_false(screen.is_open(), "iş bitmeden ekran kapalı")
	is_false(UiInput.is_gameplay_input_blocked())


func test_heist_finished_fills_fields() -> void:
	await _open(func() -> void: net.my_peer_id = 2)
	game.heist_finished.emit(sample_result())
	is_true(screen.is_open(), "heist_finished ekranı açar")
	is_true(UiInput.is_gameplay_input_blocked(), "açıkken oyun girdisi engelli (S5)")
	eq(_label("OutcomeTitle").text, tr("END_OUTCOME_SHOUTED"))
	eq(_label("OutcomeTitle").theme_type_variation, &"TitleLabel", "kazanma başlığı uyarı renginde değil")
	eq(_label("OutcomeNote").text, tr("END_OUTCOME_SHOUTED_NOTE"))
	eq(_label("DurationValue").text, "3:42")
	var sep: String = tr("NUMBER_GROUP_SEPARATOR")
	eq(_texts("PayoutGrid"), [
		tr("END_LOOT"), tr("HUD_CASH_VALUE") % ("1" + sep + "250"),
		tr("END_RATIO"), tr("END_RATIO_VALUE") % 85,
		tr("END_PAYOUT"), tr("HUD_CASH_VALUE") % ("1" + sep + "063"),
	] as Array[String], "ganimet × oran = ödeme, sayılar sonuçtan")
	eq((screen.get_node("%PayoutGrid").get_child(5) as Label).theme_type_variation, &"CashLabel", "ödeme nakit renginde")
	# Players in slot order: [colour, name, status, loot].
	eq(_texts("PlayerGrid"), [
		"Ayşe", tr("END_STATUS_ESCAPED"), tr("HUD_CASH_VALUE") % "900",
		tr("HUD_PLAYER_YOU") % (tr("HUD_PLAYER_UNNAMED") % 2), tr("END_STATUS_ESCAPED"), tr("HUD_CASH_VALUE") % "350",
		"Cem", tr("END_STATUS_CAUGHT"), tr("HUD_CASH_VALUE") % "0",
	] as Array[String])
	var grid: Node = screen.get_node("%PlayerGrid")
	var colors: Array[Color] = ThemeTokens.PLAYER_COLORS
	eq([(grid.get_child(0) as ColorRect).color, (grid.get_child(4) as ColorRect).color, (grid.get_child(8) as ColorRect).color],
		[colors[0], colors[1], colors[2]], "slot rengi")
	eq((grid.get_child(10) as Label).theme_type_variation, &"AlertLabel", "yakalandı: renk + metin")
	# Notes: title, person (or crew), description.
	var notes: Node = screen.get_node("%NoteRow")
	eq(notes.get_child_count(), 3)
	var titles: Array[String] = []
	var who: Array[String] = []
	for panel: Node in notes.get_children():
		var box: Node = panel.get_child(0)
		titles.append((box.get_child(0) as Label).text)
		var who_row: Node = box.get_child(1)
		who.append((who_row.get_child(who_row.get_child_count() - 1) as Label).text)
		eq((box.get_child(2) as Label).theme_type_variation, &"MutedLabel")
	eq(titles, [tr("NOTE_OWNER_FAVOURITE"), tr("NOTE_SLIPPER"), tr("NOTE_GHOST_CREW")] as Array[String])
	eq(who, [tr("HUD_PLAYER_YOU") % (tr("HUD_PLAYER_UNNAMED") % 2), "Cem", tr("END_NOTE_TEAM")] as Array[String])
	eq(warnings, [] as Array[String], "bilinen anahtarlar uyarı vermez")


func test_loss_outcomes_use_alert_title() -> void:
	await _open()
	for outcome: StringName in [&"police", &"caught_all"]:
		var r: Dictionary = sample_result()
		r["outcome"] = outcome
		game.heist_finished.emit(r)
		eq(_label("OutcomeTitle").text, tr("END_OUTCOME_" + String(outcome).to_upper()))
		eq(_label("OutcomeTitle").theme_type_variation, &"AlertTitleLabel", "%s: başlık uyarı renginde" % outcome)
	for outcome: StringName in [&"clean", &"hot"]:
		var r: Dictionary = sample_result()
		r["outcome"] = outcome
		game.heist_finished.emit(r)
		eq(_label("OutcomeTitle").text, tr("END_OUTCOME_" + String(outcome).to_upper()))
		eq(_label("OutcomeTitle").theme_type_variation, &"TitleLabel")
	eq(warnings, [] as Array[String])


func test_missing_keys_fall_back_with_warning() -> void:
	await _open()
	var r: Dictionary = sample_result()
	r["outcome"] = &"heist_of_the_century"
	r["notes"] = [{"kind": &"mystery_award", "peer": 1}, {"kind": &"shadow", "peer": 1}]
	game.heist_finished.emit(r)
	eq(_label("OutcomeTitle").text, tr("END_OUTCOME_GENERIC"), "bilinmeyen sonuç genel başlıkla")
	is_false(_label("OutcomeNote").visible, "bilinmeyen sonuçta alt satır yok")
	var first: Node = screen.get_node("%NoteRow").get_child(0).get_child(0)
	eq((first.get_child(0) as Label).text, tr("NOTE_GENERIC"), "anahtarı olmayan not genel metinle")
	eq((first.get_child(2) as Label).text, tr("NOTE_GENERIC_DESC"))
	for label: Label in [first.get_child(0), first.get_child(2)]:
		is_false(label.text.to_lower().contains("mystery"), "ham tür adı oyuncuya görünmez")
	eq(warnings, ["END_OUTCOME_HEIST_OF_THE_CENTURY", "NOTE_MYSTERY_AWARD"] as Array[String], "eksik anahtarlar bildirilir")


func test_notes_capped_and_hidden_when_empty() -> void:
	await _open()
	var r: Dictionary = sample_result()
	var many: Array = []
	for kind: StringName in [&"shadow", &"marathon", &"porter", &"bail", &"door_slammer"]:
		many.append({"kind": kind, "peer": 1})
	r["notes"] = many
	game.heist_finished.emit(r)
	eq(screen.get_node("%NoteRow").get_child_count(), 3, "en fazla 3 not (1280×720 tek ekran)")
	r["notes"] = []
	game.heist_finished.emit(r)
	await _settle()
	is_false((screen.get_node("%NotesBox") as Control).visible, "not yoksa bölüm gizli")


func test_late_join_reads_heist_result() -> void:
	await _open(func() -> void: game.result = sample_result())
	is_true(screen.is_open(), "geç katılan heist_result() ile ekranı görür")
	eq(_label("OutcomeTitle").text, tr("END_OUTCOME_SHOUTED"))


func test_game_without_heist_api() -> void:
	var legacy: Node = autofree(Fakes.FakeGameBase.new()) as Node
	await _open(Callable(), legacy)
	is_false(screen.is_open())
	eq(warnings, [] as Array[String])


func test_host_focus_order_and_retry() -> void:
	await _open()
	game.heist_finished.emit(sample_result())
	await _settle()
	is_true((screen.get_node("%RetryButton") as Control).visible, "host 'Bir daha' görür")
	is_false((screen.get_node("%RetryHint") as Control).visible)
	eq(_focused(), "RetryButton", "ilk odak Bir daha")
	_push_joy(JOY_BUTTON_DPAD_RIGHT)
	eq(_focused(), "MenuButton", "gamepad sağ")
	_push_joy(JOY_BUTTON_DPAD_RIGHT)
	eq(_focused(), "RetryButton", "sarar")
	_push_joy(JOY_BUTTON_DPAD_DOWN)
	eq(_focused(), "RetryButton", "aşağı odaktan kaçmaz")
	_push_key(KEY_TAB)
	eq(_focused(), "MenuButton", "Tab")
	_push_key(KEY_TAB, true)
	eq(_focused(), "RetryButton", "Shift+Tab")
	_push_joy(JOY_BUTTON_A)
	eq(journal.names(), PackedStringArray(["request_restart"]), "A: host'ta Game.request_restart() (S3 eki); ayrılış yok")
	is_true(screen.is_open())


func test_menu_leaves_session() -> void:
	await _open()
	game.heist_finished.emit(sample_result())
	await _settle()
	_push_key(KEY_RIGHT)
	eq(_focused(), "MenuButton", "klavye sağ ok")
	_push_key(KEY_ENTER)
	eq(journal.names(), PackedStringArray(["leave"]), "Menü: oturumdan ayrılır")
	eq(menu_requests, [&""] as Array[StringName], "ana menüye hatasız döner")


func test_client_sees_menu_only() -> void:
	await _open(func() -> void: net.hosting = false)
	game.heist_finished.emit(sample_result())
	await _settle()
	is_false((screen.get_node("%RetryButton") as Control).visible, "istemcide Bir daha yok")
	is_true((screen.get_node("%RetryHint") as Control).visible, "yerine host'un başlatacağı yazılı")
	eq(_focused(), "MenuButton")
	_push_joy(JOY_BUTTON_DPAD_LEFT)
	eq(_focused(), "MenuButton", "gizli düğmeye odak gitmez")
	(screen.get_node("%RetryButton") as Button).pressed.emit()
	eq(journal.names(), PackedStringArray(), "istemci yeniden başlatma isteyemez")


func test_host_without_restart_api_has_no_retry() -> void:
	var legacy: Node = autofree(Fakes.FakeGameBase.new()) as Node
	await _open(Callable(), legacy)
	screen.show_result(sample_result())
	await _settle()
	is_false(screen.can_restart())
	is_false((screen.get_node("%RetryButton") as Control).visible, "Game request_restart taşımıyorsa Bir daha yok")
	eq(_focused(), "MenuButton")


func test_pause_menu_blocked_on_end_screen() -> void:
	await _open()
	hud.toggle_pause()
	is_true(hud.is_pause_open())
	game.heist_finished.emit(sample_result())
	is_false(hud.is_pause_open(), "iş sonu açılınca duraklat menüsü kapanır")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc)
	is_false(hud.is_pause_open(), "iş sonu ekranında Esc duraklat açmaz")
	is_true(screen.is_open())


func test_format_clock() -> void:
	eq(Hud.format_clock(0.0), "0:00")
	eq(Hud.format_clock(59.2), "1:00", "yukarı yuvarlanır")
	eq(Hud.format_clock(90.0), "1:30")
	eq(Hud.format_clock(-3.0), "0:00")
	eq(Hud.format_clock(3600.0), "60:00")
