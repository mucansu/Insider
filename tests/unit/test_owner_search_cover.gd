extends TestCase
## US-048 (GB-12, KR-041): after the shout the owner does not hold a player whose cover is intact - the ALARM row applies only to a broken
## cover, an intact cover stops at 90 while the owner is alarmed, and in SEARCH SORGU-2 walks to an intact player at >= 60 ("Sen de
## buradaydın! Kim aldı?", recognised once per job, 20 s cooldown). Breaking cover (running, seen RESCUE ...) -> ALARM -> the usual chain.
## Rules (CivilianRules) + store_a single process = host (NpcStage, fixed step). Cover is supplied via `senses().cover_query` (NpcStage does
## not set up Game's job; a cover break by Game's tracker is emulated by switching the query at that moment).

const DT := 1.0 / 60.0
## Thief (broken cover) parked far from the owner's sight: shouted at, then lost -> SEARCH.
const THIEF_FAR := Vector2(60, 40)
## Customer side, ~116 px south-west of ClerkSpot (in the owner's cone after the shout): SORGU-2 walks over.
const CUSTOMER_SPOT := Vector2(480, 404)
## Staff side in front of the counter (hold spot of test_owner_hold).
const STAFF_FRONT := Vector2(560, 400)
## GB-12 record: c1 had spent 102 s in the shop (loiter row 0.25).
const LOITER_S := 102.0


func _params() -> CivilianRules.Params:
	var civ: CivilianTuning = load("res://data/npc/civilian_tuning.tres") as CivilianTuning
	return civ.rules_params(load("res://data/npc/perception_tuning.tres") as PerceptionTuning)


func _ctx(zone: CivilianRules.Zone, alert: int, intact: bool, loiter: float) -> CivilianRules.Context:
	var ctx := CivilianRules.Context.new()
	ctx.zone = zone
	ctx.alert_level = alert
	ctx.cover_intact = intact
	ctx.loiter_time = loiter
	return ctx


## Owner tuning copy (shared resource stays untouched) with a longer search, so 30 s in view happen while the owner is alarmed.
func _long_search(o: StoreOwner) -> OwnerTuning:
	var t: OwnerTuning = o.brain().owner_tuning.duplicate() as OwnerTuning
	t.calm_after_sec = 45.0
	o.brain().owner_tuning = t
	return t


## Owner shouts at the far thief (3) and loses him: SHOUT -> CHASE -> SEARCH. Peer 2 has intact cover and has loitered `LOITER_S`.
func _search(stage: NpcStage) -> StoreOwner:
	var o: StoreOwner = stage.owner()
	o.senses().cover_query = func(peer_id: int) -> bool: return peer_id == 2
	o.senses().loiter_query = func(_peer_id: int) -> float: return LOITER_S
	_long_search(o)
	stage.run(1.0)
	stage.player(3, THIEF_FAR)
	Game.set_alert_level(2)
	o.brain().shout(3, false)
	stage.run(1.0)
	return o


# --- rules ---

func test_rules_alarm_row_only_for_broken_cover() -> void:
	var p: CivilianRules.Params = _params()
	var intact: CivilianRules.Context = _ctx(CivilianRules.Zone.CUSTOMER, 2, true, LOITER_S)
	eq(CivilianRules.behaviour(p, intact), CivilianRules.Behaviour.LOITER, "örtüsü sağlam: alarmda da oyalanma satırı")
	near(CivilianRules.factor(p, intact), p.loiter_factor, 0.0001)
	var broken: CivilianRules.Context = _ctx(CivilianRules.Zone.CUSTOMER, 2, false, LOITER_S)
	eq(CivilianRules.behaviour(p, broken), CivilianRules.Behaviour.ALARM, "örtüsü bozuk: ALARM")
	near(CivilianRules.factor(p, broken), p.alarm_factor, 0.0001)
	eq(CivilianRules.factor(p, _ctx(CivilianRules.Zone.CUSTOMER, 2, true, 30.0)), 0.0, "sağlam, 60 sn altı: masum")
	var running: CivilianRules.Context = _ctx(CivilianRules.Zone.CUSTOMER, 2, true, 30.0)
	running.stance = PerceptionRules.Stance.SPRINT
	eq(CivilianRules.behaviour(p, running), CivilianRules.Behaviour.SPRINT, "koşma satırı örtüden bağımsız")
	eq(CivilianRules.behaviour(p, _ctx(CivilianRules.Zone.STAFF, 2, true, 0.0)), CivilianRules.Behaviour.STAFF_SIDE)
	eq(CivilianRules.behaviour(p, _ctx(CivilianRules.Zone.CUSTOMER, 1, false, 0.0)), CivilianRules.Behaviour.INNOCENT,
		"uyarı < 2: ALARM yok")


