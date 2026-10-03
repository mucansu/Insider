extends TestCase
## IS-023: store v1 population markers and zones (GDD v0.3 §9.2-9.3, KR-020/KR-021; mimari S4 + S4 addition). Markers complete
## and off obstacles; street route order and staying outside; neighbour spawn and route linked by navigation; zones do not overlap,
## fully partition the interior floor and split at doors; population markers in the right zone; the sight line from shelf-fix
## points to the register is cut by shelf/wall, from glass look points the interior is visible through glass (real physics ray, US-007 pattern).

const STORE := "res://levels/store_a.tscn"
const ARENA := "res://levels/test_arena.tscn"
const LEVELS: Array[String] = [STORE, ARENA]

const TILE := 32
const CHAR_RADIUS := 12.0       # character diameter ~24 px (S4)
const WORLD_LAYER := PhysicsLayers.WORLD  # mimari.md §4 layer 1
const PLAYERS_LAYER := PhysicsLayers.PLAYERS  # §4 layer 2
const TRIGGERS_LAYER := PhysicsLayers.TRIGGERS  # §4 layer 5
const SEE_THROUGH := PhysicsLayers.SEE_THROUGH_GROUP
const ARRIVE := 2.0             # path end this close to the goal counts as "reached"
const DOOR_PASS := TILE + 1.0   # door link ends are one tile from the door centre

## Singular population markers (in every level).
const SINGLES: Array[StringName] = [&"NeighbourSpawn", &"PhoneSpot", &"BackroomSpot"]
## Ordered population markers: prefix -> count in the store (at least 1 in the arena).
const SEQUENCES: Dictionary = {
	&"StreetRoute": 6, &"WindowLook": 3, &"ShopSpot": 5, &"QueueSpot": 2, &"RestockSpot": 3, &"ShelfProp": 3,
}
const POPULATION_ZONES: Array[StringName] = [&"CustomerArea", &"StaffArea", &"Backroom"]
## Zone the marker must be in ("" = no zone, outside); ordered names match by prefix.
const MARKER_ZONES: Dictionary = {
	&"ShopSpot": &"CustomerArea", &"QueueSpot": &"CustomerArea", &"RestockSpot": &"CustomerArea",
	&"ShelfProp": &"CustomerArea", &"PhoneSpot": &"StaffArea", &"ClerkSpot": &"StaffArea",
	&"BackroomSpot": &"Backroom", &"BackroomCash": &"Backroom", &"BackroomSafe": &"Backroom",
	&"StreetRoute": &"", &"WindowLook": &"", &"NeighbourSpawn": &"", &"Exit": &"EscapeZone",
}
## Zones of the tiles on both sides of a door (ordered; "" = no zone).
const DOOR_ZONES: Dictionary = {
	&"FrontDoor": [&"", &"CustomerArea"], &"BackDoor": [&"", &"Backroom"], &"BackroomDoor": [&"Backroom", &"StaffArea"],
}
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


# --- markers complete, off obstacles; zones present ---

