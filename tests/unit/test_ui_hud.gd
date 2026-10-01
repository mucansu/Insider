extends TestCase
## HUD (US-003 AC2, AC3, AC5; IS-009): ekip nakdi, ping, oyuncu listesi, oturum olayı bildirimi, sahte
## oyuncunun S7 sinyallerine tepki, `pause` eylemiyle (Esc/Start) duraklat menüsü, ayrılma ve kopma akışı.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var journal: Fakes.CallLog
var viewport: SubViewport
var hud: Hud
var menu_requests: Array[StringName] = []
## HUD'un geliştirici uyarıları (eksik metin anahtarı); çıktıya WARNING basılmaz.
var warnings: Array[String] = []


## `before_ready` HUD sahneye eklenmeden önce sahteleri hazırlamak içindir.
func _open(before_ready: Callable = Callable()) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	journal = pair[2]
	if before_ready.is_valid():
		before_ready.call()
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(error_key: StringName) -> void: menu_requests.append(error_key)
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	viewport.add_child(hud)
	await tree().process_frame


func _node(unique_name: String) -> Node:
	return hud.get_node("%" + unique_name)


func _pause_button(unique_name: String) -> Button:
	return _node("PauseMenu").get_node("%" + unique_name) as Button


func _text(unique_name: String) -> String:
	return (_node(unique_name) as Label).text


func _player_rows() -> Array[String]:
	var out: Array[String] = []
	for row: Node in _node("PlayerList").get_children():
		out.append((row.get_child(1) as Label).text)
	return out


func _toast_texts() -> Array[String]:
	var out: Array[String] = []
	for panel: Node in _node("Toasts").get_children():
		out.append((panel.get_child(0) as Label).text)
	return out


# --- ekip nakdi ---

func test_cash_initial_and_on_signal() -> void:
	await _open(func() -> void: game.cash = 1250)
	var sep: String = tr("NUMBER_GROUP_SEPARATOR")
	eq(_text("CashValue"), tr("HUD_CASH_VALUE") % ("1" + sep + "250"))
	game.team_cash_changed.emit(150)
	eq(_text("CashValue"), tr("HUD_CASH_VALUE") % "150")
	game.team_cash_changed.emit(2400000)
	eq(_text("CashValue"), tr("HUD_CASH_VALUE") % ("2" + sep + "400" + sep + "000"))


func test_group_digits() -> void:
	eq(Hud.group_digits(0, "."), "0")
	eq(Hud.group_digits(999, "."), "999")
	eq(Hud.group_digits(1000, "."), "1.000")
	eq(Hud.group_digits(1234567, ","), "1,234,567")
	eq(Hud.group_digits(-1500, "."), "-1.500")


# --- ping ---

func test_ping_polled_every_second() -> void:
	await _open()
	var timer: Timer = _node("PingTimer") as Timer
	eq(timer.wait_time, Hud.PING_INTERVAL_SEC)
	is_false(timer.one_shot, "tekrarlı")
	is_false(timer.is_stopped(), "çalışıyor")
	is_true(timer.timeout.is_connected(hud.refresh_ping), "zamanlayıcı ping'i yeniler")
	var before: int = net.ping_calls
	net.ping_ms = 42
	timer.timeout.emit()
	eq(net.ping_calls, before + 1)
	eq(_text("PingLabel"), tr("HUD_PING_MS") % 42)
	eq((_node("PingLabel") as Label).theme_type_variation, &"MutedLabel")


func test_ping_states() -> void:
	await _open()
	var label: Label = _node("PingLabel") as Label
	net.ping_ms = Hud.PING_WARN_MS
	hud.refresh_ping()
	eq(label.theme_type_variation, &"AlertLabel", "yüksek gecikme uyarı renginde")
	net.ping_ms = -1
	hud.refresh_ping()
	eq(label.text, tr("HUD_PING_UNKNOWN"))
	eq(label.theme_type_variation, &"MutedLabel")
	net.hosting = true
	hud.refresh_ping()
	eq(label.text, tr("HUD_PING_HOST"))


# --- oyuncu listesi ---

