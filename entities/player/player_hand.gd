class_name PlayerHand
extends Node2D
## Product in the player's hand (US-045, KR-038 "gerçek alışveriş v0"; S2, S7). `Status/Hand` under the player: the Status subtree is
## host-authoritative (PlayerStatus sets authority 1), so this state changes only on the host and replicates via its own
## MultiplayerSynchronizer (on change, reliable): `item` (ShopProduct id, &"" = empty hand) and `paid`. At most one product; the shelf
## item point / the counter give it (`host_give`), the counter marks it paid (`host_mark_paid`), the bag pickup drops it
## (`host_drop`, Bag) and the player drops it with Q ("Bırak"): the `Drop` Interactable is the actor's own tool (`self_only`, instant,
## enabled while holding; only this player sees it). Dropping follows the product: noise `drop_noise_px` of `drop_kind` at the player's
## latest host-known position with this player as the source (the cola breaks: 160 px, a distraction the owner LISTENs to and charges
## to the dropper, KR-038), otherwise silent; a dropped product is gone in v0 (no world prop).
## Player reads `tags()` (`holding`, `heavy` -> S7 forbidden tags: a damacana hides register and bag prompts) and `is_heavy()` (walk
## only). Shop counters (group ShopCounter.GROUP) are told about takes/drops (`note_shop`) for the "shop" dump. A held product never
## breaks cover (KR-038). Visual: `HeldItemVisual` reads `item`.

## On every peer: the held product changed (replicated).
signal changed(item: StringName, paid: bool)

const SYNC_NAME := "HandSync"
const DROP_RANGE := 24.0
const TAG_HOLDING := &"holding"
const TAG_HEAVY := &"heavy"
const DROP_KEY_DEFAULT := "INTERACT_ITEM_DROP"

## Replicated state (host writes).
var item: StringName = &"":
	set = _set_item
var paid: bool = false:
	set = _set_paid

@onready var _drop: Interactable = $Drop


func _ready() -> void:
	_drop.input_action = &"intimidate"
	_drop.hold_time = 0.0
	_drop.interact_range = DROP_RANGE
	_drop.innocent = true
	_drop.self_only = true
	_drop.completed.connect(func(_peer_id: int) -> void: host_drop())
	add_child(_make_sync())
	_apply()


## Held product definition (null if the hand is empty).
func product() -> ShopProduct:
	return ShopProduct.of(item)


func is_holding() -> bool:
	return not item.is_empty()


## Whether the held product is heavy (damacana: walk only, register/bag prompts hidden).
func is_heavy() -> bool:
	var p: ShopProduct = product()
	return p != null and p.heavy


## Interaction tags (S7) the player adds: `holding` with a product, `heavy` with a heavy one.
func tags() -> Dictionary:
	var out: Dictionary = {}
	if is_holding():
		out[TAG_HOLDING] = 1
		if is_heavy():
			out[TAG_HEAVY] = 1
	return out


func drop_interactable() -> Interactable:
	return _drop


## Host only: puts `product_id` into the empty hand (`is_paid` for the ordered product taken after paying). False if not applied.
func host_give(product_id: StringName, is_paid: bool = false) -> bool:
	if not _is_host() or is_holding() or ShopProduct.of(product_id) == null:
		return false
	paid = is_paid
	item = product_id
	_note(&"taken")
	return true


## Host only: the held product was paid at the counter.
func host_mark_paid() -> bool:
	if not _is_host() or not is_holding() or paid:
		return false
	paid = true
	return true


## Host only: drops the held product at the player's feet (Q, bag pickup). Noise per product (S8; the dropper is the source). False if
## the hand was empty.
func host_drop() -> bool:
	if not _is_host() or not is_holding():
		return false
	var p: ShopProduct = product()
	item = &""
	paid = false
	_note(&"dropped")
	if p != null and p.drop_noise_px > 0.0:
		NoiseBus.emit_noise(_actor_position(), p.drop_noise_px, p.drop_kind, _peer())
	return true


## Dump fields (S6 "shop" held map): "<item>" / "<item>:paid", "" if empty.
func dump_value() -> String:
	if not is_holding():
		return ""
	return "%s:paid" % item if paid else String(item)


func _note(kind: StringName) -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(ShopCounter.GROUP):
		if node.has_method(&"note_shop"):
			node.call(&"note_shop", kind, _peer(), item)


func _set_item(value: StringName) -> void:
	if value == item:
		return
	item = value
	if is_node_ready():
		_apply()
	changed.emit(item, paid)


func _set_paid(value: bool) -> void:
	if value == paid:
		return
	paid = value
	changed.emit(item, paid)


## On every peer: the Q line follows the replicated hand (enabled while holding; product's drop text).
func _apply() -> void:
	if _drop == null:
		return
	_drop.enabled = is_holding()
	var p: ShopProduct = product()
	_drop.action_key = p.drop_key if p != null and not p.drop_key.is_empty() else DROP_KEY_DEFAULT


## Player (owner of this hand): Status's parent.
func _player() -> Node2D:
	var status: Node = get_parent()
	return status.get_parent() as Node2D if status != null else null


func _peer() -> int:
	var p: Node = _player()
	return p.get_multiplayer_authority() if p != null else 0


func _actor_position() -> Vector2:
	var p: Node2D = _player()
	if p == null:
		return global_position
	if p.has_method(&"interaction_position"):
		var at: Variant = p.call(&"interaction_position")
		if at is Vector2:
			return at
	return p.global_position


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:paid", ".:item"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.replication_config = config
	return sync


static func _is_host() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
