extends TestCase
## US-007: bakkal v1 seviye eki (mimari.md S4 Faz 2 eki, S11; KR-019 K1/K2; GDD §9 T1, §10).
## AC1 camlar `see_through` gövdeleri (görüş hattı camı geçer, raf ve duvar keser; gerçek fizik sorgusuyla),
## AC2 üretimde bake edilen gezinme çokgeni (deterministik) ve headless yol sorguları (kapı bağı kapanınca yol
## değişir), AC3 yeni işaretler/bölge (EscapeZone, StreetRoute*, ClerkSpot, BackroomCash), düzen dosyası
## bölge sözdizimi.

const STORE := "res://levels/store_a.tscn"
const ARENA := "res://levels/test_arena.tscn"
const LEVELS: Array[String] = [STORE, ARENA]
const BUILDER := "res://levels/tools/build_levels.gd"
const LAYOUT_DIR := "res://levels/layouts"
const TMP_DIR := "user://test_levels_nav"

const TILE := 32
const WORLD_LAYER := PhysicsLayers.WORLD  # mimari.md §4 katman 1
const PLAYERS_LAYER := PhysicsLayers.PLAYERS  # §4 katman 2
const TRIGGERS_LAYER := PhysicsLayers.TRIGGERS  # §4 katman 5
const SEE_THROUGH := PhysicsLayers.SEE_THROUGH_GROUP
const AGENT_RADIUS := 12.0    # karakter çapı ~24 px (S4)
const ARRIVE := 2.0           # yol sonu hedefe bu kadar yakınsa "ulaştı"
const DOOR_PASS := TILE + 1.0  # kapı bağı uçları kapı merkezinden bir karo ötede


# --- AC1: camlar görüşü geçirir, raflar ve duvarlar keser ---

func test_windows_are_see_through_bodies() -> void:
	for path: String in LEVELS:
		var level: Level = _load(path)
		if level == null:
			continue
		var walls: StaticBody2D = level.get_node_or_null("Walls") as StaticBody2D
		if not is_true(walls != null, "%s: Walls yok" % path):
			continue
		is_false(walls.is_in_group(SEE_THROUGH), "%s: Walls (duvar/raf/tezgâh) görüşü keser" % path)
		var windows: int = 0
		for child: Node in walls.get_children():
			if child.name.begins_with("Window"):
				windows += 1
				var body: StaticBody2D = child as StaticBody2D
				if not is_true(body != null, "%s: %s StaticBody2D olmalı" % [path, child.name]):
					continue
				is_true(body.is_in_group(SEE_THROUGH), "%s: %s see_through grubunda" % [path, child.name])
				eq(body.collision_layer, WORLD_LAYER, "%s: %s world katmanında (yürünmez)" % [path, child.name])
				var shapes: Array[Node] = body.find_children("*", "CollisionShape2D", false, false)
				eq(shapes.size(), 1, "%s: %s tek şekil taşır" % [path, child.name])
			else:
				is_true(child is CollisionShape2D, "%s: %s Walls gövdesinin şekli olmalı" % [path, child.name])
				is_false(child.is_in_group(SEE_THROUGH), "%s: %s görüşü keser" % [path, child.name])
		if path == STORE:
			is_true(windows >= 2, "bakkalda ön ve yan camlar olmalı")


