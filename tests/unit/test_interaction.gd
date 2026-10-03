extends TestCase
## US-005 AC7: interaction rules (core/interaction_rules.gd, no node): range + S2 tolerance (+24 px), side constraint
## (register only from behind the counter), tag, busy state, retry cooldown, duration + S2 time margin (0.25 s), nearest
## target. Component/prop behaviour: test_interaction_props.gd; network: tests/net/{register_empty,door_sync,contention}.json.

const CORE_DIR := "res://core"
const Deps := preload("res://tests/unit/test_deps.gd")
const R := InteractionRules.Result
const TUNING_PATH := "res://data/player_tuning.tres"
## How far behind the host knows the client position (S2: one-way delay + sync interval, ~0.1 s).
const HOST_LAG_SEC := 0.1


func _target(at: Vector2 = Vector2.ZERO, interact_range: float = 40.0) -> InteractionRules.Target:
	var t := InteractionRules.Target.new()
	t.position = at
	t.interact_range = interact_range
	return t


## Register: staff side +x, counter edge 16 px (same as data/props/register.tres).
func _register_target() -> InteractionRules.Target:
	var t: InteractionRules.Target = _target(Vector2(560, 368))
	t.side = Vector2.RIGHT
	t.side_min = 16.0
	return t


func test_constants_match_contract() -> void:
	eq(InteractionRules.RANGE_TOLERANCE, 24.0, "S2: menzil +24 px")
	eq(InteractionRules.SIDE_TOLERANCE, 24.0, "S2 ilkesi: taraf eşiği -24 px (IS-014: koşu)")
	eq(InteractionRules.TIME_TOLERANCE, 0.25, "S2: zaman +0,25 sn")
	is_true(InteractionRules.REPEAT_COOLDOWN > 0.0)


func test_range_and_tolerance() -> void:
	var at := Vector2(100, 100)
	is_true(InteractionRules.in_range(at + Vector2(40, 0), at, 40.0), "sınırda menzil içinde")
	is_false(InteractionRules.in_range(at + Vector2(40.5, 0), at, 40.0))
	is_true(InteractionRules.in_range(at + Vector2(0, 64), at, 40.0, 24.0), "tolerans sınırı")
	is_false(InteractionRules.in_range(at + Vector2(0, 64.5), at, 40.0, 24.0), "+24 px üstü reddedilir")
	is_false(InteractionRules.in_range(at + Vector2(41, 0), at, 40.0, -10.0), "negatif tolerans sıfır sayılır")


func test_side_constraint() -> void:
	var reg := Vector2(560, 368)
	is_true(InteractionRules.on_side(reg + Vector2(-28, 0), reg, Vector2.ZERO, 16.0), "kısıt yoksa her taraf")
	is_true(InteractionRules.on_side(reg + Vector2(28, 0), reg, Vector2.RIGHT, 16.0), "personel tarafı")
	is_true(InteractionRules.on_side(reg + Vector2(16, 30), reg, Vector2.RIGHT, 16.0), "sınırda")
	is_false(InteractionRules.on_side(reg + Vector2(15, 0), reg, Vector2.RIGHT, 16.0))
	is_false(InteractionRules.on_side(reg + Vector2(-28, 0), reg, Vector2.RIGHT, 16.0), "müşteri tarafı")
	is_false(InteractionRules.on_side(reg + Vector2(0, 32), reg, Vector2.RIGHT, 16.0), "tezgâh ucunun önü")
	is_true(InteractionRules.on_side(reg + Vector2(28, 0), reg, Vector2(3, 0), 16.0), "yön birim olmak zorunda değil")


func test_tag_constraint() -> void:
	is_true(InteractionRules.has_tag(&"", 5, {}), "etiket gerekmiyorsa")
	is_false(InteractionRules.has_tag(&"lockpick", 1, {}))
	is_false(InteractionRules.has_tag(&"lockpick", 2, {&"lockpick": 1}), "kademe yetmez")
	is_true(InteractionRules.has_tag(&"lockpick", 2, {&"lockpick": 2}))
	is_true(InteractionRules.has_tag(&"lockpick", 0, {"lockpick": 0}), "String anahtar da olur")


func test_check_order_and_results() -> void:
	var t: InteractionRules.Target = _register_target()
	var staff := Vector2(588, 368)
	var customer := Vector2(532, 368)
	eq(InteractionRules.check(t, 1, staff, {}), R.OK)
	eq(InteractionRules.check(t, 1, customer, {}), R.WRONG_SIDE, "müşteri tarafı menzil içinde de reddedilir")
	is_true(staff.distance_to(t.position) <= t.interact_range and customer.distance_to(t.position) <= t.interact_range)
	eq(InteractionRules.check(t, 1, Vector2(620, 368), {}), R.OUT_OF_RANGE)
	t.busy_by = 2
	eq(InteractionRules.check(t, 1, staff, {}), R.BUSY, "başkası tutuyor")
	eq(InteractionRules.check(t, 2, staff, {}), R.OK, "tutan peer için meşgul değil")
	t.enabled = false
	eq(InteractionRules.check(t, 1, Vector2(9999, 0), {}), R.DISABLED, "kapalı her şeyden önce")
	t.enabled = true
	t.busy_by = 0
	t.tag = &"key"
	t.tier = 1
	eq(InteractionRules.check(t, 1, staff, {}), R.MISSING_TAG)
	eq(InteractionRules.check(t, 1, staff, {&"key": 1}), R.OK)


