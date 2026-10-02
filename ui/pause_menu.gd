class_name PauseMenu
extends Control
## Duraklat menüsü (US-003 AC3): Devam / Ayrıl. Online oyunda ağaç durmaz; menü yalnız örtüdür,
## açıkken oyun girdisi engellenir (UiInput.is_gameplay_input_blocked, S5).
## Açıp kapama (Esc / gamepad B ya da Start) ve ayrılma akışı HUD'dadır (ui/hud.gd).
## US-026: host'ta davet adresi bölümü (InvitePanel, Kopyala) görünür; istemcide gizli.

## "Ayrıl" seçildi.
signal leave_requested()

## Host mu bilgisi buradan okunur (S1 is_host); testler sahte nesneyle değiştirir.
var net: Object = Net

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _invite: InvitePanel = %Invite


func _ready() -> void:
	ThemeTokens.apply(self)
	hide()
	UiInput.block_gameplay_while_visible(self)
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	_invite.focus_layout_changed.connect(_setup_focus)
	_invite.hide()
	_setup_focus()


func open() -> void:
	_invite.visible = bool(net.call(&"is_host"))
	if _invite.visible:
		_invite.port = ConnectInfo.session_port(Args.port)
		_invite.refresh()
	_setup_focus()
	show()
	_resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
	hide()


func is_open() -> bool:
	return visible


## Odak: (davet bölümü, host'ta) → Devam → Ayrıl, halka.
func _setup_focus() -> void:
	var order: Array[Control] = []
	if _invite.visible:
		order.append_array(_invite.focus_controls())
	order.append_array([_resume_button, _leave_button] as Array[Control])
	UiInput.vertical(order)
	UiInput.tab_ring(order)
