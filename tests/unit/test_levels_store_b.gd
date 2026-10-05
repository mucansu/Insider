extends TestCase
## IS-107 (KR-037): second trial shop `store_b` (40x24, street west, counter north facing south, back alley east;
## design docs/tasarim/danisma/us-045-store-b.md §E). Generic level checks (S4 nodes, spawns, collision/layout match,
## zones, navigation) run over store_b in test_levels*.gd; this file checks the store_b-specific contract without
## store_a coordinate/direction assumptions: every store_a name exists, door props match markers, placement rules
## are stated relative to neighbouring tiles, and the information-split sight lines (KR-035) hold.

const STORE_A := "res://levels/store_a.tscn"
const STORE_B := "res://levels/store_b.tscn"
const TILE := 32
const WORLD_LAYER := PhysicsLayers.WORLD
const ARRIVE := 2.0
const DOOR_PASS := TILE + 1.0
const DOORS: Array[StringName] = [&"FrontDoor", &"BackDoor", &"BackroomDoor"]
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Hand-placed Props that sit exactly on the same-named (or given) marker.
const PROP_ON_MARKER: Dictionary = {
	&"Register": &"Register", &"Counter": &"Counter", &"Bag": &"BackroomCash",
	&"ShelfProp1": &"ShelfProp1", &"ShelfProp2": &"ShelfProp2", &"ShelfProp3": &"ShelfProp3",
}
## Information-split lookout tiles (KR-035; layout header): annex east part, inside the front door.
const ANNEX_EAST := Vector2i(33, 14)
const INSIDE_FRONT := Vector2i(9, 10)


func test_store_b_has_every_store_a_name() -> void:
	var a: Level = _load(STORE_A)
	var b: Level = _load(STORE_B)
	if a == null or b == null:
		return
	for group: String in ["Markers", "SpawnPoints", "Zones", "Props", "NPCs", "Navigation"]:
		for child: Node in a.get_node(group).get_children():
			var path := NodePath("%s/%s" % [group, child.name])
			var twin: Node = b.get_node_or_null(path)
			if not is_true(twin != null, "store_b: %s yok (store_a'da var)" % path):
				continue
			eq(twin.get_class(), child.get_class(), "store_b: %s türü" % path)
			eq(twin.scene_file_path, child.scene_file_path, "store_b: %s alt sahnesi" % path)
			var script_a: Script = child.get_script() as Script
			var script_b: Script = twin.get_script() as Script
			eq(script_b.resource_path if script_b != null else "", script_a.resource_path if script_a != null else "",
				"store_b: %s betiği" % path)
	for child: Node in a.get_children():
		is_true(b.has_node(NodePath(String(child.name))), "store_b: kök düğüm %s yok" % child.name)
	eq(b.spawn_count(), a.spawn_count(), "store_b: spawn sayısı")


func test_store_b_shop_items() -> void:
	# KR-038: ShopItem<n> markers (Markers, S4); bread on the shelf end nearest the front door, cola at the cooler.
	var level: Level = _load(STORE_B)
	if level == null:
		return
	var tiles: LevelLayout = level.layout()
	var items: Array[Node2D] = level.marker_sequence(&"ShopItem")
	eq(items.size(), 2, "ShopItem1..2")
	for item: Node2D in items:
		var cell: Vector2i = LevelLayout.cell_of(item.position)
		eq(tiles.kind_at(cell), LevelLayout.Kind.FLOOR, "%s zeminde" % item.name)
		eq(_zones_at(level, item.position), [&"CustomerArea"], "%s müşteri bölgesinde" % item.name)
	if items.size() < 2:
		return
	var bread: Vector2i = LevelLayout.cell_of(items[0].position)
	var cola: Vector2i = LevelLayout.cell_of(items[1].position)
	is_true(_touches(tiles, bread, LevelLayout.Kind.SHELF), "ShopItem1 (ekmek) raf ucunda")
	is_true(_touches(tiles, cola, LevelLayout.Kind.COOLER), "ShopItem2 (kola) soğutucu önünde")
	var front: Vector2 = level.marker(&"FrontDoor").position
	var nearest: float = INF
	for y: int in tiles.size_in_tiles().y:
		for x: int in tiles.size_in_tiles().x:
			var cell := Vector2i(x, y)
			if tiles.kind_at(cell) == LevelLayout.Kind.FLOOR and _touches(tiles, cell, LevelLayout.Kind.SHELF) \
					and _is_shelf_end(tiles, cell):
				nearest = minf(nearest, LevelLayout.cell_center(cell).distance_to(front))
	near(items[0].position.distance_to(front), nearest, 0.01, "ShopItem1 ön kapıya en yakın raf ucunda")


