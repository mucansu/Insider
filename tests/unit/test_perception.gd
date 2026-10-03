extends TestCase
## US-006 AC1/AC3/AC4: perception rules (core/perception.gd, no node): cone (range and half-angle edges), two bands (near <= R/2),
## fill = 25 x band x state (run 2, walk 1, sneak 0.5, darkness 0), sight-line input, turn ceiling; tuning data
## (data/npc/perception_tuning.tres, KR-019). Meter and times: test_suspicion.gd; components (real physics query): test_perception_components.gd.

const TUNING := "res://data/npc/perception_tuning.tres"
const B := PerceptionRules.Band
const S := PerceptionRules.Stance
const O := Vector2(100, 100)


func _tuning() -> PerceptionTuning:
	return load(TUNING) as PerceptionTuning


func _guard() -> PerceptionRules.Params:
	return Perception.params_for(_tuning(), Perception.Observer.GUARD)


func _camera() -> PerceptionRules.Params:
	return Perception.params_for(_tuning(), Perception.Observer.CAMERA)


## The point `dist` px away at `deg` degrees from the observer (facing +x).
static func _at(deg: float, dist: float) -> Vector2:
	return O + Vector2.RIGHT.rotated(deg_to_rad(deg)) * dist


func test_tuning_matches_kr019() -> void:
	var t: PerceptionTuning = _tuning()
	if not is_true(t != null, "tuning yüklenmeli"):
		return
	eq(t.guard_half_angle_deg, 50.0, "muhafız yarım açı")
	eq(t.guard_view_range, 256.0, "muhafız menzil")
	eq(t.camera_half_angle_deg, 35.0, "kamera yarım açı")
	eq(t.camera_view_range, 288.0, "kamera menzil")
	eq(t.near_ratio, 0.5, "yakın bant R/2")
	eq(t.near_factor, 2.0)
	eq(t.far_factor, 1.0)
	eq(t.base_fill_per_sec, 25.0)
	eq(t.sprint_factor, 2.0)
	eq(t.walk_factor, 1.0)
	eq(t.sneak_factor, 0.5)
	eq(t.dark_factor, 0.0, "karanlık bölge: ikili ışık/gölge")
	eq(t.decay_per_sec, 20.0)
	eq(t.notice_threshold, 30.0)
	eq(t.investigate_threshold, 60.0)
	eq(t.detect_threshold, 100.0)
	near(t.grace_sec, 0.2, 0.0001, "oyuncu lehine 0,2 sn")
	near(t.gap_tolerance_sec, 0.2, 0.0001, "kısa kesinti toleransı 0,2 sn (US-006 t2)")
	eq(t.max_turn_deg_per_sec, 120.0, "dönüş tavanı")
	eq(t.resource_path.get_file(), "perception_tuning.tres")
	is_true(t.get_script() != null and (t.get_script() as Script).get_global_name() == &"PerceptionTuning")


func test_cone_range_edges() -> void:
	var p: PerceptionRules.Params = _guard()
	is_true(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(0, 256)), "menzil sınırı dahil")
	is_false(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(0, 256.5)), "menzil +0,5 px dışarıda")
	is_true(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(30, 255)))
	is_true(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, O), "gözlemcinin üstü")
	is_false(PerceptionRules.in_cone(O, Vector2.ZERO, p.half_angle_deg, p.view_range, _at(0, 10)), "yön yoksa koni yok")
	is_true(PerceptionRules.in_cone(O, Vector2(3, 0), p.half_angle_deg, p.view_range, _at(0, 200)), "yön birim olmayabilir")


func test_cone_angle_edges() -> void:
	var p: PerceptionRules.Params = _guard()
	for deg: float in [50.0, -50.0, 49.5, 0.0, -20.0]:
		is_true(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(deg, 100)), "%s° içeride" % deg)
	for deg: float in [50.5, -50.5, 90.0, 180.0, -135.0]:
		is_false(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(deg, 100)), "%s° dışarıda" % deg)
	# When the facing turns the cone turns too (a guard facing down).
	is_true(PerceptionRules.in_cone(O, Vector2.DOWN, p.half_angle_deg, p.view_range, O + Vector2(0, 100)))
	is_false(PerceptionRules.in_cone(O, Vector2.DOWN, p.half_angle_deg, p.view_range, O + Vector2(100, 0)))


func test_camera_cone() -> void:
	var p: PerceptionRules.Params = _camera()
	is_true(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(35, 100)), "kamera 35° dahil")
	is_false(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(36, 100)), "kamera 36° dışarıda")
	is_true(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(0, 288)), "kamera menzili 288")
	is_false(PerceptionRules.in_cone(O, Vector2.RIGHT, p.half_angle_deg, p.view_range, _at(0, 289)))
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(0, 144)), B.NEAR, "kamera yakın bandı 144 px")
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(0, 145)), B.FAR)


