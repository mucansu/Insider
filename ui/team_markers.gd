class_name TeamMarkers
extends Control
## Ekip arkadaşı işaretleri (US-011c; GDD §6.5): ekip arkadaşı her zaman tam çizilir (kuklası entities'de);
## bu katman yalnız iki işaret ekler — ekrandaki arkadaşın başının üstünde "görüldü" gözü (maruziyeti 2 iken)
## ve ekran dışındaki arkadaş için ekran kenarında atkı renginde (PLAYER_COLORS[slot]) ok; görüldüyse okun
## yanında göz. Kimin gördüğü gösterilmez (§2.9). Dünya → ekran dönüşümü görünümün tuval dönüşümüyle.
## Game'den yalnız S3 ve S3 eki (mimari.md, US-011b/c) üyeleri okunur: players()/players_changed, player_world_position(peer),
## player_exposure(peer)/player_exposure_changed; yerel peer Net.local_peer_id(). Game konum vermiyorsa katman
## gizli kalır (uyarı yok); maruziyet API'si yoksa yalnız oklar çizilir. HUD `bind()` ve her karede `advance()`.

## Ok merkezinin ekran kenarına uzaklığı (px).
const EDGE_MARGIN := 28.0
## Ok boyu ve "görüldü" gözü (ekran px): GDD §14.1 oyun bilgisi işareti 1280×720'de ≥ 22 px
## (göz 16 dünya px × kamera 1,5 = 24).
const ARROW_SIZE := 26.0
const SEEN_ICON_SIZE := 24.0
## "Görüldü" gözünün dünyadaki sabit bağlantı noktası: oyuncu merkezinin üstü (kukla başının üstü,
## animasyondan bağımsız — §14.1 kural 2).
const SEEN_ANCHOR := Vector2(0.0, -40.0)
## Okun yanındaki gözün ok merkezine uzaklığı (ekranın içine doğru).
const ARROW_EYE_GAP := 30.0
const OUTLINE_WIDTH := 3.0
## Okun HUD bloğuna en yakın mesafesi (px).
const ARROW_CLEARANCE := 6.0

## Testler için dünya → ekran dönüşümü (Vector2 -> Vector2); geçersizse görünümün tuval dönüşümü.
var world_to_screen: Callable
## Okun örtmemesi gereken HUD blokları (HUD atar: nakit, ekip listesi, merdiven, rozet, istem); görünür olan
## bloğun üstüne düşen ok kenar boyunca bloğun içe bakan yanına itilir.
var avoid: Array[Control] = []

var game: Object = null
var net: Object = null
## peer -> maruziyet (0..2), sinyalden.
var _exposure: Dictionary = {}
## Son hesaplanan işaretler; bkz. `markers()`.
var _markers: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


## Game konum API'si (S3 eki; mimari.md, US-011b/c) var mı.
static func supports(source: Object) -> bool:
	return source != null and source.has_method(&"player_world_position") and source.has_method(&"players")


func bind(source_game: Object, source_net: Object) -> void:
	game = source_game
	net = source_net
	visible = supports(game) and net != null
	if not visible:
		return
	game.connect(&"players_changed", _read_exposures)
	if ExposureBadge.supports(game):
		game.connect(&"player_exposure_changed", _on_exposure_changed)
	_read_exposures()
	refresh()


## Her karede (HUD çağırır); Game/Net kapanışta HUD'dan önce serbest kalırsa işlem yapılmaz.
func advance(_delta: float) -> void:
	if visible and is_instance_valid(game) and is_instance_valid(net):
		refresh()


## Son hesaplanan işaretler: {"peer", "kind" (&"seen" | &"arrow"), "pos" (ekran), "angle" (ok yönü, rad),
## "color" (atkı rengi), "seen" (bool)}. Ekrandaki ve görülmeyen arkadaş için işaret yoktur.
func markers() -> Array[Dictionary]:
	return _markers


## Hedef ekran noktası `rect` dışındaysa `rect` merkezinden hedefe giden ışının `rect` kenarını kestiği nokta;
## içindeyse hedefin kendisi.
static func edge_point(target: Vector2, rect: Rect2) -> Vector2:
	var center: Vector2 = rect.get_center()
	var d: Vector2 = target - center
	var t: float = 1.0
	if absf(d.x) > 0.0:
		t = minf(t, rect.size.x / 2.0 / absf(d.x))
	if absf(d.y) > 0.0:
		t = minf(t, rect.size.y / 2.0 / absf(d.y))
	return center + d * t


