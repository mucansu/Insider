extends TestCase
## Ana menü (US-003 AC1, AC5, AC6): sahte Net/Game'e doğru çağrılar, hata/bağlanıyor durumları,
## klavye ve gamepad odak sırası.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const MENU_SCENE := preload("res://ui/main_menu.tscn")

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var journal: Fakes.CallLog
var viewport: SubViewport
var menu: MainMenu


func _open() -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	journal = pair[2]
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	menu = MENU_SCENE.instantiate() as MainMenu
	menu.net = net
	menu.game = game
	viewport.add_child(menu)
	await tree().process_frame


func _node(unique_name: String) -> Control:
	return menu.get_node("%" + unique_name) as Control


func _press(unique_name: String) -> void:
	(_node(unique_name) as Button).pressed.emit()


func _type(unique_name: String, text: String) -> void:
	(_node(unique_name) as LineEdit).text = text


func _error_text() -> String:
	return (_node("ErrorLabel") as Label).text if _node("ErrorPanel").visible else ""


func _focused() -> String:
	var owner: Control = viewport.gui_get_focus_owner()
	return str(owner.name) if owner != null else "<yok>"


func _push(event: InputEvent) -> void:
	viewport.push_input(event)


static func _key(keycode: Key, pressed: bool = true, shift: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	e.shift_pressed = shift
	return e


static func _joy(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


# --- AC1: Host ---

func test_host_calls_set_name_host_and_start_level_in_order() -> void:
	await _open()
	_type("NameEdit", "  Ayşe  ")
	_type("HostPortEdit", "7778")
	_press("HostButton")
	eq(journal.entries, [["set_local_name", "Ayşe"], ["host", 7778], ["start_level", Game.DEFAULT_LEVEL]])
	eq(menu.state, MainMenu.State.STARTING)
	is_true(_node("Connecting").visible, "yükleniyor görünümü")
	is_false(_node("Form").visible, "form gizli")
	is_false(_node("CancelButton").visible, "host açılırken vazgeç yok")
	eq((_node("ConnectingLabel") as Label).text, tr("MENU_STARTING"))


func test_host_failure_shows_error_and_stays() -> void:
	await _open()
	net.host_result = ERR_CANT_CREATE
	_type("NameEdit", "Ayşe")
	_press("HostButton")
	eq(journal.names(), PackedStringArray(["set_local_name", "host"]), "seviye başlatılmamalı")
	eq(menu.state, MainMenu.State.IDLE)
	eq(_error_text(), tr("MENU_ERROR_HOST_FAILED") % MainMenu.DEFAULT_PORT)


# --- AC1: Katıl ---

func test_join_calls_set_name_and_join_then_shows_connecting() -> void:
	await _open()
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "100.64.0.2")
	_type("JoinPortEdit", "7780")
	_press("JoinButton")
	eq(journal.entries, [["set_local_name", "Bo"], ["join", "100.64.0.2", 7780]])
	eq(menu.state, MainMenu.State.CONNECTING)
	eq((_node("ConnectingLabel") as Label).text, tr("MENU_CONNECTING") % ["100.64.0.2", 7780])
	is_true(_node("CancelButton").visible)
	eq(_focused(), "CancelButton", "bağlanırken odak Vazgeç'te")


func test_join_accepts_address_with_port() -> void:
	await _open()
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "kasa-pc.tail.ts.net:9000")
	_press("JoinButton")
	eq(journal.entries[1], ["join", "kasa-pc.tail.ts.net", 9000])


func test_connection_failed_returns_to_form_with_error() -> void:
	await _open()
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "10.0.0.9")
	_press("JoinButton")
	net.connection_failed.emit()
	eq(menu.state, MainMenu.State.IDLE)
	is_true(_node("Form").visible)
	is_false(_node("Connecting").visible)
	eq(_error_text(), tr("MENU_ERROR_CONNECTION_FAILED"))
	eq(_focused(), "JoinButton")


func test_connected_then_host_disconnected_shows_error() -> void:
	await _open()
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "10.0.0.9")
	_press("JoinButton")
	net.connected_to_host.emit()
	eq(menu.state, MainMenu.State.CONNECTED)
	eq((_node("ConnectingLabel") as Label).text, tr("MENU_CONNECTED"))
	net.host_disconnected.emit()
	eq(menu.state, MainMenu.State.IDLE)
	eq(_error_text(), tr("MENU_ERROR_HOST_DISCONNECTED"))


func test_join_start_failure_shows_error() -> void:
	await _open()
	net.join_result = ERR_CANT_RESOLVE
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "yok.example")
	_press("JoinButton")
	eq(menu.state, MainMenu.State.IDLE)
	eq(_error_text(), tr("MENU_ERROR_JOIN_FAILED"))


func test_cancel_while_connecting_leaves() -> void:
	await _open()
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "10.0.0.9")
	_press("JoinButton")
	_press("CancelButton")
	eq(journal.names(), PackedStringArray(["set_local_name", "join", "leave"]))
	eq(menu.state, MainMenu.State.IDLE)
	is_true(_node("Form").visible)


func test_validation_blocks_calls() -> void:
	await _open()
	_press("HostButton")
	eq(_error_text(), tr("MENU_ERROR_NAME_EMPTY"))
	eq(_focused(), "NameEdit")
	_type("NameEdit", "Ayşe")
	for bad: String in ["80", "70000", "abc", ""]:
		_type("HostPortEdit", bad)
		_press("HostButton")
		eq(_error_text(), tr("MENU_ERROR_PORT_INVALID"), "port: '%s'" % bad)
	_press("JoinButton")
	eq(_error_text(), tr("MENU_ERROR_ADDRESS_EMPTY"))
	eq(_focused(), "JoinAddressEdit")
	eq(journal.entries, [], "geçersiz girdide Net/Game çağrılmamalı")


