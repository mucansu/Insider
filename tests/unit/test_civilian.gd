extends TestCase
## US-008 AC3 (+ AC7/AC8 kuralları, ON-03, ON-04): sivil çarpan tablosu (GDD §6.1) core'da, sabit adımla
## (PerceptionRules + SuspicionMeter + CivilianRules; gerçek data/npc ayarlarıyla). Süreler: kasa tutarken yakın
## bant tespit 1,0 sn (0,2 + 0,8; ±1 kare), uzak 1,8 sn; müşteri bölgesinde yürüyen 60 sn hiç dolmaz, sonra 0,25;
## personel tarafı 1,5 sn; sızma 4,2 sn; "?" her satırda tespitten ≥ 0,5 sn önce; görünüp masumken boşalma
## 10/sn, görünmeyince 20/sn. Hatalı varyantlar (çarpanları çarpmak, kasa çarpanını büyütmek) bu ölçütte düşer.

const DT := 1.0 / 60.0
const FRAME := DT + 0.0001
const PERCEPTION := "res://data/npc/perception_tuning.tres"
const CIVILIAN := "res://data/npc/civilian_tuning.tres"

var _pt: PerceptionTuning
var _ct: CivilianTuning
var _cone: PerceptionRules.Params
var _meter: SuspicionMeter.Params
var _rules: CivilianRules.Params


func _setup() -> void:
	_pt = load(PERCEPTION) as PerceptionTuning
	_ct = load(CIVILIAN) as CivilianTuning
	_cone = Perception.params_for(_pt, Perception.Observer.GUARD)
	_cone.half_angle_deg = _ct.half_angle_deg
	_cone.view_range = _ct.view_range
	_meter = Suspicion.params_for(_pt)
	_rules = _ct.rules_params(_pt)


func _ctx(zone: CivilianRules.Zone, stance: PerceptionRules.Stance = PerceptionRules.Stance.WALK,
		interaction: CivilianRules.Interaction = CivilianRules.Interaction.NONE, loiter: float = 0.0,
		alert: int = 0) -> CivilianRules.Context:
	var c := CivilianRules.Context.new()
	c.zone = zone
	c.stance = stance
	c.interaction = interaction
	c.loiter_time = loiter
	c.alert_level = alert
	return c


## Görülen hedef: dolum = taban × bant × çarpan (Perception.observe_target'taki factor_query yolu).
func _rate(band: PerceptionRules.Band, factor: float) -> float:
	return _cone.base_fill * PerceptionRules.band_factor(_cone, band) * factor


## Sabit adımla sürer: [t_?, t_tespit] (yoksa -1). `factor_at(t)` o andaki çarpan.
func _times(band: PerceptionRules.Band, factor_at: Callable, seconds: float) -> Array[float]:
	var m := SuspicionMeter.new()
	var out: Array[float] = [-1.0, -1.0]
	var t: float = 0.0
	for i: int in roundi(seconds / DT):
		t += DT
		for level: int in m.step(_meter, _rate(band, float(factor_at.call(t))), DT):
			if level == Suspicion.Level.NOTICE and out[0] < 0.0:
				out[0] = t
			if level == Suspicion.Level.DETECT and out[1] < 0.0:
				out[1] = t
	return out


func _constant(ctx: CivilianRules.Context) -> Callable:
	var f: float = CivilianRules.factor(_rules, ctx)
	return func(_t: float) -> float: return f


## Satır ölçütü: tespit beklenen süreye ±1 kare, "?" tespitten ≥ 0,5 sn önce.
func _row_ok(times: Array[float], expected: float) -> bool:
	return absf(times[1] - expected) <= FRAME and times[0] >= 0.0 and times[1] - times[0] >= 0.5 - 0.0001


