class_name UiInput
extends RefCounted
## Arayüz girdisi yardımcıları: odak sırası, duraklatma olayları (US-003 AC3, AC6), etkin cihaza göre
## tuş adı (istemler için) ve oyun içi menü açıkken oyun girdisi engeli (S5).
## Gamepad ile onay/geri project.godot'taki ui_accept (+A) ve ui_cancel (+B) eşlemelerinden gelir (S5, IS-009).

## Duraklat menüsünü açan/kapatan eylem (S5: Esc + gamepad Start).
const PAUSE_ACTION := &"pause"
## İstemlerde gösterilen gamepad düğme adları (Xbox düzeni); listede olmayan düğme numarasıyla gösterilir.
const JOY_BUTTON_LABELS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
}
## Bu eşiğin altındaki çubuk hareketi cihaz değişimi sayılmaz (çubuk kayması).
const JOY_AXIS_DEVICE_THRESHOLD := 0.5

## Son anlamlı girdi gamepad'den mi geldi (istem tuş adı buna göre seçilir).
static var using_gamepad: bool = false
## Oyun girdisini engelleyen görünür menüler: instance_id -> true.
static var _gameplay_blockers: Dictionary = {}


## S5: oyun içi menü açıkken PlayerInput oyun girdisi okumaz. Her karede çağrılır; menü yokken tek sözlük kontrolü.
static func is_gameplay_input_blocked() -> bool:
	if _gameplay_blockers.is_empty():
		return false
	for id: int in _gameplay_blockers.keys():
		if not is_instance_id_valid(id):
			_gameplay_blockers.erase(id)  # güvenlik: ağaçtan çıkmadan serbest kalan menü
	return not _gameplay_blockers.is_empty()


## `menu` ağaçta ve görünür olduğu sürece oyun girdisini engeller. Oyun içi her menü (duraklat, ileride
## dükkân, plan masası) kendini bununla bir kez kaydeder; gizlenince ya da ağaçtan çıkınca engel kalkar.
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


## Son girdinin cihazını kaydeder; cihaz değiştiyse true.
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


## Eylemin etkin cihazdaki tuş adı (klavye "E", gamepad "A"); o cihazda eşleme yoksa diğerininki, hiç yoksa boş.
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


## Fiziksel tuşu kullanıcının klavye düzenindeki adına çevirir (headless'ta dönüşüm yok, QWERTY adı).
static func _key_name(e: InputEventKey) -> String:
	var code: Key = e.keycode
	if code == KEY_NONE:
		code = e.physical_keycode
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(code)


## Duraklat menüsünü açan olay: `pause` eylemi (Esc / gamepad Start). Gamepad B (ui_cancel) oyunda
## menü açmaz, yalnız açık menüyü kapatır (bkz. `is_pause_close_event`).
static func is_pause_open_event(event: InputEvent) -> bool:
	return event.is_action_pressed(PAUSE_ACTION, false, true)


## Açık duraklat menüsünü kapatan olay: `pause` (Esc / Start) ya da ui_cancel (Esc / gamepad B).
static func is_pause_close_event(event: InputEvent) -> bool:
	return is_pause_open_event(event) or event.is_action_pressed(&"ui_cancel", false, true)


## `from`un `side` yönündeki odak komşusunu `to` yapar.
static func link(from: Control, side: Side, to: Control) -> void:
	from.set_focus_neighbor(side, from.get_path_to(to))


## Tab / Shift+Tab sırası: listeyi halka olarak bağlar.
static func tab_ring(controls: Array[Control]) -> void:
	var n: int = controls.size()
	for i: int in n:
		var c: Control = controls[i]
		c.focus_next = c.get_path_to(controls[(i + 1) % n])
		c.focus_previous = c.get_path_to(controls[(i - 1 + n) % n])


## Dikey sıra: üst/alt komşuları bağlar; `wrap` ise son ile ilk birbirine bağlanır.
static func vertical(controls: Array[Control], wrap: bool = true) -> void:
	var n: int = controls.size()
	for i: int in n:
		if i + 1 < n or wrap:
			link(controls[i], SIDE_BOTTOM, controls[(i + 1) % n])
		if i > 0 or wrap:
			link(controls[i], SIDE_TOP, controls[(i - 1 + n) % n])


## Yazı alanında yukarı/aşağı ok tuşları imleci değil odağı taşısın (düzenleme kipinde LineEdit
## bunları yutar; gamepad yön tuşları zaten çalışır). Odak tanımlı komşuya gider.
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
