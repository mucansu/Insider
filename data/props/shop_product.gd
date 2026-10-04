class_name ShopProduct
extends Resource
## Shop product (US-045, KR-038 "gerçek alışveriş v0"; mimari.md S10 tuning-file pattern): `data/props/products/<id>.tres`, id = file name.
## A product is taken from a shelf item point (`ShopItem<n>` marker -> StoreToolsTuning.shop_items) or ordered at the counter (damacana,
## StoreToolsTuning.order_product), held in the hand (PlayerHand, at most one), paid at the counter (E "Öde N", the owner's service flow)
## and dropped with Q ("Bırak"). Rules are node-free in `ShopRules` (core/shop_rules.gd); these files are the single source of numbers and
## the per-product effects, script defaults are neutral. Only the id travels over the network, never the definition.

const DIR := "res://data/props/products/"

## i18n keys (S9): take prompt on the shelf ("Ekmek al"), drop prompt on the Q line ("Bırak" / "Damacanayı bırak").
@export var take_key: String = ""
@export var drop_key: String = ""
## Price (paid from team cash at the counter; ShopRules.can_afford).
@export_range(0, 10000) var price: int = 0
## Hold time of taking it from the shelf / the counter (s).
@export_range(0.0, 10.0, 0.05, "suffix:s") var take_sec: float = 0.0
## Dropping it (Q, or a bag pickup) makes this much noise (px; 0 = silent) of kind `drop_kind`; `breaks` = the item is gone after a drop.
@export_range(0.0, 2048.0, 1.0, "suffix:px") var drop_noise_px: float = 0.0
@export var drop_kind: StringName = &""
@export var breaks: bool = false
## Bread (KR-038): taking it resets the owner's loiter counter for that player (once per product and player).
@export var resets_loiter: bool = false
## Heavy (damacana): the carrier is locked to walking and register/bag prompts are hidden until it is dropped.
@export var heavy: bool = false

static var _cache: Dictionary = {}


## id = file name (S10); empty on an unsaved definition.
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())


## `data/props/products/<id>.tres` (cached per process); null (no error) for an empty id, null + error for an unknown one.
static func of(product_id: StringName) -> ShopProduct:
	if product_id.is_empty():
		return null
	if not _cache.has(product_id):
		var path: String = "%s%s.tres" % [DIR, product_id]
		var res: ShopProduct = load(path) as ShopProduct if ResourceLoader.exists(path) else null
		if res == null:
			push_error("ShopProduct: bilinmeyen ürün '%s'" % product_id)
		_cache[product_id] = res
	return _cache[product_id] as ShopProduct
