extends TestCase
## IS-010: level root `Level` (levels/level.gd) and the S4 API (KR-018): root nodes, spawn points (in players_root
## coordinates, also outside the tree), marker lookup; the generator's root script assignment and idempotence; real
## levels and test fixtures carry a Level root.

const LEVELS: Array[String] = [
	"res://levels/store_a.tscn", "res://levels/test_arena.tscn",
	"res://tests/fixtures/empty_level.tscn", "res://tests/fixtures/empty_level_b.tscn",
]
const BUILDER := "res://levels/tools/build_levels.gd"
const LAYOUT := "res://levels/layouts/test_arena.txt"
const TMP_DIR := "user://test_levels_api"


func test_levels_and_fixtures_use_level_root() -> void:
	for path: String in LEVELS:
		var scene: PackedScene = load(path) as PackedScene
		if not is_true(scene != null, "%s yüklenemedi" % path):
			continue
		var level: Level = autofree(scene.instantiate()) as Level
		if not is_true(level != null, "%s: kök Level olmalı (S4)" % path):
			continue
		is_true(level.players_root() == level.get_node_or_null("Players") and level.players_root() != null, "%s: players_root" % path)
		is_true(level.props_root() == level.get_node_or_null("Props") and level.props_root() != null, "%s: props_root" % path)
		is_true(level.npcs_root() == level.get_node_or_null("NPCs") and level.npcs_root() != null, "%s: npcs_root" % path)
		eq(level.spawn_count(), 4, "%s: Spawn1..4" % path)
		# A position computed outside the tree must equal the global transform in the tree.
		var outside: Array[Vector2] = []
		for i: int in level.spawn_count():
			outside.append(level.spawn_position(i))
		tree().root.add_child(level)
		var players: Node2D = level.players_root()
		for i: int in level.spawn_count():
			var spawn: Node2D = level.get_node("SpawnPoints/Spawn%d" % (i + 1)) as Node2D
			near(outside[i], players.to_local(spawn.global_position), 0.001, "%s: spawn_position(%d)" % [path, i])
		tree().root.remove_child(level)


func test_spawn_position_frames_and_wraps() -> void:
	var level: Level = autofree(_make_level()) as Level
	level.position = Vector2(1000, 1000)  # the root's own transform does not affect the result
	eq(level.spawn_count(), 3)
	# Spawn1 = (5, 6) + SpawnPoints (400, 0) - Players (10, 20)
	eq(level.spawn_position(0), Vector2(395, -14))
	eq(level.spawn_position(2), Vector2(400, -20), "Spawn3 = (10, 0) + (400, 0) - (10, 20)")
	eq(level.spawn_position(3), level.spawn_position(0), "sayıdan büyük indeks çevrilir")
	eq(level.spawn_position(-1), level.spawn_position(2), "negatif indeks sondan")


func test_marker_lookup() -> void:
	var level: Level = autofree(_make_level()) as Level
	is_true(level.marker(&"Register") == level.get_node("Markers/Register"), "Markers altındaki işaret")
	is_true(level.marker(&"Spawn1") == null, "doğma noktası yerleşim işareti değildir")
	is_true(level.marker(&"Yok") == null, "olmayan işaret null")
	is_true(level.marker(&"") == null, "boş ad null")
	is_true(level.marker(&"../Players") == null, "yol parçası içeren ad null")
	is_true(level.marker(&"Register/Child") == null, "alt yol null")
	var store: Level = autofree((load(LEVELS[0]) as PackedScene).instantiate()) as Level
	for marker_name: StringName in [&"FrontDoor", &"BackDoor", &"Register", &"Counter", &"Exit"]:
		var marker: Node2D = store.marker(marker_name)
		is_true(marker != null and marker == store.get_node("Markers/" + marker_name), "store_a: %s" % marker_name)


func test_missing_children_are_safe() -> void:
	var level: Level = autofree(Level.new()) as Level
	is_true(level.players_root() == null and level.props_root() == null and level.npcs_root() == null)
	eq(level.spawn_count(), 0)
	eq(level.spawn_position(0), Vector2.ZERO)
	is_true(level.marker(&"Exit") == null)
	eq(level.marker_sequence(&"StreetRoute").size(), 0)
	is_true(level.zone(&"EscapeZone") == null and level.navigation_region() == null and level.door_link(&"BackDoor") == null)
	eq(level.map_rect(), Rect2(), "Tiles yoksa harita dikdörtgeni boş")


