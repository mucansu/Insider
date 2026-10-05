extends TestCase
## IS-106 (KR-037 map independence): per-map tuning overrides (TuningOverrides core + VenueTuning access point + Level
## `tuning_overrides`), tile geometry (MapGrid: stands and facings from the layout), the bot's derived stand spots (store_a values
## unchanged, mirrored on the mirror fixture) and the owner's derived task facing; the mirror fixture (tests/fixtures/build_mirror.gd)
## stays in sync with store_a.

const STORE := "res://levels/store_a.tscn"
const MIRROR := "res://tests/fixtures/store_a_mirror.tscn"
const LEVEL_DIR := "res://levels"
const TILE := 32.0


# --- per-map tuning (AC2) ---

func test_empty_override_is_the_base_itself() -> void:
	var base: StoreToolsTuning = StoreToolsTuning.load_default()
	is_true(TuningOverrides.apply(base, {}) == base, "boş ezme: aynı nesne")
	var holder: Node = autofree(Level.new()) as Node
	var child := Node.new()
	holder.add_child(child)
	is_true(VenueTuning.of(child, VenueTuning.STORE_TOOLS, base) == base, "seviyede ezme yok: varsayılan")
	is_true(VenueTuning.of(child, VenueTuning.STORE_TOOLS) == load(VenueTuning.PATHS[VenueTuning.STORE_TOOLS]), "temel = küresel")
	var orphan: Node = autofree(Node.new()) as Node
	is_true(VenueTuning.of(orphan, VenueTuning.OWNER) == load(VenueTuning.PATHS[VenueTuning.OWNER]), "seviye dışı: varsayılan")


func test_field_override_applies_to_a_copy() -> void:
	var base: StoreToolsTuning = StoreToolsTuning.load_default()
	var before: float = base.topple_radius
	var level: Level = autofree(Level.new()) as Level
	level.tuning_overrides = {&"store_tools": {"topple_radius": 400, &"talk_range": 80.0}}
	var child := Node2D.new()
	level.add_child(child)
	var got: StoreToolsTuning = VenueTuning.of(child, VenueTuning.STORE_TOOLS) as StoreToolsTuning
	if not is_true(got != null and got != base, "kopya döner"):
		return
	eq(got.topple_radius, 400.0, "int -> float ezildi")
	eq(got.talk_range, 80.0)
	eq(got.phone_radius, base.phone_radius, "yazılmayan alan varsayılan")
	eq(base.topple_radius, before, "küresel .tres değişmedi")
	is_true(VenueTuning.of(child, VenueTuning.STORE_TOOLS) == got, "seviyede önbellekli")
	is_true(VenueTuning.of(level, VenueTuning.STORE_TOOLS, got) == got, "zaten seviyenin kopyası: yeniden kopyalanmaz")
	eq(VenueTuning.of(child, VenueTuning.OWNER), load(VenueTuning.PATHS[VenueTuning.OWNER]), "başka ad etkilenmez")
	eq(level.tuning_overrides.size(), 1)


func test_unknown_name_and_field_are_errors() -> void:
	var problems: PackedStringArray = VenueTuning.errors({&"nope": {"x": 1}, &"owner": {"walk_speed": "hızlı", "no_such": 1},
		&"chaser": 5})
	eq(problems.size(), 4, "bilinmeyen ad + yanlış tür + bilinmeyen alan + sözlük değil: %s" % [problems])
	is_true(VenueTuning.errors({&"owner": {"walk_speed": 90.0}, &"population": {"customer_max": 3}}).is_empty(), "geçerli ezme")
	allow_errors()
	var base: StoreToolsTuning = StoreToolsTuning.load_default()
	var copy: StoreToolsTuning = TuningOverrides.apply(base, {"no_such": 1.0, "topple_radius": 300.0}) as StoreToolsTuning
	eq(copy.topple_radius, 300.0, "geçerli alan yine uygulanır")
	is_false(VenueTuning.base(&"nope") != null, "bilinmeyen ad: null + hata")


