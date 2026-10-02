class_name PauseMenu
extends Control
## Duraklat menüsü (US-003 AC3): Devam / Ayrıl. Online oyunda ağaç durmaz; menü yalnız örtüdür,
## açıkken oyun girdisi engellenir (UiInput.is_gameplay_input_blocked, S5).
## Açıp kapama (Esc / gamepad B ya da Start) ve ayrılma akışı HUD'dadır (ui/hud.gd).

## "Ayrıl" seçildi.
signal leave_requested()

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	ThemeTokens.apply(self)
	UiSfx.wire_buttons(self)
	hide()
	UiInput.block_gameplay_while_visible(self)
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	UiInput.vertical([_resume_button, _leave_button])
	UiInput.tab_ring([_resume_button, _leave_button])


func open() -> void:
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
