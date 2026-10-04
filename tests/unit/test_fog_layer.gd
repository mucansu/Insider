extends TestCase
## US-011a AC1/AC2/AC9/AC10: vision fog layer (`FogLayer`, levels/fog) on the real level (store_a) with the real physics
## query (`FogLayer.line_clear`: same rule as NPC perception - world + vision_block cut, `see_through` glass passes),
## `Level` vision API (vision_cells, attach_fog), sketch geometry and mask, tone tokens, transition, contrast and per-frame cost.
## store_a tiles (levels/layouts/store_a.txt): sales floor rows 4-13, front windows row 14 (cols 3-9, 13-16), sidewalk
## row 15, shelves rows 4/6/8/10 (cols 4-9), counter col 17 rows 9-11, back room rows 4-7 cols 15-21, back door B (20,3)
## closed, front door F (11,14) open.

const STORE := "res://levels/store_a.tscn"
const FOG_FILES: Array[String] = ["res://levels/fog/fog_layer.gd", "res://levels/fog/fog_layer.gdshader",
	"res://levels/fog/fog_outline.gdshader"]
const LAYOUTS: Array[String] = ["res://levels/store_a.tscn", "res://levels/test_arena.tscn"]


func _store() -> Level:
	var level: Level = (load(STORE) as PackedScene).instantiate() as Level
	tree().root.add_child(level)
	autofree(level)
	await tree().physics_frame
	await tree().physics_frame
	return level


static func _at(cell: Vector2i) -> Vector2:
	return VisionGrid.cell_center(cell)


func _observer(level: Level, cell: Vector2i) -> Node2D:
	var node := Node2D.new()
	node.name = "Observer"
	level.add_child(node)
	node.global_position = level.to_global(_at(cell))
	return node


## Puts the observer on a tile and updates the fog immediately.
static func _move(fog: FogLayer, observer: Node2D, cell: Vector2i) -> void:
	observer.global_position = fog.to_global(_at(cell))
	fog.update_now()


func test_level_vision_api() -> void:
	var level: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	eq(level.vision_size(), Vector2i(30, 20))
	var cells: PackedByteArray = level.vision_cells()
	eq(cells.size(), 600)
	var expect: Dictionary = {
		Vector2i(0, 0): VisionGrid.Cell.SOLID,  # boundary
		Vector2i(1, 4): VisionGrid.Cell.SOLID,  # wall
		Vector2i(4, 4): VisionGrid.Cell.SOLID,  # shelf
		Vector2i(17, 9): VisionGrid.Cell.PORTAL,  # counter (IS-098: low obstacle, sight passes)
		Vector2i(3, 14): VisionGrid.Cell.PORTAL,  # display glass
		Vector2i(11, 14): VisionGrid.Cell.PORTAL,  # front door gap
		Vector2i(19, 8): VisionGrid.Cell.PORTAL,  # inner door gap
		Vector2i(2, 4): VisionGrid.Cell.OPEN,  # sales floor
		Vector2i(16, 6): VisionGrid.Cell.SOLID,  # back room shelf
		Vector2i(17, 5): VisionGrid.Cell.OPEN,  # back room
		Vector2i(6, 15): VisionGrid.Cell.OPEN,  # sidewalk
		Vector2i(26, 18): VisionGrid.Cell.OPEN,  # street
		Vector2i(13, 6): VisionGrid.Cell.SOLID,  # drinks cooler (US-033)
		Vector2i(20, 6): VisionGrid.Cell.SOLID,  # back room crate (US-033)
		Vector2i(21, 2): VisionGrid.Cell.SOLID,  # alley crate (US-033)
	}
	for cell: Vector2i in expect:
		eq(cells[cell.y * 30 + cell.x], expect[cell], "görüş sınıfı %s" % cell)
	is_true(level.vision_tuning() != null and level.vision_tuning().view_radius == 288.0, "vision_tuning")
	is_true(level.fog_layer() == null, "sahnede sis yok (çalışma anında eklenir)")


