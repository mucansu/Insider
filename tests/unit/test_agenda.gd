extends TestCase
## US-008 AC1/AC2 (+ I6): Agenda bileşeni ve sahibin ajandası store_a geometrisinde. 300 sn headless ölçüm (sabit
## adım, gerçek gezinme ve görüş hattı): kasa (`Register` işareti) sahibin konisi + görüş hattı dışında kalan
## toplam süre 60-120 sn, ≥ 4 pencere (her ≥ 10 sn), ardışık pencereler arasında ≥ 15 sn kasa görünür (tezgâh).
## Aynı tohum → aynı görev dizisi (I6). Kesmeler: öncelik GÖNDERİLDİ > MÜŞTERİ > DİNLE > ZİL, geri alma (kalan
## süre korunur), zil telefonu kesmez. Ölçüm kuralı `window_stats` hatalı varyantlarla da sınanır.

const DT := 1.0 / 60.0
const COARSE_DT := 1.0 / 30.0
const MEASURE_SEC := 300.0
const WINDOW_MIN := 10.0
const GAP_MIN := 15.0
const TOTAL_MIN := 60.0
const TOTAL_MAX := 120.0
const MIN_WINDOWS := 4
const OWNER_TUNING := "res://data/npc/owner_tuning.tres"
## Kasayı boşaltan oyuncunun durduğu yer: kasanın personel tarafı (register.tres taraf kısıtı +x, ≥ 16 px).
## Kasa işareti tezgâh karosunun içindedir (görüşü keser); ölçüm bu noktayla yapılır.
const REGISTER_STAFF_SIDE := Vector2(24, 0)


## Görünürlük örneklerinden pencere istatistiği: pencere = kasanın görünmediği kesintisiz süre; ≥ WINDOW_MIN olanlar
## sayılır; ardışık sayılan iki pencere arasında görünür geçen toplam süre `gaps`'e yazılır.
static func window_stats(visible: PackedByteArray, dt: float) -> Dictionary:
	var windows: Array[float] = []
	var gaps: Array[float] = []
	var total: float = 0.0
	var run: float = 0.0
	var seen_since: float = -1.0
	for i: int in visible.size() + 1:
		var hidden: bool = i < visible.size() and visible[i] == 0
		if hidden:
			run += dt
			total += dt
			continue
		if run >= WINDOW_MIN:
			if seen_since >= 0.0:
				gaps.append(seen_since)
			windows.append(run)
			seen_since = 0.0
		elif run > 0.0 and seen_since >= 0.0:
			pass  # kısa görünmezlik pencere sayılmaz, tezgâh süresine de eklenmez
		run = 0.0
		if i < visible.size() and seen_since >= 0.0:
			seen_since += dt
	return {"windows": windows, "gaps": gaps, "total": total}


