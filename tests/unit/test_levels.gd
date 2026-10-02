extends TestCase
## US-002: seviye sahneleri (mimari.md S4, S9; GDD §9 T1).
## Zorunlu düğümler ve işaretler, spawn güvenliği, kapı boşlukları, kapılardan kasaya yol (ızgara BFS'i),
## sabit renk yokluğu ve sahnenin düzen kaynağıyla (levels/layouts/*.txt) güncelliği.
## Yürünebilirlik ızgarası `Walls` çarpışma şekillerinden çıkarılır; `Tiles` düzenine güvenmez, onunla ayrıca karşılaştırılır.

const STORE := "res://levels/store_a.tscn"
const ARENA := "res://levels/test_arena.tscn"
const LEVELS: Array[String] = [STORE, ARENA]
const BUILDER := "res://levels/tools/build_levels.gd"
const LAYOUT_DIR := "res://levels/layouts"
const TMP_DIR := "user://test_levels_roundtrip"  # gidiş-dönüş testi depodaki sahnelere dokunmaz

const TILE := 32
const CHAR_RADIUS := 12.0     # karakter çapı ~24 px (S4)
const INTERACT_RANGE := 40.0  # Interactable.interact_range varsayılanı (S7)
const WORLD_LAYER := PhysicsLayers.WORLD  # mimari.md §4 katman 1

const REQUIRED: Array[String] = ["Walls", "SpawnPoints", "Players", "Props", "NPCs", "Markers"]
const MARKERS: Array[String] = ["FrontDoor", "BackDoor", "Register", "Counter", "ClerkSpot", "BackroomSafe", "Exit"]
const SPAWNS: Array[String] = ["Spawn1", "Spawn2", "Spawn3", "Spawn4"]
const STORE_DOORS: Array[String] = ["FrontDoor", "BackDoor", "BackroomDoor"]
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Karo ızgarası: hücre, karakter (çap ~24 px) merkezde durup komşu hücre merkezine düz yürüyebiliyorsa açık.
class Grid:
	extends RefCounted
	var origin: Vector2i
	var size: Vector2i
	var blocked := PackedByteArray()

	func has_cell(cell: Vector2i) -> bool:
		var c: Vector2i = cell - origin
		return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

	func is_open(cell: Vector2i) -> bool:
		return has_cell(cell) and blocked[(cell.y - origin.y) * size.x + cell.x - origin.x] == 0

	## Merkezi `pos`'a en fazla `radius` uzaklıktaki açık hücreler.
	func open_cells_near(pos: Vector2, radius: float) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for y: int in range(origin.y, origin.y + size.y):
			for x: int in range(origin.x, origin.x + size.x):
				var cell := Vector2i(x, y)
				if is_open(cell) and _center(cell).distance_to(pos) <= radius:
					out.append(cell)
		return out

	## 4-komşu BFS: `from` hücresinden `goals`tan birine, `closed` hücrelerine basmadan yol var mı.
	func reaches(from: Vector2i, goals: Array[Vector2i], closed: Array[Vector2i] = []) -> bool:
		if not is_open(from) or closed.has(from):
			return false
		var seen: Dictionary = {from: true}
		var queue: Array[Vector2i] = [from]
		var head: int = 0
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			if goals.has(cell):
				return true
			for dir: Vector2i in DIRS:
				var n: Vector2i = cell + dir
				if is_open(n) and not seen.has(n) and not closed.has(n):
					seen[n] = true
					queue.append(n)
		return false

	static func _center(cell: Vector2i) -> Vector2:
		return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func test_required_nodes() -> void:
	for path: String in LEVELS:
		var level: Node2D = _load(path)
		if level == null:
			continue
		for child: String in REQUIRED:
			is_true(level.has_node(child), "%s: zorunlu düğüm yok: %s" % [path, child])
		var walls: StaticBody2D = level.get_node_or_null("Walls") as StaticBody2D
		if is_true(walls != null, "%s: Walls StaticBody2D olmalı" % path):
			eq(walls.collision_layer, WORLD_LAYER, "%s: Walls yalnız `world` katmanında" % path)
			is_true(_wall_rects(level).size() > 0, "%s: Walls çarpışma şekli yok" % path)
		for child: String in ["SpawnPoints", "Players", "Props", "NPCs", "Markers"]:
			is_true(level.get_node_or_null(child) is Node2D, "%s: %s Node2D olmalı" % [path, child])
		var players: Node = level.get_node_or_null("Players")
		if players != null:
			eq(players.get_child_count(), 0, "%s: Players boş olmalı (oyuncuları Game üretir)" % path)