func test_store_b_door_props_match_markers() -> void:
	var level: Level = _load(STORE_B)
	if level == null:
		return
	for door_name: StringName in DOORS:
		var marker: Node2D = level.marker(door_name)
		var door: Door = level.props_root().get_node_or_null(NodePath(String(door_name))) as Door
		if not is_true(marker != null and door != null, "%s: işaret ve Props kapısı olmalı" % door_name):
			continue
		near(door.position, marker.position, 0.01, "%s kapısı işaretin karosunda" % door_name)
		near(door.rotation_degrees, marker.rotation_degrees, 0.01, "%s kapısı işaretle aynı yönde" % door_name)
		near(absf(marker.rotation_degrees), 90.0, 0.01, "store_b: %s dikey duvarda" % door_name)
		is_true(level.door_link(door_name) != null, "%s gezinme bağı" % door_name)
		eq(door.is_open, door_name == &"FrontDoor", "%s başlangıç durumu store_a ile aynı" % door_name)
	for prop: StringName in PROP_ON_MARKER:
		var node: Node2D = level.props_root().get_node_or_null(NodePath(String(prop))) as Node2D
		var marker: Node2D = level.marker(PROP_ON_MARKER[prop])
		if is_true(node != null and marker != null, "Props/%s ve işareti" % prop):
			near(node.position, marker.position, 0.01, "Props/%s işaretinde" % prop)
	var owner_node: Node2D = level.npcs_root().get_node_or_null(^"Owner") as Node2D
	if is_true(owner_node != null, "NPCs/Owner"):
		near(owner_node.position, level.marker(&"ClerkSpot").position, 0.01, "sahip ClerkSpot'ta başlar")


func test_store_b_marker_placement() -> void:
	# store_a placement rules restated relative to neighbouring tiles (no "east"/"west" assumption, KR-037).
	var level: Level = _load(STORE_B)
	if level == null:
		return
	var tiles: LevelLayout = level.layout()
	for prefix: StringName in [&"RestockSpot", &"ShelfProp"]:
		for point: Node2D in level.marker_sequence(prefix):
			var cell: Vector2i = LevelLayout.cell_of(point.position)
			eq(tiles.kind_at(cell), LevelLayout.Kind.FLOOR, "%s zeminde" % point.name)
			is_true(_touches(tiles, cell, LevelLayout.Kind.SHELF), "%s rafa bitişik" % point.name)
	var register: Vector2i = _cell(level, &"Register")
	var clerk: Vector2i = _cell(level, &"ClerkSpot")
	var queue1: Vector2i = _cell(level, &"QueueSpot1")
	is_true(_adjacent(queue1, register), "QueueSpot1 kasanın tam önünde")
	is_true(_adjacent(clerk, register), "ClerkSpot kasanın arkasında")
	eq(queue1 - register, register - clerk, "kuyruk ve tezgâhtar kasanın karşı yanlarında")
	is_true(_touches(tiles, _cell(level, &"QueueSpot2"), LevelLayout.Kind.COUNTER), "QueueSpot2 tezgâh önünde")
	var phone: Vector2i = _cell(level, &"PhoneSpot")
	is_true(_touches(tiles, phone, LevelLayout.Kind.WALL), "PhoneSpot duvara bakar")
	is_false(_touches(tiles, phone, LevelLayout.Kind.WINDOW), "PhoneSpot cam önünde değil")
	eq(tiles.kind_at(_cell(level, &"NeighbourSpawn")), LevelLayout.Kind.SIDEWALK, "NeighbourSpawn kaldırımda")
	for point: Node2D in level.marker_sequence(&"WindowLook"):
		var cell: Vector2i = LevelLayout.cell_of(point.position)
		eq(tiles.kind_at(cell), LevelLayout.Kind.SIDEWALK, "%s kaldırımda" % point.name)
		var windows: int = 0
		for dir: Vector2i in DIRS:
			if tiles.kind_at(cell + dir) == LevelLayout.Kind.WINDOW:
				windows += 1
		eq(windows, 1, "%s tam bir camın önünde" % point.name)
	for i: int in level.spawn_count():
		var spawn: Node2D = level.get_node("SpawnPoints/Spawn%d" % (i + 1)) as Node2D
		eq(tiles.kind_at(LevelLayout.cell_of(spawn.position)), LevelLayout.Kind.SIDEWALK, "Spawn%d kaldırımda" % (i + 1))


