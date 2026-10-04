@tool
class_name LevelLayout
extends Node2D
## Level tile layout and geometric placeholder drawing (US-002; mimari.md S4, S9).
##
## `rows` is the ASCII tile grid (1 tile = 32 px, top-left corner is the level root's (0, 0)). Source is `levels/layouts/<level>.txt`;
## `levels/tools/build_levels.gd` generates this node, the `Walls` collision shapes, `SpawnPoints` and `Markers` from the same grid.
## Colours are read only from the active tone's level palette (S9, IS-008: `ThemeTokens.tone().level_*_color`, noir values `ThemeTokens.LEVEL_*`); no colour is written into the scene, drawing is done in `_draw`.
##
## Legend (marker letters are defined by `@` lines in each layout file and revert to the floor character in the grid):
##   %  border (map edge / neighbouring building; collides)   #  wall (collides)
##   w  shop window (collides; lets sight through, US-007)    +  door gap (1 tile; door object US-005)
##   .  interior floor (sales area)                            :  back-room floor
##   ,  pavement / alley                                       _  street
##   S  shelf (collides, obstacle)                             T  counter (collides; low obstacle: sight passes, IS-098)
##   I  drinks cooler (collides, blocks sight; US-033)         G  crate stack (collides, blocks sight; US-033)

const TILE := 32
## Inset of shelf and counter shapes from the tile edge (px); drawing and collision use the same inset.
const FURNITURE_INSET := 2.0

enum Kind { BOUND, WALL, WINDOW, DOOR, FLOOR, BACKROOM, SIDEWALK, STREET, SHELF, COUNTER, COOLER, CRATE }

const LEGEND := {
	"%": Kind.BOUND,
	"#": Kind.WALL,
	"w": Kind.WINDOW,
	"+": Kind.DOOR,
	".": Kind.FLOOR,
	":": Kind.BACKROOM,
	",": Kind.SIDEWALK,
	"_": Kind.STREET,
	"S": Kind.SHELF,
	"T": Kind.COUNTER,
	"I": Kind.COOLER,
	"G": Kind.CRATE,
}

## Colliding types and the shape-name prefix under `Walls` (Window*: lets the Phase 2 vision system tell glass apart).
## Cooler and crate (US-033) are solid obstacles: they collide and block sight, and are `Walls` body shapes like shelves.
const SOLID_PREFIX := {
	Kind.BOUND: "Bound",
	Kind.WALL: "Wall",
	Kind.WINDOW: "Window",
	Kind.SHELF: "Shelf",
	Kind.COUNTER: "Counter",
	Kind.COOLER: "Cooler",
	Kind.CRATE: "Crate",
}

## Sight classes (US-011a; `Level.vision_cells` -> VisionGrid.Cell). Solid: always blocks sight, no ray cast, visible only by adjacency (structure).
## Portal: a physics query decides (glass and the low-obstacle counter let sight through - IS-098; a closed door blocks). Other types are open.
## A new sight-blocking type is added to SIGHT_SOLID with one line (US-033: cooler, crate).
const SIGHT_SOLID: Array[Kind] = [Kind.BOUND, Kind.WALL, Kind.SHELF, Kind.COOLER, Kind.CRATE]
const SIGHT_PORTAL: Array[Kind] = [Kind.WINDOW, Kind.DOOR, Kind.COUNTER]

# Line widths and spacings (colours come from the tone: ThemeTokens.tone()).
const WALL_EDGE_WIDTH := 2.0
const CURB_WIDTH := 2.0
const GLASS_WIDTH := 6.0
const SHELF_BAY := 16.0       # shelf divider spacing (px)
const HATCH_STEP := 8         # map-edge hatch spacing (px; divides TILE exactly, seamless across tiles)
const HATCH_WIDTH := 2.0
const COOLER_GLASS := 5.0     # glass door on the cooler's floor-facing side (px)
const CRATE_LID := 6.0        # top crate edge inset (px; stack look)
## Item types (inset shape; draw order).
const FURNITURE: Array[Kind] = [Kind.SHELF, Kind.COUNTER, Kind.COOLER, Kind.CRATE]

@export var rows: PackedStringArray = PackedStringArray():
	set(value):
		rows = value
		queue_redraw()


## Grid size (tiles): x = column, y = row.
func size_in_tiles() -> Vector2i:
	return Vector2i(rows[0].length() if not rows.is_empty() else 0, rows.size())