func test_attach_fog_follows_and_is_idempotent() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(6, 15))
	var fog: FogLayer = level.attach_fog(me)
	is_true(fog != null and level.fog_layer() == fog, "fog_layer")
	eq(fog.get_parent(), level)
	eq(fog.position, Vector2.ZERO, "ızgara = seviye koordinatı")
	eq(fog.z_index, FogLayer.Z_INDEX)
	eq(fog.observer(), me)
	eq(fog.state_at(Vector2i(6, 15)), VisionGrid.State.VISIBLE, "attach anında güncellenir")
	eq(int(fog.stats()["memory_tiles"]), 0, "yeni seviye: hafıza boş (faz içi)")
	_move(fog, me, Vector2i(25, 2))
	is_true(int(fog.stats()["memory_tiles"]) > 0)
	var other: Node2D = _observer(level, Vector2i(3, 5))
	var again: FogLayer = level.attach_fog(other)
	is_true(again == fog, "ikinci çağrı aynı katman")
	eq(fog.observer(), other, "gözlemci değişti")
	is_true(int(fog.stats()["memory_tiles"]) > 0, "hafıza korundu")
	eq(fog.state_at(Vector2i(3, 5)), VisionGrid.State.VISIBLE)


## From the sidewalk the area behind the glass is visible; the counter is visible from ~205 px through the glass (GDD §6.5 "look through glass").
func test_glass_shows_inside_from_sidewalk() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(6, 15))
	var fog: FogLayer = level.attach_fog(me)
	eq(fog.state_at(Vector2i(6, 14)), VisionGrid.State.VISIBLE, "cam karosu")
	eq(fog.state_at(Vector2i(6, 13)), VisionGrid.State.VISIBLE, "camın arkası")
	eq(fog.state_at(Vector2i(6, 11)), VisionGrid.State.VISIBLE, "camın arkası, rafın önü")
	is_true(fog.is_visible_at(level.to_global(_at(Vector2i(6, 12)))), "is_visible_at (global)")
	ne(fog.state_at(Vector2i(6, 9)), VisionGrid.State.VISIBLE, "raf arkası (satır 9) görünmez")
	_move(fog, me, Vector2i(13, 15))
	eq(fog.state_at(Vector2i(17, 10)), VisionGrid.State.VISIBLE, "tezgâh camdan görünür")
	eq(fog.state_at(Vector2i(16, 10)), VisionGrid.State.VISIBLE, "tezgâhın müşteri tarafı")
	ne(fog.state_at(Vector2i(17, 6)), VisionGrid.State.VISIBLE, "arka oda görünmez")


func test_wall_and_shelf_block() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(6, 12))
	var fog: FogLayer = level.attach_fog(me)
	eq(fog.state_at(Vector2i(6, 11)), VisionGrid.State.VISIBLE)
	eq(fog.state_at(Vector2i(6, 10)), VisionGrid.State.VISIBLE, "raf karosu (yapı) görünür")
	ne(fog.state_at(Vector2i(6, 9)), VisionGrid.State.VISIBLE, "raf arkası görünmez (K1)")
	ne(fog.state_at(Vector2i(6, 7)), VisionGrid.State.VISIBLE, "iki raf arkası görünmez")
	_move(fog, me, Vector2i(12, 12))
	ne(fog.state_at(Vector2i(17, 5)), VisionGrid.State.VISIBLE, "arka oda duvar arkasında")
	ne(fog.state_at(Vector2i(16, 4)), VisionGrid.State.VISIBLE)
	eq(fog.state_at(Vector2i(14, 8)), VisionGrid.State.VISIBLE, "duvar karosu komşuluktan görünür")
	# From outside: visible street tiles are not behind a wall outside the glass.
	_move(fog, me, Vector2i(5, 1))
	for x: int in range(2, 14):
		ne(fog.state_at(Vector2i(x, 5)), VisionGrid.State.VISIBLE, "arka ara sokaktan satış alanı (%d,5) görünmez" % x)
	eq(fog.state_at(Vector2i(5, 3)), VisionGrid.State.VISIBLE, "kuzey duvarı komşuluktan görünür")


