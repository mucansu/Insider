extends SceneTree
## Seviye üretici (US-002): levels/layouts/<ad>.txt ASCII düzeninden levels/<ad>.tscn sahnesini S4 düzeninde yazar.
##   $GODOT --headless --path . -s res://levels/tools/build_levels.gd [-- store_a test_arena]
## Ad verilmezse levels/layouts/ altındaki tüm .txt dosyaları üretilir. Sahne zaten varsa yalnız üretilen
## düğümler (Tiles, Walls, SpawnPoints, Markers) yeniden kurulur; Players, Props, NPCs ve elle eklenmiş
## diğer düğümler korunur. Düzen değişikliği .txt'de yapılır, .tscn elle düzenlenmez (tests/unit/test_levels.gd
## sahne ile ızgaranın tutarlılığını denetler).
##
## Düzen dosyası: `;` ile başlayan satır yorum; `@ <harf> <Marker adı> <zemin karakteri>` işaret tanımı
## (her harf ızgarada tam bir kez geçer, `Spawn*` adları SpawnPoints'e, diğerleri Markers'a gider); kalan
## satırlar eşit genişlikte karo ızgarasıdır (lejant: levels/level_layout.gd).

const LAYOUT_DIR := "res://levels/layouts"
const LEVEL_DIR := "res://levels"
## Üretilen düğümler; sahnedeki sıra S4 ile aynı (Tiles en altta çizilir).
const ORDER: Array[String] = ["Tiles", "Walls", "SpawnPoints", "Players", "Props", "NPCs", "Markers"]
const GENERATED: Array[String] = ["Tiles", "Walls", "SpawnPoints", "Markers"]
const WORLD_LAYER := 1  # mimari.md §4: katman 1 `world`
const LAYOUT_SCRIPT := preload("res://levels/level_layout.gd")
const SOLID_ORDER: Array[LevelLayout.Kind] = [
	LevelLayout.Kind.BOUND, LevelLayout.Kind.WALL, LevelLayout.Kind.WINDOW,
	LevelLayout.Kind.SHELF, LevelLayout.Kind.COUNTER,
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


## Tek seviyeyi üretir: layouts/<ad>.txt → <ad>.tscn.
static func build(level_name: String) -> Error:
	return build_scene(LAYOUT_DIR.path_join(level_name + ".txt"), LEVEL_DIR.path_join(level_name + ".tscn"), true)


## Düzen dosyasından sahneyi yazar (testler geçici yolla da çağırır). Var olan düğümler adla yeniden kullanılır;
## düzen değişmediyse sahne dosyası da değişmez (unique_id'ler, sahne uid'i ve alt sahne örneklerinin değerleri korunur).
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
	var keep: Dictionary = {}  # üretilen düğüm -> true
	for m: Dictionary in layout["markers"]:
		var marker_name: String = m["name"]
		var parent: Node2D = spawns if marker_name.begins_with("Spawn") else markers
		var marker: Marker2D = _ensure(parent, marker_name, "Marker2D") as Marker2D
		parent.move_child(marker, -1)
		var cell: Vector2i = m["cell"]
		marker.position = LevelLayout.cell_center(cell)
		# Kapı yönü: 0 = yatay duvardaki boşluk (kapı x boyunca), 90 = dikey duvar.
		var vertical_door: bool = tiles.kind_at(cell) == LevelLayout.Kind.DOOR and not _is_horizontal_gap(tiles, cell)
		marker.rotation_degrees = 90.0 if vertical_door else 0.0
		keep[marker] = true
	_prune(spawns, keep)
	_prune(markers, keep)

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
		print("%s: %d×%d karo, %d şekil, %d spawn, %d işaret" % [
			scene_path, size.x, size.y, root.get_node("Walls").get_child_count(),
			spawns.get_child_count(), markers.get_child_count()])
	root.free()
	return err


## Düzen dosyasını okur: {"rows": PackedStringArray (işaretler zemine dönmüş), "markers": [{name, cell}]}.
## Hata varsa push_error ile bildirir ve boş sözlük döner.
static func parse_layout(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("build_levels: düzen okunamadı: " + path)
		return {}
	var defs: Dictionary = {}  # harf -> [ad, zemin karakteri]
	var grid: PackedStringArray = []
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges(false, true)
		if line.is_empty() or line.begins_with(";"):
			continue
		if line.begins_with("@"):
			var parts: PackedStringArray = line.split(" ", false)
			if parts.size() != 4 or parts[1].length() != 1 or parts[3].length() != 1 \
					or not LevelLayout.LEGEND.has(parts[3]) or LevelLayout.LEGEND.has(parts[1]):
				push_error("build_levels: %s: geçersiz işaret satırı '%s'" % [path, line])
				return {}
			defs[parts[1]] = [parts[2], parts[3]]
			continue
		grid.append(line)
	if grid.is_empty():
		push_error("build_levels: %s: ızgara yok" % path)
		return {}
	var width: int = grid[0].length()
	var rows: PackedStringArray = []
	var seen: Dictionary = {}  # harf -> hücre
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
			elif LevelLayout.LEGEND.has(ch):
				row += ch
			else:
				push_error("build_levels: %s: bilinmeyen karakter '%s' (%d, %d)" % [path, ch, x, y])
				return {}
		rows.append(row)
	var markers: Array[Dictionary] = []  # tanım sırasıyla
	for ch: String in defs:
		if not seen.has(ch):
			push_error("build_levels: %s: işaret '%s' ızgarada yok" % [path, ch])
			return {}
		markers.append({"name": defs[ch][0], "cell": seen[ch]})
	return {"rows": rows, "markers": markers}


## Çarpışma şekilleri: tür başına birleştirilmiş dikdörtgenler, adları <Önek><n> (Bound/Wall/Window/Shelf/Counter).
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
			var cs: CollisionShape2D = _ensure(walls, "%s%d" % [prefix, n], "CollisionShape2D") as CollisionShape2D
			walls.move_child(cs, -1)
			cs.position = rect.get_center()
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			shape.resource_scene_unique_id = "%s_%d" % [prefix, n]
			cs.shape = shape
			keep[cs] = true
	_prune(walls, keep)


## Adlı çocuğu döndürür; yoksa ya da türü/betiği farklıysa yenisiyle değiştirir.
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


## Üretilen kapta bu koşuda kurulmamış çocukları siler (düzenden kalkan şekil/işaret).
static func _prune(parent: Node, keep: Dictionary) -> void:
	for child: Node in parent.get_children():
		if not keep.has(child):
			parent.remove_child(child)
			child.free()


static func _open_root(scene_path: String, root_name: String) -> Node2D:
	if ResourceLoader.exists(scene_path):
		var existing: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if existing != null:
			# Düzenleme kipi: alt sahne örnekleri yalnız değiştirilmiş değerleriyle yeniden paketlenir (editör gibi).
			var inst: Node2D = existing.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node2D
			if inst != null:
				return inst
		push_warning("build_levels: %s açılamadı, sıfırdan kuruluyor" % scene_path)
	var root := Node2D.new()
	root.name = root_name
	return root


## Var olan sahnenin başlığındaki uid ("uid://…"); yoksa boş.
static func _header_uid(scene_path: String) -> String:
	if not FileAccess.file_exists(scene_path):
		return ""
	var file := FileAccess.open(scene_path, FileAccess.READ)
	var header: String = file.get_line() if file != null else ""
	var found: RegExMatch = RegEx.create_from_string('uid="(uid://[0-9a-z]+)"').search(header)
	return found.get_string(1) if found != null else ""


## Başlığa sahne uid'ini ve ext_resource satırlarına kaynak uid'lerini yazar (editörün kaydettiği biçim).
## Headless betik kipinde ResourceSaver uid yazmaz; editör sonradan kaydederse dosya değişmesin diye.
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


## Sahiplik: üretilen kaplarda tüm alt ağaç köke bağlanır; korunan kaplarda yalnız kabın kendisi.
static func _own(node: Node, owner_node: Node, recursive: bool) -> void:
	if node.owner == null:
		node.owner = owner_node
	if recursive:
		for child: Node in node.get_children():
			_own(child, owner_node, true)