func test_store_b_lines_of_sight() -> void:
	var level: Level = _load(STORE_B)
	if level == null:
		return
	tree().root.add_child(level)
	await tree().physics_frame
	await tree().physics_frame
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var register: Vector2 = level.marker(&"Register").position
	var clerk: Vector2 = level.marker(&"ClerkSpot").position
	for point: Node2D in level.marker_sequence(&"RestockSpot"):
		for target: Vector2 in [register, clerk]:
			is_false(_ray(space, point.position, target).is_empty(), "%s → %s görüş hattı kesik" % [point.name, target])
	# (2) Entering at the front door: shelves hide the counter.
	is_false(_ray(space, LevelLayout.cell_center(INSIDE_FRONT), register).is_empty(), "ön kapıdan giren kasayı görmez")
	# (1) Annex: blind spot from the counter (cola, ShopSpot5), sees the alley through the east glass.
	var annex: Vector2 = LevelLayout.cell_center(ANNEX_EAST)
	for target: Vector2 in [annex, level.marker(&"ShopItem2").position, level.marker(&"ShopSpot5").position]:
		is_false(_ray(space, clerk, target).is_empty(), "ClerkSpot → %s görülmez (ek alan kör noktası)" % target)
	var alley_look: Vector2 = level.marker(&"WindowLook3").position
	is_true(_ray(space, annex, alley_look).is_empty(), "ek alandan doğu camından arka sokak görünür")
	# (3) Deep cash corner: hidden from BackroomSpot and from the inner door, seen only on entering by the back door.
	var cash: Vector2 = level.marker(&"BackroomCash").position
	var inner_d: Vector2 = level.marker(&"BackroomDoor").position + Vector2(TILE, 0)
	var inner_b: Vector2 = level.marker(&"BackDoor").position - Vector2(TILE, 0)
	is_false(_ray(space, level.marker(&"BackroomSpot").position, cash).is_empty(), "BackroomSpot nakdi görmez")
	is_false(_ray(space, inner_d, cash).is_empty(), "iç kapıdan giren nakdi görmez")
	is_true(_ray(space, inner_b, cash).is_empty(), "arka kapıdan giren nakdi görür")
	tree().root.remove_child(level)


func test_store_b_route_and_neighbour_navigation() -> void:
	var level: Level = _load(STORE_B)
	if level == null:
		return
	var tiles: LevelLayout = level.layout()
	var route: Array[Node2D] = level.marker_sequence(&"StreetRoute")
	var neighbour: Node2D = level.marker(&"NeighbourSpawn")
	if not is_true(route.size() == 6 and neighbour != null, "StreetRoute1..6 ve NeighbourSpawn"):
		return
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	var front: Vector2 = level.marker(&"FrontDoor").position
	var back: Vector2 = level.marker(&"BackDoor").position
	var outside_front: Vector2 = _door_side(tiles, front, false)
	var outside_back: Vector2 = _door_side(tiles, back, false)
	for door: StringName in DOORS:
		level.door_link(door).enabled = false
	await _sync(map)
	var outdoor: Array[LevelLayout.Kind] = [LevelLayout.Kind.SIDEWALK, LevelLayout.Kind.STREET]
	for i: int in range(1, route.size()):
		var path: PackedVector2Array = _path(map, route[i - 1].position, route[i].position)
		is_true(_arrives(path, route[i].position), "StreetRoute%d → StreetRoute%d bağlı" % [i, i + 1])
		for p: Vector2 in path:
			has(outdoor, tiles.kind_at(LevelLayout.cell_of(p)), "StreetRoute%d → %d yolu dışarıda (%s)" % [i, i + 1, p])
	is_true(route[1].position.distance_to(front) <= 2.0 * TILE + 0.1, "StreetRoute2 ön kapıda")
	is_true(route[5].position.distance_to(back) <= 2.0 * TILE + 0.1, "StreetRoute6 arka kapıda")
	for target: Vector2 in [outside_front, outside_back]:
		is_true(_arrives(_path(map, neighbour.position, target), target), "NeighbourSpawn → kapı önü %s dışarıdan" % target)
	for door: StringName in DOORS:
		level.door_link(door).enabled = true
	await _sync(map)
	var inside_front: Vector2 = _door_side(tiles, front, true)
	var inside_back: Vector2 = _door_side(tiles, back, true)
	var via_front: PackedVector2Array = _path(map, neighbour.position, inside_front)
	is_true(_arrives(via_front, inside_front) and _passes(via_front, front), "NeighbourSpawn → ön kapıdan içeri")
	var via_back: PackedVector2Array = _path(map, neighbour.position, inside_back)
	is_true(_arrives(via_back, inside_back) and _passes(via_back, back), "NeighbourSpawn → arka kapıdan arka odaya")
	is_true(_length(via_back) < _length(via_front), "komşu arka kapıya ön kapıdan yakın")
	NavigationServer2D.free_rid(map)
	tree().root.remove_child(level)