func test_table_detection_times() -> void:
	_setup()
	var cash: Callable = _constant(_ctx(CivilianRules.Zone.STAFF, PerceptionRules.Stance.WALK,
		CivilianRules.Interaction.CASH))
	var near_cash: Array[float] = _times(PerceptionRules.Band.NEAR, cash, 5.0)
	near(near_cash[1], 1.0, FRAME, "kasa tutarken yakın bant: 0,2 + 0,8 sn")
	var far_cash: Array[float] = _times(PerceptionRules.Band.FAR, cash, 5.0)
	near(far_cash[1], 1.8, FRAME, "kasa tutarken uzak bant: 0,2 + 1,6 sn")
	var staff: Array[float] = _times(PerceptionRules.Band.NEAR, _constant(_ctx(CivilianRules.Zone.STAFF)), 5.0)
	near(staff[1], 0.2 + 100.0 / 75.0, FRAME, "personel tarafı ~1,5 sn")
	is_true(staff[1] <= 1.55, "personel tarafı ≤ 1,5 sn (+kare)")
	var sneak: Array[float] = _times(PerceptionRules.Band.NEAR,
		_constant(_ctx(CivilianRules.Zone.CUSTOMER, PerceptionRules.Stance.SNEAK)), 8.0)
	near(sneak[1], 4.2, FRAME, "sızma (dükkân içi) yakın bant 4,2 sn")
	var sprint: Array[float] = _times(PerceptionRules.Band.NEAR,
		_constant(_ctx(CivilianRules.Zone.CUSTOMER, PerceptionRules.Stance.SPRINT)), 5.0)
	near(sprint[1], 2.2, FRAME, "koşma (dükkân içi) yakın bant 2,2 sn")
	var alarm: Array[float] = _times(PerceptionRules.Band.NEAR,
		_constant(_ctx(CivilianRules.Zone.CUSTOMER, PerceptionRules.Stance.WALK, CivilianRules.Interaction.NONE, 0.0, 2)), 5.0)
	near(alarm[1], 1.0, FRAME, "bağırıştan sonra herkes 2,5")
	for row: Array[float] in [near_cash, far_cash, staff, sneak, sprint, alarm]:
		is_true(row[1] - row[0] >= 0.5 - 0.0001, "\"?\" tespitten ≥ 0,5 sn önce (gelen %.3f → %.3f)" % [row[0], row[1]])


func test_customer_area_is_innocent_for_60_seconds() -> void:
	_setup()
	var loiter := func(t: float) -> float:
		return CivilianRules.factor(_rules, _ctx(CivilianRules.Zone.CUSTOMER, PerceptionRules.Stance.WALK,
			CivilianRules.Interaction.NONE, t))
	var m := SuspicionMeter.new()
	var t: float = 0.0
	var at_60: float = -1.0
	while t < 61.0 - 0.0001:
		t += DT
		m.step(_meter, _rate(PerceptionRules.Band.NEAR, float(loiter.call(t))), DT)
		if at_60 < 0.0 and t >= 60.0 - 0.0001:
			at_60 = m.value
	eq(at_60, 0.0, "müşteri bölgesinde yürüyen 60 sn hiç dolmaz")
	is_true(m.value > 0.0, "61. sn'de oyalanma dolmaya başlar (gelen %.3f)" % m.value)
	eq(CivilianRules.factor(_rules, _ctx(CivilianRules.Zone.CUSTOMER, PerceptionRules.Stance.WALK,
		CivilianRules.Interaction.NONE, 61.0)), 0.25)
	eq(CivilianRules.behaviour(_rules, _ctx(CivilianRules.Zone.CUSTOMER, PerceptionRules.Stance.WALK,
		CivilianRules.Interaction.NONE, 61.0)), CivilianRules.Behaviour.LOITER)
	# Oyalanmada yakın bantta tespit: 0,2 + 100 / 12,5 = 8,2 sn ("?" çok önce).
	var long: Array[float] = _times(PerceptionRules.Band.NEAR, func(_t: float) -> float: return 0.25, 20.0)
	near(long[1], 8.2, FRAME)


