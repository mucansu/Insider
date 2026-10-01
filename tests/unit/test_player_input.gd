extends TestCase
## US-004 AC3: PlayerInput (S5 cihaz girdisi, S6 bot zaman çizelgesi) ve BotTimeline ayrıştırma/oynatma;
## `UiInput.is_gameplay_input_blocked()` true iken cihaz girdisi okunmaz, bot etkilenmez; uzak kopya girdi okumaz.

const BOT_FILE := "user://test_player_input_bot.json"


func _input_node(authority: int = 1) -> PlayerInput:
	var input := PlayerInput.new()
	input.set_multiplayer_authority(authority)
	autofree(input)
	tree().root.add_child(input)
	return input


func _release_all() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint", &"sneak"]:
		Input.action_release(action)


# --- BotTimeline ---

func test_bot_file_is_parsed_sorted_and_bad_steps_skipped() -> void:
	var text: String = JSON.stringify({"steps": [
		{"t": 1.0, "move": [0, 1]},
		{"t": 0.0, "move": [1, 0]},
		{"t": -1.0, "move": [1, 0]},
		{"t": 0.5, "move": [1]},
		{"t": 0.5, "hold": "sprint", "dur": 0.25},
		{"move": [0, 0]},
	]})
	var file: FileAccess = FileAccess.open(BOT_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var timeline: BotTimeline = BotTimeline.from_file(BOT_FILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BOT_FILE))
	eq(timeline.step_count(), 3, "t'siz, negatif t'li ve bozuk move'lu adımlar atlanır")
	timeline.advance(0.1)
	eq(timeline.move_vector(), Vector2(1, 0), "sıralı: t=0 adımı ilk")
	is_false(timeline.is_held(&"sprint"))
	timeline.advance(0.5)
	is_true(timeline.is_held(&"sprint"), "t=0,6: [0,5, 0,75) basılı")
	timeline.advance(0.2)
	is_false(timeline.is_held(&"sprint"), "t=0,8: bırakıldı")
	eq(timeline.move_vector(), Vector2(1, 0))
	timeline.advance(0.3)
	eq(timeline.move_vector(), Vector2(0, 1), "t=1,1: ikinci move")
	is_true(timeline.is_finished())


func test_missing_bot_file_gives_empty_timeline() -> void:
	var timeline: BotTimeline = BotTimeline.from_file("user://yok_bot.json")
	eq(timeline.step_count(), 0)
	timeline.advance(1.0)
	eq(timeline.move_vector(), Vector2.ZERO)


func test_bot_timeline_semantics() -> void:
	var timeline: BotTimeline = BotTimeline.from_raw([
		{"t": 0.0, "move": [3, 4]},
		{"t": 0.2, "press": "intimidate"},
		{"t": 0.2, "hold": "sneak"},
		{"t": 0.4, "move": [0, 0]},
		{"t": 0.4, "game": "add_team_cash", "args": [1]},
	])
	timeline.advance(0.1)
	near(timeline.move_vector(), Vector2(0.6, 0.8), 0.0001, "move uzunluğu 1'e kırpılır")
	is_false(timeline.is_just_pressed(&"intimidate"))
	timeline.advance(0.1)
	is_true(timeline.is_just_pressed(&"intimidate"), "press uygulandığı adımda yeni basıldı")
	is_true(timeline.is_held(&"intimidate"))
	is_true(timeline.is_held(&"sneak"))
	timeline.advance(0.1)
	is_false(timeline.is_just_pressed(&"intimidate"), "press yalnız bir adım")
	is_false(timeline.is_held(&"intimidate"))
	is_true(timeline.is_held(&"sneak"), "dur'suz hold hep basılı")
	timeline.advance(0.2)
	eq(timeline.move_vector(), Vector2.ZERO)
	is_true(timeline.is_finished(), "bilinmeyen alanlı adım (fikstür 'game') yok sayılır ama tüketilir")


func test_bot_tick_advances_once_per_frame() -> void:
	var timeline := BotTimeline.from_raw([{"t": 0.15, "move": [1, 0]}])
	timeline.tick(10, 0.1)
	timeline.tick(10, 0.1)
	near(timeline.time(), 0.1, 0.0001, "aynı karede ikinci tick ilerletmez")
	eq(timeline.move_vector(), Vector2.ZERO)
	timeline.tick(11, 0.1)
	eq(timeline.move_vector(), Vector2(1, 0))


# --- PlayerInput ---

func test_device_input_reads_actions() -> void:
	var input: PlayerInput = _input_node()
	eq(input.source(), PlayerInput.Source.DEVICE, "yerel + --bot yok -> cihaz")
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	Input.action_press(&"sprint")
	input.poll(1.0 / 60.0)
	_release_all()
	near(input.move_vector(), Vector2(1, -1).normalized(), 0.001, "8 yön: çapraz birim uzunlukta")
	is_true(input.is_held(&"sprint"))
	is_false(input.is_held(&"sneak"))
	Input.action_press(&"move_left", 0.5)
	input.poll(1.0 / 60.0)
	_release_all()
	is_true(input.move_vector().x < -0.2 and input.move_vector().x > -0.8, "analog kısmi: %s" % input.move_vector())


func test_device_input_blocked_while_menu_visible() -> void:
	var input: PlayerInput = _input_node()
	var menu: Control = autofree(Control.new()) as Control
	tree().root.add_child(menu)
	UiInput.block_gameplay_while_visible(menu)
	if not is_true(UiInput.is_gameplay_input_blocked(), "görünür menü engeller"):
		return
	Input.action_press(&"move_right")
	Input.action_press(&"sneak")
	input.poll(1.0 / 60.0)
	eq(input.move_vector(), Vector2.ZERO, "menü açıkken karakter yürümez")
	is_false(input.is_held(&"sneak"), "basılı eylemler bırakılmış sayılır")
	menu.hide()
	is_false(UiInput.is_gameplay_input_blocked())
	input.poll(1.0 / 60.0)
	_release_all()
	eq(input.move_vector(), Vector2(1, 0), "menü kapanınca girdi geri gelir")
	is_true(input.is_held(&"sneak"))


func test_bot_input_ignores_menu_block() -> void:
	var input: PlayerInput = _input_node()
	input.use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [0, 1]}, {"t": 0.0, "hold": "sprint"}]))
	var menu: Control = autofree(Control.new()) as Control
	tree().root.add_child(menu)
	UiInput.block_gameplay_while_visible(menu)
	is_true(UiInput.is_gameplay_input_blocked())
	input.poll(1.0 / 60.0)
	eq(input.source(), PlayerInput.Source.BOT)
	eq(input.move_vector(), Vector2(0, 1), "bot engelden etkilenmez")
	is_true(input.is_held(&"sprint"))


func test_remote_copy_reads_no_input() -> void:
	var input: PlayerInput = _input_node(2)
	eq(input.source(), PlayerInput.Source.NONE, "yetki başka peer'da -> girdi yok")
	Input.action_press(&"move_down")
	Input.action_press(&"sprint")
	input.poll(1.0 / 60.0)
	_release_all()
	eq(input.move_vector(), Vector2.ZERO)
	is_false(input.is_held(&"sprint"))
