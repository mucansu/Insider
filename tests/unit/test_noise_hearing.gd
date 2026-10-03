extends TestCase
## US-009 AC4, AC6: `Hearing` component with a real physics ray (single process; offline singular id 1 = host). Attenuation
## behind walls (world and vision_block block; npcs/players do not), `see_through` passes only at body level (SightLine =
## Perception sight rule; a wall adjacent to glass is not skipped at the corner), the source's own body (a closing door wing)
## does not block, out-of-radius is dropped without a ray; reached from NoiseBus via the `noise_listener` group.
## Rules: test_noise_rules.gd.

const HEARING_SCRIPT := "res://entities/npc/components/hearing.gd"
const NOISE_BUS := "res://autoload/noise.gd"
const PERCEPTION_TUNING := "res://data/npc/perception_tuning.tres"
## Physics layers (mimari.md §4).
const WORLD := 1 << 0
const NPCS := 1 << 2
const VISION_BLOCK := 1 << 5

var _heard: Array = []


func _hearing(at: Vector2) -> Hearing:
	var hearing := Hearing.new()
	hearing.position = at
	hearing.heard.connect(func(pos: Vector2, radius: float, kind: StringName) -> void: _heard.append([pos, radius, kind]))
	tree().root.add_child(hearing)
	autofree(hearing)
	return hearing


## Static rectangular body (centre, size, layer); `group` can be given at body or shape level.
func _wall(center: Vector2, size: Vector2, layer: int = WORLD, body_group: StringName = &"",
		shape_group: StringName = &"") -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	if body_group != &"":
		body.add_to_group(body_group)
	if shape_group != &"":
		shape.add_to_group(shape_group)
	tree().root.add_child(body)
	autofree(body)
	return body


func _settle() -> void:
	await tree().physics_frame
	await tree().physics_frame


func test_component_setup() -> void:
	var hearing: Hearing = _hearing(Vector2.ZERO)
	is_true(hearing.is_in_group(&"noise_listener"), "S8: noise_listener grubunda")
	is_true(hearing.has_method(&"hear_noise"))
	is_true(hearing.profile != null and hearing.profile.wall_factor == 0.5, "profil data/noise_profile.tres")
	eq(Hearing.BLOCK_MASK, WORLD | VISION_BLOCK, "görüş hattı world + vision_block (S11)")
	is_true(load(HEARING_SCRIPT) != null)


func test_open_space_full_radius() -> void:
	var hearing: Hearing = _hearing(Vector2(1000, 1000))
	await _settle()
	hearing.hear_noise(Vector2(1100, 1000), 120.0, &"run")
	eq(_heard, [[Vector2(1100, 1000), 120.0, &"run"]], "açık alanda tam yarıçap")
	hearing.hear_noise(Vector2(1121, 1000), 120.0, &"run")
	eq(_heard.size(), 1, "yarıçap dışı duyulmaz")
	hearing.hear_noise(Vector2(1010, 1000), 0.0, &"sneak")
	eq(_heard.size(), 1, "sıfır yarıçap duyulmaz")
	eq(hearing.heard_count(), 1)


func test_wall_halves_radius() -> void:
	var ear := Vector2(1000, 2000)
	var hearing: Hearing = _hearing(ear)
	_wall(ear + Vector2(40, 0), Vector2(32, 200))  # wall spanning x 24..56
	await _settle()
	is_false(hearing.has_line_of_sight(ear + Vector2(100, 0)), "duvar görüş hattını keser")
	hearing.hear_noise(ear + Vector2(100, 0), 120.0, &"run")
	eq(_heard.size(), 0, "duvar arkası: 100 > 120 × 0,5")
	hearing.hear_noise(ear + Vector2(59, 0), 120.0, &"run")
	eq(_heard, [[ear + Vector2(59, 0), 60.0, &"run"]], "duvar arkası yakında: etkin yarıçap 60")
	# Control: the same distance in a wall-free direction is heard at the full radius.
	_heard.clear()
	hearing.hear_noise(ear + Vector2(-100, 0), 120.0, &"run")
	eq(_heard, [[ear + Vector2(-100, 0), 120.0, &"run"]], "duvarsız yön")
	# Door sound (160): drops to 80 behind a wall.
	_heard.clear()
	hearing.hear_noise(ear + Vector2(75, 0), 160.0, &"door")
	eq(_heard, [[ear + Vector2(75, 0), 80.0, &"door"]])
	hearing.hear_noise(ear + Vector2(85, 0), 160.0, &"door")
	eq(_heard.size(), 1, "85 > 80")


func test_layers_that_block() -> void:
	var ear := Vector2(1000, 3000)
	var hearing: Hearing = _hearing(ear)
	_wall(ear + Vector2(40, 0), Vector2(32, 60), VISION_BLOCK)
	_wall(ear + Vector2(-40, 0), Vector2(32, 60), NPCS)
	await _settle()
	hearing.hear_noise(ear + Vector2(100, 0), 120.0, &"run")
	eq(_heard.size(), 0, "vision_block (6) keser")
	hearing.hear_noise(ear + Vector2(-100, 0), 120.0, &"run")
	eq(_heard.size(), 1, "npcs katmanı kesmez")


