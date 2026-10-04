class_name VisionGrid
extends RefCounted
## Player vision grid (US-011a AC1; GDD §6.5, §14, KR-022/KR-023). Node-free: no scene tree, physics space or project dirs (KR-018).
## Input: obstacle grid (tile classes) + observer position + look direction + a Callable for the line-of-sight result; output: tile states.
##
## Tile states (1 tile = 32 px, grid origin (0, 0)): 0 unknown / 1 memory / 2 visible / 3 peripheral (directional mode only). On each `update()`:
## - Zone: distance/angle from observer to tile centre -> visible / peripheral / outside (`zone_of`). Peripheral mode (`Mode.PERIPHERAL`, 360 deg): everything within the radius is visible.
##   Directional mode: the sharp cone (half angle, radius) is visible; the peripheral zone (wider half angle, shorter range) is state 3; the 360 deg near ring is visible in every mode.
## - Line of sight: a `sight(from, to)` ray to the centre of OPEN and PORTAL (door, window) tiles in the zone; same rule as the NPC's (the caller supplies the physics query: world + vision_block cut, `see_through` bodies pass). No ray to the observer's own tile.
## - Neighbour rule: SOLID tiles (wall, border, shelf, cooler, crate) and portals whose ray is cut (closed door) are not ray-tested; they take their own zone's state if one of their 8 neighbours was seen **by ray** this update.
##   Not chained: a solid tile seen via a neighbour does not open another solid tile (a shelf behind a wall stays hidden).
## - Dark tiles (dark mask) stay in the memory tone even in line of sight; if the observer is dark too and the tile is within `dark_radius` it becomes visible. A dark observer's radius is capped by `dark_radius`.
## - Memory: a tile that was 2/3 in the previous update and is no longer seen becomes 1 and stays 1 until `reset()` (back to 0 if `memory_enabled` is off). Memory is per phase: a new grid is built when a level loads.
## - Cost: scanning covers only the previous ∪ new view rectangle (2/3 tiles can only be in the previous rectangle); counts are kept incrementally.
## Same input gives the same sequence (fixed scan order, no randomness).

## Tiles whose state changed (fixed order: row by row, left to right). Not emitted if nothing changed.
signal changed(cells: Array[Vector2i])

enum State { UNKNOWN = 0, MEMORY = 1, VISIBLE = 2, PERIPHERAL = 3 }
## Vision mode (host rule, GDD §6.5): peripheral 360 deg or directional. Names: &"peripheral", &"directional".
enum Mode { PERIPHERAL = 0, DIRECTIONAL = 1 }
## Tile class (obstacle grid): OPEN by ray, SOLID by neighbour, PORTAL by ray then neighbour.
enum Cell { OPEN = 0, SOLID = 1, PORTAL = 2 }

const TILE := 32
## Float margin on zone bounds (px and cosine).
const EPSILON := 0.0001
## `zone_of` result: outside the zone.
const OUTSIDE := -1
const MODE_NAMES: Array[StringName] = [&"peripheral", &"directional"]
const _UNLIT := 255


## Vision settings (value object; the fog layer fills it from `VisionTuning`).
class Params:
	extends RefCounted
	var mode: int = Mode.PERIPHERAL
	## Radius in light (px); in directional mode the range of the sharp cone.
	var view_radius: float = 0.0
	## Radius of an observer in the dark (px).
	var dark_radius: float = 0.0
	## Directional mode: half angles of the sharp cone and the peripheral zone (degrees), peripheral range (px).
	var cone_half_angle_deg: float = 0.0
	var peripheral_half_angle_deg: float = 0.0
	var peripheral_radius: float = 0.0
	## Near ring visible in every direction in every mode (px).
	var near_radius: float = 0.0
	var memory_enabled: bool = true


var params: Params = Params.new()
## Rays cast in the last update.
var last_ray_count: int = 0