func test_rules_cap_gain_and_question_due() -> void:
	is_false(CivilianRules.cover_cap_reached(89.9, 90.0, 100.0))
	is_true(CivilianRules.cover_cap_reached(90.0, 90.0, 100.0), "90'da dolum durur")
	is_false(CivilianRules.cover_cap_reached(100.0, 90.0, 100.0), "tespit edilmiş sayaç tutulmaz")
	eq(CivilianRules.capped_gain(70.0, 30.0, 90.0), 20.0, "+30 tavana kadar")
	eq(CivilianRules.capped_gain(95.0, 30.0, 90.0), 0.0)
	eq(CivilianRules.capped_gain(50.0, -40.0, 90.0), -40.0, "düşüş serbest")
	is_true(CivilianRules.search_question_due(60.0, 60.0, true, true, -1.0, 5.0, 20.0), "60, hiç sorulmadı")
	is_false(CivilianRules.search_question_due(59.0, 60.0, true, true, -1.0, 5.0, 20.0), "60 altı")
	is_false(CivilianRules.search_question_due(70.0, 60.0, false, true, -1.0, 5.0, 20.0), "örtüsü bozuk: sorgu değil kovalama")
	is_false(CivilianRules.search_question_due(70.0, 60.0, true, false, -1.0, 5.0, 20.0), "tutulmuş/yakalanmış")
	is_false(CivilianRules.search_question_due(70.0, 60.0, true, true, 10.0, 29.9, 20.0), "20 sn dolmadı")
	is_true(CivilianRules.search_question_due(70.0, 60.0, true, true, 10.0, 30.0, 20.0), "20 sn sonra yeniden")
	is_false(CivilianRules.search_question_due(70.0, 0.0, true, true, -1.0, 5.0, 20.0), "0 = kapalı")


func test_tuning_numbers() -> void:
	var t: OwnerTuning = load("res://data/npc/owner_tuning.tres") as OwnerTuning
	eq(t.search_cover_cap, 90.0)
	eq(t.search_question_at, 60.0)
	eq(t.search_question_speed, 110.0)
	eq(t.search_question_stop, 64.0)
	eq(t.search_question_wait_sec, 3.0)
	eq(t.search_question_cooldown_sec, 20.0)
	ne(tr(&"OWNER_QUESTION_SEARCH"), "OWNER_QUESTION_SEARCH", "balon metni (i18n)")
	eq(NpcVisual.BALLOON_KEYS.get(&"owner_question_search"), "OWNER_QUESTION_SEARCH")


# --- owner (store_a) ---