func test_population_markers_complete_and_clear() -> void:
	for path: String in LEVELS:
		var level: Level = _load(path)
		if level == null:
			continue
		var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
		var walls: Array[Rect2] = _wall_rects(level)
		var placed: Array[Node2D] = []
		for marker_name: StringName in SINGLES:
			var marker: Node2D = level.marker(marker_name)
			if is_true(marker is Marker2D, "%s: Markers/%s" % [path, marker_name]):
				placed.append(marker)
		for prefix: StringName in SEQUENCES:
			var sequence: Array[Node2D] = level.marker_sequence(prefix)
			var expected: int = int(SEQUENCES[prefix])
			if path == STORE:
				eq(sequence.size(), expected, "%s: %s1..%d" % [path, prefix, expected])
			else:
				is_true(sequence.size() >= 1, "%s: en az bir %s" % [path, prefix])
			for gap: int in [1, 2]:
				is_true(level.marker(StringName("%s%d" % [prefix, sequence.size() + gap])) == null,
					"%s: %s numaraları boşluksuz" % [path, prefix])
			placed.append_array(sequence)
		is_true(level.marker(&"PolicePatrol1") == null, "%s: PolicePatrol* kalktı (StreetRoute*)" % path)
		for marker: Node2D in placed:
			var cell: Vector2i = LevelLayout.cell_of(marker.position)
			near(marker.position, LevelLayout.cell_center(cell), 0.01, "%s: %s karo merkezinde" % [path, marker.name])
			var kind: LevelLayout.Kind = tiles.kind_at(cell)
			is_false(LevelLayout.is_solid(kind) or kind == LevelLayout.Kind.DOOR,
				"%s: %s engel/kapı karosunda (%s)" % [path, marker.name, LevelLayout.Kind.keys()[kind]])
			for rect: Rect2 in walls:
				is_false(_circle_hits(marker.position, CHAR_RADIUS, rect), "%s: %s çarpışma şekline giriyor %s" % [path, marker.name, rect])
		for zone_name: StringName in POPULATION_ZONES:
			var zone: Area2D = level.zone(zone_name)
			if not is_true(zone != null, "%s: Zones/%s" % [path, zone_name]):
				continue
			eq(zone.collision_layer, TRIGGERS_LAYER, "%s: %s yalnız triggers katmanında" % [path, zone_name])
			eq(zone.collision_mask, PLAYERS_LAYER, "%s: %s oyuncuları izler" % [path, zone_name])
			is_true(zone.monitoring and not zone.monitorable, "%s: %s izler, izlenmez" % [path, zone_name])
			is_true(_zone_rects(zone).size() >= 1, "%s: %s dikdörtgen şekil taşır" % [path, zone_name])
		if path == STORE:
			# Under Props (US-005 instances) survive regeneration.
			for prop: String in ["Register", "FrontDoor", "BackDoor"]:
				var node: Node = level.props_root().get_node_or_null(prop)
				is_true(node != null and not node.scene_file_path.is_empty(), "bakkal: Props/%s alt sahne örneği korunmalı" % prop)


# --- street route ---

func test_store_street_route_order() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
	var route: Array[Node2D] = level.marker_sequence(&"StreetRoute")
	if not eq(route.size(), 6, "StreetRoute1..6"):
		return
	var cells: Array[Vector2i] = []
	for point: Node2D in route:
		cells.append(LevelLayout.cell_of(point.position))
		has([LevelLayout.Kind.SIDEWALK, LevelLayout.Kind.STREET], tiles.kind_at(cells[-1]), "%s dışarıda" % point.name)
	var building: Rect2i = _building(tiles)
	var front: Vector2i = _marker_cell(level, &"FrontDoor")
	var back: Vector2i = _marker_cell(level, &"BackDoor")
	# 1 front windows: the tile north is display glass (front facade).
	eq(tiles.kind_at(cells[0] + Vector2i.UP), LevelLayout.Kind.WINDOW, "StreetRoute1 ön camın önünde")
	is_true(cells[0].y == building.end.y, "StreetRoute1 ön cephe kaldırımında")
	# 2 front door: at most 2 tiles from the door, on the sidewalk (outside the facade).
	is_true(_tile_dist(cells[1], front) <= 2.0 and cells[1].y >= building.end.y, "StreetRoute2 ön kapıda")
	is_true(cells[0].x < cells[1].x and cells[1].x < cells[2].x, "ön cephe batıdan doğuya yürünür")
	# 3 corner: outside the building's south-east corner.
	is_true(cells[2].x >= building.end.x and cells[2].y >= building.end.y, "StreetRoute3 güneydoğu köşede")
	# 4 side windows: the tile west is display glass (side facade).
	eq(tiles.kind_at(cells[3] + Vector2i.LEFT), LevelLayout.Kind.WINDOW, "StreetRoute4 yan camın önünde")
	# 5 side street: east of the building, north of the side windows.
	is_true(cells[4].x >= building.end.x and cells[4].y < cells[3].y, "StreetRoute5 yan sokakta, kuzeyde")
	is_true(cells[2].y > cells[3].y and cells[3].y > cells[4].y, "yan cephe güneyden kuzeye yürünür")
	# 6 back door: in the alley north of the building, at most 2 tiles from the back door.
	is_true(cells[5].y < building.position.y and _tile_dist(cells[5], back) <= 2.0, "StreetRoute6 arka kapıda")
	is_true(cells[5].x < cells[4].x, "ara sokağa batıya dönülür")