func test_markers_complete() -> void:
	for path: String in LEVELS:
		var level: Node2D = _load(path)
		if level == null:
			continue
		var grid: Grid = _grid(level)
		for marker_name: String in MARKERS:
			var marker: Marker2D = level.get_node_or_null("Markers/" + marker_name) as Marker2D
			if is_true(marker != null, "%s: Markers/%s Marker2D yok" % [path, marker_name]):
				is_true(grid.has_cell(_cell(marker.position)), "%s: %s harita dışında" % [path, marker_name])
		for spawn_name: String in SPAWNS:
			is_true(level.get_node_or_null("SpawnPoints/" + spawn_name) is Marker2D,
				"%s: SpawnPoints/%s Marker2D yok" % [path, spawn_name])


func test_spawn_points_clear_of_walls() -> void:
	for path: String in LEVELS:
		var level: Node2D = _load(path)
		if level == null:
			continue
		var rects: Array[Rect2] = _wall_rects(level)
		var grid: Grid = _grid(level)
		var placed: Array[Vector2] = []
		for spawn_name: String in SPAWNS:
			var spawn: Marker2D = level.get_node_or_null("SpawnPoints/" + spawn_name) as Marker2D
			if spawn == null:
				fail("%s: %s yok" % [path, spawn_name])
				continue
			var pos: Vector2 = spawn.position
			for rect: Rect2 in rects:
				is_false(_circle_hits(pos, CHAR_RADIUS, rect), "%s: %s duvar şekline giriyor %s" % [path, spawn_name, rect])
			is_true(grid.is_open(_cell(pos)), "%s: %s kapalı hücrede" % [path, spawn_name])
			for other: Vector2 in placed:
				is_true(pos.distance_to(other) >= CHAR_RADIUS * 2.0, "%s: %s başka spawn ile çakışıyor" % [path, spawn_name])
			placed.append(pos)


func test_routes_to_register() -> void:
	for path: String in LEVELS:
		var level: Node2D = _load(path)
		if level == null:
			continue
		var grid: Grid = _grid(level)
		var goals: Array[Vector2i] = _register_goals(level, grid)
		if not is_true(goals.size() > 0, "%s: Register'a etkileşim menzilinde açık hücre yok" % path):
			continue
		for door: String in ["FrontDoor", "BackDoor"]:
			is_true(grid.reaches(_marker_cell(level, door), goals), "%s: %s → Register yolu yok" % [path, door])


func test_store_routes_are_separate() -> void:
	var level: Node2D = _load(STORE)
	if level == null:
		return
	var grid: Grid = _grid(level)
	var front: Vector2i = _marker_cell(level, "FrontDoor")
	var back: Vector2i = _marker_cell(level, "BackDoor")
	var backroom: Vector2i = _marker_cell(level, "BackroomDoor")
	var register: Array[Vector2i] = _register_goals(level, grid)
	is_true(grid.reaches(front, register, [back, backroom]), "ön rota arka kapı ve arka odaya muhtaç olmamalı")
	is_true(grid.reaches(back, register, [front]), "arka rota ön kapıya muhtaç olmamalı (arka oda üzerinden)")
	is_false(grid.reaches(back, register, [front, backroom]), "arka kapıdan kasaya arka oda iç kapısı dışında yol olmamalı")
	var spawn: Vector2i = _cell((level.get_node("SpawnPoints/Spawn1") as Marker2D).position)
	is_true(grid.reaches(spawn, [front]), "spawn → ön kapı")
	is_true(grid.reaches(spawn, [back], [front]), "spawn'dan arka kapıya dışarıdan dolaşılabilmeli")
	var exit_cell: Array[Vector2i] = [_marker_cell(level, "Exit")]
	is_true(grid.reaches(front, exit_cell, [back]), "ön kapı → Exit")
	is_true(grid.reaches(back, exit_cell, [front]), "arka kapı → Exit")


