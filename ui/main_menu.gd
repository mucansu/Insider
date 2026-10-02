class_name MainMenu
extends Control
## Ana menü (US-003 AC1, AC6): oyuncu adı, host (port), katıl (adres + port), çıkış.
## Net/Game'e yalnız S1/S3 sözleşmesiyle bağlanır; testler `net` ve `game`'i sahneye eklemeden önce
## sahte nesnelerle değiştirir. Seviye yüklenince (`level_loaded`) menü kendini kaldırır; host'ta seviye
## START_TIMEOUT_SEC içinde yüklenmezse oturum kapatılıp forma hatayla dönülür (Vazgeç de aynı yolu açar).
## US-011c: host kartında görüş kipi seçimi (host'un oyun kuralı, GDD §6.5): Game S3 eki (mimari.md, US-011b/c) üyelerini
## (vision_mode(), set_vision_mode()) taşıyorsa görünür; seçim host açılınca seviye başlamadan Game'e iletilir.

const SCENE_PATH := "res://ui/main_menu.tscn"
const DEFAULT_PORT := 7777
const MIN_PORT := 1024
const MAX_PORT := 65535
const MAX_NAME_LENGTH := 16
## Host'ta start_level sonrası level_loaded için beklenen en uzun süre (sn); sonra oturum kapatılır.
const START_TIMEOUT_SEC := 10.0
## Görüş kipleri (S3 eki `Game.vision_mode()` değerleri; mimari.md, US-011b/c): 0 çevresel 360°, 1 yönlü.
const VISION_OMNI := 0
const VISION_DIRECTIONAL := 1
## Kip -> seçenek metni (seçenek kimliği = kip).
const VISION_KEYS := {VISION_OMNI: "MENU_VISION_OMNI", VISION_DIRECTIONAL: "MENU_VISION_DIRECTIONAL"}

enum State { IDLE, CONNECTING, CONNECTED, STARTING }

## Menü açılınca gösterilecek hata anahtarı (ör. oyunda host kopunca HUD bırakır); gösterilince silinir.
static var pending_error: StringName = &""

var net: Object = Net
var game: Object = Game
## Testler için: atanırsa Çıkış oyunu kapatmak yerine bunu çağırır.
var quit_override: Callable

var state: State = State.IDLE
## STARTING durumunda geçen süre (sn).
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
@onready var _join_button: Button = %JoinButton
@onready var _quit_button: Button = %QuitButton
@onready var _cancel_button: Button = %CancelButton
@onready var _connecting_label: Label = %ConnectingLabel
@onready var _error_panel: Control = %ErrorPanel
@onready var _error_label: Label = %ErrorLabel


## Ana menü sahnesine geçer; `error_key` verilirse menü açılışta bu hatayı gösterir.
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
	_join_address_edit.text_submitted.connect(func(_t: String) -> void: _join_port_edit.grab_focus())
	_join_port_edit.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	net.connect(&"connected_to_host", _on_connected_to_host)
	net.connect(&"connection_failed", _on_connection_failed)
	net.connect(&"host_disconnected", _on_host_disconnected)
	game.connect(&"level_loaded", _on_level_loaded)
	_setup_vision()
	_setup_focus()
	_set_state(State.IDLE)
	_hide_error()
	if not pending_error.is_empty():
		_show_error(tr(pending_error))
		pending_error = &""
	_focus_first()


## "adres" ya da "adres:port" (IPv6 değilse); port yoksa `default_port`. Port geçersizse -1.
static func parse_address(text: String, default_port: int) -> Dictionary:
	var address: String = text.strip_edges()
	var port: int = default_port
	if address.count(":") == 1:
		var parts: PackedStringArray = address.split(":")
		address = parts[0].strip_edges()
		port = parse_port(parts[1])
	return {"address": address, "port": port}


## Geçerli port ya da -1.
static func parse_port(text: String) -> int:
	var t: String = text.strip_edges()
	if not t.is_valid_int():
		return -1
	var port: int = t.to_int()
	return port if port >= MIN_PORT and port <= MAX_PORT else -1


func _on_host_pressed() -> void:
	if state != State.IDLE:
		return
	var player_name: String = _valid_name()
	if player_name.is_empty():
		return
	var port: int = parse_port(_host_port_edit.text)
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
	_set_state(State.STARTING)
	_connecting_label.text = tr(&"MENU_STARTING")
	game.call(&"start_level", Game.DEFAULT_LEVEL)


