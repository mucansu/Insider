extends TestCase
## US-012 rules (no node; core/heist_rules.gd): result kind (from alert level), broker rate and payout, win/lose decision
## (everyone not caught is in the escape zone + loot; police -> those outside the zone are caught; everyone caught),
## held != caught, caught player's share 0, notes (solo, at most 2, at most 3, ghost crew), bag drop dice.
## Fake owner events are fed through Tracker methods (without US-008).

const A := 11
const B := 22
const C := 33


static func _view(in_zone: bool, bag_value: int = 0, caught: bool = false, held: bool = false,
		sprinting: bool = false) -> Dictionary:
	return {"in_zone": in_zone, "caught": caught, "held": held, "bag_value": bag_value, "sprinting": sprinting}


static func _roster() -> Dictionary:
	return {A: {"name": "Ayşe", "slot": 0}, B: {"name": "Bora", "slot": 1}, C: {"name": "Cem", "slot": 2}}


## Fake of player state (US-008 player API).
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


## Documented (coordinator decision: no change): a player joining mid-job spawns outside the escape zone and counts as
## not caught, so holds the win back; winning requires them to enter the zone too.
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
	eq(t.evaluate({A: _view(true), B: _view(false, 0, true)}), &"win",
		"IS-094: kasayı boşaltan yakalansa da nakit ekipte (güvencede); bölgedeki arkadaş kazanır")


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
	var inside: Dictionary = _view(false)
	inside["staff_side"] = true  # cover broken (US-042): no witness check
	var views: Dictionary = {A: inside, B: _view(false, 450, false, true), C: _view(true)}
	t.arrive_police(views)
	is_true(t.is_caught(A), "içeride kalan (örtüsü bozuk) yakalanır")
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
	eq(players[str(A)], {"name": "Ayşe", "slot": 0, "escaped": true, "caught": false, "loot": 150, "bail": 0,
		"witness_released": false, "recognized": 0, "left": false})
	eq(players[str(B)]["loot"], 450)
	eq(players[str(C)], {"name": "Cem", "slot": 2, "escaped": false, "caught": true, "loot": 0, "bail": 0,
		"witness_released": false, "recognized": 0, "left": false})
	eq(t.cash_grabbed(), 150)


## IS-099: a player who left mid-job (C emptied the register, was caught, then left) is listed with `left: true` and zero share/bail;
## every other result field equals the same job without the record (economy unchanged).
func test_left_player_listed_without_changing_economy() -> void:
	var trackers: Array[HeistRules.Tracker] = [HeistRules.Tracker.new(), HeistRules.Tracker.new()]
	var views: Dictionary = {A: _view(true), B: _view(true, 450)}
	var roster: Dictionary = _roster()
	var cem: Dictionary = roster[C]
	roster.erase(C)
	for t: HeistRules.Tracker in trackers:
		t.add_cash(C, 150)
		t.mark_caught(C)
		t.observe(views, 3.0)
	trackers[1].note_left(C, cem)
	var base: Dictionary = trackers[0].build_result(&"win", views, roster, 100, 1000)
	var with_left: Dictionary = trackers[1].build_result(&"win", views, roster, 100, 1000)
	var players: Dictionary = with_left["players"]
	eq(players.size(), 3, "ayrılan da listede")
	eq(players[str(C)], {"name": "Cem", "slot": 2, "escaped": false, "caught": false, "loot": 0, "bail": 0,
		"witness_released": false, "recognized": 0, "left": true})
	eq(players[str(C)], HeistRules.left_entry(cem))
	is_false(bool(players[str(A)]["left"]), "kalanlarda left: false")
	is_false(bool(players[str(B)]["left"]))
	eq((base["players"] as Dictionary).size(), 2, "ayrılma kaydı yoksa eski davranış")
	for key: String in base:
		if key != "players":
			eq(with_left[key], base[key], "ekonomi/sonuç değişmez: " + key)
	for key: String in base["players"]:
		eq(players[key], base["players"][key], "kalanların kaydı aynı: " + key)
	eq(with_left["loot_total"], 600, "ayrılanın boşalttığı kasa ekipte kalır (IS-094)")
	eq(with_left["bail"], 0, "ayrılan kefalet ödemez")