func test_players_list_follows_signal() -> void:
	await _open()
	eq(_player_rows(), [] as Array[String])
	net.my_peer_id = 2
	game.roster = {
		2: {"name": "Bo", "color": ThemeTokens.PLAYER_COLORS[1]},
		1: {"name": "Ayşe", "color": ThemeTokens.PLAYER_COLORS[0]},
		7: {"name": "", "color": ThemeTokens.PLAYER_COLORS[2]},
	}
	game.players_changed.emit()
	eq(_player_rows(), ["Ayşe", tr("HUD_PLAYER_YOU") % "Bo", tr("HUD_PLAYER_UNNAMED") % 7] as Array[String], "peer sırasıyla, yerel işaretli")
	var first_swatch: ColorRect = _node("PlayerList").get_child(0).get_child(0) as ColorRect
	eq(first_swatch.color, ThemeTokens.PLAYER_COLORS[0])
	game.roster.erase(7)
	game.players_changed.emit()
	eq(_player_rows().size(), 2, "ayrılan oyuncu listeden düşer")


# --- oturum olayları ---

func test_session_event_shows_keyed_toast() -> void:
	await _open()
	game.session_event.emit(&"police_called", {})
	eq(_toast_texts(), [tr("EVENT_POLICE_CALLED")] as Array[String])
	eq(warnings, [] as Array[String], "anahtarı olan olay uyarı vermez")
	game.session_event.emit(&"alarm_tripped", {"amount": 5})
	eq(_toast_texts()[1], tr("EVENT_GENERIC"), "anahtarı olmayan olay genel metinle")
	is_false(_toast_texts()[1].to_lower().contains("alarm"), "ham olay adı oyuncuya görünmez")
	eq(warnings, ["EVENT_ALARM_TRIPPED"] as Array[String], "eksik anahtar geliştiriciye bildirilir")


func test_session_event_data_fills_placeholders() -> void:
	await _open()
	var t := Translation.new()
	t.locale = TranslationServer.get_locale()
	t.add_message(&"EVENT_TEST_LOOT", "{name}: {amount}")
	TranslationServer.add_translation(t)
	eq(hud.event_text(&"test_loot", {"name": "Bo", "amount": 150}), "Bo: 150")
	TranslationServer.remove_translation(t)


func test_toasts_expire_and_are_capped() -> void:
	await _open()
	for i: int in Hud.MAX_TOASTS + 2:
		game.session_event.emit(&"police_called", {})
	eq(_node("Toasts").get_child_count(), Hud.MAX_TOASTS, "en fazla %d bildirim" % Hud.MAX_TOASTS)
	hud.advance(Hud.TOAST_SECONDS - Hud.TOAST_FADE_SECONDS / 2.0)
	var panel: Control = _node("Toasts").get_child(0) as Control
	near(panel.modulate.a, 0.5, 0.01, "son yarım saniyede solar")
	hud.advance(Hud.TOAST_FADE_SECONDS)
	eq(_node("Toasts").get_child_count(), 0, "süresi dolan kalkar")


# --- etkileşim (S7 sinyalleri, sahte oyuncu) ---

func test_interaction_progress_from_local_player_signals() -> void:
	await _open()
	var player: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	var panel: Control = _node("Interaction") as Control
	var bar: ProgressBar = _node("InteractionBar") as ProgressBar
	game.local_player_changed.emit(player)
	is_false(panel.visible)
	player.interaction_started.emit("PAUSE_RESUME", 2.0)
	is_true(panel.visible, "istem görünür")
	eq(_text("InteractionLabel"), tr("PAUSE_RESUME"), "eylem anahtarı çevrilir")
	near(bar.value, 0.0, 0.001)
	hud.advance(1.0)
	near(bar.value, 0.5, 0.01)
	hud.advance(5.0)
	near(bar.value, 1.0, 0.001, "süre aşılsa da tam")
	player.interaction_finished.emit(true)
	is_true(panel.visible, "bitince kısa süre kalır")
	hud.advance(Hud.INTERACTION_LINGER_SEC + 0.05)
	is_false(panel.visible)