func _process(delta: float) -> void:
	advance(delta)


## Zamanlı durumu `delta` saniye ilerletir: host'ta seviye süresinde yüklenmezse oturum kapatılır.
func advance(delta: float) -> void:
	if state != State.STARTING:
		return
	_starting_elapsed += delta
	if _starting_elapsed >= START_TIMEOUT_SEC:
		net.call(&"leave")
		_back_to_form(&"MENU_ERROR_START_FAILED", _host_button)


## Game görüş kipi kuralını (S3 eki; mimari.md, US-011b/c) taşıyor mu; taşımıyorsa seçim gizli.
func supports_vision() -> bool:
	return game.has_method(&"vision_mode") and game.has_method(&"set_vision_mode")


## Seçili görüş kipi.
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
	# Varsayılan Game'den (data/vision_tuning.tres); bilinmeyen değerde ilk seçenek.
	var index: int = _vision_option.get_item_index(int(game.call(&"vision_mode")))
	_vision_option.select(maxi(index, 0))


func _on_join_pressed() -> void:
	if state != State.IDLE:
		return
	var player_name: String = _valid_name()
	if player_name.is_empty():
		return
	var target: Dictionary = parse_address(_join_address_edit.text, parse_port(_join_port_edit.text))
	var address: String = target["address"]
	var port: int = target["port"]
	if address.is_empty():
		_fail(&"MENU_ERROR_ADDRESS_EMPTY", _join_address_edit)
		return
	if port < 0:
		_fail(&"MENU_ERROR_PORT_INVALID", _join_port_edit)
		return
	_hide_error()
	game.call(&"set_local_name", player_name)
	var err: int = net.call(&"join", address, port)
	if err != OK:
		_fail(&"MENU_ERROR_JOIN_FAILED", _join_address_edit)
		return
	_set_state(State.CONNECTING)
	_connecting_label.text = tr(&"MENU_CONNECTING") % [address, port]


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
	set_process(false)  # zaman aşımı artık işlemez
	queue_free()


## Forma hatayla döner; odak `focus`ta (verilmezse Katıl'da).
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
	# Seviye takılırsa host da vazgeçebilir (zaman aşımını beklemeden).
	_cancel_button.visible = busy
	if busy:
		_hide_error()
		_cancel_button.grab_focus()


func _focus_first() -> void:
	if _name_edit.text.strip_edges().is_empty():
		_name_edit.grab_focus()
	else:
		_host_button.grab_focus()


## Odak sırası (AC6): iki sütun (Host | Katıl); ad en üstte, Çıkış en altta. Görüş seçimi görünürse Host
## sütununda port ile Host arasında, sağında Katıl portu.
func _setup_focus() -> void:
	var host_column: Array[Control] = [_host_port_edit, _host_button]
	if _vision_option.visible:
		host_column.insert(1, _vision_option)
	var ring: Array[Control] = [_name_edit]
	ring.append_array(host_column)
	ring.append_array([_join_address_edit, _join_port_edit, _join_button, _quit_button])
	UiInput.tab_ring(ring)
	var column: Array[Control] = [_name_edit]
	column.append_array(host_column)
	column.append(_quit_button)
	UiInput.vertical(column)
	UiInput.vertical([_join_address_edit, _join_port_edit, _join_button], false)
	UiInput.link(_join_address_edit, SIDE_TOP, _name_edit)
	UiInput.link(_join_button, SIDE_BOTTOM, _quit_button)
	UiInput.link(_host_port_edit, SIDE_RIGHT, _join_address_edit)
	UiInput.link(_host_button, SIDE_RIGHT, _join_button)
	UiInput.link(_join_address_edit, SIDE_LEFT, _host_port_edit)
	UiInput.link(_join_port_edit, SIDE_LEFT, _host_port_edit)
	UiInput.link(_join_button, SIDE_LEFT, _host_button)
	if _vision_option.visible:
		UiInput.link(_vision_option, SIDE_RIGHT, _join_port_edit)
		UiInput.link(_join_port_edit, SIDE_LEFT, _vision_option)
	UiInput.vertical([_cancel_button])
	for edit: LineEdit in [_name_edit, _host_port_edit, _join_address_edit, _join_port_edit]:
		UiInput.arrows_move_focus(edit)
