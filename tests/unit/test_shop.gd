extends TestCase
## US-045 shop v0 in the level (single process = host, fixed step; KR-036/KR-037/KR-038): shelf item points built from `ShopItem<n>`
## markers on store_a and store_b (AC6), take -> pay -> drop with the hand and the counter (AC1 rules), the cola drop LISTEN within 1 s
## and its "again?" charge to the dropper (AC2), "Para yetmiyor" when the team cash is short (AC3), the damacana order: window ~14 s,
## carry speed, on the counter, paid in time = no return cost / not paid = +20 at 20 s, no "arka" in its texts (AC3), heavy product hides
## register and bag prompts.

const DT := 1.0 / 60.0
const STORE_B := "res://levels/store_b.tscn"
## Customer side of the counter (store_a QueueSpot2 / counter front, as in test_store_tools).
const COUNTER_FRONT := Vector2(528, 336)
const ORDER_TEXT_KEYS: Array[String] = ["INTERACT_COUNTER_SEND", "EVENT_OWNER_SENT", "OWNER_SENT", "OWNER_ORDER_READY",
	"OWNER_ORDER_UNPAID", "INTERACT_TAKE_WATER", "INTERACT_ITEM_DROP_WATER", "INTERACT_COUNTER_PAY"]


func _counter(stage: NpcStage) -> ShopCounter:
	return stage.level.props_root().get_node(^"Counter") as ShopCounter


func _events(o: StoreOwner) -> Array:
	var out: Array = []
	for kind: StringName in StoreOwner.EVENT_KINDS:
		o.connect(kind, func(peer_id: int) -> void: out.append([kind, peer_id]))
	return out


## Steps the stage with the counter's host step (its physics process is not part of NpcStage.run).
func _run(stage: NpcStage, seconds: float, probe: Callable = Callable()) -> void:
	var counter: ShopCounter = _counter(stage)
	stage.run(seconds, func() -> void:
		counter._physics_process(DT)
		if probe.is_valid():
			probe.call())


func _set_cash(value: int) -> int:
	var before: int = Game.team_cash()
	Game.add_team_cash(value - before)
	return before


func _texts() -> Dictionary:
	var rows: Dictionary = {}
	var file := FileAccess.open("res://i18n/texts.csv", FileAccess.READ)
	while file != null and not file.eof_reached():
		var cols: PackedStringArray = file.get_csv_line()
		if cols.size() >= 3:
			rows[cols[0]] = cols
	return rows


# --- AC6: item points from markers, two maps ---

func test_item_points_come_from_markers_on_both_maps() -> void:
	for path: String in [NpcStage.STORE, STORE_B]:
		var stage := NpcStage.new(self)
		await stage.enter(path)
		var counter: ShopCounter = _counter(stage)
		var points: Array[ShopItemPoint] = counter.items()
		var markers: Array[Node2D] = stage.level.marker_sequence(ShopRules.ITEM_MARKER_PREFIX)
		eq(markers.size(), 2, "%s: ShopItem1..2 işaretleri" % path)
		eq(points.size(), markers.size(), "%s: işaret başına bir ürün noktası" % path)
		for i: int in mini(points.size(), markers.size()):
			eq(points[i].name, StringName("ShopItem%d" % (i + 1)), "ad işaretten")
			near(points[i].global_position, markers[i].global_position, 0.5, "%s ShopItem%d konumu işaretten" % [path, i + 1])
		if points.size() == 2:
			eq([points[0].product_id, points[1].product_id], [&"bread", &"cola"], "ürün ayar tablosundan (shop_items)")
			eq(points[0].take_interactable().action_key, "INTERACT_TAKE_BREAD")
			eq(points[1].take_interactable().hold_time, 0.5, "raftan alma 0,5 sn")
		stage.leave()


# --- AC1 rules: take, pay, drop ---

