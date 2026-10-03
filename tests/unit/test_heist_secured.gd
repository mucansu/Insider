extends TestCase
## IS-094 (play test: "after my friend was caught I went to the escape point, it said 1/1 but the job did not end"): win and
## empty-handed retreat decide on the loot the crew has secured - register cash that entered team cash during the job
## (even if the emptier is caught later) + bags carried by uncaught players (a caught player's bag is lost). Payout is from
## this total; the caught player's personal share is 0, bail is deducted (KR-029).

const LOOTER := 2
const RUNNER := 3


func _tracker() -> HeistRules.Tracker:
	var t := HeistRules.Tracker.new()
	t.abort.hold_s = 3.0
	return t


func test_looter_caught_teammate_in_zone_wins() -> void:
	var t := _tracker()
	t.add_cash(LOOTER, 150)
	t.mark_caught(LOOTER, HeistRules.CAUGHT_BY_CHASER)
	var views := {LOOTER: {"caught": true, "in_zone": false}, RUNNER: {"in_zone": true}}
	t.observe(views, 0.1)
	eq(t.secured_loot(views), 150, "kasa nakdi ekipte kalır")
	eq(t.evaluate(views), HeistRules.DECISION_WIN, "bölgedeki serbest arkadaş kazanır")
	var roster := {LOOTER: {"name": "a", "slot": 0}, RUNNER: {"name": "b", "slot": 1}}
	var r: Dictionary = t.build_result(HeistRules.DECISION_WIN, views, roster, 100, 0)
	eq(r["outcome"], HeistRules.OUTCOME_CLEAN)
	eq(r["loot_total"], 150, "ödeme güvenceye alınan ganimetten")
	eq(r["payout"], 135)
	eq(r["players"][str(LOOTER)]["loot"], 0, "yakalananın payı 0")
	eq(r["players"][str(LOOTER)]["bail"], 100, "kefalet")
	eq(r["players"][str(RUNNER)]["escaped"], true)
	eq(r["cash_after"], 35, "0 + 135 − 100")


func test_caught_bag_carrier_loses_the_bag() -> void:
	var t := _tracker()
	t.mark_caught(LOOTER)
	var views := {LOOTER: {"caught": true, "bag_value": 450}, RUNNER: {"in_zone": true}}
	eq(t.secured_loot(views), 0, "yakalananın çantası sayılmaz")
	eq(t.evaluate(views), HeistRules.DECISION_NONE, "ganimet yok: kazanma yok")
	var carried := {LOOTER: {"caught": true}, RUNNER: {"in_zone": true, "bag_value": 450}}
	eq(t.secured_loot(carried), 450, "serbestin çantası sayılır")
	eq(t.evaluate(carried), HeistRules.DECISION_WIN)


func test_nothing_secured_aborts_after_hold() -> void:
	var t := _tracker()
	t.mark_caught(LOOTER)
	var views := {LOOTER: {"caught": true}, RUNNER: {"in_zone": true}}
	for i: int in 25:
		t.observe(views, 0.1)
	eq(t.evaluate(views), HeistRules.DECISION_NONE, "2,5 sn: henüz değil")
	for i: int in 6:
		t.observe(views, 0.1)
	eq(t.evaluate(views), HeistRules.OUTCOME_ABORTED, "hiçbir şey güvencede değil: 3 sn sonra eli boş")
	# If register cash is secured, empty-handed retreat does not apply (win).
	var t2 := _tracker()
	t2.add_cash(LOOTER, 150)
	t2.mark_caught(LOOTER)
	for i: int in 40:
		t2.observe(views, 0.1)
	is_false(t2.abort.done(), "ganimet güvencede: eli boş sayacı dolmaz")
	eq(t2.evaluate(views), HeistRules.DECISION_WIN)


func test_static_rules_with_secured() -> void:
	var players := {LOOTER: {"caught": true, "loot": 0}, RUNNER: {"in_zone": true, "loot": 0}}
	eq(HeistRules.decide(players, false), HeistRules.DECISION_NONE, "eski çağrı (secured yok) aynı")
	eq(HeistRules.decide(players, false, false, 150), HeistRules.DECISION_WIN)
	eq(HeistRules.decide(players, false, true, 0), HeistRules.OUTCOME_ABORTED)
	is_true(HeistRules.abort_ready(players, 0))
	is_false(HeistRules.abort_ready(players, 150))
	is_true(HeistRules.abort_ready(players), "eski çağrı aynı")
