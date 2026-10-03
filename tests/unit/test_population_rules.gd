extends TestCase
## US-016 AC1/AC2/AC4/AC6 (düğümsüz kurallar): SpotRegistry (claim/release), Agenda lineer rota kipi, nüfus
## zamanlayıcısı (tohumla belirlenimci, üst sınırlar, NPC tavanı, uyarıda duraklama), müşteri planı (kalış,
## raf noktası), sokak rotası + cam önü bakışları, camdan bakış yönü ve örtü çarpanı (CivilianRules).

const POP_TUNING := "res://data/npc/population.tres"
const CIV_TUNING := "res://data/npc/civilian_tuning.tres"
const PERC_TUNING := "res://data/npc/perception_tuning.tres"
## store_a işaretleri (levels/store_a.tscn; test_levels_population sırayı ayrıca denetler).
const ROUTE: Array[Vector2] = [Vector2(112, 496), Vector2(336, 496), Vector2(752, 496), Vector2(752, 336),
	Vector2(752, 80), Vector2(656, 48)]
const LOOKS: Array[Vector2] = [Vector2(208, 496), Vector2(464, 496), Vector2(752, 368)]


func _params() -> PopulationRules.Params:
	return (load(POP_TUNING) as PopulationTuning).rules_params(3, 6.0)


func test_spot_registry_claim_release() -> void:
	var r := SpotRegistry.new()
	is_true(r.claim(&"ShopSpot1", 1), "boş nokta tutulur")
	is_true(r.claim(&"ShopSpot1", 1), "kendi noktası yine true")
	is_false(r.claim(&"ShopSpot1", 2), "başkasının noktası tutulamaz")
	is_false(r.claim(&"", 2), "geçersiz ad")
	is_false(r.claim(&"ShopSpot2", 0), "geçersiz sahip")
	is_true(r.claim(&"ShopSpot3", 1))
	eq(r.spots_of(1), [&"ShopSpot1", &"ShopSpot3"] as Array[StringName])
	eq(r.free_of([&"ShopSpot1", &"ShopSpot2", &"ShopSpot3"] as Array[StringName]), [&"ShopSpot2"] as Array[StringName])
	eq(r.claim_first([&"QueueSpot1", &"QueueSpot2"] as Array[StringName], 2), &"QueueSpot1")
	eq(r.claim_first([&"QueueSpot1", &"QueueSpot2"] as Array[StringName], 3), &"QueueSpot2")
	eq(r.claim_first([&"QueueSpot1", &"QueueSpot2"] as Array[StringName], 4), &"", "kuyruk dolu")
	r.release(2, &"ShopSpot1")
	eq(r.holder_of(&"ShopSpot1"), 1, "başkasının noktası bırakılmaz")
	r.release(1)
	is_true(r.is_free(&"ShopSpot1") and r.is_free(&"ShopSpot3"), "sahibin bütün noktaları bırakılır")
	eq(r.holder_of(&"QueueSpot1"), 2)
	eq(r.size(), 2)