func test_interaction_cancel_and_instant() -> void:
	await _open()
	var player: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	game.local_player_changed.emit(player)
	player.interaction_started.emit("PAUSE_LEAVE", 3.0)
	hud.advance(1.0)
	player.interaction_finished.emit(false)
	eq(_text("InteractionLabel"), tr("HUD_INTERACT_CANCELLED"))
	near((_node("InteractionBar") as ProgressBar).value, 1.0 / 3.0, 0.01, "yarıda kalan ilerleme görünür kalır")
	hud.advance(Hud.INTERACTION_LINGER_SEC + 0.05)
	is_false((_node("Interaction") as Control).visible)
	player.interaction_started.emit("PAUSE_LEAVE", 0.0)
	near((_node("InteractionBar") as ProgressBar).value, 1.0, 0.001, "anlık etkileşim dolu çubuk")


func test_rebinding_local_player() -> void:
	var first: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	await _open(func() -> void: game.local = first)
	first.interaction_started.emit("PAUSE_RESUME", 1.0)
	is_true((_node("Interaction") as Control).visible, "açılışta yerel oyuncuya bağlanır")
	var second: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	game.local_player_changed.emit(second)
	is_false((_node("Interaction") as Control).visible, "oyuncu değişince istem sıfırlanır")
	first.interaction_started.emit("PAUSE_RESUME", 1.0)
	is_false((_node("Interaction") as Control).visible, "eski oyuncunun sinyali dinlenmez")
	is_false(first.interaction_started.is_connected(hud._on_interaction_started))
	second.interaction_started.emit("PAUSE_RESUME", 1.0)
	is_true((_node("Interaction") as Control).visible)
	game.local_player_changed.emit(null)
	is_false((_node("Interaction") as Control).visible)


# --- etkileşim istemi (S7 interaction_target_changed) ---

func test_prompt_follows_target_and_input_device() -> void:
	await _open()
	UiInput.using_gamepad = false
	var player: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	var prompt: Control = _node("Prompt") as Control
	game.local_player_changed.emit(player)
	is_false(prompt.visible, "hedef yokken istem yok")
	player.interaction_target_changed.emit("PAUSE_RESUME")
	is_true(prompt.visible)
	eq(_text("PromptLabel"), tr("HUD_PROMPT") % ["E", tr("PAUSE_RESUME")], "klavye: [E] eylem")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	pad.pressed = true
	viewport.push_input(pad)
	eq(_text("PromptLabel"), tr("HUD_PROMPT") % ["A", tr("PAUSE_RESUME")], "gamepad'e geçince [A]")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	viewport.push_input(key)
	eq(_text("PromptLabel"), tr("HUD_PROMPT") % ["E", tr("PAUSE_RESUME")], "klavyeye dönünce [E]")
	player.interaction_target_changed.emit("")
	is_false(prompt.visible, "boş anahtar istemi gizler")
	UiInput.using_gamepad = false


func test_prompt_gives_way_to_progress() -> void:
	await _open()
	var player: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	var prompt: Control = _node("Prompt") as Control
	var progress: Control = _node("Interaction") as Control
	game.local_player_changed.emit(player)
	player.interaction_target_changed.emit("PAUSE_LEAVE")
	player.interaction_started.emit("PAUSE_LEAVE", 1.0)
	is_false(prompt.visible, "etkileşim sürerken istem yok")
	is_true(progress.visible)
	hud.advance(1.0)
	player.interaction_finished.emit(true)
	hud.advance(Hud.INTERACTION_LINGER_SEC + 0.05)
	is_false(progress.visible)
	is_true(prompt.visible, "hedef sürüyorsa istem geri gelir")
	player.interaction_target_changed.emit("")
	is_false(prompt.visible)