func test_store_door_gaps_fit_one_door() -> void:
	var level: Node2D = _load(STORE)
	if level == null:
		return
	var grid: Grid = _grid(level)
	for door: String in STORE_DOORS:
		var marker: Marker2D = level.get_node_or_null("Markers/" + door) as Marker2D
		if not is_true(marker != null, "Markers/%s yok" % door):
			continue
		var cell: Vector2i = _cell(marker.position)
		near(marker.position, (Vector2(cell) + Vector2(0.5, 0.5)) * TILE, 0.01, "%s karo merkezinde olmalı" % door)
		var vertical: bool = is_equal_approx(absf(marker.rotation_degrees), 90.0)
		is_true(vertical or is_zero_approx(marker.rotation_degrees), "%s yönü 0 ya da 90 derece" % door)
		var along: Vector2i = Vector2i.DOWN if vertical else Vector2i.RIGHT
		var across: Vector2i = Vector2i.RIGHT if vertical else Vector2i.DOWN
		is_true(grid.is_open(cell), "%s boşluğu açık olmalı" % door)
		is_false(grid.is_open(cell + along) or grid.is_open(cell - along), "%s boşluğu tam 1 karo (yanları duvar)" % door)
		is_true(grid.is_open(cell + across) and grid.is_open(cell - across), "%s iki yana geçit vermeli" % door)


func test_store_layout_t1() -> void:
	var level: Node2D = _load(STORE)
	if level == null:
		return
	var grid: Grid = _grid(level)
	is_true(grid.size.x >= 28 and grid.size.x <= 32 and grid.size.y >= 18 and grid.size.y <= 22,
		"bakkal yaklaşık 30×20 karo olmalı, gelen %s" % grid.size)
	var tiles: LevelLayout = level.get_node_or_null("Tiles") as LevelLayout
	if not is_true(tiles != null, "Tiles (LevelLayout) yok"):
		return
	var expected: Dictionary = {
		"FrontDoor": LevelLayout.Kind.DOOR, "BackDoor": LevelLayout.Kind.DOOR,
		"Register": LevelLayout.Kind.COUNTER, "Counter": LevelLayout.Kind.COUNTER,
		"ClerkSpot": LevelLayout.Kind.FLOOR, "BackroomSafe": LevelLayout.Kind.BACKROOM,
		"Exit": LevelLayout.Kind.STREET,
	}
	for marker_name: String in expected:
		eq(_kind_name(tiles.kind_at(_marker_cell(level, marker_name))), _kind_name(expected[marker_name]), "%s zemini" % marker_name)
	for spawn_name: String in SPAWNS:
		var spawn: Marker2D = level.get_node_or_null("SpawnPoints/" + spawn_name) as Marker2D
		if spawn != null:
			eq(_kind_name(tiles.kind_at(_cell(spawn.position))), "SIDEWALK", "%s dış kaldırımda olmalı" % spawn_name)
	var register: Vector2 = (level.get_node("Markers/Register") as Marker2D).position
	var clerk: Vector2 = (level.get_node("Markers/ClerkSpot") as Marker2D).position
	is_true(clerk.distance_to(register) <= INTERACT_RANGE, "tezgâhtar kasanın yanında")
	var counts: Dictionary = {"Shelf": 0, "Counter": 0, "Window": 0}
	for cs: Node in level.get_node("Walls").get_children():
		for prefix: String in counts:
			if cs.name.begins_with(prefix):
				counts[prefix] = int(counts[prefix]) + 1
	is_true(int(counts["Shelf"]) >= 3, "satış alanında raflar (engel) olmalı")
	is_true(int(counts["Counter"]) >= 1, "tezgâh şekli olmalı")
	is_true(int(counts["Window"]) >= 1, "vitrin camı (camdan bakış, GDD §9) olmalı")


