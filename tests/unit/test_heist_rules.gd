extends TestCase
## US-012 kuralları (düğümsüz; core/heist_rules.gd): sonuç türü (uyarı kademesinden), aracı oranı ve ödeme,
## kazanma/kaybetme kararı (yakalanmamış herkes kaçış bölgesinde + ganimet; police → bölge dışındakiler yakalanır;
## herkes yakalandı), held ≠ caught, yakalananın payı 0, notlar (tek kişi, en fazla 2, en fazla 3, hayalet ekip),
## çanta düşürme zarları. Sahte sahip olayları Tracker yöntemleriyle verilir (US-008 yokken).

const A := 11
const B := 22
const C := 33


static func _view(in_zone: bool, bag_value: int = 0, caught: bool = false, held: bool = false,
		sprinting: bool = false) -> Dictionary:
	return {"in_zone": in_zone, "caught": caught, "held": held, "bag_value": bag_value, "sprinting": sprinting}


static func _roster() -> Dictionary:
	return {A: {"name": "Ayşe", "slot": 0}, B: {"name": "Bora", "slot": 1}, C: {"name": "Cem", "slot": 2}}


## Oyuncu durumu taklidi (US-008 oyuncu API'si).
class FlagNode:
	extends RefCounted
	var caught: bool = false

	func is_caught() -> bool:
		return caught


func test_win_outcome_by_max_alert() -> void:
	eq(HeistRules.win_outcome(0), &"clean")
	eq(HeistRules.win_outcome(1), &"clean", "uyarı ≤ 1 temiz")
	eq(HeistRules.win_outcome(2), &"shouted")
	eq(HeistRules.win_outcome(3), &"hot")
	eq(HeistRules.win_outcome(5), &"hot", "polis kademesi de sıcak")


func test_ratio_and_payout() -> void:
	eq(HeistRules.ratio_pct(&"clean", false), 90, "temiz %85 + kimse bağırmadı %5")
	eq(HeistRules.ratio_pct(&"clean", true), 85, "temiz ama bağırış olduysa bonus yok")
	eq(HeistRules.ratio_pct(&"shouted", true), 85)
	eq(HeistRules.ratio_pct(&"hot", true), 70)
	eq(HeistRules.ratio_pct(&"police", false), 0, "kayıpta ödeme yok")
	eq(HeistRules.ratio_pct(&"caught_all", false), 0)
	eq(HeistRules.payout(150, 90), 135)
	eq(HeistRules.payout(450, 85), 383, "382,5 yukarı yuvarlanır (tamsayı hesap)")
	eq(HeistRules.payout(600, 70), 420)
	eq(HeistRules.payout(-5, 90), 0)



func test_heat_per_outcome() -> void:
	eq(HeistRules.heat_for(&"clean"), 0, "temiz: ısı yok")
	eq(HeistRules.heat_for(&"shouted"), 5, "bağırışlı: +5")
	eq(HeistRules.heat_for(&"hot"), 10, "sıcak: +10 (KR-026)")
	eq(HeistRules.heat_for(&"police"), 15, "polis: +15 (KR-026)")
	eq(HeistRules.heat_for(&"caught_all"), 15, "herkes yakalandı: +15 (KR-026)")
	var t := HeistRules.Tracker.new()
	t.mark_caught(A)
	eq(t.build_result(&"caught_all", {A: _view(false)}, _roster())["heat"], 15, "sonuç sözlüğünde")
	t = HeistRules.Tracker.new()
	t.set_alert(3)
	eq(t.build_result(&"win", {A: _view(true, 450)}, _roster())["heat"], 10)


func test_adapt_callable_for_optional_signals() -> void:
	var target: Callable = func(peer: int, by: StringName = &"") -> String: return "%d:%s" % [peer, by]
	is_false(HeistRules.adapt_callable(target, 0, 1, 2).is_valid(), "argümanı eksik sinyal bağlanmaz")
	is_false(HeistRules.adapt_callable(target, -1, 1, 2).is_valid(), "sinyal yok")
	eq(HeistRules.adapt_callable(target, 1, 1, 2).call(7), "7:", "tek argümanlı sinyal: by varsayılan")
	eq(HeistRules.adapt_callable(target, 2, 1, 2).call(7, &"chaser"), "7:chaser", "iki argüman: by geçer")
	eq(HeistRules.adapt_callable(target, 3, 1, 2).call(7, &"chaser", 99), "7:chaser", "fazlası atılır")


func test_marathon_accumulates_sprint_time() -> void:
	var t := HeistRules.Tracker.new()
	for i: int in 120:
		t.observe({A: _view(false, 0, false, false, true), B: _view(false, 0, false, false, i % 2 == 0)}, 0.05)
	t.observe({A: _view(false), B: _view(false)}, 10.0)
	near(float(t.sprint_s[A]), 6.0, 0.001, "yalnız koşulan adımlar birikir")
	near(float(t.sprint_s[B]), 3.0, 0.001)
	t.add_cash(A, 150)
	var notes: Array = t.build_result(&"win", {A: _view(true), B: _view(true)}, _roster())["notes"]
	has(notes, {"kind": &"marathon", "peer": A}, "≥ 5 sn koşan Maratoncu")
	t = HeistRules.Tracker.new()
	t.observe({A: _view(false, 0, false, false, true)}, 4.9)
	t.add_cash(A, 150)
	for n: Dictionary in t.build_result(&"win", {A: _view(true)}, _roster())["notes"]:
		ne(n["kind"], &"marathon", "5 sn altı not yok")