## IS-107 stage 2: store_b `tuning_overrides` (IS-106 VenueTuning). Reasons are stated as geometry relative to store_a:
## - population.convert_radius: the owner's shout turns passersby within the radius into neighbours. From ClerkSpot, store_a's
##   default 320 px covers 3 of the 6 StreetRoute points; store_b is larger (counter ~20 tiles from the west street), so its
##   radius must cover at least as many (640 px: d, e, f).
## - owner.shout_radius: the shout ring shows that reach, so it is not smaller than the conversion radius.
## - owner.neighbour_delay_sec: shout -> first neighbour at the back door (alert 3) within NEIGHBOUR_DOOR_SEC with the real path
##   length from NeighbourSpawn and the chaser speed (store_a: delay 8 + ~1-3 s; store_b's alley is longer).
const NEIGHBOUR_DOOR_SEC := 10.0


func test_store_b_tuning_overrides() -> void:
	var a: Level = _load(STORE_A)
	var b: Level = _load(STORE_B)
	if a == null or b == null:
		return
	eq(VenueTuning.errors(b.tuning_overrides), PackedStringArray(), "store_b ezmeleri geçerli")
	var pop_a: PopulationTuning = VenueTuning.of(a, VenueTuning.POPULATION) as PopulationTuning
	var pop_b: PopulationTuning = VenueTuning.of(b, VenueTuning.POPULATION) as PopulationTuning
	var owner_b: OwnerTuning = VenueTuning.of(b, VenueTuning.OWNER) as OwnerTuning
	var base_owner: OwnerTuning = VenueTuning.base(VenueTuning.OWNER) as OwnerTuning
	var covered_a: int = _route_within(a, pop_a.convert_radius)
	var covered_b: int = _route_within(b, pop_b.convert_radius)
	is_true(covered_a >= 1, "store_a: bağırış en az bir yoldan geçen noktasına ulaşır (%d)" % covered_a)
	is_true(covered_b >= covered_a, "store_b: dönüştürme yarıçapı caddeye store_a kadar ulaşır (%d >= %d)" % [covered_b, covered_a])
	is_true(owner_b.shout_radius >= pop_b.convert_radius, "bağırış halkası dönüştürme yarıçapını gösterir")
	eq(base_owner.shout_radius, 320.0, "global varsayılan değişmedi (kopya ezildi)")


func test_store_b_neighbour_reaches_back_door_in_time() -> void:
	var level: Level = _load(STORE_B)
	if level == null:
		return
	var owner_t: OwnerTuning = VenueTuning.of(level, VenueTuning.OWNER) as OwnerTuning
	var chaser_t: ChaserTuning = VenueTuning.of(level, VenueTuning.CHASER) as ChaserTuning
	var tiles: LevelLayout = level.layout()
	var spawn: Vector2 = level.marker(&"NeighbourSpawn").position
	var outside_back: Vector2 = _door_side(tiles, level.marker(&"BackDoor").position, false)
	var map: RID = await _enter_with_map(level)
	if not map.is_valid():
		return
	var path: PackedVector2Array = _path(map, spawn, outside_back)
	if is_true(_arrives(path, outside_back), "NeighbourSpawn → arka kapı önü"):
		var total: float = owner_t.neighbour_delay_sec + _length(path) / chaser_t.speed
		is_true(total <= NEIGHBOUR_DOOR_SEC, "bağırış → komşu arka kapıda %.1f sn <= %.0f" % [total, NEIGHBOUR_DOOR_SEC])
	NavigationServer2D.free_rid(map)
	tree().root.remove_child(level)


