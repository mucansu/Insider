extends TestCase
## US-037 (KR-027) on store_a (NpcStage, single process = host): a sprinting player's contact with an NPC (NpcContact) - calm shove of the
## owner (slide 24 px, 0.8 s stagger with the brain stopped, +30 to the pusher, LOOK), counter n across NPCs and the observer cost (line of
## sight), hot chaser shove (free, catch window reset, 4 s immunity), chaser back contact, the shoulder rescue while the owner HOLDs (the
## existing PULL result), the player's local slowdown prediction and the calm lean of the NPC drawing.

const DT := 1.0 / 60.0
const CHASER_SCENE := "res://entities/npc/chaser/chaser.tscn"
const STAFF_FRONT := Vector2(560, 400)
const SPRINT_SPEED := 220.0


func _sprinter(stage: NpcStage, peer_id: int, at: Vector2, heading: Vector2) -> Player:
	var p: Player = stage.player(peer_id, at)
	p.net_mode = PlayerMotion.Mode.SPRINT
	p.net_facing = heading
	p.velocity = heading * SPRINT_SPEED
	return p


func _chaser(stage: NpcStage, at: Vector2) -> Chaser:
	var c: Chaser = (load(CHASER_SCENE) as PackedScene).instantiate() as Chaser
	c.auto_step = false
	c.position = at
	c.goal = at
	c.name = "TestChaser"
	stage.level.npcs_root().add_child(c)
	return c


func test_calm_shove_owner_slides_staggers_costs_and_looks() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var start: Vector2 = o.global_position
	var p: Player = _sprinter(stage, 2, start + Vector2(0, 16), Vector2.UP)
	stage.run(DT)
	var rows: Array[Dictionary] = o.contact().journal().pushes
	if not eq(rows.size(), 1, "koşarak önden temas = itme"):
		stage.leave()
		return
	eq(rows[0]["calm"], true)
	eq(rows[0]["peer"], 2)
	eq(rows[0]["npc"], "Owner")
	eq(rows[0]["n"], 1)
	eq(rows[0]["suspicion"], 30.0, "sakin bedel 30 x 1")
	near(o.suspicion().value_of(2), 30.0, 0.01, "itilen sahip +30")
	eq(o.brain().state(), OwnerBrain.State.LOOK, "itilen sahip BAK'a geçer")
	is_true(o.contact().is_staggering(), "sendeler")
	p.net_mode = PlayerMotion.Mode.WALK
	p.position = start + Vector2(0, 160)
	stage.run(0.3)
	near(o.global_position.distance_to(start), 24.0, 1.0, "24 px / 0,25 sn kayar")
	var after: Vector2 = o.global_position
	stage.run(0.4)
	near(o.global_position, after, 0.01, "sendelerken beyin durur")
	stage.run(0.15)
	is_false(o.contact().is_staggering(), "0,8 sn sonra beyin döner")
	eq(rows.size(), 1, "uzaklaşan oyuncu yeniden itmez")
	stage.leave()