func test_note_left_after_finish_or_for_roster_player_is_ignored() -> void:
	var t := HeistRules.Tracker.new()
	t.note_left(0, {"name": "x", "slot": 0})
	t.note_left(C, {"name": "Cem", "slot": 2})
	eq(t.departed.size(), 1, "geçersiz peer yok sayılır")
	var r: Dictionary = t.build_result(&"win", {A: _view(true)}, _roster())
	is_false(bool((r["players"] as Dictionary)[str(C)]["left"]), "yeniden kadrodaki oyuncunun kaydı kadrodan gelir")
	t.finished = true
	t.note_left(B, {"name": "Bora", "slot": 1})
	is_false(t.departed.has(B), "iş bittikten sonra ayrılan kaydedilmez")
	eq(HeistRules.left_entry({})["name"], "", "eksik alan: boş ad")


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


# --- US-040 empty-handed retreat ---

## Watches `t` for `seconds` in 60 Hz steps and decides at each step: [first decision (&"" if none), its time (s)].
static func _run(t: HeistRules.Tracker, views: Dictionary, seconds: float) -> Array:
	var dt: float = 1.0 / 60.0
	for i: int in roundi(seconds / dt):
		t.observe(views, dt)
		var d: StringName = t.evaluate(views)
		if d != &"":
			return [d, (i + 1) * dt]
	return [&"", seconds]


func test_abort_after_three_seconds_together_without_loot() -> void:
	var t := HeistRules.Tracker.new()
	eq(t.abort.hold_s, 3.0, "yedek süre 3 sn (asıl değer veride)")
	eq(HeistTuning.load_default().abort_hold_s, 3.0, "data/heist_tuning.tres: 3 sn")
	var views: Dictionary = {A: _view(true), B: _view(true)}
	is_true(HeistRules.abort_ready(t.players_state(views)), "koşul: herkes bölgede, ganimet 0")
	eq(_run(t, views, 2.9)[0], &"", "3 sn dolmadan iş sürer")
	near(t.abort.left(), 0.1, 0.02, "kalan ~0,1 sn")
	eq(_run(t, views, 0.2)[0], &"aborted", "3 sn kesintisiz: aborted")
	near(t.abort.held_s, 3.0, 0.02)


func test_abort_resets_when_someone_leaves_or_is_caught() -> void:
	var t := HeistRules.Tracker.new()
	var both: Dictionary = {A: _view(true), B: _view(true)}
	eq(_run(t, both, 2.5)[0], &"")
	_run(t, {A: _view(true), B: _view(false)}, 1.0 / 60.0)
	eq(t.abort.held_s, 0.0, "biri çıktı: sayaç sıfır")
	eq(t.abort.left(), -1.0, "sayaç yok: -1")
	eq(_run(t, both, 2.5)[0], &"", "yeniden 2,5 sn: hâlâ sürer (sıfırdan saydı)")
	var r: Array = _run(t, both, 1.0)
	eq(r[0], &"aborted")
	near(float(r[1]), 0.5, 0.02, "toplam 3 sn sonra")
	# Caught: the condition is rebuilt at that step (all free players in the zone); the counter is not continuous, it restarts.
	t = HeistRules.Tracker.new()
	var three: Dictionary = {A: _view(true), B: _view(true), C: _view(false)}
	eq(_run(t, three, 2.0)[0], &"", "biri bölge dışında: sayaç yok")
	eq(t.abort.held_s, 0.0)
	t.mark_caught(C, &"chaser")
	r = _run(t, three, 3.1)
	eq(r[0], &"aborted", "yakalanan sayıma girmez: kalan ikisi bölgede ganimetsiz")
	near(float(r[1]), 3.0, 0.02, "sayaç yakalanmadan sonra başladı")
	# If someone is caught while counting in the zone (the rest still in the zone without loot) the counter restarts.
	var t2 := HeistRules.Tracker.new()
	eq(_run(t2, both, 2.0)[0], &"")
	t2.mark_caught(B, &"chaser")
	r = _run(t2, both, 3.1)
	eq(r[0], &"aborted")
	near(float(r[1]), 3.0, 0.02, "yakalanma sayacı sıfırladı (2 sn sayılmış süre gitti)")
	var result: Dictionary = t.build_result(&"aborted", three, _roster(), 100, 0)
	eq(result["players"][str(C)]["caught"], true, "yakalanan yakalı kalır")
	eq(result["players"][str(C)]["escaped"], false)
	eq(result["bail"], 100, "yakalananın kefaleti eli boş çekilmede de düşer")


