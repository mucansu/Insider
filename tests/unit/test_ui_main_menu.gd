extends TestCase
## Main menu (US-003 AC1, AC5, AC6; IS-009): correct calls to the fake Net/Game, error/connecting states, timeout/cancel if
## the host does not load a level, keyboard and gamepad focus order.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const MENU_SCENE := preload("res://ui/main_menu.tscn")

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var journal: Fakes.CallLog
var viewport: SubViewport
var menu: MainMenu


## If `fresh_settings` is false the settings file is not deleted (opens with the values the test wrote earlier).
func _open(fresh_settings: bool = true) -> void:
	var pair: Array = Fakes.make_pair(self, false, fresh_settings)
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


## Presses Host with a valid name (the fake Net opens the host successfully).
func _start_hosting() -> void:
	_type("NameEdit", "Ayşe")
	_press("HostButton")
	eq(menu.state, MainMenu.State.STARTING)


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
	is_true(_node("CancelButton").visible, "host açılırken de vazgeçilebilir")
	eq(_focused(), "CancelButton")
	eq((_node("ConnectingLabel") as Label).text, tr("MENU_STARTING"))


func test_host_start_timeout_closes_session() -> void:
	# start_level fails silently: level_loaded never arrives, the menu does not stay stuck in STARTING.
	await _open()
	_start_hosting()
	menu.advance(MainMenu.START_TIMEOUT_SEC - 0.5)
	eq(menu.state, MainMenu.State.STARTING, "süre dolmadan bekler")
	eq(journal.names(), PackedStringArray(["set_local_name", "host", "start_level"]))
	menu.advance(0.5)
	eq(menu.state, MainMenu.State.IDLE)
	eq(journal.names(), PackedStringArray(["set_local_name", "host", "start_level", "leave"]), "oturum kapatılır")
	is_true(_node("Form").visible)
	eq(_error_text(), tr("MENU_ERROR_START_FAILED"))
	eq(_focused(), "HostButton", "tekrar denemek için odak Host'ta")
	menu.advance(MainMenu.START_TIMEOUT_SEC * 2.0)
	eq(journal.names().size(), 4, "boşta zaman aşımı işlemez")


func test_host_cancel_while_starting_leaves() -> void:
	await _open()
	_start_hosting()
	menu.advance(1.0)
	_press("CancelButton")
	eq(journal.names(), PackedStringArray(["set_local_name", "host", "start_level", "leave"]))
	eq(menu.state, MainMenu.State.IDLE)
	eq(_error_text(), "", "kendi vazgeçişinde hata yok")
	eq(_focused(), "HostButton")
	_press("HostButton")
	eq(menu.state, MainMenu.State.STARTING, "yeniden host olunabilir")
	menu.advance(MainMenu.START_TIMEOUT_SEC - 0.5)
	eq(menu.state, MainMenu.State.STARTING, "süre her başlatmada sıfırlanır")


func test_level_loaded_while_starting_stops_timeout() -> void:
	await _open()
	_start_hosting()
	game.level_loaded.emit(null)
	is_true(menu.is_queued_for_deletion())
	is_false(menu.is_processing(), "kaldırılan menüde zaman aşımı işlemez")
	is_false(journal.names().has("leave"), "oturum kapatılmaz")


func test_host_failure_shows_error_and_stays() -> void:
	await _open()
	net.host_result = ERR_CANT_CREATE
	_type("NameEdit", "Ayşe")
	_press("HostButton")
	eq(journal.names(), PackedStringArray(["set_local_name", "host"]), "seviye başlatılmamalı")
	eq(menu.state, MainMenu.State.IDLE)
	eq(_error_text(), tr("MENU_ERROR_HOST_FAILED") % MainMenu.DEFAULT_PORT)


# --- AC1: Join ---

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


