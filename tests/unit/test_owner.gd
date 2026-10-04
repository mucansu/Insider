extends TestCase
## US-008 AC1/AC3/AC4/AC5/AC8/AC9: the shop owner in store_a (real geometry, navigation, sight line; fixed step, single process =
## host). Reaction chain "?" -> question -> shout, alert ladder (StoreAlert -> Game), invariants I1 ("?" >= 0.5 s before
## detection; detection record), I2 (meter does not jump), I3 (LOOK >= 0.5 s), I4 (ladder), I5 (turn <= 120 deg/s), I7 (not
## inside a wall); never behind a shelf; multiplier context (zone, register interaction, held 0); `apply_delta` API; detection
## lock (no "!" flicker on a brief hide); duck-typed Hearing (fake) and the door bell.

const DT := 1.0 / 60.0
## Staff side, inside the counter end (in the owner's cone, near band).
const STAFF_FRONT := Vector2(560, 400)
## Staff side of the register (where the register is emptied).
const REGISTER_STAFF := Vector2(586, 366)
const CUSTOMER_OPEN := Vector2(400, 400)


## Fake of US-009 Hearing (S11 contract: only the `heard` signal).
class FakeHearing:
	extends Node
	signal heard(pos: Vector2, radius: float, kind: StringName)


func _stage() -> NpcStage:
	return NpcStage.new(self)


func test_staff_side_chain_question_shout_and_ladder() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = []
	for kind: StringName in StoreOwner.EVENT_KINDS:
		o.connect(kind, func(peer_id: int) -> void: events.append([kind, peer_id]))
	var p: Player = stage.player(2, STAFF_FRONT)
	var states: Array[int] = []
	var look_time: Array[float] = [0.0]
	var meter: Array[float] = []
	var facings: Array[Vector2] = []
	var walls: Array[int] = [0]
	var probe := func() -> void:
		states.append(o.brain().state())
		if o.brain().state() == OwnerBrain.State.LOOK:
			look_time[0] += DT
		meter.append(o.suspicion().value_of(2))
		facings.append(o.perception().facing)
		if _inside_wall(o):
			walls[0] += 1
	stage.run(1.2, probe)
	eq(o.brain().state(), OwnerBrain.State.QUESTION, "60'ta sorgu (BAK ≥ 0,5 sn sonra)")
	eq(events, [[&"owner_question", 2]], "64 px içinde: hemen sorar")
	eq(Game.alert_level(), 1, "uyarı 1: şüphe/sorgu")
	stage.run(0.5, probe)
	is_true(o.brain().is_alarmed(), "100'de bağırır (personel tarafı ~1,53 sn)")
	eq(events.slice(0, 2), [[&"owner_question", 2], [&"owner_shout", 2]])
	eq(Game.alert_level(), 2, "uyarı 2: bağırdı")
	eq(stage.alert().ladder.history, PackedInt32Array([0, 1, 2]), "I4: 0 → 1 → 2, atlamasız")
	is_true(look_time[0] >= 0.5 - 0.0001, "I3: BAK ≥ 0,5 sn (gelen %.3f)" % look_time[0])
	# I1 + AC8 dump fields.
	var det: Array[Dictionary] = o.brain().detections
	if is_true(det.size() == 1, "bir tespit kaydı"):
		var d: Dictionary = det[0]
		is_true(float(d["t_question"]) >= 0.0 and float(d["t_detect"]) - float(d["t_question"]) >= 0.5,
			"I1: \"?\" tespitten ≥ 0,5 sn önce (%s)" % d)
		eq(d["behaviour"], &"staff_side")
		eq(d["band"], int(PerceptionRules.Band.NEAR))
		for key: String in ["peer", "mode", "lit", "rtt_ms", "dist_px", "flagged", "zone"]:
			has(d, key, "detections alanı " + key)
	stage.run(3.0, probe)
	is_true(p.is_held() or p.is_caught(), "sahip kovalar ve tutar (28 px + 0,5 sn)")
	has(events, [&"owner_held", 2])
	# I2: the meter does not jump.
	var cap: float = 25.0 * 2.0 * 2.5 * DT + 0.001
	var worst: float = 0.0
	for i: int in range(1, meter.size()):
		worst = maxf(worst, absf(meter[i] - meter[i - 1]))
	is_true(worst <= cap, "I2: |Δölçer| ≤ dolum × Δt (en büyük %.3f, sınır %.3f)" % [worst, cap])
	# I5: turn ceiling.
	var turn_cap: float = deg_to_rad(o.perception().tuning.max_turn_deg_per_sec) * DT + 0.0001
	var worst_turn: float = 0.0
	for i: int in range(1, facings.size()):
		worst_turn = maxf(worst_turn, absf(facings[i - 1].angle_to(facings[i])))
	is_true(worst_turn <= turn_cap, "I5: dönüş ≤ 120°/sn (en büyük %.4f rad/kare)" % worst_turn)
	eq(walls[0], 0, "I7: sahip duvar içinde değil")
	is_true(Fsm.is_valid_sequence(OwnerBrain.EDGES, o.brain().fsm.history), "beyin yalnız izinli geçişler")
	stage.leave()


