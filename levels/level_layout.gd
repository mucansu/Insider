@tool
class_name LevelLayout
extends Node2D
## Seviyenin karo düzeni ve geometrik yer tutucu çizimi (US-002; mimari.md S4, S9).
##
## `rows` ASCII karo ızgarasıdır (1 karo = 32 px, sol üst köşe seviye kökünün (0, 0) noktası).
## Kaynak `levels/layouts/<seviye>.txt`; `levels/tools/build_levels.gd` bu düğümü, `Walls`
## çarpışma şekillerini, `SpawnPoints` ve `Markers` düğümlerini aynı ızgaradan üretir.
## Renkler yalnız etkin tonun seviye paletinden okunur (S9, IS-008: `ThemeTokens.tone().level_*_color`,
## noir değerleri `ThemeTokens.LEVEL_*`); sahneye renk yazılmaz, çizim `_draw` ile yapılır.
##
## Lejant (işaret harfleri her düzen dosyasında `@` satırlarıyla tanımlanır, ızgarada zemin karakterine döner):
##   %  sınır (harita kenarı / komşu bina; çarpışır)     #  duvar (çarpışır)
##   w  vitrin camı (çarpışır; görüş geçirir, US-007)    +  kapı boşluğu (1 karo; kapı nesnesi US-005)
##   .  iç zemin (satış alanı)                            :  arka oda zemini
##   ,  kaldırım / ara sokak                              _  cadde
##   S  raf (çarpışır, engel)                             T  tezgâh (çarpışır)
##   I  içecek dolabı (çarpışır, görüşü keser; US-033)   G  koli yığını (çarpışır, görüşü keser; US-033)

const TILE := 32
## Raf ve tezgâh şekillerinin karo kenarından içe payı (px); çizim ve çarpışma aynı payı kullanır.
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

## Çarpışan türler ve `Walls` altındaki şekil adı öneki (Window*: Faz 2 görüş sistemi camı ayırt eder).
## Dolap ve koli (US-033) dolu engeldir: çarpışır ve görüşü keser, raf gibi `Walls` gövdesinin şeklidir.
const SOLID_PREFIX := {
	Kind.BOUND: "Bound",
	Kind.WALL: "Wall",
	Kind.WINDOW: "Window",
	Kind.SHELF: "Shelf",
	Kind.COUNTER: "Counter",
	Kind.COOLER: "Cooler",
	Kind.CRATE: "Crate",
}

## Görüş sınıfları (US-011a; `Level.vision_cells` → VisionGrid.Cell). Katı: görüşü her zaman keser, ışın atılmaz,
## yalnız komşuluktan görünür (yapı). Geçit: fizik sorgusu karar verir (cam geçirir, kapalı kapı keser).
## Diğer türler açık. Yeni bir görüş engeli türü tek satırla SIGHT_SOLID'e eklenir (US-033: dolap, koli).
const SIGHT_SOLID: Array[Kind] = [Kind.BOUND, Kind.WALL, Kind.SHELF, Kind.COUNTER, Kind.COOLER, Kind.CRATE]
const SIGHT_PORTAL: Array[Kind] = [Kind.WINDOW, Kind.DOOR]

# Çizgi kalınlıkları ve aralıklar (renkler tondan: ThemeTokens.tone()).
const WALL_EDGE_WIDTH := 2.0
const CURB_WIDTH := 2.0
const GLASS_WIDTH := 6.0
const SHELF_BAY := 16.0       # raf bölme aralığı (px)
const HATCH_STEP := 8         # harita kenarı tarama aralığı (px; TILE'ı tam böler, karolar arası kesintisiz)
const HATCH_WIDTH := 2.0
const COOLER_GLASS := 5.0     # dolabın zemine bakan cam kapağı (px)
const CRATE_LID := 6.0        # üstteki koli kenar payı (px; yığın görünümü)
## Eşya türleri (içe paylı şekil; çizim sırası).
const FURNITURE: Array[Kind] = [Kind.SHELF, Kind.COUNTER, Kind.COOLER, Kind.CRATE]

@export var rows: PackedStringArray = PackedStringArray():
	set(value):
		rows = value
		queue_redraw()


## Izgara boyutu (karo): x = sütun, y = satır.
func size_in_tiles() -> Vector2i:
	return Vector2i(rows[0].length() if not rows.is_empty() else 0, rows.size())


func has_cell(cell: Vector2i) -> bool:
	var size: Vector2i = size_in_tiles()
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Hücre türü; ızgara dışı sınır sayılır.
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


## Türün karolarını açgözlü birleştirilmiş dikdörtgenlere böler (karo biriminde; satır satır, soldan sağa).
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


## Birleştirilmiş dikdörtgenin piksel karşılığı (raf/tezgâh içe paylı); çizim ve çarpışma bunu kullanır.
static func shape_rect(kind: Kind, cells: Rect2i) -> Rect2:
	var rect := Rect2(Vector2(cells.position) * TILE, Vector2(cells.size) * TILE)
	return rect.grow(-FURNITURE_INSET) if is_furniture(kind) else rect


## Türün zemin/dolgu rengi (etkin tonun seviye paletinden).
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


## Kenar/çizgi rengi: duvar iç kenarı, cam şeridi, raf ve tezgâh dış çizgisi.
static func edge_color(kind: Kind) -> Color:
	var tone: Tone = ThemeTokens.tone()
	match kind:
		Kind.BOUND:
			return tone.wall_color  # tarama çizgisi: cadde ve kaldırımdan ayrı okunur
		Kind.WALL:
			return tone.level_wall_edge_color
		Kind.WINDOW:
			return tone.level_glass_color
		Kind.SHELF:
			return tone.level_shelf_edge_color
		Kind.COUNTER, Kind.CRATE:
			return tone.level_counter_edge_color
		Kind.COOLER:
			return tone.level_glass_color  # camlı kapak: rafın kenarından açık, dolap raftan ayrı okunur
		Kind.SIDEWALK:
			return tone.wall_color  # bordür
	return color_of(kind)