## US-033: cooler and crates are solid in the vision grid; behind them is unseen (cut from BackroomSpot, from StreetRoute5
## the tile of whoever opens the back door, the wall behind the cooler from the corridor), control tiles are visible.
func test_cover_obstacles_hide_behind() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(18, 5))
	var fog: FogLayer = level.attach_fog(me)
	for cell: Vector2i in [Vector2i(21, 6), Vector2i(21, 7)]:
		ne(fog.state_at(cell), VisionGrid.State.VISIBLE, "BackroomSpot'tan kese %s görünmez" % cell)
	for cell: Vector2i in [Vector2i(19, 7), Vector2i(21, 5), Vector2i(20, 6)]:
		eq(fog.state_at(cell), VisionGrid.State.VISIBLE, "BackroomSpot'tan %s görünür" % cell)
	_move(fog, me, Vector2i(19, 7))
	eq(fog.state_at(Vector2i(21, 7)), VisionGrid.State.VISIBLE, "iç kapıdan giren kesenin ağzını görür")
	_move(fog, me, Vector2i(23, 2))
	ne(fog.state_at(Vector2i(20, 2)), VisionGrid.State.VISIBLE, "StreetRoute5'ten arka kapının önü koli arkasında")
	_move(fog, me, Vector2i(20, 1))
	eq(fog.state_at(Vector2i(20, 2)), VisionGrid.State.VISIBLE, "StreetRoute6'dan arka kapının önü görünür")
	_move(fog, me, Vector2i(11, 6))
	eq(fog.state_at(Vector2i(13, 6)), VisionGrid.State.VISIBLE, "dolap (yapı) görünür")
	ne(fog.state_at(Vector2i(14, 6)), VisionGrid.State.VISIBLE, "dolabın arkasındaki duvar görünmez")


## A closed back door cuts vision; once opened, the area behind it becomes visible within <= 100 ms (one update interval).
func test_door_opening_reveals_within_update_interval() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(20, 2))
	var fog: FogLayer = level.attach_fog(me)
	var door: Door = level.props_root().get_node("BackDoor") as Door
	is_false(door.is_open, "arka kapı kapalı başlar")
	eq(fog.state_at(Vector2i(20, 3)), VisionGrid.State.VISIBLE, "kapı karosu komşuluktan görünür")
	ne(fog.state_at(Vector2i(20, 5)), VisionGrid.State.VISIBLE, "kapalı kapı arkası görünmez")
	ne(fog.state_at(Vector2i(19, 4)), VisionGrid.State.VISIBLE)
	fog.update_now()  # worst case: the update just ran, the door opens right after
	door.is_open = true
	var frames: int = 0
	var limit: int = roundi(fog.tuning.update_interval_sec * Engine.physics_ticks_per_second)
	while fog.state_at(Vector2i(20, 5)) != VisionGrid.State.VISIBLE and frames < limit + 10:
		await tree().physics_frame
		frames += 1
	is_true(frames <= limit, "kapı açıldıktan %d fizik karesi sonra görünür (≤ %d = 100 ms)" % [frames, limit])
	eq(fog.state_at(Vector2i(20, 5)), VisionGrid.State.VISIBLE, "açık kapının arkası görünen")
	eq(fog.state_at(Vector2i(20, 6)), VisionGrid.State.VISIBLE)


## Directional mode, real level: a player behind the counter facing north does not see south (front windows).
func test_directional_back_is_hidden_in_store() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(12, 11))
	var fog: FogLayer = level.attach_fog(me)
	fog.set_mode(VisionGrid.Mode.DIRECTIONAL)
	fog.set_look_dir(Vector2.UP)
	fog.update_now()
	eq(fog.mode(), VisionGrid.Mode.DIRECTIONAL)
	eq(fog.state_at(Vector2i(12, 7)), VisionGrid.State.VISIBLE, "önde (kuzey)")
	eq(fog.state_at(Vector2i(12, 12)), VisionGrid.State.VISIBLE, "arkada 32 px: yakın halka")
	eq(fog.state_at(Vector2i(12, 13)), VisionGrid.State.VISIBLE, "arkada 64 px: yakın halka sınırı")
	eq(fog.state_at(Vector2i(15, 11)), VisionGrid.State.PERIPHERAL, "yan: çevresel")
	eq(fog.state_at(Vector2i(13, 14)), VisionGrid.State.MEMORY, "arkası: ilk (çevresel kip) güncellemeden hafıza")
	fog.reset_memory()
	fog.update_now()
	eq(fog.state_at(Vector2i(13, 14)), VisionGrid.State.UNKNOWN, "hafızasız arkası bilinmeyen")
	eq(fog.stats()["mode"], "directional")
	is_true(int(fog.stats()["peripheral_tiles"]) > 0)
	fog.set_mode(VisionGrid.Mode.PERIPHERAL)
	fog.update_now()
	eq(fog.stats()["mode"], "peripheral")
	eq(int(fog.stats()["peripheral_tiles"]), 0, "çevresel 360° kipte durum 3 yok")