func has_cell(cell: Vector2i) -> bool:
	var size: Vector2i = size_in_tiles()
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Cell type; outside the grid counts as border.
func kind_at(cell: Vector2i) -> Kind:
	if not has_cell(cell):
		return Kind.BOUND
	return kind_of_char(rows[cell.y][cell.x])


static func kind_of_char(ch: String) -> Kind:
	if not LEGEND.has(ch):
		push_error("LevelLayout: lejantta olmayan karakter '%s'" % ch)
		return Kind.BOUND
	return LEGEND[ch] as Kind


static func is_solid(kind: Kind) -> bool:
	return SOLID_PREFIX.has(kind)


static func is_furniture(kind: Kind) -> bool:
	return FURNITURE.has(kind)


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


## Splits the type's tiles into greedily merged rectangles (in tile units; row by row, left to right).
func merged_rects(kind: Kind) -> Array[Rect2i]:
	var size: Vector2i = size_in_tiles()
	var taken := PackedByteArray()
	taken.resize(size.x * size.y)
	var out: Array[Rect2i] = []
	for y: int in size.y:
		for x: int in size.x:
			if taken[y * size.x + x] != 0 or kind_at(Vector2i(x, y)) != kind:
				continue
			var w: int = 1
			while x + w < size.x and taken[y * size.x + x + w] == 0 and kind_at(Vector2i(x + w, y)) == kind:
				w += 1
			var h: int = 1
			while y + h < size.y and _row_free(Vector2i(x, y + h), w, kind, taken, size.x):
				h += 1
			for yy: int in range(y, y + h):
				for xx: int in range(x, x + w):
					taken[yy * size.x + xx] = 1
			out.append(Rect2i(x, y, w, h))
	return out


## Pixel rect of a merged rectangle (shelf/counter with inset); drawing and collision use it.
static func shape_rect(kind: Kind, cells: Rect2i) -> Rect2:
	var rect := Rect2(Vector2(cells.position) * TILE, Vector2(cells.size) * TILE)
	return rect.grow(-FURNITURE_INSET) if is_furniture(kind) else rect


## Floor/fill colour of the type (from the active tone's level palette).
static func color_of(kind: Kind) -> Color:
	var tone: Tone = ThemeTokens.tone()
	match kind:
		Kind.BOUND:
			return tone.bg_color
		Kind.STREET:
			return tone.level_street_color
		Kind.SIDEWALK:
			return tone.level_sidewalk_color
		Kind.FLOOR, Kind.DOOR:
			return tone.level_floor_color
		Kind.BACKROOM:
			return tone.level_backroom_color
		Kind.WALL:
			return tone.level_wall_color
		Kind.WINDOW:
			return tone.wall_color
		Kind.SHELF:
			return tone.level_shelf_color
		Kind.COUNTER, Kind.CRATE:
			return tone.level_counter_color
		Kind.COOLER:
			return tone.level_shelf_color
	return tone.bg_color


## Edge/line colour: wall inner edge, glass strip, shelf and counter outline.
static func edge_color(kind: Kind) -> Color:
	var tone: Tone = ThemeTokens.tone()
	match kind:
		Kind.BOUND:
			return tone.wall_color  # hatch line: reads apart from street and pavement
		Kind.WALL:
			return tone.level_wall_edge_color
		Kind.WINDOW:
			return tone.level_glass_color
		Kind.SHELF:
			return tone.level_shelf_edge_color
		Kind.COUNTER, Kind.CRATE:
			return tone.level_counter_edge_color
		Kind.COOLER:
			return tone.level_glass_color  # glass door: lighter than the shelf edge, cooler reads apart from shelf
		Kind.SIDEWALK:
			return tone.wall_color  # kerb
	return color_of(kind)


## Two passes (draw batching, teknik/cizim-performans.md P1): first all filled rectangles (floor, glass strip, wall edge, kerb, item fill), then all lines (border hatch, item outline and shelf dividers).
## Batched because the command type rarely changes; lines never end up under a fill (edge hatch overflows into the neighbour tile by at most half a line width).
func _draw() -> void:
	var size: Vector2i = size_in_tiles()
	for y: int in size.y:
		for x: int in size.x:
			_draw_cell_rects(Vector2i(x, y))
	for kind: Kind in FURNITURE:
		for cells: Rect2i in merged_rects(kind):
			draw_rect(shape_rect(kind, cells), color_of(kind))
			if kind == Kind.COOLER:
				draw_rect(_cooler_glass(shape_rect(kind, cells), cells), edge_color(kind))
	for y: int in size.y:
		for x: int in size.x:
			if kind_at(Vector2i(x, y)) == Kind.BOUND:
				_draw_hatch(Rect2(Vector2(x, y) * TILE, Vector2(TILE, TILE)))
	for kind: Kind in FURNITURE:
		for cells: Rect2i in merged_rects(kind):
			_draw_furniture_lines(kind, cells)