func test_valid_action_clears_previous_error() -> void:
	await _open()
	_press("HostButton")
	ne(_error_text(), "")
	_type("NameEdit", "Ayşe")
	_press("HostButton")
	is_false(_node("ErrorPanel").visible)


func test_quit_button() -> void:
	await _open()
	var quit_calls: Array[int] = [0]
	menu.quit_override = func() -> void: quit_calls[0] += 1
	_press("QuitButton")
	eq(quit_calls[0], 1)


func test_pending_error_shown_once_on_open() -> void:
	MainMenu.pending_error = &"MENU_ERROR_HOST_DISCONNECTED"
	await _open()
	eq(_error_text(), tr("MENU_ERROR_HOST_DISCONNECTED"))
	eq(MainMenu.pending_error, &"", "gösterilince silinir")


func test_level_loaded_removes_menu() -> void:
	await _open()
	game.level_loaded.emit(null)
	is_true(menu.is_queued_for_deletion())


func test_defaults_and_initial_focus() -> void:
	await _open()
	eq((_node("HostPortEdit") as LineEdit).text, str(MainMenu.DEFAULT_PORT))
	eq((_node("JoinPortEdit") as LineEdit).text, str(MainMenu.DEFAULT_PORT))
	eq((_node("NameEdit") as LineEdit).max_length, MainMenu.MAX_NAME_LENGTH)
	eq(_focused(), "NameEdit", "ad boşken ilk odak ad alanında")
	eq(menu.theme, ThemeTokens.theme(), "menü etkin tonun temasını kullanır")
	eq((menu.get_node("Center/Column/Header/Title") as Label).language, "en", "marka adı Türkçe büyük harf kuralına (İ) girmez")


func test_parse_helpers() -> void:
	eq(MainMenu.parse_port("7777"), 7777)
	eq(MainMenu.parse_port(" 65535 "), 65535)
	eq(MainMenu.parse_port("1023"), -1)
	eq(MainMenu.parse_port("7a"), -1)
	eq(MainMenu.parse_address("10.0.0.2", 7777), {"address": "10.0.0.2", "port": 7777})
	eq(MainMenu.parse_address(" host:8000 ", 7777), {"address": "host", "port": 8000})
	eq(MainMenu.parse_address("host:x", 7777), {"address": "host", "port": -1})
	eq(MainMenu.parse_address("::1", 7777), {"address": "::1", "port": 7777}, "IPv6 bölünmez")


# --- AC6: odak sırası ---

func test_keyboard_focus_order() -> void:
	await _open()
	_node("NameEdit").grab_focus()
	var down: Array[String] = []
	for i: int in 4:
		_push(_key(KEY_DOWN))
		down.append(_focused())
	eq(down, ["HostPortEdit", "HostButton", "QuitButton", "NameEdit"] as Array[String], "aşağı ok (sol sütun, sarar)")
	# Yazı alanında sol/sağ ok imleci taşır; alanlar arası yatay geçiş butonlarda, Tab'la ve gamepad'le.
	_node("HostButton").grab_focus()
	_push(_key(KEY_RIGHT))
	eq(_focused(), "JoinButton", "sağ ok: Host → Katıl")
	_push(_key(KEY_UP))
	eq(_focused(), "JoinPortEdit")
	_push(_key(KEY_UP))
	eq(_focused(), "JoinAddressEdit")
	_push(_key(KEY_UP))
	eq(_focused(), "NameEdit")
	var tabs: Array[String] = []
	for i: int in 7:
		_push(_key(KEY_TAB))
		tabs.append(_focused())
	eq(tabs, ["HostPortEdit", "HostButton", "JoinAddressEdit", "JoinPortEdit", "JoinButton", "QuitButton", "NameEdit"] as Array[String], "Tab halkası")
	_push(_key(KEY_TAB, true, true))
	eq(_focused(), "QuitButton", "Shift+Tab geri")


func test_gamepad_navigation_and_accept() -> void:
	await _open()
	_type("NameEdit", "Pad")
	_node("NameEdit").grab_focus()
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "HostPortEdit")
	_push(_joy(JOY_BUTTON_DPAD_RIGHT))
	eq(_focused(), "JoinAddressEdit")
	_push(_joy(JOY_BUTTON_DPAD_LEFT))
	eq(_focused(), "HostPortEdit")
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "HostButton")
	_push(_joy(JOY_BUTTON_A, true))
	_push(_joy(JOY_BUTTON_A, false))
	eq(journal.names(), PackedStringArray(["set_local_name", "host", "start_level"]), "A tuşu odaktaki butona basar")


func test_gamepad_cancel_while_connecting() -> void:
	await _open()
	_type("NameEdit", "Pad")
	_type("JoinAddressEdit", "10.0.0.9")
	_node("JoinButton").grab_focus()
	_push(_joy(JOY_BUTTON_A, true))
	_push(_joy(JOY_BUTTON_A, false))
	eq(menu.state, MainMenu.State.CONNECTING)
	eq(_focused(), "CancelButton")
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "CancelButton", "bağlanırken odak Vazgeç'ten kaçmaz")
	_push(_joy(JOY_BUTTON_A, true))
	_push(_joy(JOY_BUTTON_A, false))
	eq(menu.state, MainMenu.State.IDLE)
