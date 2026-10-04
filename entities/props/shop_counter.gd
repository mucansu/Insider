class_name ShopCounter
extends Node2D
## Counter and shop hub (US-010 AC1/AC2/AC4; US-045 KR-036/KR-038; GDD §9.3 "Player tools", KR-026; S2, S7). `Props/Counter` in the level
## (`Counter` marker: the counter tile next to the register). All interactions from the customer side; rules in ShopRules (core).
## - `Buy` (E, `interact`, hold 2 s, `data/props/counter_buy.tres`): one tap, per player (`peer_gate` + prompt from replicated state):
##   pay the held unpaid product ("Öde N") > pay the ordered damacana (asker, on the counter) > BUY gum ("Sakız al", `buy_price`). Host:
##   needs the team cash (ShopRules.can_afford; short -> the owner says "Para yetmiyor", nothing sold), then the owner's
##   `serve_player(peer)` service (US-016 SERVE flow; service sec 2 `register_opened` -> US-039 discovery) and the price from team cash;
##   session event `purchase` {peer, cost[, item]}; a held product becomes paid, the order becomes PAID (owner `order_paid`: no
##   return cost).
## - `Send` (Q, `intimidate`, hold 2 s, `counter_send.tres`): "Damacana iste" (KR-036; formerly SEND TO BACKROOM). Host: the owner's
##   `send_to_backroom(peer)` (fetches `order_product` from the back room); 1 per heist (`sent_used`), session event `owner_sent` {peer}
##   (HUD "Damacana istendi." - the back room is never named, KR-036). Order state (`order`, ShopRules.Order) follows the owner's
##   `order_phase()` (FETCH -> CARRY -> READY: the damacana is on the counter) and then this counter (PAID -> TAKEN); `order_peer` = asker.
## - `Pickup` (E, the product's `take_sec`): the asker takes the paid damacana into an empty hand ("Damacanayı al").
## - Shelf item points (US-045, KR-037): one `ShopItemPoint` child per level `ShopItem<n>` marker (built in `_ready` on every peer, same
##   names), product `tuning.shop_items[n - 1]`; taking bread resets the owner's loiter clock once per player.
## Visibility (from replicated state on every peer): everything off without an active owner or after the owner shouted
## (`has_shouted`); Q hidden once used. Host blockers (peer-aware `start_blocker`, S7): `blocked` if the owner cannot serve / take the
## order now. Interactions are innocent (not tampering). The owner is reached only via the S4 Level API (`npcs_root`) and duck typing.
## Dump (S6 "props"): {"purchases", "paid" (cash), "sent_used", "buy", "send", "pickup"}; "shop" provider (`--dump`): {taken, paid
## (products paid), dropped, purchases, order, order_peer, held {peer: "<item>[:paid]"}} - replicated counters, same on every peer.

const BUY_DEF_PATH := "res://data/props/counter_buy.tres"
const SEND_DEF_PATH := "res://data/props/counter_send.tres"
const PURCHASE_EVENT := &"purchase"
const SENT_EVENT := &"owner_sent"
## Group of counters (PlayerHand reports takes/drops here).
const GROUP := &"shop_counters"
const SHOP_DUMP_KEY := "shop"
const BUY_KEY := "INTERACT_COUNTER_BUY"
const PAY_KEY := "INTERACT_COUNTER_PAY"
const PICKUP_RANGE := 48.0
const ORDER_MARK_OFFSET := Vector2(0.0, -6.0)

@export var buy_def: PropDef
@export var send_def: PropDef
@export var tuning: StoreToolsTuning

## Replicated state (host writes).
var sent_used: bool = false
var order: int = ShopRules.Order.NONE
var order_peer: int = 0
var shop_taken: int = 0
var shop_paid: int = 0
var shop_dropped: int = 0
## Host counters (dump).
var purchases: int = 0
var paid: int = 0

