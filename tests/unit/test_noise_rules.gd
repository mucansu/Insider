extends TestCase
## US-009 kuralları ve verisi (AC2, AC6): `data/noise_profile.tres` (S8 başlangıç değerleri, S10 kalıbı),
## `core/noise_rules.gd` (düğümsüz): duvar arkası zayıflama, mesafe, kaynağın kendi gövdesi, istemci isteği
## doğrulaması (hile: başka peer adına / uzak konumda / sonuç türünde ses yok, gönderen başına tempo sınırı),
## yayım temposu (≤ ~3 Hz), süren iş sesinin bitişte bastırılması.
## Fizik ışınıyla bileşen: test_noise_hearing.gd; NoiseBus, yayımcılar, halka: test_noise_bus.gd;
## ağ: tests/net/noise_ring.json.

const PROFILE := "res://data/noise_profile.tres"
const DT := 1.0 / 60.0
const R := NoiseRules.Result


func _profile() -> NoiseProfile:
	return load(PROFILE) as NoiseProfile


# --- veri (AC2) ---

func test_profile_values() -> void:
	var p: NoiseProfile = _profile()
	if not is_true(p != null, "noise_profile.tres NoiseProfile olmalı"):
		return
	eq(p.radius_for(NoiseProfile.KIND_WALK), 0.0, "yürüme sessiz")
	eq(p.radius_for(NoiseProfile.KIND_SNEAK), 0.0, "sızma sessiz")
	eq(p.radius_for(NoiseProfile.KIND_RUN), 120.0, "koşma 120")
	eq(p.radius_for(NoiseProfile.KIND_DOOR), 160.0, "kapı 160")
	eq(p.radius_for(NoiseProfile.KIND_REGISTER), 90.0, "kasa 90")
	eq(p.radius_for(NoiseProfile.KIND_INTIMIDATE), 140.0, "sindirme 140 (S8)")
	eq(p.radius_for(&"bilinmeyen"), 0.0, "bilinmeyen tür sessiz")
	eq(p.wall_factor, 0.5, "duvar arkası ×0,5")
	is_true(p.step_interval >= 1.0 / 3.0 and p.step_interval <= 0.4, "adım sesi en fazla ~3 Hz: %s" % p.step_interval)
	# Eşik her kipin hızının (sızma 70) altında: sessizliği yarıçap belirler, hız eşiği yalnız durmayı/duvara itmeyi.
	is_true(p.step_min_speed > 0.0 and p.step_min_speed < 70.0, "hareketsiz koşu sessiz, her kipte yürüyüş hareket")
	is_true(p.register_interval >= 0.5, "kasa sesi düşük tempoda")
	is_true(NoiseProfile.load_default() != null and NoiseProfile.load_default().resource_path == PROFILE)
	var blank := NoiseProfile.new()
	eq(blank.sprint_radius, 0.0, "betik varsayılanları nötr")
	eq(blank.radius_for(NoiseProfile.KIND_DOOR), 0.0)


func test_movement_kinds() -> void:
	for kind: StringName in [NoiseProfile.KIND_WALK, NoiseProfile.KIND_SNEAK, NoiseProfile.KIND_RUN]:
		is_true(NoiseProfile.is_movement_kind(kind), "istemci kendi hareket sesini üretebilir: %s" % kind)
	for kind: StringName in [NoiseProfile.KIND_DOOR, NoiseProfile.KIND_REGISTER, NoiseProfile.KIND_INTIMIDATE, &"x"]:
		is_false(NoiseProfile.is_movement_kind(kind), "sonuç sesi istemciden gelemez: %s" % kind)


# --- duyma kuralı ---

func test_wall_attenuation() -> void:
	eq(NoiseRules.effective_radius(120.0, true, 0.5), 120.0, "görüş hattı var: tam")
	eq(NoiseRules.effective_radius(120.0, false, 0.5), 60.0, "duvar arkası ×0,5")
	eq(NoiseRules.effective_radius(160.0, false, 0.5), 80.0)
	eq(NoiseRules.effective_radius(0.0, false, 0.5), 0.0, "sessiz ses sessiz kalır")
	eq(NoiseRules.effective_radius(-5.0, true, 0.5), 0.0)
	eq(NoiseRules.effective_radius(100.0, false, 2.0), 100.0, "çarpan 1'i aşamaz (duvar sesi büyütmez)")
	eq(NoiseRules.effective_radius(100.0, false, -1.0), 0.0)