func test_abort_never_with_loot_uses_win_rule() -> void:
	var t := HeistRules.Tracker.new()
	t.add_cash(A, 150)
	var views: Dictionary = {A: _view(true), B: _view(true)}
	is_false(HeistRules.abort_ready(t.players_state(views)), "ganimet var: koşul yok")
	var r: Array = _run(t, views, 5.0)
	eq(r[0], &"win", "ganimet > 0: kazanma anında")
	near(float(r[1]), 1.0 / 60.0, 0.001, "ilk adımda")
	t = HeistRules.Tracker.new()
	eq(_run(t, {A: _view(true, 450), B: _view(true)}, 1.0)[0], &"win", "çanta da ganimet")


func test_abort_not_after_police() -> void:
	var t := HeistRules.Tracker.new()
	var views: Dictionary = {A: _view(true), B: _view(true)}
	t.arrive_police(views)
	eq(_run(t, views, 1.0 / 60.0)[0], &"police", "polis geldiyse polis kuralı (ganimetsiz)")
	eq(t.abort.held_s, 0.0, "polisten sonra sayaç işlemez")
	eq(HeistRules.decide({A: {"caught": false, "in_zone": true, "loot": 0}}, false, true), &"aborted")
	eq(HeistRules.decide({A: {"caught": false, "in_zone": true, "loot": 0}}, true, true), &"police")
	eq(HeistRules.decide({A: {"caught": false, "in_zone": false, "loot": 0}}, false, true), &"",
		"sayaç dolmuş olsa da koşul bozulduysa karar yok")
	is_false(HeistRules.abort_ready({}), "oyuncu yok")
	is_false(HeistRules.abort_ready({A: {"caught": true, "in_zone": true, "loot": 0}}), "serbest kimse yok")


func test_aborted_result_and_heat() -> void:
	var t := HeistRules.Tracker.new()
	var views: Dictionary = {A: _view(true), B: _view(true)}
	var two: Dictionary = {A: _roster()[A], B: _roster()[B]}
	eq(_run(t, views, 3.1)[0], &"aborted")
	var result: Dictionary = t.build_result(&"aborted", views, two, 100, 40)
	eq(result["outcome"], &"aborted")
	eq(result["payout"], 0, "pay 0")
	eq(result["payout_ratio"], 0.0)
	eq(result["loot_total"], 0)
	eq(result["heat"], 0, "bağırış yok: ısı 0")
	eq(result["bail"], 0, "kimse yakalanmadı: kefalet yok")
	eq(result["cash_after"], 40, "kasa değişmez")
	for id: int in [A, B]:
		eq(result["players"][str(id)]["escaped"], true, "bölgedekiler kaçmış sayılır")
		eq(result["players"][str(id)]["caught"], false)
	has(result["notes"], {"kind": &"ghost_crew", "peer": 0}, "notlar mevcut kurallarla")
	eq(HeistRules.heat_for(&"aborted", 1), 0, "şüphe: 0")
	eq(HeistRules.heat_for(&"aborted", 2), 5, "bağırış olduysa +5")
	eq(HeistRules.heat_for(&"aborted", 3), 5)
	t = HeistRules.Tracker.new()
	t.set_alert(2)
	eq(_run(t, views, 3.1)[0], &"aborted")
	eq(t.build_result(&"aborted", views, two)["heat"], 5, "sonuç sözlüğünde +5")


func test_abort_clock() -> void:
	var c := HeistRules.AbortClock.new(1.0)
	eq(c.left(), -1.0)
	is_false(c.done())
	c.step(true, 0.4)
	near(c.left(), 0.6, 0.0001)
	c.step(false, 0.1)
	eq(c.left(), -1.0, "koşul bozuldu: sıfır")
	near(c.peak_s, 0.4, 0.0001, "en uzun görülen süre kalır")
	for i: int in 60:
		c.step(true, 1.0 / 60.0)
	is_true(c.done(), "60 × 1/60 = 1 sn (kayan nokta toleransı)")
	eq(c.left(), 0.0)
	c.step(true, 0.1, 1)
	near(c.held_s, 0.1, 0.0001, "epoch değişti: baştan")


# --- IS-103 escape settle (KR-034) ---

