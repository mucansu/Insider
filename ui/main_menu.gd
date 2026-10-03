class_name MainMenu
extends Control
## Main menu (US-003 AC1, AC6): player name, host (port), join (address + port), quit.
## Binds to Net/Game only through the S1/S3 contract; tests swap `net` and `game` for fakes before adding to the scene. The menu removes itself on `level_loaded`;
## on the host, if the level does not load within START_TIMEOUT_SEC the session is closed and the form returns with an error (Cancel takes the same path).
## US-011c: the host card has a vision-mode picker (host game rule, GDD §6.5), visible if Game has the S3 addendum (vision_mode(), set_vision_mode()); the choice is sent to Game after hosting, before the level starts.
## US-026: name and last joined address come from the ConnectInfo settings file and are written on host/join; the host card shows the invite address (Copy); the join card has Paste and the port under "Advanced".

const SCENE_PATH := "res://ui/main_menu.tscn"
const DEFAULT_PORT := ConnectInfo.DEFAULT_PORT
const MIN_PORT := ConnectInfo.MIN_PORT
const MAX_PORT := ConnectInfo.MAX_PORT
const MAX_NAME_LENGTH := 16
## Longest wait (s) for level_loaded after start_level on the host; then the session is closed.
const START_TIMEOUT_SEC := 10.0
## Vision modes (S3 addendum `Game.vision_mode()` values): 0 ambient 360 deg, 1 directional.
const VISION_OMNI := 0
const VISION_DIRECTIONAL := 1
## Mode -> option text (option id = mode).
const VISION_KEYS := {VISION_OMNI: "MENU_VISION_OMNI", VISION_DIRECTIONAL: "MENU_VISION_DIRECTIONAL"}

enum State { IDLE, CONNECTING, CONNECTED, STARTING }

## Error key to show when the menu opens (e.g. the HUD leaves it when the host drops in-game); cleared once shown.
static var pending_error: StringName = &""

var net: Object = Net
var game: Object = Game
## For tests: if set, Quit calls this instead of quitting the game.
var quit_override: Callable
## For tests: () -> String; if set, Paste reads this instead of the system clipboard.
var clipboard_getter: Callable

var state: State = State.IDLE
## Time (s) spent in STARTING.
var _starting_elapsed: float = 0.0

@onready var _form: Control = %Form
@onready var _connecting: Control = %Connecting
@onready var _name_edit: LineEdit = %NameEdit
@onready var _host_port_edit: LineEdit = %HostPortEdit
@onready var _vision_label: Label = %VisionLabel
@onready var _vision_option: OptionButton = %VisionOption
@onready var _vision_hint: Label = %VisionHint
@onready var _host_button: Button = %HostButton
@onready var _join_address_edit: LineEdit = %JoinAddressEdit
@onready var _join_port_edit: LineEdit = %JoinPortEdit
@onready var _paste_button: Button = %PasteButton
@onready var _advanced_button: Button = %AdvancedButton
@onready var _advanced_grid: Control = %AdvancedGrid
@onready var _host_invite: InvitePanel = %HostInvite
@onready var _join_button: Button = %JoinButton
@onready var _quit_button: Button = %QuitButton
@onready var _cancel_button: Button = %CancelButton
@onready var _connecting_label: Label = %ConnectingLabel
@onready var _error_panel: Control = %ErrorPanel
@onready var _error_label: Label = %ErrorLabel


## Switches to the main menu scene; with `error_key` the menu shows that error on open.
static func open(tree: SceneTree, error_key: StringName = &"") -> void:
	pending_error = error_key
	tree.change_scene_to_file(SCENE_PATH)


