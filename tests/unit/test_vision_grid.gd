extends TestCase
## US-011a AC1 (core): `VisionGrid` no-node vision grid. The sight line here is a fake Callable sampled from the test map (no
## physics): `#` wall and `S` shelf block (solid), `w` glass passes (passage), `d` closed door blocks (passage), `.` floor.
## The same rules with a real physics query (store_a) are in test_fog_layer.gd.
## Numbers are the `data/vision_tuning.tres` starting values (288 / 128 / 45 deg / 90 deg / 192 / 64).

const T := 32.0

## 20 x 12 test map. Row/column numbers are in the comment.
## 0123456789012345678 9
const MAP: Array[String] = [
	"####################",  # 0
	"#..................#",  # 1
	"#..................#",  # 2
	"#..................#",  # 3
	"#....#.............#",  # 4  single wall tile (5,4)
	"#..................#",  # 5
	"#........S.........#",  # 6  shelf (9,6)
	"#..................#",  # 7
	"#####w####d#########",  # 8  glass (5,8), closed door (10,8)
	"#..................#",  # 9
	"#..................#",  # 10
	"####################",  # 11
]


static func _cells(rows: Array[String]) -> PackedByteArray:
	var out := PackedByteArray()
	for row: String in rows:
		for ch: String in row:
			match ch:
				"#", "S":
					out.append(VisionGrid.Cell.SOLID)
				"w", "d":
					out.append(VisionGrid.Cell.PORTAL)
				_:
					out.append(VisionGrid.Cell.OPEN)
	return out


## Sight line from the map: the segment is sampled at 1 px steps; a sample entering a `#`, `S` or `d` tile blocks.
static func _sight_for(rows: Array[String]) -> Callable:
	return func(from: Vector2, to: Vector2) -> bool:
		var steps: int = maxi(ceili(from.distance_to(to)), 1)
		for k: int in steps + 1:
			var p: Vector2 = from.lerp(to, float(k) / steps)
			var c := Vector2i(floori(p.x / T), floori(p.y / T))
			if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length():
				return false
			if rows[c.y][c.x] in ["#", "S", "d"]:
				return false
		return true


static func _params(mode: int = VisionGrid.Mode.PERIPHERAL) -> VisionGrid.Params:
	var p := VisionGrid.Params.new()
	p.mode = mode
	p.view_radius = 288.0
	p.dark_radius = 128.0
	p.cone_half_angle_deg = 45.0
	p.peripheral_half_angle_deg = 90.0
	p.peripheral_radius = 192.0
	p.near_radius = 64.0
	p.memory_enabled = true
	return p


static func _grid(rows: Array[String] = MAP, mode: int = VisionGrid.Mode.PERIPHERAL,
		dark: PackedByteArray = PackedByteArray()) -> VisionGrid:
	var g := VisionGrid.new()
	g.params = _params(mode)
	g.setup(Vector2i(rows[0].length(), rows.size()), _cells(rows), dark)
	return g


static func _at(cell: Vector2i) -> Vector2:
	return VisionGrid.cell_center(cell)


func test_tuning_matches_design_numbers() -> void:
	var t: VisionTuning = load(VisionTuning.PATH) as VisionTuning
	if not is_true(t != null, "data/vision_tuning.tres"):
		return
	eq(t.view_radius, 288.0)
	eq(t.dark_radius, 128.0)
	eq(t.soft_edge_px, 32.0)
	eq(t.cone_half_angle_deg, 45.0)
	eq(t.peripheral_half_angle_deg, 90.0)
	eq(t.peripheral_radius, 192.0)
	eq(t.near_radius, 64.0)
	eq(t.max_turn_deg_per_sec, 240.0)
	eq(t.update_interval_sec, 0.1)
	eq(t.transition_sec, 0.15)
	eq(t.edge_blur_px, 8.0)
	is_true(t.memory_enabled)
	eq(t.default_mode, VisionGrid.Mode.PERIPHERAL, "geliştirme varsayılanı çevresel (A/B test-2'de)")


