extends TestCase
## IS-098 AC3 (KR-031 addendum): the low obstacle is one class for sight and sound. `Hearing` passes a body by its group
## (`PhysicsLayers.LOW_OBSTACLE_GROUP`), not by a shape-name prefix: a `Counter*`-named body without the group blocks, a body of any
## name in the group passes; store_a's real counter passes the owner's ear at ClerkSpot to the customer side (US-010 shelf sound).

const STORE := "res://levels/store_a.tscn"
const WORLD := PhysicsLayers.WORLD


func _hearing(at: Vector2) -> Hearing:
	var hearing := Hearing.new()
	hearing.position = at
	tree().root.add_child(hearing)
	autofree(hearing)
	return hearing


## Static rectangular body named `body_name` (shape child named like the body, as old S4 counter shapes were).
func _body(body_name: String, center: Vector2, size: Vector2, group: StringName) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = WORLD
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	shape.name = body_name
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	if not group.is_empty():
		body.add_to_group(group)
	tree().root.add_child(body)
	autofree(body)
	return body


func _settle() -> void:
	await tree().physics_frame
	await tree().physics_frame


func test_group_not_name_decides() -> void:
	var ear: Hearing = _hearing(Vector2(0, 0))
	var target := Vector2(100, 0)
	var counter: StaticBody2D = _body("Counter1", Vector2(50, 0), Vector2(16, 60), &"")
	await _settle()
	is_false(ear.has_line_of_sight(target), "ad öneki 'Counter' tek başına sesi geçirmez (grup yok)")
	counter.add_to_group(PhysicsLayers.LOW_OBSTACLE_GROUP)
	is_true(ear.has_line_of_sight(target), "low_obstacle grubundaki gövde sesi geçirir")
	var desk: StaticBody2D = _body("Desk", Vector2(50, 0), Vector2(16, 60), PhysicsLayers.LOW_OBSTACLE_GROUP)
	await _settle()
	is_true(ear.has_line_of_sight(target), "adı ne olursa olsun alçak engel geçer (%s)" % desk.name)
	_body("Wall9", Vector2(75, 0), Vector2(8, 60), &"")
	await _settle()
	is_false(ear.has_line_of_sight(target), "alçak engelin arkasındaki duvar yine keser")


func test_hearing_and_sight_share_the_class() -> void:
	eq(PhysicsLayers.PASS_SIGHT_GROUPS, [PhysicsLayers.SEE_THROUGH_GROUP, PhysicsLayers.LOW_OBSTACLE_GROUP] as Array[StringName])
	is_true(PhysicsLayers.passes_sight([PhysicsLayers.LOW_OBSTACLE_GROUP] as Array[StringName]))
	is_true(PhysicsLayers.passes_sight([&"x", PhysicsLayers.SEE_THROUGH_GROUP] as Array[StringName]))
	is_false(PhysicsLayers.passes_sight([] as Array[StringName]))
	is_false(PhysicsLayers.passes_sight([&"Counter"] as Array[StringName]), "ad değil grup")
	var consts: Dictionary = (load("res://entities/npc/components/hearing.gd") as Script).get_script_constant_map()
	is_false(consts.has("LOW_SHAPE_PREFIXES"), "ad-öneki istisnası kalktı")


func test_store_counter_passes_sound_from_clerk_spot() -> void:
	var level: Level = (load(STORE) as PackedScene).instantiate() as Level
	tree().root.add_child(level)
	autofree(level)
	await _settle()
	var ear: Hearing = _hearing(level.to_global(level.marker(&"ClerkSpot").position))
	await _settle()
	for target: Vector2 in [level.marker(&"QueueSpot1").position, Vector2(502, 378), level.marker(&"QueueSpot2").position]:
		is_true(ear.has_line_of_sight(level.to_global(target)), "ClerkSpot → %s ses hattı tezgâhtan geçer" % target)
	is_false(ear.has_line_of_sight(level.to_global(level.marker(&"RestockSpot1").position)), "raf/duvar sesi yine keser")