func test_see_through_passes() -> void:
	var ear := Vector2(1000, 4000)
	var hearing: Hearing = _hearing(ear)
	_wall(ear + Vector2(40, 0), Vector2(16, 60), WORLD, Hearing.SEE_THROUGH_GROUP)
	# A grouped shape in a shared (ungrouped) body: blocks as in the sight rule (S11; Perception).
	_wall(ear + Vector2(-40, 0), Vector2(16, 60), WORLD, &"", Hearing.SEE_THROUGH_GROUP)
	_wall(ear + Vector2(0, 40), Vector2(60, 8), WORLD, Hearing.SEE_THROUGH_GROUP)
	_wall(ear + Vector2(0, 70), Vector2(60, 16), WORLD)
	await _settle()
	hearing.hear_noise(ear + Vector2(100, 0), 120.0, &"run")
	eq(_heard.size(), 1, "cam (gövde grubu) geçirir")
	hearing.hear_noise(ear + Vector2(-100, 0), 120.0, &"run")
	eq(_heard.size(), 1, "yalnız şekli gruplu gövde keser (gövde düzeyi kuralı)")
	hearing.hear_noise(ear + Vector2(0, 100), 120.0, &"run")
	eq(_heard.size(), 1, "camın arkasındaki duvar yine keser")


func test_source_body_does_not_block() -> void:
	var ear := Vector2(1000, 5000)
	var hearing: Hearing = _hearing(ear)
	# The closed door wing at the sound source (32x8, perpendicular to the ray).
	_wall(ear + Vector2(100, 0), Vector2(8, 32))
	await _settle()
	is_true(hearing.has_line_of_sight(ear + Vector2(100, 0)), "kaynağın kendi kanadı kesmez")
	hearing.hear_noise(ear + Vector2(100, 0), 160.0, &"door")
	eq(_heard, [[ear + Vector2(100, 0), 160.0, &"door"]])
	# A player's run leaning on the other face of the wing (centre 20 px from the wing centre; hit 24 px from the source)
	# stays behind the wing: 120 > 120 x 0.5.
	_heard.clear()
	is_false(hearing.has_line_of_sight(ear + Vector2(120, 0)), "kanat arkası")
	hearing.hear_noise(ear + Vector2(120, 0), 120.0, &"run")
	eq(_heard.size(), 0, "kapalı kapı arkası zayıflar")


func test_disabled_and_bus_dispatch() -> void:
	var ear := Vector2(1000, 6000)
	var hearing: Hearing = _hearing(ear)
	await _settle()
	var bus: Node = autofree((load(NOISE_BUS) as GDScript).new()) as Node
	tree().root.add_child(bus)
	bus.call(&"emit_noise", ear + Vector2(50, 0), 120.0, &"run", 1)
	eq(_heard.size(), 1, "NoiseBus noise_listener grubundaki Hearing'e ulaşır")
	hearing.enabled = false
	bus.call(&"emit_noise", ear + Vector2(50, 0), 120.0, &"run", 1)
	eq(_heard.size(), 1, "kapalı bileşen duymaz")


## Wall corner adjacent to glass: the ray enters the glass's left face 0.2 px above the corner and immediately moves to the wall.
## The old "advance 0.5 px past the glass and recast" approach started the new ray inside the wall and skipped it.
func test_wall_adjacent_to_glass_corner_blocks() -> void:
	var ear := Vector2(1000, 7000)
	var hearing: Hearing = _hearing(ear)
	_wall(ear + Vector2(35, -25.0), Vector2(10, 50), WORLD, Hearing.SEE_THROUGH_GROUP)  # glass: x 30..40, y -50..0
	_wall(ear + Vector2(35, 25.0), Vector2(10, 50))  # wall: x 30..40, y 0..50
	await _settle()
	hearing.position = ear + Vector2(0, -30.2)
	var source: Vector2 = hearing.position + Vector2(60, 60)  # 45 deg: y -0.2 at x 30 (glass), wall 0.2 px later
	is_false(hearing.has_line_of_sight(source), "camın hemen arkasındaki duvar keser")
	hearing.hear_noise(source, 120.0, &"run")
	eq(_heard.size(), 0, "duvar arkası: ~85 px > 60")
	# Control: without a wall the glass passes fully.
	is_true(hearing.has_line_of_sight(hearing.position + Vector2(60, 20)), "yalnız cam: açık")


## Hearing and Perception use the same sight rule (S11: SightLine = Perception.has_line_of_sight).
func test_same_rule_as_perception() -> void:
	var origin := Vector2(1000, 8000)
	var perception := Perception.new()
	perception.tuning = load(PERCEPTION_TUNING) as PerceptionTuning
	perception.position = origin
	tree().root.add_child(perception)
	autofree(perception)
	_wall(origin + Vector2(40, 0), Vector2(16, 60), WORLD, Hearing.SEE_THROUGH_GROUP)
	_wall(origin + Vector2(-40, 0), Vector2(16, 60), WORLD, &"", Hearing.SEE_THROUGH_GROUP)
	_wall(origin + Vector2(0, 40), Vector2(60, 16), VISION_BLOCK)
	_wall(origin + Vector2(0, -40), Vector2(60, 16), NPCS)
	await _settle()
	var space: PhysicsDirectSpaceState2D = perception.get_world_2d().direct_space_state
	for target: Vector2 in [Vector2(100, 0), Vector2(-100, 0), Vector2(0, 100), Vector2(0, -100), Vector2(100, 100),
			Vector2(-100, -100)]:
		eq(SightLine.is_clear(space, origin, origin + target),
			perception.has_line_of_sight(origin, origin + target), "aynı sonuç: %s" % target)
