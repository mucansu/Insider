extends TestCase
## IS-098 AC2 (KR-031 addendum): the counter is not solid in the player vision grid (low obstacle: PORTAL, the physics ray decides
## and the counter body passes). A player on the customer side (502,378) sees the owner at ClerkSpot fully (FULL: cone and task
## glyph drawn), not as a silhouette; shelves, cooler and crates stay solid.

const CUSTOMER_SIDE := Vector2(502, 378)


func test_counter_is_portal_not_solid() -> void:
	eq(Level.vision_cell_of(LevelLayout.Kind.COUNTER), VisionGrid.Cell.PORTAL, "tezgâh: fizik ışını karar verir")
	for kind: LevelLayout.Kind in [LevelLayout.Kind.SHELF, LevelLayout.Kind.COOLER, LevelLayout.Kind.CRATE, LevelLayout.Kind.WALL]:
		eq(Level.vision_cell_of(kind), VisionGrid.Cell.SOLID, "katı kalır: %d" % kind)


func test_customer_side_sees_owner_fully() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	o.global_position = stage.marker(&"ClerkSpot")
	o.net_position = o.position
	var me := Node2D.new()
	me.name = "Observer"
	stage.level.add_child(me)
	me.global_position = stage.level.to_global(CUSTOMER_SIDE)
	var fog: FogLayer = stage.level.attach_fog(me)
	fog.update_now()
	var clerk: Vector2 = o.global_position
	eq(fog.state_at(LevelLayout.cell_of(stage.level.to_local(clerk))), VisionGrid.State.VISIBLE, "ClerkSpot karosu görünür")
	eq(fog.state_at(Vector2i(17, 11)), VisionGrid.State.VISIBLE, "tezgâh (kasa) karosu görünür")
	is_true(fog.line_clear(me.global_position, clerk), "sis görüş hattı tezgâhı geçer")
	is_true(fog.can_see(clerk), "sahip tam görünür noktada")
	var visual: NpcVisual = o.get_node(^"Visual") as NpcVisual
	for i: int in 3:
		await tree().physics_frame
	is_true(visual.is_fully_visible(), "sahip FULL (silüet değil): koni çizilir")
	eq(visual.sight_mode(), SightGate.Mode.FULL)
	is_true(NpcVisual.cone_style(visual.is_fully_visible(), false).x > 0.0, "koni dolgusu > 0")
	var glyph: TaskGlyph = null
	for child: Node in visual.get_children():
		if child is TaskGlyph:
			glyph = child as TaskGlyph
	if is_true(glyph != null, "görev glifi bağlı"):
		is_true(glyph.call(&"_fully_visible") as bool, "glif çizim koşulu (FULL) sağlanır")
	# Control: behind the shelf row the owner is still hidden (shelves stay solid).
	me.global_position = stage.level.to_global(Vector2(5 * 32 + 16, 7 * 32 + 16))
	fog.update_now()
	is_false(fog.can_see(clerk), "raf arkasından sahip görünmez")
	stage.leave()