var _size: Vector2i = Vector2i.ZERO
var _cells: PackedByteArray = PackedByteArray()
var _dark: PackedByteArray = PackedByteArray()
var _states: PackedByteArray = PackedByteArray()
var _lit: PackedByteArray = PackedByteArray()
var _zone: PackedByteArray = PackedByteArray()
var _old: PackedByteArray = PackedByteArray()
var _counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Previous update's scan rectangle (tiles, ends inclusive); empty if lo.x > hi.x.
var _prev_lo := Vector2i(1, 1)
var _prev_hi := Vector2i(0, 0)


## Builds the grid: `grid_size` tiles, `cells` row-major `Cell` values (length width x height), `dark` a 0/1 darkness mask in the same layout
## (empty = everywhere lit). All tiles become unknown (no change emitted).
func setup(grid_size: Vector2i, cells: PackedByteArray, dark: PackedByteArray = PackedByteArray()) -> void:
	var total: int = maxi(grid_size.x, 0) * maxi(grid_size.y, 0)
	if cells.size() != total:
		push_error("VisionGrid: hücre sayısı %d, beklenen %d" % [cells.size(), total])
		total = 0
		grid_size = Vector2i.ZERO
		cells = PackedByteArray()
	_size = grid_size
	_cells = cells.duplicate()
	_dark = dark.duplicate() if dark.size() == total else PackedByteArray()
	if _dark.is_empty():
		_dark.resize(total)
	_states = PackedByteArray()
	_states.resize(total)
	_lit = PackedByteArray()
	_lit.resize(total)
	_lit.fill(_UNLIT)
	_zone = PackedByteArray()
	_zone.resize(total)
	_counts = PackedInt32Array([total, 0, 0, 0])
	_prev_lo = Vector2i(1, 1)
	_prev_hi = Vector2i(0, 0)
	last_ray_count = 0


## Clears memory: all tiles unknown (changed tiles are emitted).
func reset() -> Array[Vector2i]:
	var diff: Array[Vector2i] = []
	for y: int in _size.y:
		for x: int in _size.x:
			var i: int = y * _size.x + x
			if _states[i] != State.UNKNOWN:
				_states[i] = State.UNKNOWN
				diff.append(Vector2i(x, y))
	_counts = PackedInt32Array([_states.size(), 0, 0, 0])
	_prev_lo = Vector2i(1, 1)
	_prev_hi = Vector2i(0, 0)
	if not diff.is_empty():
		changed.emit(diff)
	return diff


func size() -> Vector2i:
	return _size


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


## Tile state (`State`); unknown outside the grid.
func state_at(cell: Vector2i) -> int:
	if not has_cell(cell):
		return State.UNKNOWN
	return _states[cell.y * _size.x + cell.x]


## Tile state of a point in grid coordinates.
func state_at_position(pos: Vector2) -> int:
	return state_at(cell_of(pos))


## Whether the point is on a currently visible tile (state 2; peripheral does not count).
func is_visible(pos: Vector2) -> bool:
	return state_at_position(pos) == State.VISIBLE


## Whether the point is on a peripheral tile (state 3, directional mode only).
func is_peripheral(pos: Vector2) -> bool:
	return state_at_position(pos) == State.PERIPHERAL


func is_dark(cell: Vector2i) -> bool:
	return has_cell(cell) and _dark[cell.y * _size.x + cell.x] != 0


## Copy of the state array (row by row).
func states() -> PackedByteArray:
	return _states.duplicate()


## Number of tiles in the state.
func count(state: int) -> int:
	return _counts[state] if state >= 0 and state < _counts.size() else 0


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Name -> mode (`&"peripheral"` / `&"directional"`); an unknown name falls back to peripheral with a warning.
static func mode_from_name(mode_name: StringName) -> int:
	var index: int = MODE_NAMES.find(mode_name)
	if index < 0:
		push_warning("VisionGrid: bilinmeyen görüş kipi '%s', peripheral kullanılıyor" % mode_name)
		return Mode.PERIPHERAL
	return index


static func mode_name(mode: int) -> StringName:
	return MODE_NAMES[mode] if mode >= 0 and mode < MODE_NAMES.size() else MODE_NAMES[Mode.PERIPHERAL]