func test_store_route_and_neighbour_navigation() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
	var route: Array[Node2D] = level.marker_sequence(&"StreetRoute")
	var neighbour: Node2D = level.marker(&"NeighbourSpawn")
	if not is_true(route.size() >= 2 and neighbour != null, "StreetRoute ve NeighbourSpawn"):
		return
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	var front: Vector2 = level.marker(&"FrontDoor").position
	var back: Vector2 = level.marker(&"BackDoor").position
	var outside_front: Vector2 = front + Vector2(0, TILE)  # front door on a horizontal wall, outside is +y
	var outside_back: Vector2 = back - Vector2(0, TILE)    # back door on the north wall, outside is -y
	# Doors closed: route and neighbour are linked outside, path tiles always outside.
	for door: StringName in [&"FrontDoor", &"BackDoor", &"BackroomDoor"]:
		level.door_link(door).enabled = false
	await _sync(map)
	var outdoor: Array[LevelLayout.Kind] = [LevelLayout.Kind.SIDEWALK, LevelLayout.Kind.STREET]
	for i: int in range(1, route.size()):
		var path: PackedVector2Array = _path(map, route[i - 1].position, route[i].position)
		is_true(_arrives(path, route[i].position), "StreetRoute%d → StreetRoute%d bağlı" % [i, i + 1])
		for p: Vector2 in path:
			has(outdoor, tiles.kind_at(LevelLayout.cell_of(p)), "StreetRoute%d → %d yolu dışarıda kalır (%s)" % [i, i + 1, p])
	for target: Vector2 in [outside_front, outside_back]:
		is_true(_arrives(_path(map, neighbour.position, target), target), "NeighbourSpawn → kapı önü %s dışarıdan" % target)
	# Doors open: the neighbour enters through both doors (front door -> sales floor, back door -> back room).
	for door: StringName in [&"FrontDoor", &"BackDoor", &"BackroomDoor"]:
		level.door_link(door).enabled = true
	await _sync(map)
	var inside_front: Vector2 = front - Vector2(0, TILE)
	var inside_back: Vector2 = back + Vector2(0, TILE)
	var via_front: PackedVector2Array = _path(map, neighbour.position, inside_front)
	is_true(_arrives(via_front, inside_front) and _passes(via_front, front), "NeighbourSpawn → ön kapıdan içeri")
	var via_back: PackedVector2Array = _path(map, neighbour.position, inside_back)
	is_true(_arrives(via_back, inside_back) and _passes(via_back, back), "NeighbourSpawn → arka kapıdan arka odaya")
	is_true(_length(via_back) < _length(via_front), "komşu arka kapıya ön kapıdan yakın (yan sokakta)")
	_leave(level, map)


# --- zones ---