func test_line_of_sight_passes_glass_but_not_shelves() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	tree().root.add_child(level)
	await tree().physics_frame
	await tree().physics_frame
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	# Ön kaldırımdan (5, 15) satış alanına (5, 12): arada yalnız ön vitrin camı (5, 14).
	var through_glass: Dictionary = _ray(space, _center(Vector2i(5, 15)), _center(Vector2i(5, 12)), false)
	var hit: Node = through_glass.get("collider") as Node
	is_true(hit != null and hit.is_in_group(SEE_THROUGH), "ön camdan bakış cama çarpar (fiziksel engel)")
	is_true(_ray(space, _center(Vector2i(5, 15)), _center(Vector2i(5, 12)), true).is_empty(),
		"görüş hattı camı geçer (see_through atlanınca engel yok)")
	# Yan sokaktan (23, 10) tezgâh arkasına (20, 10): arada yalnız yan cam (22, 10).
	is_true(_ray(space, _center(Vector2i(23, 10)), _center(Vector2i(20, 10)), true).is_empty(), "yan camdan tezgâh arkası görünür")
	# Raf satırı (6. satır, 4-9. sütun) iki koridoru ayırır: (5, 5) → (5, 7).
	var shelf: Dictionary = _ray(space, _center(Vector2i(5, 5)), _center(Vector2i(5, 7)), true)
	eq(_shape_name(shelf), "Shelf", "raf görüşü keser (K1)")
	# Arka oda duvarı (14. sütun): satış alanından (13, 4) arka odaya (15, 4) (13, 5-7 içecek dolabı, US-033).
	eq(_shape_name(_ray(space, _center(Vector2i(13, 4)), _center(Vector2i(15, 4)), true)), "Wall", "duvar görüşü keser")
	# Tezgâh (17. sütun) yarım boy değil: görüşü keser.
	eq(_shape_name(_ray(space, _center(Vector2i(16, 10)), _center(Vector2i(18, 10)), true)), "Counter", "tezgâh görüşü keser")
	tree().root.remove_child(level)


# --- AC2: gezinme ---

func test_navigation_is_baked_and_deterministic() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	if not is_true(builder != null, "üretici yüklenemedi"):
		return
	for path: String in LEVELS:
		var level: Level = _load(path)
		if level == null:
			continue
		var region: NavigationRegion2D = level.navigation_region()
		if not is_true(region != null and region == level.get_node_or_null("Navigation"), "%s: Navigation bölgesi" % path):
			continue
		var poly: NavigationPolygon = region.navigation_polygon
		if not is_true(poly != null and poly.get_polygon_count() > 0, "%s: bake edilmiş çokgen yok" % path):
			continue
		near(poly.agent_radius, AGENT_RADIUS, 0.001, "%s: ajan yarıçapı = karakter yarıçapı" % path)
		# Kapı karoları engel, geçiş kapı başına bir bağla.
		var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
		var door_cells: Array[Vector2i] = []
		for marker: Node in level.get_node("Markers").get_children():
			var cell: Vector2i = LevelLayout.cell_of((marker as Node2D).position)
			if tiles.kind_at(cell) == LevelLayout.Kind.DOOR:
				door_cells.append(cell)
				var link: NavigationLink2D = level.door_link(marker.name)
				if is_true(link != null, "%s: %s kapı bağı" % [path, marker.name]):
					is_true(link.enabled and link.bidirectional, "%s: %s bağı açık ve çift yönlü üretilir" % [path, marker.name])
					near(link.position, (marker as Node2D).position, 0.01, "%s: %s bağı kapı merkezinde" % [path, marker.name])
					near(link.start_position.length() + link.end_position.length(), TILE * 2.0, 0.01, "%s: %s bağ uçları" % [path, marker.name])
		eq(region.get_child_count(), door_cells.size(), "%s: bağ sayısı = kapı işareti sayısı" % path)
		if path == STORE:
			eq(door_cells.size(), 3, "bakkal: ön, arka ve arka oda kapısı")
		# Aynı düzenden yeniden bake: sahnedekiyle aynı (deterministik ve güncel).
		var again: NavigationPolygon = builder.call("bake_navigation", tiles, door_cells)
		eq(again.get_vertices(), poly.get_vertices(), "%s: çokgen köşeleri güncel değil: build_levels.gd'yi koştur" % path)
		eq(again.get_polygon_count(), poly.get_polygon_count(), "%s: çokgen sayısı" % path)
		for i: int in mini(again.get_polygon_count(), poly.get_polygon_count()):
			eq(again.get_polygon(i), poly.get_polygon(i), "%s: %d. çokgen" % [path, i])
		# Engel karolarının merkezi gezinme alanında değil, açık zemin merkezleri (duvar dibi hariç) içinde.
		var inside: Array[Vector2i] = []
		var solid_hits: PackedStringArray = []
		var size: Vector2i = tiles.size_in_tiles()
		for y: int in size.y:
			for x: int in size.x:
				var cell := Vector2i(x, y)
				var in_mesh: bool = _poly_has_point(poly, _center(cell))
				if (LevelLayout.is_solid(tiles.kind_at(cell)) or door_cells.has(cell)) and in_mesh:
					solid_hits.append(str(cell))
				elif in_mesh:
					inside.append(cell)
		is_true(solid_hits.is_empty(), "%s: engel karosu gezinme alanında: %s" % [path, ", ".join(solid_hits)])
		is_true(inside.size() > 0, "%s: gezinme alanı boş" % path)