## Belgeleme (koordinatör kararı: değişiklik yok): iş sürerken katılan oyuncu kaçış bölgesi dışında doğar ve
## yakalanmamış sayıldığı için kazanmayı bekletir; kazanma onun da bölgeye girmesini ister.
func test_late_joiner_outside_zone_blocks_win_today() -> void:
	var t := HeistRules.Tracker.new()
	var views: Dictionary = {A: _view(true, 450), B: _view(true)}
	eq(t.evaluate(views), &"win", "katılım öncesi: kazanılır")
	views[C] = _view(false)
	eq(t.evaluate(views), &"", "yeni katılan bölge dışında: iş sürer (bugünkü davranış)")


func test_decide_win_needs_everyone_free_in_zone_with_loot() -> void:
	var t := HeistRules.Tracker.new()
	eq(t.evaluate({}), &"", "oyuncu yoksa karar yok")
	eq(t.evaluate({A: _view(true), B: _view(true)}), &"", "ganimetsiz kaçış kazanma değil")
	eq(t.evaluate({A: _view(true, 450), B: _view(false)}), &"", "biri içerideyken iş sürer")
	eq(t.evaluate({A: _view(true, 450), B: _view(true)}), &"win", "çantayla herkes bölgede")
	t.add_cash(B, 150)
	eq(t.evaluate({A: _view(true), B: _view(true)}), &"win", "kasa nakdi de ganimet")
	eq(t.evaluate({A: _view(true), B: _view(false, 0, true)}), &"", "kasayı boşaltan yakalandıysa nakdi gitti")


func test_held_is_not_caught() -> void:
	var t := HeistRules.Tracker.new()
	var views: Dictionary = {A: _view(true, 450), B: _view(false, 0, false, true)}
	t.observe(views, 0.1)
	is_false(t.is_caught(B), "tutulan oyuncu yakalanmış sayılmaz")
	eq(t.evaluate(views), &"", "tutulan oyuncu bölge dışındayken iş bitmez")
	eq(t.evaluate({A: _view(false, 0, true), B: _view(false, 0, false, true)}), &"",
		"biri yakalandı, diğeri tutuluyor: caught_all değil")
	t.observe({B: _view(false, 0, true)}, 0.1)
	is_true(t.is_caught(B), "tutma süresi dolunca (US-008) caught")
	var result: Dictionary = t.build_result(&"win", {A: _view(true, 450), B: _view(true)}, _roster())
	eq(result["players"][str(B)]["caught"], true)


func test_caught_all() -> void:
	var t := HeistRules.Tracker.new()
	t.mark_caught(A)
	eq(t.evaluate({A: _view(false), B: _view(false, 450)}), &"", "biri hâlâ serbest")
	eq(t.evaluate({A: _view(false), B: _view(true, 450)}), &"win", "yakalanmamış tek kişi çantayla çıktı: kazanma")
	t.mark_caught(B, &"chaser")
	eq(t.evaluate({A: _view(false), B: _view(false, 450)}), &"caught_all", "herkes yakalandı")
	var result: Dictionary = t.build_result(&"caught_all", {A: _view(false), B: _view(false, 450)}, _roster())
	eq(result["outcome"], &"caught_all")
	eq(result["payout"], 0)
	eq(result["payout_ratio"], 0.0)
	eq(result["players"][str(B)]["loot"], 0, "yakalananın payı 0")


func test_police_catches_everyone_inside() -> void:
	var t := HeistRules.Tracker.new()
	var views: Dictionary = {A: _view(false), B: _view(false, 450, false, true), C: _view(true)}
	t.arrive_police(views)
	is_true(t.is_caught(A), "içeride kalan yakalanır")
	is_true(t.is_caught(B), "tutulan da yakalanır")
	is_false(t.is_caught(C), "kaçış bölgesindeki yakalanmaz")
	eq(t.evaluate(views), &"police", "kaçan ganimetsiz: polis (kayıp)")
	var result: Dictionary = t.build_result(&"police", views, _roster())
	eq(result["outcome"], &"police")
	eq(result["players"][str(C)]["escaped"], false, "kayıpta kimse kaçmış sayılmaz")
	eq(result["players"][str(A)]["caught"], true)


func test_police_with_loot_outside_is_hot_win() -> void:
	var t := HeistRules.Tracker.new()
	t.set_alert(3)
	t.set_alert(5)
	var views: Dictionary = {A: _view(false), B: _view(true, 450)}
	t.arrive_police(views)
	eq(t.evaluate(views), &"win", "dışarıdaki çantayla: içerideki yakalanır, iş sıcak kazanılır")
	var result: Dictionary = t.build_result(&"win", views, _roster())
	eq(result["outcome"], &"hot")
	eq(result["payout_ratio"], 0.7)
	eq(result["loot_total"], 450)
	eq(result["payout"], 315)
	eq(result["players"][str(A)]["loot"], 0)
	eq(result["players"][str(B)]["escaped"], true)


