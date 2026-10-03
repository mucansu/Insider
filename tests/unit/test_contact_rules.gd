extends TestCase
## US-037 (KR-027): node-free contact/shove rules (core/contact_rules.gd) with the numbers of data/npc/contact_tuning.tres: shove cone
## +-60 deg, sprint-only heading, chaser back sector, counter n (10 s window, cap 3), calm cost (30 x n / 15 x n, 0 when hot), NPC response
## (24 px over 0.25 s, 0.8 s stagger, 1 s re-shove, chaser 4 s immunity), client prediction (x0.5 calm overlap, x0.7 for 0.2 s after a
## shove) and the lean offset.

const DT := 1.0 / 60.0


func _p() -> ContactRules.Params:
	return ContactTuning.load_default().rules_params()


func test_tuning_matches_kr027() -> void:
	# AC6: every number in the data file, none in code.
	var p: ContactRules.Params = _p()
	eq(p.contact_px, 24.0)
	eq(p.calm_max_alert, 1)
	eq(p.calm_speed_factor, 0.5)
	eq(p.lean_px, 8.0)
	eq(p.push_half_angle_deg, 60.0)
	eq(p.slide_px, 24.0)
	eq(p.slide_sec, 0.25)
	eq(p.stagger_sec, 0.8)
	eq(p.repush_sec, 1.0)
	eq(p.pusher_slow_sec, 0.2)
	eq(p.pusher_speed_factor, 0.7)
	eq(p.push_window_sec, 10.0)
	eq(p.push_count_cap, 3)
	eq(p.pushed_suspicion, 30.0)
	eq(p.observer_suspicion, 15.0)
	eq(p.chaser_stagger_sec, 0.8)
	eq(p.chaser_immune_sec, 4.0)


func test_calm_is_alert_one_or_below() -> void:
	var p: ContactRules.Params = _p()
	is_true(ContactRules.is_calm(p, 0))
	is_true(ContactRules.is_calm(p, 1), "uyarı 1 hâlâ sakin")
	is_false(ContactRules.is_calm(p, 2), "uyarı 2 kızışmış")
	is_false(ContactRules.is_calm(p, 5))


func test_overlap_is_strictly_below_contact() -> void:
	var p: ContactRules.Params = _p()
	is_true(ContactRules.overlaps(p, Vector2.ZERO, Vector2(23.9, 0)))
	is_false(ContactRules.overlaps(p, Vector2.ZERO, Vector2(24.0, 0)), "< 24 px")
	is_true(ContactRules.overlaps(p, Vector2.ZERO, Vector2(30.0, 0), 8.0), "kızışmış host payı")


func test_push_heading_only_when_sprinting_and_moving() -> void:
	var p: ContactRules.Params = _p()
	eq(ContactRules.push_heading(p, false, 140.0, Vector2.RIGHT), Vector2.ZERO, "yürüyüş itmez")
	eq(ContactRules.push_heading(p, true, 5.0, Vector2.RIGHT), Vector2.ZERO, "koşu tuşu basılı ama duruyor")
	near(ContactRules.push_heading(p, true, 220.0, Vector2(3, 4)), Vector2(0.6, 0.8), 0.0001, "birim yön")
	eq(ContactRules.push_heading(p, true, 220.0, Vector2.ZERO), Vector2.ZERO)


func test_push_cone_is_plus_minus_60() -> void:
	var p: ContactRules.Params = _p()
	var at := Vector2(100, 100)
	for deg: float in [0.0, 30.0, -59.0, 59.9]:
		is_true(ContactRules.in_front(p, at, Vector2.RIGHT, at + Vector2.from_angle(deg_to_rad(deg)) * 20.0),
			"%.1f° önde" % deg)
	for deg: float in [61.0, -61.0, 90.0, 180.0]:
		is_false(ContactRules.in_front(p, at, Vector2.RIGHT, at + Vector2.from_angle(deg_to_rad(deg)) * 20.0),
			"%.1f° koni dışı" % deg)
	is_true(ContactRules.in_front(p, at, Vector2.RIGHT, at), "tam üst üste: itme")
	is_false(ContactRules.in_front(p, at, Vector2.ZERO, at + Vector2.RIGHT * 10.0), "yön yoksa itme yok")


func test_back_contact_sector() -> void:
	var p: ContactRules.Params = _p()
	var npc := Vector2(50, 50)
	var face := Vector2.LEFT
	is_true(ContactRules.from_behind(p, npc, face, npc + Vector2(16, 0)), "tam arkası")
	is_true(ContactRules.from_behind(p, npc, face, npc + Vector2(16, 12)), "arka yarı düzlem")
	is_false(ContactRules.from_behind(p, npc, face, npc + Vector2(0, 16)), "tam yan arka sayılmaz")
	is_false(ContactRules.from_behind(p, npc, face, npc + Vector2(-16, 0)), "önü")
	is_false(ContactRules.from_behind(p, npc, Vector2.ZERO, npc + Vector2(16, 0)), "yön bilinmiyorsa arka yok")


