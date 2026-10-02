extends TestCase
## US-006 AC2/AC5: Perception + Suspicion bileşenleri gerçek fizik sorgusuyla, test odasında
## (tests/fixtures/perception_room.tscn): muhafız (100, 300) +x'e bakar; raf (Shelf1) ve duvar (Wall1) ortak
## Walls gövdesinin şekilleri, görüşü keser; camlar (Window1, Glass) `see_through` grubundaki ayrı gövdeler
## (US-007 düzeni, S4 eki), görüşü geçirir. Grup yalnız gövde düzeyinde geçerlidir. Hedefler `interaction_actors`
## grubundaki aktörler (oyuncunun S7 arayüzü: interaction_position + net_mode/move_mode). Tek süreç = host.

const ROOM := "res://tests/fixtures/perception_room.tscn"
const PLAYER_SCRIPT := "res://entities/player/player.gd"
const DT := 1.0 / 60.0
const GUARD := Vector2(100, 300)
## Hedef konumları (oda düzeni; açıklama dosya başında).
const OPEN_NEAR := Vector2(200, 300)
const OPEN_FAR := Vector2(300, 300)
const BEHIND_SHELF := Vector2(260, 240)
const BEHIND_WINDOW := Vector2(260, 360)
const BEHIND_GLASS := Vector2(240, 440)
const BEHIND_WALL := Vector2(340, 300)
const WINDOW_THEN_WALL := Vector2(340, 380)
const BEHIND_GUARD := Vector2(40, 300)


## Oyuncu taklidi: S7 aktör arayüzü + hareket kipi (Player.move_mode, PlayerMotion.Mode).
class FakeActor:
	extends Node2D
	var move_mode: int = PlayerMotion.Mode.WALK

	func interaction_position() -> Vector2:
		return global_position


## Gerçek oyuncu gibi iki kip alanı: eşitleyicinin yazdığı net_mode ve ara değerlenmiş move_mode.
class SyncedActor:
	extends FakeActor
	var net_mode: int = PlayerMotion.Mode.WALK


var _events: Array = []


func _room() -> Node2D:
	var room: Node2D = (load(ROOM) as PackedScene).instantiate() as Node2D
	tree().root.add_child(room)
	autofree(room)
	_suspicion(room).set_physics_process(false)  # testler adımları elle sürer (sabit adım)
	_suspicion(room).threshold_reached.connect(func(peer_id: int, level: int) -> void: _events.append([peer_id, level]))
	await tree().physics_frame
	await tree().physics_frame
	return room


static func _perception(room: Node) -> Perception:
	return room.get_node("Guard/Perception") as Perception


static func _suspicion(room: Node) -> Suspicion:
	return room.get_node("Guard/Suspicion") as Suspicion


func _actor(peer_id: int, at: Vector2, mode: int = PlayerMotion.Mode.WALK) -> FakeActor:
	var actor := FakeActor.new()
	actor.set_multiplayer_authority(peer_id)
	actor.position = at
	actor.move_mode = mode
	actor.add_to_group(Interactable.ACTOR_GROUP)
	tree().root.add_child(actor)
	autofree(actor)
	return actor


