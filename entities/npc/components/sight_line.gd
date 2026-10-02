class_name SightLine
extends RefCounted
## Görüş hattı fizik sorgusu (mimari.md S11 Faz 2 eki, §4; US-009): world (1) + vision_block (6) katmanlarına ışın;
## `see_through` grubundaki **gövdeler** (US-007 camları, her `Window*` ayrı gövde) geçilir: gövde RID'i dışlanıp
## ışın baştan yeniden atılır — devam noktası hesaplanmadığından cama bitişik duvar köşede atlanamaz. Grup yalnız
## gövde düzeyinde geçerlidir (ortak gövdedeki gruplu şekil keser). Oyuncu ve NPC gövdeleri maskede değil.
## Yöntem `Perception.has_line_of_sight` (US-006) ile aynıdır; NPC bileşenleri (Hearing; ileride Perception) bunu
## paylaşır. Yalnız fizik; kural (ör. gürültüde kaynağın kendi gövdesi) çağıranda ve core/'da.

const SEE_THROUGH_GROUP := PhysicsLayers.SEE_THROUGH_GROUP
const MASK := PhysicsLayers.SIGHT_MASK
## Bir ışında en fazla kaç geçiren gövde atlanır (sonsuz döngü bekçisi).
const MAX_SEE_THROUGH := 8


## `from` → `to` arasındaki ilk kesen isabet (intersect_ray sözlüğü: position, collider, rid …); açıksa boş.
## Geçiren gövde sınırı aşılırsa son isabet kesen sayılır.
static func first_blocker(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2,
		mask: int = MASK) -> Dictionary:
	var exclude: Array[RID] = []
	var hit: Dictionary = {}
	for _i: int in MAX_SEE_THROUGH + 1:
		var query := PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = false
		hit = space.intersect_ray(query)
		if hit.is_empty():
			return hit
		var collider: Node = hit.get("collider") as Node
		if collider == null or not collider.is_in_group(SEE_THROUGH_GROUP):
			return hit
		exclude.append(hit["rid"] as RID)
	return hit


static func is_clear(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int = MASK) -> bool:
	return first_blocker(space, from, to, mask).is_empty()
