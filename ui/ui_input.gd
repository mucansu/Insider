class_name UiInput
extends RefCounted
## UI input helpers: focus order, pause events (US-003 AC3, AC6), key name by active device (for prompts),
## and the gameplay-input block while an in-game menu is open (S5). Gamepad accept/back come from project.godot's ui_accept (+A) and ui_cancel (+B) (S5, IS-009).

## Action that opens/closes the pause menu (S5: Esc + gamepad Start).
const PAUSE_ACTION := &"pause"
## Gamepad button names shown in prompts (Xbox layout); buttons not listed show their index.
const JOY_BUTTON_LABELS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
}
## Stick movement below this does not count as a device change (stick drift).
const JOY_AXIS_DEVICE_THRESHOLD := 0.5

## Whether the last meaningful input came from a gamepad (picks the prompt key name).
static var using_gamepad: bool = false
## Visible menus blocking gameplay input: instance_id -> true.
static var _gameplay_blockers: Dictionary = {}


## S5: PlayerInput reads no gameplay input while an in-game menu is open. Called every frame; one dictionary check when no menu.
static func is_gameplay_input_blocked() -> bool:
	if _gameplay_blockers.is_empty():
		return false
	for id: int in _gameplay_blockers.keys():
		if not is_instance_id_valid(id):
			_gameplay_blockers.erase(id)  # safety: a menu freed without leaving the tree
	return not _gameplay_blockers.is_empty()


## Blocks gameplay input while `menu` is in the tree and visible. Every in-game menu (pause, later shop, planning table) registers itself once;
## the block lifts when it hides or leaves the tree.
static func block_gameplay_while_visible(menu: CanvasItem) -> void:
	var update := func() -> void:
		_set_gameplay_blocker(menu, menu.is_inside_tree() and menu.is_visible_in_tree())
	menu.visibility_changed.connect(update)
	menu.tree_entered.connect(update)
	menu.tree_exiting.connect(func() -> void: _set_gameplay_blocker(menu, false))
	update.call()


static func _set_gameplay_blocker(menu: Object, blocking: bool) -> void:
	if blocking:
		_gameplay_blockers[menu.get_instance_id()] = true
	else:
		_gameplay_blockers.erase(menu.get_instance_id())


## Records the device of the last input; true if the device changed.
static func note_input(event: InputEvent) -> bool:
	var pad: bool
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < JOY_AXIS_DEVICE_THRESHOLD:
			return false
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	else:
		return false
	var changed: bool = pad != using_gamepad
	using_gamepad = pad
	return changed


## Key name of the action on the active device (keyboard "E", gamepad "A"); falls back to the other device, else empty.
static func action_hint(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	var key_hint: String = ""
	var pad_hint: String = ""
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey and key_hint.is_empty():
			key_hint = _key_name(e as InputEventKey)
		elif e is InputEventJoypadButton and pad_hint.is_empty():
			var button: int = (e as InputEventJoypadButton).button_index
			pad_hint = JOY_BUTTON_LABELS.get(button, str(button))
	if using_gamepad:
		return pad_hint if not pad_hint.is_empty() else key_hint
	return key_hint if not key_hint.is_empty() else pad_hint


## Converts a physical key to its name in the user's keyboard layout (no conversion headless; QWERTY name).
static func _key_name(e: InputEventKey) -> String:
	var code: Key = e.keycode
	if code == KEY_NONE:
		code = e.physical_keycode
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(code)


## Event that opens the pause menu: the `pause` action (Esc / gamepad Start). Gamepad B (ui_cancel) does not open a menu in-game,
## it only closes an open one (see `is_pause_close_event`).
static func is_pause_open_event(event: InputEvent) -> bool:
	return event.is_action_pressed(PAUSE_ACTION, false, true)


## Event that closes an open pause menu: `pause` (Esc / Start) or ui_cancel (Esc / gamepad B).
static func is_pause_close_event(event: InputEvent) -> bool:
	return is_pause_open_event(event) or event.is_action_pressed(&"ui_cancel", false, true)


## Sets `to` as the focus neighbour of `from` in direction `side`.
static func link(from: Control, side: Side, to: Control) -> void:
	from.set_focus_neighbor(side, from.get_path_to(to))


## Tab / Shift+Tab order: links the list as a ring.
static func tab_ring(controls: Array[Control]) -> void:
	var n: int = controls.size()
	for i: int in n:
		var c: Control = controls[i]
		c.focus_next = c.get_path_to(controls[(i + 1) % n])
		c.focus_previous = c.get_path_to(controls[(i - 1 + n) % n])


## Vertical order: links up/down neighbours; with `wrap` the last links to the first.
static func vertical(controls: Array[Control], wrap: bool = true) -> void:
	var n: int = controls.size()
	for i: int in n:
		if i + 1 < n or wrap:
			link(controls[i], SIDE_BOTTOM, controls[(i + 1) % n])
		if i > 0 or wrap:
			link(controls[i], SIDE_TOP, controls[(i - 1 + n) % n])


## Make up/down arrows in a text field move focus, not the caret (LineEdit swallows them in edit mode;
## gamepad d-pad already works). Focus goes to the defined neighbour.
static func arrows_move_focus(edit: LineEdit) -> void:
	edit.gui_input.connect(func(event: InputEvent) -> void:
		for side: Side in [SIDE_TOP, SIDE_BOTTOM]:
			var action: StringName = &"ui_up" if side == SIDE_TOP else &"ui_down"
			if not event.is_action_pressed(action, true):
				continue
			var target: Control = edit.get_node_or_null(edit.get_focus_neighbor(side)) as Control
			if target != null and target.is_visible_in_tree():
				edit.accept_event()
				target.grab_focus()
			return
	)
