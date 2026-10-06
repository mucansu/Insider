class_name AmbienceRules
extends RefCounted
## Inside/outside ambience choice (US-047 AC3). Node-free. The place comes from the tile under the local player — the level layout's rows
## (Level `layout()` -> `rows`, S4 legend characters, level root at the origin, 1 tile = TILE px; same input as MapGrid) — so it works on
## every map without zone names (KR-037): street/pavement = OUTSIDE, shop floor/back room/furniture = INSIDE; thresholds (door, window,
## wall, crate, border, off-grid) keep the previous place, so standing in a doorway does not flicker. The mix moves toward the place at a
## fixed crossfade time; gains are equal-power so the crossfade has no loudness dip.

enum Place { OUTSIDE, INSIDE }

## Inside <-> outside crossfade time (s; AC3 0.5-1 s).
const CROSSFADE_TIME := 0.75
## Tile size (px; mimari.md S4).
const TILE := 32
## S4 legend: pavement/alley `,` and street `_`.
const OUTSIDE_CHARS := ",_"
## S4 legend: sales floor `.`, back room `:`, shelf `S`, counter `T`, cooler `I` (crate `G` also stands in the alley: threshold).
const INSIDE_CHARS := ".:STI"


static func place_for(ch: String, previous: Place) -> Place:
	if ch.length() != 1:
		return previous
	if OUTSIDE_CHARS.contains(ch):
		return Place.OUTSIDE
	if INSIDE_CHARS.contains(ch):
		return Place.INSIDE
	return previous


## Place at a level-local position (px) of the layout `rows`; `previous` off the grid or without rows.
static func place_at(rows: PackedStringArray, local_pos: Vector2, previous: Place) -> Place:
	var cell := Vector2i(floori(local_pos.x / TILE), floori(local_pos.y / TILE))
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return previous
	return place_for(rows[cell.y][cell.x], previous)


## Inside weight (0 = fully outside, 1 = fully inside) after `delta` seconds moving toward `place`.
static func step_mix(inside: float, place: Place, delta: float, fade_time: float = CROSSFADE_TIME) -> float:
	var target: float = 1.0 if place == Place.INSIDE else 0.0
	if fade_time <= 0.0:
		return target
	return move_toward(inside, target, delta / fade_time)


## Equal-power gain (linear 0..1) of a layer with weight `w`.
static func gain(w: float) -> float:
	return sqrt(clampf(w, 0.0, 1.0))


## Linear gain -> dB on top of the entry's level; silent floor -80 dB.
static func to_db(base_db: float, linear: float) -> float:
	return base_db + linear_to_db(linear) if linear > 0.0001 else -80.0