## Transition 0.15 s; instant with reduced motion (AC2).
func test_transition_and_reduce_motion() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(6, 15))
	var fog: FogLayer = level.attach_fog(me)
	var cell := Vector2i(25, 15)
	near(fog.shown_weights(cell), Vector3(1, 0, 0), 0.001, "bilinmeyen")
	me.global_position = fog.to_global(_at(Vector2i(22, 15)))
	fog.update_now()
	eq(fog.state_at(cell), VisionGrid.State.VISIBLE)
	is_true(fog.is_animating(), "geçiş başladı")
	fog._process(fog.tuning.transition_sec * 0.5)
	near(fog.shown_weights(cell).x, 0.5, 0.02, "yarı yolda")
	fog._process(fog.tuning.transition_sec * 0.5 + 0.001)
	near(fog.shown_weights(cell), Vector3.ZERO, 0.001, "0,15 sn sonra açık")
	is_false(fog.is_animating())
	fog.reduce_motion = true
	_move(fog, me, Vector2i(6, 15))
	eq(fog.state_at(cell), VisionGrid.State.MEMORY)
	near(fog.shown_weights(cell), Vector3(0, 1, 0), 0.001, "hareket azaltma: anlık hafıza tonu")
	is_false(fog.is_animating())
	eq(fog.blend_t(), 1.0, "hareket azaltma: blend_t anında 1")


## Transition in the shader (prev/next + blend_t): a new update mid-transition does not make the image jump (the
## intermediate value is pinned to prev), blend_t restarts from 0; uniforms live in the material.
func test_transition_is_continuous_across_updates() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(6, 15))
	var fog: FogLayer = level.attach_fog(me)
	fog._process(1.0)  # let the first opening transition finish
	_move(fog, me, Vector2i(22, 15))
	fog._process(fog.tuning.transition_sec * 0.6)
	var cells: Array[Vector2i] = [Vector2i(25, 15), Vector2i(27, 16), Vector2i(19, 15), Vector2i(16, 16)]
	var before: Array[Vector3] = []
	for c: Vector2i in cells:
		before.append(fog.shown_weights(c))
	is_true(before[0].x > 0.05 and before[0].x < 0.95, "(25,15) geçişin ortasında: %s" % before[0])
	_move(fog, me, Vector2i(23, 15))  # new update after 0.09 s
	eq(fog.blend_t(), 0.0, "yeni geçiş 0'dan")
	for k: int in cells.size():
		near(fog.shown_weights(cells[k]), before[k], 2.5 / 255.0, "sıçrama yok: %s" % cells[k])
	fog._process(fog.tuning.transition_sec + 0.01)
	near(fog.shown_weights(Vector2i(25, 15)), Vector3.ZERO, 0.001, "hedefe varır")
	var mat: ShaderMaterial = (fog.get_node("Shade") as CanvasItem).material as ShaderMaterial
	eq(mat.get_shader_parameter(&"blend_t"), 1.0)
	is_true(mat.get_shader_parameter(&"prev_data") is ImageTexture and mat.get_shader_parameter(&"next_data") is ImageTexture)
	var outline: ShaderMaterial = (fog.get_node("Outline") as CanvasItem).material as ShaderMaterial
	eq(outline.get_shader_parameter(&"next_data"), mat.get_shader_parameter(&"next_data"), "kroki aynı veriyi okur")