func test_store_navigation_paths() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	var spawn: Vector2 = level.spawn_position(0)
	var front: Vector2 = level.marker(&"FrontDoor").position
	var back: Vector2 = level.marker(&"BackDoor").position
	var backroom_door: Vector2 = level.marker(&"BackroomDoor").position
	var cash: Vector2 = level.marker(&"BackroomCash").position
	var clerk: Vector2 = level.marker(&"ClerkSpot").position
	var customer: Vector2 = _center(Vector2i(16, 11))  # kasanın müşteri tarafı (tezgâhın batısı)
	var alley: Vector2 = level.marker(&"StreetRoute6").position  # arka kapının önündeki ara sokak
	var escape: Vector2 = level.zone(&"EscapeZone").position

	var to_register: PackedVector2Array = _path(map, spawn, customer)
	is_true(_arrives(to_register, customer), "spawn → kasanın önü yolu var")
	is_true(_passes(to_register, front), "spawn → kasa ön kapıdan geçer")
	var inside_front: Vector2 = front - Vector2(0, TILE)  # ön kapının iç yanı (yatay duvar; dışarısı +y)
	is_true(_arrives(_path(map, inside_front, clerk), clerk), "ön kapı → tezgâh arkası (tezgâh ucundan)")
	var to_cash: PackedVector2Array = _path(map, inside_front, cash)
	is_true(_arrives(to_cash, cash) and _passes(to_cash, backroom_door), "ön kapı → arka oda nakdi (iç kapıdan)")
	is_true(_arrives(_path(map, cash, escape), escape), "arka oda nakdi → kaçış bölgesi")
	is_true(_arrives(_path(map, clerk, escape), escape), "tezgâh arkası → kaçış bölgesi")

	# Arka kapı açıkken ara sokaktan nakde kısa yol arka kapıdan; kapı bağı kapanınca yol ön kapıya döner.
	var open_path: PackedVector2Array = _path(map, alley, cash)
	is_true(_arrives(open_path, cash) and _passes(open_path, back), "arka kapı açık: ara sokak → nakit arka kapıdan")
	level.door_link(&"BackDoor").enabled = false
	await _sync(map)
	var closed_path: PackedVector2Array = _path(map, alley, cash)
	is_true(_arrives(closed_path, cash), "arka kapı kapalı: yol yine var (ön kapı ve iç kapıdan)")
	is_false(_passes(closed_path, back), "arka kapı kapalı: yol arka kapıdan geçmez")
	is_true(_passes(closed_path, front) and _passes(closed_path, backroom_door), "kapalı arka kapıda yol ön kapı + iç kapıya döner")
	is_true(_length(closed_path) > _length(open_path) + 20.0 * TILE,
		"kapalı arka kapı yolu belirgin uzar (%d → %d px)" % [_length(open_path), _length(closed_path)])

	# Ön kapı da kapalıysa dışarıdan içeri yol yok (pencereler ve duvarlar engel).
	level.door_link(&"FrontDoor").enabled = false
	await _sync(map)
	is_false(_arrives(_path(map, spawn, customer), customer), "iki dış kapı kapalı: dışarıdan kasaya yol olmamalı")
	is_true(_arrives(_path(map, clerk, cash), cash), "içeride tezgâh → arka oda (iç kapı açık)")
	_leave(level, map)


