extends TestCase
## KR-045 addendum (IS-114): the crew gathers at the van and starts the job there, so the escape zone (empty-handed abort US-040,
## escape settle / win IS-103) is only evaluated once the escape is armed - the first time any uncaught player is outside the zone.
## Pure rule (HeistRules.escape_arms / zone_counts) and the Tracker wiring. Multi-process: tests/net/heist_start_walk.json.

const DT := 0.1


func _tracker(settle_s: float = 0.0) -> HeistRules.Tracker:
	var t := HeistRules.Tracker.new()
	t.disarm_escape()  # as Game creates every job's Tracker
	t.abort.hold_s = 3.0
	t.settle.hold_s = settle_s
	return t


static func _views(in_zone: Array[bool], bag: int = 0) -> Dictionary:
	var out: Dictionary = {}
	for i: int in in_zone.size():
		out[i + 1] = {"in_zone": in_zone[i], "caught": false, "held": false, "bag_value": bag if i == 0 else 0, "sprinting": false}
	return out


## Runs `seconds` of observe+evaluate with the same views; returns the first decision (or DECISION_NONE).
static func _run(t: HeistRules.Tracker, views: Dictionary, seconds: float) -> StringName:
	var steps: int = roundi(seconds / DT)
	for i: int in steps:
		t.observe(views, DT)
		var d: StringName = t.evaluate(views)
		if d != HeistRules.DECISION_NONE:
			return d
	return HeistRules.DECISION_NONE


func test_rule() -> void:
	is_false(HeistRules.escape_arms(false, 2, 2), "hepsi bölgede: kurulmaz")
	is_true(HeistRules.escape_arms(false, 2, 1), "biri dışarıda: kurulur")
	is_true(HeistRules.escape_arms(true, 2, 2), "bir kez kuruldu: kalır")
	is_false(HeistRules.escape_arms(false, 0, 0), "serbest oyuncu yok: değişmez")
	var state: Dictionary = {1: {"caught": false, "in_zone": true}, 2: {"caught": true, "in_zone": false},
		3: {"released": true, "in_zone": false}, 4: {"in_zone": false}}
	eq(HeistRules.zone_counts(state), Vector2i(2, 1), "yakalanan ve serbest bırakılan sayılmaz")


func test_start_in_zone_does_not_end_job() -> void:
	var t := _tracker()
	eq(_run(t, _views([true, true]), 10.0), HeistRules.DECISION_NONE, "hepsi minibüste başladı: 10 sn sonra iş sürüyor")
	is_false(t.escape_armed)
	eq(t.escape_armed_at_s, -1.0)
	eq(t.abort.left(), -1.0, "eli boş sayacı çalışmaz")


func test_leave_and_return_then_abort_after_hold() -> void:
	var t := _tracker()
	_run(t, _views([true, true]), 2.0)
	eq(_run(t, _views([true, false]), 1.0), HeistRules.DECISION_NONE, "biri çıktı")
	is_true(t.escape_armed, "kuruldu")
	near(t.escape_armed_at_s, 2.1, 0.11)
	eq(_run(t, _views([true, true]), 2.5), HeistRules.DECISION_NONE, "döndü: sayaç sürüyor (3 sn dolmadı)")
	is_true(t.abort.running())
	eq(_run(t, _views([true, true]), 1.0), HeistRules.OUTCOME_ABORTED, "3 sn sonra eli boş çekilme (bugünkü kural)")


func test_start_away_from_zone_is_armed_at_once() -> void:
	var t := _tracker()
	eq(_run(t, _views([false, false]), 0.1), HeistRules.DECISION_NONE)
	is_true(t.escape_armed, "uzakta başlayan ekip hemen kurulur (eski davranış)")
	eq(_run(t, _views([true, true]), 3.2), HeistRules.OUTCOME_ABORTED)


func test_settle_with_loot_unchanged_after_arming() -> void:
	var t := _tracker(2.0)
	eq(_run(t, _views([true, true], 300), 5.0), HeistRules.DECISION_NONE, "kurulmadan ganimetle bölgede: kazanma yok")
	eq(t.settle.left(), -1.0, "kaçış geri sayımı çalışmaz")
	_run(t, _views([false, true], 300), 0.5)
	is_true(t.escape_armed)
	eq(_run(t, _views([true, true], 300), 1.5), HeistRules.DECISION_NONE, "geri sayım sürüyor")
	is_true(t.settle.running())
	eq(_run(t, _views([true, true], 300), 1.0), HeistRules.DECISION_WIN, "2 sn sonra kaçış (bugünkü kural)")


func test_police_still_ends_unarmed_job() -> void:
	var t := _tracker()
	var views: Dictionary = _views([true, true])
	_run(t, views, 1.0)
	t.arrive_police(views)
	eq(t.evaluate(views), HeistRules.OUTCOME_POLICE, "polis kuruluma bakmaz (bugünkü sıra)")
