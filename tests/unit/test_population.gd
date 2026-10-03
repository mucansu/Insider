extends TestCase
## US-016 (store_a geometry, fixed step, single process = host): a customer arrives (bell), stops at shelf points, is served in the
## queue (owner CUSTOMER interrupt + "register opens" hook), leaves and is removed; two customers do not hold the same point;
## a witness tells the owner (+60) or flees if the owner is not seen; a passer-by route + glass look, becomes a neighbour on a shout;
## cover counting in the owner's context; NPC cap 6; collision layers and translucency (AC7).

const DT := 1.0 / 30.0


func _stage(tune: Callable) -> NpcStage:
	var stage := NpcStage.new(self)
	stage.with_population = true
	await stage.enter(NpcStage.STORE, func(level: Level) -> void:
		for child: Node in level.npcs_root().get_children():
			if child is Population:
				var pop: Population = child as Population
				var t: PopulationTuning = (load(Population.TUNING_PATH) as PopulationTuning).duplicate() as PopulationTuning
				t.customer_first_min = 0.0
				t.customer_first_max = 0.0
				t.customer_interval = 0.0
				t.passerby_interval = 0.0
				tune.call(t)
				pop.tuning = t)
	return stage


func _customers(pop: Population) -> Array[Civilian]:
	var out: Array[Civilian] = []
	for c: Civilian in pop.civilians():
		if c.is_customer():
			out.append(c)
	return out


func test_customer_visits_is_served_and_leaves() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 1.0
		t.customer_first_max = 1.0
		t.customer_interval = 500.0)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	var opened: Array[int] = []
	o.brain().register_opened.connect(func(id: int) -> void: opened.append(id))
	var seen: Array[Civilian] = []
	var inside_t: Array[float] = [-1.0, -1.0]
	var clock: Array[float] = [0.0]
	var max_spots: Array[int] = [0]
	stage.run(100.0, func() -> void:
		clock[0] += DT
		for c: Civilian in _customers(pop):
			if not seen.has(c):
				seen.append(c)
			if CivilianRules.is_inside(o.senses().zone_of(c.global_position)):
				if inside_t[0] < 0.0:
					inside_t[0] = clock[0]
				inside_t[1] = clock[0]
			max_spots[0] = maxi(max_spots[0], pop.registry.spots_of(c.serial).size()), DT)
	eq(seen.size(), 1, "bir müşteri geldi")
	eq(_customers(pop).size(), 0, "çıktı ve silindi")
	eq(pop.registry.size(), 0, "noktalar bırakıldı")
	is_true(max_spots[0] >= 1 and max_spots[0] <= 2, "1-2 raf noktası tutuldu (%d)" % max_spots[0])
	is_true(o.agenda().sequence.has(&"bell"), "ön kapı geçişi: zil (%s)" % [o.agenda().sequence])
	is_true(o.agenda().sequence.has(&"customer"), "sahip servis kesmesi")
	eq(o.brain().serves_done, 1, "servis tamamlandı")
	eq(opened.size(), 1, "kasa açılır kancası bir kez")
	if not opened.is_empty() and not seen.is_empty():
		eq(opened[0], 1, "kanca müşteri kimliğiyle")
	var stay: float = inside_t[1] - inside_t[0]
	is_true(stay >= 20.0 and stay <= 60.0, "içeride kalış %.1f sn" % stay)
	var d: Dictionary = pop.dump_state()
	eq(int(d["served"]), 1)
	eq(int(d["customers_spawned"]), 1)
	eq(d["seen"], ["Customer1"])
	has(d["events"], &"customer_enter")
	eq(o.brain().state(), OwnerBrain.State.AGENDA, "sahip ajandaya döndü")
	stage.leave()


## Two customers do not hold the same shelf/queue point; both are served in turn.
func test_two_customers_never_share_spots() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 1.0
		t.customer_first_max = 1.0
		t.customer_interval = 3.0
		t.customer_jitter = 0.0)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	var clash: Array[String] = []
	var both: Array[int] = [0]
	stage.run(110.0, func() -> void:
		var cs: Array[Civilian] = _customers(pop)
		if cs.size() > 2:
			clash.append("müşteri sayısı %d" % cs.size())
		if cs.size() == 2:
			both[0] += 1
			var a: Array[StringName] = pop.registry.spots_of(cs[0].serial)
			for spot: StringName in pop.registry.spots_of(cs[1].serial):
				if a.has(spot):
					clash.append(String(spot))
			var qa: StringName = cs[0].brain().queue_spot()
			if not qa.is_empty() and qa == cs[1].brain().queue_spot():
				clash.append("kuyruk %s" % qa), DT)
	eq(clash, [] as Array[String], "ortak nokta yok")
	is_true(both[0] > 0, "iki müşteri aynı anda içerideydi")
	is_true(o.brain().serves_done >= 2, "ikisi de servis oldu (%d)" % o.brain().serves_done)
	stage.leave()


