class_name ShopItemPoint
extends Node2D
## Shelf item point (US-045, KR-037/KR-038; S4, S7): built at runtime by the counter (ShopCounter) for every `ShopItem<n>` marker of the
## level - never placed by hand; the product comes from the map's tuning (`StoreToolsTuning.shop_items[n - 1]`, overridable per map), so
## a new map only needs the markers. Same name (`ShopItem<n>`) and position on every peer: RPC and sync paths match.
## `Take` Interactable (E, the product's `take_sec`, innocent): empty-handed players only (tag `free_hands`, no `holding`); host on
## completion puts the product into the player's hand (PlayerHand.host_give, unpaid) and emits `taken`. Stock is endless in v0 (shelf
## fill visual US-046). Visual: a faded product glyph (ProductMark).

## Host only: `peer_id` took a product here.
signal taken(peer_id: int, product_id: StringName)

const TAKE_RANGE := 40.0
const TAKE_NAME := "Take"

var product_id: StringName = &""
var index: int = 0

var _take: Interactable = null


## Builds the point (before entering the tree): name, product, Take component and mark.
func setup(marker_index: int, product: StringName, at: Vector2) -> void:
	index = marker_index
	product_id = product
	name = "%s%d" % [ShopRules.ITEM_MARKER_PREFIX, marker_index]
	position = at
	var def: ShopProduct = ShopProduct.of(product)
	_take = Interactable.new()
	_take.name = TAKE_NAME
	_take.action_key = def.take_key if def != null else ""
	_take.hold_time = def.take_sec if def != null else 0.0
	_take.interact_range = TAKE_RANGE
	_take.innocent = true
	var need := InteractionRequirement.new()
	need.required_tag = HeistRules.FREE_HANDS_TAG
	need.forbidden_tag = PlayerHand.TAG_HOLDING
	_take.requirement = need
	_take.completed.connect(_on_take)
	add_child(_take)
	var mark := ProductMark.new()
	mark.name = "Mark"
	mark.faded = true
	mark.product_id = product
	add_child(mark)


func take_interactable() -> Interactable:
	return _take


## Host only (Interactable.completed).
func _on_take(peer_id: int) -> void:
	var hand: PlayerHand = hand_of(self, peer_id)
	if hand != null and hand.host_give(product_id, false):
		taken.emit(peer_id, product_id)


## The hand of `peer_id`'s player (S7 actor group; null if none or a player without a hand).
static func hand_of(node: Node, peer_id: int) -> PlayerHand:
	if node == null or not node.is_inside_tree() or peer_id <= 0:
		return null
	for actor: Node in node.get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if actor.get_multiplayer_authority() == peer_id:
			var hand: PlayerHand = actor.get_node_or_null(^"Status/Hand") as PlayerHand
			if hand != null:
				return hand
	return null