func test_level_scenes_have_valid_overrides() -> void:
	var scenes: Array[String] = [MIRROR]
	for f: String in DirAccess.get_files_at(LEVEL_DIR):
		if f.ends_with(".tscn"):
			scenes.append(LEVEL_DIR.path_join(f))
	for path: String in scenes:
		var level: Level = (load(path) as PackedScene).instantiate() as Level
		if level == null:
			continue
		eq(VenueTuning.errors(level.tuning_overrides), PackedStringArray(), path)
		level.free()


func test_level_override_reaches_props_and_owner() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(NpcStage.STORE, func(level: Level) -> void:
		level.tuning_overrides = {&"store_tools": {"topple_radius": 123.0}, &"owner": {"walk_speed": 77.0}})
	var shelf: ShelfProp = stage.level.props_root().get_node(^"ShelfProp1") as ShelfProp
	eq(shelf.tuning.topple_radius, 123.0, "raf prop'u seviye ezmesini okur")
	eq(stage.owner().owner_tuning.walk_speed, 77.0, "sahip ayarı ezildi")
	eq(stage.alert().tuning.walk_speed, 77.0, "uyarı yöneticisi aynı ezmeyi görür")
	ne(StoreToolsTuning.load_default().topple_radius, 123.0, "küresel değişmedi")
	stage.leave()


# --- tile geometry ---

func test_map_grid_rules() -> void:
	var grid := MapGrid.new(PackedStringArray([
		"%%%%%%",
		"%S...%",
		"%ST..%",
		"%....%",
		"%%+%%%",
		"%,,,,%",
	]))
	var at: Vector2 = MapGrid.cell_center(Vector2i(2, 1))
	eq(grid.face_block(at, Vector2.UP), Vector2.UP, "ipucu engele bakıyor: korunur")
	eq(grid.face_block(at, Vector2.RIGHT), Vector2.DOWN, "ipucu boşluğa bakıyor: en yakın açılı engel (eşitlikte DIRS sırası)")
	eq(grid.face_block(MapGrid.cell_center(Vector2i(3, 2)), Vector2.RIGHT), Vector2.LEFT, "tek engel tezgâh: ona döner")
	eq(grid.face_block(MapGrid.cell_center(Vector2i(3, 3)), Vector2.DOWN), Vector2.DOWN, "komşu engel yok: ipucu")
	eq(grid.away_from_block(MapGrid.cell_center(Vector2i(2, 1))), MapGrid.cell_center(Vector2i(3, 1)), "engelden uzak taraf")
	var staff: Array[Rect2] = [Rect2(Vector2(3, 2) * TILE, Vector2(2, 1) * TILE)]
	eq(grid.side_stand(MapGrid.cell_center(Vector2i(2, 2)), staff), MapGrid.cell_center(Vector2i(3, 2)), "bölgedeki komşu")
	var inside: Array[Rect2] = [Rect2(Vector2(1, 1) * TILE, Vector2(4, 3) * TILE)]
	var door: Vector2 = MapGrid.cell_center(Vector2i(2, 4))
	eq(grid.outward(door, inside), Vector2i.DOWN, "kapının dış yüzü")
	eq(grid.outside_of(door, inside, 2), MapGrid.cell_center(Vector2i(2, 5)), "yol kapalıysa daha kısa")
	eq(grid.beside_door(door, inside, MapGrid.cell_center(Vector2i(1, 5))), MapGrid.cell_center(Vector2i(3, 5)),
		"iki yan açık: kaçınılan noktadan uzak olan")


func test_zone_side_rule() -> void:
	var at := Vector2(80.0, 80.0)
	var customer: Array[Rect2] = [Rect2(Vector2(32.0, 64.0), Vector2(32.0, 32.0))]  # the tile west of `at`
	eq(MapGrid.zone_side(at, customer, Vector2.RIGHT, false), Vector2.LEFT, "bölgeye doğru (tezgâh müşteri tarafı)")
	eq(MapGrid.zone_side(at, customer, Vector2.LEFT, true), Vector2.RIGHT, "bölgeden uzak (kasa personel tarafı)")
	var none: Array[Rect2] = []
	eq(MapGrid.zone_side(at, none, Vector2.UP, true), Vector2.UP, "bölge komşusu yok: ipucu")


