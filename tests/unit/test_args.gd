extends TestCase
## Args (autoload/args.gd, S6) parsing and bot file reading (US-001 AC7).

const ArgsScript := preload("res://autoload/args.gd")


func _make() -> ArgsScript:
	return autofree(ArgsScript.new()) as ArgsScript


func test_parses_all_s6_arguments() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray([
		"--host", "--port=9100", "--name=Ayşe", "--level=res://tests/fixtures/empty_level.tscn",
		"--bot=res://tests/net/bots/move_host.json", "--dump=/tmp/x.json", "--quit-after=2.5",
		"--player-scene=res://tests/fixtures/dummy_player.tscn",
	]))
	is_true(a.want_host)
	eq(a.join_address, "")
	eq(a.port, 9100)
	eq(a.player_name, "Ayşe")
	eq(a.level, "res://tests/fixtures/empty_level.tscn")
	eq(a.bot_path, "res://tests/net/bots/move_host.json")
	eq(a.dump_path, "/tmp/x.json")
	near(a.quit_after, 2.5, 0.0001)
	eq(a.player_scene, "res://tests/fixtures/dummy_player.tscn")
	eq(a.unknown.size(), 0)
	is_true(a.wants_session())
	is_true(a.is_automated())


func test_join_and_defaults() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--join=192.168.1.20"]))
	is_false(a.want_host)
	eq(a.join_address, "192.168.1.20")
	eq(a.port, ArgsScript.DEFAULT_PORT)
	eq(a.port, 7777)
	is_true(a.wants_session())
	is_false(a.is_automated())
	# Re-parsing resets previous values.
	a.parse(PackedStringArray([]))
	eq(a.join_address, "")
	is_false(a.wants_session())
	eq(a.quit_after, 0.0)


func test_invalid_values_keep_defaults() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--port=99999", "--quit-after=abc", "--join", "--name="]))
	eq(a.port, 7777, "aralık dışı port varsayılanda kalır")
	eq(a.quit_after, 0.0)
	eq(a.join_address, "", "değersiz --join yok sayılır")
	eq(a.player_name, "")
	a.parse(PackedStringArray(["--port=0"]))
	eq(a.port, 7777)
	a.parse(PackedStringArray(["--port=12x"]))
	eq(a.port, 7777)


func test_unknown_arguments_are_collected() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--filter=test_net", "--timeout=5", "--host"]))
	eq(a.unknown, PackedStringArray(["--filter=test_net", "--timeout=5"]))
	is_true(a.want_host)


func test_host_wins_over_join() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--join=10.0.0.1", "--host"]))
	is_true(a.want_host)
	eq(a.join_address, "")


func test_value_with_equals_and_spaces() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--name= Bob=2 ", " --port=7000 "]))
	eq(a.player_name, "Bob=2")
	eq(a.port, 7000)


func test_load_bot_file() -> void:
	var steps: Array[Dictionary] = ArgsScript.load_bot("res://tests/net/bots/move_host.json")
	eq(steps.size(), 4)
	eq(typeof(steps[0]["t"]), TYPE_FLOAT)
	eq(steps[0]["move"], Vector2(1, 0))
	eq(steps[3]["move"], Vector2.ZERO)
	for i: int in range(1, steps.size()):
		is_true(float(steps[i - 1]["t"]) <= float(steps[i]["t"]), "adımlar t'ye göre sıralı")
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--bot=res://tests/net/bots/events_host.json"]))
	var events: Array[Dictionary] = a.bot_steps()
	eq(events.size(), 4)
	eq(events[0]["game"], "add_team_cash")
	a.parse(PackedStringArray([]))
	eq(a.bot_steps().size(), 0, "--bot yoksa boş")


func test_load_bot_missing_file_is_empty() -> void:
	eq(ArgsScript.load_bot("res://tests/net/bots/yok.json").size(), 0)


func test_parse_bot_step_validation() -> void:
	var ok: Dictionary = ArgsScript.parse_bot_step({"t": 1, "move": [0.5, -1], "dur": 2, "hold": "interact"})
	eq(ok["t"], 1.0)
	eq(ok["move"], Vector2(0.5, -1))
	eq(ok["dur"], 2.0)
	eq(ok["hold"], "interact")
	eq(ArgsScript.parse_bot_step({"t": 2.0, "press": "intimidate"})["press"], "intimidate")
	is_true(ArgsScript.parse_bot_step({"move": [1, 0]}).is_empty(), "t zorunlu")
	is_true(ArgsScript.parse_bot_step({"t": -1.0}).is_empty(), "negatif t")
	is_true(ArgsScript.parse_bot_step({"t": "1"}).is_empty(), "t sayı olmalı")
	is_true(ArgsScript.parse_bot_step({"t": 0.0, "move": [1]}).is_empty(), "move iki bileşenli")
	is_true(ArgsScript.parse_bot_step({"t": 0.0, "move": ["a", 0]}).is_empty())
	is_true(ArgsScript.parse_bot_step({"t": 0.0, "dur": -2}).is_empty())
	is_true(ArgsScript.parse_bot_step([1, 2]).is_empty())


func test_autoload_reads_process_arguments() -> void:
	# The test runner starts with user arguments (e.g. --filter); the autoload counts them as unrecognised.
	is_false(Args.wants_session())
	for raw: String in OS.get_cmdline_user_args():
		has(Args.unknown, raw)