func test_join_address_errors_focus_visible_field() -> void:
	# US-026 t2: a single parser (ConnectInfo.parse_host_port); the error focus is always on a visible field.
	await _open()
	_type("NameEdit", "Bo")
	for bad_port: String in ["100.64.0.2:", "1.2.3.4:65536", "1.2.3.4:80", "kasa-pc:x"]:
		_type("JoinAddressEdit", bad_port)
		_press("JoinButton")
		eq(_error_text(), tr("MENU_ERROR_PORT_INVALID"), "adresteki port: '%s'" % bad_port)
		eq(_focused(), "JoinAddressEdit", "Gelişmiş kapalı: odak adres alanında ('%s')" % bad_port)
	for bad_address: String in ["kasa pc", "256.1.1.1", "::1", "1.2.3"]:
		_type("JoinAddressEdit", bad_address)
		_press("JoinButton")
		eq(_error_text(), tr("MENU_ERROR_ADDRESS_INVALID"), "adres: '%s'" % bad_address)
		eq(_focused(), "JoinAddressEdit")
	# A bad port in Advanced: focus on the port when open, on the address field when closed.
	_type("JoinAddressEdit", "10.0.0.9")
	_type("JoinPortEdit", "80")
	_press("JoinButton")
	eq(_error_text(), tr("MENU_ERROR_PORT_INVALID"))
	eq(_focused(), "JoinAddressEdit", "Gelişmiş kapalı")
	(_node("AdvancedButton") as Button).button_pressed = true
	_press("JoinButton")
	eq(_focused(), "JoinPortEdit", "Gelişmiş açık")
	_type("JoinAddressEdit", "10.0.0.9:7781")
	_press("JoinButton")
	eq(journal.entries[1], ["join", "10.0.0.9", 7781], "adresteki port Gelişmiş'tekinden önce")
	eq(journal.names(), PackedStringArray(["set_local_name", "join"]), "hatalı denemelerde Net çağrılmaz")


# --- AC6: focus order ---

func test_keyboard_focus_order() -> void:
	await _open()
	_node("NameEdit").grab_focus()
	var down: Array[String] = []
	for i: int in 5:
		_push(_key(KEY_DOWN))
		down.append(_focused())
	eq(down, ["CopyButton", "HostPortEdit", "HostButton", "QuitButton", "NameEdit"] as Array[String], "aşağı ok (sol sütun, sarar)")
	# In a text field left/right arrows move the caret; horizontal moves between fields are on buttons, with Tab and gamepad.
	_node("HostButton").grab_focus()
	_push(_key(KEY_RIGHT))
	eq(_focused(), "JoinButton", "sağ ok: Host → Katıl")
	_push(_key(KEY_UP))
	eq(_focused(), "AdvancedButton", "port gizliyken Katıl'ın üstü Gelişmiş")
	_push(_key(KEY_UP))
	eq(_focused(), "JoinAddressEdit")
	_push(_key(KEY_UP))
	eq(_focused(), "NameEdit")
	var tabs: Array[String] = []
	for i: int in 9:
		_push(_key(KEY_TAB))
		tabs.append(_focused())
	eq(tabs, ["CopyButton", "HostPortEdit", "HostButton", "JoinAddressEdit", "PasteButton", "AdvancedButton", "JoinButton",
		"QuitButton", "NameEdit"] as Array[String], "Tab halkası")
	_push(_key(KEY_TAB, true, true))
	eq(_focused(), "QuitButton", "Shift+Tab geri")


func test_gamepad_navigation_and_accept() -> void:
	await _open()
	_type("NameEdit", "Pad")
	_node("NameEdit").grab_focus()
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "CopyButton")
	_push(_joy(JOY_BUTTON_DPAD_RIGHT))
	eq(_focused(), "JoinAddressEdit")
	_push(_joy(JOY_BUTTON_DPAD_LEFT))
	eq(_focused(), "CopyButton")
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "HostPortEdit")
	_push(_joy(JOY_BUTTON_DPAD_RIGHT))
	eq(_focused(), "AdvancedButton", "host portu satırı ↔ Gelişmiş")
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