func test_street_route_is_walkable_outside() -> void:
	var level: Level = _load(STORE)
	if level == null:
		return
	var points: Array[Node2D] = level.marker_sequence(&"StreetRoute")
	is_true(points.size() >= 4, "sokak rotası en az 4 nokta (gelen %d)" % points.size())
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	# Sokak rotası kapıları kullanmadan dışarıda kalır: kapı bağları kapalıyken de ardışık noktalar bağlı.
	for door: StringName in [&"FrontDoor", &"BackDoor", &"BackroomDoor"]:
		level.door_link(door).enabled = false
	await _sync(map)
	for i: int in range(1, points.size()):
		var from: Vector2 = points[i - 1].position
		var to: Vector2 = points[i].position
		is_true(_arrives(_path(map, from, to), to), "StreetRoute%d → StreetRoute%d dışarıdan yürünür" % [i, i + 1])
	is_true(_arrives(_path(map, points[-1].position, points[0].position), points[0].position), "rota geri dönebilir")
	_leave(level, map)


func test_arena_navigation_paths() -> void:
	var level: Level = _load(ARENA)
	if level == null:
		return
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	var exit: Vector2 = level.marker(&"Exit").position
	var path: PackedVector2Array = _path(map, level.spawn_position(0), exit)
	is_true(_arrives(path, exit), "arena: spawn → Exit")
	near(_length(path), level.spawn_position(0).distance_to(exit), 1.0, "arena boş: yol düz çizgi")
	for marker_name: StringName in [&"BackroomCash", &"ClerkSpot", &"StreetRoute1"]:
		var to: Vector2 = level.marker(marker_name).position
		is_true(_arrives(_path(map, level.spawn_position(0), to), to), "arena: spawn → %s" % marker_name)
	_leave(level, map)


# --- AC3: işaretler ve kaçış bölgesi ---

func test_us007_markers_and_escape_zone() -> void:
	for path: String in LEVELS:
		var level: Level = _load(path)
		if level == null:
			continue
		for marker_name: StringName in [&"ClerkSpot", &"BackroomCash"]:
			is_true(level.marker(marker_name) is Marker2D, "%s: Markers/%s" % [path, marker_name])
		var patrol: Array[Node2D] = level.marker_sequence(&"StreetRoute")
		is_true(patrol.size() >= 3, "%s: StreetRoute1..N (gelen %d)" % [path, patrol.size()])
		is_true(level.marker(StringName("StreetRoute%d" % (patrol.size() + 2))) == null, "%s: rota numaraları boşluksuz" % path)
		var zone: Area2D = level.zone(&"EscapeZone")
		if not is_true(zone != null and zone == level.get_node_or_null("Zones/EscapeZone"), "%s: Zones/EscapeZone Area2D" % path):
			continue
		eq(zone.collision_layer, TRIGGERS_LAYER, "%s: EscapeZone yalnız triggers katmanında" % path)
		eq(zone.collision_mask, PLAYERS_LAYER, "%s: EscapeZone oyuncuları izler" % path)
		is_true(zone.monitoring and not zone.monitorable, "%s: EscapeZone izler, izlenmez" % path)
		var rect: Rect2 = _zone_rect(zone)
		if not is_true(rect.has_area(), "%s: EscapeZone tek dikdörtgen şekil" % path):
			continue
		is_true(rect.has_point(level.marker(&"Exit").position), "%s: Exit kaçış bölgesinin içinde" % path)
		var tiles: LevelLayout = level.get_node("Tiles") as LevelLayout
		for y: int in range(floori(rect.position.y / TILE), ceili(rect.end.y / TILE)):
			for x: int in range(floori(rect.position.x / TILE), ceili(rect.end.x / TILE)):
				is_false(LevelLayout.is_solid(tiles.kind_at(Vector2i(x, y))), "%s: kaçış bölgesi (%d, %d) engel üstünde" % [path, x, y])
		if path != STORE:
			continue
		var outdoor: Array[LevelLayout.Kind] = [LevelLayout.Kind.SIDEWALK, LevelLayout.Kind.STREET]
		for y: int in range(floori(rect.position.y / TILE), ceili(rect.end.y / TILE)):
			for x: int in range(floori(rect.position.x / TILE), ceili(rect.end.x / TILE)):
				has(outdoor, tiles.kind_at(Vector2i(x, y)), "bakkal: kaçış bölgesi dışarıda (%d, %d)" % [x, y])
		for point: Node2D in patrol:
			has(outdoor, tiles.kind_at(LevelLayout.cell_of(point.position)), "bakkal: %s dışarıda" % point.name)
		eq(_kind(tiles, level.marker(&"BackroomCash")), LevelLayout.Kind.BACKROOM, "bakkal: nakit arka odada")
		eq(_kind(tiles, level.marker(&"ClerkSpot")), LevelLayout.Kind.FLOOR, "bakkal: tezgâhtar satış alanında")
		# Tezgâhtar tezgâhın arkasında: tezgâh tezgâhtar ile ön kapı arasında (x ekseninde).
		var counter_x: float = level.marker(&"Counter").position.x
		is_true(level.marker(&"ClerkSpot").position.x > counter_x and level.marker(&"FrontDoor").position.x < counter_x,
			"bakkal: ClerkSpot tezgâh arkasında")


