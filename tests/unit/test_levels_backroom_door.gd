extends TestCase
## IS-086: the shop's inner door D (GDD §9.3; behind-counter <-> back room). In store_a every door marker has a same-named
## Props door (S4: door tile + nav link + door object); D is unlocked, starts closed; when closed it cuts passage and sight
## (world layer; sight/hearing ray SightLine), when open both are free. The door sound (US-009, NoiseProfile KIND_DOOR) is
## heard from ClerkSpot: distance <= radius and no wall between (radius is not shrunk by walls); the door is behind the owner
## at the counter (outside the west-facing cone, GDD §9.3 COUNTER row).

const STORE := "res://levels/store_a.tscn"
const DOORS: Array[StringName] = [&"FrontDoor", &"BackDoor", &"BackroomDoor"]
const TILE := 32.0
## The owner at ClerkSpot faces the door (west) (GDD §9.3 agenda table, COUNTER).
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
	var staff_side: Vector2 = at + Vector2(0.0, TILE)  # staff side (horizontal wall: south)
	var backroom_side: Vector2 = at - Vector2(0.0, TILE)  # back room side (north)

	# Closed: the wing is on the world layer; rays from the staff side into the back room are cut, passage is blocked.
	is_true(door.is_blocking(), "kapalı D geçişi engeller")
	is_false(SightLine.first_blocker(space, staff_side, backroom_side).is_empty(), "kapalı D görüşü keser")

	# Sound: distance from the door position to ClerkSpot is within the radius; no wall between (the source's own body does not count).
	var radius: float = NoiseProfile.load_default().radius_for(NoiseProfile.KIND_DOOR)
	var distance: float = clerk.distance_to(at)
	is_true(distance <= radius, "ClerkSpot kapı sesinin içinde (%.0f ≤ %.0f px)" % [distance, radius])
	var hit: Dictionary = SightLine.first_blocker(space, clerk, at)
	is_true(hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, at),
		"ClerkSpot ile D arasında duvar yok (ses yarıçapı küçülmez)")
	# The door is behind the owner: outside the west-facing cone (entered by sneaking, the only trace is sound).
	is_true(CLERK_FACING.dot((at - clerk).normalized()) < 0.0, "D tezgâhtaki sahibin arkasında")

	# Open: wing disabled; rays and passage are free.
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