## A Tracker with the real escape settle duration (data/heist_tuning.tres; Game sets it the same way).
static func _settle_tracker() -> HeistRules.Tracker:
	var t := HeistRules.Tracker.new()
	t.settle.hold_s = HeistTuning.load_default().escape_settle_s
	return t


func test_escape_settle_countdown_then_clean() -> void:
	eq(HeistTuning.load_default().escape_settle_s, 3.0, "data/heist_tuning.tres: 3 sn")
	eq(HeistRules.Tracker.new().settle.hold_s, 0.0, "Tracker varsayılanı 0: geri sayım yok (ayarı Game verir)")
	var t := _settle_tracker()
	t.add_cash(A, 150)
	var views: Dictionary = {A: _view(true), B: _view(true, 450)}
	is_true(HeistRules.settle_ready(t.players_state(views), t.secured_loot(views)), "koşul: herkes bölgede, ganimet > 0")
	eq(t.evaluate(views), &"", "gözlem yokken de kazanma bekletilir")
	eq(_run(t, views, 2.9)[0], &"", "3 sn dolmadan iş sürer")
	near(t.settle.left(), 0.1, 0.02, "kalan ~0,1 sn")
	eq(t.abort.left(), -1.0, "eli boş sayacı çalışmaz")
	eq(_run(t, views, 0.2)[0], &"win", "3 sn kesintisiz: kazanma")
	near(t.settle.held_s, 3.0, 0.02)
	var result: Dictionary = t.build_result(&"win", views, {A: _roster()[A], B: _roster()[B]})
	eq(result["outcome"], &"clean")
	eq(result["payout_ratio"], 0.9, "kimse bağırmadı: %90")
	# Zero duration = old behaviour (instant win at the first step).
	var t0 := HeistRules.Tracker.new()
	t0.add_cash(A, 150)
	var r: Array = _run(t0, views, 1.0)
	eq(r[0], &"win")
	near(float(r[1]), 1.0 / 60.0, 0.001, "süre 0: ilk adımda")


func test_escape_settle_shout_during_countdown_is_shouted() -> void:
	var t := _settle_tracker()
	t.add_cash(A, 150)
	var views: Dictionary = {A: _view(true)}
	eq(_run(t, views, 1.5)[0], &"", "geri sayım sürüyor")
	t.set_alert(2)
	var r: Array = _run(t, views, 1.0)
	eq(r[0], &"win", "bağırış: iş hemen biter")
	near(float(r[1]), 1.0 / 60.0, 0.001, "bağırıştan sonraki ilk adımda")
	eq(t.settle.left(), -1.0, "bağırıştan sonra geri sayım yok")
	var result: Dictionary = t.build_result(&"win", views, {A: _roster()[A]})
	eq(result["outcome"], &"shouted")
	eq(result["payout_ratio"], 0.85, "ödeme kuralları değişmez")
	eq(result["payout"], 128)
	eq(result["heat"], 5)
	# Alert 3 during the countdown: hot (same rule, highest tier).
	t = _settle_tracker()
	t.add_cash(A, 150)
	eq(_run(t, views, 1.0)[0], &"")
	t.set_alert(3)
	eq(_run(t, views, 1.0 / 60.0)[0], &"win")
	eq(t.build_result(&"win", views, {A: _roster()[A]})["outcome"], &"hot")


func test_escape_settle_cancelled_when_someone_leaves_or_is_caught() -> void:
	var t := _settle_tracker()
	t.add_cash(A, 150)
	var both: Dictionary = {A: _view(true), B: _view(true)}
	eq(_run(t, both, 2.5)[0], &"")
	_run(t, {A: _view(true), B: _view(false)}, 1.0 / 60.0)
	eq(t.settle.left(), -1.0, "biri çıktı: geri sayım iptal")
	eq(_run(t, both, 2.5)[0], &"", "baştan sayıyor: 2,5 sn'de bitmez")
	var r: Array = _run(t, both, 1.0)
	eq(r[0], &"win")
	near(float(r[1]), 0.5, 0.02, "yeniden girişten 3 sn sonra")
	# Caught during the countdown (the rest still in the zone with loot): the countdown restarts.
	t = _settle_tracker()
	t.add_cash(A, 150)
	eq(_run(t, both, 2.0)[0], &"")
	t.mark_caught(B, &"chaser")
	r = _run(t, both, 3.1)
	eq(r[0], &"win")
	near(float(r[1]), 3.0, 0.02, "yakalanma geri sayımı sıfırladı")
	# A newcomer outside the zone (late joiner) cancels it as well.
	t = _settle_tracker()
	t.add_cash(A, 150)
	eq(_run(t, {A: _view(true)}, 2.0)[0], &"")
	eq(_run(t, {A: _view(true), C: _view(false)}, 2.0)[0], &"", "yeni gelen dışarıda: iş sürer")
	eq(t.settle.left(), -1.0)