func test_starts_unknown() -> void:
	var g: VisionGrid = _grid()
	eq(g.size(), Vector2i(20, 12))
	eq(g.count(VisionGrid.State.UNKNOWN), 240)
	eq(g.state_at(Vector2i(3, 3)), VisionGrid.State.UNKNOWN)
	eq(g.state_at(Vector2i(-1, 3)), VisionGrid.State.UNKNOWN, "ızgara dışı bilinmeyen")


## Behind a single wall tile (same direction) is never visible; the wall itself is visible by adjacency.
func test_single_wall_shadow_never_visible() -> void:
	var g: VisionGrid = _grid()
	var sight: Callable = _sight_for(MAP)
	for x: int in [1, 2, 3]:
		g.update(_at(Vector2i(x, 4)), Vector2.RIGHT, sight)
		eq(g.state_at(Vector2i(4, 4)), VisionGrid.State.VISIBLE, "duvarın önü (gözlemci x=%d)" % x)
		eq(g.state_at(Vector2i(5, 4)), VisionGrid.State.VISIBLE, "duvar karosu komşuluktan görünür")
		for behind: int in [6, 7, 8]:
			ne(g.state_at(Vector2i(behind, 4)), VisionGrid.State.VISIBLE, "duvar arkası (%d,4), gözlemci x=%d" % [behind, x])
	# A sight line to all visible open tiles must be open (the adjacency rule applies only to solid/passage tiles).
	var origin: Vector2 = _at(Vector2i(2, 4))
	g.update(origin, Vector2.RIGHT, sight)
	for y: int in 12:
		for x: int in 20:
			var c := Vector2i(x, y)
			if g.state_at(c) == VisionGrid.State.VISIBLE and MAP[y][x] == ".":
				is_true(bool(sight.call(origin, _at(c))), "görünen açık karo %s görüş hattında olmalı" % c)


func test_glass_passes_door_blocks() -> void:
	var g: VisionGrid = _grid()
	var sight: Callable = _sight_for(MAP)
	g.update(_at(Vector2i(5, 6)), Vector2.DOWN, sight)
	eq(g.state_at(Vector2i(5, 8)), VisionGrid.State.VISIBLE, "cam karosu")
	eq(g.state_at(Vector2i(5, 9)), VisionGrid.State.VISIBLE, "cam arkası görünen")
	eq(g.state_at(Vector2i(5, 10)), VisionGrid.State.VISIBLE, "cam arkası iki karo")
	g.update(_at(Vector2i(10, 6)), Vector2.DOWN, sight)
	eq(g.state_at(Vector2i(10, 8)), VisionGrid.State.VISIBLE, "kapalı kapı karosu komşuluktan görünür")
	ne(g.state_at(Vector2i(10, 9)), VisionGrid.State.VISIBLE, "kapalı kapı arkası görünmez")
	ne(g.state_at(Vector2i(10, 10)), VisionGrid.State.VISIBLE)


func test_shelf_blocks() -> void:
	var g: VisionGrid = _grid()
	g.update(_at(Vector2i(9, 4)), Vector2.DOWN, _sight_for(MAP))
	eq(g.state_at(Vector2i(9, 6)), VisionGrid.State.VISIBLE, "raf karosu görünür (yapı)")
	ne(g.state_at(Vector2i(9, 7)), VisionGrid.State.VISIBLE, "raf arkası görünmez (K1)")


## The adjacency rule does not chain: a wall visible by adjacency does not reveal the shelf behind it.
func test_solid_behind_solid_not_chained() -> void:
	var rows: Array[String] = [
		"##########",
		"#........#",
		"#........#",
		"##########",
		"#SSSSSSSS#",
		"#........#",
		"##########",
	]
	var g: VisionGrid = _grid(rows)
	g.update(_at(Vector2i(4, 2)), Vector2.DOWN, _sight_for(rows))
	for x: int in range(1, 9):
		eq(g.state_at(Vector2i(x, 3)), VisionGrid.State.VISIBLE, "duvar (%d,3) komşuluktan" % x)
		ne(g.state_at(Vector2i(x, 4)), VisionGrid.State.VISIBLE, "duvar arkasındaki raf (%d,4)" % x)