func test_behind_shelf_never_fills() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var o: StoreOwner = stage.owner()
	o.global_position = Vector2(420, 240)
	o.perception().facing = Vector2.LEFT
	Game.set_alert_level(2)  # after the shout everyone is 2.5: worst case
	var p: Player = stage.player(2, Vector2(240, 176))
	await tree().physics_frame
	for i: int in roundi(5.0 / DT):
		o.suspicion().tick(DT)
	eq(o.suspicion().value_of(2), 0.0, "raf arkası (görüş hattı kesik) hiç dolmaz")
	p.position = Vector2(304, 240)  # open aisle at the same distance (far band)
	var detected_at: float = -1.0
	for i: int in roundi(3.0 / DT):
		o.suspicion().tick(DT)
		if detected_at < 0.0 and o.suspicion().level_of(2) >= Suspicion.Level.DETECT:
			detected_at = (i + 1) * DT
	near(detected_at, 1.8, DT + 0.001, "kontrol: açıkta uzak bant 2,5 → 1,8 sn")
	Game.set_alert_level(0)
	stage.leave()


func test_factor_context_from_zone_interaction_and_status() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var senses: CivilianSenses = o.senses()
	var p: Player = stage.player(2, CUSTOMER_OPEN)
	eq(senses.factor_for(p), 0.0, "müşteri bölgesinde yürüme masum")
	eq(senses.zone_of(CUSTOMER_OPEN), CivilianRules.Zone.CUSTOMER)
	eq(senses.zone_of(Vector2(592, 176)), CivilianRules.Zone.BACKROOM)
	eq(senses.zone_of(Vector2(368, 496)), CivilianRules.Zone.OUTSIDE, "kaldırım dışarı")
	p.position = STAFF_FRONT
	eq(senses.factor_for(p), 1.5, "personel tarafı")
	p.position = REGISTER_STAFF
	var register: Interactable = stage.level.props_root().get_node(^"Register/Interactable") as Interactable
	register.host_start(2, 1)
	eq(register.busy_by, 2)
	eq(senses.interaction_of(2), CivilianRules.Interaction.CASH)
	eq(senses.factor_for(p), 2.5, "kasa tutarken 2,5")
	register.host_cancel(2, 1)
	is_true(p.host_hold(6.0))
	eq(senses.factor_for(p), 0.0, "tutulan oyuncu hedef değil")
	senses.step(1.0)
	near(senses.loiter_time(2), 1.0, 0.001, "dükkân içi süre (oyalanma)")
	senses.reset_loiter(2)
	eq(senses.loiter_time(2), 0.0, "SATIN AL sıfırlar (US-010 API)")
	stage.leave()


