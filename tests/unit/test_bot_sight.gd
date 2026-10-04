extends TestCase
## IS-058b: bot brain fair sight (core/bot_rules.gd) - `+omni` suffix parsing, `Sighting` memory and ageing, window / back-room /
## counter / owner-back conditions on an unseen owner (last sighting + age, UNSEEN_OPEN_S, MEMORY_STALE_S), and a window Mind flow
## that only sees the owner leave.

const REGISTER := Vector2(560, 368)
const STAND := Vector2(592, 368)
const OUTSIDE := Vector2(368, 528)
const ESCAPE := Vector2(864, 576)
const SHELVES := Vector2(144, 176)


## Owner at the counter, seen; every spot known; the bot at `pos`.
func _view(t: float, pos: Vector2 = OUTSIDE) -> BotRules.View:
	var v := BotRules.View.new()
	v.t = t
	v.pos = pos
	v.owner_present = true
	v.owner_pos = STAND
	v.owner_facing = Vector2.LEFT
	v.owner_task = &"counter"
	v.register_pos = REGISTER
	v.spots = {BotRules.SPOT_REGISTER: STAND, BotRules.SPOT_OUTSIDE: OUTSIDE, BotRules.SPOT_ESCAPE: ESCAPE}
	v.bag_present = true
	v.bag_pos = Vector2(496, 240)
	return v


## Unseen owner whose last sighting was `age` s ago at `at` on `task`.
func _unseen(age: float, at: Vector2, task: StringName) -> BotRules.View:
	var v: BotRules.View = _view(10.0)
	v.owner_seen = false
	v.owner_age = age
	v.owner_pos = at
	v.owner_task = task
	return v


func test_parse_omni_suffix() -> void:
	var p: Dictionary = BotRules.parse_strategy("Window+Omni")
	eq([p["base"], p["bag"], p["omni"], p["valid"]], ["window", false, true, true])
	p = BotRules.parse_strategy("team+omni+bag")
	eq([p["base"], p["bag"], p["omni"], p["valid"]], ["team", true, true, true], "ek sırası serbest")
	is_true(BotRules.is_valid_strategy("rush+bag+omni"))
	is_false(BotRules.parse_strategy("window")["omni"], "varsayılan adil görüş")
	is_false(BotRules.is_valid_strategy("window+omni+omni"), "tekrar eden ek")
	is_false(BotRules.is_valid_strategy("window+xray"), "bilinmeyen ek")
	is_false(BotRules.is_valid_strategy("omni"))
	is_true(BotRules.Mind.new("buy+omni", 1).omni)
	is_false(BotRules.Mind.new("buy", 1).omni)


func test_sighting_memory_and_age() -> void:
	var m := BotRules.Sighting.new()
	is_false(m.known)
	eq(m.age(5.0), INF, "hiç görülmedi")
	var v := BotRules.View.new()
	m.fill(v, 5.0, false)
	is_false(v.owner_seen)
	eq(v.owner_age, INF)
	eq(v.owner_pos, Vector2.INF, "konum bilinmiyor")
	m.observe(6.0, SHELVES, Vector2.UP, 0, &"restock")
	m.fill(v, 6.0, true)
	is_true(v.owner_seen)
	eq(v.owner_age, 0.0)
	eq([v.owner_pos, v.owner_facing, v.owner_task], [SHELVES, Vector2.UP, &"restock"])
	m.fill(v, 9.5, false)
	is_false(v.owner_seen, "görmüyor: son görülen")
	eq(v.owner_age, 3.5, "yaş")
	eq(v.owner_pos, SHELVES)
	m.forget()
	eq(m.age(10.0), INF, "yeni koşu: hafıza silinir")


func test_window_open_on_unseen_owner() -> void:
	is_false(BotRules.window_open(_unseen(INF, Vector2.INF, &"")), "hiç görülmeyen sahip: bilinmez, pencere yok")
	is_false(BotRules.window_open(_unseen(1.0, SHELVES, &"restock")), "yeni kayboldu (< 3 sn)")
	is_true(BotRules.window_open(_unseen(BotRules.UNSEEN_OPEN_S + 0.1, SHELVES, &"restock")), "uzak görevde, 3 sn görünmedi: fırsat")
	is_true(BotRules.window_open(_unseen(5.0, Vector2(560, 300), &"backroom")), "arka odaya gitti (tezgâha yakın kayboldu)")
	is_false(BotRules.window_open(_unseen(BotRules.MEMORY_STALE_S + 1.0, SHELVES, &"restock")), "eski görülme: bilinmez")
	is_false(BotRules.window_open(_unseen(5.0, STAND, &"counter")), "son görüldüğünde tezgâhtaydı")
	is_false(BotRules.window_open(_unseen(5.0, SHELVES, &"counter")), "tezgâha dönüyordu")
	is_true(BotRules.window_open(_unseen(5.0, SHELVES, &"")), "görev bilinmiyor ama uzaktaydı")
	is_false(BotRules.window_open(_unseen(5.0, Vector2(560, 300), &"")), "görev bilinmiyor, yakındaydı")
	var reacting: BotRules.View = _unseen(5.0, SHELVES, &"restock")
	reacting.owner_state = 3
	is_false(BotRules.window_open(reacting), "son görüldüğünde tepki veriyordu")
	var shouted: BotRules.View = _unseen(5.0, SHELVES, &"restock")
	shouted.owner_shouted = true
	is_false(BotRules.window_open(shouted), "bağırma duyulur")
	var seen: BotRules.View = _view(0.0)
	seen.owner_pos = SHELVES
	seen.owner_task = &"restock"
	is_true(BotRules.window_open(seen), "görülüyorsa canlı kural (bekleme yok)")


