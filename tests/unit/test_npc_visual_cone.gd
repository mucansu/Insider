extends TestCase
## IS-096 AC1 (KR-031, GDD §9.3 "Sahip okunurluğu"): NPC vision cone opacity - calm 0.15, local player inside the cone 0.25 + edge 0.35,
## nothing unless the NPC is FULL on this peer; in-cone test uses the drawn cone geometry.


func test_tokens_match_design() -> void:
	near(ThemeTokens.GAMEPLAY_CONE_ALPHA, 0.15, 0.0001)
	near(ThemeTokens.GAMEPLAY_CONE_WATCHED_ALPHA, 0.25, 0.0001)
	near(ThemeTokens.GAMEPLAY_CONE_EDGE_ALPHA, 0.35, 0.0001)
	near(ThemeTokens.GAMEPLAY_CONE_EDGE_WIDTH, 1.0, 0.0001)


func test_cone_style_by_visibility_and_watch() -> void:
	eq(NpcVisual.cone_style(true, false), Vector2(ThemeTokens.GAMEPLAY_CONE_ALPHA, 0.0), "sakin: dolgu, kenar yok")
	eq(NpcVisual.cone_style(true, true), Vector2(ThemeTokens.GAMEPLAY_CONE_WATCHED_ALPHA,
		ThemeTokens.GAMEPLAY_CONE_EDGE_ALPHA), "yerel oyuncu konide: koyu dolgu + kenar")
	eq(NpcVisual.cone_style(false, false), Vector2.ZERO, "tam görünmüyor: koni yok")
	eq(NpcVisual.cone_style(false, true), Vector2.ZERO, "silüet/hayalet: konide olsa da çizilmez")


func test_in_drawn_cone() -> void:
	var at := Vector2(100.0, 100.0)
	var face := Vector2.RIGHT
	is_true(NpcVisual.in_drawn_cone(at, face, 45.0, 200.0, at + Vector2(150.0, 20.0)), "önde, menzilde")
	is_false(NpcVisual.in_drawn_cone(at, face, 45.0, 200.0, at + Vector2(250.0, 0.0)), "menzil dışı")
	is_false(NpcVisual.in_drawn_cone(at, face, 45.0, 200.0, at + Vector2(-50.0, 0.0)), "arkada")
	is_false(NpcVisual.in_drawn_cone(at, face, 45.0, 200.0, at + Vector2(10.0, 50.0)), "açı dışı")
	is_false(NpcVisual.in_drawn_cone(at, face, 45.0, 200.0, Vector2.INF), "yerel oyuncu yok")
	is_false(NpcVisual.in_drawn_cone(at, face, 0.0, 200.0, at + Vector2(50.0, 0.0)), "koni yok")
	is_false(NpcVisual.in_drawn_cone(at, face, 180.0, 200.0, at + Vector2(-50.0, 0.0)),
		"çizilen en geniş koni %d° (arkası çizilmez)" % int(NpcVisual.MAX_CONE_DEG))


func test_owner_cone_not_watched_without_local_player() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var visual: NpcVisual = o.get_node(^"Visual") as NpcVisual
	await tree().physics_frame
	is_true(visual.is_fully_visible(), "sissiz sahnede tam görünür")
	is_false(visual.call(&"_watched", o) as bool, "yerel oyuncu yokken koni sakin")
	stage.leave()