func test_zones_match_layout_sources() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	if not is_true(builder != null, "üretici yüklenemedi"):
		return
	for path: String in LEVELS:
		var level: Level = _load(path)
		var layout: Dictionary = builder.call("parse_layout", LAYOUT_DIR.path_join(path.get_file().get_basename() + ".txt"))
		if level == null or not is_true(not layout.is_empty(), "%s düzeni okunamadı" % path):
			continue
		var zones: Node = level.get_node_or_null("Zones")
		eq(zones.get_child_count() if zones != null else -1, (layout["zones"] as Array).size(), "%s: bölge sayısı" % path)
		for z: Dictionary in layout["zones"]:
			var area: Area2D = level.zone(StringName(z["name"]))
			var expected: Array[Rect2] = []
			for cells: Rect2i in z["rects"]:
				expected.append(Rect2(Vector2(cells.position) * TILE, Vector2(cells.size) * TILE))
			if is_true(area != null, "%s: Zones/%s yok: build_levels.gd'yi koştur" % [path, z["name"]]):
				eq(_zone_rects(area), expected, "%s: %s dikdörtgenleri" % [path, z["name"]])


func test_layout_zone_syntax() -> void:
	var builder: GDScript = load(BUILDER) as GDScript
	if not is_true(builder != null, "üretici yüklenemedi"):
		return
	_clear_tmp()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var header: String = "@ A Spawn1 .\n= Z Zone .\n"
	# Bölge içine düşen işaret dikdörtgene sayılır.
	var ok: Dictionary = builder.call("parse_layout", _write("ok.txt", header + "#####\n#ZZ.#\n#ZA.#\n#####\n"))
	if is_true(not ok.is_empty(), "geçerli bölge okunmalı"):
		var zones: Array = ok["zones"]
		if eq(zones.size(), 1, "tek bölge"):
			eq(zones[0]["name"], "Zone")
			eq(zones[0]["rects"], [Rect2i(1, 1, 2, 2)], "bölge dikdörtgeni (işaret dahil)")
		eq((ok["rows"] as PackedStringArray)[2], "#...#", "bölge ve işaret karoları zemine döner")
	# IS-023: boyamasız dikdörtgen bölge (raf/işaret üstünde); aynı ad yinelenince çok parçalı, tanım sırasıyla.
	var grid: String = "#####\n#S.A#\n#..S#\n#####\n"
	var spawn_def: String = "@ A Spawn1 .\n"
	var rects: Dictionary = builder.call("parse_layout", _write("rects.txt",
		spawn_def + "= Room 1 1 2 2\n= Hall 3 1 1 1\n= Room 3 2 1 1\n" + grid))
	# Kontrol: aynı ızgara bölgesiz de geçerli (aşağıdaki red satırları yalnız bölge yüzünden reddedilir).
	is_false((builder.call("parse_layout", _write("plain.txt", spawn_def + grid)) as Dictionary).is_empty(), "bölgesiz ızgara geçerli")
	if is_true(not rects.is_empty(), "boyamasız bölge okunmalı"):
		var zones: Array = rects["zones"]
		eq(zones.size(), 2, "iki bölge")
		if zones.size() == 2:
			eq([zones[0]["name"], zones[1]["name"]], ["Room", "Hall"], "ilk tanım sırası")
			eq(zones[0]["rects"], [Rect2i(1, 1, 2, 2), Rect2i(3, 2, 1, 1)], "Room iki parça")
			eq(zones[1]["rects"], [Rect2i(3, 1, 1, 1)], "Hall tek parça (işaret üstünde)")
		eq((rects["rows"] as PackedStringArray)[1], "#S..#", "boyamasız bölge ızgarayı değiştirmez")
		# Üretim: parça başına şekil (Shape, Shape2), kök kapsayıcının merkezinde; ikinci üretim dosyayı değiştirmez.
		var scene_path: String = TMP_DIR.path_join("rects.tscn")
		var texts: PackedStringArray = []
		for i: int in 2:
			eq(builder.call("build_scene", TMP_DIR.path_join("rects.txt"), scene_path), OK, "%d. üretim" % (i + 1))
			texts.append(FileAccess.get_file_as_string(scene_path))
		is_true(texts.size() == 2 and texts[0] == texts[1], "çok parçalı bölge yeniden üretimde değişmemeli")
		var level: Level = autofree((ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()) as Level
		var room: Area2D = level.zone(&"Room") if level != null else null
		if is_true(room != null, "Zones/Room"):
			eq(room.get_child(0).name, &"Shape")
			eq(room.get_child(1).name, &"Shape2")
			eq(_zone_rects(room), [Rect2(32, 32, 64, 64), Rect2(96, 64, 32, 32)], "Room şekilleri")
			near(room.position, Vector2(80, 64), 0.001, "kök kapsayıcı merkezinde")
	allow_errors()
	for bad: String in [
		header + "#####\n#Z..#\n#.ZA#\n#####\n",  # dolu dikdörtgen değil
		header + "#####\n#...#\n#..A#\n#####\n",  # bölge ızgarada yok
		"@ A Spawn1 .\n= A Zone .\n#####\n#AA.#\n#####\n",  # harf hem işaret hem bölge
		"= Z ../Zone .\n#####\n#Z..#\n#####\n",  # düğüm adı olamaz
		spawn_def + "= Room 2 1 4 1\n" + grid,  # ızgara dışına taşar (genişlik 5)
		spawn_def + "= Room 1 3 1 2\n" + grid,  # ızgara dışına taşar (yükseklik 4)
		spawn_def + "= Room 1 1 0 1\n" + grid,  # boyut sıfır
		spawn_def + "= Room -1 1 1 1\n" + grid,  # negatif konum
		spawn_def + "= Room 1 x 1 1\n" + grid,  # sayı değil
		spawn_def + "= ../Room 1 1 1 1\n" + grid,  # düğüm adı olamaz
		"= Z Room .\n= Room 1 1 1 1\n#####\n#Z..#\n#####\n",  # boyalı bölgeyle aynı ad
		"= Room 1 1 1 1\n= Z Room .\n#####\n#Z..#\n#####\n",  # aynı ad (ters sıra)
	]:
		is_true((builder.call("parse_layout", _write("bad.txt", bad)) as Dictionary).is_empty(), "geçersiz bölge reddedilmeli:\n" + bad)
	_clear_tmp()


# --- yardımcılar ---

func _load(path: String) -> Level:
	var scene: PackedScene = load(path) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % path):
		return null
	var level: Level = scene.instantiate() as Level
	if not is_true(level != null, "%s kökü Level olmalı" % path):
		return null
	return autofree(level) as Level