func test_police_with_nobody_out_is_police() -> void:
	var t := HeistRules.Tracker.new()
	var views: Dictionary = {A: _view(false, 450), B: _view(false)}
	t.arrive_police(views)
	eq(t.evaluate(views), &"police")


func test_result_shape_and_shares() -> void:
	var t := HeistRules.Tracker.new()
	t.set_alert(2)
	t.add_cash(A, 150)
	t.note_bag(B)
	t.observe({A: _view(true), B: _view(true, 450), C: _view(false, 0, true)}, 12.346)
	var views: Dictionary = {A: _view(true), B: _view(true, 450), C: _view(false, 0, true)}
	eq(t.evaluate(views), &"win")
	var result: Dictionary = t.build_result(&"win", views, _roster())
	for key: String in ["outcome", "loot_total", "payout_ratio", "payout", "duration_s", "players", "notes"]:
		is_true(result.has(key), "S3 eki alanı: " + key)
	eq(result["outcome"], &"shouted")
	eq(result["loot_total"], 600, "kaçanların ganimeti: kasa 150 + çanta 450")
	eq(result["payout_ratio"], 0.85)
	eq(result["payout"], 510)
	eq(result["duration_s"], 12.35)
	eq(result["heat"], 5)
	var players: Dictionary = result["players"]
	eq(players.size(), 3)
	eq(players[str(A)], {"name": "Ayşe", "slot": 0, "escaped": true, "caught": false, "loot": 150})
	eq(players[str(B)]["loot"], 450)
	eq(players[str(C)], {"name": "Cem", "slot": 2, "escaped": false, "caught": true, "loot": 0})
	eq(t.cash_grabbed(), 150)


func test_shout_event_cancels_clean_bonus() -> void:
	var t := HeistRules.Tracker.new()
	t.add_cash(A, 150)
	t.note_shout()
	var result: Dictionary = t.build_result(&"win", {A: _view(true)}, {A: {"name": "", "slot": 0}})
	eq(result["outcome"], &"clean", "uyarı 0 → temiz")
	eq(result["payout_ratio"], 0.85, "ama biri bağırdı: bonus yok")


func test_notes_rules() -> void:
	var stats: Dictionary = {
		"max_alert": 0, "caught": {}, "bags": {B: 2, C: 2}, "sprint_s": {A: 9.0, B: 4.0},
		"slots": {A: 0, B: 2, C: 1},
	}
	var notes: Array[Dictionary] = HeistRules.pick_notes(HeistRules.note_candidates(stats))
	eq(notes, [
		{"kind": &"ghost_crew", "peer": 0},
		{"kind": &"porter", "peer": C},
		{"kind": &"marathon", "peer": A},
	], "hayalet ekip; eşitlikte küçük yuva; maratoncu ≥ 5 sn")
	stats["max_alert"] = 2
	stats["caught"] = {A: &"chaser"}
	stats["bags"] = {A: 1}
	notes = HeistRules.pick_notes(HeistRules.note_candidates(stats))
	eq(notes, [{"kind": &"slipper", "peer": A}, {"kind": &"bail", "peer": A}],
		"aynı kişiye en fazla 2 not; hayalet ekip yok (uyarı oldu)")
	var many: Array[Dictionary] = [
		{"kind": &"ghost_crew", "peer": 0}, {"kind": &"bail", "peer": A}, {"kind": &"porter", "peer": B},
		{"kind": &"marathon", "peer": C}, {"kind": &"bail", "peer": B},
	]
	eq(HeistRules.pick_notes(many).size(), 3, "en fazla 3 not")


func test_bag_drop_rolls() -> void:
	eq(HeistRules.rolls_due(0.0, 0.99), 0)
	eq(HeistRules.rolls_due(0.99, 1.0), 1, "her tam saniyede bir zar")
	eq(HeistRules.rolls_due(0.5, 3.2), 3)
	eq(HeistRules.rolls_due(2.0, 2.0), 0)
	is_true(HeistRules.drops(0.0))
	is_true(HeistRules.drops(0.2499))
	is_false(HeistRules.drops(0.25), "%25")
	is_false(HeistRules.drops(0.9))


func test_node_flag_reads_player_api() -> void:
	var node := FlagNode.new()
	is_false(HeistRules.node_flag(node, HeistRules.CAUGHT_METHODS))
	node.caught = true
	is_true(HeistRules.node_flag(node, HeistRules.CAUGHT_METHODS))
	is_false(HeistRules.node_flag(node, HeistRules.HELD_METHODS), "yöntem yoksa false (US-008 öncesi)")
	is_false(HeistRules.node_flag(null, HeistRules.CAUGHT_METHODS))


func test_finished_tracker_stops_deciding() -> void:
	var t := HeistRules.Tracker.new()
	t.finished = true
	eq(t.evaluate({A: _view(true, 450)}), &"")
