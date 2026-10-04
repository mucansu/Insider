extends TestCase
## IS-015a: node-free bot brain rules (core/bot_rules.gd) - strategy parsing and roles, window/target conditions, plans, Mind phase
## transitions on scripted views (window, send, distract, buy, team), global overrides (flee, held, caught, job over), retries, retreats,
## seed determinism, stuck detection, A* grid on the store_a layout.

const STORE := "res://levels/store_a.tscn"
const REGISTER := Vector2(560, 368)
const STAND := Vector2(592, 368)
const COUNTER_STAND := Vector2(528, 336)
const QUEUE := Vector2(528, 368)
const OUTSIDE := Vector2(368, 528)
const SHELF := Vector2(368, 208)
const ESCAPE := Vector2(864, 576)
const SPAWN := Vector2(112, 528)
## IS-101: alley staging spot (BackDoor (20,3) + (-1,-1) tile), bag (BackroomCash), back-room owner spot (BackroomSpot).
const ALLEY := Vector2(624, 80)
const BAG := Vector2(496, 240)
const BACKROOM_SPOT := Vector2(592, 176)
const BAG_ROUTE: Array = [BotRules.Phase.STAGE, BotRules.Phase.WAIT, BotRules.Phase.GO_BAG, BotRules.Phase.TAKE_BAG,
	BotRules.Phase.LEAVE, BotRules.Phase.ESCAPE]


## A view with the owner at the counter and every spot known; the bot stands at `pos`.
func _view(t: float, pos: Vector2 = SPAWN) -> BotRules.View:
	var v := BotRules.View.new()
	v.t = t
	v.pos = pos
	v.owner_present = true
	v.owner_pos = STAND
	v.owner_facing = Vector2.LEFT
	v.owner_task = &"counter"
	v.register_pos = REGISTER
	v.spots = {
		BotRules.SPOT_REGISTER: STAND, BotRules.SPOT_COUNTER: COUNTER_STAND, BotRules.SPOT_QUEUE: QUEUE,
		BotRules.SPOT_OUTSIDE: OUTSIDE, BotRules.SPOT_SHELF: SHELF, BotRules.SPOT_ESCAPE: ESCAPE,
	}
	v.shelf_left = 3
	v.bag_present = true
	v.bag_pos = BAG
	v.spots[BotRules.SPOT_BAG] = v.bag_pos
	v.spots[BotRules.SPOT_ALLEY] = ALLEY
	return v


## Owner away on the west shelves (restock) - the register window.
func _away(v: BotRules.View) -> BotRules.View:
	v.owner_pos = Vector2(144, 176)
	v.owner_task = &"restock"
	v.owner_facing = Vector2.LEFT
	return v


func _phases(plan: Array[Dictionary]) -> Array:
	var out: Array = []
	for step: Dictionary in plan:
		out.append(int(step["phase"]))
	return out