## Agenda lineer rota: sırayla, süre 0 = ara nokta, bitince `finished` bir kez; kesme ve advance çalışır.
func test_agenda_route_mode() -> void:
	var agenda: Agenda = autofree(Agenda.new()) as Agenda
	var points := {&"A": Vector2(0, 0), &"B": Vector2(100, 0), &"C": Vector2(200, 0)}
	var resolver := func(m: StringName) -> Array[Vector2]:
		var out: Array[Vector2] = []
		if points.has(m):
			out.append(points[m])
		return out
	var tasks: Array[AgendaTask] = []
	for item: Array in [[&"A", 0.0], [&"B", 2.0], [&"C", 0.0]]:
		var t := AgendaTask.new()
		t.name = StringName(String(item[0]).to_lower())
		t.marker = item[0]
		t.min_sec = item[1]
		t.max_sec = item[1]
		t.facing = Vector2.UP
		tasks.append(t)
	var done: Array[int] = [0]
	agenda.finished.connect(func() -> void: done[0] += 1)
	agenda.setup_route(tasks, 5, resolver)
	is_true(agenda.is_route())
	eq(agenda.task_name(), &"a")
	eq(agenda.goal_position(), Vector2(0, 0))
	agenda.step(0.1, true)
	eq(agenda.task_name(), &"b", "süre 0: ara nokta, varınca geçer")
	agenda.step(1.0, false)
	eq(agenda.task_name(), &"b", "varmadan süre işlemez")
	agenda.step(1.0, true)
	near(agenda.arrived_for(), 1.0, 0.001, "varıştan beri geçen")
	is_true(agenda.interrupt(Agenda.Interrupt.BELL, 0.5, Vector2.INF, Vector2(9, 9)))
	agenda.step(0.6, false)
	eq(agenda.task_name(), &"b", "kesme bitince görev kaldığı yerden")
	agenda.step(1.1, true)
	eq(agenda.task_name(), &"c")
	eq(done[0], 0)
	agenda.step(0.1, true)
	eq(done[0], 1, "son görev bitince finished")
	is_true(agenda.is_finished())
	is_false(agenda.goal_position().is_finite(), "bitince hedef yok")
	agenda.step(1.0, true)
	eq(done[0], 1, "finished bir kez")
	eq(agenda.sequence.slice(0, 5), [&"a", &"b", &"bell", &"b", &"c"] as Array[StringName])
	# advance: süren görevi bitirir; boş rota hemen biter.
	agenda.setup_route(tasks, 5, resolver)
	agenda.advance()
	agenda.advance()
	eq(agenda.task_name(), &"c")
	agenda.setup_route([] as Array[AgendaTask], 5, resolver)
	eq(done[0], 2, "boş rota hemen biter")


## Ev ↔ uzak kipinde `begin_task` adlı görevi başlatır, kesme bırakılır (`interrupt_ended` completed = false).
func test_agenda_begin_task_and_interrupt_ended() -> void:
	var agenda: Agenda = autofree(Agenda.new()) as Agenda
	var tuning: OwnerTuning = load("res://data/npc/owner_tuning.tres") as OwnerTuning
	var ended: Array = []
	agenda.interrupt_ended.connect(func(kind: Agenda.Interrupt, completed: bool) -> void: ended.append([kind, completed]))
	agenda.setup(tuning.tasks, 3, func(_m: StringName) -> Array[Vector2]: return [Vector2.ZERO] as Array[Vector2])
	eq(agenda.task_name(), &"counter")
	agenda.interrupt(Agenda.Interrupt.CUSTOMER, 6.0, Vector2.ZERO, Vector2.INF, true)
	agenda.step(2.0, true)
	near(agenda.interrupt_elapsed(), 2.0, 0.001)
	agenda.step(4.5, true)
	eq(ended, [[Agenda.Interrupt.CUSTOMER, true]], "süresi doldu: completed")
	agenda.interrupt(Agenda.Interrupt.CUSTOMER, 6.0)
	is_true(agenda.begin_task(&"backroom"))
	eq(agenda.task_name(), &"backroom")
	eq(ended[-1], [Agenda.Interrupt.CUSTOMER, false], "begin_task kesmeyi bırakır")
	agenda.interrupt(Agenda.Interrupt.LISTEN, 6.0)
	agenda.restart_home()
	eq(ended[-1], [Agenda.Interrupt.LISTEN, false], "restart_home kesmeyi bırakır")
	is_false(agenda.begin_task(&"yok"))


## Aynı tohum → aynı geliş anları ve planlar (I6); farklı tohum farklı. Basit benzetim: müşteri kalış sonunda,
## yoldan geçen 15 sn sonra ayrılır.
func test_schedule_is_deterministic() -> void:
	var a: Array = _simulate(7, 900.0)
	var b: Array = _simulate(7, 900.0)
	var c: Array = _simulate(8, 900.0)
	eq(a, b, "aynı tohum → aynı geliş/plan dizisi")
	ne(a, c, "farklı tohum → farklı dizi")
	is_true(a.size() >= 30, "900 sn'de yeterli geliş (%d)" % a.size())