func test_escape_settle_instant_when_alert_already_shouted_or_police() -> void:
	var t := _settle_tracker()
	t.add_cash(A, 150)
	t.set_alert(2)
	var views: Dictionary = {A: _view(true)}
	var r: Array = _run(t, views, 1.0)
	eq(r[0], &"win", "varışta uyarı 2: anında")
	near(float(r[1]), 1.0 / 60.0, 0.001, "ilk adımda")
	eq(t.settle.peak_s, 0.0, "geri sayım hiç başlamadı")
	# Alert went 2 -> 1 before arriving: max alert still counts (no countdown).
	t = _settle_tracker()
	t.add_cash(A, 150)
	t.set_alert(2)
	t.set_alert(1)
	eq(_run(t, views, 1.0 / 60.0)[0], &"win", "en yüksek uyarı 2 kalır: anında")
	# Police arrived: those in the zone with loot win at once (hot), no countdown.
	t = _settle_tracker()
	t.add_cash(A, 150)
	var two: Dictionary = {A: _view(true), B: _view(false)}
	t.arrive_police(two)
	eq(_run(t, two, 1.0 / 60.0)[0], &"win", "polis: anında sıcak kazanma")
	eq(t.settle.peak_s, 0.0)
	eq(HeistRules.decide({A: {"caught": false, "in_zone": true, "loot": 150}}, false, false, -1, true), &"",
		"win_hold: kazanma bekletilir")
	eq(HeistRules.decide({A: {"caught": false, "in_zone": true, "loot": 0}}, false, true, -1, true), &"aborted",
		"win_hold eli boş çekilmeyi etkilemez")


func test_escape_settle_and_abort_never_overlap() -> void:
	var t := _settle_tracker()
	var views: Dictionary = {A: _view(true), B: _view(true)}
	eq(_run(t, views, 2.0)[0], &"", "ganimet 0: eli boş sayacı")
	is_true(t.abort.running(), "abort çalışıyor")
	eq(t.settle.left(), -1.0, "settle çalışmıyor")
	t.add_cash(A, 150)  # loot appears (e.g. register emptied from inside the zone edge)
	_run(t, views, 1.0 / 60.0)
	eq(t.abort.left(), -1.0, "ganimet > 0: abort sıfırlandı")
	is_true(t.settle.running(), "settle başladı")
	var r: Array = _run(t, views, 3.1)
	eq(r[0], &"win", "settle yolu: kazanma (aborted değil)")
	near(float(r[1]), 3.0 - 1.0 / 60.0, 0.02)
	is_false(HeistRules.settle_ready({A: {"caught": false, "in_zone": true, "loot": 0}}), "ganimet 0: settle koşulu yok")
	is_false(HeistRules.abort_ready({A: {"caught": false, "in_zone": true, "loot": 10}}), "ganimet > 0: abort koşulu yok")


# --- US-041 bail ---

func test_bail_table_and_cash() -> void:
	var table: Dictionary = HeistTuning.load_default().bail_by_tier
	eq(HeistRules.bail_for_tier(table, 1), 100, "T1 bakkal 100 (data/heist_tuning.tres)")
	eq(HeistRules.bail_for_tier({1: 100, 3: 250}, 2), 100, "tabloda yok: en yakın alt kademe")
	eq(HeistRules.bail_for_tier({1: 100, 3: 250}, 4), 250)
	eq(HeistRules.bail_for_tier({2: 100}, 1), 0, "alt kademe yok: 0")
	eq(HeistRules.bail_for_tier({}, 1), 0)
	eq(HeistRules.cash_after(0, 540, 0), 540)
	eq(HeistRules.cash_after(0, 0, 200), -200, "kasa eksiye düşebilir (borç)")
	eq(HeistRules.cash_after(-200, 135, 0), -65, "sonraki ödeme borcu azaltır")
	eq(HeistRules.cash_after(-65, 383, 100), 218, "borç kapanır, yeni kefalet düşer")


