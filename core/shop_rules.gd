class_name ShopRules
extends RefCounted
## Shop rules (US-045, KR-036/KR-038 "gerçek alışveriş v0" + damacana order; GDD §9.3; S2). Node-free (KR-003): the counter, the shelf
## item points, the player's hand and the owner's brain ask these and keep only state.
## - Hand: at most one product (`ShopProduct` id) held, paid or not; a held product never breaks cover (customer's goods, KR-038).
## - Counter E (`counter_action`): pay the held unpaid product > pay the ordered product (only the asker, once it is on the counter) >
##   take the paid order (asker, empty hand) > BUY (gum) - one tap, so the bot's `buy` strategy and the service hook are unchanged.
## - Money: a purchase needs the team cash (`can_afford`); short -> the owner says "Para yetmiyor" and nothing is sold (KR-038).
## - Order (damacana instead of SEND): NONE -> FETCH (owner in the back room) -> CARRY (walking back slower) -> READY (on the
##   counter) -> PAID -> TAKEN; an alarm drops it back to NONE. `OrderClock`: READY starts `order_pay_sec`; the asker paying in time
##   cancels the return cost, expiry gives it once (KR-038 conditional +20).

enum Order { NONE, FETCH, CARRY, READY, PAID, TAKEN }
enum CounterAction { NONE, BUY, PAY_HELD, PAY_ORDER, TAKE_ORDER }

const ORDER_NAMES: Array[StringName] = [&"none", &"fetch", &"carry", &"ready", &"paid", &"taken"]
const ACTION_NAMES: Array[StringName] = [&"none", &"buy", &"pay_held", &"pay_order", &"take_order"]
## S4 marker prefix of the shelf item points (`ShopItem1`, `ShopItem2` ...; KR-038, same pattern on every map).
const ITEM_MARKER_PREFIX := &"ShopItem"


## Whether the team cash covers `price` (a free item always does).
static func can_afford(cash: int, price: int) -> bool:
	return price <= 0 or cash >= price


## What the counter's E does for this player now. `held` product id in hand (&"" none) and whether it is paid; `asker` = this player
## ordered the current product; `order` = Order state; `hands_free` = no bag carried (the ordered product goes to an empty hand).
static func counter_action(held: StringName, held_paid: bool, asker: bool, order: int, hands_free: bool) -> CounterAction:
	if not held.is_empty() and not held_paid:
		return CounterAction.PAY_HELD
	if asker and order == Order.READY:
		return CounterAction.PAY_ORDER
	if asker and order == Order.PAID:
		return CounterAction.TAKE_ORDER if held.is_empty() and hands_free else CounterAction.NONE
	return CounterAction.BUY


## Price of a counter action (gum = `buy_price`; held / ordered product its own price; taking the paid order is free).
static func action_price(action: CounterAction, buy_price: int, held_price: int, order_price: int) -> int:
	match action:
		CounterAction.BUY:
			return buy_price
		CounterAction.PAY_HELD:
			return held_price
		CounterAction.PAY_ORDER:
			return order_price
	return 0


## Whether a product can be taken into the hand: empty hand and no bag (the bag needs the hands, US-012).
static func can_take(held: StringName, carrying_bag: bool) -> bool:
	return held.is_empty() and not carrying_bag


## Product of the `index`-th (1-based) shelf item point: `shop_items[index - 1]`; &"" if the map's table has no entry.
static func item_product(index: int, shop_items: Array[StringName]) -> StringName:
	return shop_items[index - 1] if index >= 1 and index <= shop_items.size() else &""


## Whether the order is waiting on the counter (drawn there; pay / take prompts).
static func on_counter(order: int) -> bool:
	return order == Order.READY or order == Order.PAID


static func order_name(order: int) -> StringName:
	return ORDER_NAMES[clampi(order, 0, ORDER_NAMES.size() - 1)]


## Payment clock of the ordered product (host; KR-038): starts when the product is on the counter; the asker paying cancels it,
## otherwise it expires once at `sec` (the return cost is given then).
class OrderClock:
	extends RefCounted
	var peer: int = 0
	var left: float = -1.0

	func start(asker: int, sec: float) -> void:
		peer = asker
		left = maxf(sec, 0.0)

	func running() -> bool:
		return left >= 0.0

	## Paid / alarm: no cost any more.
	func cancel() -> void:
		left = -1.0

	## One step; true exactly once, when the time runs out (then stopped).
	func step(delta: float) -> bool:
		if left < 0.0:
			return false
		left -= maxf(delta, 0.0)
		if left > 0.0:
			return false
		left = -1.0
		return true
