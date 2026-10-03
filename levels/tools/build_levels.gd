extends SceneTree
## Level generator (US-002): writes the levels/<name>.tscn scene in the S4 layout from the levels/layouts/<name>.txt ASCII layout.
##   $GODOT --headless --path . -s res://levels/tools/build_levels.gd [-- store_a test_arena]
## With no name, every .txt under levels/layouts/ is generated. If the scene exists only the generated nodes (Tiles, Walls, SpawnPoints, Markers, Zones, Navigation) are rebuilt;
## Players, Props, NPCs and other hand-added nodes are kept. Layout changes go in the .txt, never hand-edit the .tscn (tests/unit/test_levels*.gd check scene/grid consistency).
##
## Layout file: a line starting with `;` is a comment; `@ <letter> <Marker name> <floor char>` defines a marker (each letter appears exactly once in the grid; `Spawn*` names go to SpawnPoints, others to Markers);
## `= <letter> <Zone name> <floor char>` defines a zone (the letter's cells form a filled rectangle; `@` markers inside count toward it; `Zones/<name>` Area2D, triggers layer);
## `= <Zone name> <col> <row> <width> <height>` is an unpainted rectangle zone piece (IS-023: rooms with shelves/markers cannot be painted; a repeated name makes a zone of several rectangles, shapes `Shape`, `Shape2` ... in order);
## the remaining lines are an equal-width tile grid (legend: levels/level_layout.gd). US-007 additions (glass, zones, navigation): see `_build_walls`, `_build_zones`, `_build_navigation`.

const LAYOUT_DIR := "res://levels/layouts"
const LEVEL_DIR := "res://levels"
## Generated nodes; scene order matches S4 (Tiles draws at the bottom).
const ORDER: Array[String] = ["Tiles", "Walls", "SpawnPoints", "Players", "Props", "NPCs", "Markers", "Zones", "Navigation"]
const GENERATED: Array[String] = ["Tiles", "Walls", "SpawnPoints", "Markers", "Zones", "Navigation"]
const WORLD_LAYER := PhysicsLayers.WORLD  # mimari.md §4: layer 1 `world`
const PLAYERS_LAYER := PhysicsLayers.PLAYERS  # §4: layer 2 `players`
const TRIGGERS_LAYER := PhysicsLayers.TRIGGERS  # §4: layer 5 `triggers`
## Group of sight-passing bodies (S11 Phase 2 addendum; perception skips colliders in this group).
const SEE_THROUGH_GROUP := PhysicsLayers.SEE_THROUGH_GROUP
## Types built as their own StaticBody2D (+ `Shape` child) in a sight-passing group: glass and the low obstacle (IS-098: counter
## stops walking, passes sight and sound for everyone). Group membership works per body, so these cannot share the `Walls` body.
const OWN_BODY_GROUP := {
	LevelLayout.Kind.WINDOW: PhysicsLayers.SEE_THROUGH_GROUP,
	LevelLayout.Kind.COUNTER: PhysicsLayers.LOW_OBSTACLE_GROUP,
}
## Navigation agent radius (px): character diameter ~24 px (S4); the bake grows obstacles by this much.
const NAV_AGENT_RADIUS := 12.0
const LAYOUT_SCRIPT := preload("res://levels/level_layout.gd")
## Root script (S4 Level API, KR-018).
const LEVEL_SCRIPT := preload("res://levels/level.gd")
const SOLID_ORDER: Array[LevelLayout.Kind] = [
	LevelLayout.Kind.BOUND, LevelLayout.Kind.WALL, LevelLayout.Kind.WINDOW,
	LevelLayout.Kind.SHELF, LevelLayout.Kind.COUNTER, LevelLayout.Kind.COOLER, LevelLayout.Kind.CRATE,
]


func _initialize() -> void:
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		for f: String in DirAccess.get_files_at(LAYOUT_DIR):
			if f.ends_with(".txt"):
				names.append(f.get_basename())
	var code: int = 0
	for level_name: String in names:
		var err: Error = build(level_name)
		if err != OK:
			push_error("build_levels: %s üretilemedi (%s)" % [level_name, error_string(err)])
			code = 1
	quit(code)


