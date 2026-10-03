class_name FogView
extends RefCounted
## Yerel oyuncunun görüş sisine (US-011a `FogLayer`; Level `fog_layer()`, mimari.md S3 eki) varlık görsellerinden
## erişim (US-011b). Duck typing: entities/ seviye sınıflarını bilmez (§6); sis yalnız seviyede `attach_fog` ile
## kurulmuşsa ve bir gözlemcisi varsa (yerel oyuncu) vardır. Sis yoksa (menü, sahipsiz test) her şey görülür.
## Yalnız okur; çizim kararını çağıran verir.

const FOG_METHOD := &"fog_layer"


## `node`'un en yakın `fog_layer()` taşıyan atasının sisi; gözlemcisi yoksa ya da sis yoksa null.
static func fog_of(node: Node) -> Object:
	var level: Node = node.get_parent() if node != null else null
	while level != null and not level.has_method(FOG_METHOD):
		level = level.get_parent()
	if level == null:
		return null
	var fog: Object = level.call(FOG_METHOD) as Object
	if fog == null or observer_of(fog) == null:
		return null
	return fog


## Sisin gözlemcisi (yerel oyuncu) ya da null.
static func observer_of(fog: Object) -> Node2D:
	var raw: Variant = fog.call(&"observer")
	if not is_instance_valid(raw):
		return null  # gözlemci kalktı (geç katılan, seviye değişimi; sis kendi adımında bırakır)
	return raw as Node2D


## Global nokta bu peer'da canlı görülüyor mu: karo görünen ya da çevresel (sis yoksa hep true). Prop durumu
## (kapı, çanta) ve ses halkası kaynağı için; NPC'ler ayrıca görüş hattı ister (NpcVisual).
static func is_seen(node: Node, global_pos: Vector2) -> bool:
	var fog: Object = fog_of(node)
	if fog == null:
		return true
	return is_tile_seen(fog, global_pos)


static func is_tile_seen(fog: Object, global_pos: Vector2) -> bool:
	var state: int = int(fog.call(&"state_at_position", global_pos))
	return state == VisionGrid.State.VISIBLE or state == VisionGrid.State.PERIPHERAL
