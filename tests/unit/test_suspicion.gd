extends TestCase
## US-006 AC1/AC4: suspicion meter (core/suspicion.gd, no node) - fixed-step, time-independent simulation. Detection times (running
## near/far band, sneaking far band), "?" (30) >= 0.5 s before detection, 0.2 s in the player's favour ("seen" start and leaving
## the sight line), short interruption tolerance (0.2 s; fidgeting at an edge and sync jitter do not reset the meter, detection level
## does not flicker), drain 20/s, threshold levels, independence from step size. Fills from the KR-019 table (PerceptionRules +
## data/npc/perception_tuning.tres).
## Time reading (US-006 t2 decision): detection moment = 0.2 s player-favour margin + 100 / fill; the Phase 2 exit criterion
## "running in the near band <= 1 s" is the fill time, and the 0.2 s network margin (S2) is added on top.

const TUNING := "res://data/npc/perception_tuning.tres"
const B := PerceptionRules.Band
const S := PerceptionRules.Stance
const DT := 1.0 / 60.0


func _tuning() -> PerceptionTuning:
	return load(TUNING) as PerceptionTuning


func _params() -> SuspicionMeter.Params:
	return Suspicion.params_for(_tuning())


func _rate(which: PerceptionRules.Band, stance: PerceptionRules.Stance) -> float:
	var p: PerceptionRules.Params = Perception.params_for(_tuning(), Perception.Observer.GUARD)
	return PerceptionRules.fill_rate(p, which, stance, false, true)


## Seen continuously at target `rate`; returns the moment each level is first reached (s, end of step): {level: moment}.
func _level_times(rate: float, dt: float = DT, max_t: float = 20.0) -> Dictionary:
	var meter := SuspicionMeter.new()
	var params: SuspicionMeter.Params = _params()
	var out: Dictionary = {}
	var t: float = 0.0
	while t < max_t and not out.has(3):
		t += dt
		for l: int in meter.step(params, rate, dt):
			out[l] = t
	return out


## Steps at `rate` for `seconds`.
static func _run(meter: SuspicionMeter, params: SuspicionMeter.Params, rate: float, seconds: float,
		dt: float = DT) -> PackedInt32Array:
	var reached := PackedInt32Array()
	var steps: int = roundi(seconds / dt)
	for i: int in steps:
		reached.append_array(meter.step(params, rate, dt))
	return reached


func test_sprint_near_band_detects_within_one_second_of_fill() -> void:
	var grace: float = _params().grace
	var times: Dictionary = _level_times(_rate(B.NEAR, S.SPRINT))
	if not is_true(times.has(3), "tespit olmalı"):
		return
	var fill_time: float = float(times[3]) - grace
	is_true(fill_time <= 1.0 + DT, "koşan, yakın bant: dolum ≤ 1 sn (gelen %.3f)" % fill_time)
	near(float(times[3]), grace + 1.0, DT, "tespit anı = 0,2 pay + 1,0 dolum")


func test_sprint_far_band_detects_within_two_seconds_of_fill() -> void:
	var grace: float = _params().grace
	var times: Dictionary = _level_times(_rate(B.FAR, S.SPRINT))
	if not is_true(times.has(3)):
		return
	is_true(float(times[3]) - grace <= 2.0 + DT, "koşan, uzak bant: dolum ≤ 2 sn")
	near(float(times[3]), grace + 2.0, DT)


func test_sneak_far_band_takes_about_eight_seconds() -> void:
	var grace: float = _params().grace
	var times: Dictionary = _level_times(_rate(B.FAR, S.SNEAK))
	if not is_true(times.has(3)):
		return
	near(float(times[3]) - grace, 8.0, DT, "sızan, uzak bant ~8 sn")
	near(float(times[1]) - grace, 2.4, DT, "sızanda \"?\" 2,4 sn")