func _ready() -> void:
	ThemeTokens.apply(self)
	UiSfx.wire_buttons(self)
	_name_edit.max_length = MAX_NAME_LENGTH
	_host_port_edit.text = str(DEFAULT_PORT)
	_join_port_edit.text = str(DEFAULT_PORT)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _host_port_edit.grab_focus())
	_host_port_edit.text_submitted.connect(func(_t: String) -> void: _on_host_pressed())
	_join_address_edit.text_submitted.connect(_on_address_submitted)
	_join_port_edit.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	_paste_button.pressed.connect(_on_paste_pressed)
	_advanced_button.toggled.connect(_on_advanced_toggled)
	_host_port_edit.text_changed.connect(_on_host_port_changed)
	_host_invite.focus_layout_changed.connect(_setup_focus)
	_restore_settings()
	net.connect(&"connected_to_host", _on_connected_to_host)
	net.connect(&"connection_failed", _on_connection_failed)
	net.connect(&"host_disconnected", _on_host_disconnected)
	game.connect(&"level_loaded", _on_level_loaded)
	_setup_vision()
	for edit: LineEdit in [_name_edit, _host_port_edit, _join_address_edit, _join_port_edit]:
		UiInput.arrows_move_focus(edit)
	_setup_focus()
	_set_state(State.IDLE)
	_hide_error()
	if not pending_error.is_empty():
		_show_error(tr(pending_error))
		pending_error = &""
	_focus_first()


func _on_host_pressed() -> void:
	if state != State.IDLE:
		return
	var player_name: String = _valid_name()
	if player_name.is_empty():
		return
	var port: int = ConnectInfo.parse_port(_host_port_edit.text)
	if port < 0:
		_fail(&"MENU_ERROR_PORT_INVALID", _host_port_edit)
		return
	_hide_error()
	game.call(&"set_local_name", player_name)
	var err: int = net.call(&"host", port)
	if err != OK:
		_show_error(tr(&"MENU_ERROR_HOST_FAILED") % port)
		_host_port_edit.grab_focus()
		return
	if supports_vision():
		game.call(&"set_vision_mode", vision_mode())
	ConnectInfo.hosted_port = port
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: player_name})
	_set_state(State.STARTING)
	_connecting_label.text = tr(&"MENU_STARTING")
	game.call(&"start_level", Game.DEFAULT_LEVEL)


func _process(delta: float) -> void:
	advance(delta)


## Advances the timed state by `delta` seconds: on the host the session is closed if the level does not load in time.
func advance(delta: float) -> void:
	if state != State.STARTING:
		return
	_starting_elapsed += delta
	if _starting_elapsed >= START_TIMEOUT_SEC:
		net.call(&"leave")
		_back_to_form(&"MENU_ERROR_START_FAILED", _host_button)


## Whether Game has the vision-mode rule (S3 addendum); the picker is hidden if not.
func supports_vision() -> bool:
	return game.has_method(&"vision_mode") and game.has_method(&"set_vision_mode")


## Selected vision mode.
func vision_mode() -> int:
	return _vision_option.get_selected_id()


func _setup_vision() -> void:
	var shown: bool = supports_vision()
	_vision_label.visible = shown
	_vision_option.visible = shown
	_vision_hint.visible = shown
	if not shown:
		return
	for mode: int in VISION_KEYS:
		_vision_option.add_item(VISION_KEYS[mode], mode)
	# Default from Game (data/vision_tuning.tres); first option on an unknown value.
	var index: int = _vision_option.get_item_index(int(game.call(&"vision_mode")))
	_vision_option.select(maxi(index, 0))


func _on_join_pressed() -> void:
	if state != State.IDLE:
		return
	var player_name: String = _valid_name()
	if player_name.is_empty():
		return
	# Single parser (ConnectInfo): a port in the address wins over the Advanced port.
	var text: String = _join_address_edit.text.strip_edges()
	if text.is_empty():
		_fail(&"MENU_ERROR_ADDRESS_EMPTY", _join_address_edit)
		return
	var port_in_address: bool = text.count(":") == 1
	var field_port: int = ConnectInfo.parse_port(_join_port_edit.text)
	if not port_in_address and field_port < 0:
		# A bad port focuses Advanced if it is open, else the visible address field.
		_fail(&"MENU_ERROR_PORT_INVALID", _join_port_edit if _advanced_grid.visible else _join_address_edit)
		return
	var target: Dictionary = ConnectInfo.parse_host_port(text, field_port)
	var address: String = target["address"]
	var port: int = target["port"]
	if not target["ok"]:
		var port_bad: bool = port_in_address and port < 0 and ConnectInfo.is_valid_host(address)
		_fail(&"MENU_ERROR_PORT_INVALID" if port_bad else &"MENU_ERROR_ADDRESS_INVALID", _join_address_edit)
		return
	_hide_error()
	game.call(&"set_local_name", player_name)
	var err: int = net.call(&"join", address, port)
	if err != OK:
		_fail(&"MENU_ERROR_JOIN_FAILED", _join_address_edit)
		return
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: player_name,
		ConnectInfo.KEY_ADDRESS: ConnectInfo.format_address(address, port)})
	_set_state(State.CONNECTING)
	_connecting_label.text = tr(&"MENU_CONNECTING") % [address, port]