func test_most_suspicious_row_wins_not_product() -> void:
	_setup()
	var ctx := _ctx(CivilianRules.Zone.STAFF, PerceptionRules.Stance.SPRINT, CivilianRules.Interaction.CASH, 99.0, 2)
	eq(CivilianRules.factor(_rules, ctx), 2.5, "en büyük satır (çarpılmaz)")
	ctx = _ctx(CivilianRules.Zone.BACKROOM, PerceptionRules.Stance.SNEAK)
	eq(CivilianRules.factor(_rules, ctx), 1.5, "arka oda personel satırı sızmaya baskın")
	eq(CivilianRules.behaviour(_rules, ctx), CivilianRules.Behaviour.STAFF_SIDE)
	ctx = _ctx(CivilianRules.Zone.OUTSIDE, PerceptionRules.Stance.SPRINT)
	eq(CivilianRules.factor(_rules, ctx), 0.0, "sokakta koşmak suç değil (yalnız dükkân içi)")
	ctx = _ctx(CivilianRules.Zone.OUTSIDE, PerceptionRules.Stance.WALK, CivilianRules.Interaction.TAMPER)
	eq(CivilianRules.factor(_rules, ctx), 1.5, "dışarıdan kilit açma 1,5")
	ctx = _ctx(CivilianRules.Zone.OUTSIDE)
	ctx.carrying_bag = true
	eq(CivilianRules.factor(_rules, ctx), 1.5, "çanta taşıma 1,5")
	ctx = _ctx(CivilianRules.Zone.OUTSIDE, PerceptionRules.Stance.WALK, CivilianRules.Interaction.NONE, 0.0, 2)
	eq(CivilianRules.factor(_rules, ctx), 2.5, "bağırıştan sonra sokakta da herkes")
	eq(CivilianRules.behaviour_name(CivilianRules.behaviour(_rules, ctx)), &"alarm")


## Hatalı varyantlar ölçütü geçemez: çarpanları çarpmak ve kasa çarpanını 3'e çıkarmak.
func test_wrong_variants_fail_the_row_check() -> void:
	_setup()
	var ok: Array[float] = _times(PerceptionRules.Band.NEAR, _constant(_ctx(CivilianRules.Zone.STAFF,
		PerceptionRules.Stance.WALK, CivilianRules.Interaction.CASH)), 5.0)
	is_true(_row_ok(ok, 1.0), "doğru tablo kasa satırını geçer")
	var product: Array[float] = _times(PerceptionRules.Band.NEAR, func(_t: float) -> float:
		return _rules.staff_factor * _rules.cash_factor, 5.0)
	is_false(_row_ok(product, 1.0), "çarpılan çarpanlar (3,75) kasa satırını tutturamaz (gelen %.3f)" % product[1])
	var greedy: Array[float] = _times(PerceptionRules.Band.NEAR, func(_t: float) -> float: return 3.0, 5.0)
	is_false(_row_ok(greedy, 1.0), "kasa çarpanı 3 → tespit < 1 sn")
	# Pay yok (0,2 sn grace atlanırsa) "?" → tespit aralığı yine ≥ 0,5 ama süre tutmaz.
	var no_grace := SuspicionMeter.Params.new()
	no_grace.decay_per_sec = _meter.decay_per_sec
	no_grace.thresholds = _meter.thresholds
	no_grace.gap_tolerance = _meter.gap_tolerance
	var m := SuspicionMeter.new()
	var t: float = 0.0
	while m.level < Suspicion.Level.DETECT and t < 5.0:
		t += DT
		m.step(no_grace, _rate(PerceptionRules.Band.NEAR, 2.5), DT)
	is_false(absf(t - 1.0) <= FRAME, "oyuncu lehine pay olmadan kasa 0,8 sn'de görülür (ölçüt düşer)")


func test_innocent_decay_vs_unseen_decay() -> void:
	_setup()
	var innocent: SuspicionMeter.Params = Suspicion.params_for(_pt)
	innocent.decay_per_sec = _rules.innocent_decay
	var a := SuspicionMeter.new()
	var b := SuspicionMeter.new()
	a.value = 50.0
	b.value = 50.0
	a.seen_for = 1.0
	b.seen_for = 1.0
	for i: int in roundi(2.2 / DT):
		a.step(innocent, 0.0, DT)  # görünüyor ama masum (çarpan 0)
		b.step(_meter, 0.0, DT)  # görünmüyor
	near(a.value, 50.0 - 10.0 * 2.0, 0.2, "görünüp masumken 10/sn (0,2 sn kesinti payından sonra)")
	near(b.value, 50.0 - 20.0 * 2.0, 0.2, "görünmeyince 20/sn")