func test_notice_precedes_detection_by_half_second() -> void:
	for which: PerceptionRules.Band in [B.NEAR, B.FAR]:
		for stance: PerceptionRules.Stance in [S.SPRINT, S.WALK, S.SNEAK]:
			var times: Dictionary = _level_times(_rate(which, stance))
			if not is_true(times.has(1) and times.has(2) and times.has(3), "üç düzey %s/%s" % [which, stance]):
				continue
			is_true(float(times[1]) < float(times[2]) and float(times[2]) < float(times[3]), "düzey sırası")
			is_true(float(times[3]) - float(times[1]) >= 0.5,
				"\"?\" tespitten ≥ 0,5 sn önce (bant %s, durum %s: %.3f)" % [which, stance, float(times[3]) - float(times[1])])
	# Fastest case (running, near): "?" at 0.3 s of fill, detection 1.0 -> 0.7 s window.
	var fast: Dictionary = _level_times(_rate(B.NEAR, S.SPRINT))
	near(float(fast[3]) - float(fast[1]), 0.7, DT)


func test_step_size_independent() -> void:
	var grace: float = _params().grace
	for dt: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0, 0.05, 0.1]:
		var times: Dictionary = _level_times(_rate(B.NEAR, S.SPRINT), dt)
		near(float(times.get(3, INF)), grace + 1.0, dt + 0.0001, "dt %.4f tespit" % dt)
		near(float(times.get(1, INF)), grace + 0.3, dt + 0.0001, "dt %.4f \"?\"" % dt)
		var sneak: Dictionary = _level_times(_rate(B.FAR, S.SNEAK), dt)
		near(float(sneak.get(3, INF)), grace + 8.0, dt + 0.0001, "dt %.4f sızma" % dt)
	# A single large step gives the same value (the margin is split within the step).
	var a := SuspicionMeter.new()
	var b := SuspicionMeter.new()
	a.step(_params(), 50.0, 1.0)
	_run(b, _params(), 50.0, 1.0)
	near(a.value, b.value, 0.001, "1 adım = 60 adım")
	near(a.value, 50.0 * (1.0 - grace), 0.001)


func test_blocked_line_of_sight_never_accrues() -> void:
	var meter := SuspicionMeter.new()
	var p: PerceptionRules.Params = Perception.params_for(_tuning(), Perception.Observer.GUARD)
	# Behind a shelf: inside the cone, near, running but the sight line is cut (visible=false).
	var rate: float = PerceptionRules.rate_for(p, Vector2.ZERO, Vector2.RIGHT, Vector2(60, 0), false, S.SPRINT, false)
	var reached: PackedInt32Array = _run(meter, _params(), rate, 30.0)
	eq(meter.value, 0.0, "raf arkası hiç birikmez")
	eq(reached.size(), 0)
	eq(meter.level, 0)


func test_dark_zone_and_sneak_effect() -> void:
	var p: PerceptionRules.Params = Perception.params_for(_tuning(), Perception.Observer.GUARD)
	var dark := SuspicionMeter.new()
	_run(dark, _params(), PerceptionRules.rate_for(p, Vector2.ZERO, Vector2.RIGHT, Vector2(60, 0), true, S.SPRINT, true), 10.0)
	eq(dark.value, 0.0, "karanlık bölgede koşan bile birikmez")
	var walk := SuspicionMeter.new()
	var sneak := SuspicionMeter.new()
	_run(walk, _params(), _rate(B.FAR, S.WALK), 1.2)
	_run(sneak, _params(), _rate(B.FAR, S.SNEAK), 1.2)
	near(walk.value, 25.0, 0.01, "yürüyen uzak bant 1 sn dolum = 25")
	near(sneak.value, 12.5, 0.01, "sızma yarı hız")


