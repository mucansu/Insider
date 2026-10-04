extends TestCase
## IS-058b: session seed (core/session_seed.gd, Game.session_seed()). Derivation (0 = the data seed unchanged, non-zero mixes, salts
## independent), policy (`--seed` -> N then derived per job, automation -> 0, real game -> random non-zero), consumers (population
## schedule seed input, owner agenda seed with override priority) and the Game host path (seed picked per level start, dump key).

const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"


func test_derive_zero_is_the_data_seed() -> void:
	eq(SessionSeed.derive(0, 3, SessionSeed.SALT_OWNER_AGENDA), 3, "tohum 0: veri tohumu aynen")
	eq(SessionSeed.derive(0, 7, SessionSeed.SALT_POPULATION), 7)
	eq(SessionSeed.derive(0, -1, "x"), -1)
	eq(PopulationRules.schedule_seed(0, 7), 7, "nüfus tohumu girişi: 0 = eski davranış")


func test_derive_mixes_deterministically() -> void:
	var a: int = SessionSeed.derive(5, 3, SessionSeed.SALT_OWNER_AGENDA)
	eq(a, SessionSeed.derive(5, 3, SessionSeed.SALT_OWNER_AGENDA), "aynı girdi aynı tohum")
	ne(a, 3, "oturum tohumu veri tohumunu değiştirir")
	ne(a, SessionSeed.derive(6, 3, SessionSeed.SALT_OWNER_AGENDA), "farklı oturum farklı tohum")
	ne(a, SessionSeed.derive(5, 3, SessionSeed.SALT_POPULATION), "tuz akışları ayırır")
	ne(a, SessionSeed.derive(5, 4, SessionSeed.SALT_OWNER_AGENDA), "veri tohumu da girer")
	is_true(a >= 0 and a <= SessionSeed.RANDOM_MAX, "pozitif 31 bit")
	eq(PopulationRules.schedule_seed(5, 7), SessionSeed.derive(5, 7, SessionSeed.SALT_POPULATION))


func test_pick_policy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	eq(SessionSeed.pick(0, true, 42, false, rng), 42, "--seed: ilk iş N")
	eq(SessionSeed.pick(0, true, 42, true, rng), 42, "otomasyonda da N")
	var second: int = SessionSeed.pick(1, true, 42, true, rng)
	eq(second, SessionSeed.derive(42, 1, SessionSeed.SALT_JOB), "sonraki iş N'den türetilir (tekrarlanabilir)")
	ne(second, 42)
	ne(second, SessionSeed.pick(2, true, 42, true, rng), "her iş farklı")
	eq(SessionSeed.pick(3, true, 0, false, rng), 0, "--seed=0: her iş eski davranış")
	for job: int in 4:
		eq(SessionSeed.pick(job, false, 0, true, rng), 0, "otomasyon, tohumsuz: 0 (iş %d)" % job)
	var seen: Dictionary = {}
	for job: int in 8:
		var value: int = SessionSeed.pick(job, false, 0, false, rng)
		is_true(value > 0, "gerçek oyun: sıfır olmayan rastgele tohum")
		seen[value] = true
	is_true(seen.size() >= 7, "gerçek oyun: her iş yeni tohum")


func test_population_schedule_follows_seed() -> void:
	var p := PopulationRules.Params.new()
	p.customer_first_min = 5.0
	p.customer_first_max = 60.0
	p.passerby_interval = 20.0
	p.passerby_jitter = 10.0
	var base := PopulationRules.Schedule.new(p, 7)
	var same := PopulationRules.Schedule.new(p, PopulationRules.schedule_seed(0, 7))
	eq([same.next_customer, same.next_passerby], [base.next_customer, base.next_passerby], "tohum 0: aynı takvim")
	var other := PopulationRules.Schedule.new(p, PopulationRules.schedule_seed(99, 7))
	is_true(other.next_customer != base.next_customer or other.next_passerby != base.next_passerby, "oturum tohumu takvimi değiştirir")


func _start() -> PackedScene:
	var previous: PackedScene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	if eq(Net.host(port), OK):
		Game.start_level(STORE)
	return previous


func _stop(previous: PackedScene) -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = previous


func _owner() -> StoreOwner:
	var level: Level = Game.current_level() as Level
	return level.npcs_root().get_node_or_null(^"Owner") as StoreOwner if level != null else null


func test_game_picks_seed_per_job_and_owner_derives() -> void:
	var saved: Array = [Args.run_seed, Args.run_seed_given]
	Args.run_seed = 0
	Args.run_seed_given = false
	var previous: PackedScene = _start()
	var owner: StoreOwner = _owner()
	if is_true(owner != null, "sahip var"):
		eq(Game.session_seed(), 0, "test koşucusu otomasyon sayılır: 0")
		eq(owner.agenda_seed(), owner.owner_tuning.agenda_seed, "tohum 0: ajanda veri tohumu (eski davranış)")
		eq(Game.collect_dump().get("session_seed", -1), 0, "döküm anahtarı (host)")
	Args.run_seed = 42
	Args.run_seed_given = true
	Game.request_restart()
	var jobs: int = int(Game.get(&"_session_jobs"))
	var expected: int = SessionSeed.pick(jobs - 1, true, 42, true, RandomNumberGenerator.new())
	eq(Game.session_seed(), expected, "--seed: bu işin tohumu")
	owner = _owner()
	if is_true(owner != null):
		eq(owner.agenda_seed(), SessionSeed.derive(expected, owner.owner_tuning.agenda_seed, SessionSeed.SALT_OWNER_AGENDA),
			"ajanda oturum tohumundan türer")
		owner.agenda_seed_override = 5
		eq(owner.agenda_seed(), 5, "agenda_seed_override önceliklidir")
		owner.agenda_seed_override = -1
		eq(Game.collect_dump()["session_seed"], expected)
	Args.run_seed = saved[0]
	Args.run_seed_given = saved[1]
	Game.request_restart()
	eq(Game.session_seed(), 0, "tohum argümanı kalkınca yeniden 0")
	await _stop(previous)
