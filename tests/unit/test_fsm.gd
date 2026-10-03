extends TestCase
## US-008 AC1/AC9: core/fsm.gd small state machine + invariant I4 (shopkeeper alert set {0->1, 1->2, 2->3, 3->5,
## 2->1, 1->0}; a jump walks through intermediate levels, no drop from 3) and brain edge tables.

const ALERT_EDGES := StoreAlert.EDGES


func test_go_respects_edges_and_records_history() -> void:
	var f := Fsm.new(0, {0: [1], 1: [0, 2]})
	var seen: Array = []
	f.changed.connect(func(a: int, b: int) -> void: seen.append([a, b]))
	is_false(f.go(2), "0→2 izinli değil")
	is_false(f.go(0), "aynı duruma geçiş yok")
	f.step(0.5)
	near(f.time_in_state, 0.5, 0.0001)
	is_true(f.go(1))
	eq(f.time_in_state, 0.0, "geçişte süre sıfırlanır")
	is_true(f.go(2))
	is_false(f.go(0), "2'den çıkış yok")
	eq(f.history, PackedInt32Array([0, 1, 2]))
	eq(seen, [[0, 1], [1, 2]])
	eq(f.history_times, PackedFloat64Array([0.0, 0.5, 0.5]), "geçmiş zaman damgalı (clock)")
	f.step(0.25)
	near(f.clock, 0.75, 0.0001)
	eq(f.history_rows([&"a", &"b", &"c"]), [[&"a", 0.0], [&"b", 0.5], [&"c", 0.5]], "döküm satırları")


func test_free_fsm_and_route() -> void:
	var free := Fsm.new(3)
	is_true(free.go(7), "kenar tablosu yoksa serbest")
	eq(free.route(1), PackedInt32Array([1]))
	var ladder := Fsm.new(0, ALERT_EDGES)
	eq(ladder.route(2), PackedInt32Array([1, 2]), "0'dan 2'ye 1 üzerinden")
	eq(ladder.route(5), PackedInt32Array([1, 2, 3, 5]), "polis yalnız 3'ten")
	eq(ladder.route(0), PackedInt32Array(), "aynı kademe")
	ladder.go(1)
	ladder.go(2)
	ladder.go(3)
	eq(ladder.route(1), PackedInt32Array(), "I4: 3'ten düşüş yok")
	eq(ladder.route(4), PackedInt32Array(), "bakkalda 4 yok")


func test_alert_ladder_invariant_i4() -> void:
	is_true(Fsm.is_valid_sequence(ALERT_EDGES, PackedInt32Array([0, 1, 2, 1, 0, 1, 2, 3, 5])))
	is_true(Fsm.is_valid_sequence(ALERT_EDGES, PackedInt32Array([0, 0, 1, 1, 0])), "yinelenen kademe geçiş değil")
	for bad: PackedInt32Array in [PackedInt32Array([0, 2]), PackedInt32Array([0, 1, 2, 3, 2]),
			PackedInt32Array([0, 1, 2, 3, 4]), PackedInt32Array([2, 0]), PackedInt32Array([0, 1, 2, 5]),
			PackedInt32Array([0, 1, 2, 3, 5, 3])]:
		is_false(Fsm.is_valid_sequence(ALERT_EDGES, bad), "I4 ihlali yakalanır: %s" % bad)


## Brain tables: the reaction chain only goes forward (AGENDA -> LOOK -> QUESTION -> SHOUT), from alarm back to the agenda only
## via SEARCH (30 s no sight); the neighbour chaser does not go to waiting after a catch, it searches.
func test_brain_edge_tables() -> void:
	var o := Fsm.new(OwnerBrain.State.AGENDA, OwnerBrain.EDGES)
	is_false(o.can(OwnerBrain.State.CHASE), "ajandadan doğrudan kovalama yok")
	is_false(o.can(OwnerBrain.State.QUESTION), "\"?\" (LOOK) atlanmaz")
	is_true(o.can(OwnerBrain.State.SHOUT), "tespit her sakin durumdan bağırır")
	var alarm_exits: Array[int] = []
	for s: int in OwnerBrain.ALARM_STATES:
		for t: int in OwnerBrain.EDGES.get(s, []):
			if not OwnerBrain.ALARM_STATES.has(t):
				alarm_exits.append(s * 10 + t)
	eq(alarm_exits, [OwnerBrain.State.SEARCH * 10 + OwnerBrain.State.AGENDA] as Array[int],
		"alarmdan çıkış yalnız SEARCH → AGENDA")
	var c := Fsm.new(ChaserBrain.State.RUN, ChaserBrain.EDGES)
	is_false(c.can(ChaserBrain.State.WAIT), "koşarken beklemeye geçmez")
	is_true(c.can(ChaserBrain.State.CHASE))