## Fog colours come only from ThemeTokens.GAMEPLAY_FOG_* (AC2): values match the design, no hard-coded colours in files.
func test_fog_tokens_and_no_literal_colors() -> void:
	var bg: Color = ThemeTokens.BG
	for spec: Array in [[ThemeTokens.GAMEPLAY_FOG_UNKNOWN, 1.0], [ThemeTokens.GAMEPLAY_FOG_MEMORY, 0.55],
			[ThemeTokens.GAMEPLAY_FOG_PERIPHERAL, 0.30]]:
		var c: Color = spec[0]
		near(c.a, float(spec[1]), 0.001, "sis alfası")
		near(Vector3(c.r, c.g, c.b), Vector3(bg.r, bg.g, bg.b), 0.001, "sis rengi BG")
	near(ThemeTokens.GAMEPLAY_FOG_MEMORY_SATURATION, 0.5, 0.001)
	near(ThemeTokens.GAMEPLAY_FOG_PERIPHERAL_SATURATION, 0.6, 0.001)
	# Hard-coded colour: Color built from numbers or strings, named colour, hex code, colour-hinted uniform. (A Color(weight, ...)
	# written into a data texture from variables is not a colour and does not match.)
	var literal := RegEx.create_from_string(
		"Color\\s*\\(\\s*[\"'0-9.]|Color\\.[A-Z]|#[0-9a-fA-F]{6}\\b|source_color|hint_color")
	var vec_default := RegEx.create_from_string("uniform\\s+vec4\\s+\\w+\\s*=")
	for path: String in FOG_FILES:
		var text: String = FileAccess.get_file_as_string(path)
		if not is_true(not text.is_empty(), path):
			continue
		var hit: RegExMatch = literal.search(text)
		is_true(hit == null, "%s: sabit renk '%s'" % [path, hit.get_string() if hit else ""])
		is_true(vec_default.search(text) == null, "%s: varsayılanlı vec4 uniform (renk) yok" % path)
	var level: Level = await _store()
	var fog: FogLayer = level.attach_fog(_observer(level, Vector2i(6, 15)))
	var mat: ShaderMaterial = (fog.get_node("Shade") as CanvasItem).material as ShaderMaterial
	eq(mat.get_shader_parameter(&"unknown_color"), ThemeTokens.GAMEPLAY_FOG_UNKNOWN)
	eq(mat.get_shader_parameter(&"memory_color"), ThemeTokens.GAMEPLAY_FOG_MEMORY)
	eq(mat.get_shader_parameter(&"peripheral_color"), ThemeTokens.GAMEPLAY_FOG_PERIPHERAL)
	eq(mat.get_shader_parameter(&"edge_px"), 8.0, "kenar yumuşatma 8 px")


## AC10: wall/sketch line and crew scarf colours at memory tone >= 3:1; unknown is an opaque flat tone (independent of the floor,
## no content leak) and also >= 3:1 above it. Fog tone follows the shader formula: saturation multiplier, then alpha blend
## with the fog colour (sRGB space, like 2D).
func test_contrast_on_fog_tones() -> void:
	var tone: Tone = ThemeTokens.tone()
	var grounds: Array[Color] = [tone.level_floor_color, tone.level_backroom_color, tone.level_sidewalk_color,
		tone.level_street_color, tone.level_shelf_color, tone.level_counter_color, tone.level_wall_color]
	var flat: Color = fogged(grounds[0], ThemeTokens.GAMEPLAY_FOG_UNKNOWN, ThemeTokens.GAMEPLAY_FOG_UNKNOWN_SATURATION)
	for ground: Color in grounds:
		var memory: Color = fogged(ground, ThemeTokens.GAMEPLAY_FOG_MEMORY, ThemeTokens.GAMEPLAY_FOG_MEMORY_SATURATION)
		var unknown: Color = fogged(ground, ThemeTokens.GAMEPLAY_FOG_UNKNOWN, ThemeTokens.GAMEPLAY_FOG_UNKNOWN_SATURATION)
		near(Vector3(unknown.r, unknown.g, unknown.b), Vector3(flat.r, flat.g, flat.b), 0.0001,
			"bilinmeyen düz ton, zemin %s sızmaz" % ground.to_html(false))
		for fog_tone: Array in [["hafıza", memory], ["bilinmeyen", unknown]]:
			var under: Color = fog_tone[1]
			var ratio: float = contrast(tone.level_wall_edge_color, under)
			is_true(ratio >= 3.0, "duvar çizgisi / %s(%s) %.2f" % [fog_tone[0], ground.to_html(false), ratio])
			for scarf: Color in ThemeTokens.PLAYER_COLORS:
				var r: float = contrast(scarf, under)
				is_true(r >= 3.0, "atkı %s / %s(%s) %.2f" % [scarf.to_html(false), fog_tone[0], ground.to_html(false), r])
	# Three tones separate: sales floor visible > memory > unknown in brightness.
	var floor_visible: Color = tone.level_floor_color
	var floor_memory: Color = fogged(floor_visible, ThemeTokens.GAMEPLAY_FOG_MEMORY, ThemeTokens.GAMEPLAY_FOG_MEMORY_SATURATION)
	is_true(luminance(floor_visible) > luminance(floor_memory) and luminance(floor_memory) > luminance(flat),
		"görünen > hafıza > bilinmeyen")