func test_host_check_tolerance_and_cooldown() -> void:
	var t: InteractionRules.Target = _register_target()
	# The client rejects without tolerance, the host gives a +24 px margin (S2).
	var lagging := Vector2(560 + 60, 368)
	eq(InteractionRules.check(t, 1, lagging, {}), R.OUT_OF_RANGE)
	eq(InteractionRules.host_check(t, 1, lagging, {}, 0.0), R.OK, "host menzile +24 px pay verir")
	eq(InteractionRules.host_check(t, 1, Vector2(560 + 64.5, 368), {}, 0.0), R.OUT_OF_RANGE, "+24 px üstü")
	eq(InteractionRules.host_check(t, 1, Vector2(588, 368), {}, 0.1), R.COOLDOWN, "tekrar beklemesi")
	t.busy_by = 1
	eq(InteractionRules.host_check(t, 1, Vector2(588, 368), {}, 0.1), R.OK, "tutanın kendi isteği beklemeye takılmaz")
	is_true(InteractionRules.keeps_going(t, Vector2(560 + 64, 368)))
	is_false(InteractionRules.keeps_going(t, Vector2(560 + 64.5, 368)), "menzil + tolerans dışı: iptal")


## The host gives margin to the side threshold (S2/GDD §12 in the player's favour): when the client sees the prompt the host
## knows the position ~0.1 s behind: ~14 px walking, ~22 px running (speeds from data/player_tuning.tres). The customer side
## (counter 546..574, radius 12 -> at most -26 px) is still rejected.
func test_host_side_tolerance() -> void:
	var t: InteractionRules.Target = _register_target()
	var tuning: PlayerTuning = load(TUNING_PATH) as PlayerTuning
	if not is_true(tuning != null, "player_tuning.tres"):
		return
	var client_sees := Vector2(576.5, 395)
	eq(InteractionRules.check(t, 1, client_sees, {}), R.OK, "istemci: istem çıkar")
	for speed: float in [tuning.walk_speed, tuning.sprint_speed]:
		var host_sees: Vector2 = client_sees - Vector2(speed * HOST_LAG_SEC, 0)
		eq(InteractionRules.check(t, 1, host_sees, {}), R.WRONG_SIDE, "toleranssız olsaydı reddedilirdi (%s)" % speed)
		eq(InteractionRules.host_check(t, 1, host_sees, {}, 0.0), R.OK,
			"(a) host %.0f px/sn × %.1f sn geriden görse de kabul" % [speed, HOST_LAG_SEC])
	# (b) Real customer-side positions: leaning on the counter (nearest, x = 534) and others within register range.
	for y: float in [336.0, 350.0, 368.0, 386.0, 395.0]:
		var customer := Vector2(534, y)
		if customer.distance_to(t.position) > t.interact_range + InteractionRules.RANGE_TOLERANCE:
			continue
		eq(InteractionRules.host_check(t, 1, customer, {}, 0.0), R.WRONG_SIDE, "müşteri tarafı: %s" % customer)
	eq(InteractionRules.host_check(t, 1, Vector2(520, 368), {}, 0.0), R.WRONG_SIDE)
	eq(InteractionRules.check(t, 1, Vector2(534, 368), {}, 0.0, -5.0), R.WRONG_SIDE, "negatif pay sıfır sayılır")


func test_hold_time_and_release() -> void:
	var p: float = 0.0
	for i: int in 180:
		p = InteractionRules.advance(p, 1.0 / 60.0)
	near(p, 3.0, 0.0001)
	is_true(InteractionRules.is_complete(3.0, 3.0))
	is_false(InteractionRules.is_complete(2.99, 3.0))
	is_true(InteractionRules.is_complete(0.0, 0.0), "süre 0: anlık")
	eq(InteractionRules.advance(-1.0, -0.5), 0.0, "negatifler sıfırlanır")
	# Release: OK within the last 0.25 s (S2 time margin), cancelled earlier (progress resets).
	is_true(InteractionRules.release_completes(2.75, 3.0))
	is_false(InteractionRules.release_completes(2.74, 3.0))
	is_false(InteractionRules.release_completes(2.0, 3.0), "yarıda bırakma")
	eq(InteractionRules.ratio(1.5, 3.0), 0.5)
	eq(InteractionRules.ratio(9.0, 3.0), 1.0)
	eq(InteractionRules.ratio(0.0, 0.0), 0.0)