## Seviyeyi ağaca ekler; gezinme düğümlerini yalıtık yeni bir haritaya bağlar (dünya haritası ayarlarıyla) ve
## eşitler. Başarısızsa geçersiz RID.
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
	# Bölge verisi de bu karede işlensin (varsayılan: arka planda, sonraki eşitlemelerde).
	NavigationServer2D.region_set_use_async_iterations(region.get_rid(), false)
	for link: Node in region.get_children():
		(link as NavigationLink2D).set_navigation_map(map)
	tree().root.add_child(level)
	await _sync(map)
	is_true(NavigationServer2D.map_get_regions(map).size() == 1, "harita tek gezinme bölgesi taşımalı")
	return map


## Harita eşitlemesi: kuvvetli güncelleme; işlemediyse fizik karelerini bekler (headless).
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


## Yol kapı merkezinin bir karo yakınından geçiyor mu (bağ uçları kapının iki yanındaki karo merkezleri).
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


## İlk engel; `skip_see_through` ise see_through gövdeleri atlanır (algının görüş hattı kuralı, S11).
func _ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, skip_see_through: bool) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER)
	var exclude: Array[RID] = []
	for i: int in 8:
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not skip_see_through or not (hit["collider"] as Node).is_in_group(SEE_THROUGH):
			return hit
		exclude.append(hit["rid"] as RID)
	return {}


