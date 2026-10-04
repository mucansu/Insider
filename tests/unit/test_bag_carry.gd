extends TestCase
## IS-085 bag carry visual: BagCarry (no node) side choice (near hand by facing, last side when vertical), smooth side
## switch, instant setup on teleport, pendulum swing (present walking, fades standing, 0 with reduced motion), layer
## (behind when back turned); BagVisual + real player: bag in puppet hand, above foot line, z by direction, on the ground at carrier on drop.

const BAG_SCENE := "res://entities/props/bag.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const DT := 1.0 / 60.0
## Hands of a right-facing puppet (px relative to carrier) [left, right]: near hand (right) is lower.
const HANDS_RIGHT: Array[Vector2] = [Vector2(0.0, -10.2), Vector2(0.0, -7.8)]
const HANDS_DOWN: Array[Vector2] = [Vector2(10.5, -9.0), Vector2(-10.5, -9.0)]


func _hands(points: Array[Vector2], shift: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for p: Vector2 in points:
		out.append(p + shift)
	return out


func _grip_target(points: Array[Vector2], side: int) -> Vector2:
	return points[BagCarry.hand_index(side)] + Vector2(0.0, -BagCarry.GRIP_LIFT)


func test_side_follows_facing_with_vertical_hold() -> void:
	eq(BagCarry.pick_side(Vector2.RIGHT, -1), 1, "sağa bakarken sağ el")
	eq(BagCarry.pick_side(Vector2.LEFT, 1), -1, "sola bakarken sol el")
	eq(BagCarry.pick_side(Vector2.DOWN, 1), 1, "dikeyde son taraf korunur (sağ)")
	eq(BagCarry.pick_side(Vector2.UP, -1), -1, "dikeyde son taraf korunur (sol)")
	eq(BagCarry.pick_side(Vector2(0.2, 0.98).normalized(), -1), -1, "eşik altında titreme yok")
	eq(BagCarry.pick_side(Vector2(0.6, 0.8), -1), 1, "eşik üstünde taraf değişir")
	eq(BagCarry.hand_index(1), 1, "sağ el PuppetBody.hands dizisinde 1")
	eq(BagCarry.hand_index(-1), 0)


func test_grip_in_hand_and_smooth_side_switch() -> void:
	var carry := BagCarry.new()
	carry.update(DT, Vector2.RIGHT, _hands(HANDS_RIGHT), false, Vector2.ZERO, false)
	is_true(carry.is_built(), "ilk güncellemede kurulur")
	eq(carry.side, 1)
	near(carry.grip, _grip_target(HANDS_RIGHT, 1), 0.001, "tutuş sağ elde (elin biraz üstü)")
	is_true(carry.front, "yüzü dönükken önde")
	var start: Vector2 = carry.grip
	var target: Vector2 = _grip_target(HANDS_RIGHT, -1)
	carry.update(DT, Vector2.LEFT, _hands(HANDS_RIGHT), false, Vector2.ZERO, false)
	eq(carry.side, -1, "sola dönünce sol el")
	var moved: float = carry.grip.distance_to(start)
	is_true(moved > 0.0 and moved < start.distance_to(target) * 0.5, "tek karede sıçrama yok: %.2f" % moved)
	for i: int in 30:
		carry.update(DT, Vector2.LEFT, _hands(HANDS_RIGHT), false, Vector2.ZERO, false)
	near(carry.grip, target, 0.05, "0,5 sn içinde yeni ele yerleşir")


func test_back_facing_draws_behind_and_teleport_snaps() -> void:
	var carry := BagCarry.new()
	carry.update(DT, Vector2.DOWN, _hands(HANDS_DOWN), false, Vector2.ZERO, false)
	carry.update(DT, Vector2.UP, _hands(HANDS_DOWN), true, Vector2.ZERO, false)
	is_false(carry.front, "sırt dönükken arkada")
	var far: Vector2 = Vector2(0.0, BagCarry.SNAP_DISTANCE * 2.0)
	carry.update(DT, Vector2.UP, _hands(HANDS_DOWN, far), true, Vector2.ZERO, false)
	near(carry.grip, _grip_target(HANDS_DOWN, 1) + far, 0.001, "ışınlanmada anında kurulur")
	carry.reset()
	is_false(carry.is_built())
	carry.update(DT, Vector2.DOWN, _hands(HANDS_DOWN), false, Vector2.ZERO, false)
	near(carry.grip, _grip_target(HANDS_DOWN, 1), 0.001, "sıfırlanınca (yeni taşıyan) anında kurulur")


## Walking: hand swings back and forth, carrier walks right.
func _walk(carry: BagCarry, seconds: float, speed: float, reduced: bool) -> float:
	var peak: float = 0.0
	var t: float = 0.0
	for i: int in roundi(seconds / DT):
		t += DT
		var swing := Vector2(sin(t * 10.0) * 3.2, 0.0) if not reduced else Vector2.ZERO
		carry.update(DT, Vector2.RIGHT, _hands(HANDS_RIGHT, swing), false, Vector2(speed, 0.0), reduced)
		peak = maxf(peak, absf(carry.angle))
	return peak


func test_sway_while_walking_settles_when_stopped() -> void:
	var carry := BagCarry.new()
	var peak: float = _walk(carry, 1.5, 150.0, false)
	is_true(peak > 0.05, "yürürken sallanır: %.3f" % peak)
	is_true(peak <= BagCarry.SWAY_MAX, "küçük genlik")
	is_true(carry.angle > 0.0, "sağa giderken çanta geride kalır")
	for i: int in roundi(2.0 / DT):
		carry.update(DT, Vector2.RIGHT, _hands(HANDS_RIGHT), false, Vector2.ZERO, false)
	near(carry.angle, 0.0, 0.01, "durunca sakinleşir")


func test_reduced_motion_has_no_sway() -> void:
	var carry := BagCarry.new()
	var peak: float = _walk(carry, 1.5, 220.0, true)
	eq(peak, 0.0, "hareket azaltmada salınım yok")
	eq(carry.angular_velocity, 0.0)
	near(carry.grip, _grip_target(HANDS_RIGHT, 1), 0.001, "tutuş duruş elinde sabit")


func _settle_puppet(puppet: Puppet, player: Player, facing: Vector2) -> void:
	player.facing = facing
	for i: int in 8:
		puppet.rig().update(0.25, puppet.global_position, Vector2.ZERO, facing, PuppetRig.Gait.WALK, false)


func test_visual_grips_carrier_hand_by_facing_and_drops_to_floor() -> void:
	var bag: Bag = (load(BAG_SCENE) as PackedScene).instantiate() as Bag
	bag.position = Vector2(400, 400)
	bag.noise_sink = func(_p: Vector2, _r: float, _k: StringName, _s: int) -> void: pass
	tree().root.add_child(bag)
	autofree(bag)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.set_multiplayer_authority(1, true)
	player.position = Vector2(400, 420)
	tree().root.add_child(player)
	autofree(player)
	var take: Interactable = bag.get_node("Take") as Interactable
	for i: int in roundi((InteractionRules.REPEAT_COOLDOWN + 0.05) / DT):
		take.step(DT)
	take.host_start(1, 1)
	for i: int in roundi(2.05 / DT):
		take.step(DT)
	if not eq(bag.carrier, 1, "oyuncu taşıyor"):
		return
	var visual: BagVisual = bag.get_node("Visual") as BagVisual
	var puppet: Puppet = (player.get_node("Visual") as PlayerVisual).puppet()
	_settle_puppet(puppet, player, Vector2.RIGHT)
	visual.refresh(DT)
	is_true(visual.is_gripped(), "kukla elinde")
	var hands: PackedVector2Array = puppet.hand_points()
	var expected: Vector2 = hands[1] + Vector2(0.0, -BagCarry.GRIP_LIFT)
	near(visual.shown_position(), expected, 0.5, "sağa bakarken sağ elde")
	is_true(visual.shown_position().y < player.global_position.y - 6.0, "ayak hizasında değil (kalça)")
	eq(visual.z_index, VisionRules.ABOVE_FOG_Z + BagVisual.CARRY_FRONT_Z, "yüzü dönükken taşıyanın önünde")
	eq(bag.global_position, player.global_position + Bag.CARRY_OFFSET, "kural konumu değişmedi (devir bileşeni)")
	_settle_puppet(puppet, player, Vector2.UP)
	for i: int in 30:
		visual.refresh(DT)
	eq(visual.z_index, VisionRules.ABOVE_FOG_Z + BagVisual.CARRY_BACK_Z, "sırt dönükken arkada")
	is_true(visual.z_index > 50, "arkada da sisin üstünde")
	Puppet.set_reduced_motion(true)
	for i: int in 30:
		visual.refresh(DT)
	eq(visual.carry().angle, 0.0, "hareket azaltmada salınım yok")
	Puppet.set_reduced_motion(false)
	bag.host_drop()
	bag.step(DT)
	visual.refresh(DT)
	eq(bag.carrier, 0)
	is_false(visual.is_gripped(), "yerde tutuş yok")
	eq(visual.shown_position(), player.interaction_position(), "düşen çanta taşıyanın konumunda yerde")
	eq(visual.z_index, 0, "yerde normal katman")