var _owner_node: Node = null
var _items: Array[ShopItemPoint] = []
var _pickup: Interactable = null
var _order_mark: ProductMark = null
var _loiter_reset: Dictionary = {}

@onready var _buy: Interactable = $Buy
@onready var _send: Interactable = $Send


func _ready() -> void:
	if buy_def == null:
		buy_def = load(BUY_DEF_PATH) as PropDef
	if send_def == null:
		send_def = load(SEND_DEF_PATH) as PropDef
	# IS-106: global default (or the scene's) + the level's per-map overrides.
	tuning = VenueTuning.of(self, VenueTuning.STORE_TOOLS, tuning if tuning != null else StoreToolsTuning.load_default()) \
		as StoreToolsTuning
	_setup(_buy, buy_def)
	_setup(_send, send_def)
	_send.input_action = &"intimidate"
	_buy.completed.connect(_on_buy)
	_send.completed.connect(_on_send)
	_buy.start_blocker = func(peer_id: int) -> bool: return not _can_buy(peer_id)
	_send.start_blocker = func(peer_id: int) -> bool: return not _can_send(peer_id)
	_buy.peer_gate = _buy_offered
	_build_pickup()
	_build_items()
	_refresh()
	add_to_group(GROUP)
	add_to_group(PropDump.GROUP)
	PropDump.register()
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(SHOP_DUMP_KEY, shop_dump)


func _physics_process(_delta: float) -> void:
	if _is_host():
		_follow_owner_order()
	_refresh()


## Owner (node under S4 `npcs_root` offering `serve_player`); null if none.
func shop_owner() -> Node:
	if _owner_node != null and is_instance_valid(_owner_node):
		return _owner_node
	_owner_node = null
	var node: Node = get_parent()
	while node != null and not node.has_method(&"npcs_root"):
		node = node.get_parent()
	var npcs: Node = node.call(&"npcs_root") as Node if node != null else null
	if npcs != null:
		for child: Node in npcs.get_children():
			if child.has_method(&"serve_player"):
				_owner_node = child
				break
	return _owner_node


func buy_interactable() -> Interactable:
	return _buy


func send_interactable() -> Interactable:
	return _send


func pickup_interactable() -> Interactable:
	return _pickup


## Shelf item points built from the level's `ShopItem<n>` markers (in marker order).
func items() -> Array[ShopItemPoint]:
	return _items.duplicate()


## What the counter's E does for `peer_id` now (ShopRules.CounterAction; from replicated state, same on every peer).
func action_for(peer_id: int) -> int:
	var hand: PlayerHand = ShopItemPoint.hand_of(self, peer_id)
	var held: StringName = hand.item if hand != null else &""
	var held_paid: bool = hand != null and hand.paid
	return ShopRules.counter_action(held, held_paid, peer_id == order_peer, order, not _carrying_bag(peer_id))


## Price the counter's E charges `peer_id` now (0 if nothing to pay).
func price_for(peer_id: int) -> int:
	var hand: PlayerHand = ShopItemPoint.hand_of(self, peer_id)
	var held: ShopProduct = hand.product() if hand != null else null
	var ordered: ShopProduct = ShopProduct.of(tuning.order_product)
	return ShopRules.action_price(action_for(peer_id) as ShopRules.CounterAction, tuning.buy_price,
		held.price if held != null else 0, ordered.price if ordered != null else 0)


## Host only (PlayerHand): a product went into a hand (`taken`) or was dropped (`dropped`).
func note_shop(kind: StringName, _peer_id: int, _item: StringName) -> void:
	if not _is_host():
		return
	match kind:
		&"taken":
			shop_taken += 1
		&"dropped":
			shop_dropped += 1


func dump_state() -> Dictionary:
	return {
		"purchases": purchases,
		"paid": paid,
		"sent_used": sent_used,
		"buy": _buy.stats(),
		"send": _send.stats(),
		"pickup": _pickup.stats(),
	}