## `inner` kenarındaki `pos`, `blocks` dikdörtgenlerinden birine (ok yarı boyu + pay kadar büyütülmüş) düşüyorsa
## kenara dik yönde, ekranın içine doğru bloğun dışına itilir (üst kenarda bloğun altına, solda sağına …).
static func push_clear(pos: Vector2, inner: Rect2, blocks: Array[Rect2], half: float) -> Vector2:
	var out: Vector2 = pos
	for block: Rect2 in blocks:
		var grown: Rect2 = block.grow(half)
		if not grown.has_point(out):
			continue
		if is_equal_approx(out.y, inner.position.y):
			out.y = grown.end.y
		elif is_equal_approx(out.y, inner.end.y):
			out.y = grown.position.y
		elif is_equal_approx(out.x, inner.position.x):
			out.x = grown.end.x
		else:
			out.x = grown.position.x
	return out


func refresh() -> void:
	_markers.clear()
	var screen := Rect2(Vector2.ZERO, size)
	var inner: Rect2 = screen.grow(-EDGE_MARGIN)
	var players: Dictionary = game.call(&"players")
	var local_id: int = int(net.call(&"local_peer_id"))
	var ids: Array = players.keys()
	ids.sort()
	var blocks: Array[Rect2] = []
	for c: Control in avoid:
		if is_instance_valid(c) and c.is_visible_in_tree():
			blocks.append(Rect2(c.global_position - global_position, c.size))
	for i: int in ids.size():
		var peer: int = ids[i]
		if peer == local_id:
			continue
		var world: Vector2 = game.call(&"player_world_position", peer)
		if not world.is_finite():
			continue  # oyuncu henüz yok
		var seen: bool = int(_exposure.get(peer, EyeIcon.HIDDEN)) >= EyeIcon.SEEN
		var at: Vector2 = _to_screen(world)
		if screen.has_point(at):
			if seen:
				var anchor: Vector2 = _to_screen(world + SEEN_ANCHOR)
				anchor.y = maxf(anchor.y, SEEN_ICON_SIZE / 2.0)
				_markers.append({"peer": peer, "kind": &"seen", "pos": anchor, "angle": 0.0,
					"color": _slot_color(players[peer], i), "seen": true})
			continue
		var pos: Vector2 = push_clear(edge_point(at, inner), inner, blocks, ARROW_SIZE / 2.0 + ARROW_CLEARANCE)
		_markers.append({"peer": peer, "kind": &"arrow", "pos": pos,
			"angle": (at - inner.get_center()).angle(), "color": _slot_color(players[peer], i), "seen": seen})
	queue_redraw()


func _draw() -> void:
	for m: Dictionary in _markers:
		var pos: Vector2 = m["pos"]
		if m["kind"] == &"arrow":
			var dir := Vector2.from_angle(float(m["angle"]))
			_draw_arrow(pos, dir, m["color"])
			if m["seen"]:
				EyeIcon.draw_eye(self, pos - dir * ARROW_EYE_GAP, SEEN_ICON_SIZE, EyeIcon.SEEN)
		else:
			EyeIcon.draw_eye(self, pos, SEEN_ICON_SIZE, EyeIcon.SEEN)


func _draw_arrow(center: Vector2, dir: Vector2, color: Color) -> void:
	draw_arrow(self, center, dir, color, ARROW_SIZE)


## Kenar oku (ok ucu `dir` yönünde, zemin renginde dış çizgili); kaçış oku da kullanır (US-038).
static func draw_arrow(canvas: CanvasItem, center: Vector2, dir: Vector2, color: Color, arrow_size: float) -> void:
	var side: Vector2 = dir.orthogonal() * arrow_size * 0.45
	var tip: Vector2 = center + dir * arrow_size * 0.5
	var back: Vector2 = center - dir * arrow_size * 0.5
	var points := PackedVector2Array([tip, back + side, center - dir * arrow_size * 0.25, back - side])
	var outline: PackedVector2Array = points.duplicate()
	outline.append(tip)
	canvas.draw_polyline(outline, ThemeTokens.tone().bg_color, OUTLINE_WIDTH * 2.0, true)
	canvas.draw_colored_polygon(points, color)


func _to_screen(world: Vector2) -> Vector2:
	if world_to_screen.is_valid():
		return world_to_screen.call(world)
	return get_viewport().get_canvas_transform() * world


## S3: Game renk değil katılım yuvası yayınlar; renk slot'tan (slot yoksa sıra).
static func _slot_color(info: Variant, index: int) -> Color:
	var slot: int = index
	if info is Dictionary and typeof((info as Dictionary).get("slot")) == TYPE_INT:
		slot = int((info as Dictionary)["slot"])
	return ThemeTokens.PLAYER_COLORS[posmod(slot, ThemeTokens.PLAYER_COLORS.size())]


func _read_exposures() -> void:
	_exposure.clear()
	if not ExposureBadge.supports(game):
		return
	var players: Dictionary = game.call(&"players")
	for peer: int in players:
		_exposure[peer] = int(game.call(&"player_exposure", peer))


func _on_exposure_changed(peer: int, value: int) -> void:
	_exposure[peer] = value