## Generates one level: layouts/<name>.txt -> <name>.tscn.
static func build(level_name: String) -> Error:
	return build_scene(LAYOUT_DIR.path_join(level_name + ".txt"), LEVEL_DIR.path_join(level_name + ".tscn"), true)


## Writes the scene from the layout file (tests also call it with a temp path). Existing nodes are reused by name;
## if the layout is unchanged the scene file is unchanged too (unique_ids, scene uid and sub-scene instance values are kept).
static func build_scene(layout_path: String, scene_path: String, verbose: bool = false) -> Error:
	var layout: Dictionary = parse_layout(layout_path)
	if layout.is_empty():
		return ERR_PARSE_ERROR
	var uid_text: String = _header_uid(scene_path)
	if uid_text.is_empty():
		uid_text = ResourceUID.id_to_text(ResourceUID.create_id())
	var root: Node2D = _open_root(scene_path, layout_path.get_file().get_basename().to_pascal_case())

	var tiles: LevelLayout = _ensure(root, "Tiles", "Node2D", LAYOUT_SCRIPT) as LevelLayout
	tiles.rows = layout["rows"]
	_build_walls(_ensure(root, "Walls", "StaticBody2D") as StaticBody2D, tiles)

	var spawns: Node2D = _ensure(root, "SpawnPoints", "Node2D") as Node2D
	var markers: Node2D = _ensure(root, "Markers", "Node2D") as Node2D
	var keep: Dictionary = {}  # generated node -> true
	var doors: Array[Marker2D] = []  # markers on door tiles (navigation links)
	for m: Dictionary in layout["markers"]:
		var marker_name: String = m["name"]
		var parent: Node2D = spawns if marker_name.begins_with("Spawn") else markers
		var marker: Marker2D = _ensure(parent, marker_name, "Marker2D") as Marker2D
		parent.move_child(marker, -1)
		var cell: Vector2i = m["cell"]
		marker.position = LevelLayout.cell_center(cell)
		# Door orientation: 0 = gap in a horizontal wall (door along x), 90 = vertical wall.
		var is_door: bool = tiles.kind_at(cell) == LevelLayout.Kind.DOOR
		marker.rotation_degrees = 90.0 if is_door and not _is_horizontal_gap(tiles, cell) else 0.0
		if is_door:
			doors.append(marker)
		keep[marker] = true
	_prune(spawns, keep)
	_prune(markers, keep)
	_build_zones(_ensure(root, "Zones", "Node2D") as Node2D, layout["zones"])
	_build_navigation(_ensure(root, "Navigation", "NavigationRegion2D") as NavigationRegion2D, tiles, doors)

	for child_name: String in ORDER:
		if root.get_node_or_null(NodePath(child_name)) == null:
			var empty := Node2D.new()
			empty.name = child_name
			root.add_child(empty)
	for i: int in ORDER.size():
		root.move_child(root.get_node(NodePath(ORDER[i])), i)
	for child_name: String in ORDER:
		_own(root.get_node(NodePath(child_name)), root, GENERATED.has(child_name))

	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, scene_path)
	if err == OK:
		err = _write_uids(scene_path, uid_text)
	if err == OK and verbose:
		var size: Vector2i = tiles.size_in_tiles()
		var nav: NavigationPolygon = (root.get_node("Navigation") as NavigationRegion2D).navigation_polygon
		print("%s: %d×%d karo, %d şekil, %d spawn, %d işaret, %d bölge, %d gezinme çokgeni, %d kapı bağı" % [
			scene_path, size.x, size.y, root.get_node("Walls").get_child_count(),
			spawns.get_child_count(), markers.get_child_count(), root.get_node("Zones").get_child_count(),
			nav.get_polygon_count(), doors.size()])
	root.free()
	return err