func test_bail_per_caught_player() -> void:
	var two: Dictionary = {A: _roster()[A], B: _roster()[B]}
	# 0 caught.
	var t := HeistRules.Tracker.new()
	t.add_cash(A, 150)
	var views: Dictionary = {A: _view(true), B: _view(true)}
	var r: Dictionary = t.build_result(&"win", views, two, 100, 0)
	eq(r["bail"], 0)
	eq(r["cash_after"], 135, "iş öncesi 0 + ödeme 135")
	# 1 caught: B caught, A escaped with the register.
	t = HeistRules.Tracker.new()
	t.add_cash(A, 150)
	t.mark_caught(B, &"chaser")
	views = {A: _view(true), B: _view(false)}
	eq(t.evaluate(views), &"win")
	r = t.build_result(&"win", views, two, 100, 50)
	eq(r["bail"], 100, "toplam kefalet")
	eq(r["players"][str(B)]["bail"], 100, "yakalanan kaydında")
	eq(r["players"][str(A)]["bail"], 0)
	eq(r["cash_before"], 50)
	eq(r["cash_after"], 50 + 135 - 100, "iş öncesi + ödeme − kefalet")
	# 2 caught (everyone): payout 0, register goes negative.
	t = HeistRules.Tracker.new()
	t.mark_caught(A)
	t.mark_caught(B)
	r = t.build_result(&"caught_all", {A: _view(false), B: _view(false)}, two, 100, 0)
	eq(r["bail"], 200)
	eq(r["cash_after"], -200, "borç")
	# The next job's payout naturally clears the debt (no extra logic: pre-job = previous job's cash_after).
	t = HeistRules.Tracker.new()
	t.add_cash(A, 150)
	t.add_cash(B, 300)
	r = t.build_result(&"win", {A: _view(true), B: _view(true)}, two, 100, -200)
	eq(r["payout"], 405)
	eq(r["cash_after"], 205, "-200 + 405: borç kapandı")


# --- US-042 cover and witness check ---

static func _with(view: Dictionary, extra: Dictionary) -> Dictionary:
	var out: Dictionary = view.duplicate()
	out.merge(extra, true)
	return out


func test_cover_breakers() -> void:
	eq(HeistRules.cover_breaker(_view(false)), &"", "dışarıda yürüyen: sağlam")
	eq(HeistRules.cover_breaker(_with(_view(false), {"move_mode": HeistRules.MOVE_WALK})), &"")
	eq(HeistRules.cover_breaker(_with(_view(false), {"masked": true})), &"mask")
	eq(HeistRules.cover_breaker(_view(false, 450)), &"bag", "çanta elde")
	eq(HeistRules.cover_breaker(_with(_view(false), {"holding_cash": true})), &"cash", "kasa/nakit tutuyor")
	eq(HeistRules.cover_breaker(_with(_view(false), {"staff_side": true})), &"staff", "personel tarafı / arka oda")
	eq(HeistRules.cover_breaker(_view(false, 0, false, false, true)), &"run", "koşuyor")
	eq(HeistRules.cover_breaker(_with(_view(false), {"move_mode": HeistRules.MOVE_SNEAK})), &"sneak", "sızıyor")
	eq([HeistRules.MOVE_WALK, HeistRules.MOVE_SNEAK, HeistRules.MOVE_SPRINT],
		[PlayerMotion.Mode.WALK, PlayerMotion.Mode.SNEAK, PlayerMotion.Mode.SPRINT], "kip değerleri PlayerMotion ile aynı")


func test_cover_breaks_permanently() -> void:
	var t := HeistRules.Tracker.new()
	t.observe({A: _view(false), B: _view(false)}, 0.1)
	is_true(t.cover_intact(A) and t.cover_intact(B), "başta sağlam")
	eq(t.cover_events, [] as Array[Dictionary])
	t.observe({A: _with(_view(false), {"staff_side": true, "seen_by": "Owner"}), B: _view(false)}, 0.1)
	is_false(t.cover_intact(A), "personel tarafında görüldü: bozuldu")
	eq(t.cover_events, [{"peer": A, "reason": &"staff", "by": &"Owner"}] as Array[Dictionary], "yeni bozulma olayı + gören")
	eq(t.cover_seen_by[A], &"Owner")
	t.cover_events.clear()
	t.observe({A: _view(false), B: _view(false)}, 0.1)
	is_false(t.cover_intact(A), "müşteri tarafına dönse de geri gelmez")
	eq(t.cover_events, [] as Array[Dictionary], "ikinci kez olay yok")
	eq(t.cover_broken[A], &"staff", "ilk neden kalır")