## A tile leaving sight goes 2 -> 1 and stays 1 on later updates; `reset` clears it.
func test_memory_persists_until_reset() -> void:
	var g: VisionGrid = _grid()
	var sight: Callable = _sight_for(MAP)
	g.update(_at(Vector2i(5, 9)), Vector2.UP, sight)
	eq(g.state_at(Vector2i(5, 9)), VisionGrid.State.VISIBLE)
	eq(g.state_at(Vector2i(8, 10)), VisionGrid.State.VISIBLE)
	# Cross to the other side of the wall: the lower corridor is no longer in sight.
	for i: int in 5:
		g.update(_at(Vector2i(14, 2)), Vector2.UP, sight)
		eq(g.state_at(Vector2i(8, 10)), VisionGrid.State.MEMORY, "hafıza kalır (güncelleme %d)" % i)
	eq(g.state_at(Vector2i(14, 2)), VisionGrid.State.VISIBLE)
	is_true(g.count(VisionGrid.State.MEMORY) > 0)
	var cleared: Array[Vector2i] = g.reset()
	is_true(cleared.size() > 0, "silinen karolar yayılır")
	eq(g.count(VisionGrid.State.UNKNOWN), 240, "hafıza silindi")


func test_memory_disabled_returns_to_unknown() -> void:
	var g: VisionGrid = _grid()
	g.params.memory_enabled = false
	var sight: Callable = _sight_for(MAP)
	g.update(_at(Vector2i(5, 9)), Vector2.UP, sight)
	g.update(_at(Vector2i(14, 2)), Vector2.UP, sight)
	eq(g.state_at(Vector2i(8, 10)), VisionGrid.State.UNKNOWN)
	eq(g.count(VisionGrid.State.MEMORY), 0)


func test_deterministic() -> void:
	var a: VisionGrid = _grid()
	var b: VisionGrid = _grid()
	var sight: Callable = _sight_for(MAP)
	var path: Array[Vector2] = [Vector2(70, 70), Vector2(170, 150), Vector2(330, 200), Vector2(170, 300)]
	for p: Vector2 in path:
		a.update(p, Vector2(1, 1), sight)
		b.update(p, Vector2(1, 1), sight)
		eq(a.states(), b.states(), "aynı girdi aynı dizi (%s)" % p)
	var before: PackedByteArray = a.states()
	var again: Array[Vector2i] = a.update(path[-1], Vector2(1, 1), sight)
	eq(again.size(), 0, "aynı konumda değişim yok")
	eq(a.states(), before)


func test_changed_signal_lists_diff() -> void:
	var g: VisionGrid = _grid()
	var got: Array = []
	g.changed.connect(func(cells: Array[Vector2i]) -> void: got.append(cells))
	var first: Array[Vector2i] = g.update(_at(Vector2i(3, 3)), Vector2.RIGHT, _sight_for(MAP))
	eq(got.size(), 1, "bir yayın")
	eq(got[0], first)
	eq(first.size(), g.count(VisionGrid.State.VISIBLE), "ilk güncellemede değişen = görünen")
	g.update(_at(Vector2i(3, 3)), Vector2.RIGHT, _sight_for(MAP))
	eq(got.size(), 1, "değişim yoksa yayın yok")


