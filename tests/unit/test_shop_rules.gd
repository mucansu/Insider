extends TestCase
## US-045 shop rules (core/shop_rules.gd, node-free; KR-036/KR-038): money check, the counter's one-tap choice per player, prices,
## taking into the hand, shelf item -> product table, order payment clock (conditional +20), product data (prices, effects).


func test_can_afford_and_prices() -> void:
	is_true(ShopRules.can_afford(50, 40), "50 >= 40")
	is_false(ShopRules.can_afford(3, 5), "3 < 5: Para yetmiyor")
	is_true(ShopRules.can_afford(-100, 0), "bedava her zaman")
	eq(ShopRules.action_price(ShopRules.CounterAction.BUY, 3, 5, 40), 3, "sakız")
	eq(ShopRules.action_price(ShopRules.CounterAction.PAY_HELD, 3, 5, 40), 5, "eldeki ürün")
	eq(ShopRules.action_price(ShopRules.CounterAction.PAY_ORDER, 3, 5, 40), 40, "damacana")
	eq(ShopRules.action_price(ShopRules.CounterAction.TAKE_ORDER, 3, 5, 40), 0, "ödenmiş damacanayı almak")


func test_counter_action_priority() -> void:
	eq(ShopRules.counter_action(&"", false, false, ShopRules.Order.NONE, true), ShopRules.CounterAction.BUY, "boş el: sakız")
	eq(ShopRules.counter_action(&"bread", false, false, ShopRules.Order.NONE, true), ShopRules.CounterAction.PAY_HELD, "ödenmemiş ekmek: öde")
	eq(ShopRules.counter_action(&"bread", true, false, ShopRules.Order.NONE, true), ShopRules.CounterAction.BUY, "ödenmiş ekmek elde: sakız")
	eq(ShopRules.counter_action(&"cola", false, true, ShopRules.Order.READY, true), ShopRules.CounterAction.PAY_HELD, "eldeki önce")
	eq(ShopRules.counter_action(&"", false, true, ShopRules.Order.READY, true), ShopRules.CounterAction.PAY_ORDER, "isteyen: damacanayı öde")
	eq(ShopRules.counter_action(&"", false, false, ShopRules.Order.READY, true), ShopRules.CounterAction.BUY, "istemeyen: sakız")
	eq(ShopRules.counter_action(&"", false, true, ShopRules.Order.CARRY, true), ShopRules.CounterAction.BUY, "tezgâhta değilken: sakız")
	eq(ShopRules.counter_action(&"", false, true, ShopRules.Order.PAID, true), ShopRules.CounterAction.TAKE_ORDER, "ödendi: al")
	eq(ShopRules.counter_action(&"", false, true, ShopRules.Order.PAID, false), ShopRules.CounterAction.NONE, "çanta elde: alamaz")
	eq(ShopRules.counter_action(&"bread", true, true, ShopRules.Order.PAID, true), ShopRules.CounterAction.NONE, "el dolu: alamaz")
	is_true(ShopRules.on_counter(ShopRules.Order.READY) and ShopRules.on_counter(ShopRules.Order.PAID), "tezgâhta: READY/PAID")
	is_false(ShopRules.on_counter(ShopRules.Order.TAKEN) or ShopRules.on_counter(ShopRules.Order.CARRY), "TAKEN/CARRY tezgâhta değil")


func test_take_and_item_table() -> void:
	is_true(ShopRules.can_take(&"", false))
	is_false(ShopRules.can_take(&"bread", false), "elde en çok 1 ürün")
	is_false(ShopRules.can_take(&"", true), "çanta elde")
	var items: Array[StringName] = [&"bread", &"cola"]
	eq(ShopRules.item_product(1, items), &"bread")
	eq(ShopRules.item_product(2, items), &"cola")
	eq(ShopRules.item_product(3, items), &"", "tabloda yok: atlanır")
	eq(ShopRules.item_product(0, items), &"")


func test_order_clock_conditional_cost() -> void:
	var clock := ShopRules.OrderClock.new()
	is_false(clock.running())
	clock.start(5, 20.0)
	var fired: int = 0
	for i: int in 19 * 10:
		if clock.step(0.1):
			fired += 1
	eq(fired, 0, "19 sn: henüz bedel yok")
	is_true(clock.running())
	for i: int in 20:
		if clock.step(0.1):
			fired += 1
	eq(fired, 1, "20. sn'de bir kez")
	is_false(clock.running())
	clock.start(5, 20.0)
	clock.step(10.0)
	clock.cancel()  # ödendi
	is_false(clock.step(20.0), "ödenince bedel yok")


func test_product_data() -> void:
	var bread: ShopProduct = ShopProduct.of(&"bread")
	var cola: ShopProduct = ShopProduct.of(&"cola")
	var water: ShopProduct = ShopProduct.of(&"water")
	if not is_true(bread != null and cola != null and water != null, "ürün dosyaları"):
		return
	eq([bread.price, cola.price, water.price], [5, 10, 40], "KR-038 fiyatları")
	is_true(bread.resets_loiter and not cola.resets_loiter, "ekmek: oyalanma sıfırlar")
	eq(cola.drop_noise_px, 160.0, "kola: 160 px")
	eq(cola.drop_kind, StoreToolsTuning.KIND_BOTTLE)
	is_true(StoreToolsTuning.DISTRACTION_KINDS.has(cola.drop_kind), "şişe kırılması dikkat dağıtma sesi")
	is_true(water.heavy and not bread.heavy, "damacana ağır")
	eq(bread.id(), &"bread")
	var tools: StoreToolsTuning = StoreToolsTuning.load_default()
	eq(tools.buy_price, 3, "sakız 3")
	eq(tools.order_product, &"water")
	eq(tools.order_pay_sec, 20.0)
	eq(HeistTuning.load_default().start_cash, 50, "harçlık 50")
	allow_errors()
	is_true(ShopProduct.of(&"konserve") == null, "konserve v0'da yok")