func test_sequence_zone_and_navigation_lookup() -> void:
	# US-007 API addition: ordered markers, trigger zones, navigation region and door links.
	var level: Level = autofree(_make_level()) as Level
	var markers: Node = level.get_node("Markers")
	for n: int in [2, 1, 4]:  # scene order is independent of the number; 3 missing -> the array ends at 2
		_child(markers, "Patrol%d" % n, Vector2(n, 0), true)
	var sequence: Array[Node2D] = level.marker_sequence(&"Patrol")
	eq(sequence.size(), 2, "ilk eksik numarada durur")
	if sequence.size() == 2:
		is_true(sequence[0] == markers.get_node("Patrol1") and sequence[1] == markers.get_node("Patrol2"), "numara sırası")
	eq(level.marker_sequence(&"Yok").size(), 0)
	var zones := _child(level, "Zones", Vector2.ZERO)
	var area := Area2D.new()
	area.name = "EscapeZone"
	zones.add_child(area)
	var region := NavigationRegion2D.new()
	region.name = "Navigation"
	level.add_child(region)
	var link := NavigationLink2D.new()
	link.name = "BackDoor"
	region.add_child(link)
	is_true(level.zone(&"EscapeZone") == area, "Zones altındaki bölge")
	is_true(level.zone(&"../Markers") == null and level.zone(&"") == null, "yol parçası/boş ad null")
	is_true(level.navigation_region() == region, "gezinme bölgesi")
	is_true(level.door_link(&"BackDoor") == link, "kapı bağı")
	is_true(level.door_link(&"FrontDoor") == null and level.door_link(&"BackDoor/x") == null, "olmayan bağ null")
	var store: Level = autofree((load(LEVELS[0]) as PackedScene).instantiate()) as Level
	eq(store.marker_sequence(&"StreetRoute").size(), 6, "store_a: StreetRoute1..6 (IS-023)")
	is_true(store.zone(&"EscapeZone") != null and store.navigation_region() != null, "store_a: EscapeZone ve Navigation")
	for door: StringName in [&"FrontDoor", &"BackDoor", &"BackroomDoor"]:
		is_true(store.door_link(door) != null, "store_a: %s bağı" % door)


## IS-027: map rectangle = the whole Tiles grid (incl. border padding), relative to the root.
func test_map_rect() -> void:
	var store: Level = autofree((load(LEVELS[0]) as PackedScene).instantiate()) as Level
	store.position = Vector2(500, 500)  # the root's own transform is not included
	eq(store.map_rect(), Rect2(0, 0, 960, 640), "store_a 30×20 karo")
	var arena: Level = autofree((load(LEVELS[1]) as PackedScene).instantiate()) as Level
	var tiles: LevelLayout = arena.get_node("Tiles") as LevelLayout
	eq(arena.map_rect().size, Vector2(tiles.size_in_tiles() * LevelLayout.TILE), "test_arena ızgarası")
	var fixture: Level = autofree((load(LEVELS[2]) as PackedScene).instantiate()) as Level
	eq(fixture.map_rect(), Rect2(), "Tiles'sız fikstür")
	# Shifted Tiles and an empty grid.
	var level: Level = autofree(Level.new()) as Level
	var layout := LevelLayout.new()
	layout.name = "Tiles"
	layout.position = Vector2(64, -32)
	layout.rows = PackedStringArray(["%%%", "%.%"])
	level.add_child(layout)
	eq(level.map_rect(), Rect2(64, -32, 96, 64))
	layout.rows = PackedStringArray()
	eq(level.map_rect(), Rect2(), "boş ızgara")


func test_builder_assigns_level_root_and_stays_idempotent() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	if not is_true(builder != null, "üretici yüklenemedi"):
		return
	_clear_tmp()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	# Old format: a scene whose root is a plain Node2D, with a node hand-added under Props.
	var old_path: String = TMP_DIR.path_join("old.tscn")
	var old_root := Node2D.new()
	old_root.name = "TestArena"
	var props := Node2D.new()
	props.name = "Props"
	old_root.add_child(props)
	props.owner = old_root
	var kept := Node2D.new()
	kept.name = "Kept"
	props.add_child(kept)
	kept.owner = old_root
	var packed := PackedScene.new()
	eq(packed.pack(old_root), OK)
	old_root.free()
	eq(ResourceSaver.save(packed, old_path), OK)
	var new_path: String = TMP_DIR.path_join("new.tscn")
	for path: String in [old_path, new_path]:
		eq(builder.call("build_scene", LAYOUT, path), OK, "%s üretimi" % path.get_file())
		var first: String = FileAccess.get_file_as_string(path)
		eq(builder.call("build_scene", LAYOUT, path), OK, "%s yeniden üretim" % path.get_file())
		is_true(FileAccess.get_file_as_string(path) == first, "%s: yeniden üretim dosyayı değiştirmemeli" % path.get_file())
		has(first, 'path="res://levels/level.gd"', "%s: kök betik kaynağı" % path.get_file())
		var level: Level = autofree((ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()) as Level
		if is_true(level != null, "%s: kök Level olmalı" % path.get_file()):
			eq(level.spawn_count(), 4)
			is_true(level.players_root() != null and level.marker(&"Exit") != null)
			if path == old_path:
				is_true(level.props_root().get_node_or_null("Kept") != null, "Props altındaki düğüm korunur")
	_clear_tmp()


# --- helpers ---

## A small level with shifted containers: SpawnPoints (400, 0), Players (10, 20), 3 spawn points, 1 marker.
func _make_level() -> Level:
	var level := Level.new()
	var spawns := _child(level, "SpawnPoints", Vector2(400, 0))
	_child(spawns, "Spawn1", Vector2(5, 6), true)
	_child(spawns, "Spawn2", Vector2(50, 6), true)
	_child(spawns, "Spawn3", Vector2(10, 0), true)
	_child(level, "Players", Vector2(10, 20))
	var markers := _child(level, "Markers", Vector2.ZERO)
	var register := _child(markers, "Register", Vector2(1, 1), true)
	_child(register, "Child", Vector2.ZERO, true)
	return level


static func _child(parent: Node, child_name: String, pos: Vector2, marker: bool = false) -> Node2D:
	var node: Node2D = Marker2D.new() if marker else Node2D.new()
	node.name = child_name
	node.position = pos
	parent.add_child(node)
	return node


static func _clear_tmp() -> void:
	if not DirAccess.dir_exists_absolute(TMP_DIR):
		return
	for f: String in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))
	DirAccess.remove_absolute(TMP_DIR)