static func check_stats(stats: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var windows: Array[float] = stats["windows"]
	var total: float = stats["total"]
	if total < TOTAL_MIN or total > TOTAL_MAX:
		problems.append("toplam görünmezlik %.1f sn (60-120)" % total)
	if windows.size() < MIN_WINDOWS:
		problems.append("pencere sayısı %d (≥ 4)" % windows.size())
	for g: float in stats["gaps"]:
		if g < GAP_MIN:
			problems.append("pencereler arası tezgâh %.1f sn (≥ 15)" % g)
	return problems


## 300 sn ölçüm: kasanın sahibin konisinde (o anki koni) ve görüş hattında olup olmadığı.
func _measure(agenda_seed: int, dt: float) -> Dictionary:
	var stage := NpcStage.new(self)
	var level: Level = await stage.enter()
	var o: StoreOwner = stage.owner()
	var tuning: OwnerTuning = (o.owner_tuning.duplicate(true)) as OwnerTuning
	tuning.agenda_seed = agenda_seed
	o.agenda().setup(tuning.tasks, agenda_seed, o.senses().marker_positions)
	var register: Vector2 = stage.marker(&"Register") + REGISTER_STAFF_SIDE
	var p: Perception = o.perception()
	var samples := PackedByteArray()
	var probe := func() -> void:
		var params: PerceptionRules.Params = p.params()
		var seen: bool = PerceptionRules.in_cone(p.global_position, p.facing, params.half_angle_deg,
			params.view_range, register) and p.has_line_of_sight(p.global_position, register)
		samples.append(1 if seen else 0)
	var walls: Array[int] = [0]
	var wall_probe := func() -> void:
		probe.call()
		if _inside_wall(o):
			walls[0] += 1
	stage.run(MEASURE_SEC, wall_probe, dt)
	var out: Dictionary = window_stats(samples, dt)
	out["sequence"] = o.agenda().sequence.duplicate()
	out["wall_frames"] = walls[0]
	stage.leave()
	return out


static func _inside_wall(o: StoreOwner) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = o.global_position
	query.collision_mask = PhysicsLayers.WORLD
	return not o.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func test_owner_agenda_opens_register_windows() -> void:
	var tuning: OwnerTuning = load(OWNER_TUNING) as OwnerTuning
	var stats: Dictionary = await _measure(tuning.agenda_seed, DT)
	var problems: PackedStringArray = check_stats(stats)
	is_true(problems.is_empty(), "AC2 tohum %d: %s\n  pencereler %s\n  aralar %s\n  dizi %s" % [tuning.agenda_seed,
		", ".join(problems), stats["windows"], stats["gaps"], stats["sequence"]])
	eq(stats["wall_frames"], 0, "I7: sahip hiçbir karede duvar/raf içinde değil")


## Ayar tek tohuma göre kurulmuş olmasın: başka tohumlarda da kabul tutar (kaba adım).
func test_agenda_windows_hold_across_seeds() -> void:
	for agenda_seed: int in [1, 2, 3, 4, 5]:
		var stats: Dictionary = await _measure(agenda_seed, COARSE_DT)
		var problems: PackedStringArray = check_stats(stats)
		is_true(problems.is_empty(), "AC2 tohum %d: %s\n  pencereler %s\n  aralar %s" % [agenda_seed,
			", ".join(problems), stats["windows"], stats["gaps"]])


## Ölçüm kuralı hatalı ajandaları yakalar (bozuk varyant → düşer).
func test_window_rule_rejects_bad_agendas() -> void:
	var dt: float = 0.5
	# İyi: 30 sn tezgâh / 15 sn pencere, 300 sn: 6-7 pencere, toplam ~100.
	eq(check_stats(window_stats(_pattern([[30.0, 1], [15.0, 0]], 300.0, dt), dt)).size(), 0, "iyi ajanda geçer")
	# Pencere kısa (8 sn): sayılmaz.
	ne(check_stats(window_stats(_pattern([[30.0, 1], [8.0, 0]], 300.0, dt), dt)).size(), 0, "kısa pencere düşer")
	# Tezgâh kısa (10 sn) — pencereler arası < 15 sn ve toplam > 120.
	ne(check_stats(window_stats(_pattern([[10.0, 1], [12.0, 0]], 300.0, dt), dt)).size(), 0, "kısa tezgâh düşer")
	# Çok seyrek: 80 sn tezgâh / 12 sn pencere → 3 pencere, toplam < 60.
	ne(check_stats(window_stats(_pattern([[80.0, 1], [12.0, 0]], 300.0, dt), dt)).size(), 0, "seyrek pencere düşer")


static func _pattern(cycle: Array, seconds: float, dt: float) -> PackedByteArray:
	var out := PackedByteArray()
	var t: float = 0.0
	while t < seconds:
		for part: Array in cycle:
			for i: int in roundi(float(part[0]) / dt):
				if t >= seconds:
					break
				out.append(int(part[1]))
				t += dt
	return out


# --- Agenda bileşeni (düğüm, sahnesiz) ---

func _agenda(agenda_seed: int = 3) -> Agenda:
	var agenda := Agenda.new()
	autofree(agenda)
	var tuning: OwnerTuning = load(OWNER_TUNING) as OwnerTuning
	var spots := {&"ClerkSpot": [Vector2(0, 0)], &"RestockSpot": [Vector2(10, 0), Vector2(20, 0), Vector2(30, 0)],
		&"BackroomSpot": [Vector2(0, 10)], &"PhoneSpot": [Vector2(0, 20)]}
	agenda.setup(tuning.tasks, agenda_seed, func(m: StringName) -> Array:
		var got: Array[Vector2] = []
		for v: Vector2 in spots.get(m, []):
			got.append(v)
		return got)
	return agenda


static func _run_agenda(agenda: Agenda, seconds: float) -> void:
	for i: int in roundi(seconds / 0.1):
		agenda.step(0.1, true)


func test_agenda_is_deterministic_and_alternates() -> void:
	var a: Agenda = _agenda(11)
	var b: Agenda = _agenda(11)
	var c: Agenda = _agenda(12)
	_run_agenda(a, 600.0)
	_run_agenda(b, 600.0)
	_run_agenda(c, 600.0)
	eq(a.sequence, b.sequence, "I6: aynı tohum → aynı görev dizisi")
	ne(a.sequence, c.sequence, "farklı tohum farklı dizi")
	is_true(a.sequence.size() > 10)
	for i: int in a.sequence.size():
		var home: bool = a.sequence[i] == &"counter"
		eq(home, i % 2 == 0, "tezgâh ↔ pencere görevi dönüşümlü (%d: %s)" % [i, a.sequence[i]])
		if i >= 3 and not home:
			ne(a.sequence[i], a.sequence[i - 2], "aynı pencere görevi art arda gelmez")


func test_task_time_counts_after_arrival() -> void:
	var a: Agenda = _agenda()
	eq(a.task_name(), &"counter")
	var left: float = a.time_left()
	is_true(left >= 25.0 and left <= 40.0, "tezgâh 25-40 sn (gelen %.1f)" % left)
	for i: int in 100:
		a.step(0.1, false)  # yolda: süre işlemez
	near(a.time_left(), left, 0.001)
	a.step(0.1, true)
	near(a.time_left(), left - 0.1, 0.001)


func test_interrupt_priority_and_resume() -> void:
	var a: Agenda = _agenda()
	a.step(0.1, true)
	var left: float = a.time_left()
	is_true(a.interrupt(Agenda.Interrupt.LISTEN, 8.0, Vector2(5, 5), Vector2(5, 5)))
	eq(a.task_name(), &"listen")
	eq(a.goal_position(), Vector2(5, 5))
	is_false(a.interrupt(Agenda.Interrupt.BELL, 1.0), "zil dinlemeyi kesmez (öncelik)")
	is_true(a.interrupt(Agenda.Interrupt.CUSTOMER, 6.0, Vector2(0, 0), Vector2.INF, true), "müşteri > dinle")
	is_true(a.interrupt(Agenda.Interrupt.SENT, 10.0, Vector2(0, 10), Vector2.INF, true), "gönderildi > müşteri")
	is_false(a.interrupt(Agenda.Interrupt.CUSTOMER, 6.0), "müşteri gönderilmeyi kesmez")
	for i: int in 50:
		a.step(0.1, false)  # varmadı: süre işlemez
	eq(a.task_name(), &"sent")
	for i: int in 101:
		a.step(0.1, true)
	eq(a.task_name(), &"counter", "kesme bitince görev sürer")
	a.step(0.1, true)
	near(a.time_left(), left - 0.1, 0.05, "kalan süre korundu")


func test_bell_does_not_interrupt_phone() -> void:
	var a: Agenda = _agenda()
	var guard: int = 0
	while a.task_name() != &"phone" and guard < 20000:
		a.step(0.1, true)
		guard += 1
	if not is_true(a.task_name() == &"phone", "telefon görevi gelmeli"):
		return
	eq(a.half_angle_deg(), 25.0, "telefonda koni daralır")
	is_false(a.interrupt(Agenda.Interrupt.BELL, 1.0, Vector2.INF, Vector2(0, 0)), "zil telefonu kesmez")
	is_true(a.interrupt(Agenda.Interrupt.LISTEN, 8.0, Vector2.INF, Vector2(0, 0)), "ses keser")