func test_distance_check() -> void:
	is_true(NoiseRules.can_hear(0.0, 120.0))
	is_true(NoiseRules.can_hear(120.0, 120.0), "sınırda duyulur")
	is_false(NoiseRules.can_hear(120.01, 120.0))
	is_false(NoiseRules.can_hear(0.0, 0.0), "sıfır yarıçap (yürüme/sızma) hiç duyulmaz")
	# Duvar arkası: 96 px tam yarıçapta duyulur, ×0,5'te duyulmaz (noise_ring.json ProbeInside).
	is_true(NoiseRules.can_hear(96.0, NoiseRules.effective_radius(120.0, true, 0.5)))
	is_false(NoiseRules.can_hear(96.0, NoiseRules.effective_radius(120.0, false, 0.5)))
	is_true(NoiseRules.can_hear(55.0, NoiseRules.effective_radius(120.0, false, 0.5)), "yakında duvar arkası duyulur")


func test_source_body_does_not_block() -> void:
	var source := Vector2(100, 0)
	is_false(NoiseRules.hit_blocks(Vector2(96, 0), source), "kaynağın kendi kanadı (4 px)")
	is_false(NoiseRules.hit_blocks(source + Vector2(0, NoiseRules.SOURCE_MARGIN), source), "sınırda kesmez")
	is_true(NoiseRules.hit_blocks(Vector2(56, 0), source), "duvara yaslanan oyuncunun arkasındaki duvar (44 px)")
	is_true(NoiseRules.SOURCE_MARGIN < 44.0, "duvar kalınlığı (32) + gövde (12) payın dışında")


# --- istemci isteği doğrulaması (AC1, AC6 hile) ---

func test_client_check_accepts_own_nearby_noise() -> void:
	var known := Vector2(200, 100)
	eq(NoiseRules.check_client(5, 5, true, 120.0, known, known, true), R.OK)
	eq(NoiseRules.check_client(5, 0, true, 120.0, known + Vector2(20, 0), known, true), R.OK, "kaynak 0 = kendisi")
	eq(NoiseRules.check_client(5, 5, true, 120.0, known + Vector2(0, NoiseRules.POSITION_TOLERANCE), known, true),
		R.OK, "tolerans sınırı")


func test_client_check_rejects_cheats() -> void:
	var known := Vector2(200, 100)
	eq(NoiseRules.check_client(5, 7, true, 120.0, known, known, true), R.FOREIGN_PEER, "başka peer adına ses")
	eq(NoiseRules.check_client(0, 0, true, 120.0, known, known, true), R.FOREIGN_PEER, "geçersiz gönderen")
	eq(NoiseRules.check_client(5, 5, true, 120.0, known + Vector2(NoiseRules.POSITION_TOLERANCE + 0.5, 0), known, true),
		R.TOO_FAR, "uzak konumda ses")
	eq(NoiseRules.check_client(5, 5, true, 120.0, Vector2(900, 900), known, true), R.TOO_FAR)
	eq(NoiseRules.check_client(5, 5, false, 160.0, known, known, true), R.KIND_NOT_ALLOWED, "istemci kapı sesi üretemez")
	eq(NoiseRules.check_client(5, 5, true, 0.0, known, known, true), R.SILENT, "sızma sesi yayılmaz")
	eq(NoiseRules.check_client(5, 5, true, 120.0, known, Vector2.INF, false), R.NO_ACTOR, "aktörü olmayan peer")
	eq(NoiseRules.check_client(5, 5, true, 120.0, Vector2(NAN, 0), known, true), R.BAD_POSITION)
	eq(NoiseRules.check_client(5, 5, true, 120.0, Vector2.INF, known, true), R.BAD_POSITION)
	eq(NoiseRules.result_name(R.TOO_FAR), "too_far")
	eq(NoiseRules.result_name(R.FOREIGN_PEER), "foreign_peer")
	is_true(NoiseRules.POSITION_TOLERANCE >= 24.0 and NoiseRules.POSITION_TOLERANCE <= 48.0,
		"S2 menzil payı ölçeğinde (koşu 220 px/sn × ~0,1 sn)")