## AC2/AC3/AC5 (1): an intact customer in the owner's view for 30 s during the search is not held; suspicion stops at 90; SORGU-2 walks
## over (stops at 64 px), asks, recognised once.
func test_intact_customer_in_view_30s_is_questioned_not_held() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = _search(stage)
	eq(o.brain().state(), OwnerBrain.State.SEARCH, "hırsız kayıp: ARA")
	var asks: Array[float] = []
	var ask_dist: Array[float] = []
	var recognized: Array[int] = []
	o.recognized.connect(func(peer_id: int) -> void: recognized.append(peer_id))
	var c1: Player = stage.player(2, CUSTOMER_SPOT)
	o.owner_question_search.connect(func(peer_id: int) -> void:
		if peer_id == 2:
			asks.append(o.brain().fsm.clock)
			ask_dist.append(o.global_position.distance_to(c1.global_position)))
	var start_dist: float = o.global_position.distance_to(CUSTOMER_SPOT)
	var peak: Array[float] = [0.0]
	var held: Array[bool] = [false]
	var alarmed: Array[bool] = [true]
	stage.run(30.0, func() -> void:
		peak[0] = maxf(peak[0], o.suspicion().value_of(2))
		held[0] = held[0] or not c1.is_free()
		alarmed[0] = alarmed[0] and o.brain().is_alarmed())
	is_true(alarmed[0], "30 sn boyunca sahip alarmda (ARA)")
	is_false(held[0], "örtüsü sağlam müşteri tutulmadı")
	is_true(peak[0] >= 60.0 and peak[0] <= 90.5, "şüphe 90'da durur (%.1f)" % peak[0])
	is_true(start_dist > 64.0, "sorgu yürüyerek (%.0f px)" % start_dist)
	if is_true(asks.size() >= 1 and asks.size() <= 2, "sorgu 1-2 kez (20 sn aralık): %s" % [asks]):
		is_true(ask_dist[0] <= 64.5, "64 px'te sorar (%.1f)" % ask_dist[0])
		if asks.size() == 2:
			is_true(asks[1] - asks[0] >= 20.0 - 0.01, "aynı oyuncuya 20 sn içinde yeniden sorgu yok")
	eq(recognized, [2] as Array[int], "tanındı +1, iş başına bir kez")
	eq(o.brain().search_questions.size(), asks.size(), "döküm search_questions")
	eq(o.brain().state(), OwnerBrain.State.SEARCH, "aramaya döndü")
	Game.set_alert_level(0)
	stage.leave()


## AC5 (2): an intact player who runs while the owner searches -> cover breaks (Game's tracker; emulated) -> ALARM row -> "!" within 1 s.
func test_running_intact_player_detected_within_one_second() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = _search(stage)
	var c1: Player = stage.player(2, CUSTOMER_SPOT)
	stage.run(12.0)
	var before: float = o.suspicion().value_of(2)
	is_true(before >= 60.0 and before <= 90.5, "koşmadan önce tavanda/altında (%.1f)" % before)
	var running: Array[bool] = [true]
	o.senses().cover_query = func(peer_id: int) -> bool: return peer_id == 2 and not running[0]
	c1.net_mode = PlayerMotion.Mode.SPRINT
	var t: Array[float] = [0.0]
	var detect_at: Array[float] = [-1.0]
	stage.run(1.0, func() -> void:
		t[0] += DT
		if detect_at[0] < 0.0 and o.suspicion().level_of(2) >= Suspicion.Level.DETECT:
			detect_at[0] = t[0])
	is_true(detect_at[0] > 0.0 and detect_at[0] <= 1.0, "koşan: <= 1,0 sn'de ! (%.2f sn)" % detect_at[0])
	c1.net_mode = PlayerMotion.Mode.WALK
	var chased: Array[bool] = [false]
	stage.run(4.0, func() -> void:
		chased[0] = chased[0] or o.brain().state() in [OwnerBrain.State.CHASE, OwnerBrain.State.HOLD])
	is_true(chased[0], "sahip kovaladı (zincir aynen)")
	is_false(c1.is_free(), "tutuldu / yakalandı")
	Game.set_alert_level(0)
	stage.leave()


## AC5 (3), GB-12 order: the thief is held on the staff side; the intact customer in view stays <= 90 and free, PULLs within the 6 s
## window -> both free, the owner staggers, the rescuer's cover breaks (seen RESCUE; emulated) and gets 100.
func test_gb12_rescue_from_intact_cover() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var cover_lost: Dictionary = {3: true}
	o.senses().cover_query = func(peer_id: int) -> bool: return not cover_lost.has(peer_id)
	o.senses().loiter_query = func(_peer_id: int) -> float: return LOITER_S
	stage.run(1.0)
	var host: Player = stage.player(3, STAFF_FRONT)
	for i: int in roundi(6.0 / DT):
		stage.run(DT)
		if host.is_held():
			break
	if not is_true(host.is_held(), "personel tarafında tutuldu"):
		stage.leave()
		return
	var c1: Player = stage.player(2, host.position + Vector2(-24, 8))
	stage.run(2.0)
	is_true(c1.is_free(), "örtüsü sağlam c1 tutulmadı")
	is_true(o.suspicion().value_of(2) <= 90.5, "c1 tavanda/altında (%.1f)" % o.suspicion().value_of(2))
	host.rescued.connect(func(_by: int) -> void: cover_lost[2] = true)  # Game: the seen RESCUE breaks the rescuer's cover
	var rescue: Interactable = stage.level.players_root().get_node(^"3/Status/Rescue") as Interactable
	rescue.host_start(2, 1)
	stage.run(1.1)
	is_true(host.is_free() and c1.is_free(), "ikisi serbest")
	eq(o.brain().state(), OwnerBrain.State.STAGGER, "sahip sendeler")
	is_false(o.senses().cover_intact(2), "c1'in örtüsü bozuldu")
	eq(o.suspicion().value_of(2), 100.0, "kurtarana 100 (tavan kanıtı kesmez)")
	Game.set_alert_level(0)
	stage.leave()


