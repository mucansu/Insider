extends TestCase
## IS-058b: brain loop wiring - `--brain-loop` (Args), bot file key "brain_loop", BotBrain.from_args, run reset (new Mind with seed +
## run index, memory and per-run counters cleared, previous run recorded) and the dump additions (omni, run, sight, runs).

const ArgsScript := preload("res://autoload/args.gd")
const SPEC_FILE := "user://test_bot_loop_spec.json"


func _write(path: String, data: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func test_args_brain_loop() -> void:
	var a: ArgsScript = autofree(ArgsScript.new()) as ArgsScript
	a.parse(PackedStringArray(["--host", "--brain=window+omni", "--brain-loop=4.5"]))
	eq(a.brain, "window+omni", "+omni geçerli strateji")
	eq(a.brain_loop, 4.5)
	a.parse(PackedStringArray(["--host"]))
	eq(a.brain_loop, -1.0, "varsayılan kapalı")
	a.parse(PackedStringArray(["--brain-loop=-2"]))
	eq(a.brain_loop, -1.0, "negatif: uyarı, kapalı")
	a.parse(PackedStringArray(["--brain-loop=0"]))
	eq(a.brain_loop, 0.0)


func test_spec_and_from_args_loop() -> void:
	_write(SPEC_FILE, {"brain": "rush", "seed": 2, "brain_loop": 3, "steps": []})
	eq(BotBrain.spec_from_file(SPEC_FILE), {"brain": "rush", "seed": 2, "brain_loop": 3.0})
	_write(SPEC_FILE, {"brain": "rush", "seed": 2, "brain_loop": -1, "steps": []})
	eq(BotBrain.spec_from_file(SPEC_FILE), {"brain": "rush", "seed": 2}, "geçersiz döngü yok sayılır")
	var saved: Array = [Args.brain, Args.run_seed, Args.run_seed_given, Args.bot_path, Args.brain_loop]
	Args.brain = ""
	Args.run_seed_given = false
	Args.brain_loop = -1.0
	_write(SPEC_FILE, {"brain": "rush", "seed": 2, "brain_loop": 3, "steps": []})
	Args.bot_path = SPEC_FILE
	eq(BotBrain.from_args().loop_s, 3.0, "bot dosyasından")
	Args.brain_loop = 1.5
	eq(BotBrain.from_args().loop_s, 1.5, "--brain-loop dosyayı ezer")
	Args.bot_path = ""
	Args.brain = "buy"
	Args.brain_loop = -1.0
	eq(BotBrain.from_args().loop_s, -1.0, "--brain, döngüsüz")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SPEC_FILE))
	Args.brain = saved[0]
	Args.run_seed = saved[1]
	Args.run_seed_given = saved[2]
	Args.bot_path = saved[3]
	Args.brain_loop = saved[4]


func test_dump_additions() -> void:
	var brain := BotBrain.new("team+omni", 3)
	is_true(brain.is_omni())
	is_false(BotBrain.new("team", 3).is_omni(), "varsayılan adil görüş")
	var dump: Dictionary = brain.dump_state()
	for key: String in ["omni", "run", "sight", "runs"]:
		has(dump, key)
	eq(dump["run"], 0)
	eq(dump["runs"], [])
	eq(dump["sight"], {"owner_seen_s": 0.0, "owner_sightings": 0})
	is_true(JSON.stringify(dump).length() > 0)


func test_next_run_resets_the_brain() -> void:
	var brain := BotBrain.new("window", 7)
	var first: BotRules.Mind = brain.mind()
	first.phase_log.append([1.0, "stage"])
	first.wait_timeouts = 1
	brain.call(&"_record_run", {"outcome": &"clean", "duration_s": 42.0})
	eq(brain.runs().size(), 1)
	eq(brain.runs()[0]["outcome"], "clean")
	eq(brain.runs()[0]["seed"], 7)
	eq(brain.runs()[0]["wait_timeouts"], 1)
	eq(brain.runs()[0]["duration_s"], 42.0)
	brain.call(&"_next_run")
	eq(brain.run_index(), 1)
	is_true(brain.mind() != first, "yeni Mind")
	eq(brain.mind().seed_value, 8, "koşu tohumu = tohum + koşu sırası")
	eq(brain.mind().phase_name(), "start")
	eq(brain.mind().phase_log, [])
	eq(brain.runs().size(), 1, "kayıtlı koşu tekrar yazılmaz")
	brain.call(&"_next_run")
	eq(brain.run_index(), 2)
	eq(brain.runs().size(), 2, "iş bitmeden seviye değişti")
	eq(brain.runs()[1]["outcome"], BotBrain.RUN_UNFINISHED)
	eq(brain.dump_state()["seed"], 7, "dökümdeki tohum taban tohum")
