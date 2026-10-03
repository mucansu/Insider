extends TestCase
## IS-098 (KR-031 addendum): the counter is a low obstacle for everyone and the owner has a 360 deg arm-reach near band.
## AC1: counter collision and navigation cut unchanged (walking stops); NPC sight line passes the counter (ClerkSpot -> QueueSpot1 and
## the customer side (502,378); QueueSpot1 -> the register emptier); shelves/cooler/crate/walls unchanged (RestockSpot1 -> register cut).
## AC4: `PerceptionRules` arm reach (`reach_px`: NEAR regardless of facing, 0 = off); the owner (owner_tuning.arm_reach_px 48) detects a
## player emptying the register beside it at (590,395) (~86 deg off its westward facing, outside the 50 deg cone), line of sight still
## required; only the owner sets it (civilians, chaser unchanged). AC5 (unit side): the queue customer's cone sees the emptier.

const STORE := "res://levels/store_a.tscn"
const DT := 1.0 / 60.0
const CUSTOMER_SIDE := Vector2(502, 378)
## Register emptied from beside the owner (staff side, south of ClerkSpot) and from the staff side of the register (test_owner).
const BESIDE_OWNER := Vector2(590, 395)
const REGISTER_STAFF := Vector2(586, 366)


func _store() -> Level:
	var level: Level = (load(STORE) as PackedScene).instantiate() as Level
	tree().root.add_child(level)
	autofree(level)
	await tree().physics_frame
	await tree().physics_frame
	return level


func _space(level: Level) -> PhysicsDirectSpaceState2D:
	return level.get_world_2d().direct_space_state


# --- AC1 ---

func test_counter_collides_but_sight_passes() -> void:
	var level: Level = await _store()
	var space: PhysicsDirectSpaceState2D = _space(level)
	var body: StaticBody2D = level.get_node_or_null(^"Walls/Counter1") as StaticBody2D
	if not is_true(body != null, "Counter1 ayrı gövde"):
		return
	eq(body.collision_layer, PhysicsLayers.WORLD, "tezgâh world katmanında: yürüme kesilir")
	is_true(body.is_in_group(PhysicsLayers.LOW_OBSTACLE_GROUP), "alçak engel grubunda")
	is_false(body.is_in_group(PhysicsLayers.SEE_THROUGH_GROUP), "cam değil (vitrin mantığı tezgâhı görmez)")
	# A body moving east from the customer side is stopped by the counter (walking is cut).
	var probe := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	probe.shape = circle
	probe.collision_mask = PhysicsLayers.WORLD
	probe.transform = Transform2D(0.0, level.to_global(level.marker(&"Counter").position))
	is_false(space.intersect_shape(probe, 1).is_empty(), "tezgâh üstünde durulamaz")
	var clerk: Vector2 = level.to_global(level.marker(&"ClerkSpot").position)
	var queue: Vector2 = level.to_global(level.marker(&"QueueSpot1").position)
	var raw: Dictionary = space.intersect_ray(PhysicsRayQueryParameters2D.create(clerk, queue, PhysicsLayers.WORLD))
	is_true(raw.get("collider") == body, "fiziksel ışın tezgâha çarpar (gruplar atlanmadan)")
	is_true(SightLine.is_clear(space, clerk, queue), "sahip → QueueSpot1 görüş hattı")
	is_true(SightLine.is_clear(space, clerk, level.to_global(CUSTOMER_SIDE)), "sahip → müşteri tarafı (502,378)")
	for target: Vector2 in [REGISTER_STAFF, BESIDE_OWNER]:
		is_true(SightLine.is_clear(space, queue, level.to_global(target)), "QueueSpot1 → kasa boşaltan %s" % target)
	var register: Vector2 = level.to_global(level.marker(&"Register").position)
	is_false(SightLine.is_clear(space, level.to_global(level.marker(&"RestockSpot1").position), register),
		"RestockSpot1 → kasa hâlâ kesik (raf/duvar)")
	is_false(SightLine.is_clear(space, level.to_global(Vector2(5 * 32 + 16, 5 * 32 + 16)),
		level.to_global(Vector2(5 * 32 + 16, 7 * 32 + 16))), "raf sırası keser")


func test_navigation_still_cut_by_counter() -> void:
	var level: Level = (load(STORE) as PackedScene).instantiate() as Level
	autofree(level)
	var poly: NavigationPolygon = level.navigation_region().navigation_polygon
	var counter: Vector2 = level.marker(&"Counter").position
	var open: Vector2 = level.marker(&"QueueSpot1").position
	eq(_on_mesh(poly, counter), false, "tezgâh karosu gezinme ağında değil")
	eq(_on_mesh(poly, open), true, "kontrol: kuyruk noktası ağda")


static func _on_mesh(poly: NavigationPolygon, point: Vector2) -> bool:
	var vertices: PackedVector2Array = poly.get_vertices()
	for i: int in poly.get_polygon_count():
		var outline := PackedVector2Array()
		for index: int in poly.get_polygon(i):
			outline.append(vertices[index])
		if Geometry2D.is_point_in_polygon(point, outline):
			return true
	return false


func test_perception_line_of_sight_through_counter() -> void:
	var level: Level = await _store()
	var eye := Perception.new()
	eye.tuning = load(Perception.TUNING_PATH) as PerceptionTuning
	level.add_child(eye)
	var clerk: Vector2 = level.to_global(level.marker(&"ClerkSpot").position)
	is_true(eye.has_line_of_sight(clerk, level.to_global(level.marker(&"QueueSpot1").position)), "Perception: sahip → kuyruk")
	is_true(eye.has_line_of_sight(clerk, level.to_global(CUSTOMER_SIDE)), "Perception: sahip → müşteri tarafı")
	is_false(eye.has_line_of_sight(level.to_global(level.marker(&"RestockSpot1").position),
		level.to_global(level.marker(&"Register").position)), "Perception: raf keser")


