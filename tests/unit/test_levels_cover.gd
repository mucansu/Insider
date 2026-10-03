extends TestCase
## US-033: shop pockets and sight-blocking obstacles (mekan-estetigi.md K3, §2.1 #1/#11/#14, §2.1 density rule; GDD §6.5
## vision rule: world + vision_block cut, see_through passes; mimari S4 + S4 addition). Obstacles use separate legend chars in
## the layout file (`I` drinks cooler, `G` crate pile; levels/level_layout.gd): a solid obstacle = a `Walls` body shape (world
## layer), collides and blocks sight. Vision tests use perception's own physics query (`SightLine`, tile centre to tile
## centre; Perception also looks centre to centre).

const STORE := "res://levels/store_a.tscn"
const TILE := 32
const WORLD_LAYER := PhysicsLayers.WORLD  # mimari.md §4 layer 1
const SEE_THROUGH := PhysicsLayers.SEE_THROUGH_GROUP
const ARRIVE := 2.0
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Expected obstacle tiles (exactly the layout file; if it changes, update this list and the report together).
const COOLER_CELLS: Array[Vector2i] = [Vector2i(13, 5), Vector2i(13, 6), Vector2i(13, 7)]
const CRATE_CELLS: Array[Vector2i] = [Vector2i(20, 6), Vector2i(21, 2)]
## Back room pocket (mekan-estetigi §2.1 #11): hidden from BackroomSpot, open from the first tile entering through the inner door (BackroomDoor).
const BACKROOM_POCKET: Array[Vector2i] = [Vector2i(21, 6), Vector2i(21, 7)]
## The tile where whoever opens the back door in the alley stands (outer side of the back door).
const LOCK_SPOT := Vector2i(20, 2)
## Density rule (mekan-estetigi §2.1): colliding decor <= 8 tiles, new sight-blocking obstacles <= 3 pieces.
const MAX_OBSTACLE_TILES := 8
const MAX_OCCLUDERS := 3


func test_obstacles_in_layout_and_walls() -> void:
	var level: Level = _load()
	if level == null:
		return
	var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
	eq(_cells_of(tiles, LevelLayout.Kind.COOLER), COOLER_CELLS, "içecek dolabı karoları (I)")
	eq(_cells_of(tiles, LevelLayout.Kind.CRATE), CRATE_CELLS, "koli karoları (G)")
	eq(LevelLayout.kind_of_char("I"), LevelLayout.Kind.COOLER, "lejant I = dolap")
	eq(LevelLayout.kind_of_char("G"), LevelLayout.Kind.CRATE, "lejant G = koli")
	for kind: LevelLayout.Kind in [LevelLayout.Kind.COOLER, LevelLayout.Kind.CRATE]:
		is_true(LevelLayout.is_solid(kind), "%s çarpışan tür" % LevelLayout.Kind.keys()[kind])
	# Shapes are in the Walls body (block sight, not see_through), on the world layer; one per merged rectangle.
	var walls: StaticBody2D = level.get_node("Walls") as StaticBody2D
	eq(walls.collision_layer, WORLD_LAYER, "Walls world katmanında")
	var counts: Dictionary = {"Cooler": 0, "Crate": 0}
	for child: Node in walls.get_children():
		for prefix: String in counts:
			if child.name.begins_with(prefix):
				counts[prefix] = int(counts[prefix]) + 1
				is_true(child is CollisionShape2D, "%s Walls gövdesinin şekli" % child.name)
				is_false(child.is_in_group(SEE_THROUGH), "%s görüşü geçirmez" % child.name)
	eq(counts, {"Cooler": 1, "Crate": 2}, "Cooler1 (1×3) + Crate1, Crate2")
	is_true(int(counts["Cooler"]) + int(counts["Crate"]) <= MAX_OCCLUDERS, "görüş kesen yeni engel ≤ %d" % MAX_OCCLUDERS)
	is_true(COOLER_CELLS.size() + CRATE_CELLS.size() <= MAX_OBSTACLE_TILES, "çarpışan dekor ≤ %d karo" % MAX_OBSTACLE_TILES)


