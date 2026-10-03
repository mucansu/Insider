class_name Level
extends Node2D
## Level root (mimari.md S4, KR-018). `levels/tools/build_levels.gd` attaches it to the root of every generated scene.
## Core and other systems reach level nodes only through this API, never by name string; node names (S4 required children) appear only here and in the generator.
## Queries also work outside the tree (Game builds the level before adding it). Missing required child: the matching root returns null, spawn count is 0.

const _PLAYERS := ^"Players"
const _PROPS := ^"Props"
const _NPCS := ^"NPCs"
const _SPAWN_POINTS := ^"SpawnPoints"
const _MARKERS := ^"Markers"
const _ZONES := ^"Zones"
const _NAVIGATION := ^"Navigation"
const _TILES := ^"Tiles"
## Vision fog layer (US-011a; added at runtime by `attach_fog`, not in the scene).
const _FOG := ^"Fog"


## Container of player nodes (Game creates them; node name = peer id).
func players_root() -> Node2D:
	return get_node_or_null(_PLAYERS) as Node2D


## Container of interactable objects.
func props_root() -> Node2D:
	return get_node_or_null(_PROPS) as Node2D


## Container of NPCs.
func npcs_root() -> Node2D:
	return get_node_or_null(_NPCS) as Node2D


## Number of spawn points under `SpawnPoints` (Spawn1..N in scene order).
func spawn_count() -> int:
	return _spawn_points().size()


## The `index`-th spawn point (index wraps by spawn count), in `players_root()` coordinates: used directly as the player node's `position`.
## Vector2.ZERO if there is no spawn point or no Players.
func spawn_position(index: int) -> Vector2:
	var points: Array[Node2D] = _spawn_points()
	var players: Node2D = players_root()
	if points.is_empty() or players == null:
		return Vector2.ZERO
	var at: Vector2 = _to_level(points[posmod(index, points.size())]).origin
	return _to_level(players).affine_inverse() * at


## Named placement marker under `Markers` (e.g. &"Register", &"BackDoor"); null if missing.
func marker(marker_name: StringName) -> Node2D:
	return _child_of(_MARKERS, marker_name) as Node2D


## Ordered marker array: `<prefix>1`, `<prefix>2` ... up to the first missing number (e.g. &"StreetRoute" street route,
## &"ShopSpot" customer shelf points; IS-023). Empty array if none.
func marker_sequence(prefix: StringName) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var next: Node2D = marker(StringName("%s%d" % [prefix, 1]))
	while next != null:
		out.append(next)
		next = marker(StringName("%s%d" % [prefix, out.size() + 1]))
	return out


## Named trigger zone under `Zones` (e.g. &"EscapeZone"; Area2D, triggers layer, tracks players); null if missing.
func zone(zone_name: StringName) -> Area2D:
	return _child_of(_ZONES, zone_name) as Area2D


## Level navigation region (NavigationPolygon baked at generation); null if missing.
func navigation_region() -> NavigationRegion2D:
	return get_node_or_null(_NAVIGATION) as NavigationRegion2D


## Navigation link of a door marker (e.g. &"BackDoor"): the door tile blocks the polygon, passage goes through this link.
## Set `enabled = false` when the door closes (the system wiring door state; US-008). Null if missing.
func door_link(door_name: StringName) -> NavigationLink2D:
	return _child_of(_NAVIGATION, door_name) as NavigationLink2D


## Tile layout (`Tiles`, LevelLayout); null if missing.
func layout() -> LevelLayout:
	return get_node_or_null(_TILES) as LevelLayout


## Vision grid size (tiles; US-011a). Zero if there is no layout.
func vision_size() -> Vector2i:
	var tiles: LevelLayout = layout()
	return tiles.size_in_tiles() if tiles != null else Vector2i.ZERO


## Vision obstacle grid (US-011a; `VisionGrid.Cell`, row by row). Classes: `LevelLayout.SIGHT_SOLID` (wall, border,
## shelf, counter) and `SIGHT_PORTAL` (door gap, shop window: a physics query decides); the rest are open.
func vision_cells() -> PackedByteArray:
	var out := PackedByteArray()
	var tiles: LevelLayout = layout()
	if tiles == null:
		return out
	var size: Vector2i = tiles.size_in_tiles()
	out.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			out[y * size.x + x] = vision_cell_of(tiles.kind_at(Vector2i(x, y)))
	return out


## Vision class of a tile type (`VisionGrid.Cell`).
static func vision_cell_of(kind: LevelLayout.Kind) -> int:
	if LevelLayout.SIGHT_SOLID.has(kind):
		return VisionGrid.Cell.SOLID
	if LevelLayout.SIGHT_PORTAL.has(kind):
		return VisionGrid.Cell.PORTAL
	return VisionGrid.Cell.OPEN


## Vision settings (`data/vision_tuning.tres`).
func vision_tuning() -> VisionTuning:
	return load(VisionTuning.PATH) as VisionTuning


## This level's vision fog layer (if set up via `attach_fog`); null otherwise.
func fog_layer() -> FogLayer:
	return get_node_or_null(_FOG) as FogLayer


## Sets up the local player's vision fog (US-011a; client only, for the local player) and tracks `observer`.
## If the layer exists only the observer changes (memory is kept). The level must be in the tree (physics query).
func attach_fog(observer: Node2D) -> FogLayer:
	var fog: FogLayer = fog_layer()
	if fog == null:
		fog = FogLayer.new()
		fog.name = String(_FOG)
		add_child(fog)
		fog.setup_from_level(self)
	fog.follow(observer)
	return fog


## Direct child of `container`; names with a path part (like "../Players") are rejected.
func _child_of(container: NodePath, child_name: StringName) -> Node:
	var text: String = String(child_name)
	var parent: Node = get_node_or_null(container)
	if parent == null or text.is_empty() or text.validate_node_name() != text:
		return null
	return parent.get_node_or_null(NodePath(text))


## Playable-area rectangle of the map (IS-027; camera limit): the whole `Tiles` grid including the map-edge fill (border tiles);
## relative to this root (excluding the root's own transform). Rect2() with zero area if `Tiles` is missing or empty
## (the caller applies no limit).
func map_rect() -> Rect2:
	var tiles: LevelLayout = get_node_or_null(_TILES) as LevelLayout
	if tiles == null:
		return Rect2()
	var size: Vector2i = tiles.size_in_tiles()
	if size.x <= 0 or size.y <= 0:
		return Rect2()
	return _to_level(tiles) * Rect2(Vector2.ZERO, Vector2(size * LevelLayout.TILE))


func _spawn_points() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var points: Node = get_node_or_null(_SPAWN_POINTS)
	if points != null:
		for child: Node in points.get_children():
			if child is Node2D:
				out.append(child as Node2D)
	return out


## Node's transform relative to this root (works outside the tree; global_transform needs the tree).
func _to_level(node: Node2D) -> Transform2D:
	var xform: Transform2D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != self:
		if parent is Node2D:
			xform = (parent as Node2D).transform * xform
		parent = parent.get_parent()
	return xform