## "shop" dump (US-045 AC1): replicated counters and hands, comparable between peers.
func shop_dump() -> Dictionary:
	var held: Dictionary = {}
	if is_inside_tree():
		for actor: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
			var hand: PlayerHand = actor.get_node_or_null(^"Status/Hand") as PlayerHand
			if hand != null:
				held[str(actor.get_multiplayer_authority())] = hand.dump_value()
	return {
		"taken": shop_taken,
		"paid": shop_paid,
		"dropped": shop_dropped,
		"order": String(ShopRules.order_name(order)),
		"order_peer": order_peer,
		"items": _items.map(func(p: ShopItemPoint) -> String: return "%s:%s" % [p.name, p.product_id]),
		"held": held,
	}


## On every peer: prompt lines and the order mark from replicated state (AC1).
func _refresh() -> void:
	var o: Node = shop_owner()
	var open: bool = o != null and bool(o.call(&"is_active")) and not bool(o.call(&"has_shouted"))
	_buy.enabled = open
	_send.enabled = open and not sent_used
	_pickup.enabled = open and order == ShopRules.Order.PAID
	for item: ShopItemPoint in _items:
		item.take_interactable().enabled = open
	var me: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var action: int = action_for(me) if me > 0 else ShopRules.CounterAction.BUY
	if action == ShopRules.CounterAction.PAY_HELD or action == ShopRules.CounterAction.PAY_ORDER:
		_buy.action_key = tr(PAY_KEY).format({"price": price_for(me)})
	else:
		_buy.action_key = BUY_KEY
	_order_mark.visible = ShopRules.on_counter(order)


## Host: order phases before the product is on the counter come from the owner (FETCH, CARRY, READY; NONE = dropped by an alarm).
func _follow_owner_order() -> void:
	if order != ShopRules.Order.FETCH and order != ShopRules.Order.CARRY:
		return
	var o: Node = shop_owner()
	var phase: int = int(o.call(&"order_phase")) if o != null and o.has_method(&"order_phase") else ShopRules.Order.NONE
	if phase != order:
		order = phase


func _buy_offered(peer_id: int) -> bool:
	var action: int = action_for(peer_id)
	return action != ShopRules.CounterAction.NONE and action != ShopRules.CounterAction.TAKE_ORDER


func _pickup_offered(peer_id: int) -> bool:
	return action_for(peer_id) == ShopRules.CounterAction.TAKE_ORDER


func _can_buy(peer_id: int) -> bool:
	var o: Node = shop_owner()
	return o != null and bool(o.call(&"can_serve_player", peer_id))


func _can_send(peer_id: int) -> bool:
	var o: Node = shop_owner()
	return not sent_used and o != null and bool(o.call(&"can_send", peer_id))


## Host only (Interactable.completed): pay / buy for that player (action re-derived from the host's state).
func _on_buy(peer_id: int) -> void:
	var o: Node = shop_owner()
	if o == null:
		return
	var action: int = action_for(peer_id)
	if action == ShopRules.CounterAction.NONE or action == ShopRules.CounterAction.TAKE_ORDER:
		return
	var cost: int = price_for(peer_id)
	if not ShopRules.can_afford(Game.team_cash(), cost):
		if o.has_method(&"refuse_sale"):
			o.call(&"refuse_sale", peer_id)  # "Para yetmiyor" (KR-038)
		return
	if not bool(o.call(&"serve_player", peer_id)):
		return
	purchases += 1
	var data: Dictionary = {"peer": peer_id, "cost": cost}
	match action:
		ShopRules.CounterAction.PAY_HELD:
			var hand: PlayerHand = ShopItemPoint.hand_of(self, peer_id)
			if hand != null:
				data["item"] = String(hand.item)
				hand.host_mark_paid()
			shop_paid += 1
		ShopRules.CounterAction.PAY_ORDER:
			order = ShopRules.Order.PAID
			data["item"] = String(tuning.order_product)
			shop_paid += 1
			if o.has_method(&"order_paid"):
				o.call(&"order_paid", peer_id)
	if cost > 0:
		paid += cost
		Game.add_team_cash(-cost)
	Game.raise_session_event(PURCHASE_EVENT, data)