## Zone of the point at `offset` from the observer: State.VISIBLE, State.PERIPHERAL or OUTSIDE. In directional mode a zero look
## direction shows only the near ring. Bounds inclusive.
static func zone_of(offset: Vector2, look_dir: Vector2, p: Params, observer_dark: bool = false) -> int:
	var cap: float = minf(p.view_radius, p.dark_radius) if observer_dark else p.view_radius
	var dist: float = offset.length()
	if dist <= minf(p.near_radius, cap) + EPSILON:
		return State.VISIBLE
	if dist > cap + EPSILON:
		return OUTSIDE
	if p.mode != Mode.DIRECTIONAL:
		return State.VISIBLE
	if look_dir.is_zero_approx():
		return OUTSIDE
	var cos_angle: float = offset.dot(look_dir.normalized()) / dist
	if cos_angle >= cos(deg_to_rad(clampf(p.cone_half_angle_deg, 0.0, 180.0))) - EPSILON:
		return State.VISIBLE
	if dist <= minf(p.peripheral_radius, cap) + EPSILON \
			and cos_angle >= cos(deg_to_rad(clampf(p.peripheral_half_angle_deg, 0.0, 180.0))) - EPSILON:
		return State.PERIPHERAL
	return OUTSIDE


## Updates the grid with the observer at `origin` (grid coordinates, px) looking along `look_dir`. `sight` =
## func(from: Vector2, to: Vector2) -> bool (whether line of sight is clear). Returns the changed tiles and emits `changed`.
func update(origin: Vector2, look_dir: Vector2, sight: Callable) -> Array[Vector2i]:
	var diff: Array[Vector2i] = []
	if _size.x <= 0 or _size.y <= 0:
		return diff
	# Zone thresholds (same rules as zone_of; computed once so they are not recomputed in the loop).
	var w: int = _size.x
	var origin_cell: Vector2i = cell_of(origin)
	var observer_dark: bool = is_dark(origin_cell)
	var cap: float = minf(params.view_radius, params.dark_radius) if observer_dark else params.view_radius
	var cap_sq: float = (cap + EPSILON) * (cap + EPSILON)
	var near_r: float = minf(params.near_radius, cap) + EPSILON
	var near_sq: float = near_r * near_r
	var peri_r: float = minf(params.peripheral_radius, cap) + EPSILON
	var peri_sq: float = peri_r * peri_r
	var dark_sq: float = (params.dark_radius + EPSILON) * (params.dark_radius + EPSILON)
	var directional: bool = params.mode == Mode.DIRECTIONAL
	var look: Vector2 = look_dir.normalized() if not look_dir.is_zero_approx() else Vector2.ZERO
	var cos_cone: float = cos(deg_to_rad(clampf(params.cone_half_angle_deg, 0.0, 180.0))) - EPSILON
	var cos_peri: float = cos(deg_to_rad(clampf(params.peripheral_half_angle_deg, 0.0, 180.0))) - EPSILON
	# A tile centre can be at most (k - 0.5) tiles away: k <= ceil(reach / TILE + 0.5) - 1.
	var span: int = ceili(maxf(cap, near_r) / TILE + 0.5) - 1
	var lo := Vector2i(clampi(origin_cell.x - span, 0, w - 1), clampi(origin_cell.y - span, 0, _size.y - 1))
	var hi := Vector2i(clampi(origin_cell.x + span, 0, w - 1), clampi(origin_cell.y + span, 0, _size.y - 1))
	var u_lo: Vector2i = lo
	var u_hi: Vector2i = hi
	if _prev_lo.x <= _prev_hi.x:
		u_lo = Vector2i(mini(lo.x, _prev_lo.x), mini(lo.y, _prev_lo.y))
		u_hi = Vector2i(maxi(hi.x, _prev_hi.x), maxi(hi.y, _prev_hi.y))
	var u_w: int = u_hi.x - u_lo.x + 1
	_old.resize(u_w * (u_hi.y - u_lo.y + 1))
	# 0) Previous ∪ new rectangle: save the old state, drop seen tiles to memory.
	var forget: int = State.MEMORY if params.memory_enabled else State.UNKNOWN
	for y: int in range(u_lo.y, u_hi.y + 1):
		var row: int = y * w
		var old_row: int = (y - u_lo.y) * u_w - u_lo.x
		for x: int in range(u_lo.x, u_hi.x + 1):
			var s: int = _states[row + x]
			_old[old_row + x] = s
			if s == State.VISIBLE or s == State.PERIPHERAL:
				_states[row + x] = forget
	# 1) Zone (all tiles) and ray (open and portal tiles). _lit: zone seen by ray, _zone: zone.
	var rays: int = 0
	for y: int in range(lo.y, hi.y + 1):
		var row: int = y * w
		var cy: float = (y + 0.5) * TILE - origin.y
		for x: int in range(lo.x, hi.x + 1):
			var i: int = row + x
			var cx: float = (x + 0.5) * TILE - origin.x
			var dist_sq: float = cx * cx + cy * cy
			var zone: int = _UNLIT
			if dist_sq <= near_sq:
				zone = State.VISIBLE
			elif dist_sq <= cap_sq:
				if not directional:
					zone = State.VISIBLE
				elif look != Vector2.ZERO:
					var cos_angle: float = (cx * look.x + cy * look.y) / sqrt(dist_sq)
					if cos_angle >= cos_cone:
						zone = State.VISIBLE
					elif cos_angle >= cos_peri and dist_sq <= peri_sq:
						zone = State.PERIPHERAL
			_zone[i] = zone
			if zone == _UNLIT or _cells[i] == Cell.SOLID:
				continue
			if x != origin_cell.x or y != origin_cell.y:
				rays += 1
				if not bool(sight.call(origin, Vector2(cx, cy) + origin)):
					continue
			_lit[i] = zone
	# 2) Ray-seen tiles and the neighbour rule (solid tiles, cut portals; only from a ray-seen neighbour,
	# not chained). A dark tile stays in the memory tone; visible if the observer is dark too and near.
	for y: int in range(lo.y, hi.y + 1):
		var row: int = y * w
		for x: int in range(lo.x, hi.x + 1):
			var i: int = row + x
			var zone: int = _lit[i]
			if zone == _UNLIT:
				zone = _zone[i]
				if zone == _UNLIT or _cells[i] == Cell.OPEN or not _neighbour_lit(x, y):
					continue
			if _dark[i] != 0:
				var cx: float = (x + 0.5) * TILE - origin.x
				var cy: float = (y + 0.5) * TILE - origin.y
				if not observer_dark or cx * cx + cy * cy > dark_sq:
					zone = State.MEMORY
			_states[i] = zone
	for y: int in range(lo.y, hi.y + 1):
		var row: int = y * w
		for x: int in range(lo.x, hi.x + 1):
			_lit[row + x] = _UNLIT
	# 3) Diff (row by row, left to right) and counts.
	for y: int in range(u_lo.y, u_hi.y + 1):
		var row: int = y * w
		var old_row: int = (y - u_lo.y) * u_w - u_lo.x
		for x: int in range(u_lo.x, u_hi.x + 1):
			var now: int = _states[row + x]
			var was: int = _old[old_row + x]
			if now != was:
				_counts[was] -= 1
				_counts[now] += 1
				diff.append(Vector2i(x, y))
	_prev_lo = lo
	_prev_hi = hi
	last_ray_count = rays
	if not diff.is_empty():
		changed.emit(diff)
	return diff


func _neighbour_lit(x: int, y: int) -> bool:
	for ny: int in range(maxi(y - 1, 0), mini(y + 1, _size.y - 1) + 1):
		var row: int = ny * _size.x
		for nx: int in range(maxi(x - 1, 0), mini(x + 1, _size.x - 1) + 1):
			if _lit[row + nx] != _UNLIT:
				return true
	return false