func test_layout_matches_collision() -> void:
	for path: String in LEVELS:
		var level: Node2D = _load(path)
		if level == null:
			continue
		var tiles: LevelLayout = level.get_node_or_null("Tiles") as LevelLayout
		if not is_true(tiles != null, "%s: Tiles (LevelLayout) yok" % path):
			continue
		var grid: Grid = _grid(level)
		eq(grid.origin, Vector2i.ZERO, "%s: ızgara (0, 0)'dan başlamalı" % path)
		eq(grid.size, tiles.size_in_tiles(), "%s: çarpışma ile düzen boyutu" % path)
		var mismatches: PackedStringArray = []
		for y: int in grid.size.y:
			for x: int in grid.size.x:
				var cell := Vector2i(x, y)
				if LevelLayout.is_solid(tiles.kind_at(cell)) == grid.is_open(cell):
					mismatches.append(str(cell))
		is_true(mismatches.is_empty(), "%s: çizim ile çarpışma uyuşmuyor: %s" % [path, ", ".join(mismatches)])


func test_scenes_match_layout_sources() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	if not is_true(builder != null, "üretici yüklenemedi"):
		return
	for path: String in LEVELS:
		var level: Node2D = _load(path)
		var source: String = LAYOUT_DIR.path_join(path.get_file().get_basename() + ".txt")
		var layout: Dictionary = builder.call("parse_layout", source)
		if level == null or not is_true(not layout.is_empty(), "%s okunamadı" % source):
			continue
		var tiles: LevelLayout = level.get_node_or_null("Tiles") as LevelLayout
		var stale: String = "%s güncel değil: build_levels.gd'yi koştur" % path
		eq(tiles.rows if tiles != null else PackedStringArray(), layout["rows"], stale)
		for m: Dictionary in layout["markers"]:
			var marker_name: String = m["name"]
			var parent: String = "SpawnPoints/" if marker_name.begins_with("Spawn") else "Markers/"
			var marker: Marker2D = level.get_node_or_null(parent + marker_name) as Marker2D
			if is_true(marker != null, "%s: %s%s yok" % [stale, parent, marker_name]):
				eq(_cell(marker.position), m["cell"], "%s: %s konumu" % [stale, marker_name])