# --- US-026: connection ease ---

func test_remembers_name_and_last_address() -> void:
	Fakes.reset_connect_settings()
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: "Bo", ConnectInfo.KEY_ADDRESS: "100.64.0.2:7780"})
	await _open(false)
	eq((_node("NameEdit") as LineEdit).text, "Bo")
	eq((_node("JoinAddressEdit") as LineEdit).text, "100.64.0.2:7780")
	eq(_focused(), "JoinButton", "ikinci açılışta tek tuşla katılım")
	_push(_joy(JOY_BUTTON_A, true))
	_push(_joy(JOY_BUTTON_A, false))
	eq(journal.entries, [["set_local_name", "Bo"], ["join", "100.64.0.2", 7780]])


func test_only_name_remembered_focuses_host() -> void:
	Fakes.reset_connect_settings()
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: "Bo"})
	await _open(false)
	eq((_node("JoinAddressEdit") as LineEdit).text, "")
	eq(_focused(), "HostButton")


func test_corrupt_settings_open_with_defaults() -> void:
	Fakes.reset_connect_settings()
	var f: FileAccess = FileAccess.open(ConnectInfo.settings_path, FileAccess.WRITE)
	f.store_string("[connect\nname = = \"yarım\n")
	f.close()
	await _open(false)
	eq((_node("NameEdit") as LineEdit).text, "")
	eq((_node("JoinAddressEdit") as LineEdit).text, "")
	eq(_focused(), "NameEdit", "bozuk dosya: ilk açılış gibi")
	eq(_error_text(), "", "oyuncuya hata gösterilmez")


func test_join_saves_name_and_address() -> void:
	await _open()
	_type("NameEdit", " Bo ")
	_type("JoinAddressEdit", "100.64.0.9")
	_type("JoinPortEdit", "7780")
	_press("JoinButton")
	eq(journal.entries[1], ["join", "100.64.0.9", 7780])
	eq(ConnectInfo.load_settings(), {ConnectInfo.KEY_NAME: "Bo", ConnectInfo.KEY_ADDRESS: "100.64.0.9:7780"},
		"varsayılan dışı port adrese yazılır")
	_press("CancelButton")
	_type("JoinAddressEdit", "kasa-pc:7777")
	_type("JoinPortEdit", "7777")
	_press("JoinButton")
	eq(ConnectInfo.load_settings()[ConnectInfo.KEY_ADDRESS], "kasa-pc", "varsayılan port yazılmaz")


func test_failed_join_start_does_not_save_address() -> void:
	Fakes.reset_connect_settings()
	ConnectInfo.save_settings({ConnectInfo.KEY_ADDRESS: "100.64.0.2"})
	await _open(false)
	net.join_result = ERR_CANT_RESOLVE
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "yok.example")
	_press("JoinButton")
	eq(ConnectInfo.load_settings()[ConnectInfo.KEY_ADDRESS], "100.64.0.2")


func test_host_saves_name_keeps_address_and_port() -> void:
	Fakes.reset_connect_settings()
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: "Eski", ConnectInfo.KEY_ADDRESS: "100.64.0.2"})
	await _open(false)
	_type("NameEdit", "Ayşe")
	_type("HostPortEdit", "7790")
	_press("HostButton")
	eq(ConnectInfo.load_settings(), {ConnectInfo.KEY_NAME: "Ayşe", ConnectInfo.KEY_ADDRESS: "100.64.0.2"})
	eq(ConnectInfo.hosted_port, 7790, "duraklat menüsündeki davet bu portu gösterir")