func test_apply_delta_api_and_detection_latch() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var levels: Array = []
	o.suspicion().threshold_reached.connect(func(peer_id: int, level: int) -> void: levels.append([peer_id, level]))
	o.apply_suspicion(7, 35.0)
	eq(o.suspicion().value_of(7), 35.0)
	eq(levels, [[7, 1]], "AC4: apply_delta eşik sinyali")
	o.apply_suspicion(7, -40.0)
	eq(o.suspicion().value_of(7), 0.0, "OYALA −40 (US-010)")
	# Detection lock: after the shout, if the player is briefly invisible, the summary level and "!" do not flicker.
	var p: Player = stage.player(2, STAFF_FRONT)
	stage.run(1.8)
	is_true(o.brain().is_alarmed())
	p.position = Vector2(656, 176)  # back room: behind a wall
	var levels_seen: Array[int] = []
	var bubbles: Array[int] = []
	stage.run(1.5, func() -> void:
		levels_seen.append(o.suspicion().max_level)
		bubbles.append(o.bubble))
	is_false(levels_seen.has(Suspicion.Level.INVESTIGATE) or levels_seen.has(Suspicion.Level.NOTICE),
		"max_level kilitli (3), inceleme/\"?\" titremesi yok")
	is_false(bubbles.has(CivilianRules.Bubble.NOTICE), "gösterge \"!\"te kalır")
	stage.leave()


func test_hearing_duck_typing_and_bell_interrupts() -> void:
	var stage: NpcStage = _stage()
	var fake := FakeHearing.new()
	fake.name = "Hearing"
	await stage.enter(NpcStage.STORE, func(level: Level) -> void:
		for child: Node in level.npcs_root().get_children():
			if child is StoreOwner:
				child.add_child(fake))
	var o: StoreOwner = stage.owner()
	stage.run(0.2)
	fake.heard.emit(Vector2(400, 400), 120.0, &"shout")
	eq(o.agenda().task_name(), &"counter", "kendi türünden bağırış dinletmez")
	fake.heard.emit(Vector2(400, 400), 120.0, &"knock")
	eq(o.agenda().task_name(), &"listen", "S8 heard → DİNLE kesmesi")
	near(o.agenda().goal_position().distance_to(Vector2(400, 400)), 64.0, 1.0, "sese 64 px kala durur")
	stage.run(1.0)
	is_true(o.global_position.x < 590.0, "sese doğru yürür")
	stage.run(8.0)
	eq(o.agenda().task_name(), &"counter", "8 sn sonra ajanda sürer")
	stage.run(6.0)
	# Door bell: the player enters through the front door.
	var p: Player = stage.player(2, Vector2(368, 496))
	stage.run(0.1)
	p.position = Vector2(368, 432)
	stage.run(0.1)
	eq(o.agenda().task_name(), &"bell", "ön kapı geçişi zil kesmesi")
	stage.run(1.2)
	eq(o.agenda().task_name(), &"counter", "zil 1 sn")
	is_true(o.agenda().sequence.has(&"listen") and o.agenda().sequence.has(&"bell"))
	stage.leave()


## I7: at an unreachable task point the owner does not freeze (cannot go = counts as arrived), does not push into walls.
func test_unreachable_task_does_not_freeze() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var clerk: Vector2 = stage.marker(&"ClerkSpot")
	o.agenda().setup(o.owner_tuning.tasks, 5, func(m: StringName) -> Array:
		return [clerk] if m == &"ClerkSpot" else [Vector2(-400, -400)])
	var failures: Array[int] = [0]
	(o.get_node(^"Mover") as NpcMover).path_failed.connect(func(_t: Vector2) -> void: failures[0] += 1)
	var walls: Array[int] = [0]
	stage.run(150.0, func() -> void:
		if _inside_wall(o):
			walls[0] += 1, 1.0 / 30.0)
	is_true(o.agenda().sequence.size() >= 5, "ajanda ilerler (%s)" % [o.agenda().sequence])
	is_true(failures[0] >= 2, "gezinme başarısızlığı beyne bildirilir (path_failed: %d)" % failures[0])
	eq(walls[0], 0, "I7: duvar içinde değil")
	eq(o.brain().state(), OwnerBrain.State.AGENDA)
	stage.leave()


static func _inside_wall(o: StoreOwner) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = o.global_position
	query.collision_mask = PhysicsLayers.WORLD
	return not o.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
