extends TestCase
## UiInput (S5, US-003 t1): oyun içi menü açıkken oyun girdisi engeli; son girdi cihazı ve istem tuş adı.


func test_not_blocked_without_menus() -> void:
	is_false(UiInput.is_gameplay_input_blocked())


func test_block_follows_visibility_and_tree() -> void:
	var parent: Control = autofree(Control.new()) as Control
	var menu := Control.new()
	parent.add_child(menu)
	UiInput.block_gameplay_while_visible(menu)
	is_false(UiInput.is_gameplay_input_blocked(), "ağaç dışında engel yok")
	tree().root.add_child(parent)
	is_true(UiInput.is_gameplay_input_blocked(), "ağaçta ve görünür")
	menu.hide()
	is_false(UiInput.is_gameplay_input_blocked(), "gizli")
	menu.show()
	is_true(UiInput.is_gameplay_input_blocked())
	parent.hide()
	is_false(UiInput.is_gameplay_input_blocked(), "üstü gizlenince")
	parent.show()
	is_true(UiInput.is_gameplay_input_blocked())
	tree().root.remove_child(parent)
	is_false(UiInput.is_gameplay_input_blocked(), "ağaçtan çıkınca")
	tree().root.add_child(parent)
	is_true(UiInput.is_gameplay_input_blocked(), "geri girince")
	menu.free()
	is_false(UiInput.is_gameplay_input_blocked(), "açıkken serbest kalan menü engel bırakmaz")


func test_two_menus_block_until_both_close() -> void:
	var a: Control = autofree(Control.new()) as Control
	var b: Control = autofree(Control.new()) as Control
	for m: Control in [a, b]:
		tree().root.add_child(m)
		UiInput.block_gameplay_while_visible(m)
	a.hide()
	is_true(UiInput.is_gameplay_input_blocked(), "biri hâlâ açık")
	b.hide()
	is_false(UiInput.is_gameplay_input_blocked())


func test_stale_blocker_is_pruned() -> void:
	var obj := Object.new()
	UiInput._set_gameplay_blocker(obj, true)
	is_true(UiInput.is_gameplay_input_blocked())
	obj.free()
	is_false(UiInput.is_gameplay_input_blocked(), "geçersiz kimlik ayıklanır")


func test_device_tracking_and_action_hints() -> void:
	UiInput.using_gamepad = false
	eq(UiInput.action_hint(&"interact"), "E")
	eq(UiInput.action_hint(&"intimidate"), "Q")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	is_true(UiInput.note_input(a), "gamepad'e geçiş")
	eq(UiInput.action_hint(&"interact"), "A")
	eq(UiInput.action_hint(&"intimidate"), "X")
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.2
	is_false(UiInput.note_input(drift), "çubuk kayması cihaz değiştirmez")
	is_false(UiInput.note_input(InputEventMouseMotion.new()), "fare hareketi sayılmaz")
	is_true(UiInput.using_gamepad)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	is_true(UiInput.note_input(key), "klavyeye dönüş")
	is_false(UiInput.note_input(key), "aynı cihaz değişim değil")
	eq(UiInput.action_hint(&"interact"), "E")
	eq(UiInput.action_hint(&"no_such_action"), "")
	UiInput.using_gamepad = false
