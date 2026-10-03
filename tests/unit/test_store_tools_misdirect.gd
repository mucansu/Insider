extends TestCase
## US-010 izi (OYALA söndürmesi −40/−20/0, kararlar), US-043 YÖNLENDİR "o tarafa kaçtı!" ve US-044 vitrinden bakma
## (store_a, sabit adım, tek süreç = host; NpcStage). Örtü (US-042) testte `senses().cover_query` ile verilir
## (NpcStage Game'in işini kurmaz).

const DT := 1.0 / 60.0
const TALK_SPOT := Vector2(532, 404)
## Sahibe (ClerkSpot) 56 px: YÖNLENDİR menzili (64) içinde.
const NEAR_OWNER := Vector2(536, 368)


func _events(o: StoreOwner) -> Array:
	var out: Array = []
	for kind: StringName in StoreOwner.EVENT_KINDS:
		o.connect(kind, func(peer_id: int) -> void: out.append([kind, peer_id]))
	o.social_action.connect(func(peer_id: int, kind: StringName) -> void: out.append([&"social", peer_id, kind]))
	return out


func _chaser(stage: NpcStage, at: Vector2) -> Chaser:
	var c: Chaser = (load("res://entities/npc/chaser/chaser.tscn") as PackedScene).instantiate() as Chaser
	c.auto_step = false
	c.position = at
	c.goal = at
	c.name = "TestChaser%d" % stage.level.npcs_root().get_child_count()
	stage.level.npcs_root().add_child(c)
	return c


# --- kurallar ---

func test_rules_soothe_and_misdirect_point() -> void:
	var steps: Array[float] = [40.0, 20.0, 0.0]
	eq(CivilianRules.soothe_amount(0, steps), 40.0)
	eq(CivilianRules.soothe_amount(1, steps), 20.0)
	eq(CivilianRules.soothe_amount(2, steps), 0.0, "üçüncü: bir daha tutmaz")
	eq(CivilianRules.soothe_amount(5, steps), 0.0)
	var p: Vector2 = CivilianRules.misdirect_point(Vector2(100, 100), Vector2(100, 500), 400.0)
	near(p, Vector2(100, -300), 0.01, "kaçış noktasının tersine")
	near(CivilianRules.misdirect_point(Vector2(10, 10), Vector2.INF, 50.0), Vector2(10, -40), 0.01, "kaçış yoksa yedek yön")


func test_rules_window_stare_row() -> void:
	var t: CivilianTuning = load("res://data/npc/civilian_tuning.tres") as CivilianTuning
	var p: CivilianRules.Params = t.rules_params(load("res://data/npc/perception_tuning.tres") as PerceptionTuning)
	var ctx := CivilianRules.Context.new()
	ctx.zone = CivilianRules.Zone.OUTSIDE
	ctx.window_stare = 5.9
	eq(CivilianRules.factor(p, ctx), 0.0, "ilk 6 sn bakmak serbest (yoldan geçen örtüsü)")
	ctx.window_stare = 6.1
	eq(CivilianRules.behaviour(p, ctx), CivilianRules.Behaviour.WINDOW_STARE)
	near(CivilianRules.factor(p, ctx), 0.15, 0.0001, "sonra yavaş dolum")
	ctx.zone = CivilianRules.Zone.CUSTOMER
	ctx.loiter_time = 0.0
	eq(CivilianRules.factor(p, ctx), 0.0, "içeride vitrin satırı yok")


# --- OYALA söndürmesi ---

func test_talk_soothes_looking_owner_forty_twenty_then_refuses() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	stage.player(2, TALK_SPOT)
	stage.run(1.0)
	var talk: Interactable = o.talk_interactable()
	var amounts: Array[float] = []
	for i: int in 3:
		o.apply_suspicion(2, 55.0)
		stage.run(DT * 2)
		eq(o.brain().state(), OwnerBrain.State.LOOK, "tur %d: sahip bakıyor (\"?\")" % i)
		await tree().physics_frame
		is_true(talk.enabled, "tur %d: BAK'taki sahiple konuşulur" % i)
		var before: float = o.suspicion().value_of(2)
		talk.host_start(2, i + 1)
		stage.run(DT * 2)
		amounts.append(snappedf(before - o.suspicion().value_of(2), 1.0))
		talk.host_abort()
		stage.run(0.2)
	eq(o.brain().soothed.size(), 2, "iki söndürme")
	if o.brain().soothed.size() == 2:
		eq(o.brain().soothed[0]["amount"], 40.0, "1. kez −40")
		eq(o.brain().soothed[1]["amount"], 20.0, "2. kez −20")
	is_true(amounts[0] >= 39.0 and amounts[1] >= 19.0 and amounts[2] < 2.0, "düşüş 40/20/0 (%s)" % [amounts])
	has(events, [&"owner_shrug", 2], "söndürülen sahip omuz silker")
	has(events, [&"owner_soothe_refused", 2], "3. kez: bir daha tutmaz")
	stage.leave()


# --- YÖNLENDİR (US-043) ---