func test_nearest() -> void:
	var at := Vector2(10, 10)
	eq(InteractionRules.nearest(at, PackedVector2Array()), -1)
	eq(InteractionRules.nearest(at, PackedVector2Array([Vector2(50, 10), Vector2(20, 10), Vector2(0, 30)])), 1)
	eq(InteractionRules.nearest(at, PackedVector2Array([Vector2(20, 10), Vector2(0, 10)])), 0, "eşitlikte ilk")


func test_result_names() -> void:
	eq(InteractionRules.result_name(R.OK), "ok")
	eq(InteractionRules.result_name(R.BUSY), "busy")
	eq(InteractionRules.result_name(R.WRONG_SIDE), "wrong_side")
	eq(InteractionRules.result_name(R.OUT_OF_RANGE), "out_of_range")
	eq(InteractionRules.result_name(R.COOLDOWN), "cooldown")
	eq(InteractionRules.result_name(R.BLOCKED), "blocked")


## IS-014: a host obstruction (e.g. a body in the doorway) applies only in host validation; the client filter ignores it (the
## prompt stays visible). Other rejections come first; accepted once the obstruction clears.
func test_blocked_is_host_only() -> void:
	var t: InteractionRules.Target = _target(Vector2(368, 464))
	var closer := Vector2(368, 498)
	t.blocked = true
	eq(InteractionRules.check(t, 1, closer, {}), R.OK, "istemci süzgeci engeli bilmez: istem görünür")
	eq(InteractionRules.host_check(t, 1, closer, {}, 0.0), R.BLOCKED)
	eq(InteractionRules.host_check(t, 1, closer, {}, 0.1), R.COOLDOWN, "bekleme önce")
	eq(InteractionRules.host_check(t, 1, Vector2(368, 600), {}, 0.0), R.OUT_OF_RANGE, "menzil önce")
	t.blocked = false
	eq(InteractionRules.host_check(t, 1, closer, {}, 0.0), R.OK)


## Wing (32x8, centred on the door marker) vs body circle (radius 12): tangent contact is not overlap; rotation is respected.
func test_circle_overlaps_box() -> void:
	var door := Vector2(368, 464)
	var half := Vector2(16, 4)
	is_true(InteractionRules.circle_overlaps_box(door, 12.0, door, half, 0.0), "merkez kanatta")
	is_true(InteractionRules.circle_overlaps_box(door + Vector2(0, 15.9), 12.0, door, half, 0.0), "kenara 11,9 px")
	is_false(InteractionRules.circle_overlaps_box(door + Vector2(0, 16), 12.0, door, half, 0.0), "teğet (kanada yaslanmış)")
	is_false(InteractionRules.circle_overlaps_box(door + Vector2(0, 28), 12.0, door, half, 0.0), "kapatan oyuncu (28 px)")
	is_true(InteractionRules.circle_overlaps_box(door + Vector2(27, 0), 12.0, door, half, 0.0), "kanat ucunun yanı")
	is_false(InteractionRules.circle_overlaps_box(door + Vector2(24, 14), 12.0, door, half, 0.0), "köşe çaprazı dışarıda")
	# On a vertical wall (90 deg): the wing extends along y.
	is_true(InteractionRules.circle_overlaps_box(door + Vector2(0, 27), 12.0, door, half, PI / 2), "90°: uç")
	is_false(InteractionRules.circle_overlaps_box(door + Vector2(16, 0), 12.0, door, half, PI / 2), "90°: teğet")
	is_false(InteractionRules.circle_overlaps_box(door, 0.0, door, half, 0.0), "yarıçap 0: örtüşme yok")


## KR-018/§6: core/ has no nodes and knows no project dirs (portability to 3D).
func test_core_is_nodeless() -> void:
	var forbidden: Array[String] = [
		"\\bNode2D\\b", "\\bNode3D\\b", "\\bNode\\b", "get_tree", "res://", "\\bpreload\\(", "\\bload\\(",
		"\\bGame\\.", "\\bNet\\.", "\\bArgs\\.", "\\bNoiseBus\\.",
	]
	var files: PackedStringArray = []
	for f: String in DirAccess.get_files_at(CORE_DIR):
		if f.ends_with(".gd"):
			files.append(CORE_DIR.path_join(f))
	is_true(files.size() >= 1, "core/ betikleri")
	for path: String in files:
		var source: String = FileAccess.get_file_as_string(path)
		has(source, "extends RefCounted", "%s RefCounted olmalı" % path)
		for line: String in source.split("\n"):
			var code: String = Deps.strip_comment(line)
			for pattern: String in forbidden:
				is_true(RegEx.create_from_string(pattern).search(code) == null,
					"%s yasak başvuru (%s): %s" % [path, pattern, line.strip_edges()])