static func _tick(s: Suspicion, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		s.tick(DT)


func test_line_of_sight_in_room() -> void:
	var room: Node2D = await _room()
	var p: Perception = _perception(room)
	near(p.global_position, GUARD, 0.001)
	is_true(p.has_line_of_sight(GUARD, OPEN_NEAR), "açık alan")
	is_true(p.has_line_of_sight(GUARD, OPEN_FAR), "açık alan uzak")
	is_false(p.has_line_of_sight(GUARD, BEHIND_SHELF), "raf görüşü keser (K1)")
	is_true(p.has_line_of_sight(GUARD, BEHIND_WINDOW), "cam gövdesi Window1 (see_through) geçirir")
	is_true(p.has_line_of_sight(GUARD, BEHIND_GLASS), "cam gövdesi Glass (see_through) geçirir")
	is_false(p.has_line_of_sight(GUARD, BEHIND_WALL), "duvar keser")
	is_false(p.has_line_of_sight(GUARD, WINDOW_THEN_WALL), "camdan sonra duvar yine keser")
	is_true(p.has_line_of_sight(BEHIND_WINDOW, GUARD), "cam iki yönde geçirir")


## Görüşü geçiren şey grup üyeliğidir: grup kalkınca cam da keser.
func test_see_through_group_is_what_passes() -> void:
	var room: Node2D = await _room()
	var p: Perception = _perception(room)
	room.get_node("Window1").remove_from_group(Perception.SEE_THROUGH_GROUP)
	room.get_node("Glass").remove_from_group(Perception.SEE_THROUGH_GROUP)
	is_false(p.has_line_of_sight(GUARD, BEHIND_WINDOW), "gruptan çıkan Window1 keser")
	is_false(p.has_line_of_sight(GUARD, BEHIND_GLASS), "gruptan çıkan Glass keser")
	is_true(p.has_line_of_sight(GUARD, OPEN_NEAR))


## Grup yalnız gövde düzeyinde: ortak Walls gövdesinin gruptaki şekli görüşü keser (t2 nit 1: şekil yolu yok).
func test_grouped_shape_in_shared_body_blocks() -> void:
	var room: Node2D = await _room()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 40)
	shape.shape = rect
	shape.position = Vector2(150, 300)
	shape.add_to_group(Perception.SEE_THROUGH_GROUP)
	room.get_node("Walls").add_child(shape)
	await tree().physics_frame
	is_false(_perception(room).has_line_of_sight(GUARD, OPEN_NEAR))


## Cama bitişik duvar (ortak kenar), sığ açılı ışınlar: cam dışlanınca ışın baştan atılır, duvar hiçbir ışında
## atlanmaz. Doğruluk: ışın parçasının duvar dikdörtgeniyle analitik kesişimi (sıyıran ışınlar sayılmaz).
func test_window_adjacent_to_wall_never_leaks() -> void:
	var room: Node2D = await _room()
	var glass_rect := Rect2(1100, 960, 8, 40)
	var wall_rect := Rect2(1100, 1000, 8, 60)
	room.add_child(_static_rect(glass_rect, 1, true))
	room.add_child(_static_rect(wall_rect, 1, false))
	await tree().physics_frame
	await tree().physics_frame
	var p: Perception = _perception(room)
	var checked: int = 0
	var blocked: int = 0
	var leaks: PackedStringArray = []
	for i: int in 200:
		var a := Vector2(1080.0 + i * 0.25, 900.0)
		var b := Vector2(1130.0 - i * 0.2, 1150.0)
		var hits_inner: bool = _segment_hits_rect(a, b, wall_rect.grow(-0.05))
		if hits_inner != _segment_hits_rect(a, b, wall_rect.grow(0.05)):
			continue
		checked += 1
		var clear: bool = p.has_line_of_sight(a, b)
		if hits_inner:
			blocked += 1
		if clear == hits_inner:
			leaks.append("%s→%s görüş %s, beklenen %s" % [a, b, clear, not hits_inner])
	is_true(checked >= 150, "denetlenen ışın: %d" % checked)
	is_true(blocked >= 50, "duvara çarpan ışın: %d" % blocked)
	is_true(leaks.is_empty(), "%d ışın yanlış:
  %s" % [leaks.size(), "
  ".join(leaks.slice(0, 5))])


static func _static_rect(rect: Rect2, layer: int, see_through: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	if see_through:
		body.add_to_group(Perception.SEE_THROUGH_GROUP)
	return body


## Parça–dikdörtgen kesişimi (Liang–Barsky).
static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d: Vector2 = b - a
	var t0: float = 0.0
	var t1: float = 1.0
	var checks: Array = [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y],
		[d.y, r.end.y - a.y]]
	for pq: Array in checks:
		var pp: float = pq[0]
		var qq: float = pq[1]
		if is_zero_approx(pp):
			if qq < 0.0:
				return false
			continue
		var t: float = qq / pp
		if pp < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
	return t0 <= t1


## vision_block (6) katmanı da keser (yürünebilen ama görüşü kesen engel, mimari.md §4).
func test_vision_block_layer_blocks() -> void:
	var room: Node2D = await _room()
	var block := StaticBody2D.new()
	block.collision_layer = 1 << 5
	block.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 40)
	shape.shape = rect
	block.position = Vector2(150, 300)
	block.add_child(shape)
	room.add_child(block)
	await tree().physics_frame
	is_false(_perception(room).has_line_of_sight(GUARD, OPEN_NEAR))