func test_zones_disjoint_and_partition_interior() -> void:
	for path: String in LEVELS:
		var level: Level = _load(path)
		if level == null:
			continue
		var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
		var owner_of: Dictionary = {}  # tile -> zone name
		var overlaps: PackedStringArray = []
		for zone: Node in level.get_node("Zones").get_children():
			for rect: Rect2 in _zone_rects(zone as Area2D):
				for cell: Vector2i in _cells(rect):
					if owner_of.has(cell):
						overlaps.append("%s %s/%s" % [cell, owner_of[cell], zone.name])
					owner_of[cell] = zone.name
		is_true(overlaps.is_empty(), "%s: bölgeler örtüşüyor: %s" % [path, ", ".join(overlaps)])
		var bad_ground: PackedStringArray = []
		for cell: Vector2i in owner_of:
			if not POPULATION_ZONES.has(StringName(owner_of[cell])):
				continue
			var kind: LevelLayout.Kind = tiles.kind_at(cell)
			if not [LevelLayout.Kind.FLOOR, LevelLayout.Kind.BACKROOM, LevelLayout.Kind.SHELF, LevelLayout.Kind.COUNTER,
					LevelLayout.Kind.COOLER, LevelLayout.Kind.CRATE].has(kind):
				bad_ground.append("%s %s" % [cell, LevelLayout.Kind.keys()[kind]])
		is_true(bad_ground.is_empty(), "%s: nüfus bölgesi iç zemin dışında: %s" % [path, ", ".join(bad_ground)])
		for i: int in level.spawn_count():
			var cell: Vector2i = LevelLayout.cell_of((level.get_node("SpawnPoints/Spawn%d" % (i + 1)) as Node2D).position)
			is_false(owner_of.has(cell), "%s: Spawn%d bölge dışında (dışarısı)" % [path, i + 1])
		if path != STORE:
			continue
		# Store: every tile of the interior floor (sales floor + back room) is in exactly one population zone.
		var uncovered: PackedStringArray = []
		var size: Vector2i = tiles.size_in_tiles()
		for y: int in size.y:
			for x: int in size.x:
				var cell := Vector2i(x, y)
				var kind: LevelLayout.Kind = tiles.kind_at(cell)
				if (kind == LevelLayout.Kind.FLOOR or kind == LevelLayout.Kind.BACKROOM) \
						and not POPULATION_ZONES.has(StringName(owner_of.get(cell, &""))):
					uncovered.append(str(cell))
		is_true(uncovered.is_empty(), "bakkal: bölgesiz iç zemin: %s" % ", ".join(uncovered))
		# Doors separate zones: the door tile has no zone (threshold), both sides are in the expected zones.
		for door: StringName in DOOR_ZONES:
			var marker: Node2D = level.marker(door)
			var cell: Vector2i = LevelLayout.cell_of(marker.position)
			var across: Vector2i = Vector2i.RIGHT if is_equal_approx(marker.rotation_degrees, 90.0) else Vector2i.DOWN
			is_false(owner_of.has(cell), "bakkal: %s karosu bölgesiz" % door)
			var sides: Array[StringName] = [StringName(owner_of.get(cell - across, &"")), StringName(owner_of.get(cell + across, &""))]
			sides.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			eq(sides, DOOR_ZONES[door], "bakkal: %s iki yanı" % door)


func test_markers_lie_in_expected_zones() -> void:
	for path: String in LEVELS:
		var level: Level = _load(path)
		if level == null:
			continue
		var checked: int = 0
		for marker: Node in level.get_node("Markers").get_children():
			var key: StringName = _zone_key(marker.name)
			if key == &"":
				continue
			checked += 1
			var zones: Array[StringName] = _zones_at(level, (marker as Node2D).position)
			var expected: StringName = MARKER_ZONES[key]
			if expected == &"":
				is_true(zones.is_empty(), "%s: %s bölge dışında olmalı, gelen %s" % [path, marker.name, zones])
			else:
				eq(zones, [expected], "%s: %s bölgesi" % [path, marker.name])
		is_true(checked >= MARKER_ZONES.size(), "%s: bölgesi denetlenen işaret sayısı %d" % [path, checked])


# --- placement rules (layout) ---