func test_take_bread_pay_at_counter_and_drop() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	var bread_point: ShopItemPoint = counter.items()[0]
	var p: Player = stage.player(2, bread_point.global_position + Vector2(0, 4))
	var hand: PlayerHand = p.hand()
	var cash_before: int = _set_cash(50)
	_run(stage, 2.0)
	o.senses().step(0.0)
	is_true(o.senses().loiter_time(2) > 1.0, "dükkânda oyalanma birikti")
	bread_point.take_interactable().host_start(2, 1)
	_run(stage, 0.6)
	eq(hand.item, &"bread", "ekmek elde")
	is_false(hand.paid, "ödenmedi")
	is_true(o.senses().loiter_time(2) < 0.7, "ekmek oyalanmayı sıfırladı (%.2f)" % o.senses().loiter_time(2))
	is_false(bread_point.take_interactable().can_start(2, p.global_position, p.interaction_tags()), "elde en çok 1 ürün")
	is_true(p.interaction_tags().has(PlayerHand.TAG_HOLDING))
	is_true(p.interaction_tags().has(HeistRules.FREE_HANDS_TAG), "ekmek hafif: çanta alınabilir")
	eq(counter.shop_taken, 1)
	p.position = COUNTER_FRONT
	_run(stage, 0.2)
	eq(counter.action_for(2), ShopRules.CounterAction.PAY_HELD, "tezgâhta: öde")
	eq(counter.price_for(2), 5)
	counter.buy_interactable().host_start(2, 2)
	_run(stage, 2.1)
	is_true(hand.paid, "ekmek ödendi")
	eq(Game.team_cash(), 45, "5 ekip nakdinden")
	eq(counter.shop_paid, 1)
	eq(o.brain().player_serves, 1, "ödeme = SERVİS akışı")
	eq(counter.action_for(2), ShopRules.CounterAction.BUY, "ödenmiş ürün elde: E sakız")
	hand.drop_interactable().host_start(2, 3)
	eq(hand.item, &"", "Q bırak")
	eq(counter.shop_dropped, 1)
	eq(counter.shop_dump()["held"], {"2": ""}, "shop dökümü")
	_set_cash(cash_before)
	stage.leave()


## KR-038: taking the bag drops the product in the hand (bread silently; the glass bottle would break).
func test_bag_take_drops_held_product() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var bag: Bag = stage.level.props_root().get_node(^"Bag") as Bag
	var p: Player = stage.player(2, bag.global_position + Vector2(0, -8))
	p.hand().host_give(&"bread")
	stage.run(DT)
	var take: Interactable = bag.get_node(^"Take") as Interactable
	is_true(take.can_start(2, p.global_position, p.interaction_tags()), "hafif ürünle çanta alınabilir")
	take.host_start(2, 1)
	stage.run(2.1)
	eq(bag.carrier, 2, "çanta alındı")
	eq(p.hand().item, &"", "ürün düştü")
	eq(_counter(stage).shop_dropped, 1)
	stage.leave()


func test_drop_component_is_self_only() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var a: Player = stage.player(2, COUNTER_FRONT)
	var b: Player = stage.player(3, COUNTER_FRONT + Vector2(4, 0))
	a.hand().host_give(&"bread")
	stage.run(DT)
	var drop: Interactable = a.hand().drop_interactable()
	drop.host_start(3, 1)
	eq(a.hand().item, &"bread", "başkası bırakamaz")
	eq(int((drop.stats()["rejected"] as Dictionary).get("self", 0)), 1, "red sebebi self")
	drop.host_start(2, 2)
	eq(a.hand().item, &"", "sahibi bırakır")
	is_false(b.hand().is_holding())
	stage.leave()


# --- AC2: cola drop ---