## Host only (Interactable.completed): the damacana order (KR-036).
func _on_send(peer_id: int) -> void:
	var o: Node = shop_owner()
	if sent_used or o == null or not bool(o.call(&"send_to_backroom", peer_id)):
		return
	sent_used = true
	order_peer = peer_id
	order = ShopRules.Order.FETCH
	_refresh()
	Game.raise_session_event(SENT_EVENT, {"peer": peer_id})


## Host only: the asker takes the paid order.
func _on_pickup(peer_id: int) -> void:
	if order != ShopRules.Order.PAID or peer_id != order_peer:
		return
	var hand: PlayerHand = ShopItemPoint.hand_of(self, peer_id)
	if hand != null and hand.host_give(tuning.order_product, true):
		order = ShopRules.Order.TAKEN


## Host only (ShopItemPoint.taken): bread resets the owner's loiter clock once per player and product.
func _on_item_taken(peer_id: int, product_id: StringName) -> void:
	var def: ShopProduct = ShopProduct.of(product_id)
	var key: String = "%d:%s" % [peer_id, product_id]
	if def == null or not def.resets_loiter or _loiter_reset.has(key):
		return
	_loiter_reset[key] = true
	var o: Node = shop_owner()
	if o != null and o.has_method(&"reset_loiter"):
		o.call(&"reset_loiter", peer_id)


func _build_pickup() -> void:
	var def: ShopProduct = ShopProduct.of(tuning.order_product)
	_pickup = Interactable.new()
	_pickup.name = "Pickup"
	_pickup.action_key = def.take_key if def != null else ""
	_pickup.hold_time = def.take_sec if def != null else 0.0
	_pickup.interact_range = PICKUP_RANGE
	_pickup.innocent = true
	var need := InteractionRequirement.new()
	need.required_tag = HeistRules.FREE_HANDS_TAG
	need.forbidden_tag = PlayerHand.TAG_HOLDING
	_pickup.requirement = need
	_pickup.peer_gate = _pickup_offered
	_pickup.completed.connect(_on_pickup)
	add_child(_pickup)
	_order_mark = ProductMark.new()
	_order_mark.name = "OrderMark"
	_order_mark.position = ORDER_MARK_OFFSET
	_order_mark.product_id = tuning.order_product
	_order_mark.visible = false
	add_child(_order_mark)


## One ShopItemPoint per `ShopItem<n>` marker of the level (Level API, duck typed); none outside a level.
func _build_items() -> void:
	var level: Node = get_parent()
	while level != null and not level.has_method(&"marker_sequence"):
		level = level.get_parent()
	if level == null:
		return
	var markers: Array = level.call(&"marker_sequence", ShopRules.ITEM_MARKER_PREFIX) as Array
	for i: int in markers.size():
		var marker: Node2D = markers[i] as Node2D
		var product: StringName = ShopRules.item_product(i + 1, tuning.shop_items)
		if marker == null or product.is_empty() or ShopProduct.of(product) == null:
			continue
		var point := ShopItemPoint.new()
		point.setup(i + 1, product, to_local(marker.global_position))
		point.taken.connect(_on_item_taken)
		add_child(point)
		_items.append(point)


func _carrying_bag(peer_id: int) -> bool:
	if not is_inside_tree():
		return false
	for actor: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if actor.get_multiplayer_authority() == peer_id and actor.has_method(&"is_carrying"):
			return bool(actor.call(&"is_carrying"))
	return false


func _is_host() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0


static func _setup(item: Interactable, def: PropDef) -> void:
	item.action_key = def.action_key
	item.hold_time = def.hold_time
	item.interact_range = def.interact_range
	item.requirement = def.requirement
	item.innocent = true