## US-045 (GB-08 option A, KR-038): a breaking state counts only while an NPC sees the player; taking the bag is no event breaker;
## the police witness check stays unconditional.
func test_cover_breaks_only_when_seen() -> void:
	var t := HeistRules.Tracker.new()
	for state: Dictionary in [{"sprinting": true}, {"staff_side": true}, {"holding_cash": true}, {"move_mode": HeistRules.MOVE_SNEAK},
			{"masked": true}, {"seen_by": ""}]:
		t.observe({A: _with(_view(false), state)}, 0.1)
	t.observe({A: _view(false, 450)}, 0.1)
	is_true(t.cover_intact(A), "kimse görmedi: koşu/personel/kasa/sızma/maske/çanta örtüyü bozmaz")
	t.note_bag(A)
	is_true(t.cover_intact(A), "çanta alma olayı bozmaz (çanta görülürse bozar)")
	t.observe({A: _with(_view(false, 450), {"seen_by": "Civilian2"})}, 0.1)
	is_false(t.cover_intact(A), "çantayla görüldü")
	eq([t.cover_broken[A], t.cover_seen_by[A]], [&"bag", &"Civilian2"])
	t.observe({B: _with(_view(false), {"seen_by": "Owner"})}, 0.1)
	is_true(t.cover_intact(B), "görülse de bozan durum yok: sağlam")
	var views: Dictionary = {B: _with(_view(false), {"staff_side": true})}
	t.arrive_police(views)
	is_true(t.is_caught(B), "polis: personel tarafındaki görülmemiş de yakalanır (koşulsuz)")


func test_association_window_and_radius() -> void:
	is_true(HeistRules.associates(0.0, 30.0, true, 10.0, 48.0))
	is_true(HeistRules.associates(9.9, 48.0, true, 10.0, 48.0), "pencere içinde, sınırda")
	is_false(HeistRules.associates(10.1, 30.0, true, 10.0, 48.0), "10 sn geçti")
	is_false(HeistRules.associates(-1.0, 30.0, true, 10.0, 48.0), "arkadaş hiç işaretlenmedi")
	is_false(HeistRules.associates(2.0, 49.0, true, 10.0, 48.0), "48 px dışı")
	is_false(HeistRules.associates(2.0, 30.0, false, 10.0, 48.0), "gözlemci görmedi")
	var t := HeistRules.Tracker.new()
	is_false(t.associate(A, B, 30.0, true, 48.0), "B işaretsiz: ilişkilendirme yok")
	t.mark_target(B)
	t.observe({A: _view(false), B: _view(false)}, 4.0)
	is_true(t.associate(A, B, 30.0, true, 48.0), "4 sn önce bağırılan arkadaşla görüldü")
	is_false(t.cover_intact(A))
	eq(t.cover_broken[A], &"seen_with")
	t = HeistRules.Tracker.new()
	t.mark_target(B)
	t.observe({A: _view(false), B: _view(false)}, 10.5)
	is_false(t.associate(A, B, 30.0, true, 48.0), "10 sn penceresi doldu")
	is_true(t.cover_intact(A))
	t.cover_mark_window_s = 12.0
	is_true(t.associate(A, B, 30.0, true, 48.0), "pencere veriden (Game verir)")


