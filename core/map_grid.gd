class_name MapGrid
extends RefCounted
## Node-free tile geometry of a level layout (IS-106, KR-037 map independence): stand spots and facings are derived from the layout and
## zones instead of hard-coded offsets/directions ("register staff side is east", "the owner faces west"). Input is the layout's rows
## (`LevelLayout.rows`, S4 legend characters; level root at the origin, 1 tile = TILE px) and zone rectangles in the same coordinates.
## Used by the bot brain (stand spots: staff/customer side of the register and counter, aisle side of a shelf end, outside of a door,
## back-alley staging) and by the owner's agenda (task facing toward the adjacent shelf/counter/wall).
## Determinism: candidates are scanned in the fixed DIRS order; ties keep the first.

## Tile size (px; mimari.md S4: 1 tile = 32 px).
const TILE := 32
## Blocking legend characters (S4 legend: border, wall, shop window, shelf, counter, cooler, crate). A door gap `+` is open.
const SOLID_CHARS := "%#wSTIG"
## 4-neighbour directions in scan order.
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var _rows: PackedStringArray = PackedStringArray()
var _width: int = 0


func _init(rows: PackedStringArray = PackedStringArray()) -> void:
	_rows = rows
	_width = rows[0].length() if not rows.is_empty() else 0


func size() -> Vector2i:
	return Vector2i(_width, _rows.size())


func is_empty() -> bool:
	return _rows.is_empty() or _width == 0


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.y < _rows.size() and cell.x < mini(_width, _rows[cell.y].length())


## Walkable tile (in bounds and not a blocking character; door gaps are open).
func is_open(cell: Vector2i) -> bool:
	return in_bounds(cell) and not SOLID_CHARS.contains(_rows[cell.y][cell.x])


## Blocking tile (out of bounds counts as blocked).
func is_blocked(cell: Vector2i) -> bool:
	return not is_open(cell)


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Whether `pos` lies in one of `rects`.
static func in_rects(pos: Vector2, rects: Array[Rect2]) -> bool:
	for r: Rect2 in rects:
		if r.has_point(pos):
			return true
	return false


## Facing at `pos` toward an adjacent blocking tile (shelf, counter, wall), with `hint` (a tuning direction) as preference: the hint is kept
## if its own neighbour blocks or no 4-neighbour blocks; otherwise the blocking neighbour closest in angle to the hint (ties: DIRS order).
## A zero hint picks the first blocking neighbour. Returns a unit vector (or ZERO for a zero hint without blocking neighbours).
func face_block(pos: Vector2, hint: Vector2) -> Vector2:
	var want: Vector2 = hint.normalized() if not hint.is_zero_approx() else Vector2.ZERO
	if is_empty() or not pos.is_finite():
		return want
	var cell: Vector2i = cell_of(pos)
	if not want.is_zero_approx() and is_blocked(cell + _axis_of(want)):
		return want
	var best: Vector2i = Vector2i.ZERO
	var best_dot: float = -INF
	for d: Vector2i in DIRS:
		if not is_blocked(cell + d):
			continue
		var dot: float = Vector2(d).dot(want)
		if dot > best_dot:
			best_dot = dot
			best = d
	return Vector2(best) if best != Vector2i.ZERO else want


## Stand spot on the open side of the tile at `pos` facing away from its blocking neighbours (aisle side of a shelf end): the open
## neighbour with the largest dot against the sum of blocking directions (none blocking: the first open neighbour). INF if none is open.
func away_from_block(pos: Vector2) -> Vector2:
	if is_empty() or not pos.is_finite():
		return Vector2.INF
	var cell: Vector2i = cell_of(pos)
	var push := Vector2.ZERO
	for d: Vector2i in DIRS:
		if is_blocked(cell + d):
			push -= Vector2(d)
	var best: Vector2i = Vector2i(-1, -1)
	var best_dot: float = -INF
	for d: Vector2i in DIRS:
		var c: Vector2i = cell + d
		if not is_open(c):
			continue
		var dot: float = Vector2(d).dot(push)
		if dot > best_dot:
			best_dot = dot
			best = c
	return cell_center(best) if best.x >= 0 else Vector2.INF