func test_bag_counter_and_back_on_unseen_owner() -> void:
	is_true(BotRules.bag_window_open(_unseen(4.0, SHELVES, &"restock")), "raflarda kayboldu: arka oda boş")
	is_false(BotRules.bag_window_open(_unseen(4.0, Vector2(560, 240), &"backroom")), "arka odaya gitti")
	is_false(BotRules.bag_window_open(_unseen(1.0, SHELVES, &"restock")), "yeni kayboldu")
	is_false(BotRules.bag_window_open(_unseen(INF, Vector2.INF, &"")), "hiç görülmedi")
	is_true(BotRules.owner_at_counter(_unseen(5.0, STAND, &"counter")), "tezgâhta görülmüştü, taze")
	is_false(BotRules.owner_at_counter(_unseen(BotRules.MEMORY_STALE_S + 1.0, STAND, &"counter")), "eski")
	is_false(BotRules.owner_at_counter(_unseen(INF, Vector2.INF, &"")), "hiç görülmedi")
	is_false(BotRules.owner_back(_unseen(0.5, STAND, &"counter")), "dönüşü yalnız görerek bilir")
	is_true(BotRules.owner_back(_view(0.0)), "görülüyor ve tezgâhta")


## Window strategy, fair sight: owner seen at the counter, then seen leaving for the shelves, then out of sight; the bot waits until the
## owner was unseen UNSEEN_OPEN_S (+ reaction) and then goes to the register.
func test_window_flow_on_lost_sight() -> void:
	var mind := BotRules.Mind.new("window", 2)
	var mem := BotRules.Sighting.new()
	var t: float = 0.0
	var go_at: float = -1.0
	while t < 20.0:
		var v: BotRules.View = _view(t)
		var seen: bool = t < 2.75  # lost from sight 96 px from the register (not yet "far")
		if seen:
			var leaving: bool = t >= 2.0
			mem.observe(t, Vector2(560 - (t - 2.0) * 120.0, 368) if leaving else STAND, Vector2.LEFT, 0,
				&"restock" if leaving else &"counter")
		mem.fill(v, t, seen)
		mind.decide(v)
		if mind.phase == BotRules.Phase.GO_REGISTER and go_at < 0.0:
			go_at = t
		t += 0.1
	is_true(go_at > 0.0, "sonunda kasaya gider")
	is_true(go_at >= 2.7 + BotRules.UNSEEN_OPEN_S + BotRules.REACTION_MIN_S - 0.11,
		"görünmez olduktan en az 3 sn + tepki sonra (%.2f)" % go_at)
	is_true(go_at <= 2.8 + BotRules.UNSEEN_OPEN_S + BotRules.REACTION_MAX_S + 0.21, "geç de kalmaz (%.2f)" % go_at)


## Same views, omni: the window opens while the owner is still visible on the way (no 3 s wait).
func test_window_flow_omni_is_earlier() -> void:
	var mind := BotRules.Mind.new("window+omni", 2)
	var t: float = 0.0
	var go_at: float = -1.0
	while t < 20.0:
		var v: BotRules.View = _view(t)
		if t >= 2.0:
			v.owner_pos = Vector2(560 - (t - 2.0) * 120.0, 368)
			v.owner_task = &"restock"
		mind.decide(v)
		if mind.phase == BotRules.Phase.GO_REGISTER and go_at < 0.0:
			go_at = t
		t += 0.1
	is_true(go_at > 0.0 and go_at < 2.7 + BotRules.UNSEEN_OPEN_S, "her şeyi bilen erken gider (%.2f)" % go_at)


## Own successful SEND TO BACKROOM: the brain knows the owner left for the back room without seeing it (never seen before too).
func test_send_inference() -> void:
	var m := BotRules.Sighting.new()
	m.infer(10.0, BotRules.TASK_SENT)
	var v: BotRules.View = _view(11.0)
	m.fill(v, 11.0, false)
	is_false(BotRules.window_open(v), "yeni gönderildi (< 3 sn)")
	v = _view(13.5)
	m.fill(v, 13.5, false)
	is_true(BotRules.window_open(v), "gönderdi, 3 sn görünmedi: konum bilinmese de fırsat")
	var brain := BotBrain.new("send", 1)
	brain.set(&"_press_tag", BotRules.Phase.LURE)
	brain.set(&"_press_action", BotRules.ACTION_ALT)
	brain.call(&"_on_finished", true)
	var mem: BotRules.Sighting = brain.get(&"_owner_mem")
	eq(mem.task, BotRules.TASK_SENT, "beyin kendi ARKAYA GÖNDER'inden çıkarır")
	var buy := BotBrain.new("buy", 1)
	buy.set(&"_press_tag", BotRules.Phase.LURE)
	buy.set(&"_press_action", BotRules.ACTION_INTERACT)
	buy.call(&"_on_finished", true)
	is_false((buy.get(&"_owner_mem") as BotRules.Sighting).known, "SATIN AL bir şey söylemez")