func test_police_releases_witness_with_intact_cover() -> void:
	var t := HeistRules.Tracker.new()
	t.add_cash(B, 150)
	var views: Dictionary = {A: _view(false), B: _view(true), C: _with(_view(false), {"staff_side": true})}
	t.observe(views, 0.5)
	t.set_alert(5)
	t.arrive_police(views)
	is_false(t.is_caught(A), "örtüsü sağlam, ganimetsiz: yakalanmaz")
	is_true(t.is_released(A), "tanık sorgusuyla serbest")
	is_true(t.is_caught(C), "örtüsü bozuk: yakalandı")
	eq(t.evaluate(views), &"win", "serbest bırakılan bölge koşuluna girmez: B ganimetle bölgede → kazanma")
	var r: Dictionary = t.build_result(&"win", views, _roster(), 100, 0)
	eq(r["outcome"], &"hot")
	var a: Dictionary = r["players"][str(A)]
	eq([a["escaped"], a["caught"], a["witness_released"], a["recognized"], a["bail"], a["loot"]],
		[false, false, true, 1, 0, 0], "kaçmadı, yakalanmadı, tanındı, kefalet yok")
	eq(r["players"][str(C)]["bail"], 100)
	eq(r["bail"], 100, "yalnız yakalanan kefalet öder")
	eq(r["payout"], HeistRules.payout(150, 70), "kalanın kısmi ödemesi (yakalananın payı 0; tanık yakalanmadı)")
	eq(r["heat"], HeistRules.HEAT_HOT + 2, "tanık başına ekip ısısı +2")


func test_police_witness_branches() -> void:
	is_true(HeistRules.witness_released(true, 0, false))
	is_false(HeistRules.witness_released(false, 0, false), "örtü bozuk")
	is_false(HeistRules.witness_released(true, 150, false), "ganimet taşıyor")
	is_false(HeistRules.witness_released(true, 0, true), "tutuluyor")
	var t := HeistRules.Tracker.new()
	t.add_cash(A, 150)  # emptied the register and returned to the customer side: cash on them
	var views: Dictionary = {A: _view(false), B: _view(false, 0, false, true)}
	t.arrive_police(views)
	is_true(t.is_caught(A), "nakit taşıyan yakalanır")
	is_true(t.is_caught(B), "tutulan yakalanır")
	eq(t.evaluate(views), &"police")
	t = HeistRules.Tracker.new()
	views = {A: _view(false), B: _view(false)}
	t.arrive_police(views)
	eq(t.evaluate(views), &"police", "herkes serbest: iş polisle biter (kimse kaçmadı)")
	var r: Dictionary = t.build_result(&"police", views, {A: _roster()[A], B: _roster()[B]}, 100, 0)
	eq(r["bail"], 0, "tanıkların kefaleti yok")
	eq(r["heat"], HeistRules.HEAT_POLICE + 4)
	t.witness_heat = 3
	eq(t.build_result(&"police", views, {A: _roster()[A]})["heat"], HeistRules.HEAT_POLICE + 3, "ısı veriden")


func test_strategy_class_rules() -> void:
	var mixed: Dictionary = {"1": true, "2": false}
	eq(HeistRules.strategy_class(3, true, 2, mixed), &"gürültü", "uyarı ≥ 3 önce")
	eq(HeistRules.strategy_class(2, true, 2, mixed), &"arka_kapı")
	eq(HeistRules.strategy_class(1, false, 1, mixed), &"sosyal")
	eq(HeistRules.strategy_class(0, false, 0, mixed), &"örtü", "biri müşteri gibi, öteki iş başında")
	eq(HeistRules.strategy_class(0, false, 0, {"1": false, "2": false}), &"zaman", "herkesin örtüsü bozuk")
	eq(HeistRules.strategy_class(0, false, 0, {"1": true}), &"zaman", "kimse bozmadı")
	eq(HeistRules.strategy_class(0, false, 0, {}), &"zaman")


func test_strategy_dump_fields() -> void:
	var t := HeistRules.Tracker.new()
	t.observe({A: _view(false), B: _view(false)}, 2.0)
	t.add_cash(A, 150)
	t.note_interaction(A)
	t.observe({A: _with(_view(false), {"staff_side": true, "seen_by": "Owner"}), B: _view(false)}, 3.0)
	t.note_bag(A)
	t.note_interaction(A)
	t.note_interaction(0)  # NPC: not counted
	var s: Dictionary = t.build_result(&"win", {A: _view(true, 450), B: _view(true)},
		{A: _roster()[A], B: _roster()[B]})["strategy"]
	eq(s, {
		"class": &"örtü", "interactions": 2, "max_alert": 0, "back_door_used": false,
		"cover_intact": {str(A): false, str(B): true},
		"register_emptied_at_s": 2.0, "cash_bag_taken_at_s": 5.0,
	})
	t.back_door_used = true
	eq(t.strategy({A: {}})["class"], &"arka_kapı")
	eq(HeistRules.Tracker.new().strategy({})["register_emptied_at_s"], -1.0, "olmayan an −1")