func test_store_marker_placement() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
	var building: Rect2i = _building(tiles)
	for point: Node2D in level.marker_sequence(&"RestockSpot"):
		var cell: Vector2i = LevelLayout.cell_of(point.position)
		eq(tiles.kind_at(cell), LevelLayout.Kind.FLOOR, "%s satış alanında" % point.name)
		is_true(_touches(tiles, cell, LevelLayout.Kind.SHELF), "%s raf önünde (rafa döner)" % point.name)
	for point: Node2D in level.marker_sequence(&"ShelfProp"):
		var cell: Vector2i = LevelLayout.cell_of(point.position)
		eq(tiles.kind_at(cell), LevelLayout.Kind.FLOOR, "%s zeminde" % point.name)
		is_true(_touches(tiles, cell, LevelLayout.Kind.SHELF), "%s raf ucunda" % point.name)
	var counter_x: int = _marker_cell(level, &"Counter").x
	for point: Node2D in level.marker_sequence(&"QueueSpot"):
		var cell: Vector2i = LevelLayout.cell_of(point.position)
		eq(tiles.kind_at(cell + Vector2i.RIGHT), LevelLayout.Kind.COUNTER, "%s tezgâhın önünde" % point.name)
		is_true(cell.x < counter_x, "%s tezgâhın müşteri (batı) tarafında" % point.name)
	var queue: Node2D = level.marker(&"QueueSpot1")
	if queue != null:
		eq(LevelLayout.cell_of(queue.position) + Vector2i.RIGHT, _marker_cell(level, &"Register"), "QueueSpot1 kasanın tam önünde")
	var phone: Vector2i = _marker_cell(level, &"PhoneSpot")
	eq(tiles.kind_at(phone), LevelLayout.Kind.FLOOR, "PhoneSpot zeminde")
	eq(tiles.kind_at(phone + Vector2i.RIGHT), LevelLayout.Kind.WALL, "PhoneSpot doğu duvarının önünde (cam değil)")
	is_true(phone.x > counter_x, "PhoneSpot tezgâh arkasında")
	eq(tiles.kind_at(_marker_cell(level, &"BackroomSpot")), LevelLayout.Kind.BACKROOM, "BackroomSpot arka odada")
	var neighbour: Vector2i = _marker_cell(level, &"NeighbourSpawn")
	eq(tiles.kind_at(neighbour), LevelLayout.Kind.SIDEWALK, "NeighbourSpawn kaldırımda")
	is_true(neighbour.x >= building.end.x, "NeighbourSpawn yan sokakta (binanın doğusu)")
	is_true(neighbour.y > _marker_cell(level, &"BackDoor").y and neighbour.y < building.end.y,
		"NeighbourSpawn arka kapı ile cadde arasında")
	for point: Node2D in level.marker_sequence(&"WindowLook"):
		var cell: Vector2i = LevelLayout.cell_of(point.position)
		eq(tiles.kind_at(cell), LevelLayout.Kind.SIDEWALK, "%s kaldırımda" % point.name)
		var windows: int = 0
		for dir: Vector2i in DIRS:
			if tiles.kind_at(cell + dir) == LevelLayout.Kind.WINDOW:
				windows += 1
		eq(windows, 1, "%s tam bir camın önünde" % point.name)


# --- sight line (real physics ray) ---