## Çarpılan şeklin ad öneki (Shelf/Wall/Counter/Window …); çarpma yoksa boş.
static func _shape_name(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	var body: CollisionObject2D = hit["collider"] as CollisionObject2D
	var owner_node: Object = body.shape_owner_get_owner(body.shape_find_owner(int(hit["shape"])))
	var shape_name: String = (owner_node as Node).name
	var prefix := RegEx.create_from_string("^[A-Za-z]+")
	return prefix.search(shape_name).get_string() if shape_name != "Shape" else String(body.name)


static func _zone_rect(zone: Area2D) -> Rect2:
	var shapes: Array[Node] = zone.find_children("*", "CollisionShape2D", false, false)
	if shapes.size() != 1:
		return Rect2()
	var cs: CollisionShape2D = shapes[0] as CollisionShape2D
	var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2()
	return Rect2(zone.position + cs.position - rect_shape.size / 2.0, rect_shape.size)


## Bölgenin tüm dikdörtgen şekilleri (seviye koordinatında, çocuk sırasıyla); dikdörtgen olmayan şekil atlanır.
static func _zone_rects(zone: Area2D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node: Node in zone.find_children("*", "CollisionShape2D", false, false):
		var cs: CollisionShape2D = node as CollisionShape2D
		var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
		if rect_shape != null:
			out.append(Rect2(zone.position + cs.position - rect_shape.size / 2.0, rect_shape.size))
	return out


## Nokta çokgenlerden birinin içinde mi (sınır dahil değil sayılmaz; merkez yoklaması için yeterli).
static func _poly_has_point(poly: NavigationPolygon, point: Vector2) -> bool:
	var vertices: PackedVector2Array = poly.get_vertices()
	for i: int in poly.get_polygon_count():
		var shape := PackedVector2Array()
		for index: int in poly.get_polygon(i):
			shape.append(vertices[index])
		if Geometry2D.is_point_in_polygon(point, shape):
			return true
	return false


static func _kind(tiles: LevelLayout, marker: Node2D) -> LevelLayout.Kind:
	return tiles.kind_at(LevelLayout.cell_of(marker.position))


static func _center(cell: Vector2i) -> Vector2:
	return LevelLayout.cell_center(cell)


static func _write(file_name: String, text: String) -> String:
	var path: String = TMP_DIR.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


static func _clear_tmp() -> void:
	if not DirAccess.dir_exists_absolute(TMP_DIR):
		return
	for f: String in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))
	DirAccess.remove_absolute(TMP_DIR)