## Register (staff side) and counter (customer side) interaction sides come from the zones: store_a as in the data, mirrored on the mirror.
func test_prop_sides_from_zones() -> void:
	for case: Array in [[NpcStage.STORE, Vector2.RIGHT], [MIRROR, Vector2.LEFT]]:
		var stage := NpcStage.new(self)
		await stage.enter(case[0] as String)
		var staff: Vector2 = case[1]
		var props: Node2D = stage.level.props_root()
		eq((props.get_node(^"Register/Interactable") as Interactable)._required_side(), staff, "%s kasa" % case[0])
		eq((props.get_node(^"Counter/Buy") as Interactable)._required_side(), -staff, "%s satın al" % case[0])
		eq((props.get_node(^"Counter/Send") as Interactable)._required_side(), -staff, "%s gönder" % case[0])
		stage.leave()


# --- bot stands (store_a unchanged, mirror mirrored) ---

func test_store_a_stands_match_the_old_offsets() -> void:
	var level: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	var s: Dictionary = _stands(level)
	var props: Node2D = level.props_root()
	var reg: Vector2 = (props.get_node(^"Register") as Node2D).position
	var counter: Vector2 = (props.get_node(^"Counter") as Node2D).position
	eq(s.get(BotRules.SPOT_REGISTER), reg + Vector2(TILE, 0.0), "kasa personel tarafı (eski +1 karo)")
	eq(s.get(BotRules.SPOT_COUNTER), counter + Vector2(-TILE, 0.0), "tezgâh müşteri tarafı (eski -1 karo)")
	eq(s.get(BotRules.SPOT_QUEUE), _m(level, &"QueueSpot1"))
	eq(s.get(BotRules.SPOT_OUTSIDE), _m(level, &"FrontDoor") + Vector2(0.0, 2.0 * TILE), "ön kapı dışı (eski +2 karo)")
	eq(s.get(BotRules.SPOT_ALLEY), _m(level, &"BackDoor") + Vector2(-TILE, -TILE), "ara sokak (eski kuzeybatı)")
	eq(s.get(BotRules.SPOT_PEEK), _m(level, &"WindowLook3"), "yan cam (eski WindowLook3)")
	eq(s.get(BotRules.SPOT_HIDE), _m(level, &"BackroomCash"))
	eq(s.get(BotBrain.STANDS_SLACK), 0.0, "ClerkSpot kasaya bitişik")
	for i: int in 3:
		var shelf: Vector2 = (props.get_node(NodePath("ShelfProp%d" % (i + 1))) as Node2D).position
		eq((s[BotBrain.STANDS_SHELVES] as Array)[i], shelf + Vector2(TILE, 0.0), "raf ucu koridor tarafı %d" % (i + 1))


func test_mirror_stands_are_mirrored() -> void:
	var store: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	var mirror: Level = autofree((load(MIRROR) as PackedScene).instantiate()) as Level
	var width: float = float(store.layout().size_in_tiles().x) * TILE
	var a: Dictionary = _stands(store)
	var b: Dictionary = _stands(mirror)
	for spot: StringName in [BotRules.SPOT_REGISTER, BotRules.SPOT_COUNTER, BotRules.SPOT_QUEUE, BotRules.SPOT_OUTSIDE,
			BotRules.SPOT_ALLEY, BotRules.SPOT_PEEK, BotRules.SPOT_HIDE]:
		if is_true(a.has(spot) and b.has(spot), "nokta türetildi: %s" % spot):
			eq(b[spot], _mx(a[spot] as Vector2, width), "aynada yansır: %s" % spot)
	for i: int in 3:
		eq((b[BotBrain.STANDS_SHELVES] as Array)[i], _mx((a[BotBrain.STANDS_SHELVES] as Array)[i] as Vector2, width), "raf %d" % i)