func test_player_without_prompt_signals_is_tolerated() -> void:
	await _open()
	var legacy: Node = autofree(Node.new()) as Node
	game.local_player_changed.emit(legacy)
	is_false((_node("Prompt") as Control).visible)
	is_false((_node("Interaction") as Control).visible)
	var first: Fakes.FakePlayer = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	game.local_player_changed.emit(first)
	first.interaction_target_changed.emit("PAUSE_LEAVE")
	game.local_player_changed.emit(legacy)
	is_false((_node("Prompt") as Control).visible, "oyuncu değişince istem sıfırlanır")
	first.interaction_target_changed.emit("PAUSE_LEAVE")
	is_false((_node("Prompt") as Control).visible, "eski oyuncunun hedef sinyali dinlenmez")


# --- AC3: duraklat menüsü ---

func test_pause_menu_blocks_gameplay_input() -> void:
	await _open()
	is_false(UiInput.is_gameplay_input_blocked())
	hud.toggle_pause()
	is_true(UiInput.is_gameplay_input_blocked(), "menü açıkken oyun girdisi engelli")
	hud.toggle_pause()
	is_false(UiInput.is_gameplay_input_blocked(), "kapanınca engel kalkar")
	hud.toggle_pause()
	viewport.remove_child(hud)
	is_false(UiInput.is_gameplay_input_blocked(), "HUD ağaçtan çıkınca (oturumdan ayrılış) engel kalmaz")
	hud.free()

func test_escape_and_start_toggle_pause_menu() -> void:
	await _open()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc)
	is_true(hud.is_pause_open(), "Esc açar")
	eq(str(viewport.gui_get_focus_owner().name), "ResumeButton", "odak Devam'da")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	viewport.push_input(down)
	eq(str(viewport.gui_get_focus_owner().name), "LeaveButton", "gamepad ile Ayrıl'a iner")
	viewport.push_input(esc)
	is_false(hud.is_pause_open(), "Esc kapatır")
	is_true(viewport.gui_get_focus_owner() == null, "kapanınca odak bırakılır")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	viewport.push_input(back)
	is_false(hud.is_pause_open(), "gamepad B oyunda menü açmaz")
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	viewport.push_input(start)
	is_true(hud.is_pause_open(), "gamepad Start açar")
	viewport.push_input(back)
	is_false(hud.is_pause_open(), "gamepad B açık menüyü kapatır")
	viewport.push_input(start)
	is_true(hud.is_pause_open())
	_pause_button("ResumeButton").pressed.emit()
	is_false(hud.is_pause_open(), "Devam kapatır")
	eq(journal.entries, [], "duraklatma ağa bir şey göndermez")


func test_leave_calls_net_leave_and_opens_menu() -> void:
	await _open()
	hud.toggle_pause()
	_pause_button("LeaveButton").pressed.emit()
	eq(journal.names(), PackedStringArray(["leave"]))
	eq(menu_requests, [&""] as Array[StringName], "ana menüye hatasız döner")
	net.host_disconnected.emit()
	eq(menu_requests.size(), 1, "kendi ayrılışında kopma hatası gösterilmez")


func test_host_disconnected_returns_to_menu_with_error() -> void:
	await _open()
	net.host_disconnected.emit()
	eq(menu_requests, [&"MENU_ERROR_HOST_DISCONNECTED"] as Array[StringName])


func test_connection_failed_after_level_load_returns_to_menu() -> void:
	# El sıkışma bitmeden seviye yüklendi (ana menü kalktı), sonra bağlantı kurulamadı.
	await _open()
	net.connection_failed.emit()
	eq(menu_requests, [&"MENU_ERROR_CONNECTION_FAILED"] as Array[StringName])
	net.host_disconnected.emit()
	net.connection_failed.emit()
	eq(menu_requests.size(), 1, "menüye bir kez döner")
	eq(journal.entries, [], "ağa bir şey göndermez")


func test_connection_failed_after_own_leave_shows_no_error() -> void:
	await _open()
	hud.toggle_pause()
	_pause_button("LeaveButton").pressed.emit()
	net.connection_failed.emit()
	eq(menu_requests, [&""] as Array[StringName])


func test_hud_uses_active_tone_theme() -> void:
	await _open()
	eq((_node("Root") as Control).theme, ThemeTokens.theme())
	eq((hud as CanvasLayer).layer, 10)