func test_counter_window_and_cap() -> void:
	var p: ContactRules.Params = _p()
	var h := ContactRules.PushHistory.new()
	var costs: Array[float] = []
	for i: int in 4:
		h.add(2)
		costs.append(ContactRules.pushed_cost(p, ContactRules.push_count(p, h.count(2)), true))
		h.step(1.0, p.push_window_sec)
	eq(costs, [30.0, 60.0, 90.0, 90.0] as Array[float], "n = 1, 2, 3, tavan 3")
	h.add(3)
	eq(h.count(3), 1, "sayaç oyuncu başına")
	h.step(6.5, p.push_window_sec)
	eq(h.count(2), 3, "10 sn'den eski ilk itme düştü (yaşlar 10,5 / 9,5 / 8,5 / 7,5)")
	h.step(3.0, p.push_window_sec)
	eq(h.count(2), 0)
	eq(ContactRules.push_count(p, 0), 1, "itmenin kendisi en az 1 sayılır")


func test_calm_cost_and_hot_free() -> void:
	var p: ContactRules.Params = _p()
	eq(ContactRules.pushed_cost(p, 2, true), 60.0)
	eq(ContactRules.observer_cost(p, 2, true), 30.0)
	eq(ContactRules.observer_cost(p, 3, true), 45.0)
	eq(ContactRules.pushed_cost(p, 3, false), 0.0, "kızışmış: bedel yok")
	eq(ContactRules.observer_cost(p, 3, false), 0.0)


func test_npc_response_slide_stagger_cooldown() -> void:
	var p: ContactRules.Params = _p()
	var s := ContactRules.NpcState.new()
	is_true(s.can_be_pushed())
	s.start(p, Vector2.UP, p.stagger_sec, 0.0)
	is_false(s.can_be_pushed(), "1 sn yeniden itme yok")
	var moved := Vector2.ZERO
	var t: float = 0.0
	var stagger_end: float = -1.0
	var free_at: float = -1.0
	while t < 1.5:
		moved += s.step(DT) * DT
		t += DT
		if stagger_end < 0.0 and not s.is_staggering():
			stagger_end = t
		if free_at < 0.0 and s.can_be_pushed():
			free_at = t
	near(moved, Vector2(0, -24), DT * 96.0 + 0.01, "24 px / 0,25 sn kayar")
	near(stagger_end, 0.8, DT + 0.001, "0,8 sn sendeler")
	near(free_at, 1.0, DT + 0.001, "1 sn sonra yeniden itilebilir")


func test_chaser_immunity() -> void:
	var p: ContactRules.Params = _p()
	var s := ContactRules.NpcState.new()
	s.start(p, Vector2.LEFT, p.chaser_stagger_sec, p.chaser_immune_sec)
	var t: float = 0.0
	while not s.can_be_pushed() and t < 10.0:
		s.step(DT)
		t += DT
	near(t, 4.0, DT + 0.001, "4 sn itilmeye bağışık")


func test_slide_only_response_keeps_brain() -> void:
	var s := ContactRules.NpcState.new()
	s.start(_p(), Vector2.RIGHT, 0.0, 0.0)
	s.step(DT)
	is_true(s.is_sliding(), "kurtarma itmesi: kayar")
	is_false(s.is_staggering(), "sendelemez (beyin kendi SENDELE'sinde)")


func test_predictor_slowdowns() -> void:
	var p: ContactRules.Params = _p()
	var c := ContactRules.Predictor.new()
	eq(c.speed_factor(p, false), 1.0)
	eq(c.speed_factor(p, true), 0.5, "sakin temas x0,5")
	is_true(c.can_push(7))
	c.note_push(p, 7, p.repush_sec)
	is_false(c.can_push(7), "aynı NPC tekrar tahmin edilmez")
	eq(c.speed_factor(p, true), 0.7, "iten x0,7")
	var t: float = 0.0
	while c.speed_factor(p, false) < 1.0 and t < 1.0:
		c.step(DT)
		t += DT
	near(t, 0.2, DT + 0.001, "0,2 sn")
	eq(c.speed_factor(p, true), 0.5, "itme bitince temas yavaşlaması")
	for i: int in roundi(0.85 / DT):
		c.step(DT)
	is_true(c.can_push(7), "1 sn sonra yeniden")
	c.note_cooldown(9, 4.0)
	is_false(c.can_push(9), "host olayı: bağışıklık")
	eq(c.predicted, 1)


func test_lean_offset() -> void:
	var p: ContactRules.Params = _p()
	near(ContactRules.lean_offset(p, Vector2(100, 100), Vector2(90, 100)), Vector2(8, 0), 0.0001, "8 px uzağa eğilir")
	eq(ContactRules.lean_offset(p, Vector2(100, 100), Vector2(60, 100)), Vector2.ZERO, "temas yoksa eğilmez")