func test_slide_does_not_enter_walls() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var start: Vector2 = o.global_position
	# The register counter is right west of ClerkSpot: a westward shove stops at it (physics, world layer).
	o.contact().host_push(2, start + Vector2(16, 0), Vector2.LEFT, true)
	stage.run(0.3)
	var shape := CircleShape2D.new()
	shape.radius = ((o.get_node(^"CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius - 0.5
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, o.global_position)
	query.collision_mask = PhysicsLayers.WORLD
	query.exclude = [o.get_rid()]
	is_true(o.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(),
		"kayma duvara/tezgâha girmez (x %.1f)" % o.global_position.x)
	is_true(start.distance_to(o.global_position) < 24.0 - 8.0, "engel kaymayı keser")
	stage.leave()


func test_counter_spans_npcs_and_observer_with_line_of_sight() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var c: Chaser = _chaser(stage, o.global_position + Vector2(0, 48))
	o.contact().host_push(2, o.global_position + Vector2(0, 16), Vector2.UP, true)
	c.contact().host_push(2, c.global_position + Vector2(0, 16), Vector2.UP, true)
	var rows: Array[Dictionary] = o.contact().journal().pushes
	if not eq(rows.size(), 2, "ortak günlük"):
		stage.leave()
		return
	eq(rows[1]["n"], 2, "n tüm NPC'ler üstünden sayılır")
	eq(rows[1]["suspicion"], 0.0, "mahallelinin şüphesi yok")
	eq(rows[1]["observers"], {"Owner": 30.0}, "görüş hattındaki gözlemci +15 x 2")
	near(o.suspicion().value_of(2), 60.0, 0.01, "sahip: kendi itmesi 30 + gözlem 30")
	o.contact().host_push(3, o.global_position + Vector2(0, 16), Vector2.UP, false)
	eq(rows[2]["suspicion"], 0.0, "kızışmış: bedel yok")
	eq(rows[2]["observers"], {})
	stage.leave()


func test_observer_without_line_of_sight_pays_nothing() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	# Back room (behind walls and the closed inner door), within the owner's range: no line of sight.
	var c: Chaser = _chaser(stage, stage.marker(&"BackroomSpot"))
	c.contact().host_push(2, c.global_position + Vector2(0, 16), Vector2.UP, true)
	eq(o.contact().journal().pushes[0]["observers"], {}, "duvar arkası görmez")
	eq(o.suspicion().value_of(2), 0.0)
	stage.leave()


func test_hot_chaser_shove_free_resets_catch_and_immune() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	Game.set_alert_level(2)
	var c: Chaser = _chaser(stage, Vector2(400, 400))
	c.facing = Vector2.LEFT
	var p: Player = _sprinter(stage, 2, Vector2(384, 400), Vector2.RIGHT)
	c.brain()._contact = 0.4
	c.contact().step(DT)
	var rows: Array[Dictionary] = c.contact().journal().pushes
	if not eq(rows.size(), 1, "önden koşarak temas = itme"):
		Game.set_alert_level(0)
		stage.leave()
		return
	eq(rows[0]["calm"], false)
	eq(rows[0]["suspicion"], 0.0, "kızışmış: bedelsiz")
	eq(c.brain()._contact, 0.0, "yakalama penceresi sıfırlandı")
	is_true(c.contact().is_staggering(), "0,8 sn sendeler")
	var stagger: float = DT
	var t: float = DT
	while t < 3.9:
		p.position = c.global_position + Vector2(-16, 0)
		c.contact().step(DT)
		t += DT
		if c.contact().is_staggering():
			stagger += DT
	near(stagger, 0.8, DT + 0.001)
	eq(rows.size(), 1, "4 sn itilmeye bağışık")
	for i: int in roundi(0.3 / DT):
		p.position = c.global_position + Vector2(-16, 0)
		c.contact().step(DT)
	eq(rows.size(), 2, "bağışıklık bitince yeniden itilir")
	Game.set_alert_level(0)
	stage.leave()


func test_chaser_back_contact_is_not_a_shove_but_owner_back_is() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	Game.set_alert_level(2)
	var c: Chaser = _chaser(stage, Vector2(400, 400))
	c.facing = Vector2.LEFT
	var p: Player = _sprinter(stage, 2, Vector2(416, 400), Vector2.LEFT)
	for i: int in 10:
		c.contact().step(DT)
	eq(c.contact().journal().pushes.size(), 0, "mahallelinin arkasından temas itme sayılmaz")
	var o: StoreOwner = stage.owner()
	p.position = o.global_position + Vector2(16, 0)
	p.net_facing = Vector2.LEFT
	o.contact().step(DT)
	eq(o.contact().journal().pushes.size(), 1, "arka kuralı yalnız mahallelide")
	Game.set_alert_level(0)
	stage.leave()


func test_walking_or_side_contact_is_not_a_shove() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var p: Player = stage.player(2, o.global_position + Vector2(0, 16))
	p.net_facing = Vector2.UP
	p.velocity = Vector2.UP * 140.0
	stage.run(0.2)
	eq(o.contact().journal().pushes.size(), 0, "yürüyerek temas: itme yok")
	eq(o.global_position.distance_to(stage.marker(&"ClerkSpot")) < 8.0, true, "sakin temas: NPC yer değiştirmez")
	p.net_mode = PlayerMotion.Mode.SPRINT
	p.net_facing = Vector2.RIGHT  # owner is at 90 deg: outside the +-60 cone
	p.velocity = Vector2.RIGHT * SPRINT_SPEED
	stage.run(DT)
	eq(o.contact().journal().pushes.size(), 0, "koni dışı: itme yok")
	stage.leave()


func test_shoulder_while_owner_holds_is_the_pull_result() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var p: Player = stage.player(2, STAFF_FRONT)
	for i: int in roundi(6.0 / DT):
		stage.run(DT)
		if p.is_held():
			break
	if not is_true(p.is_held(), "sahip tuttu"):
		stage.leave()
		return
	var mate: Player = _sprinter(stage, 3, o.global_position + Vector2(0, 16), Vector2.UP)
	stage.run(DT)
	is_true(p.is_free(), "omuz = ÇEK sonucu: serbest")
	eq(o.brain().state(), OwnerBrain.State.STAGGER, "sahip kendi SENDELE'sinde")
	eq(o.brain().rescues.size(), 1)
	if o.brain().rescues.size() == 1:
		eq(o.brain().rescues[0]["by"], 3)
	near(o.suspicion().value_of(3), 100.0, 1.0, "kurtarana şüphe 100 (mevcut ÇEK yolu; aynı adımda azalma başlar)")
	var rows: Array[Dictionary] = o.contact().journal().pushes
	if eq(rows.size(), 1):
		eq(rows[0]["rescue"], true)
		eq(rows[0]["calm"], false)
	is_false(o.contact().is_staggering(), "itme sendelemesi yok (beyin STAGGER'da)")
	is_true(o.contact().is_sliding(), "kayar")
	mate.position = Vector2(656, 176)
	stage.leave()


func test_local_prediction_slowdowns() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var p: Player = stage.player(2, o.global_position + Vector2(0, 16))
	p.move_mode = PlayerMotion.Mode.WALK
	p.velocity = Vector2.UP * 140.0
	eq(p._contact_scale(DT), 0.5, "sakin temas x0,5")
	p.move_mode = PlayerMotion.Mode.SPRINT
	p.velocity = Vector2.UP * SPRINT_SPEED
	eq(p._contact_scale(DT), 0.7, "tahmini itme: iten x0,7")
	for i: int in roundi(0.2 / DT):
		p._contact_scale(DT)
	eq(p._contact_scale(DT), 0.5, "0,2 sn sonra (aynı NPC'ye yeniden yok) temas yavaşlaması")
	Game.set_alert_level(2)
	p.move_mode = PlayerMotion.Mode.WALK
	eq(p._contact_scale(DT), 1.0, "kızışmış: temas yavaşlatmaz")
	p.position = o.global_position + Vector2(0, 80)
	eq(p._contact_scale(DT), 1.0, "temas yok")
	eq(int((p.motion_state()["contact"] as Dictionary)["predicted"]), 1)
	Game.set_alert_level(0)
	stage.leave()


func test_calm_lean_is_visual_and_local() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var visual: NpcVisual = o.get_node(^"Visual") as NpcVisual
	var p: Player = stage.player(2, o.global_position + Vector2(0, 10))
	for i: int in 30:
		await tree().physics_frame
	near(visual.position, Vector2(0, -8), 0.5, "8 px uzağa eğilir")
	p.position = o.global_position + Vector2(0, 120)
	for i: int in 30:
		await tree().physics_frame
	near(visual.position, Vector2.ZERO, 0.5, "temas bitince döner")
	stage.leave()