func test_paste_button_fills_address() -> void:
	await _open()
	var clip: Array[String] = [" 100.64.0.2:7777 \n"]
	menu.clipboard_getter = func() -> String: return clip[0]
	_press("PasteButton")
	eq((_node("JoinAddressEdit") as LineEdit).text, "100.64.0.2", "varsayılan port yazılmaz")
	eq(_focused(), "JoinButton", "yapıştırınca odak Katıl'da")
	clip[0] = "Adres: 100.70.1.2:9000 — gelin"
	_press("PasteButton")
	eq((_node("JoinAddressEdit") as LineEdit).text, "100.70.1.2:9000", "sohbet metninden IPv4:port")
	clip[0] = "kasa-pc.tail1234.ts.net"
	_press("PasteButton")
	eq((_node("JoinAddressEdit") as LineEdit).text, "kasa-pc.tail1234.ts.net")
	for bad: String in ["", "merhaba dünya", "100.64.0.2:80", "::1"]:
		clip[0] = bad
		_press("PasteButton")
		eq(_error_text(), tr("MENU_ERROR_PASTE_INVALID"), "geçersiz pano: '%s'" % bad)
		eq((_node("JoinAddressEdit") as LineEdit).text, "kasa-pc.tail1234.ts.net", "alan değişmez")
		eq(_focused(), "PasteButton")
	clip[0] = "10.0.0.9"
	_press("PasteButton")
	eq(_error_text(), "", "geçerli yapıştırma hatayı kaldırır")
	eq(journal.entries, [], "yapıştırma bağlanmaz")


func test_advanced_reveals_port_and_address_enter_joins() -> void:
	await _open()
	is_false(_node("JoinPortEdit").is_visible_in_tree(), "port varsayılan gizli")
	_type("NameEdit", "Bo")
	_type("JoinAddressEdit", "10.0.0.9")
	(_node("JoinAddressEdit") as LineEdit).text_submitted.emit("10.0.0.9")
	eq(journal.entries, [["set_local_name", "Bo"], ["join", "10.0.0.9", MainMenu.DEFAULT_PORT]], "port gizliyken Enter katılır")
	_press("CancelButton")
	(_node("AdvancedButton") as Button).button_pressed = true
	is_true(_node("JoinPortEdit").is_visible_in_tree(), "Gelişmiş portu gösterir")
	_node("AdvancedButton").grab_focus()
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "JoinPortEdit", "gamepad ile porta iner")
	_push(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "JoinButton")
	_node("AdvancedButton").grab_focus()
	_push(_key(KEY_TAB))
	eq(_focused(), "JoinPortEdit", "Tab halkasında port")
	(_node("JoinAddressEdit") as LineEdit).text_submitted.emit("10.0.0.9")
	eq(_focused(), "JoinPortEdit", "Gelişmiş açıkken Enter porta geçer")
	(_node("AdvancedButton") as Button).button_pressed = false
	is_false(_node("JoinPortEdit").is_visible_in_tree())
	_node("AdvancedButton").grab_focus()
	_push(_key(KEY_TAB))
	eq(_focused(), "JoinButton", "kapalıyken port atlanır")


func test_host_card_invite_follows_port_and_copies() -> void:
	await _open()
	var invite: InvitePanel = menu.get_node("%HostInvite") as InvitePanel
	var copied: Array[String] = []
	invite.addresses_provider = func() -> PackedStringArray: return PackedStringArray(["192.168.1.5", "100.101.2.3"])
	invite.clipboard_setter = func(text: String) -> void: copied.append(text)
	invite.refresh()
	eq(invite.invite_text(), "100.101.2.3:7777", "Tailscale önce")
	is_false((invite.get_node("%AddressButton") as CanvasItem).visible, "ana menüde liste yok (yer)")
	(_node("HostPortEdit") as LineEdit).text_changed.emit("7790")
	eq((invite.get_node("%AddressLabel") as Label).text, "100.101.2.3:7790")
	(invite.get_node("%CopyButton") as Button).pressed.emit()
	eq(copied, ["100.101.2.3:7790"] as Array[String])
	(_node("HostPortEdit") as LineEdit).text_changed.emit("80")
	eq(invite.invite_text(), "100.101.2.3:7777", "geçersiz portta varsayılan")