## Reads the layout file: {"rows": PackedStringArray (markers turned back to floor), "markers": [{name, cell}],
## "zones": [{name, rects: Array[Rect2i] (tiles)}]} (zones in first-definition order). On error reports via push_error and returns an empty dictionary.
static func parse_layout(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("build_levels: düzen okunamadı: " + path)
		return {}
	var defs: Dictionary = {}  # letter -> [name, floor char]
	var zone_defs: Dictionary = {}  # letter -> [name, floor char]
	var zone_order: Array[String] = []  # zone names, in first-definition order
	var rect_zones: Dictionary = {}  # unpainted zone name -> Array[Rect2i]
	var grid: PackedStringArray = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges(false, true)
		if line.is_empty() or line.begins_with(";"):
			continue
		if line.begins_with("=") and line.split(" ", false).size() == 6:
			var rect: Rect2i = _parse_zone_rect(line.split(" ", false))
			var zone_name: String = line.split(" ", false)[1]
			if not rect.has_area() or _painted_zone_named(zone_defs, zone_name):
				push_error("build_levels: %s: geçersiz bölge dikdörtgeni satırı '%s'" % [path, line])
				return {}
			if not rect_zones.has(zone_name):
				rect_zones[zone_name] = []
				zone_order.append(zone_name)
			(rect_zones[zone_name] as Array).append(rect)
			continue
		if line.begins_with("@") or line.begins_with("="):
			var parts: PackedStringArray = line.split(" ", false)
			if parts.size() != 4 or parts[1].length() != 1 or parts[3].length() != 1 \
					or not LevelLayout.LEGEND.has(parts[3]) or LevelLayout.LEGEND.has(parts[1]) \
					or defs.has(parts[1]) or zone_defs.has(parts[1]) or parts[2].validate_node_name() != parts[2] \
					or (line.begins_with("=") and (zone_order.has(parts[2]))):
				push_error("build_levels: %s: geçersiz işaret/bölge satırı '%s'" % [path, line])
				return {}
			(defs if line.begins_with("@") else zone_defs)[parts[1]] = [parts[2], parts[3]]
			if line.begins_with("="):
				zone_order.append(parts[2])
			continue
		grid.append(line)
	if grid.is_empty():
		push_error("build_levels: %s: ızgara yok" % path)
		return {}
	var width: int = grid[0].length()
	var rows: PackedStringArray = []
	var seen: Dictionary = {}  # marker letter -> cell
	var zone_cells: Dictionary = {}  # zone letter -> Array[Vector2i]
	for y: int in grid.size():
		if grid[y].length() != width:
			push_error("build_levels: %s: %d. satır genişliği %d, beklenen %d" % [path, y + 1, grid[y].length(), width])
			return {}
		var row: String = ""
		for x: int in width:
			var ch: String = grid[y][x]
			if defs.has(ch):
				if seen.has(ch):
					push_error("build_levels: %s: işaret '%s' birden çok kez" % [path, ch])
					return {}
				seen[ch] = Vector2i(x, y)
				row += String(defs[ch][1])
			elif zone_defs.has(ch):
				if not zone_cells.has(ch):
					zone_cells[ch] = []
				(zone_cells[ch] as Array).append(Vector2i(x, y))
				row += String(zone_defs[ch][1])
			elif LevelLayout.LEGEND.has(ch):
				row += ch
			else:
				push_error("build_levels: %s: bilinmeyen karakter '%s' (%d, %d)" % [path, ch, x, y])
				return {}
		rows.append(row)
	var markers: Array[Dictionary] = []  # in definition order
	for ch: String in defs:
		if not seen.has(ch):
			push_error("build_levels: %s: işaret '%s' ızgarada yok" % [path, ch])
			return {}
		markers.append({"name": defs[ch][0], "cell": seen[ch]})
	var painted: Dictionary = {}  # painted zone name -> rectangle
	for ch: String in zone_defs:
		var rect: Rect2i = _zone_rect(zone_cells.get(ch, []), seen.values())
		if rect.has_area():
			painted[zone_defs[ch][0]] = rect
		else:
			push_error("build_levels: %s: bölge '%s' ızgarada yok ya da dolu dikdörtgen değil" % [path, ch])
			return {}
	var bounds := Rect2i(0, 0, width, grid.size())
	var zones: Array[Dictionary] = []  # in first-definition order
	for zone_name: String in zone_order:
		var rects: Array[Rect2i] = []
		if painted.has(zone_name):
			rects.append(painted[zone_name] as Rect2i)
		for rect: Rect2i in rect_zones.get(zone_name, []):
			if not bounds.encloses(rect):
				push_error("build_levels: %s: bölge '%s' dikdörtgeni %s ızgara dışına taşıyor" % [path, zone_name, rect])
				return {}
			rects.append(rect)
		zones.append({"name": zone_name, "rects": rects})
	return {"rows": rows, "markers": markers, "zones": zones}


## Rectangle of a `= <name> <col> <row> <width> <height>` line; empty rectangle if the name is not a node name or the numbers
## are invalid (negative position, zero/negative size).
static func _parse_zone_rect(parts: PackedStringArray) -> Rect2i:
	if parts[1].validate_node_name() != parts[1]:
		return Rect2i()
	var nums: Array[int] = []
	for i: int in range(2, 6):
		if not parts[i].is_valid_int():
			return Rect2i()
		nums.append(parts[i].to_int())
	if nums[0] < 0 or nums[1] < 0 or nums[2] <= 0 or nums[3] <= 0:
		return Rect2i()
	return Rect2i(nums[0], nums[1], nums[2], nums[3])


static func _painted_zone_named(zone_defs: Dictionary, zone_name: String) -> bool:
	for ch: String in zone_defs:
		if zone_defs[ch][0] == zone_name:
			return true
	return false


## Rectangle covered by a zone's cells; empty rectangle if the cells (with markers in between) do not fill it exactly.
static func _zone_rect(cells: Array, marker_cells: Array) -> Rect2i:
	if cells.is_empty():
		return Rect2i()
	var rect := Rect2i(cells[0] as Vector2i, Vector2i.ONE)
	for cell: Vector2i in cells:
		rect = rect.merge(Rect2i(cell, Vector2i.ONE))
	var covered: int = cells.size()
	for cell: Variant in marker_cells:
		if rect.has_point(cell as Vector2i):
			covered += 1
	return rect if covered == rect.get_area() else Rect2i()


## Collision shapes: merged rectangles per type, named <Prefix><n> (Bound/Wall/Window/Shelf/Counter; US-033: Cooler/Crate - solid obstacle, `Walls` shape on the world layer: collides and blocks sight).
## Glass (`Window<n>`) is a separate StaticBody2D + `Shape` child in the `see_through` group: a line-of-sight query returns the collider as a body, so glass needs its own body to be told apart from a wall (KR-019 K1).
## The counter (`Counter<n>`, IS-098) is built the same way in the `low_obstacle` group (OWN_BODY_GROUP); still on the world layer (collides).
static func _build_walls(walls: StaticBody2D, tiles: LevelLayout) -> void:
	walls.collision_layer = WORLD_LAYER
	walls.collision_mask = 0
	var keep: Dictionary = {}
	for kind: LevelLayout.Kind in SOLID_ORDER:
		var prefix: String = LevelLayout.SOLID_PREFIX[kind]
		var n: int = 0
		for cells: Rect2i in tiles.merged_rects(kind):
			n += 1
			var rect: Rect2 = LevelLayout.shape_rect(kind, cells)
			var node_name: String = "%s%d" % [prefix, n]
			var node: Node2D
			var cs: CollisionShape2D
			if OWN_BODY_GROUP.has(kind):
				var body: StaticBody2D = _ensure(walls, node_name, "StaticBody2D") as StaticBody2D
				body.collision_layer = WORLD_LAYER
				body.collision_mask = 0
				body.add_to_group(OWN_BODY_GROUP[kind] as StringName, true)
				cs = _ensure(body, "Shape", "CollisionShape2D") as CollisionShape2D
				cs.position = Vector2.ZERO
				_prune(body, {cs: true})
				node = body
			else:
				cs = _ensure(walls, node_name, "CollisionShape2D") as CollisionShape2D
				node = cs
			walls.move_child(node, -1)
			node.position = rect.get_center()
			cs.shape = _rect_shape(rect.size, "%s_%d" % [prefix, n])
			keep[node] = true
	_prune(walls, keep)


## Zones: `Zones/<name>` Area2D (triggers layer, tracks players) + one shape per rectangle (`Shape`, `Shape2` ...).
## The zone root sits at the centre of the rectangles' bounds (with a single rectangle the shape is at the centre).
static func _build_zones(zones: Node2D, defs: Array) -> void:
	var keep: Dictionary = {}
	for z: Dictionary in defs:
		var zone_name: String = z["name"]
		var rects: Array = z["rects"]
		var bounds: Rect2i = rects[0]
		for cells: Rect2i in rects:
			bounds = bounds.merge(cells)
		var area: Area2D = _ensure(zones, zone_name, "Area2D") as Area2D
		zones.move_child(area, -1)
		area.position = (Vector2(bounds.position) + Vector2(bounds.size) / 2.0) * LevelLayout.TILE
		area.collision_layer = TRIGGERS_LAYER
		area.collision_mask = PLAYERS_LAYER
		area.monitorable = false
		var shapes: Dictionary = {}
		for i: int in rects.size():
			var cells: Rect2i = rects[i]
			var suffix: String = "" if i == 0 else str(i + 1)
			var cs: CollisionShape2D = _ensure(area, "Shape" + suffix, "CollisionShape2D") as CollisionShape2D
			area.move_child(cs, -1)
			cs.position = (Vector2(cells.position) + Vector2(cells.size) / 2.0) * LevelLayout.TILE - area.position
			cs.shape = _rect_shape(Vector2(cells.size) * LevelLayout.TILE, "Zone_" + zone_name + ("" if i == 0 else "_" + suffix))
			shapes[cs] = true
		_prune(area, shapes)
		keep[area] = true
	_prune(zones, keep)


## Navigation: one region baked from the layout + one link per door (`Navigation/<door marker name>`, NavigationLink2D).
## The door tile blocks the polygon; passage goes through the link; closed door = link `enabled = false` (set by the system wiring the door).
static func _build_navigation(region: NavigationRegion2D, tiles: LevelLayout, doors: Array[Marker2D]) -> void:
	var door_cells: Array[Vector2i] = []
	var keep: Dictionary = {}
	for door: Marker2D in doors:
		door_cells.append(LevelLayout.cell_of(door.position))
		var link: NavigationLink2D = _ensure(region, door.name, "NavigationLink2D") as NavigationLink2D
		region.move_child(link, -1)
		link.position = door.position
		# Axis crossing the door perpendicularly: 0 deg (horizontal wall) -> y, 90 deg (vertical wall) -> x; ends are the centres of the tiles on either side.
		var across: Vector2 = Vector2.RIGHT if is_equal_approx(door.rotation_degrees, 90.0) else Vector2.DOWN
		link.start_position = -across * LevelLayout.TILE
		link.end_position = across * LevelLayout.TILE
		keep[link] = true
	_prune(region, keep)
	region.navigation_polygon = bake_navigation(tiles, door_cells)


## The layout's navigation polygon: the map rectangle is walkable; all colliding shapes (shelf/counter with inset) and
## `blocked_cells` (door tiles; passage via links) are obstacles; agent radius NAV_AGENT_RADIUS. Synchronous and deterministic (tests re-bake from the same input and compare with the scene).
static func bake_navigation(tiles: LevelLayout, blocked_cells: Array[Vector2i]) -> NavigationPolygon:
	var poly := NavigationPolygon.new()
	poly.agent_radius = NAV_AGENT_RADIUS
	poly.resource_scene_unique_id = "Navigation_poly"
	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(_outline(Rect2(Vector2.ZERO, Vector2(tiles.size_in_tiles()) * LevelLayout.TILE)))
	for kind: LevelLayout.Kind in SOLID_ORDER:
		for cells: Rect2i in tiles.merged_rects(kind):
			source.add_obstruction_outline(_outline(LevelLayout.shape_rect(kind, cells)))
	for cell: Vector2i in blocked_cells:
		source.add_obstruction_outline(_outline(Rect2(Vector2(cell) * LevelLayout.TILE, Vector2.ONE * LevelLayout.TILE)))
	NavigationServer2D.bake_from_source_geometry_data(poly, source)
	return poly


static func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _rect_shape(size: Vector2, unique_id: String) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	shape.resource_scene_unique_id = unique_id
	return shape


## Returns the named child; replaces it with a new one if missing or of a different type/script.
static func _ensure(parent: Node, child_name: String, cls: String, script: Script = null) -> Node:
	var node: Node = parent.get_node_or_null(NodePath(child_name))
	if node != null and node.get_class() == cls and node.get_script() == script:
		return node
	var index: int = -1
	if node != null:
		index = node.get_index()
		parent.remove_child(node)
		node.free()
	node = ClassDB.instantiate(cls) as Node
	if script != null:
		node.set_script(script)
	node.name = child_name
	parent.add_child(node)
	if index >= 0:
		parent.move_child(node, index)
	return node


## Deletes children of the generated container not built this run (shape/marker removed from the layout).
static func _prune(parent: Node, keep: Dictionary) -> void:
	for child: Node in parent.get_children():
		if not keep.has(child):
			parent.remove_child(child)
			child.free()


## The root always carries LEVEL_SCRIPT (an old scene's root also moves to this script).
static func _open_root(scene_path: String, root_name: String) -> Node2D:
	var root: Node2D = null
	if ResourceLoader.exists(scene_path):
		var existing: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if existing != null:
			# Edit mode: sub-scene instances are repacked with only their changed values (like the editor).
			root = existing.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
		if root == null:
			push_warning("build_levels: %s açılamadı, sıfırdan kuruluyor" % scene_path)
	if root == null:
		root = Node2D.new()
		root.name = root_name
	if root.get_script() != LEVEL_SCRIPT:
		root.set_script(LEVEL_SCRIPT)
	return root


## The uid ("uid://...") in the existing scene's header; empty if none.
static func _header_uid(scene_path: String) -> String:
	if not FileAccess.file_exists(scene_path):
		return ""
	var file := FileAccess.open(scene_path, FileAccess.READ)
	var header: String = file.get_line() if file != null else ""
	var found: RegExMatch = RegEx.create_from_string('uid="(uid://[0-9a-z]+)"').search(header)
	return found.get_string(1) if found != null else ""


## Writes the scene uid into the header and resource uids into ext_resource lines (the format the editor saves).
## ResourceSaver writes no uids in headless script mode; this keeps the file unchanged if the editor saves later.
static func _write_uids(scene_path: String, uid_text: String) -> Error:
	var lines: PackedStringArray = FileAccess.get_file_as_string(scene_path).split("\n")
	if lines.is_empty() or not lines[0].begins_with("[gd_scene"):
		return ERR_FILE_CORRUPT
	if not lines[0].contains(" uid="):
		lines[0] = lines[0].trim_suffix("]") + ' uid="%s"]' % uid_text
	var ext := RegEx.create_from_string('^\\[ext_resource type="([^"]+)" path="([^"]+)"')
	for i: int in lines.size():
		var found: RegExMatch = ext.search(lines[i])
		if found == null:
			continue
		var res_uid: int = ResourceLoader.get_resource_uid(found.get_string(2))
		if res_uid != ResourceUID.INVALID_ID:
			lines[i] = lines[i].replace('type="%s" path=' % found.get_string(1),
				'type="%s" uid="%s" path=' % [found.get_string(1), ResourceUID.id_to_text(res_uid)])
	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	return OK


static func _is_horizontal_gap(tiles: LevelLayout, cell: Vector2i) -> bool:
	return LevelLayout.is_solid(tiles.kind_at(cell + Vector2i.LEFT)) \
		and LevelLayout.is_solid(tiles.kind_at(cell + Vector2i.RIGHT))


## Ownership: in generated containers the whole subtree is owned by the root; in kept containers only the container itself.
static func _own(node: Node, owner_node: Node, recursive: bool) -> void:
	if node.owner == null:
		node.owner = owner_node
	if recursive:
		for child: Node in node.get_children():
			_own(child, owner_node, true)
