extends TestCase
## Session score store (US-051, ui/session_scores.gd): accumulation, duplicate result, reset, clean vs fast, best values,
## row limit for long sessions, map/strategy keys and the constants mirrored from HeistRules (ui/ may not depend on core/).


static func run_result(outcome: StringName, duration: float, cash_delta: int, max_alert: int = 0,
		cover: Dictionary = {"1": true, "2": true}, strategy_class: StringName = HeistRules.STRATEGY_TIME) -> Dictionary:
	return {
		"outcome": outcome, "duration_s": duration, "loot_total": 0, "payout": maxi(cash_delta, 0), "payout_ratio": 1.0,
		"players": {}, "notes": [], "max_alert": max_alert, "cash_before": 1000, "cash_after": 1000 + cash_delta,
		"strategy": {"class": strategy_class, "max_alert": max_alert, "cover_intact": cover},
	}


func test_records_runs_in_order_and_skips_duplicates() -> void:
	var s := SessionScores.new()
	eq(s.record({}), 0, "boş sonuç kaydedilmez")
	var first: Dictionary = run_result(&"clean", 61.0, 500)
	eq(s.record(first, "res://levels/store_a.tscn"), 1)
	eq(s.record(first.duplicate(true), "res://levels/store_a.tscn"), 0, "aynı sonuç (heist_finished + heist_result) bir kez")
	eq(s.record(run_result(&"caught_all", 90.0, -300), "res://levels/store_b.tscn"), 2)
	eq(s.size(), 2)
	var runs: Array[Dictionary] = s.runs()
	eq(runs[0]["level"], "res://levels/store_a.tscn")
	eq(runs[1]["outcome"], &"caught_all")
	eq(runs[1]["cash"], -300, "ödeme = ekip kasası farkı")
	is_false(runs[1]["escaped"])
	eq(s.latest()["no"], 2)


func test_reset_empties_and_restarts_numbering() -> void:
	var s := SessionScores.new()
	s.record(run_result(&"clean", 50.0, 100))
	s.record(run_result(&"hot", 40.0, 50))
	s.reset()
	eq(s.size(), 0)
	eq(s.latest(), {})
	eq(s.best()[SessionScores.BEST_FASTEST], 0)
	eq(s.record(run_result(&"clean", 50.0, 100)), 1, "yeni oturum 1'den sayar; önceki son sonuçla aynı olsa da kaydedilir")


func test_shared_store_survives_until_reset() -> void:
	SessionScores.reset_shared()
	SessionScores.shared().record(run_result(&"clean", 50.0, 100))
	eq(SessionScores.shared().size(), 1, "HUD yeniden kurulsa da (seviye yeniden yükleme) paylaşılan depo kalır")
	SessionScores.reset_shared()
	eq(SessionScores.shared().size(), 0)


func test_clean_is_cover_and_shout_not_speed() -> void:
	is_true(SessionScores.is_clean(run_result(&"clean", 300.0, 10)), "yavaş ama temiz")
	is_false(SessionScores.is_clean(run_result(&"shouted", 20.0, 10, HeistRules.ALERT_SHOUTED)), "bağırış: temiz değil")
	is_false(SessionScores.is_clean(run_result(&"clean", 20.0, 10, 0, {"1": true, "2": false})), "örtü bozuldu: temiz değil")
	is_true(SessionScores.is_clean({"outcome": &"clean", "max_alert": 1}), "örtü verisi yoksa yalnız bağırışa bakılır")
	is_false(SessionScores.is_clean({"outcome": &"clean", "strategy": {"max_alert": 3}}), "max_alert strategy'den de okunur")


func test_best_values_separate_clean_fast_and_cash() -> void:
	var s := SessionScores.new()
	s.record(run_result(&"clean", 80.0, 400))                      # 1: clean, slow
	s.record(run_result(&"shouted", 38.0, 900, 2))                 # 2: fastest, loud, most cash
	s.record(run_result(&"caught_all", 10.0, -500))                # 3: shortest but caught: not a getaway
	s.record(run_result(&"clean", 55.0, 300))                      # 4: fastest clean
	s.record(run_result(&"aborted", 5.0, 0))                       # 5: empty-handed: not a getaway
	s.record(run_result(&"clean", 55.0, 100))                      # 6: tie with 4 -> 4 stays
	var b: Dictionary = s.best()
	eq(b[SessionScores.BEST_FASTEST_CLEAN], 4, "en hızlı temiz")
	eq(b[SessionScores.BEST_FASTEST], 2, "en hızlı kaçış (temiz olmasa da)")
	eq(b[SessionScores.BEST_TOP_CASH], 2, "en çok kazanç")
	var none := SessionScores.new()
	none.record(run_result(&"caught_all", 10.0, -500))
	eq(none.best(), {SessionScores.BEST_FASTEST_CLEAN: 0, SessionScores.BEST_FASTEST: 0, SessionScores.BEST_TOP_CASH: 0},
		"kaçış ve kazanç yoksa en iyi yok")


func test_visible_rows_newest_first_bounded_with_older_bests() -> void:
	var s := SessionScores.new()
	s.record(run_result(&"clean", 30.0, 2000))   # 1: fastest clean + most cash (falls outside the last 5)
	for i: int in 9:
		s.record(run_result(&"shouted", 60.0 + i, 100, 2))
	var rows: Array[Dictionary] = s.visible_rows()
	var numbers: Array[int] = []
	for r: Dictionary in rows:
		numbers.append(int(r["no"]))
	eq(numbers, [10, 9, 8, 7, 6, 1] as Array[int], "son 5 (yeniden eskiye) + dışarıda kalan en iyi")
	is_true(rows.size() <= SessionScores.RECENT_ROWS + SessionScores.BEST_KINDS.size())
	var short := SessionScores.new()
	short.record(run_result(&"clean", 30.0, 10))
	short.record(run_result(&"clean", 40.0, 20))
	eq(short.visible_rows().size(), 2, "az koşuda tekrar satır yok")


func test_cash_change_falls_back_to_payout_minus_bail() -> void:
	eq(SessionScores.cash_change({"payout": 800, "bail": 300}), 500)
	eq(SessionScores.cash_change({"payout": 800, "cash_before": -100, "cash_after": 700}), 800)


func test_keys_and_mirrored_constants() -> void:
	eq(SessionScores.SHOUT_ALERT, HeistRules.ALERT_SHOUTED)
	eq(SessionScores.ESCAPE_OUTCOMES, [HeistRules.OUTCOME_CLEAN, HeistRules.OUTCOME_SHOUTED, HeistRules.OUTCOME_HOT] as Array[StringName])
	eq(SessionScores.map_key("res://levels/store_b.tscn"), "MAP_STORE_B")
	eq(SessionScores.map_key(""), "")
	eq(SessionScores.strategy_key(""), "")
	for strategy_class: StringName in [HeistRules.STRATEGY_TIME, HeistRules.STRATEGY_SOCIAL, HeistRules.STRATEGY_NOISE,
			HeistRules.STRATEGY_BACK_DOOR, HeistRules.STRATEGY_COVER]:
		var key: String = SessionScores.strategy_key(strategy_class)
		ne(tr(key), key, "strateji metni var: %s -> %s" % [strategy_class, key])
	eq(SessionScores.strategy_key(HeistRules.STRATEGY_BACK_DOOR), "END_STRATEGY_ARKA_KAPI")
	for level: String in ["res://levels/store_a.tscn", "res://levels/store_b.tscn", "res://levels/test_arena.tscn"]:
		var key: String = SessionScores.map_key(level)
		ne(tr(key), key, "harita adı var: " + key)