func _first_customer(stage: NpcStage, pop: Population) -> Civilian:
	for i: int in 300:
		stage.run(DT, Callable(), DT)
		var cs: Array[Civilian] = _customers(pop)
		if not cs.is_empty():
			return cs[0]
	return null


## AC5: a witness does not shout at 100; if it sees the owner it walks to them, the owner's suspicion of that player +60 within 3-5 s.
func test_witness_tells_owner() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 0.5
		t.customer_first_max = 0.5)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	var p: Player = stage.player(2, Vector2(880, 592))  # outside, nobody sees
	var c: Civilian = _first_customer(stage, pop)
	if not is_true(c != null, "müşteri geldi"):
		stage.leave()
		return
	c.global_position = Vector2(592, 440)  # behind the counter, the owner (ClerkSpot) clearly sees
	stage.run(0.5, Callable(), DT)
	c.suspicion().apply_delta(2, 100.0)
	var told: Array[float] = []
	var t: Array[float] = [0.0]
	stage.run(6.0, func() -> void:
		t[0] += DT
		if told.is_empty() and o.suspicion().value_of(2) > 0.0:
			told.append(t[0])
			told.append(o.suspicion().value_of(2)), DT)
	eq(c.brain().witness_outcome, &"tell")
	if is_true(told.size() == 2, "sahibe söyledi"):
		is_true(told[0] >= 3.0 - DT and told[0] <= 5.0 + DT, "3-5 sn (%.2f)" % told[0])
		near(told[1], 60.0, 1.0, "sahibin şüphesi +60")
	has(c.events(), &"customer_tell")
	is_false(c.events().has(&"customer_flee"), "bağırmaz/kaçmaz")
	ne(o.brain().state(), OwnerBrain.State.SHOUT, "sahip bağırmadı")
	eq(c.brain().state(), CivilianBrain.State.LEAVE, "söyledikten sonra çıkar")
	is_true(p != null)
	stage.leave()


## AC5: if the owner is not seen it flees through the front door, nothing happens to the owner.
func test_witness_flees_without_owner_in_sight() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 0.5
		t.customer_first_max = 0.5
		t.owner_sight_range = 1.0)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	stage.player(2, Vector2(880, 592))
	var c: Civilian = _first_customer(stage, pop)
	if not is_true(c != null, "müşteri geldi"):
		stage.leave()
		return
	stage.run(4.0, Callable(), DT)
	c.suspicion().apply_delta(2, 100.0)
	stage.run(0.2, Callable(), DT)
	eq(c.brain().witness_outcome, &"flee")
	has(c.events(), &"customer_flee")
	eq(o.suspicion().value_of(2), 0.0, "sahibe söylenmedi")
	stage.run(30.0, Callable(), DT)
	eq(_customers(pop).size(), 0, "kaçıp çıktı")
	eq(int(pop.dump_state()["flees"]), 1)
	stage.leave()


## AC4 + conversion (play-test #20): route StreetRoute1..6, looks inside for 2 s at the windows in its plan; when the owner shouts
## a passer-by within 320 px turns into a neighbour on the spot (NPC count unchanged).
func test_passerby_route_looks_and_conversion() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.passerby_interval = 1.0
		t.passerby_jitter = 0.0
		t.passerby_max = 1
		t.look_chance = 1.0)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	var facings: Array[Vector2] = []
	var looked_at: Array[StringName] = []
	stage.run(60.0, func() -> void:
		for c: Civilian in pop.civilians():
			var task: AgendaTask = c.agenda().current_task()
			if task != null and task.name == &"look" and c.agenda().has_arrived() and c.agenda().arrived_for() > 1.5 \
					and not looked_at.has(task.marker):
				looked_at.append(task.marker)
				facings.append(c.perception().facing.snapped(Vector2.ONE * 0.1)), DT)
	eq(looked_at, [&"WindowLook1", &"WindowLook2", &"WindowLook3"] as Array[StringName], "üç camda bakış")
	eq(facings, [Vector2.UP, Vector2.UP, Vector2.LEFT] as Array[Vector2], "içeri bakar")
	is_true(int(pop.dump_state()["looks"]) >= 3, "bakış sayısı")
	is_true(int(pop.dump_state()["passersby_spawned"]) >= 2, "rota sonunda silinir, yenisi gelir")
	# Conversion: a shout while the passer-by is within 320 px of the owner.
	var near_one: Array[Civilian] = []
	for i: int in 900:
		stage.run(DT, Callable(), DT)
		for c: Civilian in pop.civilians():
			if c.global_position.distance_to(o.global_position) < 250.0:
				near_one.append(c)
		if not near_one.is_empty():
			break
	if not is_true(not near_one.is_empty(), "yoldan geçen sahibe yaklaştı"):
		stage.leave()
		return
	var at: Vector2 = near_one[0].global_position
	var before: int = pop.npc_count()
	o.brain().shout(0, false)
	eq(pop.civilians().size(), 0, "yoldan geçen silindi")
	var chasers: Array[Chaser] = stage.alert().chasers()
	if is_true(chasers.size() == 1, "aynı yerde mahalleli"):
		near(chasers[0].global_position.distance_to(at), 0.0, 1.0)
	eq(pop.npc_count(), before, "NPC sayısı değişmedi")
	eq(int(pop.dump_state()["converted"]), 1)
	stage.leave()