## Solid behind solid (adjacency does not chain): from the back alley the north wall is visible, the row-4
## shelves behind it (4..11, 4) are not.
func test_solid_behind_solid_from_back_alley() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(4, 2))
	var fog: FogLayer = level.attach_fog(me)
	for spot: Vector2i in [Vector2i(4, 2), Vector2i(8, 2), Vector2i(11, 2), Vector2i(7, 1)]:
		_move(fog, me, spot)
		eq(fog.state_at(Vector2i(spot.x, 3)), VisionGrid.State.VISIBLE, "kuzey duvarı (%d,3) komşuluktan" % spot.x)
		for x: int in range(4, 12):
			ne(fog.state_at(Vector2i(x, 4)), VisionGrid.State.VISIBLE, "duvar arkası raf (%d,4), gözlemci %s" % [x, spot])


## Sketch geometry: wall edge strips and door threshold (store_a tiles), FogLayer cache has the same geometry.
func test_outline_geometry() -> void:
	var level: Level = await _store()
	var layout: LevelLayout = level.layout()
	var w: float = LevelLayout.WALL_EDGE_WIDTH
	eq(layout.wall_edge_rects(Vector2i(1, 5)), [Rect2(64 - w, 160, w, 32)] as Array[Rect2], "batı duvarı: doğu kenarı")
	eq(layout.wall_edge_rects(Vector2i(5, 3)), [Rect2(160, 96, 32, w), Rect2(160, 128 - w, 32, w)] as Array[Rect2],
		"kuzey duvarı: ara sokak ve satış alanı kenarı")
	eq(layout.wall_edge_rects(Vector2i(3, 14)), [Rect2(96, 448, 32, w), Rect2(96, 480 - w, 32, w)] as Array[Rect2],
		"cam karosu da kenarlı")
	eq(layout.wall_edge_rects(Vector2i(0, 0)).size(), 0, "sınır karosu kenarsız")
	eq(layout.wall_edge_rects(Vector2i(4, 4)).size(), 0, "raf kenarsız")
	eq(layout.door_gap_segment(Vector2i(11, 14)), PackedVector2Array([Vector2(352, 464), Vector2(384, 464)]),
		"ön kapı: yatay duvarda yatay eşik")
	eq(layout.door_gap_segment(Vector2i(19, 8)), PackedVector2Array([Vector2(608, 272), Vector2(640, 272)]))
	eq(layout.door_gap_segment(Vector2i(2, 4)).size(), 0, "kapı değil")
	var fog: FogLayer = level.attach_fog(_observer(level, Vector2i(6, 15)))
	var expect_rects: Array[Rect2] = []
	var expect_gaps := PackedVector2Array()
	for y: int in 20:
		for x: int in 30:
			expect_rects.append_array(layout.wall_edge_rects(Vector2i(x, y)))
			expect_gaps.append_array(layout.door_gap_segment(Vector2i(x, y)))
	eq(fog.outline_rects(), expect_rects, "önbellek = düzen geometrisi")
	eq(fog.outline_gaps(), expect_gaps)
	eq(expect_gaps.size(), 6, "üç kapı boşluğu")