## Stand spot next to the tile at `pos` (e.g. register/counter): an open 4-neighbour inside `rects` (the zone of the wanted side; empty =
## any open neighbour), the one nearest `hint` (INF = first in DIRS order). INF if none qualifies.
func side_stand(pos: Vector2, rects: Array[Rect2], hint: Vector2 = Vector2.INF) -> Vector2:
	if is_empty() or not pos.is_finite():
		return Vector2.INF
	var cell: Vector2i = cell_of(pos)
	var best := Vector2.INF
	var best_d: float = INF
	for d: Vector2i in DIRS:
		var c: Vector2i = cell + d
		if not is_open(c):
			continue
		var at: Vector2 = cell_center(c)
		if not rects.is_empty() and not in_rects(at, rects):
			continue
		var dist: float = at.distance_to(hint) if hint.is_finite() else 0.0
		if dist < best_d:
			best_d = dist
			best = at
	return best


## Outward direction of a door tile at `pos`: the open 4-neighbour that is not in any interior rect (`inside`: the venue's zones). ZERO if
## none (both sides inside or no open side).
func outward(pos: Vector2, inside: Array[Rect2]) -> Vector2i:
	if is_empty() or not pos.is_finite():
		return Vector2i.ZERO
	var cell: Vector2i = cell_of(pos)
	for d: Vector2i in DIRS:
		var c: Vector2i = cell + d
		if is_open(c) and not in_rects(cell_center(c), inside) and is_open(cell - d):
			return d
	for d: Vector2i in DIRS:
		var c: Vector2i = cell + d
		if is_open(c) and not in_rects(cell_center(c), inside):
			return d
	return Vector2i.ZERO


## Spot `steps` tiles outside the door at `pos` (fewer if the way is blocked; INF if the door has no outward side).
func outside_of(pos: Vector2, inside: Array[Rect2], steps: int) -> Vector2:
	var dir: Vector2i = outward(pos, inside)
	if dir == Vector2i.ZERO:
		return Vector2.INF
	var cell: Vector2i = cell_of(pos)
	var at: Vector2i = cell + dir
	for i: int in range(1, maxi(steps, 1)):
		if not is_open(at + dir):
			break
		at += dir
	return cell_center(at)


## Staging spot beside the outside of the door at `pos`: one tile out, then one tile sideways (off the door's approach line), on the open
## side; both open -> the side farther from `avoid` (e.g. the nearest street-route point; INF = first in DIRS order). INF if none.
func beside_door(pos: Vector2, inside: Array[Rect2], avoid: Vector2 = Vector2.INF) -> Vector2:
	var dir: Vector2i = outward(pos, inside)
	if dir == Vector2i.ZERO:
		return Vector2.INF
	var front: Vector2i = cell_of(pos) + dir
	var best := Vector2.INF
	var best_d: float = -INF
	for side: Vector2i in [Vector2i(dir.y, dir.x), Vector2i(-dir.y, -dir.x)]:
		var c: Vector2i = front + side
		if not is_open(c):
			continue
		var at: Vector2 = cell_center(c)
		var dist: float = at.distance_to(avoid) if avoid.is_finite() else 0.0
		if dist > best_d:
			best_d = dist
			best = at
	return best if best.is_finite() else (cell_center(front) if is_open(front) else Vector2.INF)


## Side of a prop at `pos` derived from a zone (IS-106; register/counter sides): the directions to 4-neighbour tile centres lying in
## `rects` (or their opposites with `away`); several -> the one closest in angle to `hint` (ties: DIRS order); none -> `hint`.
static func zone_side(pos: Vector2, rects: Array[Rect2], hint: Vector2, away: bool) -> Vector2:
	var best := Vector2.ZERO
	var best_dot: float = -INF
	for d: Vector2i in DIRS:
		if not in_rects(pos + Vector2(d) * TILE, rects):
			continue
		var side: Vector2 = -Vector2(d) if away else Vector2(d)
		var dot: float = side.dot(hint)
		if dot > best_dot:
			best_dot = dot
			best = side
	return best if best != Vector2.ZERO else hint


## The point of `points` nearest `to` (INF if empty or `to` is not finite).
static func nearest(points: Array[Vector2], to: Vector2) -> Vector2:
	var best := Vector2.INF
	if not to.is_finite():
		return best
	for p: Vector2 in points:
		if p.is_finite() and (not best.is_finite() or p.distance_to(to) < best.distance_to(to)):
			best = p
	return best


## Dominant axis of a direction as a 4-neighbour step (ZERO for a zero vector).
static func _axis_of(dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return Vector2i(int(signf(dir.x)), 0)
	return Vector2i(0, int(signf(dir.y)))