func test_cola_drop_owner_listens_within_one_second_and_again_charges_dropper() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	var p: Player = stage.player(2, COUNTER_FRONT)
	_run(stage, 1.0)
	is_true(o.global_position.distance_to(stage.marker(&"ClerkSpot")) < 8.0, "sahip tezgâhta")
	p.hand().host_give(&"cola")
	var heard: Array[float] = [-1.0]
	var t: Array[float] = [0.0]
	p.hand().drop_interactable().host_start(2, 1)
	_run(stage, 1.0, func() -> void:
		t[0] += DT
		if heard[0] < 0.0 and o.agenda().current_interrupt() == Agenda.Interrupt.LISTEN:
			heard[0] = t[0])
	is_true(heard[0] >= 0.0 and heard[0] <= 1.0, "≤ 1 sn'de DİNLE (%.2f)" % heard[0])
	has(events, [&"owner_listen", 0])
	eq(o.brain().distractions.count, 1, "dikkat dağıtma sayıldı")
	_run(stage, 8.0)
	var before: float = o.suspicion().value_of(2)
	p.position = COUNTER_FRONT + Vector2(0, 24)
	p.hand().host_give(&"cola")
	p.hand().drop_interactable().host_start(2, 2)
	has(events, [&"owner_again", 2], "ikinci: bırakan kabahatli (Yine mi?!)")
	is_true(o.suspicion().value_of(2) >= before + 29.0, "+30 bırakana (%.1f -> %.1f)" % [before, o.suspicion().value_of(2)])
	stage.leave()


# --- AC3: money ---

func test_short_cash_is_refused_with_balloon() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	var events: Array = _events(o)
	stage.player(2, COUNTER_FRONT)
	var cash_before: int = _set_cash(2)
	_run(stage, 0.5)
	counter.buy_interactable().host_start(2, 1)
	_run(stage, 2.1)
	has(events, [&"owner_no_money", 2], "Para yetmiyor")
	eq(counter.purchases, 0, "satış yok")
	eq(o.brain().player_serves, 0, "servis yok")
	eq(Game.team_cash(), 2, "nakit aynı")
	_set_cash(3)
	_run(stage, 0.5)
	counter.buy_interactable().host_start(2, 2)
	_run(stage, 2.1)
	eq(counter.purchases, 1, "3 ile sakız alınır")
	eq(Game.team_cash(), 0)
	is_true(_texts().has("OWNER_NO_MONEY"), "metin")
	_set_cash(cash_before)
	stage.leave()


# --- AC3: damacana order ---

## Sends, then steps until the damacana is on the counter (READY); returns the measured window (s; -1 if it never came back).
func _order_and_wait(stage: NpcStage, peer_id: int) -> float:
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	counter.send_interactable().host_start(peer_id, 1)
	_run(stage, 2.1)
	if not is_true(counter.sent_used, "Damacana iste kabul"):
		return -1.0
	eq(counter.order, ShopRules.Order.FETCH)
	var carry_speed: Array[float] = [0.0]
	for i: int in roundi(40.0 / DT):
		var before: Vector2 = o.global_position
		_run(stage, DT)
		if o.order_phase() == ShopRules.Order.CARRY:
			carry_speed[0] = maxf(carry_speed[0], o.global_position.distance_to(before) / DT)
		if counter.order == ShopRules.Order.READY:
			break
	var tuning: OwnerTuning = o.brain().owner_tuning
	is_true(carry_speed[0] > 0.0 and carry_speed[0] <= tuning.walk_speed * tuning.carry_speed_factor + 1.0,
		"taşırken ×0,6 (en çok %.0f px/sn)" % carry_speed[0])
	return o.brain().sent_windows[0] if o.brain().sent_windows.size() == 1 else -1.0