# --- tempo ---

## `seconds` boyunca 60 Hz adımlarla `active(t)` ile çalıştırır; olay anlarını döner.
func _run_cadence(cadence: NoiseRules.Cadence, seconds: float, active: Callable) -> Array[float]:
	var times: Array[float] = []
	var steps: int = roundi(seconds / DT)
	for i: int in steps:
		var t: float = (i + 1) * DT
		if cadence.tick(DT, bool(active.call(i))):
			times.append(t)
	return times


func test_step_cadence_at_most_3hz() -> void:
	var interval: float = _profile().step_interval
	var times: Array[float] = _run_cadence(NoiseRules.Cadence.new(interval), 2.0, func(_i: int) -> bool: return true)
	if not is_true(times.size() >= 2, "koşarken ses var"):
		return
	near(times[0], DT, 0.0001, "ilk adım hemen")
	eq(times.size(), 1 + floori((2.0 - DT) / interval + 0.0001), "aralıklı: %s" % [times])
	for i: int in range(1, times.size()):
		is_true(times[i] - times[i - 1] >= interval - 0.0001, "≥ aralık")
	is_true(float(times.size()) / 2.0 <= 3.0 + 0.5, "≤ ~3 Hz")
	# Aç/kapa her karede: tempo sınırı aşılmaz.
	var flicker: Array[float] = _run_cadence(NoiseRules.Cadence.new(interval), 2.0, func(i: int) -> bool: return i % 2 == 0)
	is_true(flicker.size() <= times.size(), "aç/kapa tempo sınırını aşamaz: %d" % flicker.size())
	# Etkin değilken ses yok.
	eq(_run_cadence(NoiseRules.Cadence.new(interval), 2.0, func(_i: int) -> bool: return false).size(), 0)


func test_cadence_lead() -> void:
	var times: Array[float] = _run_cadence(NoiseRules.Cadence.new(1.0, 1.0), 3.5, func(_i: int) -> bool: return true)
	eq(times.size(), 3, "1, 2, 3. sn: %s" % [times])
	if times.size() > 0:
		near(times[0], 1.0, 2.0 * DT, "ilk ses lead kadar sonra")
	# Etkinlik kesilirse lead baştan sayılır.
	var cadence := NoiseRules.Cadence.new(1.0, 1.0)
	var fired: Array[float] = _run_cadence(cadence, 0.8, func(_i: int) -> bool: return true)
	fired.append_array(_run_cadence(cadence, 0.1, func(_i: int) -> bool: return false))
	fired.append_array(_run_cadence(cadence, 0.8, func(_i: int) -> bool: return true))
	eq(fired.size(), 0, "kesintili 0,8 + 0,8 sn: ses yok")


func test_client_rate_limit() -> void:
	var interval: float = _profile().step_interval
	var min_gap: float = interval * NoiseRules.CLIENT_RATE_FACTOR
	is_true(NoiseRules.within_rate(interval, interval), "dürüst istemci (adım aralığı) geçer")
	is_true(NoiseRules.within_rate(min_gap, interval), "yığılmaya pay: yarım aralık")
	is_false(NoiseRules.within_rate(min_gap - 0.01, interval), "daha sık: red")
	is_false(NoiseRules.within_rate(0.0, interval))
	eq(NoiseRules.result_name(R.RATE), "rate")


func test_work_tick_suppressed_near_end() -> void:
	# Kasa: 3 sn, 1 sn aralık. Tikler ~1,0 ve ~2,0'da; ~3,0'daki tik bitiş sesiyle çakışır, bastırılır.
	is_true(NoiseRules.work_tick_allowed(0.983, 3.0, 1.0))
	is_true(NoiseRules.work_tick_allowed(1.983, 3.0, 1.0))
	is_false(NoiseRules.work_tick_allowed(2.983, 3.0, 1.0), "bitişe yarım aralıktan az: bastır")
	is_false(NoiseRules.work_tick_allowed(3.0, 3.0, 1.0))
	is_true(NoiseRules.work_tick_allowed(2.49, 3.0, 1.0))
	is_false(NoiseRules.work_tick_allowed(2.5, 3.0, 1.0))
	is_true(NoiseRules.work_tick_allowed(5.0, 0.0, 1.0), "süresiz iş: bastırma yok")
