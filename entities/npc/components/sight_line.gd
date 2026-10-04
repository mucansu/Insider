class_name SightLine
extends RefCounted
## Line-of-sight physics query (S11 Phase 2 addendum, §4; US-009): ray on world (1) + vision_block (6); **bodies** in the `see_through`
## group (US-007 windows, each `Window*` a separate body) and the `low_obstacle` group (IS-098: counter) are passed
## (PhysicsLayers.passes_sight): the body RID is excluded and the ray re-cast from the start - no
## continuation point is computed, so a wall adjacent to a window cannot be skipped at a corner. The group works at body level only
## (a grouped shape on a shared body blocks). Player and NPC bodies are not in the mask. Same method as `Perception.has_line_of_sight`
## (US-006); NPC components (Hearing; Perception later) share it. Physics only; rules (e.g. the source's own body for noise) are the
## caller's and core/'s.

const SEE_THROUGH_GROUP := PhysicsLayers.SEE_THROUGH_GROUP
const MASK := PhysicsLayers.SIGHT_MASK
## Maximum passed bodies skipped on one ray (infinite-loop guard).
const MAX_SEE_THROUGH := 8


## First blocking hit between `from` and `to` (intersect_ray dictionary: position, collider, rid ...); empty if clear.
## If the pass-through body limit is exceeded the last hit counts as blocking.
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
		if collider == null or not PhysicsLayers.passes_sight(collider.get_groups()):
			return hit
		exclude.append(hit["rid"] as RID)
	return hit


static func is_clear(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int = MASK) -> bool:
	return first_blocker(space, from, to, mask).is_empty()