## 0.2 s in the player's favour: the "seen" start. A glance shorter than the margin leaves no trace; neither fill nor drain during the margin.
func test_grace_on_first_sight() -> void:
	var params: SuspicionMeter.Params = _params()
	var rate: float = _rate(B.NEAR, S.SPRINT)
	var meter := SuspicionMeter.new()
	_run(meter, params, rate, 0.18)
	eq(meter.value, 0.0, "0,18 sn bakış: iz yok")
	_run(meter, params, 0.0, 0.3)
	_run(meter, params, rate, 0.18)
	eq(meter.value, 0.0, "tolerans (0,2 sn) aşan kesinti payı yeniden başlatır")
	_run(meter, params, rate, 0.12)
	near(meter.value, 10.0, 0.5, "0,3 sn kesintisiz: 0,1 sn × 100")
	# An interruption shorter than the tolerance does not break the sequence; interruption time counts toward the margin, fill only while seen.
	var short := SuspicionMeter.new()
	_run(short, params, rate, 0.1)
	_run(short, params, 0.0, 0.1)
	eq(short.value, 0.0)
	_run(short, params, rate, 0.1)
	near(short.value, 10.0, 0.5, "0,1 görülme + 0,1 kesinti + 0,1 görülme: pay dolmuş, 0,1 sn × 100")
	# From a known value: constant during the margin (no drain), then fills.
	var held := SuspicionMeter.new()
	held.value = 50.0
	_run(held, params, rate, 0.15)
	eq(held.value, 50.0, "pay içinde ne dolum ne boşalma")
	_run(held, params, rate, 0.15)
	near(held.value, 60.0, 0.5)


## 0.2 s in the player's favour: leaving the sight line. The last ~0.2 s of the host's old view does not reach detection:
## a runner who would be detected at 1.0 s with fill is not detected if seen for 1.15 s and then hidden.
func test_grace_on_leaving_line_of_sight() -> void:
	var params: SuspicionMeter.Params = _params()
	var rate: float = _rate(B.NEAR, S.SPRINT)
	var meter := SuspicionMeter.new()
	var reached: PackedInt32Array = _run(meter, params, rate, 1.15)
	is_false(reached.has(3), "1,15 sn görülüp saklanan tespit edilmez (dolum süresi 1,0 sn)")
	has(reached, 2, "inceleme düzeyi geçildi")
	var top: float = meter.value
	near(top, 95.0, 0.5)
	reached = _run(meter, params, 0.0, DT)
	eq(meter.value, top, "saklanınca dolum anında durur (tolerans içinde boşalma da yok)")
	eq(reached.size(), 0)
	_run(meter, params, 0.0, 0.5 - DT)
	near(meter.value, top - params.decay_per_sec * (0.5 - params.gap_tolerance), 0.001,
		"gerçek saklanma: tolerans aşınca boşalır")
	# The same runner seen for 1.25 s is detected.
	var late := SuspicionMeter.new()
	has(_run(late, params, rate, 1.25), 3)


func test_decay_and_levels_drop() -> void:
	var params: SuspicionMeter.Params = _params()
	var meter := SuspicionMeter.new()
	meter.value = 60.0
	meter.level = SuspicionMeter.level_for(params, 60.0)
	eq(meter.level, 2)
	_run(meter, params, 0.0, 1.0)
	near(meter.value, 40.0, 0.001, "boşalma 20/sn")
	eq(meter.level, 1, "düzey değerle iner")
	_run(meter, params, 0.0, 0.5)
	near(meter.value, 30.0, 0.001)
	eq(meter.level, 1, "30 eşiği dahil")
	_run(meter, params, 0.0, 5.0)
	eq(meter.value, 0.0, "0'da durur")
	eq(meter.level, 0)