func test_observe_rates_by_position_and_mode() -> void:
	var room: Node2D = await _room()
	var p: Perception = _perception(room)
	_actor(2, OPEN_NEAR, PlayerMotion.Mode.SPRINT)
	_actor(3, BEHIND_SHELF, PlayerMotion.Mode.SPRINT)
	_actor(4, BEHIND_WINDOW, PlayerMotion.Mode.WALK)
	_actor(5, BEHIND_WALL, PlayerMotion.Mode.SPRINT)
	_actor(6, BEHIND_GUARD, PlayerMotion.Mode.SPRINT)
	_actor(7, OPEN_FAR, PlayerMotion.Mode.SNEAK)
	var obs: Dictionary = p.observe()
	eq(obs.size(), 6, "gruptaki bütün aktörler")
	var o2: Perception.Observation = obs[2]
	eq(o2.band, PerceptionRules.Band.NEAR)
	is_true(o2.line_clear)
	near(o2.rate, 100.0, 0.001, "koşan, yakın bant")
	near(o2.position, OPEN_NEAR, 0.001)
	var o3: Perception.Observation = obs[3]
	eq(o3.band, PerceptionRules.Band.FAR)
	is_false(o3.line_clear, "raf arkası")
	eq(o3.rate, 0.0)
	near((obs[4] as Perception.Observation).rate, 25.0, 0.001, "cam arkası yürüyen, uzak bant")
	eq((obs[5] as Perception.Observation).rate, 0.0, "duvar arkası")
	eq((obs[6] as Perception.Observation).band, PerceptionRules.Band.NONE, "arkasında")
	eq((obs[6] as Perception.Observation).rate, 0.0)
	near((obs[7] as Perception.Observation).rate, 12.5, 0.001, "sızan, uzak bant")


func test_stance_mapping_and_player_contract() -> void:
	# Host'ta en güncel kip: eşitleyici değeri net_mode, ara değerlenmiş move_mode'a baskın (t2 nit 2).
	var synced := SyncedActor.new()
	synced.net_mode = PlayerMotion.Mode.SPRINT
	synced.move_mode = PlayerMotion.Mode.SNEAK
	eq(Perception.stance_of(synced), PerceptionRules.Stance.SPRINT, "net_mode baskın")
	synced.net_mode = PlayerMotion.Mode.SNEAK
	synced.move_mode = PlayerMotion.Mode.SPRINT
	eq(Perception.stance_of(synced), PerceptionRules.Stance.SNEAK)
	synced.free()
	var actor := FakeActor.new()
	actor.move_mode = PlayerMotion.Mode.SPRINT
	eq(Perception.stance_of(actor), PerceptionRules.Stance.SPRINT)
	actor.move_mode = PlayerMotion.Mode.SNEAK
	eq(Perception.stance_of(actor), PerceptionRules.Stance.SNEAK)
	actor.move_mode = PlayerMotion.Mode.WALK
	eq(Perception.stance_of(actor), PerceptionRules.Stance.WALK)
	var plain := Node2D.new()
	eq(Perception.stance_of(plain), PerceptionRules.Stance.WALK, "kip yoksa yürüme")
	actor.free()
	plain.free()
	# Gerçek oyuncu bu okuma arayüzünü sunar (Player.move_mode + interaction_position, S7).
	var script: Script = load(PLAYER_SCRIPT) as Script
	var props: Array[String] = []
	for info: Dictionary in script.get_script_property_list():
		props.append(str(info["name"]))
	has(props, "move_mode")
	has(props, "net_mode")
	var methods: Array[String] = []
	for info: Dictionary in script.get_script_method_list():
		methods.append(str(info["name"]))
	has(methods, "interaction_position")