## Bot stand spots derived from zones/geometry (IS-106) land on the right side in store_b (counter faces south).
func test_store_b_derived_bot_stands() -> void:
	var level: Level = _load(STORE_B)
	if level == null:
		return
	var tiles: LevelLayout = level.layout()
	var props: Node2D = level.props_root()
	var reg: Vector2 = (props.get_node(^"Register") as Node2D).position
	var counter: Vector2 = (props.get_node(^"Counter") as Node2D).position
	var shelves: Array[Vector2] = []
	for i: int in 3:
		shelves.append((props.get_node(NodePath("ShelfProp%d" % (i + 1))) as Node2D).position)
	var s: Dictionary = BotBrain.derive_stands(MapGrid.new(tiles.rows), _zone_rects(level),
		func(n: StringName) -> Vector2: return level.marker(n).position if level.marker(n) != null else Vector2.INF,
		func(p: StringName) -> Array[Vector2]: return _seq_positions(level, p), reg, counter, shelves)
	var reg_stand: Vector2 = s.get(BotRules.SPOT_REGISTER, Vector2.INF) as Vector2
	has(_zones_at(level, reg_stand), &"StaffArea", "kasa noktası personel tarafında")
	is_true(reg_stand.distance_to(reg) <= TILE + 0.1, "kasa noktası kasaya bitişik")
	eq(reg_stand, level.marker(&"ClerkSpot").position, "store_b: kasa noktası = ClerkSpot (kuzey)")
	var counter_stand: Vector2 = s.get(BotRules.SPOT_COUNTER, Vector2.INF) as Vector2
	has(_zones_at(level, counter_stand), &"CustomerArea", "tezgâh noktası müşteri tarafında")
	is_true(counter_stand.y > counter.y, "tezgâh noktası tezgâhın güneyinde")
	eq(s.get(BotRules.SPOT_QUEUE), level.marker(&"QueueSpot1").position)
	eq(s.get(BotBrain.STANDS_SLACK), 0.0, "ClerkSpot kasaya bitişik")
	var outdoor: Array[LevelLayout.Kind] = [LevelLayout.Kind.SIDEWALK, LevelLayout.Kind.STREET]
	for spot: StringName in [BotRules.SPOT_OUTSIDE, BotRules.SPOT_ALLEY]:
		var at: Vector2 = s.get(spot, Vector2.INF) as Vector2
		if is_true(at.is_finite(), "nokta türetildi: %s" % spot):
			has(outdoor, tiles.kind_at(LevelLayout.cell_of(at)), "%s dışarıda" % spot)
			is_true(_zones_at(level, at).is_empty(), "%s hiçbir bölgede değil" % spot)
	is_true((s[BotRules.SPOT_OUTSIDE] as Vector2).x < level.marker(&"FrontDoor").position.x, "ön kapı dışı batıda (cadde)")
	is_true((s[BotRules.SPOT_ALLEY] as Vector2).distance_to(level.marker(&"BackDoor").position) <= 2.0 * TILE,
		"ara sokak noktası arka kapının yanında")
	eq(s.get(BotRules.SPOT_PEEK), level.marker(&"WindowLook3").position, "gözetleme = arka kapıya en yakın cam (doğu)")
	eq(s.get(BotRules.SPOT_HIDE), level.marker(&"BackroomCash").position)
	for i: int in 3:
		var stand: Vector2 = (s[BotBrain.STANDS_SHELVES] as Array)[i] as Vector2
		has(_zones_at(level, stand), &"CustomerArea", "raf ucu %d koridorda" % (i + 1))
		eq(tiles.kind_at(LevelLayout.cell_of(stand)), LevelLayout.Kind.FLOOR, "raf ucu %d zeminde" % (i + 1))


## Derived serve facing (IS-106): the owner at ClerkSpot faces the register, i.e. south (0, 1) in store_b.
func test_store_b_owner_faces_the_register() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(STORE_B)
	var owner: StoreOwner = stage.owner()
	stage.run(2.0)
	var clerk: Vector2 = stage.marker(&"ClerkSpot")
	var reg: Vector2 = stage.marker(&"Register")
	near((reg - clerk).normalized(), Vector2.DOWN, 0.001, "store_b kasası ClerkSpot'un güneyinde")
	if is_true(owner.global_position.distance_to(clerk) < 8.0, "sahip tezgâhta"):
		near(owner.facing, Vector2.DOWN, 0.05, "sahip kasaya (güneye) bakar")
	stage.leave()