func _names(log: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Variant in log:
		out.append(str((entry as Array)[1]))
	return out


# --- strategy, role, conditions ---

func test_parse_strategy_and_bag_suffix() -> void:
	var p: Dictionary = BotRules.parse_strategy(" Window+Bag ")
	eq(p["base"], "window")
	is_true(p["bag"])
	is_true(p["valid"])
	is_true(BotRules.is_valid_strategy("team"))
	is_true(BotRules.is_valid_strategy("rush+bag"))
	is_false(BotRules.is_valid_strategy("sneaky"), "bilinmeyen strateji")
	is_false(BotRules.is_valid_strategy("+bag"))
	for s: String in BotRules.STRATEGIES:
		is_true(BotRules.is_valid_strategy(s), s)
	is_true(BotRules.is_valid_strategy("bag"), "IS-101: tek kişi çanta stratejisi")
	is_false(BotRules.is_valid_strategy("bag+bag"), "bag tabanına +bag eki anlamsız")
	is_true(BotRules.is_valid_strategy("bag+omni+human"))
	var h: Dictionary = BotRules.parse_strategy("team+human+bag")
	is_true(h["valid"])
	is_true(h["human"])
	is_true(h["bag"])
	is_false(BotRules.parse_strategy("window")["human"])
	is_false(BotRules.is_valid_strategy("window+human+human"), "tekrar eden ek")


func test_roles_by_join_slot() -> void:
	eq(BotRules.role_for("rush", 0), BotRules.Role.SOLO)
	eq(BotRules.role_for("window", 2), BotRules.Role.SOLO)
	eq(BotRules.role_for("team", 0), BotRules.Role.LURE)
	eq(BotRules.role_for("team", 1), BotRules.Role.THIEF)
	eq(BotRules.role_for("team", 2), BotRules.Role.BAGGER)
	eq(BotRules.role_for("team", 3), BotRules.Role.THIEF, "dördüncü oyuncu ikinci kasacı")


func test_window_open_rules() -> void:
	var v: BotRules.View = _view(0.0)
	is_false(BotRules.window_open(v), "sahip tezgâhta")
	is_true(BotRules.window_open(_away(_view(0.0))), "sahip raflarda")
	var near: BotRules.View = _view(0.0)
	near.owner_task = &"restock"
	near.owner_pos = REGISTER + Vector2(-100, 0)
	is_false(BotRules.window_open(near), "görev penceresi ama kasaya 128 px'ten yakın (yeni yola çıktı)")
	var shouted: BotRules.View = _away(_view(0.0))
	shouted.owner_shouted = true
	is_false(BotRules.window_open(shouted), "bağırdıysa pencere yok")
	var looking: BotRules.View = _away(_view(0.0))
	looking.owner_state = 1
	is_false(BotRules.window_open(looking), "tepki veriyor (bakıyor/soruyor)")
	var turned: BotRules.View = _view(0.0)
	turned.owner_task = &"customer"
	turned.owner_pos = REGISTER + Vector2(160, 0)
	turned.owner_facing = Vector2.RIGHT
	is_true(BotRules.window_open(turned), "uzakta ve sırtı kasaya dönük")
	turned.owner_facing = Vector2.LEFT
	is_false(BotRules.window_open(turned), "uzakta ama kasaya bakıyor")
	var empty := BotRules.View.new()
	is_true(BotRules.window_open(empty), "sahipsiz bakkal")


func test_bag_window_and_owner_at_counter() -> void:
	var v: BotRules.View = _view(0.0)
	is_true(BotRules.owner_at_counter(v))
	is_false(BotRules.bag_window_open(v), "sahip tezgâhta: arka oda kapısı 3 karo arkasında")
	v.owner_task = &"phone"
	v.owner_pos = Vector2(688, 400)
	is_true(BotRules.bag_window_open(v), "telefonda, çantaya uzak")
	is_false(BotRules.owner_at_counter(v))
	v.owner_task = &"backroom"
	v.owner_pos = Vector2(592, 176)
	is_false(BotRules.bag_window_open(v), "arka odada")
	var c: BotRules.View = _view(0.0)
	c.bag_carrier = 7
	is_true(BotRules.condition(BotRules.COND_CARRYING, c), "arkadaş taşıyor: çanta adımı atlanır")


func test_plans() -> void:
	var rush: Array[Dictionary] = BotRules.plan_for("rush", false, BotRules.Role.SOLO)
	eq(rush.size(), 3)
	eq(int(rush[0]["phase"]), BotRules.Phase.GO_REGISTER)
	eq(int(rush[1]["phase"]), BotRules.Phase.EMPTY)
	eq(int(rush[2]["phase"]), BotRules.Phase.ESCAPE)
	eq(int(rush[0]["abort_to"]), -1, "rush geri çekilmez")
	var window: Array[Dictionary] = BotRules.plan_for("window", true, BotRules.Role.SOLO)
	var phases: Array = []
	for step: Dictionary in window:
		phases.append(int(step["phase"]))
	eq(phases, [BotRules.Phase.STAGE, BotRules.Phase.WAIT, BotRules.Phase.GO_REGISTER, BotRules.Phase.EMPTY,
		BotRules.Phase.GO_BAG, BotRules.Phase.TAKE_BAG, BotRules.Phase.ESCAPE])
	eq(int(window[2]["abort_to"]), 1, "kasaya koşu bekleme adımına geri döner")
	var bagger: Array[Dictionary] = BotRules.plan_for("team", false, BotRules.Role.BAGGER)
	eq(_phases(bagger), BAG_ROUTE, "IS-101: çantacı ara sokak -> B -> çanta -> ara sokak -> kaçış")
	eq(StringName(bagger[0]["spot"]), BotRules.SPOT_ALLEY, "sahneleme ara sokakta")
	eq(StringName(bagger[1]["until"]), BotRules.COND_BACK_CLEAR)
	eq(int(bagger[2]["abort_to"]), 1, "kapı açılıp sahip arka odada görünürse ara sokağa geri çekilir")
	eq(StringName(bagger[2]["abort_if"]), BotRules.COND_OWNER_IN_BACKROOM)
	eq(StringName(bagger[4]["spot"]), BotRules.SPOT_ALLEY, "çantayla arka kapıdan çıkar")
	var lure: Array[Dictionary] = BotRules.plan_for("team", false, BotRules.Role.LURE)
	eq(StringName(lure[2]["action"]), BotRules.ACTION_ALT, "oyalayıcı Q ile arka odaya gönderir")
	eq(StringName(lure[1]["until"]), BotRules.COND_LURE_GO, "IS-101: GÖNDER kasacı hazır + çanta alındı (ya da çantacı yok)")
	eq(float(lure[1]["timeout"]), BotRules.TEAM_WAIT_S)
	eq(float(lure[1]["timeout_bag"]), BotRules.TEAM_BAG_WAIT_S, "çantacı varken daha uzun bekler")
	eq(StringName(lure[2]["skip"]), BotRules.COND_NO_SEND, "çantacı varken / çanta alındıysa GÖNDER yok")
	eq(StringName(lure[3]["spot"]), BotRules.SPOT_SHELF, "yerine raf devirme (oyalama)")
	eq(StringName(lure[3]["skip"]), BotRules.COND_NO_DISTRACT)
	eq(StringName(lure[5]["action"]), BotRules.ACTION_INTERACT)
	var lure_bag: Array[Dictionary] = BotRules.plan_for("team", true, BotRules.Role.LURE)
	is_false(_phases(lure_bag).has(BotRules.Phase.GO_BAG), "team+bag: oyalayıcı çantaya gitmez (örtüsünü korur)")
	for step: Dictionary in lure_bag:
		is_false(StringName(step["action"]) == BotRules.ACTION_ALT, "team+bag: GÖNDER yok (sahip arka odada çantayı kontrol eder)")
	var thief: Array[Dictionary] = BotRules.plan_for("team", true, BotRules.Role.THIEF)
	eq(StringName(thief[1]["until"]), BotRules.COND_THIEF_GO, "kasacı pencere + çanta alındı (kasa en son)")
	eq(_phases(thief), [BotRules.Phase.STAGE, BotRules.Phase.WAIT, BotRules.Phase.GO_REGISTER, BotRules.Phase.EMPTY,
		BotRules.Phase.GO_BAG, BotRules.Phase.TAKE_BAG, BotRules.Phase.ESCAPE], "team+bag: 2 kişide kasacı çantayı da hedefler")
	eq(StringName(thief[2]["abort_if"]), BotRules.COND_OWNER_BACK)
	eq(int(thief[4]["abort_to"]), 6, "kasadan sonra sahip arka odada görünürse çantayı bırakıp kaçar")
	eq(StringName(thief[4]["abort_if"]), BotRules.COND_OWNER_IN_BACKROOM)
	var bag: Array[Dictionary] = BotRules.plan_for("bag", false, BotRules.Role.SOLO)
	eq(_phases(bag), BAG_ROUTE, "tek kişi bag stratejisi kasaya dokunmaz")
	for base: String in BotRules.STRATEGIES:
		for role: int in BotRules.Role.size():
			var plan: Array[Dictionary] = BotRules.plan_for(base, true, role as BotRules.Role)
			eq(int(plan[plan.size() - 1]["phase"]), BotRules.Phase.ESCAPE, "her plan kaçışla biter: %s/%d" % [base, role])


# --- Mind transitions ---

func test_window_flow_to_done() -> void:
	var m := BotRules.Mind.new("window", 1)
	var i: BotRules.Intent = m.decide(_view(0.0))
	eq(m.phase, BotRules.Phase.STAGE)
	eq(i.spot, BotRules.SPOT_OUTSIDE)
	i = m.decide(_view(5.0, OUTSIDE))
	eq(m.phase, BotRules.Phase.WAIT, "dışarıda bekler")
	eq(i.look, Vector2.DOWN, "vitrine bakmaz")
	m.decide(_view(10.0, OUTSIDE))
	eq(m.phase, BotRules.Phase.WAIT, "sahip tezgâhta: beklemeye devam")
	m.decide(_away(_view(20.0, OUTSIDE)))
	eq(m.phase, BotRules.Phase.WAIT, "tepki gecikmesi")
	i = m.decide(_away(_view(21.5, OUTSIDE)))
	eq(m.phase, BotRules.Phase.GO_REGISTER)
	eq(i.spot, BotRules.SPOT_REGISTER)
	is_false(i.sprint, "örtü: yürür")
	i = m.decide(_away(_view(26.0, STAND)))
	eq(m.phase, BotRules.Phase.EMPTY)
	eq(i.action, BotRules.ACTION_INTERACT, "kasada E tutar")
	var done: BotRules.View = _away(_view(29.0, STAND))
	done.result = BotRules.RESULT_OK
	done.register_emptied = true
	i = m.decide(done)
	eq(m.phase, BotRules.Phase.ESCAPE)
	eq(i.spot, BotRules.SPOT_ESCAPE)
	eq(i.action, &"")
	var over: BotRules.View = _view(40.0, ESCAPE)
	over.heist_over = true
	m.decide(over)
	eq(m.phase, BotRules.Phase.DONE)
	is_true(m.is_done())
	eq(m.decide(_view(41.0)).spot, BotRules.SPOT_NONE, "iş bitince durur")
	eq(_names(m.phase_log), PackedStringArray(["stage", "wait", "go_register", "empty", "escape", "done"]))


func test_slot_unknown_waits_in_start() -> void:
	var m := BotRules.Mind.new("team", 1)
	var v: BotRules.View = _view(0.0)
	v.slot = -1
	eq(m.decide(v).spot, BotRules.SPOT_NONE)
	eq(m.phase, BotRules.Phase.START, "rol bilinmeden plan kurulmaz")
	v.slot = 1
	m.decide(v)
	eq(m.role, BotRules.Role.THIEF)
	eq(m.phase, BotRules.Phase.STAGE)


func test_send_flow_uses_alt_action_and_skips_when_sent() -> void:
	var m := BotRules.Mind.new("send", 2)
	m.decide(_view(0.0))
	var i: BotRules.Intent = m.decide(_view(3.0, COUNTER_STAND))
	eq(m.phase, BotRules.Phase.LURE)
	eq(i.action, BotRules.ACTION_ALT)
	var sent: BotRules.View = _view(6.0, COUNTER_STAND)
	sent.result = BotRules.RESULT_OK
	sent.send_used = true
	m.decide(sent)
	eq(m.phase, BotRules.Phase.WAIT)
	var gone: BotRules.View = _view(9.0, COUNTER_STAND)
	gone.owner_task = &"sent"
	gone.owner_pos = Vector2(592, 176)
	m.decide(gone)
	gone.t = 10.5
	var i2: BotRules.Intent = m.decide(gone)
	eq(m.phase, BotRules.Phase.GO_REGISTER, "gönderme penceresi")
	eq(i2.spot, BotRules.SPOT_REGISTER)
	var m2 := BotRules.Mind.new("send", 2)
	var already: BotRules.View = _view(0.0, COUNTER_STAND)
	already.send_used = true
	m2.decide(_view(0.0))
	m2.decide(already)
	is_false(_names(m2.phase_log).has("lure"), "gönderme kullanılmışsa atlanır")


func test_distract_topples_when_owner_at_counter() -> void:
	var m := BotRules.Mind.new("distract", 3)
	m.decide(_view(0.0))
	var away: BotRules.View = _away(_view(4.0, SHELF))
	m.decide(away)
	eq(m.phase, BotRules.Phase.WAIT)
	away.t = 8.0
	m.decide(away)
	eq(m.phase, BotRules.Phase.WAIT, "sahip tezgâhta değil: devirmez")
	m.decide(_view(9.0, SHELF))
	var i: BotRules.Intent = m.decide(_view(10.5, SHELF))
	eq(m.phase, BotRules.Phase.LURE)
	eq(i.action, BotRules.ACTION_INTERACT)
	var ok: BotRules.View = _view(10.6, SHELF)
	ok.result = BotRules.RESULT_OK
	i = m.decide(ok)
	eq(m.phase, BotRules.Phase.STAGE, "devirdikten sonra sıra noktasına")
	eq(i.spot, BotRules.SPOT_QUEUE)


func test_buy_repeats_until_window() -> void:
	var m := BotRules.Mind.new("buy", 4)
	m.decide(_view(0.0))
	m.decide(_view(3.0, COUNTER_STAND))
	eq(m.phase, BotRules.Phase.LURE)
	var ok: BotRules.View = _view(5.0, COUNTER_STAND)
	ok.result = BotRules.RESULT_OK
	m.decide(ok)
	eq(m.phase, BotRules.Phase.WAIT)
	var t: float = 5.0
	while t < 5.0 + BotRules.REBUY_MAX_S + 1.0 and m.phase == BotRules.Phase.WAIT:
		t += 0.5
		m.decide(_view(t, COUNTER_STAND))
	eq(m.phase, BotRules.Phase.LURE, "pencere gelmezse yeniden satın alır")
	between_ok(t - 5.0, BotRules.REBUY_MIN_S, BotRules.REBUY_MAX_S + 0.5)


func between_ok(value: float, lo: float, hi: float) -> void:
	is_true(value >= lo and value <= hi, "%.2f [%.2f, %.2f] içinde değil" % [value, lo, hi])


func test_team_lure_waits_for_thief_then_holds_cover() -> void:
	var m := BotRules.Mind.new("team", 5)
	var v: BotRules.View = _view(0.0)
	v.slot = 0
	m.decide(v)
	eq(m.role, BotRules.Role.LURE)
	var at: BotRules.View = _view(3.0, COUNTER_STAND)
	m.decide(at)
	eq(m.phase, BotRules.Phase.WAIT, "kasacıyı bekler")
	var ready: BotRules.View = _view(6.0, COUNTER_STAND)
	ready.team_size = 2
	ready.thief_ready = true
	m.decide(ready)
	ready.t = 7.5
	var i: BotRules.Intent = m.decide(ready)
	eq(m.phase, BotRules.Phase.LURE)
	eq(i.action, BotRules.ACTION_ALT)
	var sent: BotRules.View = _view(9.0, COUNTER_STAND)
	sent.team_size = 2
	sent.result = BotRules.RESULT_OK
	m.decide(sent)
	eq(m.phase, BotRules.Phase.WAIT)
	var away: BotRules.View = _away(_view(12.0, COUNTER_STAND))
	away.team_size = 2
	m.decide(away)
	away.t = 14.0
	m.decide(away)
	eq(m.phase, BotRules.Phase.WAIT, "takımda pencere kasacınındır; oyalayıcı müşteri gibi kalır")
	var emptied: BotRules.View = _view(20.0, COUNTER_STAND)
	emptied.team_size = 2
	emptied.register_emptied = true
	m.decide(emptied)
	emptied.t = 21.5
	var i2: BotRules.Intent = m.decide(emptied)
	eq(m.phase, BotRules.Phase.ESCAPE)
	eq(i2.spot, BotRules.SPOT_ESCAPE)
	is_false(_names(m.phase_log).has("go_register"), "atlanan adım günlüğe girmez")


func test_team_lure_acts_alone_after_timeout() -> void:
	var m := BotRules.Mind.new("team", 6)
	m.decide(_view(0.0, COUNTER_STAND))
	m.decide(_view(1.0, COUNTER_STAND))
	eq(m.phase, BotRules.Phase.WAIT)
	m.decide(_view(1.0 + BotRules.TEAM_WAIT_S + 0.1, COUNTER_STAND))
	eq(m.phase, BotRules.Phase.LURE, "tek başına da gönderir")
	eq(m.wait_timeouts, 1)


# --- IS-101: register last, bag route ---

func test_backroom_clear_rules() -> void:
	is_true(BotRules.backroom_clear(_view(0.0)), "sahip tezgâhta (çantaya 160 px): arka kapı serbest")
	var inside: BotRules.View = _view(0.0)
	inside.owner_task = &"backroom"
	inside.owner_pos = BACKROOM_SPOT
	is_false(BotRules.backroom_clear(inside), "sahip arka odada")
	is_true(BotRules.condition(BotRules.COND_OWNER_IN_BACKROOM, inside), "görülüyor: koşu geri çekilir")
	var sent: BotRules.View = _view(0.0)
	sent.owner_task = &"sent"
	is_false(BotRules.backroom_clear(sent), "arkaya gönderildi (yolda)")
	var near: BotRules.View = _view(0.0)
	near.owner_state = 1
	near.owner_pos = BAG + Vector2(40, 0)
	is_false(BotRules.backroom_clear(near), "tepki verirken çantanın yanında")
	var shouted: BotRules.View = _view(0.0)
	shouted.owner_shouted = true
	is_false(BotRules.backroom_clear(shouted), "bağırdıysa gitmez")
	var mem: BotRules.View = _view(0.0)
	mem.owner_seen = false
	mem.owner_age = 5.0
	mem.owner_task = &"backroom"
	mem.owner_pos = BACKROOM_SPOT
	is_false(BotRules.backroom_clear(mem), "taze anı: arka odadaydı")
	is_false(BotRules.condition(BotRules.COND_OWNER_IN_BACKROOM, mem), "görmeden geri çekilmez")
	mem.owner_age = BotRules.MEMORY_STALE_S + 0.1
	is_true(BotRules.backroom_clear(mem), "bayat anı: bakmaya gider (açılan kapı gösterir)")
	var never := BotRules.View.new()
	never.owner_present = true
	never.owner_seen = false
	never.owner_age = INF
	is_true(BotRules.backroom_clear(never), "hiç görülmedi: bakmaya gider")
	is_true(BotRules.backroom_clear(BotRules.View.new()), "sahipsiz bakkal")


func test_team_go_conditions() -> void:
	var v: BotRules.View = _away(_view(0.0))
	v.thief_ready = true
	v.team_size = 2
	is_true(BotRules.condition(BotRules.COND_LURE_GO, v), "2 kişi: çantacı yok, kasacı hazır yeter")
	is_true(BotRules.condition(BotRules.COND_THIEF_GO, v), "2 kişi: pencere yeter")
	v.team_size = 3
	v.bagger_present = true
	is_false(BotRules.condition(BotRules.COND_LURE_GO, v), "3 kişi: çanta yerde, GÖNDER yok")
	is_false(BotRules.condition(BotRules.COND_THIEF_GO, v), "3 kişi: çanta yerde, kasa en son")
	v.bag_carrier = 9
	is_true(BotRules.condition(BotRules.COND_LURE_GO, v), "çanta alındı")
	is_true(BotRules.condition(BotRules.COND_THIEF_GO, v))
	v.thief_ready = false
	is_false(BotRules.condition(BotRules.COND_LURE_GO, v), "kasacı sırada değil")
	var left: BotRules.View = _away(_view(0.0))
	left.team_size = 2
	left.bagger_present = true
	is_false(BotRules.condition(BotRules.COND_THIEF_GO, left), "biri ayrıldı ama çantacı (yuva 2) duruyor: çantayı bekler")
	var solo: BotRules.View = _view(0.0)
	solo.thief_ready = true
	is_false(BotRules.condition(BotRules.COND_LURE_GO, solo), "tek kişi: kasacı yok")


func test_team_lure_waits_for_bag_with_bagger() -> void:
	var m := BotRules.Mind.new("team", 22)
	var v: BotRules.View = _view(0.0, COUNTER_STAND)
	v.team_size = 3
	v.bagger_present = true
	v.thief_ready = true
	m.decide(v)
	eq(m.phase, BotRules.Phase.WAIT)
	v.t = BotRules.TEAM_WAIT_S + 2.0
	m.decide(v)
	eq(m.phase, BotRules.Phase.WAIT, "çanta yerde: çantacıyı TEAM_WAIT_S'den uzun bekler")
	var taken: BotRules.View = _view(v.t + 0.5, COUNTER_STAND)
	taken.team_size = 3
	taken.bagger_present = true
	taken.thief_ready = true
	taken.bag_carrier = 9
	m.decide(taken)
	taken.t += 1.5
	var i: BotRules.Intent = m.decide(taken)
	eq(m.phase, BotRules.Phase.STAGE, "çanta alındı: GÖNDER değil raf devirmeye")
	eq(i.spot, BotRules.SPOT_SHELF)
	eq(m.wait_timeouts, 0)
	var at_shelf: BotRules.View = _view(taken.t + 4.0, SHELF)
	at_shelf.team_size = 3
	at_shelf.bagger_present = true
	at_shelf.thief_ready = true
	at_shelf.bag_carrier = 9
	m.decide(at_shelf)
	at_shelf.t += 1.5
	i = m.decide(at_shelf)
	eq(m.phase, BotRules.Phase.LURE, "sahip tezgâhta: rafı devirir")
	eq(i.action, BotRules.ACTION_INTERACT)
	at_shelf.result = BotRules.RESULT_OK
	at_shelf.t += 0.5
	i = m.decide(at_shelf)
	eq(m.phase, BotRules.Phase.WAIT, "sonra müşteri gibi bekler (kasa boşalana dek)")
	eq(i.spot, BotRules.SPOT_COUNTER)
	var late := BotRules.Mind.new("team", 23)
	var w: BotRules.View = _view(0.0, COUNTER_STAND)
	w.team_size = 3
	w.bagger_present = true
	late.decide(w)
	w.t = BotRules.TEAM_BAG_WAIT_S + 0.1
	late.decide(w)
	eq(late.phase, BotRules.Phase.STAGE, "çantacı gelmezse TEAM_BAG_WAIT_S sonra yine oyalar")
	eq(late.wait_timeouts, 1)
	var duo := BotRules.Mind.new("team", 27)
	var d: BotRules.View = _view(0.0, COUNTER_STAND)
	d.team_size = 2
	d.thief_ready = true
	duo.decide(d)
	d.t = 1.5
	var di: BotRules.Intent = duo.decide(d)
	eq(duo.phase, BotRules.Phase.LURE, "2 kişi, çanta işte değil: GÖNDER (bugünkü davranış)")
	eq(di.action, BotRules.ACTION_ALT)
	d.send_used = true
	d.result = BotRules.RESULT_OK
	d.t = 2.0
	duo.decide(d)
	eq(duo.phase, BotRules.Phase.WAIT, "GÖNDER sonrası raf adımları atlanır")


func test_team_thief_takes_register_last() -> void:
	var m := BotRules.Mind.new("team", 24)
	var v: BotRules.View = _away(_view(0.0, QUEUE))
	v.slot = 1
	v.team_size = 3
	v.bagger_present = true
	m.decide(v)
	eq(m.role, BotRules.Role.THIEF)
	v.t = 3.0
	m.decide(v)
	eq(m.phase, BotRules.Phase.WAIT, "pencere açık ama çanta yerde: kasa en son")
	var taken: BotRules.View = _away(_view(4.0, QUEUE))
	taken.slot = 1
	taken.team_size = 3
	taken.bagger_present = true
	taken.bag_carrier = 9
	m.decide(taken)
	taken.t = 5.5
	m.decide(taken)
	eq(m.phase, BotRules.Phase.GO_REGISTER, "çanta alındı + pencere: kasa")
	var duo := BotRules.Mind.new("team", 25)
	var d: BotRules.View = _away(_view(0.0, QUEUE))
	d.slot = 1
	d.team_size = 2
	duo.decide(d)
	d.t = 1.5
	duo.decide(d)
	eq(duo.phase, BotRules.Phase.GO_REGISTER, "2 kişi (çantacı yok): bugünkü davranış")


func test_bag_route_flow_and_backroom_retreat() -> void:
	var m := BotRules.Mind.new("bag", 21)
	var i: BotRules.Intent = m.decide(_view(0.0))
	eq(m.role, BotRules.Role.SOLO)
	eq(m.phase, BotRules.Phase.STAGE)
	eq(i.spot, BotRules.SPOT_ALLEY, "önce ara sokak")
	var inside: BotRules.View = _view(4.0, ALLEY)
	inside.owner_seen = false
	inside.owner_age = 2.0
	inside.owner_task = &"backroom"
	inside.owner_pos = BACKROOM_SPOT
	m.decide(inside)
	inside.t = 6.0
	m.decide(inside)
	eq(m.phase, BotRules.Phase.WAIT, "sahip arka odada (taze anı): ara sokakta bekler")
	var clear: BotRules.View = _view(8.0, ALLEY)
	m.decide(clear)
	clear.t = 9.5
	i = m.decide(clear)
	eq(m.phase, BotRules.Phase.GO_BAG)
	eq(i.spot, BotRules.SPOT_BAG)
	var peek: BotRules.View = _view(11.0, Vector2(656, 144))
	peek.owner_task = &"backroom"
	peek.owner_pos = BACKROOM_SPOT
	m.decide(peek)
	eq(m.phase, BotRules.Phase.WAIT, "açık kapıdan sahip arka odada görüldü: geri çekilir")
	eq(m.retreats, 1)
	var stale: BotRules.View = _view(40.0, ALLEY)
	stale.owner_seen = false
	stale.owner_age = BotRules.MEMORY_STALE_S + 1.0
	stale.owner_task = &"backroom"
	stale.owner_pos = BACKROOM_SPOT
	m.decide(stale)
	stale.t = 41.5
	m.decide(stale)
	eq(m.phase, BotRules.Phase.GO_BAG, "anı bayatladı: yeniden bakmaya gider")
	i = m.decide(_view(45.0, BAG))
	eq(m.phase, BotRules.Phase.TAKE_BAG)
	eq(i.action, BotRules.ACTION_INTERACT)
	var took: BotRules.View = _view(47.0, BAG)
	took.result = BotRules.RESULT_OK
	took.carrying = true
	took.bag_carrier = 5
	took.spots.erase(BotRules.SPOT_BAG)
	i = m.decide(took)
	eq(m.phase, BotRules.Phase.LEAVE, "çantayla arka kapıdan ara sokağa")
	eq(i.spot, BotRules.SPOT_ALLEY)
	var out: BotRules.View = _view(52.0, ALLEY)
	out.carrying = true
	out.bag_carrier = 5
	i = m.decide(out)
	eq(m.phase, BotRules.Phase.ESCAPE)
	eq(i.spot, BotRules.SPOT_ESCAPE)
	var names: PackedStringArray = _names(m.phase_log)
	is_false(names.has("go_register") or names.has("empty"), "kasaya dokunmaz")
	eq(Array(names.slice(0, 3)), ["stage", "wait", "go_bag"])


func test_bag_after_register_skipped_when_owner_in_backroom() -> void:
	var m := BotRules.Mind.new("rush+bag", 28)
	var emptied: BotRules.View = _view(30.0, STAND)
	emptied.register_emptied = true
	emptied.owner_task = &"sent"
	emptied.owner_pos = BACKROOM_SPOT
	var i: BotRules.Intent = m.decide(emptied)
	eq(m.phase, BotRules.Phase.ESCAPE, "kasa boş, sahip arka odada görünüyor: çantayı bırakır, kaçar")
	eq(i.spot, BotRules.SPOT_ESCAPE)
	eq(m.retreats, 1)
	var m2 := BotRules.Mind.new("rush+bag", 29)
	var free: BotRules.View = _away(_view(30.0, STAND))
	free.register_emptied = true
	i = m2.decide(free)
	eq(m2.phase, BotRules.Phase.GO_BAG, "sahip raflarda: kasadan sonra çantaya")
	eq(i.spot, BotRules.SPOT_BAG)
	var unseen := BotRules.Mind.new("rush+bag", 30)
	var mem: BotRules.View = _view(30.0, STAND)
	mem.register_emptied = true
	mem.owner_seen = false
	mem.owner_age = 4.0
	mem.owner_task = &"sent"
	mem.owner_pos = BACKROOM_SPOT
	unseen.decide(mem)
	eq(unseen.phase, BotRules.Phase.GO_BAG, "görmeden vazgeçmez (adil görüş)")


func test_human_reaction_delay() -> void:
	var m := BotRules.Mind.new("window+human", 26)
	is_true(m.human)
	m.decide(_view(0.0))
	m.decide(_view(1.0, OUTSIDE))
	var a: BotRules.View = _away(_view(10.0, OUTSIDE))
	m.decide(a)
	a.t = 10.0 + BotRules.REACTION_HUMAN_MIN_S - 0.05
	m.decide(a)
	eq(m.phase, BotRules.Phase.WAIT, "insan gibi geç tepki (en az %.1f sn)" % BotRules.REACTION_HUMAN_MIN_S)
	a.t = 10.0 + BotRules.REACTION_HUMAN_MAX_S + 0.05
	m.decide(a)
	eq(m.phase, BotRules.Phase.GO_REGISTER)
	is_false(BotRules.Mind.new("window", 26).human)


func test_team_pull_held_mate() -> void:
	var m := BotRules.Mind.new("team", 7)
	var v: BotRules.View = _view(0.0, QUEUE)
	v.slot = 1
	m.decide(v)
	var mate: BotRules.View = _view(2.0, QUEUE)
	mate.slot = 1
	mate.mate_held_pos = QUEUE + Vector2(100, 0)
	mate.spots[BotRules.SPOT_MATE] = mate.mate_held_pos
	var i: BotRules.Intent = m.decide(mate)
	eq(m.phase, BotRules.Phase.PULL)
	eq(i.spot, BotRules.SPOT_MATE)
	eq(i.action, &"", "yanına varmadan basmaz")
	mate.pos = mate.mate_held_pos + Vector2(20, 0)
	eq(m.decide(mate).action, BotRules.ACTION_INTERACT, "yanında ÇEK")
	var far: BotRules.View = _view(3.0, QUEUE)
	far.slot = 1
	far.mate_held_pos = QUEUE + Vector2(BotRules.PULL_RANGE_PX + 50, 0)
	m.decide(far)
	is_false(m.phase == BotRules.Phase.PULL, "uzaktaki arkadaşa koşmaz")


func test_flee_on_alert_but_finish_emptying() -> void:
	var m := BotRules.Mind.new("window", 8)
	m.decide(_view(0.0))
	m.decide(_view(4.0, OUTSIDE))
	var alarm: BotRules.View = _view(6.0, OUTSIDE)
	alarm.alert = 2
	var i: BotRules.Intent = m.decide(alarm)
	eq(m.phase, BotRules.Phase.ESCAPE)
	is_true(i.sprint, "kaçarken koşar")
	var r := BotRules.Mind.new("rush", 8)
	r.decide(_view(0.0))
	r.decide(_view(4.0, STAND))
	eq(r.phase, BotRules.Phase.EMPTY)
	var busy: BotRules.View = _view(5.0, STAND)
	busy.alert = 2
	busy.interacting = true
	eq(r.decide(busy).action, BotRules.ACTION_INTERACT, "boşaltma sürerken bırakmaz")
	eq(r.phase, BotRules.Phase.EMPTY)
	busy.interacting = false
	busy.t = 6.0
	r.decide(busy)
	eq(r.phase, BotRules.Phase.ESCAPE)


func test_held_resumes_and_caught_ends() -> void:
	var m := BotRules.Mind.new("rush", 9)
	m.decide(_view(0.0))
	var held: BotRules.View = _view(1.0, Vector2(400, 400))
	held.held = true
	eq(m.decide(held).spot, BotRules.SPOT_NONE)
	eq(m.phase, BotRules.Phase.HELD)
	m.decide(_view(5.0, Vector2(400, 400)))
	eq(m.phase, BotRules.Phase.GO_REGISTER, "serbest kalınca kaldığı adıma döner")
	var caught: BotRules.View = _view(6.0)
	caught.caught = true
	m.decide(caught)
	eq(m.phase, BotRules.Phase.DONE)


func test_use_retries_then_gives_up() -> void:
	var m := BotRules.Mind.new("rush", 10)
	m.decide(_view(0.0))
	var t: float = 1.0
	m.decide(_view(t, STAND))
	eq(m.phase, BotRules.Phase.EMPTY)
	for attempt: int in BotRules.MAX_ATTEMPTS - 1:
		var fail: BotRules.View = _view(t, STAND)
		fail.result = BotRules.RESULT_FAIL
		eq(m.decide(fail).action, &"", "başarısızlık sonrası bekler (deneme %d)" % attempt)
		t += BotRules.RETRY_MAX_S + 0.1
		eq(m.decide(_view(t, STAND)).action, BotRules.ACTION_INTERACT, "sonra yeniden dener")
	var last: BotRules.View = _view(t, STAND)
	last.result = BotRules.RESULT_FAIL
	m.decide(last)
	eq(m.phase, BotRules.Phase.ESCAPE, "%d denemeden sonra vazgeçer" % BotRules.MAX_ATTEMPTS)
	eq(m.failures, BotRules.MAX_ATTEMPTS)


func test_retreat_when_owner_returns() -> void:
	var m := BotRules.Mind.new("window", 11)
	m.decide(_view(0.0))
	m.decide(_view(4.0, OUTSIDE))
	m.decide(_away(_view(10.0, OUTSIDE)))
	m.decide(_away(_view(12.0, OUTSIDE)))
	eq(m.phase, BotRules.Phase.GO_REGISTER)
	var back: BotRules.View = _view(13.0, Vector2(368, 430))
	m.decide(back)
	eq(m.phase, BotRules.Phase.WAIT, "sahip döndü, kasaya bağlanmadan geri çekilir")
	eq(m.retreats, 1)
	m.decide(_away(_view(20.0, Vector2(368, 430))))
	m.decide(_away(_view(22.0, Vector2(368, 430))))
	eq(m.phase, BotRules.Phase.GO_REGISTER)
	var committed: BotRules.View = _view(23.0, STAND + Vector2(-20, 40))
	m.decide(committed)
	eq(m.phase, BotRules.Phase.GO_REGISTER, "kasaya yakınken (COMMIT_PX) geri dönmez")


func test_same_seed_same_decisions() -> void:
	var logs: Array = []
	for seed_value: int in [42, 42, 43]:
		var m := BotRules.Mind.new("window", seed_value)
		var t: float = 0.0
		m.decide(_view(t))
		m.decide(_view(1.0, OUTSIDE))
		t = 1.0
		while t < 120.0 and not m.is_done():
			t += 0.25
			var v: BotRules.View = _view(t, OUTSIDE if m.phase == BotRules.Phase.WAIT else STAND)
			m.decide(v)
			if m.phase == BotRules.Phase.EMPTY:
				var ok: BotRules.View = _view(t, STAND)
				ok.result = BotRules.RESULT_OK
				m.decide(ok)
			if m.phase == BotRules.Phase.ESCAPE:
				var over: BotRules.View = _view(t + 1.0, ESCAPE)
				over.heist_over = true
				m.decide(over)
		logs.append(m.phase_log)
		eq(m.wait_timeouts, 1, "pencere hiç açılmazsa bekleme zaman aşımına düşer")
	eq(logs[0], logs[1], "aynı tohum + aynı strateji + aynı dünya = aynı faz günlüğü")
	ne(logs[0], logs[2], "farklı tohum farklı bekleme süresi çizer")
	var wait_end: float = float(((logs[0] as Array)[2] as Array)[0])
	between_ok(wait_end - 1.0, BotRules.WAIT_MAX_MIN_S, BotRules.WAIT_MAX_MAX_S + 0.3)


# --- stuck, path ---

func test_stuck_meter() -> void:
	var s := BotRules.StuckMeter.new()
	var t: float = 0.0
	var fired: int = 0
	for i: int in 120:
		t += 1.0 / 60.0
		if s.feed(t, 1.0 / 60.0, Vector2(100, 100), true):
			fired += 1
	eq(fired, 1, "1 sn pencere + 0,75 sn ardışık takılma = bir yeniden plan")
	near(s.total_s, BotRules.STUCK_REPLAN_S, 0.05, "pencereden sonraki süre sayılır; plan sonrası pencere yeniden başlar")
	var moving := BotRules.StuckMeter.new()
	for i: int in 120:
		is_false(moving.feed(i / 60.0, 1.0 / 60.0, Vector2(i * 2.0, 0), true), "hareket eden takılmaz")
	eq(moving.total_s, 0.0)
	var idle := BotRules.StuckMeter.new()
	for i: int in 120:
		is_false(idle.feed(i / 60.0, 1.0 / 60.0, Vector2.ZERO, false), "beklerken takılma sayılmaz")
	eq(idle.total_s, 0.0)


func test_grid_paths_on_store_layout() -> void:
	var level: Node = (load(STORE) as PackedScene).instantiate()
	var rows: PackedStringArray = (level.get_node("Tiles") as Node).get(&"rows")
	level.free()
	var grid: AStarGrid2D = BotRules.build_grid(rows)
	var spawn: Vector2i = BotRules.cell_of(SPAWN)
	var to_register: Array[Vector2i] = BotRules.find_path(grid, spawn, BotRules.cell_of(STAND))
	is_true(to_register.size() > 5, "spawn -> kasa arkası yol var")
	has(to_register, Vector2i(11, 14), "ön kapıdan girer")
	for cell: Vector2i in to_register:
		is_false(grid.is_point_solid(cell), "yol katı karodan geçmez: %s" % cell)
	var to_bag: Array[Vector2i] = BotRules.find_path(grid, BotRules.cell_of(STAND), BotRules.cell_of(Vector2(496, 240)))
	has(to_bag, Vector2i(19, 8), "arka oda iç kapısından (D) geçer")
	var escape: Array[Vector2i] = BotRules.find_path(grid, BotRules.cell_of(STAND), BotRules.cell_of(ESCAPE))
	eq(escape[escape.size() - 1], BotRules.cell_of(ESCAPE))
	eq(BotRules.nearest_open(grid, BotRules.cell_of(REGISTER)), Vector2i(16, 11), "tezgâh karosu en yakın boş karoya çekilir")
	eq(BotRules.find_path(grid, spawn, BotRules.cell_of(REGISTER)).back(), Vector2i(16, 11))
	is_true(grid.get_point_weight_scale(Vector2i(11, 14)) > 1.0, "kapı karosu ağırlıklı")
	# IS-101 bag route: alley -> back door B (20,3) -> bag, not through the inner door D (19,8); B is out of earshot of the counter.
	var alley: Vector2i = BotRules.cell_of(ALLEY)
	is_false(grid.is_point_solid(alley), "ara sokak noktası boş karo")
	var via_back: Array[Vector2i] = BotRules.find_path(grid, alley, BotRules.cell_of(BAG))
	has(via_back, Vector2i(20, 3), "arka kapıdan (B) girer")
	is_false(via_back.has(Vector2i(19, 8)), "iç kapıdan (D) geçmez")
	is_true(BotRules.cell_center(Vector2i(20, 3)).distance_to(STAND) > 160.0, "B tezgâhtan kapı sesi (160 px) menzili dışında")
	var outside: AStarGrid2D = BotRules.outside_grid(rows, Vector2i(20, 3))
	var spawn_to_alley: Array[Vector2i] = BotRules.find_path(outside, spawn, alley)
	eq(spawn_to_alley.back(), alley, "dış ızgarada ara sokağa yol var")
	is_false(spawn_to_alley.has(Vector2i(11, 14)) or spawn_to_alley.has(Vector2i(19, 8)), "ara sokağa dükkândan değil yan sokaktan gider")
	has(spawn_to_alley, Vector2i(23, 8), "yan sokak")
	var bag_to_alley: Array[Vector2i] = BotRules.find_path(outside, BotRules.cell_of(BAG), alley)
	has(bag_to_alley, Vector2i(20, 3), "çantayla arka kapıdan çıkar")
	is_false(grid.is_point_solid(Vector2i(11, 14)), "dış ızgara ana ızgarayı değiştirmez")


func test_steer() -> void:
	eq(BotRules.steer(Vector2.ZERO, Vector2(1, 0), 2.0, 24.0), Vector2.ZERO, "varış yarıçapında durur")
	near(BotRules.steer(Vector2.ZERO, Vector2(100, 0), 2.0, 24.0), Vector2(1, 0), 0.001)
	near(BotRules.steer(Vector2.ZERO, Vector2(12, 0), 2.0, 24.0), Vector2(0.5, 0), 0.001, "yaklaşırken yavaşlar")
	near(BotRules.steer(Vector2.ZERO, Vector2(4, 0), 2.0, 24.0), Vector2(0.35, 0), 0.001, "alt sınır")
	near(BotRules.steer(Vector2.ZERO, Vector2(0, 5), 0.0, 0.0), Vector2(0, 1), 0.001, "yavaşlamasız ara nokta")