func test_zone_lookup_and_rescue_rules() -> void:
	var rects := {
		CivilianRules.Zone.CUSTOMER: [Rect2(0, 0, 100, 100)],
		CivilianRules.Zone.STAFF: [Rect2(100, 0, 50, 100)],
		CivilianRules.Zone.BACKROOM: [Rect2(0, -60, 150, 50), Rect2(200, 0, 10, 10)],
	}
	eq(CivilianRules.zone_at(Vector2(50, 50), rects), CivilianRules.Zone.CUSTOMER)
	eq(CivilianRules.zone_at(Vector2(120, 50), rects), CivilianRules.Zone.STAFF)
	eq(CivilianRules.zone_at(Vector2(205, 5), rects), CivilianRules.Zone.BACKROOM, "çok parçalı bölge")
	eq(CivilianRules.zone_at(Vector2(100, 50), rects), CivilianRules.Zone.STAFF, "sınırda personel baskın")
	eq(CivilianRules.zone_at(Vector2(500, 500), rects), CivilianRules.Zone.OUTSIDE)
	eq(CivilianRules.hold_window(0, 6.0, 3.0), 6.0, "ilk tutma 6 sn")
	eq(CivilianRules.hold_window(1, 6.0, 3.0), 3.0, "ikinci kez 3 sn")
	var c: float = 0.0
	for i: int in 29:
		c = CivilianRules.contact_step(c, 20.0, 28.0, DT)
	is_true(c < 0.5, "29 kare < 0,5 sn")
	c = CivilianRules.contact_step(c, 28.0, 28.0, DT)
	near(c, 0.5, 0.001, "28 px dahil, 30. karede 0,5 sn")
	eq(CivilianRules.contact_step(c, 28.5, 28.0, DT), 0.0, "menzilden çıkınca sıfır")


## ON-03: tutma/yakalamada oyuncu konumu hızı yönünde min(RTT/2, 0,1 sn) ileri alınır.
func test_contact_lead_prediction() -> void:
	var v := Vector2(220, 0)
	eq(CivilianRules.predicted_position(Vector2.ZERO, v, 0.0, 0.1), Vector2.ZERO, "host (RTT 0): ileri alma yok")
	near(CivilianRules.predicted_position(Vector2.ZERO, v, 150.0, 0.1), Vector2(16.5, 0), 0.001, "150 ms: 75 ms ileri")
	near(CivilianRules.predicted_position(Vector2.ZERO, v, 400.0, 0.1), Vector2(22, 0), 0.001, "tavan 0,1 sn")
	eq(CivilianRules.predicted_position(Vector2(5, 5), Vector2.ZERO, 150.0, 0.1), Vector2(5, 5), "duran oyuncu")


## ON-04: gösterge istemcide çoğaltılan ölçerden; "?" histerezisli, "!" alarm kilidinde titremez.
func test_bubble_thresholds_and_hysteresis() -> void:
	_setup()
	var none: int = CivilianRules.Bubble.NONE
	eq(CivilianRules.bubble(_rules, 29.0, false, none), none)
	eq(CivilianRules.bubble(_rules, 30.0, false, none), CivilianRules.Bubble.NOTICE)
	eq(CivilianRules.bubble(_rules, 27.0, false, CivilianRules.Bubble.NOTICE), CivilianRules.Bubble.NOTICE,
		"eşiğin hemen altında söner değil (histerezis)")
	eq(CivilianRules.bubble(_rules, 24.0, false, CivilianRules.Bubble.NOTICE), none)
	eq(CivilianRules.bubble(_rules, 27.0, false, none), none, "histerezis yalnız gösterilirken")
	eq(CivilianRules.bubble(_rules, 100.0, false, none), CivilianRules.Bubble.ALARM)
	eq(CivilianRules.bubble(_rules, 10.0, true, CivilianRules.Bubble.ALARM), CivilianRules.Bubble.ALARM,
		"tespit kilidi: kısa saklanmada \"!\" kalır")