# --- helpers ---

func _route_within(level: Level, radius: float) -> int:
	var clerk: Vector2 = level.marker(&"ClerkSpot").position
	var count: int = 0
	for node: Node2D in level.marker_sequence(&"StreetRoute"):
		if node.position.distance_to(clerk) <= radius:
			count += 1
	return count


func _seq_positions(level: Level, prefix: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node: Node2D in level.marker_sequence(prefix):
		out.append(node.position)
	return out


## Zone rects in level coordinates (outside the tree): area transform * shape position.
func _zone_rects(level: Level) -> Dictionary:
	var out: Dictionary = {}
	for zone_name: StringName in [BotBrain.ZONE_STAFF, BotBrain.ZONE_CUSTOMER, BotBrain.ZONE_BACKROOM]:
		var rects: Array[Rect2] = []
		var area: Area2D = level.zone(zone_name)
		for node: Node in area.get_children():
			var cs: CollisionShape2D = node as CollisionShape2D
			var box: RectangleShape2D = cs.shape as RectangleShape2D if cs != null else null
			if box != null:
				var center: Vector2 = area.transform * cs.position
				rects.append(Rect2(center - box.size * 0.5, box.size))
		out[zone_name] = rects
	return out

func _load(path: String) -> Level:
	var scene: PackedScene = load(path) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % path):
		return null
	var level: Level = scene.instantiate() as Level
	if not is_true(level != null, "%s kökü Level olmalı" % path):
		return null
	return autofree(level) as Level


func _cell(level: Level, marker_name: StringName) -> Vector2i:
	var marker: Node2D = level.marker(marker_name)
	if not is_true(marker != null, "Markers/%s yok" % marker_name):
		return Vector2i(-9999, -9999)
	return LevelLayout.cell_of(marker.position)


## Centre of the open tile beside a door: inside (interior floor) or outside (sidewalk/street).
static func _door_side(tiles: LevelLayout, door: Vector2, inside: bool) -> Vector2:
	var cell: Vector2i = LevelLayout.cell_of(door)
	for dir: Vector2i in DIRS:
		var kind: LevelLayout.Kind = tiles.kind_at(cell + dir)
		var interior: bool = kind == LevelLayout.Kind.FLOOR or kind == LevelLayout.Kind.BACKROOM
		var exterior: bool = kind == LevelLayout.Kind.SIDEWALK or kind == LevelLayout.Kind.STREET
		if (inside and interior) or (not inside and exterior):
			return LevelLayout.cell_center(cell + dir)
	return door


## Floor tile at a shelf run's end: the shelf neighbour continues away from this tile (not beside a shelf's long side).
static func _is_shelf_end(tiles: LevelLayout, cell: Vector2i) -> bool:
	for dir: Vector2i in DIRS:
		if tiles.kind_at(cell + dir) == LevelLayout.Kind.SHELF and tiles.kind_at(cell + dir * 2) == LevelLayout.Kind.SHELF:
			return true
	return false


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func _touches(tiles: LevelLayout, cell: Vector2i, kind: LevelLayout.Kind) -> bool:
	for dir: Vector2i in DIRS:
		if tiles.kind_at(cell + dir) == kind:
			return true
	return false


static func _zones_at(level: Level, pos: Vector2) -> Array[StringName]:
	var out: Array[StringName] = []
	for zone: Node in level.get_node("Zones").get_children():
		for node: Node in zone.find_children("*", "CollisionShape2D", false, false):
			var cs: CollisionShape2D = node as CollisionShape2D
			var rect_shape: RectangleShape2D = cs.shape as RectangleShape2D
			if rect_shape == null:
				continue
			var rect := Rect2((zone as Node2D).position + cs.position - rect_shape.size / 2.0, rect_shape.size)
			if rect.has_point(pos) and not out.has(StringName(zone.name)):
				out.append(StringName(zone.name))
	return out


## First sight-blocking obstacle (see-through glass and the low counter are skipped, S11 sight-line rule).
func _ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER)
	var exclude: Array[RID] = []
	for i: int in 8:
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or not PhysicsLayers.passes_sight((hit["collider"] as Node).get_groups()):
			return hit
		exclude.append(hit["rid"] as RID)
	return {}


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