func test_store_lines_of_sight() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	tree().root.add_child(level)
	await tree().physics_frame
	await tree().physics_frame
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var register: Vector2 = level.marker(&"Register").position
	var clerk: Vector2 = level.marker(&"ClerkSpot").position
	# Shelf fix: the owner cannot see the register nor the counter spot behind it where the emptier stands (shelf/wall blocks).
	for point: Node2D in level.marker_sequence(&"RestockSpot"):
		for target: Vector2 in [register, clerk]:
			var blocker: String = _shape_name(_ray(space, point.position, target, true))
			has(["Shelf", "Wall"], blocker, "%s → %s görüş hattı raf/duvarla kesik (gelen '%s')" % [point.name, target, blocker])
	# Control: the ray is clear in the open aisle (ShopSpot4 -> QueueSpot1, row 11).
	is_true(_ray(space, level.marker(&"ShopSpot4").position, level.marker(&"QueueSpot1").position, true).is_empty(),
		"açık koridorda görüş hattı engelsiz")
	# Glass look: from the sidewalk the ray first hits glass, with glass skipped it is clear 3 tiles inside; one per glass piece.
	var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
	var seen_windows: Dictionary = {}
	for point: Node2D in level.marker_sequence(&"WindowLook"):
		var cell: Vector2i = LevelLayout.cell_of(point.position)
		var inward: Vector2i = Vector2i.ZERO
		for dir: Vector2i in DIRS:
			if tiles.kind_at(cell + dir) == LevelLayout.Kind.WINDOW:
				inward = dir
		if not is_true(inward != Vector2i.ZERO, "%s camın önünde" % point.name):
			continue
		var target: Vector2 = LevelLayout.cell_center(cell + inward * 3)
		var glass: Dictionary = _ray(space, point.position, target, false)
		var body: Node = glass.get("collider") as Node
		if is_true(body != null and body.is_in_group(SEE_THROUGH), "%s: ilk engel cam" % point.name):
			seen_windows[body] = true
		is_true(_ray(space, point.position, target, true).is_empty(), "%s: camdan içerisi görünür" % point.name)
	var window_bodies: int = 0
	for child: Node in level.get_node("Walls").get_children():
		if child.is_in_group(SEE_THROUGH):
			window_bodies += 1
	eq(seen_windows.size(), window_bodies, "her cam parçasının önünde bir WindowLook")
	# Phone: the owner facing east faces the wall (the side glass does not show outside).
	var phone: Vector2 = level.marker(&"PhoneSpot").position
	eq(_shape_name(_ray(space, phone, phone + Vector2(TILE, 0), false)), "Wall", "PhoneSpot doğusu duvar")
	tree().root.remove_child(level)


# --- helpers ---

func _load(path: String) -> Level:
	var scene: PackedScene = load(path) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % path):
		return null
	var level: Level = scene.instantiate() as Level
	if not is_true(level != null, "%s kökü Level olmalı" % path):
		return null
	return autofree(level) as Level


func _marker_cell(level: Level, marker_name: StringName) -> Vector2i:
	var marker: Node2D = level.marker(marker_name)
	if not is_true(marker != null, "Markers/%s yok" % marker_name):
		return Vector2i(-9999, -9999)
	return LevelLayout.cell_of(marker.position)


## The building's tile rectangle: container of wall, glass and door tiles.
static func _building(tiles: LevelLayout) -> Rect2i:
	var out := Rect2i()
	var size: Vector2i = tiles.size_in_tiles()
	for y: int in size.y:
		for x: int in size.x:
			var kind: LevelLayout.Kind = tiles.kind_at(Vector2i(x, y))
			if kind == LevelLayout.Kind.WALL or kind == LevelLayout.Kind.WINDOW or kind == LevelLayout.Kind.DOOR:
				var cell := Rect2i(x, y, 1, 1)
				out = cell if not out.has_area() else out.merge(cell)
	return out


static func _touches(tiles: LevelLayout, cell: Vector2i, kind: LevelLayout.Kind) -> bool:
	for dir: Vector2i in DIRS:
		if tiles.kind_at(cell + dir) == kind:
			return true
	return false


static func _tile_dist(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))


## The marker name's key in the zone table (prefix for ordered names); empty if not in the table.
static func _zone_key(marker_name: StringName) -> StringName:
	var text: String = String(marker_name)
	if MARKER_ZONES.has(marker_name):
		return marker_name
	var prefix: String = text.rstrip("0123456789")
	if prefix != text and MARKER_ZONES.has(StringName(prefix)):
		return StringName(prefix)
	return &""


