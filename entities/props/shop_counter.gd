class_name ShopCounter
extends Node2D
## Counter (US-010 AC1/AC2/AC4; GDD §9.3 "Player tools", KR-026; S2, S7). `Props/Counter` in the level (store_a `Counter` marker: the counter
## tile north of the register). Two Interactables, both from the customer side:
## - `Buy` (E, `interact`): BUY, `data/props/counter_buy.tres` (hold 2 s). Host: owner's `serve_player(peer)` service (US-016 SERVE flow;
##   service sec 2 `register_opened` -> US-039 discovery); if accepted, `buy_price` from team cash (free if cash is short;
##   `CivilianRules.purchase_cost`), session event `purchase` {peer}.
## - `Send` (Q, `intimidate`; gamepad X): SEND TO BACKROOM, `data/props/counter_send.tres` (hold 2 s). Host: owner's `send_to_backroom(peer)`;
##   1 per heist (`sent_used`, replicated), session event `owner_sent` {peer}.
## Visibility (from replicated state on every peer): both off without an active owner; both hidden if the owner has shouted
## (`has_shouted`, replicated); Q prompt hidden once SEND was used. Host blocker (peer-aware `start_blocker`, S7 addendum): request is
## `blocked` if the owner cannot accept now (alarm, other service, already sent). Interactions are innocent (`Interactable.innocent`:
## not tampering in the civilian multiplier table). The owner is reached only via the S4 Level API (`npcs_root`) and duck typing
## (`serve_player`, `send_to_backroom`, `can_serve_player`, `can_send`, `has_shouted`, `is_active`).
## Dump (S6 "props"): {"purchases", "paid", "sent_used", "buy", "send"}.

const BUY_DEF_PATH := "res://data/props/counter_buy.tres"
const SEND_DEF_PATH := "res://data/props/counter_send.tres"
const PURCHASE_EVENT := &"purchase"
const SENT_EVENT := &"owner_sent"

@export var buy_def: PropDef
@export var send_def: PropDef
@export var tuning: StoreToolsTuning

## Replicated state (host writes).
var sent_used: bool = false
## Host counters (dump).
var purchases: int = 0
var paid: int = 0

var _owner_node: Node = null

@onready var _buy: Interactable = $Buy
@onready var _send: Interactable = $Send


func _ready() -> void:
	if buy_def == null:
		buy_def = load(BUY_DEF_PATH) as PropDef
	if send_def == null:
		send_def = load(SEND_DEF_PATH) as PropDef
	# IS-106: global default (or the scene's) + the level's per-map overrides.
	tuning = VenueTuning.of(self, VenueTuning.STORE_TOOLS, tuning if tuning != null else StoreToolsTuning.load_default()) 		as StoreToolsTuning
	_setup(_buy, buy_def)
	_setup(_send, send_def)
	_send.input_action = &"intimidate"
	_buy.completed.connect(_on_buy)
	_send.completed.connect(_on_send)
	_buy.start_blocker = func(peer_id: int) -> bool: return not _can_buy(peer_id)
	_send.start_blocker = func(peer_id: int) -> bool: return not _can_send(peer_id)
	_refresh()
	add_to_group(PropDump.GROUP)
	PropDump.register()


func _physics_process(_delta: float) -> void:
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


func dump_state() -> Dictionary:
	return {
		"purchases": purchases,
		"paid": paid,
		"sent_used": sent_used,
		"buy": _buy.stats(),
		"send": _send.stats(),
	}


## On every peer: prompt lines from replicated state (AC1).
func _refresh() -> void:
	var o: Node = shop_owner()
	var open: bool = o != null and bool(o.call(&"is_active")) and not bool(o.call(&"has_shouted"))
	_buy.enabled = open
	_send.enabled = open and not sent_used


func _can_buy(peer_id: int) -> bool:
	var o: Node = shop_owner()
	return o != null and bool(o.call(&"can_serve_player", peer_id))


func _can_send(peer_id: int) -> bool:
	var o: Node = shop_owner()
	return not sent_used and o != null and bool(o.call(&"can_send", peer_id))


## Host only (Interactable.completed).
func _on_buy(peer_id: int) -> void:
	var o: Node = shop_owner()
	if o == null or not bool(o.call(&"serve_player", peer_id)):
		return
	purchases += 1
	var cost: int = CivilianRules.purchase_cost(Game.team_cash(), tuning.buy_price)
	if cost > 0:
		paid += cost
		Game.add_team_cash(-cost)
	Game.raise_session_event(PURCHASE_EVENT, {"peer": peer_id, "cost": cost})


## Host only (Interactable.completed).
func _on_send(peer_id: int) -> void:
	var o: Node = shop_owner()
	if sent_used or o == null or not bool(o.call(&"send_to_backroom", peer_id)):
		return
	sent_used = true
	_refresh()
	Game.raise_session_event(SENT_EVENT, {"peer": peer_id})


static func _setup(item: Interactable, def: PropDef) -> void:
	item.action_key = def.action_key
	item.hold_time = def.hold_time
	item.interact_range = def.interact_range
	item.requirement = def.requirement
	item.innocent = true
