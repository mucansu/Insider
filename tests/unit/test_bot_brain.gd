extends TestCase
## IS-015a: bot brain wiring - Args (--brain, --seed, --quit-on-heist-end, --brain with --bot error), brain bot file spec, BotBrain
## selection from the arguments, dump section and PlayerInput's BRAIN source (the timeline source is unchanged).

const ArgsScript := preload("res://autoload/args.gd")
const Smoke := preload("res://tests/unit/test_smoke.gd")
const SPEC_FILE := "user://test_bot_brain_spec.json"


## tests/contracts.gd "BotBrain" lines (IS-015b interface) match the script verbatim; Args lines are checked by test_smoke.
func test_contract_surface() -> void:
	var problems: PackedStringArray = Smoke.contract_problems("BotBrain", load("res://entities/player/bot_brain.gd") as Script)
	is_true(problems.is_empty(), "BotBrain sözleşmesinde eksik ya da farklı: %s" % ", ".join(problems))
	var args_problems: PackedStringArray = Smoke.contract_problems("Args", ArgsScript)
	is_true(args_problems.is_empty(), "Args sözleşmesinde eksik ya da farklı: %s" % ", ".join(args_problems))


func _make() -> ArgsScript:
	return autofree(ArgsScript.new()) as ArgsScript


func _write(path: String, data: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _remove(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_args_brain_seed_and_quit_on_heist_end() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--host", "--brain=Window+Bag", "--seed=-7", "--quit-on-heist-end=2.5", "--filter=x"]))
	eq(a.brain, "window+bag", "küçük harfe çevrilir")
	eq(a.run_seed, -7)
	is_true(a.run_seed_given)
	eq(a.quit_on_heist_end, 2.5)
	eq(a.unknown, PackedStringArray(["--filter=x"]), "tanınanlar unknown'dan çekilir")
	a.parse(PackedStringArray(["--host"]))
	eq(a.brain, "", "varsayılan: beyin yok")
	eq(a.run_seed, 0)
	is_false(a.run_seed_given)
	eq(a.quit_on_heist_end, -1.0, "varsayılan kapalı")


func test_args_bad_values_keep_defaults() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--brain=sneaky", "--seed=abc", "--quit-on-heist-end=-1"]))
	eq(a.brain, "", "geçersiz strateji")
	is_false(a.run_seed_given, "geçersiz tohum")
	eq(a.quit_on_heist_end, -1.0, "negatif süre")
	a.parse(PackedStringArray(["--quit-on-heist-end=0"]))
	eq(a.quit_on_heist_end, 0.0, "0 = iş biter bitmez")


func test_brain_with_bot_is_an_error() -> void:
	allow_errors()
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--brain=rush", "--bot=res://tests/net/bots/walk_c1.json"]))
	eq(a.brain, "rush", "beyin kalır")
	eq(a.bot_path, "", "--bot yok sayılır")


func test_spec_from_bot_file() -> void:
	_write(SPEC_FILE, {"brain": "send+bag", "seed": 4, "steps": []})
	var spec: Dictionary = BotBrain.spec_from_file(SPEC_FILE)
	eq(spec, {"brain": "send+bag", "seed": 4})
	_write(SPEC_FILE, {"brain": "team", "steps": []})
	eq(BotBrain.spec_from_file(SPEC_FILE), {"brain": "team", "seed": 0}, "tohumsuz: 0")
	_write(SPEC_FILE, {"steps": [{"t": 0.0, "move": [1, 0]}]})
	eq(BotBrain.spec_from_file(SPEC_FILE), {}, "zaman çizelgesi dosyası beyin değil")
	_write(SPEC_FILE, {"brain": "nope", "steps": []})
	eq(BotBrain.spec_from_file(SPEC_FILE), {}, "geçersiz strateji (uyarı)")
	_remove(SPEC_FILE)
	eq(BotBrain.spec_from_file(SPEC_FILE), {}, "dosya yok")
	eq(BotBrain.spec_from_file(""), {})
	eq(Args.load_bot("res://tests/net/bots/brain_team.json"), [] as Array[Dictionary],
		"beyin bot dosyası zaman çizelgesi olarak boş (steps: [])")
	eq(BotBrain.spec_from_file("res://tests/net/bots/brain_team.json")["brain"], "team")


func test_from_args_prefers_brain_arg_and_seed_override() -> void:
	var saved: Array = [Args.brain, Args.run_seed, Args.run_seed_given, Args.bot_path]
	Args.brain = ""
	Args.run_seed = 0
	Args.run_seed_given = false
	Args.bot_path = ""
	is_false(BotBrain.requested(), "argümansız beyin yok")
	is_true(BotBrain.from_args() == null)
	_write(SPEC_FILE, {"brain": "distract", "seed": 9, "steps": []})
	Args.bot_path = SPEC_FILE
	is_true(BotBrain.requested(), "beyin bot dosyası")
	var from_file: BotBrain = BotBrain.from_args()
	eq(from_file.strategy(), "distract")
	eq(from_file.seed_value(), 9)
	Args.run_seed = 11
	Args.run_seed_given = true
	eq(BotBrain.from_args().seed_value(), 11, "--seed dosyadaki tohumu ezer")
	Args.bot_path = ""
	Args.brain = "buy"
	var from_arg: BotBrain = BotBrain.from_args()
	eq(from_arg.strategy(), "buy")
	eq(from_arg.seed_value(), 11)
	_remove(SPEC_FILE)
	Args.brain = saved[0]
	Args.run_seed = saved[1]
	Args.run_seed_given = saved[2]
	Args.bot_path = saved[3]


func test_dump_section_and_idle_without_player() -> void:
	var brain := BotBrain.new("window+bag", 3)
	brain.tick(null, 1, 1.0 / 60.0)
	eq(brain.move_vector(), Vector2.ZERO, "oyuncu yoksa girdi yok")
	is_false(brain.is_held(&"interact"))
	var dump: Dictionary = brain.dump_state()
	for key: String in ["strategy", "seed", "role", "phase", "phase_log", "stuck_s", "unsticks", "wait_timeouts", "retreats",
			"failures", "time_s"]:
		has(dump, key)
	eq(dump["strategy"], "window+bag")
	eq(dump["seed"], 3)
	eq(dump["phase"], "start")
	eq(dump["phase_log"], [])
	eq(dump["stuck_s"], 0.0)
	is_true(JSON.stringify(dump).length() > 0, "JSON'a yazılabilir")


func test_player_input_brain_source() -> void:
	var input := PlayerInput.new()
	input.set_multiplayer_authority(1)
	autofree(input)
	tree().root.add_child(input)
	var brain := BotBrain.new("rush", 1)
	input.use_brain(brain)
	eq(input.source(), PlayerInput.Source.BRAIN)
	eq(input.brain(), brain)
	input.poll(1.0 / 60.0)
	eq(input.move_vector(), Vector2.ZERO, "üst düğüm oyuncu değil: beyin boşta")
	is_false(input.is_held(&"interact"))
	input.use_bot(BotTimeline.new([{"t": 0.0, "move": Vector2(1, 0)}] as Array[Dictionary]))
	eq(input.source(), PlayerInput.Source.BOT, "zaman çizelgesi kaynağı aynen çalışır")
	is_true(input.brain() == null)
	input.poll(1.0 / 60.0)
	eq(input.move_vector(), Vector2(1, 0))
	input.use_brain(null)
	eq(input.source(), PlayerInput.Source.NONE)