## Names of the zones containing the point (Zones child order).
static func _zones_at(level: Level, pos: Vector2) -> Array[StringName]:
	var out: Array[StringName] = []
	for zone: Node in level.get_node("Zones").get_children():
		for rect: Rect2 in _zone_rects(zone as Area2D):
			if rect.has_point(pos) and not out.has(StringName(zone.name)):
				out.append(StringName(zone.name))
	return out


static func _zone_rects(zone: Area2D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node: Node in zone.find_children("*", "CollisionShape2D", false, false):
		var cs: CollisionShape2D = node as CollisionShape2D
		var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
		if rect_shape != null:
			out.append(Rect2(zone.position + cs.position - rect_shape.size / 2.0, rect_shape.size))
	return out


## Tiles covered by the rectangle (rectangle aligned to tile boundaries).
static func _cells(rect: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(roundi(rect.position.y / TILE), roundi(rect.end.y / TILE)):
		for x: int in range(roundi(rect.position.x / TILE), roundi(rect.end.x / TILE)):
			out.append(Vector2i(x, y))
	return out


## All rectangular shapes under `Walls` (glass included), in level-root coordinates.
func _wall_rects(level: Level) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node: Node in level.get_node("Walls").find_children("*", "CollisionShape2D", true, false):
		var cs: CollisionShape2D = node as CollisionShape2D
		var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
		if not is_true(rect_shape != null, "Walls/%s dikdörtgen olmalı" % cs.name):
			continue
		var xform: Transform2D = cs.transform
		var parent: Node = cs.get_parent()
		while parent != null and parent != level:
			if parent is Node2D:
				xform = (parent as Node2D).transform * xform
			parent = parent.get_parent()
		out.append(xform * Rect2(-rect_shape.size / 2.0, rect_shape.size))
	return out


static func _circle_hits(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_to(closest) < radius


## First obstacle; with `skip_see_through`, see_through bodies are skipped (perception's sight-line rule, S11).
func _ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, skip_see_through: bool) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER)
	var exclude: Array[RID] = []
	for i: int in 8:
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not skip_see_through or not PhysicsLayers.passes_sight((hit["collider"] as Node).get_groups()):
			return hit
		exclude.append(hit["rid"] as RID)
	return {}


## Name prefix of the hit shape (Shelf/Wall/Counter/Window ...); empty if no hit.
static func _shape_name(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	var body: CollisionObject2D = hit["collider"] as CollisionObject2D
	var owner_node: Object = body.shape_owner_get_owner(body.shape_find_owner(int(hit["shape"])))
	var shape_name: String = (owner_node as Node).name
	var prefix := RegEx.create_from_string("^[A-Za-z]+")
	return prefix.search(shape_name).get_string() if shape_name != "Shape" else prefix.search(String(body.name)).get_string()


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
	await _sync(map)
	return map


func _sync(map: RID) -> void:
	var before: int = NavigationServer2D.map_get_iteration_id(map)
	NavigationServer2D.map_force_update(map)
	for i: int in 30:
		if NavigationServer2D.map_get_iteration_id(map) > before:
			return
		await tree().physics_frame
	fail("gezinme haritası eşitlenmedi")


func _leave(level: Level, map: RID) -> void:
	tree().root.remove_child(level)
	NavigationServer2D.free_rid(map)


func _path(map: RID, from: Vector2, to: Vector2) -> PackedVector2Array:
	return NavigationServer2D.map_get_path(map, from, to, true)


static func _arrives(path: PackedVector2Array, to: Vector2) -> bool:
	return path.size() >= 2 and path[path.size() - 1].distance_to(to) <= ARRIVE


static func _passes(path: PackedVector2Array, door: Vector2) -> bool:
	for p: Vector2 in path:
		if p.distance_to(door) <= DOOR_PASS:
			return true
	return false


static func _length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