func _simulate(seed_value: int, seconds: float) -> Array:
	var p: PopulationRules.Params = _params()
	var s := PopulationRules.Schedule.new(p, seed_value)
	var out: Array = []
	var leave: Array = []  # [rol, ayrılış anı]
	var dt: float = 0.1
	for i: int in roundi(seconds / dt):
		var t: float = (i + 1) * dt
		for k: int in range(leave.size() - 1, -1, -1):
			if float(leave[k][1]) <= t:
				leave.remove_at(k)
		var counts := PopulationRules.Counts.new()
		for item: Array in leave:
			if int(item[0]) == PopulationRules.Role.CUSTOMER:
				counts.customers += 1
			else:
				counts.passersby += 1
		counts.npcs = 1 + leave.size()
		for o: PopulationRules.Order in s.tick(dt, counts):
			out.append([o.role, snappedf(o.at, 0.01), snappedf(o.stay_sec, 0.01), o.dwell.size(), o.looks])
			leave.append([o.role, t + (o.stay_sec if o.role == PopulationRules.Role.CUSTOMER else 15.0)])
	return out


func test_schedule_timing_and_caps() -> void:
	var p: PopulationRules.Params = _params()
	var s := PopulationRules.Schedule.new(p, 7)
	is_true(s.next_customer >= 10.0 and s.next_customer <= 20.0, "ilk müşteri 10-20 sn (%.1f)" % s.next_customer)
	is_true(s.next_passerby >= 12.0 and s.next_passerby <= 28.0, "ilk yoldan geçen 20 ± 8 (%.1f)" % s.next_passerby)
	var counts := PopulationRules.Counts.new()
	counts.npcs = 1
	var first: float = s.next_customer
	var got: Array[PopulationRules.Order] = []
	while got.is_empty():
		got = s.tick(0.1, counts)
	near(got[0].at, first, 0.11)
	var gap: float = s.next_customer - s.clock
	is_true(gap >= 20.0 - 0.001 and gap <= 50.0 + 0.001, "aralık 35 ± 15 (%.1f)" % gap)
	# Üst sınırda gelen beklemez, iptal edilir; sonraki aralık çekilir.
	var full := PopulationRules.Counts.new()
	full.customers = 2
	full.npcs = 3
	is_false(PopulationRules.may_spawn(p, full, PopulationRules.Role.CUSTOMER), "içeride 2 müşteri: gelmez")
	full.customers = 1
	is_true(PopulationRules.may_spawn(p, full, PopulationRules.Role.CUSTOMER))
	full.npcs = 5
	is_false(PopulationRules.may_spawn(p, full, PopulationRules.Role.CUSTOMER), "NPC 5 + komşu payı 1 = tavan 6")
	full.npcs = 2
	full.alert_level = 2
	is_false(PopulationRules.may_spawn(p, full, PopulationRules.Role.PASSERBY), "uyarı 2: yeni sivil yok")
	full.alert_level = 1
	full.passersby = 2
	is_false(PopulationRules.may_spawn(p, full, PopulationRules.Role.PASSERBY), "sokakta 2: gelmez")
	var blocked := PopulationRules.Counts.new()
	blocked.customers = 2
	blocked.npcs = 3
	var before: int = s.cancelled.size()
	s.clock = s.next_customer - 0.05
	var customers: int = 0
	for o: PopulationRules.Order in s.tick(0.1, blocked):
		customers += 1 if o.role == PopulationRules.Role.CUSTOMER else 0
	eq(customers, 0, "iptal")
	eq(s.cancelled.size(), before + 1)
	is_true(s.next_customer > s.clock + 19.9, "iptalden sonra yeni aralık")


func test_customer_plan_fits_stay() -> void:
	var p: PopulationRules.Params = _params()
	var twos: int = 0
	for seed_value: int in 40:
		var s := PopulationRules.Schedule.new(p, seed_value)
		var counts := PopulationRules.Counts.new()
		var got: Array[PopulationRules.Order] = []
		while got.is_empty():
			got = s.tick(0.5, counts)
		var o: PopulationRules.Order = got[0]
		if o.role != PopulationRules.Role.CUSTOMER:
			continue
		is_true(o.stay_sec >= 25.0 and o.stay_sec <= 45.0, "kalış 25-45 (%.1f)" % o.stay_sec)
		is_true(o.dwell.size() >= 1 and o.dwell.size() <= 2, "1-2 raf noktası")
		eq(o.picks.size(), o.dwell.size())
		for d: float in o.dwell:
			is_true(d >= 8.0 and d <= 12.0, "raf 8-12 sn (%.1f)" % d)
		if o.dwell.size() == 2:
			twos += 1
			is_true(o.dwell[0] + o.dwell[1] + p.serve_sec + p.walk_margin_sec <= o.stay_sec, "iki nokta kalışa sığar")
	is_true(twos > 0, "iki noktalı plan da çıkar")
	eq(PopulationRules.pick([&"A", &"B", &"C"] as Array[StringName], 0.0), &"A")
	eq(PopulationRules.pick([&"A", &"B", &"C"] as Array[StringName], 0.99), &"C")
	eq(PopulationRules.pick([] as Array[StringName], 0.5), &"")