func test_obstacles_keep_clear_of_doors_and_markers() -> void:
	var level: Level = _load()
	if level == null:
		return
	var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
	var obstacles: Array[Vector2i] = COOLER_CELLS + CRATE_CELLS
	# The door threshold and both sides (passing through the door) are free of obstacles.
	for door: StringName in [&"FrontDoor", &"BackDoor", &"BackroomDoor"]:
		var cell: Vector2i = LevelLayout.cell_of(level.marker(door).position)
		for dir: Vector2i in [Vector2i.ZERO] + DIRS:
			is_false(obstacles.has(cell + dir), "%s eşiği/yanı (%s) engelsiz" % [door, cell + dir])
	# No marker or spawn is on an obstacle tile (radius overlap is checked in test_levels_population/test_levels).
	for parent: String in ["Markers", "SpawnPoints"]:
		for marker: Node in level.get_node(parent).get_children():
			var cell: Vector2i = LevelLayout.cell_of((marker as Node2D).position)
			is_false(obstacles.has(cell), "%s engel karosunda değil" % marker.name)
	# The sales aisle keeps 2 tiles next to the cooler (columns 11-12 open floor).
	for y: int in range(5, 8):
		for x: int in [11, 12]:
			eq(tiles.kind_at(Vector2i(x, y)), LevelLayout.Kind.FLOOR, "dolap önü koridoru (%d, %d) açık" % [x, y])
	# Alley crate: the tile north of it is open (the route goes around via row 1).
	eq(tiles.kind_at(Vector2i(21, 1)), LevelLayout.Kind.SIDEWALK, "ara sokak kolisinin kuzeyi açık")


func test_obstacles_block_sight_pockets() -> void:
	var level: Level = _load()
	if level == null:
		return
	tree().root.add_child(level)
	await tree().physics_frame
	await tree().physics_frame
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	# Back room pocket: BackroomSpot looking hits the crate; whoever enters the inner door (the door's inner tile) sees the pocket.
	var spot: Vector2 = level.marker(&"BackroomSpot").position
	var door: Vector2i = LevelLayout.cell_of(level.marker(&"BackroomDoor").position)
	var door_inside: Vector2 = _center(door + Vector2i.UP)  # inner door on a horizontal wall; back room to the north
	for cell: Vector2i in BACKROOM_POCKET:
		eq(_blocker(space, spot, _center(cell)), "Crate", "BackroomSpot → %s koliyle kesik" % cell)
	# Whoever enters the inner door (inner tile) sees the pocket mouth (21, 7); (21, 6) just east of the crate is visible one step
	# inside at (20, 7) (looking from the inner tile grazes the crate's south edge: the crate hides its own nook).
	eq(_blocker(space, door_inside, _center(Vector2i(21, 7))), "", "iç kapıdan giren (21, 7)'yi görür")
	eq(_blocker(space, _center(door + Vector2i(1, -1)), _center(Vector2i(21, 6))), "", "(20, 7)'den (21, 6) görünür")
	# Control: outside the pocket is open from BackroomSpot (the crate does not block the whole room): the inner tile of the inner
	# door, the D->O path, the inner side of the back door and the north-east corner.
	var back: Vector2i = LevelLayout.cell_of(level.marker(&"BackDoor").position)
	for cell: Vector2i in [door + Vector2i.UP, Vector2i(19, 6), back + Vector2i.DOWN, Vector2i(21, 5), Vector2i(21, 4)]:
		eq(_blocker(space, spot, _center(cell)), "", "BackroomSpot → %s açık" % cell)
	# Alley: hidden from StreetRoute5 (e) which unlocks, visible from StreetRoute6 (f).
	var e: Vector2 = level.marker(&"StreetRoute5").position
	var f: Vector2 = level.marker(&"StreetRoute6").position
	var lock: Vector2 = _center(LOCK_SPOT)
	eq(LOCK_SPOT, back + Vector2i.UP, "kilit açanın karosu arka kapının dış yanı")
	eq(_blocker(space, e, lock), "Crate", "StreetRoute5 → kilit açan koliyle kesik")
	eq(_blocker(space, f, lock), "", "StreetRoute6 → kilit açan görünür")
	# The drinks cooler blocks sight (from the corridor you see the cooler before the wall to the east).
	eq(_blocker(space, _center(Vector2i(12, 6)), _center(Vector2i(15, 6))), "Cooler", "dolap görüşü keser")
	tree().root.remove_child(level)