func test_threshold_events() -> void:
	var params: SuspicionMeter.Params = _params()
	var meter := SuspicionMeter.new()
	var events := PackedInt32Array()
	for i: int in 120:
		events.append_array(meter.step(params, 100.0, DT))
	eq(events, PackedInt32Array([1, 2, 3]), "her eşik bir kez, sırayla")
	_run(meter, params, 100.0, 1.0)
	eq(meter.value, SuspicionMeter.MAX_VALUE, "tavan 100")
	# A large step crosses several thresholds: all are returned in order.
	var jump := SuspicionMeter.new()
	jump.seen_for = 1.0
	eq(jump.step(params, 100.0, 0.7), PackedInt32Array([1, 2]))
	# When it drops and rises again the threshold is reported again.
	var again := SuspicionMeter.new()
	again.value = 35.0
	again.level = 1
	_run(again, params, 0.0, 0.5)
	eq(again.level, 0)
	eq(_run(again, params, 50.0, 0.5), PackedInt32Array([1]))
	again.reset()
	eq(again.value, 0.0)
	eq(again.level, 0)
	eq(again.seen_for, 0.0)


## Detection moment of a running, near-band target in an `on`/`off` seconds seen/interrupted pattern (INF if none).
func _pattern_detect_time(on: float, off: float, dt: float = DT, max_t: float = 10.0) -> float:
	var meter := SuspicionMeter.new()
	var params: SuspicionMeter.Params = _params()
	var rate: float = _rate(B.NEAR, S.SPRINT)
	var t: float = 0.0
	while t < max_t:
		var phase: float = fmod(t + dt * 0.5, on + off)
		var seen: bool = phase < on
		t += dt
		if meter.step(params, rate if seen else 0.0, dt).has(3):
			return t
	return INF


## Looking while fidgeting at an edge / 20 Hz sync jitter: short interruptions do not reset the meter (should-fix t2).
func test_short_gaps_still_detect() -> void:
	var params: SuspicionMeter.Params = _params()
	near(params.gap_tolerance, 0.2, 0.0001, "tuning: kesinti toleransı 0,2 sn")
	var continuous: float = params.grace + 1.0
	for frames: Array in [[11, 1], [9, 3], [12, 3], [15, 3]]:
		var t: float = _pattern_detect_time(int(frames[0]) * DT, int(frames[1]) * DT)
		is_true(t <= continuous * 1.3, "%d/%d kare deseni tespit eder: %.3f sn (kesintisiz %.2f × 1,3 = %.3f)"
			% [frames[0], frames[1], t, continuous, continuous * 1.3])


func test_short_gaps_step_size_independent() -> void:
	# 0.15 s seen / 0.05 s interrupted: the margin fills at 0.2 s, each 0.2 s cycle fills 0.15 s x 100 ->
	# 6 cycles (90) + 0.1 s -> 1.5 s.
	for dt: float in [1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0, 0.05]:
		near(_pattern_detect_time(0.15, 0.05, dt), 1.5, dt + 0.0001, "dt %.4f" % dt)


## After detection short interruptions do not drop level 3 and do not re-emit detection ("!" does not flicker).
func test_detection_survives_short_gaps() -> void:
	var params: SuspicionMeter.Params = _params()
	var rate: float = _rate(B.NEAR, S.SPRINT)
	var meter := SuspicionMeter.new()
	if not is_true(_run(meter, params, rate, 1.3).has(3), "önce tespit"):
		return
	var events := PackedInt32Array()
	var min_level: int = 3
	for cycle: int in 100:  # 15/3 frame pattern, 30 s
		for i: int in 18:
			events.append_array(meter.step(params, rate if i < 15 else 0.0, DT))
			min_level = mini(min_level, meter.level)
	eq(events.size(), 0, "tespit yeniden yayılmaz")
	eq(min_level, 3, "düzey 3'te kalır")
	eq(meter.value, SuspicionMeter.MAX_VALUE)
	# A single-frame loss (the host's own player) does not drop it either; a real hide (>= tolerance) does.
	meter.step(params, rate, DT)  # pattern ended with a 3-frame interruption; being seen resets the interruption counter
	meter.step(params, 0.0, DT)
	eq(meter.level, 3)
	_run(meter, params, 0.0, 0.3)
	eq(meter.level, 2, "0,3 sn saklanma: tolerans sonrası boşalma 3 → 2")
	near(meter.value, 100.0 - params.decay_per_sec * (0.3 + DT - params.gap_tolerance), 0.001)
