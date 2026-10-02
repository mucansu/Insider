class_name MainMenu
extends Control
## Ana menü (US-003 AC1, AC6): oyuncu adı, host (port), katıl (adres + port), çıkış.
## Net/Game'e yalnız S1/S3 sözleşmesiyle bağlanır; testler `net` ve `game`'i sahneye eklemeden önce
## sahte nesnelerle değiştirir. Seviye yüklenince (`level_loaded`) menü kendini kaldırır; host'ta seviye
## START_TIMEOUT_SEC içinde yüklenmezse oturum kapatılıp forma hatayla dönülür (Vazgeç de aynı yolu açar).
## US-011c: host kartında görüş kipi seçimi (host'un oyun kuralı, GDD §6.5): Game S3 eki (mimari.md, US-011b/c) üyelerini
## (vision_mode(), set_vision_mode()) taşıyorsa görünür; seçim host açılınca seviye başlamadan Game'e iletilir.
## US-026: ad ve son katılınan adres ConnectInfo ayar dosyasından gelir ve host/katıl'da yazılır; host kartı
## davet adresini (Kopyala) gösterir; katıl kartında Yapıştır ve "Gelişmiş" altında port.

const SCENE_PATH := "res://ui/main_menu.tscn"
const DEFAULT_PORT := ConnectInfo.DEFAULT_PORT
const MIN_PORT := ConnectInfo.MIN_PORT
const MAX_PORT := ConnectInfo.MAX_PORT
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
## Testler için: () -> String; atanırsa Yapıştır sistem panosu yerine bunu okur.
var clipboard_getter: Callable

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
	# Tek ayrıştırıcı (ConnectInfo): adresteki port, Gelişmiş'teki porttan önce gelir.
	var text: String = _join_address_edit.text.strip_edges()
	if text.is_empty():
		_fail(&"MENU_ERROR_ADDRESS_EMPTY", _join_address_edit)
		return
	var port_in_address: bool = text.count(":") == 1
	var field_port: int = ConnectInfo.parse_port(_join_port_edit.text)
	if not port_in_address and field_port < 0:
		# Hatalı port yalnız Gelişmiş'teyse odak oraya; kapalıysa görünen alana (adres).
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


## Adres alanında Enter: port gizliyse doğrudan katıl, "Gelişmiş" açıksa porta geç.
func _on_address_submitted(_text: String) -> void:
	if _advanced_grid.visible:
		_join_port_edit.grab_focus()
	else:
		_on_join_pressed()


## Panodan "adres[:port]" alır (metnin içindeki ilk IPv4[:port] de olur); yoksa hata gösterir.
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


## Son oturumun adı ve katılınan adresi alanlara yazılır (dosya yoksa/bozuksa alanlar boş kalır).
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


## İlk açılışta ad alanı; ad ve son adres hatırlanıyorsa Katıl (tek tuşla katılım), yalnız ad varsa Host ol.
func _focus_first() -> void:
	if _name_edit.text.strip_edges().is_empty():
		_name_edit.grab_focus()
	elif not _join_address_edit.text.strip_edges().is_empty():
		_join_button.grab_focus()
	else:
		_host_button.grab_focus()


## Odak sırası (AC6): iki sütun (Host | Katıl); ad en üstte, Çıkış en altta. Satırlar: davet ↔ adres,
## host portu [↔ görüş] ↔ Gelişmiş, (Gelişmiş açıksa) Katıl portu ← host portu/görüş, Host ol ↔ Katıl.
## Görüş seçimi host portuyla aynı satırda (IS-078, 720p'de yer): dikey zincirde değil, sağ/sol ve Tab ile gelinir.
## Yalnız görünen öğeler bağlanır; "Gelişmiş" açılıp kapanınca (ya da davet bölümü değişince) yeniden kurulur.
func _setup_focus() -> void:
	var invite: Array[Control] = _host_invite.focus_controls()
	var invite_last: Control = invite[invite.size() - 1]
	var vision: bool = _vision_option.visible
	# Host portu satırının sağ ucu: görüş görünürse görüş, değilse port.
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
	# Yapıştır adres alanıyla aynı satırda: sol adres, yukarı ad, aşağı Gelişmiş.
	UiInput.link(_paste_button, SIDE_LEFT, _join_address_edit)
	UiInput.link(_paste_button, SIDE_TOP, _name_edit)
	UiInput.link(_paste_button, SIDE_BOTTOM, _advanced_button)
	# Host portu satırı: port → [görüş →] Gelişmiş; geri yönde aynı yol.
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