## AC6: with a customer inside the owner's context carries the cover (the x0.5 rule is in test_population_rules).
func test_cover_count_reaches_owner_context() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 0.5
		t.customer_first_max = 0.5)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	var p: Player = stage.player(2, Vector2(240, 240))
	eq(o.senses().context_for(p).customers_inside, 0)
	var c: Civilian = _first_customer(stage, pop)
	if not is_true(c != null):
		stage.leave()
		return
	c.global_position = Vector2(240, 400)
	eq(o.senses().customers_inside(), 1)
	eq(o.senses().context_for(p).customers_inside, 1, "sahibin bağlamında müşteri sayısı")
	c.global_position = Vector2(880, 592)
	eq(o.senses().customers_inside(), 0, "dışarıdaki müşteri sayılmaz")
	stage.leave()


## AC8: NPC cap 6 (owner + civilians + neighbour); no new civilian arrives after the shout (alert 2).
func test_npc_cap_and_pause_on_alarm() -> void:
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 0.5
		t.customer_first_max = 0.5
		t.customer_interval = 2.0
		t.customer_jitter = 0.0
		t.passerby_interval = 2.0
		t.passerby_jitter = 0.0)
	var o: StoreOwner = stage.owner()
	var pop: Population = stage.population()
	var top: Array[int] = [0]
	stage.run(20.0, func() -> void: top[0] = maxi(top[0], pop.npc_count()), DT)
	is_true(top[0] <= 5, "komşu payı: nüfus 5'i aşmaz (%d)" % top[0])
	is_true(top[0] >= 4, "nüfus doldu (%d)" % top[0])
	var spawned: int = int(pop.dump_state()["customers_spawned"]) + int(pop.dump_state()["passersby_spawned"])
	o.brain().shout(0, false)
	stage.run(30.0, func() -> void: top[0] = maxi(top[0], pop.npc_count()), DT)
	is_true(top[0] <= 6, "tavan 6 (%d)" % top[0])
	eq(int(pop.dump_state()["customers_spawned"]) + int(pop.dump_state()["passersby_spawned"]), spawned,
		"uyarı ≥ 2: yeni sivil yok")
	is_true(stage.alert().chasers().size() >= 1, "komşu geldi")
	stage.leave()


## AC7: NPCs do not push the player and the player does not push NPCs (layer/mask); when overlapping the civilian is translucent.
func test_no_collision_and_overlap_translucency() -> void:
	var civ: Civilian = autofree((load(Population.CIVILIAN_SCENE) as PackedScene).instantiate()) as Civilian
	eq(civ.collision_layer, PhysicsLayers.NPCS)
	eq(civ.collision_mask, PhysicsLayers.WORLD, "sivil yalnız dünyaya çarpar")
	var player: CharacterBody2D = autofree((load(NpcStage.PLAYER_SCENE) as PackedScene).instantiate()) as CharacterBody2D
	eq(player.collision_mask & PhysicsLayers.NPCS, 0, "oyuncu NPC'ye çarpmaz")
	var stage: NpcStage = await _stage(func(t: PopulationTuning) -> void:
		t.customer_first_min = 0.5
		t.customer_first_max = 0.5)
	var pop: Population = stage.population()
	var c: Civilian = _first_customer(stage, pop)
	if not is_true(c != null):
		stage.leave()
		return
	var visual: NpcVisual = c.get_node(^"Visual") as NpcVisual
	var p: Player = stage.player(2, c.global_position + Vector2(200, 0))
	visual._physics_process(DT)
	near(visual.modulate.a, 1.0, 0.001)
	p.global_position = c.global_position + Vector2(6, 0)
	visual._physics_process(DT)
	near(visual.modulate.a, NpcVisual.OVERLAP_ALPHA, 0.001, "iç içe: yarı saydam")
	stage.leave()