## Yoldan geçen planı: cam başına zar; olasılık %30 (çok sayıda örnekte 0,2-0,4).
func test_passerby_look_chance() -> void:
	var p: PopulationRules.Params = _params()
	var s := PopulationRules.Schedule.new(p, 11)
	var looks: int = 0
	var total: int = 0
	for i: int in 20000:
		for o: PopulationRules.Order in s.tick(1.0, PopulationRules.Counts.new()):
			if o.role == PopulationRules.Role.PASSERBY:
				eq(o.looks.size(), 3)
				for l: bool in o.looks:
					total += 1
					looks += 1 if l else 0
	is_true(total > 1000)
	var ratio: float = float(looks) / float(total)
	is_true(ratio > 0.27 and ratio < 0.33, "bakış oranı %.3f (0,3)" % ratio)


func test_street_route_inserts_window_looks() -> void:
	var r: Array[Dictionary] = PopulationRules.street_route(ROUTE, LOOKS)
	var looks: Array = []
	for item: Dictionary in r:
		looks.append(item["look"])
	eq(looks, [-1, 0, -1, 1, -1, 2, -1, -1, -1], "rota: a g b h c i d e f")
	eq(r[1]["pos"], LOOKS[0])
	eq(PopulationRules.street_route([] as Array[Vector2], LOOKS), [] as Array[Dictionary])
	# Camdan içeri bakış yönü: içerinin en yakın noktası (ön camlar yukarı, yan cam sola).
	var inside: Array[Rect2] = [Rect2(64, 128, 384, 320), Rect2(544, 288, 160, 160)]
	eq(PopulationRules.look_facing(LOOKS[0], inside), Vector2.UP)
	eq(PopulationRules.look_facing(LOOKS[2], inside), Vector2.LEFT)
	eq(PopulationRules.look_facing(Vector2(100, 200), inside), Vector2.ZERO, "içerideyse yön yok")


## AC6: içeride ≥ 1 müşteri varken müşteri bölgesindeki satırlar ×0,5; personel tarafı ve kasa satırları aynı.
func test_cover_factor() -> void:
	var civ: CivilianTuning = load(CIV_TUNING) as CivilianTuning
	var p: CivilianRules.Params = civ.rules_params(load(PERC_TUNING) as PerceptionTuning)
	near(p.cover_factor, 0.5, 0.0001)
	var ctx := CivilianRules.Context.new()
	ctx.zone = CivilianRules.Zone.CUSTOMER
	ctx.stance = PerceptionRules.Stance.SNEAK
	near(CivilianRules.factor(p, ctx), 0.5, 0.0001, "müşterisiz sızma 0,5")
	ctx.customers_inside = 1
	near(CivilianRules.factor(p, ctx), 0.25, 0.0001, "örtü: sızma ×0,5")
	ctx.stance = PerceptionRules.Stance.SPRINT
	near(CivilianRules.factor(p, ctx), 0.5, 0.0001, "örtü: koşu ×0,5")
	ctx.stance = PerceptionRules.Stance.WALK
	ctx.loiter_time = 61.0
	near(CivilianRules.factor(p, ctx), 0.125, 0.0001, "örtü: oyalanma ×0,5")
	ctx.interaction = CivilianRules.Interaction.CASH
	near(CivilianRules.factor(p, ctx), 2.5, 0.0001, "kasa satırı etkilenmez")
	ctx.interaction = CivilianRules.Interaction.NONE
	ctx.zone = CivilianRules.Zone.STAFF
	near(CivilianRules.factor(p, ctx), 1.5, 0.0001, "personel tarafı etkilenmez")
	ctx.zone = CivilianRules.Zone.OUTSIDE
	ctx.carrying_bag = true
	near(CivilianRules.factor(p, ctx), 1.5, 0.0001, "dışarısı (müşteri bölgesi değil) etkilenmez")