func test_misdirect_owner_sends_chasers_wrong_way_once() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	o.senses().cover_query = func(peer_id: int) -> bool: return peer_id == 2
	stage.player(2, NEAR_OWNER)
	stage.player(3, Vector2(400, 400))
	stage.run(0.5)
	var item: Interactable = o.misdirect_interactable()
	await tree().physics_frame
	is_false(item.enabled, "uyarı < 2: YÖNLENDİR yok")
	Game.set_alert_level(2)
	var near_c: Chaser = _chaser(stage, Vector2(592, 440))
	var far_c: Chaser = _chaser(stage, Vector2(60, 40))
	stage.run(DT)
	await tree().physics_frame
	is_true(item.enabled, "uyarı 2: açık")
	is_true(item.can_start(2, NEAR_OWNER, {&"cover": 1}), "örtüsü sağlam oyuncu, 64 px")
	is_false(item.can_start(3, NEAR_OWNER, {}), "örtüsü bozuk (etiket yok): istem yok")
	is_false(o.misdirect(3), "host: örtüsü bozuk reddedilir")
	item.host_start(2, 1)
	stage.run(1.6)
	is_true(o.net_misdirected, "kabul (1,5 sn tut)")
	has(events, [&"owner_misdirect", 2])
	has(events, [&"social", 2, &"misdirect"], "sosyal kanca")
	is_true(o.suspicion().value_of(2) >= 25.0, "söyleyene +30 (%.1f)" % o.suspicion().value_of(2))
	eq(near_c.brain().state_name(), &"misled", "menzildeki mahalleli yanlış yöne")
	ne(far_c.brain().state_name(), &"misled", "menzil dışındaki etkilenmez")
	var start: Vector2 = near_c.global_position
	var escape: Vector2 = stage.marker(&"Exit")
	stage.run(3.0)
	is_true(near_c.global_position.distance_to(escape) > start.distance_to(escape),
		"kaçış noktasından uzaklaşır (%s → %s)" % [start, near_c.global_position])
	await tree().physics_frame
	is_false(item.enabled, "iş başına 1: istem gizli")
	is_false(near_c.misdirect_interactable().enabled, "mahallelide de gizli")
	is_false(o.misdirect(2), "ikinci kez reddedilir")
	stage.run(6.0)
	eq(near_c.brain().state_name(), &"search", "8 sn sonra o noktada arar")
	Game.set_alert_level(0)
	stage.leave()


func test_chaser_spares_intact_cover_and_halts_while_misdirected() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	o.senses().cover_query = func(peer_id: int) -> bool: return peer_id == 2
	Game.set_alert_level(2)
	var bystander: Player = stage.player(2, Vector2(400, 400))
	var thief: Player = stage.player(3, Vector2(300, 400))
	var c: Chaser = _chaser(stage, Vector2(440, 400))
	stage.run(4.0)
	is_false(bystander.is_caught(), "örtüsü sağlam: mahalleli kovalamaz")
	is_true(thief.is_caught(), "örtüsü bozuk: yakalanır")
	# Konuşulurken (YÖNLENDİR tutulurken) mahalleli durur.
	var bystander2: Player = stage.player(4, Vector2(500, 420))
	o.senses().cover_query = func(_peer_id: int) -> bool: return false
	c.global_position = Vector2(560, 420)
	c.misdirect_interactable().host_start(2, 1)  # 2 menzil dışında: reddedilir, durmaz
	stage.run(0.1)
	c.global_position = bystander2.global_position + Vector2(40, 0)
	o.senses().cover_query = func(peer_id: int) -> bool: return peer_id == 4
	c.misdirect_interactable().host_start(4, 2)
	stage.run(0.5)
	is_true(c.brain().listening, "dinliyor")
	near(c.velocity.length(), 0.0, 1.0, "durur")
	is_false(bystander2.is_caught())
	Game.set_alert_level(0)
	stage.leave()


# --- vitrinden bakma (US-044) ---

func test_window_stare_slow_fill_question_at_door_no_shout() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	var recognized: Array[int] = []
	o.recognized.connect(func(peer_id: int) -> void: recognized.append(peer_id))
	stage.run(1.0)
	var at: Vector2 = stage.marker(&"WindowLook2")
	var p: Player = stage.player(2, at)
	p.look_dir = Vector2.UP  # vitrine (kuzey) bakar
	var meter: Array[float] = []
	var shouted: Array[bool] = [false]
	var t: Array[float] = [0.0]
	var first_fill: Array[float] = [-1.0]
	stage.run(60.0, func() -> void:
		t[0] += DT
		var v: float = o.suspicion().value_of(2)
		meter.append(v)
		if first_fill[0] < 0.0 and v > 0.0:
			first_fill[0] = t[0]
		shouted[0] = shouted[0] or o.brain().is_alarmed())
	is_true(first_fill[0] >= 6.0, "ilk 6 sn bakmak serbest (dolum %.2f sn'de)" % first_fill[0])
	var peak: float = 0.0
	for v: float in meter:
		peak = maxf(peak, v)
	is_true(peak >= 60.0 and peak <= 90.5, "yavaş dolum, sorguya varır ama tavanda durur (%.1f)" % peak)
	is_false(shouted[0], "bağırmaz")
	has(events, [&"owner_question_window", 2], "kapıdan: Bir şey mi arıyorsun?")
	is_false(events.has([&"owner_question", 2]), "içerideki sorgu değil")
	eq(o.brain().window_questions.slice(0, 1), [2])
	has(recognized, 2, "tanındı (US-042 recognized)")
	stage.leave()


func test_walking_past_or_looking_away_is_free() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	stage.run(1.0)
	var p: Player = stage.player(2, stage.marker(&"WindowLook2"))
	p.look_dir = Vector2.DOWN  # sokağa bakar
	stage.run(15.0)
	eq(o.senses().window_stare_of(2), 0.0, "vitrine bakmıyor")
	eq(o.suspicion().value_of(2), 0.0)
	p.look_dir = Vector2.UP
	p.velocity = Vector2(100, 0)  # yürüyerek geçiyor
	stage.run(10.0)
	eq(o.senses().window_stare_of(2), 0.0, "yürürken sayılmaz")
	eq(o.suspicion().value_of(2), 0.0)
	stage.leave()