func test_mirror_fixture_in_sync_with_store_a() -> void:
	var store: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	var mirror: Level = autofree((load(MIRROR) as PackedScene).instantiate()) as Level
	var rows: PackedStringArray = store.layout().rows
	var mrows: PackedStringArray = mirror.layout().rows
	if not eq(mrows.size(), rows.size(), "satır sayısı"):
		return
	for y: int in rows.size():
		eq(mrows[y], rows[y].reverse(), "satır %d yansımış (yeniden üret: tests/fixtures/build_mirror.gd)" % y)
	var width: float = float(rows[0].length()) * TILE
	for container: String in ["Markers", "SpawnPoints", "Props"]:
		var src: Node = store.get_node(container)
		for child: Node in src.get_children():
			var twin: Node2D = mirror.get_node(container).get_node_or_null(NodePath(child.name)) as Node2D
			if is_true(twin != null, "%s/%s aynada var" % [container, child.name]):
				eq(twin.position, _mx((child as Node2D).position, width), "%s/%s yansımış" % [container, child.name])
	eq((mirror.npcs_root().get_node(^"Owner") as Node2D).position,
		_mx((store.npcs_root().get_node(^"Owner") as Node2D).position, width), "sahip yansımış")


# --- owner facing ---

func test_owner_task_facing_derived_from_geometry() -> void:
	var tuning: OwnerTuning = load(VenueTuning.PATHS[VenueTuning.OWNER]) as OwnerTuning
	var store: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	var mirror: Level = autofree((load(MIRROR) as PackedScene).instantiate()) as Level
	var grid_a: MapGrid = CivilianSenses.grid_of(store)
	var grid_b: MapGrid = CivilianSenses.grid_of(mirror)
	for task: AgendaTask in tuning.tasks:
		for i: int in _spots(store, task.marker).size():
			var at: Vector2 = _spots(store, task.marker)[i]
			var bt: Vector2 = _spots(mirror, task.marker)[i]
			eq(grid_a.face_block(at, task.facing), task.facing.normalized(), "store_a %s: ayardaki yön" % task.name)
			var want := Vector2(-task.facing.x, task.facing.y).normalized()
			eq(grid_b.face_block(bt, task.facing), want, "ayna %s: yön yansır" % task.name)
	var clerk_b: Vector2 = _m(mirror, tuning.counter_marker)
	eq(grid_b.face_block(clerk_b, tuning.serve_facing), Vector2.RIGHT, "aynada servis tezgâha (doğuya) bakar")


func test_owner_faces_the_counter_on_the_mirror() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(MIRROR)
	var owner: StoreOwner = stage.owner()
	stage.run(2.0)
	var clerk: Vector2 = stage.marker(&"ClerkSpot")
	var reg: Vector2 = stage.marker(&"Register")
	if is_true(owner.global_position.distance_to(clerk) < 8.0, "sahip tezgâhta"):
		near(owner.facing, (reg - clerk).normalized(), 0.05, "kasaya bakar (aynada doğu)")
	stage.leave()


func _stands(level: Level) -> Dictionary:
	var props: Node2D = level.props_root()
	var shelves: Array[Vector2] = []
	for i: int in 3:
		shelves.append((props.get_node(NodePath("ShelfProp%d" % (i + 1))) as Node2D).position)
	return BotBrain.derive_stands(MapGrid.new(level.layout().rows), _zones(level), func(n: StringName) -> Vector2: return _m(level, n),
		func(p: StringName) -> Array[Vector2]: return _seq(level, p), (props.get_node(^"Register") as Node2D).position,
		(props.get_node(^"Counter") as Node2D).position, shelves)


## Zone rects outside the tree (Zones at the origin): area transform * shape position.
func _zones(level: Level) -> Dictionary:
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


func _m(level: Level, marker_name: StringName) -> Vector2:
	var node: Node2D = level.marker(marker_name)
	return node.position if node != null else Vector2.INF


func _seq(level: Level, prefix: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for node: Node2D in level.marker_sequence(prefix):
		out.append(node.position)
	return out


func _spots(level: Level, marker_name: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = _seq(level, marker_name)
	if out.is_empty():
		out.append(_m(level, marker_name))
	return out


func _mx(pos: Vector2, width: float) -> Vector2:
	return Vector2(width - pos.x, pos.y)