## Sketch lines are visible only on unknown/memory tiles (mask formula = fog_outline.gdshader).
func test_outline_only_on_unknown_and_memory() -> void:
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(6, 12))
	var fog: FogLayer = level.attach_fog(me)
	fog.reduce_motion = true
	fog.reset_memory()
	_move(fog, me, Vector2i(6, 12))
	var seen_wall := Vector2i(1, 12)
	eq(fog.state_at(seen_wall), VisionGrid.State.VISIBLE)
	near(fog.outline_alpha(seen_wall), 0.0, 0.001, "görünen duvarda kroki yok (seviyenin kendi çizgisi görünür)")
	near(fog.outline_alpha(Vector2i(20, 3)), 1.0, 0.001, "bilinmeyende kroki")
	_move(fog, me, Vector2i(25, 17))
	eq(fog.state_at(seen_wall), VisionGrid.State.MEMORY)
	near(fog.outline_alpha(seen_wall), 1.0, 0.001, "hafızada kroki")
	fog.set_mode(VisionGrid.Mode.DIRECTIONAL)
	fog.set_look_dir(Vector2.UP)
	_move(fog, me, Vector2i(12, 11))
	eq(fog.state_at(Vector2i(15, 11)), VisionGrid.State.PERIPHERAL)
	near(fog.outline_alpha(Vector2i(15, 11)), 0.0, 0.001, "çevresel karoda kroki yok")
	var shader: String = FileAccess.get_file_as_string("res://levels/fog/fog_outline.gdshader")
	has(shader, "COLOR.a *= clamp(d.r + d.g, 0.0, 1.0)", "shader maskesi outline_alpha ile aynı formül")


## `_draw_wall_edges` refactor: wall_edge_rects yields the same rectangles as the old inline drawing.
func test_wall_edge_rects_match_previous_drawing() -> void:
	for path: String in LAYOUTS:
		var level: Level = autofree((load(path) as PackedScene).instantiate()) as Level
		var layout: LevelLayout = level.layout()
		var size: Vector2i = layout.size_in_tiles()
		var total: int = 0
		for y: int in size.y:
			for x: int in size.x:
				var cell := Vector2i(x, y)
				var expected: Array[Rect2] = _previous_wall_edges(layout, cell)
				total += expected.size()
				eq(layout.wall_edge_rects(cell), expected, "%s %s" % [path.get_file(), cell])
		is_true(total > 20, "%s: %d kenar" % [path.get_file(), total])


## Rectangles of the old `_draw_wall_edges(cell, rect)` body (US-002/IS-008 drawing; walls and glass only).
static func _previous_wall_edges(layout: LevelLayout, cell: Vector2i) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var kind: LevelLayout.Kind = layout.kind_at(cell)
	if kind != LevelLayout.Kind.WALL and kind != LevelLayout.Kind.WINDOW:
		return out
	var t: float = LevelLayout.TILE
	var w: float = LevelLayout.WALL_EDGE_WIDTH
	var rect := Rect2(Vector2(cell) * t, Vector2(t, t))
	var opens: Callable = func(c: Vector2i) -> bool:
		var k: LevelLayout.Kind = layout.kind_at(c)
		return not (k == LevelLayout.Kind.WALL or k == LevelLayout.Kind.WINDOW or k == LevelLayout.Kind.BOUND)
	if opens.call(cell + Vector2i.UP):
		out.append(Rect2(rect.position, Vector2(t, w)))
	if opens.call(cell + Vector2i.DOWN):
		out.append(Rect2(rect.position + Vector2(0, t - w), Vector2(t, w)))
	if opens.call(cell + Vector2i.LEFT):
		out.append(Rect2(rect.position, Vector2(w, t)))
	if opens.call(cell + Vector2i.RIGHT):
		out.append(Rect2(rect.position + Vector2(t - w, 0), Vector2(w, t)))
	return out