## Directional mode: net cone 90 deg / 288, peripheral 180 deg / 192, near ring 64, behind invisible.
func test_directional_zones() -> void:
	var rows: Array[String] = []
	rows.append("#".repeat(31))
	for i: int in 29:
		rows.append("#" + ".".repeat(29) + "#")
	rows.append("#".repeat(31))
	var g: VisionGrid = _grid(rows, VisionGrid.Mode.DIRECTIONAL)
	var me := Vector2i(15, 15)
	g.update(_at(me), Vector2.RIGHT, _sight_for(rows))
	eq(g.state_at(me), VisionGrid.State.VISIBLE, "kendi karosu")
	eq(g.state_at(me + Vector2i(8, 0)), VisionGrid.State.VISIBLE, "önde 256 px: net koni")
	eq(g.state_at(me + Vector2i(5, 4)), VisionGrid.State.VISIBLE, "önde ~39°: net koni")
	eq(g.state_at(me + Vector2i(0, -4)), VisionGrid.State.PERIPHERAL, "90° yan, 128 px: çevresel")
	eq(g.state_at(me + Vector2i(2, 5)), VisionGrid.State.PERIPHERAL, "~68°, 172 px: çevresel")
	eq(g.state_at(me + Vector2i(0, -7)), VisionGrid.State.UNKNOWN, "90° yan, 224 px: çevresel menzil dışı")
	eq(g.state_at(me + Vector2i(-1, 1)), VisionGrid.State.VISIBLE, "arkada 45 px: yakın halka")
	eq(g.state_at(me + Vector2i(-2, 0)), VisionGrid.State.VISIBLE, "arkada 64 px: yakın halka sınırı")
	for back: Vector2i in [Vector2i(-3, 0), Vector2i(-6, 0), Vector2i(-4, -3), Vector2i(-2, 5)]:
		eq(g.state_at(me + back), VisionGrid.State.UNKNOWN, "arkası görünmez: %s" % back)
	for y: int in rows.size():
		for x: int in rows[0].length():
			var c := Vector2i(x, y)
			var s: int = g.state_at(c)
			if (s == VisionGrid.State.VISIBLE or s == VisionGrid.State.PERIPHERAL) and rows[y][x] == ".":
				var off: Vector2 = _at(c) - _at(me)
				is_true(off.x >= 0.0 or off.length() <= 64.0 + 0.001, "arkada görünen karo %s" % c)
	# After turning, behind (the old front) is in memory, the new front visible.
	g.update(_at(me), Vector2.LEFT, _sight_for(rows))
	eq(g.state_at(me + Vector2i(8, 0)), VisionGrid.State.MEMORY, "dönünce eski ön hafıza")
	eq(g.state_at(me + Vector2i(-6, 0)), VisionGrid.State.VISIBLE, "yeni ön görünen")
	is_true(g.count(VisionGrid.State.PERIPHERAL) > 0, "çevresel karo sayısı")


func test_peripheral_mode_sees_all_around() -> void:
	var rows: Array[String] = []
	rows.append("#".repeat(31))
	for i: int in 29:
		rows.append("#" + ".".repeat(29) + "#")
	rows.append("#".repeat(31))
	var g: VisionGrid = _grid(rows)
	var me := Vector2i(15, 15)
	g.update(_at(me), Vector2.RIGHT, _sight_for(rows))
	for off: Vector2i in [Vector2i(9, 0), Vector2i(-9, 0), Vector2i(0, 9), Vector2i(0, -9), Vector2i(-6, -6)]:
		eq(g.state_at(me + off), VisionGrid.State.VISIBLE, "360°: %s" % off)
	eq(g.state_at(me + Vector2i(10, 0)), VisionGrid.State.UNKNOWN, "320 px > 288")
	eq(g.state_at(me + Vector2i(7, 7)), VisionGrid.State.UNKNOWN, "~317 px > 288")
	eq(g.count(VisionGrid.State.PERIPHERAL), 0, "çevresel kipte durum 3 yok")


## AC9: ray budget <= 320 / update (open area, worst case).
func test_ray_budget() -> void:
	var rows: Array[String] = []
	for i: int in 40:
		rows.append(".".repeat(40))
	var counter: Array[int] = [0]
	var sight: Callable = func(_a: Vector2, _b: Vector2) -> bool:
		counter[0] += 1
		return true
	var all_round: VisionGrid = _grid(rows)
	for origin: Vector2 in [_at(Vector2i(20, 20)), Vector2(645, 655), Vector2(631, 640)]:
		all_round.update(origin, Vector2.RIGHT, sight)
		is_true(all_round.last_ray_count <= 320, "çevresel ışın %d ≤ 320" % all_round.last_ray_count)
		is_true(all_round.last_ray_count >= 240, "çevresel ışın %d (yarıçap 9 karo)" % all_round.last_ray_count)
	is_true(counter[0] >= 3 * 240, "ışınlar Callable üzerinden atılır")
	var directional: VisionGrid = _grid(rows, VisionGrid.Mode.DIRECTIONAL)
	directional.update(_at(Vector2i(20, 20)), Vector2(1, 0.3), sight)
	is_true(directional.last_ray_count <= 160, "yönlü ışın %d ≤ 160 (≈140)" % directional.last_ray_count)