## İki geçiş (çizim toplama, teknik/cizim-performans.md P1): önce bütün dolu dikdörtgenler (zemin, cam şeridi,
## duvar kenarı, bordür, eşya dolgusu), sonra bütün çizgiler (sınır taraması, eşya dış çizgisi ve raf bölmeleri).
## Komut türü sık değişmediği için toplu çizilir; çizgiler hiçbir dolgunun altında kalmaz (kenar taraması komşu
## karoya en çok yarım çizgi kalınlığı taşar).
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


## Duvarın yürünebilir ya da eşyalı tarafına açık renk kenar: odalar üstten kalın ve net okunur.
func _draw_wall_edges(cell: Vector2i) -> void:
	var color: Color = edge_color(Kind.WALL)
	for edge: Rect2 in wall_edge_rects(cell):
		draw_rect(edge, color)


## Duvar/cam karosunun kenar çizgileri (px, seviye koordinatı): yürünebilir ya da eşyalı komşuya bakan her kenar
## için WALL_EDGE_WIDTH kalınlıkta şerit. Duvar ya da cam değilse boş. Seviye çizimi ve görüş sisinin krokisi
## (US-011a, `FogLayer`) aynı çizgileri kullanır.
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


## Kapı boşluğu karosunun eşik çizgisi (iki uç, px): boşluğu kesen duvar doğrultusunda, karo ortasından.
## Kapı boşluğu değilse boş.
func door_gap_segment(cell: Vector2i) -> PackedVector2Array:
	if kind_at(cell) != Kind.DOOR:
		return PackedVector2Array()
	var c: Vector2 = cell_center(cell)
	var half: float = TILE / 2.0
	if _horizontal_wall(cell):
		return PackedVector2Array([c - Vector2(half, 0), c + Vector2(half, 0)])
	return PackedVector2Array([c - Vector2(0, half), c + Vector2(0, half)])


## Harita kenarı / komşu bina: çapraz tarama, yürünebilir dış alandan ayrı okunur.
func _draw_hatch(rect: Rect2) -> void:
	var color: Color = edge_color(Kind.BOUND)
	var o: Vector2 = rect.position
	for k: int in range(HATCH_STEP, TILE * 2, HATCH_STEP):
		if k <= TILE:
			draw_line(o + Vector2(k, 0), o + Vector2(0, k), color, HATCH_WIDTH)
		else:
			draw_line(o + Vector2(TILE, k - TILE), o + Vector2(k - TILE, TILE), color, HATCH_WIDTH)


## Kaldırımın caddeye bakan kenarında bordür çizgisi.
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


## Eşyanın dış çizgisi ve raf bölmeleri (dolgu `_draw` dikdörtgen geçişinde).
func _draw_furniture_lines(kind: Kind, cells: Rect2i) -> void:
	var rect: Rect2 = shape_rect(kind, cells)
	draw_rect(rect, edge_color(kind), false, 1.0)
	if kind == Kind.SHELF:
		# Çift yüzlü raf: uzun eksen boyunca orta çizgi ve kısa bölmeler; duvardan ayrı okunur.
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
		# Koli yığını: bantlı üst koli (çapraz bant) ve altta görünen ikinci kolinin kenarı.
		var edge: Color = edge_color(kind)
		var lid := Rect2(rect.position + Vector2(CRATE_LID, 0), rect.size - Vector2(CRATE_LID, CRATE_LID))
		draw_rect(lid, edge, false, 1.0)
		draw_line(lid.position, lid.end, edge, 1.0)
		draw_line(Vector2(lid.end.x, lid.position.y), Vector2(lid.position.x, lid.end.y), edge, 1.0)


## İçecek dolabının camlı kapak şeridi (px): zemine bakan uzun kenarda (dolap duvara yaslı; arka yüz kör).
func _cooler_glass(rect: Rect2, cells: Rect2i) -> Rect2:
	if cells.size.y >= cells.size.x:
		var west_open: bool = not is_solid(kind_at(cells.position + Vector2i.LEFT))
		var x: float = rect.position.x if west_open else rect.end.x - COOLER_GLASS
		return Rect2(x, rect.position.y, COOLER_GLASS, rect.size.y)
	var north_open: bool = not is_solid(kind_at(cells.position + Vector2i.UP))
	var y: float = rect.position.y if north_open else rect.end.y - COOLER_GLASS
	return Rect2(rect.position.x, y, rect.size.x, COOLER_GLASS)


## Karonun altındaki zemin: eşya ve kapı için komşu zemin türü (önce iç zemin; dışarıdaki eşya için kaldırım/cadde),
## diğerleri kendisi.
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


## Karo yatay bir duvar şeridinde mi (sol ya da sağ komşusu duvar/cam)?
func _horizontal_wall(cell: Vector2i) -> bool:
	return not _opens(cell + Vector2i.LEFT) or not _opens(cell + Vector2i.RIGHT)


func _row_free(start: Vector2i, width: int, kind: Kind, taken: PackedByteArray, stride: int) -> bool:
	for xx: int in range(start.x, start.x + width):
		if taken[start.y * stride + xx] != 0 or kind_at(Vector2i(xx, start.y)) != kind:
			return false
	return true