func _draw_cell_rects(cell: Vector2i) -> void:
	var kind: Kind = kind_at(cell)
	var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	draw_rect(rect, color_of(_ground_kind(cell, kind)))
	if kind == Kind.WINDOW:
		var glass: Rect2
		if _horizontal_wall(cell):
			glass = Rect2(rect.position.x, rect.get_center().y - GLASS_WIDTH / 2.0, TILE, GLASS_WIDTH)
		else:
			glass = Rect2(rect.get_center().x - GLASS_WIDTH / 2.0, rect.position.y, GLASS_WIDTH, TILE)
		draw_rect(glass, edge_color(Kind.WINDOW))
	if kind == Kind.WALL or kind == Kind.WINDOW:
		_draw_wall_edges(cell)
	elif kind == Kind.SIDEWALK:
		_draw_curbs(cell, rect)


## Light edge on the walkable or furnished side of a wall: rooms read thick and clear from above.
func _draw_wall_edges(cell: Vector2i) -> void:
	var color: Color = edge_color(Kind.WALL)
	for edge: Rect2 in wall_edge_rects(cell):
		draw_rect(edge, color)


## Edge lines of a wall/glass tile (px, level coordinates): a WALL_EDGE_WIDTH strip on every edge facing a walkable or furnished neighbour.
## Empty if not wall or glass. Level drawing and the vision fog sketch (US-011a, `FogLayer`) use the same lines.
func wall_edge_rects(cell: Vector2i) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var kind: Kind = kind_at(cell)
	if kind != Kind.WALL and kind != Kind.WINDOW:
		return out
	var w: float = WALL_EDGE_WIDTH
	var origin := Vector2(cell) * TILE
	if _opens(cell + Vector2i.UP):
		out.append(Rect2(origin, Vector2(TILE, w)))
	if _opens(cell + Vector2i.DOWN):
		out.append(Rect2(origin + Vector2(0, TILE - w), Vector2(TILE, w)))
	if _opens(cell + Vector2i.LEFT):
		out.append(Rect2(origin, Vector2(w, TILE)))
	if _opens(cell + Vector2i.RIGHT):
		out.append(Rect2(origin + Vector2(TILE - w, 0), Vector2(w, TILE)))
	return out


## Threshold line of a door-gap tile (two ends, px): along the wall direction cutting the gap, through the tile centre.
## Empty if not a door gap.
func door_gap_segment(cell: Vector2i) -> PackedVector2Array:
	if kind_at(cell) != Kind.DOOR:
		return PackedVector2Array()
	var c: Vector2 = cell_center(cell)
	var half: float = TILE / 2.0
	if _horizontal_wall(cell):
		return PackedVector2Array([c - Vector2(half, 0), c + Vector2(half, 0)])
	return PackedVector2Array([c - Vector2(0, half), c + Vector2(0, half)])


## Map edge / neighbouring building: diagonal hatch, reads apart from the walkable outside area.
func _draw_hatch(rect: Rect2) -> void:
	var color: Color = edge_color(Kind.BOUND)
	var o: Vector2 = rect.position
	for k: int in range(HATCH_STEP, TILE * 2, HATCH_STEP):
		if k <= TILE:
			draw_line(o + Vector2(k, 0), o + Vector2(0, k), color, HATCH_WIDTH)
		else:
			draw_line(o + Vector2(TILE, k - TILE), o + Vector2(k - TILE, TILE), color, HATCH_WIDTH)