## A dark tile is memory even in the sight line; observer in the dark: radius 128 and a near dark tile is visible.
func test_dark_cells() -> void:
	var rows: Array[String] = []
	for i: int in 20:
		rows.append(".".repeat(30))
	var dark := PackedByteArray()
	dark.resize(600)
	for y: int in range(8, 13):
		for x: int in range(12, 18):
			dark[y * 30 + x] = 1
	var g: VisionGrid = _grid(rows, VisionGrid.Mode.PERIPHERAL, dark)
	var sight: Callable = _sight_for(rows)
	g.update(_at(Vector2i(8, 10)), Vector2.RIGHT, sight)
	eq(g.state_at(Vector2i(10, 10)), VisionGrid.State.VISIBLE, "aydınlık")
	eq(g.state_at(Vector2i(13, 10)), VisionGrid.State.MEMORY, "karanlık karo görüş hattında hafıza tonunda")
	is_true(g.is_dark(Vector2i(13, 10)))
	g.update(_at(Vector2i(14, 10)), Vector2.RIGHT, sight)
	eq(g.state_at(Vector2i(16, 10)), VisionGrid.State.VISIBLE, "gözlemci karanlıkta, 64 px: görünen")
	eq(g.state_at(Vector2i(10, 10)), VisionGrid.State.VISIBLE, "128 px aydınlık: görünen")
	ne(g.state_at(Vector2i(9, 10)), VisionGrid.State.VISIBLE, "160 px > 128: karanlıktaki gözlemcinin menzili dışı")


func test_zone_boundaries() -> void:
	var p: VisionGrid.Params = _params(VisionGrid.Mode.DIRECTIONAL)
	eq(VisionGrid.zone_of(Vector2(288, 0), Vector2.RIGHT, p), VisionGrid.State.VISIBLE, "koni menzil sınırı dahil")
	eq(VisionGrid.zone_of(Vector2(289, 0), Vector2.RIGHT, p), VisionGrid.OUTSIDE)
	eq(VisionGrid.zone_of(Vector2(100, 100), Vector2.RIGHT, p), VisionGrid.State.VISIBLE, "45° sınır dahil")
	eq(VisionGrid.zone_of(Vector2(100, 101), Vector2.RIGHT, p), VisionGrid.State.PERIPHERAL)
	eq(VisionGrid.zone_of(Vector2(0, 192), Vector2.RIGHT, p), VisionGrid.State.PERIPHERAL, "90° / 192 sınır dahil")
	eq(VisionGrid.zone_of(Vector2(-1, 150), Vector2.RIGHT, p), VisionGrid.OUTSIDE, "90°'nin arkası")
	eq(VisionGrid.zone_of(Vector2(-64, 0), Vector2.RIGHT, p), VisionGrid.State.VISIBLE, "yakın halka sınırı")
	eq(VisionGrid.zone_of(Vector2(-65, 0), Vector2.RIGHT, p), VisionGrid.OUTSIDE)
	eq(VisionGrid.zone_of(Vector2(100, 0), Vector2.ZERO, p), VisionGrid.OUTSIDE, "yönsüz yönlü kip: yalnız halka")
	eq(VisionGrid.zone_of(Vector2(150, 0), Vector2.RIGHT, p, true), VisionGrid.OUTSIDE, "karanlıkta 128 sınırı")
	eq(VisionGrid.mode_from_name(&"directional"), VisionGrid.Mode.DIRECTIONAL)
	eq(VisionGrid.mode_from_name(&"peripheral"), VisionGrid.Mode.PERIPHERAL)
	eq(VisionGrid.mode_from_name(&"omni"), VisionGrid.Mode.PERIPHERAL, "bilinmeyen ad: uyarı + peripheral")
	eq(VisionGrid.mode_name(VisionGrid.Mode.PERIPHERAL), &"peripheral")
	eq(VisionGrid.mode_name(VisionGrid.Mode.DIRECTIONAL), &"directional")


func test_bad_setup_is_empty() -> void:
	allow_errors()
	var g := VisionGrid.new()
	g.setup(Vector2i(4, 4), PackedByteArray([0, 0]))
	eq(g.size(), Vector2i.ZERO)
	eq(g.update(Vector2(16, 16), Vector2.RIGHT, func(_a: Vector2, _b: Vector2) -> bool: return true).size(), 0)