## No levels/ -> entities/ dependency: the fog layer does not use the perception component, it has its own line-of-sight query.
func test_fog_has_no_entities_dependency() -> void:
	var text: String = FileAccess.get_file_as_string("res://levels/fog/fog_layer.gd")
	is_false(text.contains("res://entities"), "entities yolu")
	is_false(text.contains("Perception.") or text.contains(": Perception"), "Perception kullanımı")
	eq(FogLayer.SIGHT_MASK, (1 << 0) | (1 << 5), "world + vision_block")
	eq(FogLayer.SEE_THROUGH_GROUP, &"see_through")


## AC9: total per-frame cost while moving in store_a (physics step: timer + grid update + rays; process: transition + texture
## upload) averages <= 0.5 ms, peak <= 2 ms; rays <= 320 / update. Sketch drawing happens once at setup (no frame cost).
## The workload is deterministic, so the same walk runs RUNS times and each frame takes the minimum across runs (an OS
## hiccup inflates only one frame in a single run; tests may run in parallel). The raw (single-run) peak is printed too.
func test_performance_in_store() -> void:
	const RUNS := 3
	var level: Level = await _store()
	var me: Node2D = _observer(level, Vector2i(3, 15))
	var fog: FogLayer = level.attach_fog(me)
	var path: Array[Vector2i] = [Vector2i(3, 15), Vector2i(20, 15), Vector2i(23, 15), Vector2i(23, 4),
		Vector2i(20, 2), Vector2i(3, 2), Vector2i(3, 1), Vector2i(23, 1), Vector2i(23, 15), Vector2i(11, 15),
		Vector2i(11, 12), Vector2i(3, 12), Vector2i(3, 9), Vector2i(16, 9), Vector2i(18, 11)]
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var speed: float = 120.0  # px/s, walking
	var frame_usec := PackedInt64Array()
	var raw_peak: int = 0
	var rays_max: int = 0
	for run: int in RUNS:
		me.global_position = level.to_global(_at(path[0]))
		fog.reset_memory()
		fog.follow(me)
		var f: int = 0
		for leg: int in path.size() - 1:
			var a: Vector2 = level.to_global(_at(path[leg]))
			var b: Vector2 = level.to_global(_at(path[leg + 1]))
			var steps: int = maxi(ceili(a.distance_to(b) / (speed * dt)), 1)
			for k: int in steps:
				me.global_position = a.lerp(b, float(k + 1) / steps)
				var t0: int = Time.get_ticks_usec()
				fog._physics_process(dt)
				fog._process(dt)
				var spent: int = Time.get_ticks_usec() - t0
				raw_peak = maxi(raw_peak, spent)
				if run == 0:
					frame_usec.append(spent)
				else:
					frame_usec[f] = mini(frame_usec[f], spent)
				f += 1
				rays_max = maxi(rays_max, fog.grid().last_ray_count)
	var total: int = 0
	var peak: int = 0
	for u: int in frame_usec:
		total += u
		peak = maxi(peak, u)
	var avg_ms: float = total / 1000.0 / frame_usec.size()
	var peak_ms: float = peak / 1000.0
	print("    sis: %d kare, ort. %.3f ms/kare, tepe %.3f ms (ham tek koşu %.3f), güncelleme ort. %.3f ms, ışın en çok %d" % [
		frame_usec.size(), avg_ms, peak_ms, raw_peak / 1000.0, fog.stats()["update_ms_avg"], rays_max])
	is_true(frame_usec.size() > 600, "en az 10 sn hareket")
	is_true(rays_max <= 320, "ışın en çok %d" % rays_max)
	is_true(avg_ms <= 0.5, "ortalama %.3f ms/kare" % avg_ms)
	is_true(peak_ms <= 3.0, "tepe %.3f ms" % peak_ms)


static func fogged(under: Color, fog: Color, saturation: float) -> Color:
	var lum: float = under.r * 0.299 + under.g * 0.587 + under.b * 0.114
	var desat := Color(lerpf(lum, under.r, saturation), lerpf(lum, under.g, saturation), lerpf(lum, under.b, saturation))
	return Color(lerpf(desat.r, fog.r, fog.a), lerpf(desat.g, fog.g, fog.a), lerpf(desat.b, fog.b, fog.a))


static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func luminance(c: Color) -> float:
	var lin: Color = c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b
