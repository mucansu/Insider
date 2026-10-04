class_name InvitePanel
extends VBoxContainer
## Invite address section (US-026): "YOUR INVITE ADDRESS 100.x.y.z:7777 [Copy]". The address is ConnectInfo's first candidate (Tailscale > private LAN > 127.0.0.1);
## with several candidates the address button opens a dropdown and the chosen one is copied. Used on the main menu host card and the host's pause menu.
## Tests replace the address source and clipboard via `addresses_provider` / `clipboard_setter`; the "Copied" feedback advances with `advance()`.

## Focusable items changed (list opened/closed, candidate count changed): the parent screen refreshes its focus order.
signal focus_layout_changed()

## How long (s) "Copied" stays on the button.
const COPIED_SEC := 1.5
## Max addresses in the dropdown (so the card does not overflow on multi-interface machines).
const MAX_LISTED := 5

## Title row ("YOUR INVITE ADDRESS"); on the main menu the card description acts as the title.
@export var show_caption: bool = true
## Dropdown when there are several candidates; when closed only the first is shown (main menu, space limit at 720p).
@export var allow_list: bool = true

## () -> PackedStringArray: raw interface addresses (default IP.get_local_addresses).
var addresses_provider: Callable = IP.get_local_addresses
## (text: String) -> void: writes to the clipboard; defaults to the DisplayServer clipboard (if supported).
var clipboard_setter: Callable
## Port shown in the invite.
var port: int = ConnectInfo.DEFAULT_PORT:
	set(value):
		port = value
		if is_node_ready():
			_show_selected()

var _candidates: PackedStringArray = []
var _selected: int = 0
var _copied_left: float = 0.0

@onready var _address_label: Label = %AddressLabel
@onready var _address_button: Button = %AddressButton
@onready var _copy_button: Button = %CopyButton
@onready var _note: Label = %NoteLabel
@onready var _list: VBoxContainer = %AddressList
@onready var _caption: Label = %Caption


func _ready() -> void:
	_caption.visible = show_caption
	_copy_button.pressed.connect(copy)
	_address_button.toggled.connect(_on_address_toggled)
	refresh()


func _process(delta: float) -> void:
	advance(delta)


## Re-reads address candidates; selection returns to the first and the list closes.
func refresh() -> void:
	_candidates = ConnectInfo.invite_candidates(addresses_provider.call() as PackedStringArray)
	if _candidates.size() > MAX_LISTED:
		_candidates = _candidates.slice(0, MAX_LISTED)
	_selected = 0
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for i: int in _candidates.size():
		var b := Button.new()
		b.name = "Address%d" % i
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_choose.bind(i))
		_list.add_child(b)
	# List buttons rebuilt after the screen sound was set up also get sound (IS-078).
	var sfx: UiSfx = UiSfx.find_for(self)
	if sfx != null:
		for b: Node in _list.get_children():
			UiSfx.wire_button(b as BaseButton, sfx)
	var multiple: bool = allow_list and _candidates.size() > 1
	_address_button.visible = multiple
	_address_label.visible = not multiple
	_address_button.set_pressed_no_signal(false)
	_list.hide()
	_show_selected()
	focus_layout_changed.emit()


func candidates() -> PackedStringArray:
	return _candidates


func selected_address() -> String:
	return _candidates[_selected] if _selected < _candidates.size() else ConnectInfo.LOOPBACK


## Invite to send: "address:port".
func invite_text() -> String:
	return ConnectInfo.invite_text(selected_address(), port)


## Writes the invite to the clipboard; the button briefly shows "Copied".
func copy() -> void:
	if clipboard_setter.is_valid():
		clipboard_setter.call(invite_text())
	elif DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(invite_text())
	_copied_left = COPIED_SEC
	_copy_button.text = "MENU_INVITE_COPIED"


func is_list_open() -> bool:
	return _list.visible


## Visible focusable items, top to bottom.
func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	if _address_button.visible:
		out.append(_address_button)
		if _list.visible:
			for b: Node in _list.get_children():
				out.append(b as Control)
	out.append(_copy_button)
	return out


func advance(delta: float) -> void:
	if _copied_left <= 0.0:
		return
	_copied_left -= delta
	if _copied_left <= 0.0:
		_copy_button.text = "MENU_INVITE_COPY"


func _show_selected() -> void:
	var text: String = invite_text()
	_address_label.text = text
	_address_button.text = tr(&"MENU_INVITE_CHOICE") % [text, _candidates.size() - 1]
	for i: int in _list.get_child_count():
		(_list.get_child(i) as Button).text = ConnectInfo.invite_text(_candidates[i], port)
	_note.visible = not ConnectInfo.is_tailscale(selected_address())


func _on_address_toggled(open: bool) -> void:
	_list.visible = open
	focus_layout_changed.emit()
	if open and _list.get_child_count() > 0:
		(_list.get_child(_selected) as Control).grab_focus()


func _choose(index: int) -> void:
	_selected = index
	_address_button.set_pressed_no_signal(false)
	_list.hide()
	_show_selected()
	focus_layout_changed.emit()
	copy()
	_copy_button.grab_focus()