func test_shelf_hidden_player_never_accrues() -> void:
	var room: Node2D = await _room()
	var s: Suspicion = _suspicion(room)
	_actor(3, BEHIND_SHELF, PlayerMotion.Mode.SPRINT)
	_tick(s, 10.0)
	eq(s.value_of(3), 0.0, "raf arkası hiç birikmez")
	eq(s.level_of(3), 0)
	eq(_events.size(), 0)
	eq(s.max_level, Suspicion.Level.CALM)
	eq(s.focus_direction, Vector2.ZERO)


func test_window_target_detected_with_events() -> void:
	var room: Node2D = await _room()
	var s: Suspicion = _suspicion(room)
	_actor(4, BEHIND_WINDOW, PlayerMotion.Mode.SPRINT)
	var t: float = 0.0
	var times: Dictionary = {}
	while t < 5.0 and _events.size() < 3:
		s.tick(DT)
		t += DT
		for e: Array in _events:
			if not times.has(e[1]):
				times[e[1]] = t
	eq(_events, [[4, 1], [4, 2], [4, 3]], "\"?\", inceleme, tespit sırayla (peer 4)")
	near(float(times.get(3, INF)), 0.2 + 2.0, DT + 0.0001, "cam arkası koşan, uzak bant: 0,2 + 2 sn")
	is_true(float(times.get(3, INF)) - float(times.get(1, -INF)) >= 0.5, "\"?\" ≥ 0,5 sn önce")
	eq(s.max_level, Suspicion.Level.DETECT)
	# S11 eki (US-008): çoğaltılan yön 1/16 adıma yuvarlanır (ON_CHANGE her karede delta üretmesin).
	near(s.focus_direction, (BEHIND_WINDOW - GUARD).normalized(), Suspicion.FOCUS_STEP, "özet yön hedefe")
	eq(s.focus_direction, s.focus_direction.snapped(Vector2.ONE * Suspicion.FOCUS_STEP), "1/16 adımda")


func test_hiding_behind_shelf_decays_and_hides_position() -> void:
	var room: Node2D = await _room()
	var s: Suspicion = _suspicion(room)
	var actor: FakeActor = _actor(2, OPEN_NEAR, PlayerMotion.Mode.SPRINT)
	_tick(s, 0.6)  # 0,4 sn dolum × 100 = 40 → "?"
	near(s.value_of(2), 40.0, 1.0)
	eq(s.max_level, Suspicion.Level.NOTICE)
	actor.position = BEHIND_SHELF
	_tick(s, 0.5)
	near(s.value_of(2), 34.0, 1.0, "0,2 sn kesinti toleransından sonra boşalma 20/sn")
	near(s.focus_direction, (OPEN_NEAR - GUARD).normalized(), Suspicion.FOCUS_STEP, "özet yön son görüldüğü yere (şimdiki konum sızmaz)")
	_tick(s, 2.0)
	eq(s.value_of(2), 0.0)
	eq(s.max_level, Suspicion.Level.CALM)
	eq(s.focus_direction, Vector2.ZERO)
	eq(_events, [[2, 1]])


func test_per_player_meters_and_departure() -> void:
	var room: Node2D = await _room()
	var s: Suspicion = _suspicion(room)
	var a: FakeActor = _actor(2, OPEN_NEAR, PlayerMotion.Mode.WALK)
	_actor(3, OPEN_FAR, PlayerMotion.Mode.SNEAK)
	_tick(s, 1.2)
	near(s.value_of(2), 50.0, 1.0, "yürüyen yakın: 1 sn × 50")
	near(s.value_of(3), 12.5, 1.0, "sızan uzak: 1 sn × 12,5")
	eq(s.max_level, Suspicion.Level.NOTICE, "özet: en yüksek ölçer")
	near(s.focus_direction, Vector2.RIGHT, 0.0001)
	a.remove_from_group(Interactable.ACTOR_GROUP)  # ayrılan oyuncu: ölçeri boşalıp silinir
	_tick(s, 3.0)
	eq(s.value_of(2), 0.0)
	is_true(s.value_of(3) > 12.5)


