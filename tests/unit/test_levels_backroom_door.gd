extends TestCase
## IS-086: bakkalın iç kapısı D (GDD §9.3; tezgâh arkası ↔ arka oda). store_a'da her kapı işaretinin aynı adlı
## Props kapısı var (S4: kapı karosu + gezinme bağı + kapı nesnesi); D kilitsiz, kapalı başlar; kapalıyken
## geçişi ve görüşü keser (world katmanı; görüş/duyma ışını SightLine), açılınca ikisi de açılır. Kapı sesi
## (US-009, NoiseProfile KIND_DOOR) ClerkSpot'tan duyulur: mesafe ≤ yarıçap ve araya duvar girmez (yarıçap duvarla
## küçülmez); kapı tezgâhtaki sahibin arkasında (batıya bakan koninin dışında, GDD §9.3 TEZGÂH satırı).

const STORE := "res://levels/store_a.tscn"
const DOORS: Array[StringName] = [&"FrontDoor", &"BackDoor", &"BackroomDoor"]
const TILE := 32.0
## ClerkSpot'taki sahip kapıya (batıya) bakar (GDD §9.3 ajanda tablosu, TEZGÂH).
const CLERK_FACING := Vector2.LEFT


func test_every_door_marker_has_a_door_prop() -> void:
	var level: Level = _load()
	if level == null:
		return
	for door_name: StringName in DOORS:
		var marker: Node2D = level.marker(door_name)
		var door: Door = level.props_root().get_node_or_null(NodePath(String(door_name))) as Door
		if not is_true(marker != null and door != null, "%s: işaret ve Props kapısı olmalı" % door_name):
			continue
		near(door.position, marker.position, 0.01, "%s kapısı işaretin karosunda" % door_name)
		near(door.rotation_degrees, marker.rotation_degrees, 0.01, "%s kapısı işaretle aynı yönde" % door_name)
		is_true(level.door_link(door_name) != null, "%s gezinme bağı var" % door_name)
	var d: Door = level.props_root().get_node_or_null(^"BackroomDoor") as Door
	if d != null:
		is_false(d.is_open, "D kapalı başlar (arka odadaki oyuncu sahibi görmez, GDD §9.3 kabul)")
		is_true(d.def != null and d.def.requirement == null, "D kilitsiz (gereksinim yok)")


func test_backroom_door_blocks_sight_when_closed_and_is_heard_from_clerk_spot() -> void:
	var level: Level = _load()
	if level == null:
		return
	tree().root.add_child(level)
	await tree().physics_frame
	await tree().physics_frame
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var door: Door = level.props_root().get_node(^"BackroomDoor") as Door
	var at: Vector2 = door.global_position
	var clerk: Vector2 = level.marker(&"ClerkSpot").global_position
	var staff_side: Vector2 = at + Vector2(0.0, TILE)  # personel tarafı (yatay duvar: güney)
	var backroom_side: Vector2 = at - Vector2(0.0, TILE)  # arka oda tarafı (kuzey)

	# Kapalı: kanat world katmanında; personel tarafından arka odaya ışın kesilir, geçiş engellenir.
	is_true(door.is_blocking(), "kapalı D geçişi engeller")
	is_false(SightLine.first_blocker(space, staff_side, backroom_side).is_empty(), "kapalı D görüşü keser")

	# Ses: kapı konumundan ClerkSpot'a mesafe yarıçap içinde; araya duvar girmez (kaynağın kendi gövdesi sayılmaz).
	var radius: float = NoiseProfile.load_default().radius_for(NoiseProfile.KIND_DOOR)
	var distance: float = clerk.distance_to(at)
	is_true(distance <= radius, "ClerkSpot kapı sesinin içinde (%.0f ≤ %.0f px)" % [distance, radius])
	var hit: Dictionary = SightLine.first_blocker(space, clerk, at)
	is_true(hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, at),
		"ClerkSpot ile D arasında duvar yok (ses yarıçapı küçülmez)")
	# Kapı sahibin arkasında: batıya bakan koninin dışında (sızarak girilir, iz yalnız sestir).
	is_true(CLERK_FACING.dot((at - clerk).normalized()) < 0.0, "D tezgâhtaki sahibin arkasında")

	# Açık: kanat devre dışı; ışın ve geçiş serbest.
	door.is_open = true
	await tree().physics_frame
	await tree().physics_frame
	is_false(door.is_blocking(), "açık D geçişi engellemez")
	is_true(SightLine.first_blocker(space, staff_side, backroom_side).is_empty(), "açık D görüşü geçirir")
	tree().root.remove_child(level)


func _load() -> Level:
	var scene: PackedScene = load(STORE) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % STORE):
		return null
	return autofree(scene.instantiate()) as Level