func test_routes_around_obstacles() -> void:
	var level: Level = _load()
	if level == null:
		return
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	var spot: Vector2 = level.marker(&"BackroomSpot").position
	var back: Vector2 = level.marker(&"BackDoor").position
	var backroom_door: Vector2 = level.marker(&"BackroomDoor").position
	var pairs: Array = [
		[back + Vector2(0, TILE), spot, "arka kapı içi → BackroomSpot"],
		[backroom_door - Vector2(0, TILE), spot, "iç kapı içi → BackroomSpot"],
		[backroom_door - Vector2(0, TILE), _center(Vector2i(21, 7)), "iç kapı içi → kese (21, 7)"],
		[spot, level.marker(&"BackroomCash").position, "BackroomSpot → arka oda nakdi"],
		[level.marker(&"StreetRoute5").position, _center(LOCK_SPOT), "StreetRoute5 → arka kapının önü"],
		[_center(Vector2i(12, 4)), _center(Vector2i(12, 8)), "dolap önü koridoru"],
		[level.marker(&"ShopSpot2").position, level.marker(&"ShelfProp1").position, "ShopSpot2 → ShelfProp1 (dolap yanı)"],
	]
	for p: Array in pairs:
		var to: Vector2 = p[1]
		var path: PackedVector2Array = NavigationServer2D.map_get_path(map, p[0] as Vector2, to, true)
		is_true(path.size() >= 2 and path[path.size() - 1].distance_to(to) <= ARRIVE, "yol var: %s" % p[2])
	tree().root.remove_child(level)
	NavigationServer2D.free_rid(map)


# --- helpers ---

func _load() -> Level:
	var scene: PackedScene = load(STORE) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % STORE):
		return null
	var level: Level = scene.instantiate() as Level
	if not is_true(level != null, "%s kökü Level olmalı" % STORE):
		return null
	return autofree(level) as Level


## Tiles of the kind (row by row, left to right).
static func _cells_of(tiles: LevelLayout, kind: LevelLayout.Kind) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size: Vector2i = tiles.size_in_tiles()
	for x: int in size.x:
		for y: int in size.y:
			if tiles.kind_at(Vector2i(x, y)) == kind:
				out.append(Vector2i(x, y))
	return out


## Name prefix of the first shape cut by perception's sight-line query (Crate/Cooler/Wall ...); empty if clear.
static func _blocker(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> String:
	var hit: Dictionary = SightLine.first_blocker(space, from, to)
	if hit.is_empty():
		return ""
	var body: CollisionObject2D = hit["collider"] as CollisionObject2D
	var owner_node: Node = body.shape_owner_get_owner(body.shape_find_owner(int(hit["shape"]))) as Node
	return RegEx.create_from_string("^[A-Za-z]+").search(String(owner_node.name)).get_string()


static func _center(cell: Vector2i) -> Vector2:
	return LevelLayout.cell_center(cell)


## Adds the level to the tree; links navigation nodes to a fresh isolated map and syncs (test_levels_nav pattern).
func _enter_with_map(level: Level) -> RID:
	var region: NavigationRegion2D = level.navigation_region()
	if not is_true(region != null, "Navigation yok"):
		return RID()
	var world_map: RID = tree().root.get_world_2d().navigation_map
	var map: RID = NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(map, NavigationServer2D.map_get_cell_size(world_map))
	NavigationServer2D.map_set_edge_connection_margin(map, NavigationServer2D.map_get_edge_connection_margin(world_map))
	NavigationServer2D.map_set_link_connection_radius(map, NavigationServer2D.map_get_link_connection_radius(world_map))
	NavigationServer2D.map_set_use_async_iterations(map, false)
	NavigationServer2D.map_set_active(map, true)
	region.set_navigation_map(map)
	NavigationServer2D.region_set_use_async_iterations(region.get_rid(), false)
	for link: Node in region.get_children():
		(link as NavigationLink2D).set_navigation_map(map)
	tree().root.add_child(level)
	var before: int = NavigationServer2D.map_get_iteration_id(map)
	NavigationServer2D.map_force_update(map)
	for i: int in 30:
		if NavigationServer2D.map_get_iteration_id(map) > before:
			return map
		await tree().physics_frame
	fail("gezinme haritası eşitlenmedi")
	return map