func test_dark_query_blocks_accrual() -> void:
	var room: Node2D = await _room()
	var p: Perception = _perception(room)
	var s: Suspicion = _suspicion(room)
	p.dark_query = func(pos: Vector2) -> bool: return pos.x > 150.0
	_actor(2, OPEN_NEAR, PlayerMotion.Mode.SPRINT)
	_tick(s, 2.0)
	eq(s.value_of(2), 0.0, "karanlık bölgede birikmez")
	p.dark_query = Callable()
	_tick(s, 0.3)
	near(s.value_of(2), 10.0, 1.0, "aydınlıkta (varsayılan) birikir")


func test_turn_toward_uses_tuning_cap() -> void:
	var room: Node2D = await _room()
	var p: Perception = _perception(room)
	p.facing = Vector2.RIGHT
	p.turn_toward(Vector2.DOWN, 0.25)
	near(rad_to_deg(Vector2.RIGHT.angle_to(p.facing)), 30.0, 0.01, "120°/sn × 0,25 sn")


func test_camera_observer_uses_camera_cone() -> void:
	var room: Node2D = await _room()
	var p: Perception = _perception(room)
	_actor(2, GUARD + Vector2.RIGHT.rotated(deg_to_rad(40.0)) * 100.0, PlayerMotion.Mode.WALK)
	is_true((p.observe()[2] as Perception.Observation).rate > 0.0, "muhafız 50°: 40° görünür")
	p.observer = Perception.Observer.CAMERA
	p.refresh()
	eq((p.observe()[2] as Perception.Observation).rate, 0.0, "kamera 35°: 40° görünmez")


func test_runs_on_host_physics_and_replicates_summary() -> void:
	var room: Node2D = await _room()
	var s: Suspicion = _suspicion(room)
	var sync: MultiplayerSynchronizer = s.get_node_or_null(NodePath(Suspicion.SYNC_NAME)) as MultiplayerSynchronizer
	if not is_true(sync != null, "özet eşitleyicisi"):
		return
	var props: Array[NodePath] = sync.replication_config.get_properties()
	has(props, NodePath(".:max_level"))
	has(props, NodePath(".:focus_direction"))
	eq(sync.get_multiplayer_authority(), 1, "host yetkili")
	is_true(multiplayer_is_server(), "tek süreç host'tur")
	_actor(2, OPEN_NEAR, PlayerMotion.Mode.SPRINT)
	s.set_physics_process(true)
	for i: int in 45:
		await tree().physics_frame
	is_true(s.value_of(2) > 0.0, "host'ta fizik adımında işler")


func multiplayer_is_server() -> bool:
	return tree().root.multiplayer.is_server()


## Raf kenarında kıpırdayan koşan (11 kare görünür / 1 kare raf arkası): kısa kesintiler ölçeri sıfırlamaz,
## tespit kesintisizin ≤ 1,3 katında gelir ve bir kez yayılır (t2 should-fix, gerçek fizik sorgusuyla).
func test_peeking_at_shelf_edge_is_detected_once() -> void:
	var room: Node2D = await _room()
	var s: Suspicion = _suspicion(room)
	var actor: FakeActor = _actor(2, OPEN_NEAR, PlayerMotion.Mode.SPRINT)
	var t: float = 0.0
	var detected_at: float = INF
	for i: int in roundi(4.0 / DT):
		actor.position = BEHIND_SHELF if i % 12 == 11 else OPEN_NEAR
		s.tick(DT)
		t += DT
		if detected_at == INF and s.level_of(2) == Suspicion.Level.DETECT:
			detected_at = t
	is_true(detected_at <= (0.2 + 1.0) * 1.3, "11/1 desen tespit: %.3f sn" % detected_at)
	eq(_events, [[2, 1], [2, 2], [2, 3]], "her eşik bir kez")
	eq(s.max_level, Suspicion.Level.DETECT, "\"!\" titremez")
