class_name FogView
extends RefCounted
## Access from entity visuals to the local player's vision fog (US-011a `FogLayer`; Level `fog_layer()`, S3 addendum; US-011b).
## Duck typed: entities/ does not know level classes (§6); fog exists only if the level attached it via `attach_fog` and it has an
## observer (local player). Without fog (menu, ownerless test) everything is seen. Read-only; the caller decides what to draw.

const FOG_METHOD := &"fog_layer"


## Fog of `node`'s nearest ancestor providing `fog_layer()`; null if no observer or no fog.
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


## Fog observer (local player) or null.
static func observer_of(fog: Object) -> Node2D:
	var raw: Variant = fog.call(&"observer")
	if not is_instance_valid(raw):
		return null  # observer gone (late joiner, level change; fog releases it on its own step)
	return raw as Node2D


## Whether a global point is live-seen on this peer: tile visible or peripheral (always true without fog). For prop state
## (door, bag) and noise ring source; NPCs additionally need line of sight (NpcVisual).
static func is_seen(node: Node, global_pos: Vector2) -> bool:
	var fog: Object = fog_of(node)
	if fog == null:
		return true
	return is_tile_seen(fog, global_pos)


static func is_tile_seen(fog: Object, global_pos: Vector2) -> bool:
	var state: int = int(fog.call(&"state_at_position", global_pos))
	return state == VisionGrid.State.VISIBLE or state == VisionGrid.State.PERIPHERAL