## KR-041 addendum (b): when the search ends the capped intact customer drops to 59; the calm chain asks "Ne yapıyorsun?" before any
## shout at him (no instant 90 -> 100 detection).
func test_search_end_drops_intact_to_59_then_calm_question_first() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = _search(stage)
	o.brain().owner_tuning.calm_after_sec = 12.0  # the test's own copy (_long_search)
	var c1: Player = stage.player(2, CUSTOMER_SPOT)
	var order: Array[StringName] = []
	o.owner_question.connect(func(peer_id: int) -> void:
		if peer_id == 2:
			order.append(&"question"))
	o.owner_shout.connect(func(peer_id: int) -> void:
		if peer_id == 2:
			order.append(&"shout"))
	var calm_value: Array[float] = [-1.0]
	var capped_before: Array[float] = [0.0]
	stage.run(16.0, func() -> void:
		var v: float = o.suspicion().value_of(2)
		if o.brain().is_alarmed():
			capped_before[0] = v
		elif calm_value[0] < 0.0:
			calm_value[0] = v)
	is_true(capped_before[0] >= 85.0, "arama boyunca tavanda (%.1f)" % capped_before[0])
	is_true(calm_value[0] >= 0.0 and calm_value[0] <= 59.5, "arama bitince 59'a iner (%.1f)" % calm_value[0])
	stage.run(10.0)
	is_true(order.size() >= 1 and order[0] == &"question", "önce sakin sorgu, sonra (gerekirse) bağırış: %s" % [order])
	is_false(order.size() >= 1 and order[0] == &"shout", "anında bağırış yok")
	is_true(c1 != null)
	Game.set_alert_level(0)
	stage.leave()


## AC4: during SORGU-2 (owner at 64 px, waiting 3 s) the intact player can hold REDIRECT 1.5 s; accepted, +30 capped at 90 (no chase).
func test_misdirect_works_on_owner_during_search_question() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = _search(stage)
	var c1: Player = stage.player(2, CUSTOMER_SPOT)
	var asked: Array[bool] = [false]
	o.owner_question_search.connect(func(_peer_id: int) -> void: asked[0] = true)
	for i: int in roundi(20.0 / DT):
		stage.run(DT)
		if asked[0]:
			break
	if not is_true(asked[0], "sorgu başladı"):
		stage.leave()
		return
	await tree().physics_frame
	var item: Interactable = o.misdirect_interactable()
	var dist: float = o.global_position.distance_to(c1.interaction_position())
	is_true(item.enabled, "uyarı 2: YÖNLENDİR açık")
	is_true(item.can_start(2, c1.interaction_position(), c1.interaction_tags()), "64 px'te istem (%.1f px)" % dist)
	item.host_start(2, 1)
	stage.run(1.6)
	is_true(o.net_misdirected, "YÖNLENDİR sahibe karşı çalıştı (1,5 sn)")
	is_true(o.suspicion().value_of(2) <= 90.5, "+30 tavanda kesilir (%.1f)" % o.suspicion().value_of(2))
	stage.run(2.0)
	is_true(c1.is_free(), "kovalanmadı / tutulmadı")
	eq(o.brain().state(), OwnerBrain.State.SEARCH)
	Game.set_alert_level(0)
	stage.leave()