## Kerb line on the pavement edge facing the street.
func _draw_curbs(cell: Vector2i, rect: Rect2) -> void:
	var w: float = CURB_WIDTH
	var color: Color = edge_color(Kind.SIDEWALK)
	if kind_at(cell + Vector2i.UP) == Kind.STREET:
		draw_rect(Rect2(rect.position, Vector2(TILE, w)), color)
	if kind_at(cell + Vector2i.DOWN) == Kind.STREET:
		draw_rect(Rect2(rect.position + Vector2(0, TILE - w), Vector2(TILE, w)), color)
	if kind_at(cell + Vector2i.LEFT) == Kind.STREET:
		draw_rect(Rect2(rect.position, Vector2(w, TILE)), color)
	if kind_at(cell + Vector2i.RIGHT) == Kind.STREET:
		draw_rect(Rect2(rect.position + Vector2(TILE - w, 0), Vector2(w, TILE)), color)


## Item outline and shelf dividers (fill is in the `_draw` rectangle pass).
func _draw_furniture_lines(kind: Kind, cells: Rect2i) -> void:
	var rect: Rect2 = shape_rect(kind, cells)
	draw_rect(rect, edge_color(kind), false, 1.0)
	if kind == Kind.SHELF:
		# Double-sided shelf: centre line along the long axis and short dividers; reads apart from the wall.
		var edge: Color = edge_color(kind)
		var c: Vector2 = rect.get_center()
		if rect.size.x >= rect.size.y:
			draw_line(Vector2(rect.position.x, c.y), Vector2(rect.end.x, c.y), edge, 1.0)
			var x: float = rect.position.x + SHELF_BAY
			while x < rect.end.x - 1.0:
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), edge, 1.0)
				x += SHELF_BAY
		else:
			draw_line(Vector2(c.x, rect.position.y), Vector2(c.x, rect.end.y), edge, 1.0)
			var y: float = rect.position.y + SHELF_BAY
			while y < rect.end.y - 1.0:
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), edge, 1.0)
				y += SHELF_BAY
	elif kind == Kind.CRATE:
		# Crate stack: taped top crate (diagonal tape) and the edge of the second crate showing below.
		var edge: Color = edge_color(kind)
		var lid := Rect2(rect.position + Vector2(CRATE_LID, 0), rect.size - Vector2(CRATE_LID, CRATE_LID))
		draw_rect(lid, edge, false, 1.0)
		draw_line(lid.position, lid.end, edge, 1.0)
		draw_line(Vector2(lid.end.x, lid.position.y), Vector2(lid.position.x, lid.end.y), edge, 1.0)


## Glass door strip of the drinks cooler (px): on the long edge facing the floor (cooler stands against the wall; back is blind).
func _cooler_glass(rect: Rect2, cells: Rect2i) -> Rect2:
	if cells.size.y >= cells.size.x:
		var west_open: bool = not is_solid(kind_at(cells.position + Vector2i.LEFT))
		var x: float = rect.position.x if west_open else rect.end.x - COOLER_GLASS
		return Rect2(x, rect.position.y, COOLER_GLASS, rect.size.y)
	var north_open: bool = not is_solid(kind_at(cells.position + Vector2i.UP))
	var y: float = rect.position.y if north_open else rect.end.y - COOLER_GLASS
	return Rect2(rect.position.x, y, rect.size.x, COOLER_GLASS)


## Floor under a tile: for items and doors the neighbouring floor type (interior floor first; pavement/street for outside items),
## otherwise the tile itself.
func _ground_kind(cell: Vector2i, kind: Kind) -> Kind:
	if not is_furniture(kind) and kind != Kind.DOOR:
		return kind
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir: Vector2i in dirs:
		var n: Kind = kind_at(cell + dir)
		if n == Kind.FLOOR or n == Kind.BACKROOM:
			return n
	if is_furniture(kind):
		for dir: Vector2i in dirs:
			var n: Kind = kind_at(cell + dir)
			if n == Kind.SIDEWALK or n == Kind.STREET:
				return n
	return Kind.FLOOR


func _opens(cell: Vector2i) -> bool:
	var k: Kind = kind_at(cell)
	return not (k == Kind.WALL or k == Kind.WINDOW or k == Kind.BOUND)


## Whether the tile is in a horizontal wall strip (left or right neighbour is wall/glass).
func _horizontal_wall(cell: Vector2i) -> bool:
	return not _opens(cell + Vector2i.LEFT) or not _opens(cell + Vector2i.RIGHT)


func _row_free(start: Vector2i, width: int, kind: Kind, taken: PackedByteArray, stride: int) -> bool:
	for xx: int in range(start.x, start.x + width):
		if taken[start.y * stride + xx] != 0 or kind_at(Vector2i(xx, start.y)) != kind:
			return false
	return true
