extends TestCase
## IS-010: seviye kökü `Level` (levels/level.gd) ve S4 API'si (KR-018): kök düğümler, doğma noktaları
## (players_root koordinatında, ağaç dışında da), işaret araması; üreticinin kök betiği ataması ve
## idempotentliği; gerçek seviyelerin ve test fikstürlerinin Level kökü taşıması.

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
		# Ağaç dışında hesaplanan konum, ağaçtaki global dönüşümle aynı olmalı.
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
	level.position = Vector2(1000, 1000)  # kökün kendi dönüşümü sonucu etkilemez
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
	eq(level.map_rect(), Rect2(), "Tiles yoksa harita dikdörtgeni boş")


## IS-027: harita dikdörtgeni = Tiles ızgarasının tamamı (sınır dolgusu dahil), köke göre.
func test_map_rect() -> void:
	var store: Level = autofree((load(LEVELS[0]) as PackedScene).instantiate()) as Level
	store.position = Vector2(500, 500)  # kökün kendi dönüşümü dahil değil
	eq(store.map_rect(), Rect2(0, 0, 960, 640), "store_a 30×20 karo")
	var arena: Level = autofree((load(LEVELS[1]) as PackedScene).instantiate()) as Level
	var tiles: LevelLayout = arena.get_node("Tiles") as LevelLayout
	eq(arena.map_rect().size, Vector2(tiles.size_in_tiles() * LevelLayout.TILE), "test_arena ızgarası")
	var fixture: Level = autofree((load(LEVELS[2]) as PackedScene).instantiate()) as Level
	eq(fixture.map_rect(), Rect2(), "Tiles'sız fikstür")
	# Kaydırılmış Tiles ve boş ızgara.
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
	# Eski biçim: kökü düz Node2D olan, Props altında elle eklenmiş düğüm taşıyan sahne.
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


# --- yardımcılar ---

## Kaydırılmış kaplarla küçük bir seviye: SpawnPoints (400, 0), Players (10, 20), 3 doğma noktası, 1 işaret.
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
