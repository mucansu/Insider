extends TestCase
## Cosmetic footsteps (US-047 AC2): FootstepRules gait/event/cadence (walk -> walk_step, sprint -> run_step on the 0.35 s noise cadence,
## sneak and standing silent), FootstepEmitter on a fake character (remote-style fields) and on the real player scene; steps never reach
## NoiseBus.


## Character stand-in exposing the player's movement contract (`move_mode`, `velocity`), like a remote copy.
class FakeMover extends Node2D:
	var move_mode: int = PlayerMotion.Mode.WALK
	var velocity: Vector2 = Vector2.ZERO


func _run(cadence: FootstepRules.Cadence, gait: FootstepRules.Gait, seconds: float, step: float = 1.0 / 60.0) -> Array[StringName]:
	var out: Array[StringName] = []
	var t: float = 0.0
	while t < seconds - 0.00001:
		var ev: StringName = cadence.tick(step, gait)
		if not ev.is_empty():
			out.append(ev)
		t += step
	return out


func test_gait_from_mode_and_speed() -> void:
	eq(FootstepRules.gait_for(false, false, 140.0), FootstepRules.Gait.WALK)
	eq(FootstepRules.gait_for(false, true, 220.0), FootstepRules.Gait.RUN)
	eq(FootstepRules.gait_for(true, false, 70.0), FootstepRules.Gait.SNEAK)
	eq(FootstepRules.gait_for(true, true, 70.0), FootstepRules.Gait.SNEAK, "sızma koşuya baskın (PlayerMotion.mode_for)")
	eq(FootstepRules.gait_for(false, true, 10.0), FootstepRules.Gait.STILL, "duvara koşmak/durmak adım değil")
	eq(FootstepRules.gait_for(false, false, FootstepRules.MIN_SPEED - 1.0), FootstepRules.Gait.STILL)


func test_events_per_gait() -> void:
	eq(FootstepRules.event_for(FootstepRules.Gait.WALK), &"walk_step")
	eq(FootstepRules.event_for(FootstepRules.Gait.RUN), &"run_step")
	eq(FootstepRules.event_for(FootstepRules.Gait.SNEAK), &"", "sızarken adım yok")
	eq(FootstepRules.event_for(FootstepRules.Gait.STILL), &"")


func test_run_cadence_matches_noise_ring() -> void:
	var profile: NoiseProfile = NoiseProfile.load_default()
	near(FootstepRules.RUN_INTERVAL, profile.step_interval, 0.0001, "koşu adımı = koşu halkası kadansı")
	near(FootstepRules.MIN_SPEED, profile.step_min_speed, 0.0001, "aynı hız eşiği")
	is_true(FootstepRules.WALK_INTERVAL > FootstepRules.RUN_INTERVAL, "yürüme daha seyrek")


func test_cadence_walk_run_sneak_stop() -> void:
	var cadence := FootstepRules.Cadence.new()
	var walk: Array[StringName] = _run(cadence, FootstepRules.Gait.WALK, 2.0)
	is_true(walk.size() >= 4 and walk.size() <= 5, "2 sn yürüme ~4 adım (%d)" % walk.size())
	is_true(walk.all(func(e: StringName) -> bool: return e == &"walk_step"))
	var run: Array[StringName] = _run(cadence, FootstepRules.Gait.RUN, 2.0)
	is_true(run.size() >= 5 and run.size() <= 6, "2 sn koşu ~6 adım (%d)" % run.size())
	is_true(run.all(func(e: StringName) -> bool: return e == &"run_step"))
	eq(_run(cadence, FootstepRules.Gait.SNEAK, 2.0).size(), 0, "sızma sessiz")
	eq(_run(cadence, FootstepRules.Gait.STILL, 2.0).size(), 0, "durma sessiz")
	var first: Array[StringName] = _run(cadence, FootstepRules.Gait.WALK, FootstepRules.WALK_INTERVAL * 0.3)
	eq(first.size(), 1, "harekete başlayınca ilk adım çeyrek aralıkta gelir")


func test_emitter_on_remote_style_mover() -> void:
	var mover := FakeMover.new()
	tree().root.add_child(mover)
	autofree(mover)
	var steps := FootstepEmitter.new()
	mover.add_child(steps)
	var heard: Array[StringName] = []
	steps.played.connect(func(ev: StringName) -> void: heard.append(ev))
	var emitted_before: int = int(NoiseBus.stats()["emitted"])
	mover.velocity = Vector2(140.0, 0.0)
	for i: int in 50:
		steps._process(1.0 / 60.0)
	is_true(heard.size() >= 1 and heard.has(&"walk_step"), "yürüyen kukla yürüme adımı çalar")
	is_false(heard.has(&"run_step"))
	heard.clear()
	mover.move_mode = PlayerMotion.Mode.SPRINT
	mover.velocity = Vector2(220.0, 0.0)
	for i: int in 50:
		steps._process(1.0 / 60.0)
	is_true(heard.has(&"run_step"), "koşan kukla koşu adımı çalar")
	heard.clear()
	mover.move_mode = PlayerMotion.Mode.SNEAK
	mover.velocity = Vector2(70.0, 0.0)
	for i: int in 60:
		steps._process(1.0 / 60.0)
	eq(heard.size(), 0, "sızan kukla sessiz")
	eq(int(NoiseBus.stats()["emitted"]), emitted_before, "adım sesi NoiseBus'a gürültü yaymaz")
	eq(steps.bus, &"SFX")


func test_player_scene_has_footsteps_and_soundscape() -> void:
	var scene: PackedScene = load("res://entities/player/player.tscn") as PackedScene
	var state: SceneState = scene.get_state()
	var names: PackedStringArray = []
	for i: int in state.get_node_count():
		names.append(String(state.get_node_name(i)))
	has(names, "Footsteps")
	has(names, "Soundscape")