func test_damacana_window_paid_in_time_costs_nothing() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	var events: Array = _events(o)
	var p: Player = stage.player(2, COUNTER_FRONT)
	var cash_before: int = _set_cash(50)
	_run(stage, 1.0)
	var window: float = await _order_and_wait(stage, 2)
	# Fable estimate ~14 s assumed an 8-tile walk; store_a ClerkSpot->BackroomSpot is shorter (measured ~12.4 s; + return_check_sec 1 s).
	is_true(window >= 11.5 and window <= 16.0, "kasa penceresi ≈ 12-14 sn (%.1f)" % window)
	has(events, [&"owner_sent", 2], "Hemen getiriyorum!")
	has(events, [&"owner_order_ready", 2], "Buyrun, 40 lira.")
	eq(o.balloon_args(&"owner_order_ready"), {"price": 40})
	eq(counter.action_for(2), ShopRules.CounterAction.PAY_ORDER, "isteyen: Öde 40")
	eq(counter.action_for(3), ShopRules.CounterAction.BUY, "başkası: sakız")
	is_true(counter.buy_interactable().offered_to(2) and not counter.pickup_interactable().offered_to(2))
	_run(stage, 1.5)  # return check
	o.apply_suspicion(2, 25.0)
	counter.buy_interactable().host_start(2, 2)
	_run(stage, 2.1)
	eq(counter.order, ShopRules.Order.PAID, "damacana ödendi")
	eq(Game.team_cash(), 10, "40 ekip nakdinden")
	eq(o.suspicion().value_of(2), 0.0, "ödeyene şüphe 0")
	is_false(o.brain().order_clock.running(), "bedel saati durdu")
	is_true(counter.pickup_interactable().offered_to(2) and not counter.buy_interactable().offered_to(2), "E: Damacanayı al")
	counter.pickup_interactable().host_start(2, 3)
	_run(stage, 1.1)
	eq(p.hand().item, &"water", "damacana elde")
	is_true(p.hand().paid)
	eq(counter.order, ShopRules.Order.TAKEN)
	var tags: Dictionary = p.interaction_tags()
	is_true(tags.has(PlayerHand.TAG_HEAVY) and not tags.has(HeistRules.FREE_HANDS_TAG), "ağır: eller dolu")
	var register: Interactable = stage.level.props_root().get_node(^"Register/Interactable") as Interactable
	var bag: Interactable = stage.level.props_root().get_node(^"Bag/Take") as Interactable
	if register != null:
		is_false(register.can_start(2, register.global_position + Vector2(24, 0), tags), "kasa istemi gizli")
	if bag != null:
		is_false(bag.can_start(2, bag.global_position, tags), "çanta istemi gizli")
	eq(p.hand().drop_interactable().action_key, "INTERACT_ITEM_DROP_WATER", "Q: Damacanayı bırak")
	_run(stage, 22.0)
	eq(o.brain().send_costs.size(), 0, "zamanında ödendi: +20 yok")
	_set_cash(cash_before)
	stage.leave()


func test_damacana_unpaid_costs_twenty_at_twenty_seconds() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	stage.player(2, COUNTER_FRONT)
	_run(stage, 1.0)
	var window: float = await _order_and_wait(stage, 2)
	is_true(window > 0.0, "döndü")
	var pay_sec: float = StoreToolsTuning.load_default().order_pay_sec
	_run(stage, pay_sec - 0.5)
	eq(o.brain().send_costs.size(), 0, "19,5 sn: henüz bedel yok")
	_run(stage, 1.0)
	eq(o.brain().send_costs, [{"peer": 2, "amount": 20.0}], "20. sn: +20 isteyene")
	has(events, [&"owner_order_unpaid", 2], "Nereye gitti bu?")
	stage.leave()


func test_damacana_shout_cancels_cost() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	stage.player(2, COUNTER_FRONT)
	_run(stage, 1.0)
	await _order_and_wait(stage, 2)
	is_true(o.brain().order_clock.running())
	o.brain().shout(2, false)
	is_false(o.brain().order_clock.running(), "bağırış: bedel iptal")
	stage.leave()


func test_order_texts_never_name_the_back_room() -> void:
	var rows: Dictionary = _texts()
	for key: String in ORDER_TEXT_KEYS:
		if is_true(rows.has(key), "metin " + key):
			var cols: PackedStringArray = rows[key]
			is_true(not cols[1].strip_edges().is_empty() and not cols[2].strip_edges().is_empty(), key + " tr+en")
			is_false(cols[1].to_lower().contains("arka") or cols[2].to_lower().contains("back"), key + ": arka oda geçmez")
	eq((rows["OWNER_ORDER_READY"] as PackedStringArray)[1].format({"price": 40}), "Buyrun, 40 lira.")
	eq((rows["OWNER_SENT"] as PackedStringArray)[1], "Hemen getiriyorum!")
	eq((rows["EVENT_OWNER_SENT"] as PackedStringArray)[1], "Damacana istendi.")
	for kind: StringName in [&"owner_order_ready", &"owner_order_unpaid", &"owner_no_money"]:
		has(StoreOwner.EVENT_KINDS, kind, "olay kanalı " + kind)
		has(NpcVisual.BALLOON_KEYS, kind, "balon " + kind)