func test_builder_preserves_instanced_props() -> void:
	# S4: Players/Props/NPCs altına eklenenler yeniden üretimde korunur. US-005 kasa/kapıyı Props altına alt sahne
	# örneği olarak koyacak: örneğin değiştirilmiş değeri kalmalı, alt sahnenin değeri seviyeye sabitlenmemeli.
	var builder: GDScript = load(BUILDER) as GDScript
	if not is_true(builder != null, "üretici yüklenemedi"):
		return
	_clear_tmp()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var prop_path: String = TMP_DIR.path_join("prop.tscn")
	var level_path: String = TMP_DIR.path_join("level.tscn")
	var layout_path: String = LAYOUT_DIR.path_join("test_arena.txt")
	var prop := Area2D.new()
	prop.name = "Prop"
	prop.monitoring = false
	prop.priority = 3
	var prop_scene := PackedScene.new()
	eq(prop_scene.pack(prop), OK, "alt sahne paketlenmeli")
	prop.free()
	eq(ResourceSaver.save(prop_scene, prop_path), OK, "alt sahne yazılmalı")
	eq(builder.call("build_scene", layout_path, level_path), OK, "ilk üretim")
	# Editörün yaptığı gibi: seviyeye alt sahne örneği ekle ve bir değerini değiştir.
	var level: Node = (ResourceLoader.load(level_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene) \
		.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var instance: Area2D = (ResourceLoader.load(prop_path) as PackedScene) \
		.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Area2D
	instance.name = "Kasa"
	instance.monitoring = true
	level.get_node("Props").add_child(instance)
	instance.owner = level
	var edited := PackedScene.new()
	eq(edited.pack(level), OK, "düzenlenen seviye paketlenmeli")
	level.free()
	eq(ResourceSaver.save(edited, level_path), OK, "düzenlenen seviye yazılmalı")

	var texts: PackedStringArray = []
	for i: int in 2:
		eq(builder.call("build_scene", layout_path, level_path), OK, "%d. yeniden üretim" % (i + 1))
		texts.append(FileAccess.get_file_as_string(level_path))
	is_true(texts[1] == texts[0], "ikinci üretim dosyayı değiştirmemeli")
	for i: int in 2:
		var block: String = _node_block(texts[i], "Kasa")
		var label: String = "%d. üretim" % (i + 1)
		has(block, "instance=ExtResource(", "%s: Props/Kasa alt sahne örneği kalmalı" % label)
		is_false(block.contains(" type="), "%s: örnek düğüme type= eklenmemeli" % label)
		has(block, "monitoring = true", "%s: örnekte değiştirilen değer korunmalı" % label)
		is_false(block.contains("priority"), "%s: alt sahnenin değeri seviyeye sabitlenmemeli" % label)
	var loaded: Node = autofree((ResourceLoader.load(level_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()) as Node
	var kasa: Area2D = loaded.get_node_or_null("Props/Kasa") as Area2D
	if is_true(kasa != null, "Props/Kasa Area2D olarak kalmalı"):
		is_true(kasa.monitoring, "monitoring = true (örnek değeri)")
		eq(kasa.priority, 3, "priority = 3 (alt sahne değeri)")
		eq(kasa.scene_file_path, prop_path, "alt sahne bağı")
	_clear_tmp()


func test_visuals_take_colors_from_theme_tokens() -> void:
	# Sahnelere renk yazılmaz; seviye betiklerinde renk sabiti yok (S9: renkler yalnız ThemeTokens'tan).
	var literal := RegEx.create_from_string("Color\\s*\\(|Color8\\s*\\(|Color\\.(html|hex|from_)|Color\\.[A-Z]{2,}|\"#[0-9a-fA-F]{3,8}\"")
	var files: PackedStringArray = [STORE, ARENA, "res://levels/level_layout.gd", BUILDER]
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		is_false(text.is_empty(), "%s okunamadı" % path)
		var found: RegExMatch = literal.search(text)
		is_true(found == null, "%s sabit renk içeriyor: %s" % [path, found.get_string() if found != null else ""])
	# Zemin, duvar, raf ve tezgâh birbirinden ayrı okunur.
	var kinds: Array[LevelLayout.Kind] = [LevelLayout.Kind.FLOOR, LevelLayout.Kind.WALL, LevelLayout.Kind.SHELF, LevelLayout.Kind.COUNTER]
	for i: int in kinds.size():
		for j: int in range(i + 1, kinds.size()):
			var a: Color = LevelLayout.color_of(kinds[i])
			var b: Color = LevelLayout.color_of(kinds[j])
			var diff: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			is_true(diff >= 0.05, "%s ile %s renkleri ayırt edilemiyor" % [_kind_name(kinds[i]), _kind_name(kinds[j])])
	# Harita kenarı (tarama çizgisi) cadde ve kaldırımdan ayrı okunur.
	for outside: LevelLayout.Kind in [LevelLayout.Kind.STREET, LevelLayout.Kind.SIDEWALK]:
		var a: Color = LevelLayout.edge_color(LevelLayout.Kind.BOUND)
		var b: Color = LevelLayout.color_of(outside)
		var diff: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
		is_true(diff >= 0.03, "harita kenarı ile %s ayırt edilemiyor" % _kind_name(outside))


func test_level_palette_comes_from_tone() -> void:
	# IS-008: seviye renkleri etkin tonun seviye paletinden; noir değerleri ThemeTokens.LEVEL_*.
	var tokens: Dictionary = {
		"level_floor_color": ThemeTokens.LEVEL_FLOOR, "level_backroom_color": ThemeTokens.LEVEL_BACKROOM,
		"level_sidewalk_color": ThemeTokens.LEVEL_SIDEWALK, "level_street_color": ThemeTokens.LEVEL_STREET,
		"level_wall_color": ThemeTokens.LEVEL_WALL, "level_wall_edge_color": ThemeTokens.LEVEL_WALL_EDGE,
		"level_glass_color": ThemeTokens.LEVEL_GLASS, "level_shelf_color": ThemeTokens.LEVEL_SHELF,
		"level_shelf_edge_color": ThemeTokens.LEVEL_SHELF_EDGE, "level_counter_color": ThemeTokens.LEVEL_COUNTER,
		"level_counter_edge_color": ThemeTokens.LEVEL_COUNTER_EDGE,
	}
	var noir: Tone = ThemeTokens.noir_tone()
	for prop: String in tokens:
		eq(noir.get(prop), tokens[prop], "noir_tone().%s = ThemeTokens sabiti" % prop)
	var fill: Dictionary = {
		LevelLayout.Kind.BOUND: "bg_color", LevelLayout.Kind.STREET: "level_street_color",
		LevelLayout.Kind.SIDEWALK: "level_sidewalk_color", LevelLayout.Kind.FLOOR: "level_floor_color",
		LevelLayout.Kind.DOOR: "level_floor_color", LevelLayout.Kind.BACKROOM: "level_backroom_color",
		LevelLayout.Kind.WALL: "level_wall_color", LevelLayout.Kind.WINDOW: "wall_color",
		LevelLayout.Kind.SHELF: "level_shelf_color", LevelLayout.Kind.COUNTER: "level_counter_color",
		LevelLayout.Kind.COOLER: "level_shelf_color", LevelLayout.Kind.CRATE: "level_counter_color",
	}
	var edge: Dictionary = {
		LevelLayout.Kind.BOUND: "wall_color", LevelLayout.Kind.SIDEWALK: "wall_color",
		LevelLayout.Kind.WALL: "level_wall_edge_color", LevelLayout.Kind.WINDOW: "level_glass_color",
		LevelLayout.Kind.SHELF: "level_shelf_edge_color", LevelLayout.Kind.COUNTER: "level_counter_edge_color",
		LevelLayout.Kind.COOLER: "level_glass_color", LevelLayout.Kind.CRATE: "level_counter_edge_color",
	}
	eq(fill.size(), LevelLayout.Kind.size(), "her karo türünün dolgu rengi tanımlı")
	# Başka bir ton seviye renklerini de değiştirir: renkler çizim anında etkin tondan okunur.
	var other: Tone = ThemeTokens.noir_tone()
	other.id = &"test_level_tone"
	for prop: String in tokens.keys() + ["bg_color", "wall_color"]:
		other.set(prop, (other.get(prop) as Color).inverted())
	for tone: Tone in [noir, other]:
		ThemeTokens.set_tone(tone)
		for kind: LevelLayout.Kind in fill:
			eq(LevelLayout.color_of(kind), tone.get(fill[kind]), "%s: %s dolgusu ← %s" % [tone.id, _kind_name(kind), fill[kind]])
		for kind: LevelLayout.Kind in edge:
			eq(LevelLayout.edge_color(kind), tone.get(edge[kind]), "%s: %s kenarı ← %s" % [tone.id, _kind_name(kind), edge[kind]])
	ThemeTokens.set_tone(null)
	# Seviye betikleri ton dışı sabit renk okumaz (ThemeTokens.BG, .LEVEL_* vb.); ikinci ton seviyeyi de boyar.
	var direct := RegEx.create_from_string("ThemeTokens\\.[A-Z]")
	for path: String in ["res://levels/level_layout.gd", BUILDER]:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var code: String = lines[i].get_slice("#", 0)  # yorumlar hariç
			is_true(direct.search(code) == null, "%s:%d ton yerine ThemeTokens sabiti okuyor: %s" % [path, i + 1, code.strip_edges()])


# --- yardımcılar ---

func _load(path: String) -> Node2D:
	var scene: PackedScene = load(path) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % path):
		return null
	var level: Node2D = scene.instantiate() as Node2D
	if not is_true(level != null, "%s kökü Node2D olmalı" % path):
		return null
	return autofree(level) as Node2D


## `Walls` altındaki tüm dikdörtgen çarpışma şekilleri, seviye kökü koordinatında.
func _wall_rects(level: Node2D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var walls: Node = level.get_node_or_null("Walls")
	if walls == null:
		return out
	for node: Node in walls.find_children("*", "CollisionShape2D", true, false):
		var cs: CollisionShape2D = node as CollisionShape2D
		if cs.disabled:
			continue
		var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
		if not is_true(rect_shape != null, "Walls/%s: yalnız RectangleShape2D destekleniyor" % cs.name):
			continue
		out.append(_to_level(cs, level) * Rect2(-rect_shape.size / 2.0, rect_shape.size))
	return out


## Izgara: hücre merkezindeki artı biçimli yoklama (yatay 32×24, dikey 24×32 px) hiçbir şekle girmiyorsa açık.
## Artı, karakterin (r = 12 px) komşu hücre merkezine düz yürürken taradığı alanı kapsar.
func _grid(level: Node2D) -> Grid:
	var rects: Array[Rect2] = _wall_rects(level)
	var grid := Grid.new()
	if rects.is_empty():
		return grid
	var bounds: Rect2 = rects[0]
	for rect: Rect2 in rects:
		bounds = bounds.merge(rect)
	grid.origin = Vector2i(floori(bounds.position.x / TILE), floori(bounds.position.y / TILE))
	var end := Vector2i(ceili(bounds.end.x / TILE), ceili(bounds.end.y / TILE))
	grid.size = end - grid.origin
	grid.blocked.resize(grid.size.x * grid.size.y)
	var half: float = TILE / 2.0
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			var center: Vector2 = (Vector2(grid.origin + Vector2i(x, y)) + Vector2(0.5, 0.5)) * TILE
			var horizontal := Rect2(center - Vector2(half, CHAR_RADIUS), Vector2(TILE, CHAR_RADIUS * 2.0))
			var vertical := Rect2(center - Vector2(CHAR_RADIUS, half), Vector2(CHAR_RADIUS * 2.0, TILE))
			for rect: Rect2 in rects:
				if rect.intersects(horizontal) or rect.intersects(vertical):
					grid.blocked[y * grid.size.x + x] = 1
					break
	return grid


func _register_goals(level: Node2D, grid: Grid) -> Array[Vector2i]:
	var register: Marker2D = level.get_node_or_null("Markers/Register") as Marker2D
	if register == null:
		return []
	return grid.open_cells_near(register.position, INTERACT_RANGE)


func _marker_cell(level: Node2D, marker_name: String) -> Vector2i:
	var marker: Marker2D = level.get_node_or_null("Markers/" + marker_name) as Marker2D
	if not is_true(marker != null, "Markers/%s yok" % marker_name):
		return Vector2i(-9999, -9999)
	return _cell(marker.position)


## .tscn metninde adı verilen düğümün bölümü (başlık satırı + özellikler).
static func _node_block(text: String, node_name: String) -> String:
	var start: int = text.find('[node name="%s"' % node_name)
	if start < 0:
		return ""
	var end: int = text.find("\n[", start)
	return text.substr(start, end - start if end >= 0 else -1)


static func _clear_tmp() -> void:
	if not DirAccess.dir_exists_absolute(TMP_DIR):
		return
	for f: String in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))
	DirAccess.remove_absolute(TMP_DIR)


static func _kind_name(kind: int) -> String:
	return LevelLayout.Kind.keys()[kind]


static func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func _to_level(node: Node2D, level: Node2D) -> Transform2D:
	var xform: Transform2D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != level:
		if parent is Node2D:
			xform = (parent as Node2D).transform * xform
		parent = parent.get_parent()
	return xform


static func _circle_hits(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_to(closest) < radius