# --- AC4: rule ---

func test_reach_band_rule() -> void:
	var p := PerceptionRules.Params.new()
	p.half_angle_deg = 50.0
	p.view_range = 224.0
	p.near_ratio = 0.5
	var at := Vector2(592, 368)
	var beside: Vector2 = BESIDE_OWNER
	eq(PerceptionRules.band(p, at, Vector2.LEFT, beside), PerceptionRules.Band.NONE, "kapalıyken koni dışı")
	p.reach_px = 48.0
	eq(PerceptionRules.band(p, at, Vector2.LEFT, beside), PerceptionRules.Band.NEAR, "kol mesafesinde yakın bant")
	eq(PerceptionRules.band(p, at, Vector2.LEFT, at + Vector2(48, 0)), PerceptionRules.Band.NEAR, "sınır dahil, tam arkada")
	eq(PerceptionRules.band(p, at, Vector2.LEFT, at + Vector2(49, 0)), PerceptionRules.Band.NONE, "48 px ötesi arkada görmez")
	eq(PerceptionRules.band(p, at, Vector2.ZERO, at + Vector2(0, 30)), PerceptionRules.Band.NEAR, "bakış yönü yokken de")
	is_true(PerceptionRules.in_reach(p, at, at + Vector2(30, 30)))
	p.reach_px = 0.0
	is_false(PerceptionRules.in_reach(p, at, at))


# --- AC4: owner in store_a ---

func test_owner_detects_register_emptier_beside_it() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	eq(o.perception().arm_reach(), 48.0, "owner_tuning.arm_reach_px")
	o.global_position = stage.marker(&"ClerkSpot")
	o.perception().facing = Vector2.LEFT
	stage.player(2, BESIDE_OWNER)
	await tree().physics_frame
	var offset: Vector2 = BESIDE_OWNER - o.perception().global_position
	is_true(rad_to_deg(absf(Vector2.LEFT.angle_to(offset))) > 50.0, "koni dışında (%.0f°)" % rad_to_deg(Vector2.LEFT.angle_to(offset)))
	var register: Interactable = stage.level.props_root().get_node(^"Register/Interactable") as Interactable
	register.host_start(2, 1)
	var detected_at: float = _detect_time(o, 2, 3.0)
	is_true(detected_at > 0.0 and detected_at <= 1.0, "kasa boşaltan yanındaki oyuncu tespit (%.2f sn)" % detected_at)
	register.host_cancel(2, 1)
	# Control: without arm reach the same spot is not seen (cone only).
	stage.leave()
	var stage2 := NpcStage.new(self)
	await stage2.enter()
	var o2: StoreOwner = stage2.owner()
	o2.perception().set_arm_reach(0.0)
	o2.global_position = stage2.marker(&"ClerkSpot")
	o2.perception().facing = Vector2.LEFT
	stage2.player(2, BESIDE_OWNER)
	await tree().physics_frame
	var register2: Interactable = stage2.level.props_root().get_node(^"Register/Interactable") as Interactable
	register2.host_start(2, 1)
	eq(_detect_time(o2, 2, 2.0), -1.0, "kol mesafesi kapalıyken koni dışı: görmez (eski davranış)")
	eq(o2.suspicion().value_of(2), 0.0)
	register2.host_cancel(2, 1)
	stage2.leave()


func test_arm_reach_still_needs_line_of_sight() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	# Staff side below the back-room wall (row 8, col 18) and the back room above it: 46 px apart, the wall between.
	o.global_position = Vector2(592, 296)
	o.perception().facing = Vector2.LEFT
	stage.player(2, Vector2(592, 250))
	await tree().physics_frame
	var obs: Perception.Observation = o.perception().observe_target(stage.level.players_root().get_node(^"2"))
	eq(obs.band, PerceptionRules.Band.NEAR, "kol mesafesinde")
	is_false(obs.line_clear, "duvar arkası: görüş hattı yok")
	eq(obs.rate, 0.0, "dolmaz")
	stage.leave()


func test_only_owner_sets_arm_reach() -> void:
	var eye := Perception.new()
	eye.tuning = load(Perception.TUNING_PATH) as PerceptionTuning
	autofree(eye)
	eq(eye.arm_reach(), 0.0, "varsayılan kapalı (sivil, kovalayan)")
	eq(eye.params().reach_px, 0.0)
	var callers: Array[String] = []
	for path: String in _scripts("res://entities"):
		if FileAccess.get_file_as_string(path).contains("set_arm_reach("):
			callers.append(path)
	eq(callers, ["res://entities/npc/components/perception.gd", "res://entities/npc/owner/store_owner.gd"] as Array[String],
		"yalnız sahip kol mesafesi kurar")


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	out.sort()
	return out


## First time (s) the owner's meter reaches DETECT for `peer` while ticking suspicion only (brain not stepped); -1 if not.
func _detect_time(o: StoreOwner, peer: int, seconds: float) -> float:
	for i: int in roundi(seconds / DT):
		o.suspicion().tick(DT)
		if o.suspicion().level_of(peer) >= Suspicion.Level.DETECT:
			return (i + 1) * DT
	return -1.0