func test_bands() -> void:
	var p: PerceptionRules.Params = _guard()
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(0, 64)), B.NEAR)
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(45, 128)), B.NEAR, "R/2 sınırı yakın banda dahil")
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(0, 128.5)), B.FAR, "R/2 + 0,5 px uzak bant")
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(-45, 200)), B.FAR)
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(0, 256)), B.FAR, "menzil sınırı uzak bant")
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(0, 257)), B.NONE, "menzil dışı")
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(60, 64)), B.NONE, "açı dışı (yakın da olsa)")
	eq(PerceptionRules.band(p, O, Vector2.RIGHT, _at(180, 30)), B.NONE, "arkası")
	eq(PerceptionRules.band_factor(p, B.NEAR), 2.0)
	eq(PerceptionRules.band_factor(p, B.FAR), 1.0)
	eq(PerceptionRules.band_factor(p, B.NONE), 0.0)


## KR-019: fill/s = 25 x band x state.
func test_fill_rates() -> void:
	var p: PerceptionRules.Params = _guard()
	var table: Array = [
		[B.NEAR, S.SPRINT, 100.0], [B.NEAR, S.WALK, 50.0], [B.NEAR, S.SNEAK, 25.0],
		[B.FAR, S.SPRINT, 50.0], [B.FAR, S.WALK, 25.0], [B.FAR, S.SNEAK, 12.5],
	]
	for row: Array in table:
		near(PerceptionRules.fill_rate(p, row[0], row[1], false, true), row[2], 0.0001, "bant %s, durum %s" % [row[0], row[1]])
		eq(PerceptionRules.fill_rate(p, row[0], row[1], false, false), 0.0, "görüş hattı kesik: dolum yok")
		eq(PerceptionRules.fill_rate(p, row[0], row[1], true, true), 0.0, "karanlık bölge: dolum yok")
	for stance: PerceptionRules.Stance in [S.SPRINT, S.WALK, S.SNEAK]:
		eq(PerceptionRules.fill_rate(p, B.NONE, stance, false, true), 0.0, "koni dışı: dolum yok")


func test_rate_for_combines_geometry_and_inputs() -> void:
	var p: PerceptionRules.Params = _guard()
	near(PerceptionRules.rate_for(p, O, Vector2.RIGHT, _at(10, 100), true, S.SPRINT, false), 100.0, 0.0001)
	near(PerceptionRules.rate_for(p, O, Vector2.RIGHT, _at(10, 200), true, S.SNEAK, false), 12.5, 0.0001)
	eq(PerceptionRules.rate_for(p, O, Vector2.RIGHT, _at(10, 100), false, S.SPRINT, false), 0.0, "raf arkası (visible=false)")
	eq(PerceptionRules.rate_for(p, O, Vector2.RIGHT, _at(10, 100), true, S.SPRINT, true), 0.0, "karanlık")
	eq(PerceptionRules.rate_for(p, O, Vector2.LEFT, _at(10, 100), true, S.SPRINT, false), 0.0, "sırtı dönük")
	# Sneaking fills 4x slower than running (same band).
	var sneak: float = PerceptionRules.rate_for(p, O, Vector2.RIGHT, _at(0, 100), true, S.SNEAK, false)
	var sprint: float = PerceptionRules.rate_for(p, O, Vector2.RIGHT, _at(0, 100), true, S.SPRINT, false)
	near(sprint / sneak, 4.0, 0.0001)


func test_turn_rate_cap() -> void:
	var cap: float = _tuning().max_turn_deg_per_sec
	var dir: Vector2 = Vector2.RIGHT
	for i: int in 30:  # 0.5 s @ 60 Hz -> 60 deg
		dir = PerceptionRules.turn_toward(dir, Vector2.DOWN, cap, 1.0 / 60.0)
	near(rad_to_deg(Vector2.RIGHT.angle_to(dir)), 60.0, 0.01, "120°/sn tavan")
	for i: int in 30:
		dir = PerceptionRules.turn_toward(dir, Vector2.DOWN, cap, 1.0 / 60.0)
	near(dir, Vector2.DOWN, 0.0001, "hedefe varınca durur, aşmaz")
	var ccw: Vector2 = PerceptionRules.turn_toward(Vector2.RIGHT, Vector2.UP, cap, 0.25)
	near(rad_to_deg(Vector2.RIGHT.angle_to(ccw)), -30.0, 0.01, "kısa yönden döner")
	near(PerceptionRules.turn_toward(Vector2.RIGHT, Vector2.ZERO, cap, 1.0), Vector2.RIGHT, 0.0001, "hedef yön yoksa korunur")
	near(PerceptionRules.turn_toward(Vector2.ZERO, Vector2(0, 5), cap, 0.0), Vector2.DOWN, 0.0001)
	near(PerceptionRules.turn_toward(Vector2(2, 0), Vector2.RIGHT, cap, 0.0).length(), 1.0, 0.0001, "birim döner")