## Enter in the address field: join directly if the port is hidden, move to the port if "Advanced" is open.
func _on_address_submitted(_text: String) -> void:
	if _advanced_grid.visible:
		_join_port_edit.grab_focus()
	else:
		_on_join_pressed()


## Takes "address[:port]" from the clipboard (the first IPv4[:port] inside the text also works); shows an error if none.
func _on_paste_pressed() -> void:
	if state != State.IDLE:
		return
	var found: Dictionary = ConnectInfo.find_invite(_read_clipboard())
	if not found["ok"]:
		_fail(&"MENU_ERROR_PASTE_INVALID", _paste_button)
		return
	_hide_error()
	_join_address_edit.text = ConnectInfo.format_address(found["address"], found["port"])
	_join_button.grab_focus()


func _read_clipboard() -> String:
	if clipboard_getter.is_valid():
		return str(clipboard_getter.call())
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return DisplayServer.clipboard_get()
	return ""


func _on_advanced_toggled(open: bool) -> void:
	_advanced_grid.visible = open
	_setup_focus()


func _on_host_port_changed(text: String) -> void:
	var port: int = ConnectInfo.parse_port(text)
	_host_invite.port = port if port > 0 else DEFAULT_PORT


## The last session's name and joined address fill the fields (fields stay empty if the file is missing/corrupt).
func _restore_settings() -> void:
	var saved: Dictionary = ConnectInfo.load_settings()
	_name_edit.text = saved[ConnectInfo.KEY_NAME]
	_join_address_edit.text = saved[ConnectInfo.KEY_ADDRESS]


func _on_cancel_pressed() -> void:
	if state == State.IDLE:
		return
	var was_hosting: bool = state == State.STARTING
	net.call(&"leave")
	_set_state(State.IDLE)
	(_host_button if was_hosting else _join_button).grab_focus()


func _on_quit_pressed() -> void:
	if quit_override.is_valid():
		quit_override.call()
	else:
		get_tree().quit()


func _on_connected_to_host() -> void:
	if state == State.CONNECTING:
		_set_state(State.CONNECTED)
		_connecting_label.text = tr(&"MENU_CONNECTED")


func _on_connection_failed() -> void:
	_back_to_form(&"MENU_ERROR_CONNECTION_FAILED")


func _on_host_disconnected() -> void:
	_back_to_form(&"MENU_ERROR_HOST_DISCONNECTED")


func _on_level_loaded(_level: Node) -> void:
	set_process(false)  # the timeout no longer applies
	queue_free()


## Returns to the form with an error; focus goes to `focus` (Join if not given).
func _back_to_form(error_key: StringName, focus: Control = null) -> void:
	_set_state(State.IDLE)
	_show_error(tr(error_key))
	(focus if focus != null else _join_button).grab_focus()


func _valid_name() -> String:
	var player_name: String = _name_edit.text.strip_edges().left(MAX_NAME_LENGTH)
	if player_name.is_empty():
		_fail(&"MENU_ERROR_NAME_EMPTY", _name_edit)
	return player_name


func _fail(error_key: StringName, focus: Control) -> void:
	_show_error(tr(error_key))
	focus.grab_focus()


func _show_error(text: String) -> void:
	_error_label.text = text
	_error_panel.show()


func _hide_error() -> void:
	_error_label.text = ""
	_error_panel.hide()


func _set_state(value: State) -> void:
	state = value
	_starting_elapsed = 0.0
	var busy: bool = value != State.IDLE
	_form.visible = not busy
	_connecting.visible = busy
	# If the level hangs the host can give up too (without waiting for the timeout).
	_cancel_button.visible = busy
	if busy:
		_hide_error()
		_cancel_button.grab_focus()


## On first open: name field; Join if a name and last address are remembered (one-key join), Host if only a name.
func _focus_first() -> void:
	if _name_edit.text.strip_edges().is_empty():
		_name_edit.grab_focus()
	elif not _join_address_edit.text.strip_edges().is_empty():
		_join_button.grab_focus()
	else:
		_host_button.grab_focus()


## Focus order (AC6): two columns (Host | Join); name on top, Quit at the bottom. Rows: invite <-> address,
## host port [<-> vision] <-> Advanced, (if Advanced is open) join port <- host port/vision, Host <-> Join.
## The vision picker shares the host-port row (IS-078, space at 720p): reached by left/right and Tab, not the vertical chain.
## Only visible items are linked; rebuilt when "Advanced" toggles (or the invite section changes).
func _setup_focus() -> void:
	var invite: Array[Control] = _host_invite.focus_controls()
	var invite_last: Control = invite[invite.size() - 1]
	var vision: bool = _vision_option.visible
	# Right end of the host-port row: vision if visible, else the port.
	var port_row_end: Control = _vision_option if vision else _host_port_edit
	var left: Array[Control] = [_name_edit]
	left.append_array(invite)
	left.append_array([_host_port_edit, _host_button, _quit_button] as Array[Control])
	var right: Array[Control] = [_join_address_edit, _advanced_button]
	if _advanced_grid.visible:
		right.append(_join_port_edit)
	right.append(_join_button)
	var ring: Array[Control] = [_name_edit]
	ring.append_array(invite)
	ring.append(_host_port_edit)
	if vision:
		ring.append(_vision_option)
	ring.append_array([_host_button, _join_address_edit, _paste_button, _advanced_button] as Array[Control])
	if _advanced_grid.visible:
		ring.append(_join_port_edit)
	ring.append_array([_join_button, _quit_button] as Array[Control])
	UiInput.tab_ring(ring)
	UiInput.vertical(left)
	UiInput.vertical(right, false)
	UiInput.link(_join_address_edit, SIDE_TOP, _name_edit)
	UiInput.link(_join_button, SIDE_BOTTOM, _quit_button)
	for c: Control in invite:
		UiInput.link(c, SIDE_RIGHT, _join_address_edit)
	UiInput.link(_join_address_edit, SIDE_LEFT, invite_last)
	UiInput.link(_join_address_edit, SIDE_RIGHT, _paste_button)
	# Paste shares the address row: left is the address, up the name, down Advanced.
	UiInput.link(_paste_button, SIDE_LEFT, _join_address_edit)
	UiInput.link(_paste_button, SIDE_TOP, _name_edit)
	UiInput.link(_paste_button, SIDE_BOTTOM, _advanced_button)
	# Host-port row: port -> [vision ->] Advanced; same path in reverse.
	UiInput.link(_host_port_edit, SIDE_RIGHT, _vision_option if vision else _advanced_button)
	UiInput.link(_advanced_button, SIDE_LEFT, port_row_end)
	UiInput.link(_join_port_edit, SIDE_LEFT, port_row_end)
	if vision:
		UiInput.link(_vision_option, SIDE_LEFT, _host_port_edit)
		UiInput.link(_vision_option, SIDE_RIGHT, _advanced_button)
		UiInput.link(_vision_option, SIDE_TOP, invite_last)
		UiInput.link(_vision_option, SIDE_BOTTOM, _host_button)
	UiInput.link(_host_button, SIDE_RIGHT, _join_button)
	UiInput.link(_join_button, SIDE_LEFT, _host_button)
	UiInput.vertical([_cancel_button])
