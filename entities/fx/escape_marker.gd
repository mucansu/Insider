class_name EscapeMarker
extends Node2D
## Kaçış noktasının dünya işareti (US-038 AC1; GDD §9.3): seviye kökünde ayrı görsel düğüm, seviye düzenine
## dokunmaz (S4 bölgesi `Zones/<zone_name>` üreticide kalır; bu düğüm "elle eklenmiş diğer düğüm" olarak korunur).
## Konum ve boyut bölgenin dikdörtgen şeklinden okunur (Level API, ördek tipleme: `zone(ad)`; entities → levels
## derleme bağımlılığı yok, §6).
## - Zemin katmanı (bu düğüm, z 0): yarı saydam dolgu + çapraz tarama + kenar çizgisi; dolgu hafif nabız atar
##   (hareket azaltmada sabit: `reduce_motion` ya da Puppet.is_reduced_motion()). Sis kurallarına uyar: bilinmeyen
##   karoda sisin altında kalır, hafızada soluk görünür.
## - Kroki katmanı (`Kroki` çocuğu, z = VisionRules.ABOVE_FOG_Z − 1): ince kenar çizgisi + kaçış aracı silueti,
##   nabızsız. Sisin üstünde, oyuncuların altında: kaçış noktası (ekibin bildiği plan bilgisi) haritanın sisli
##   yerinde de bulunur (sisin duvar krokisi gibi).
## Renk ThemeTokens.GAMEPLAY_ESCAPE (her tonda aynı).

## İşaretlenen bölge (Level.zone adı).
@export var zone_name: StringName = &"EscapeZone"
## Hareket azaltma (GDD §14.1 kural 5): nabız yok, dolgu sabit.
var reduce_motion: bool = false

const KROKI_Z := VisionRules.ABOVE_FOG_Z - 1
## Nabız: dolgu alfası taban ± genlik, periyot (sn).
const FILL_ALPHA := 0.22
const PULSE_AMPLITUDE := 0.12
const PULSE_PERIOD := 1.6
const EDGE_WIDTH := 3.0
const KROKI_EDGE_WIDTH := 2.0
const HATCH_ALPHA := 0.35
const HATCH_STEP := 16.0
const HATCH_WIDTH := 2.0
## Kaçış aracı silueti: bölge yüksekliğine göre oran (gövde en/boy ~2,2).
const VAN_HEIGHT_RATIO := 0.5
const VAN_ASPECT := 2.2
const SILHOUETTE_ALPHA := 0.85

## Bölgenin bu düğüme göre dikdörtgeni (yerel); bölge yoksa alanı sıfır.
var rect: Rect2 = Rect2()
var _t: float = 0.0
var _kroki: Node2D = null


func _ready() -> void:
	_kroki = Node2D.new()
	_kroki.name = "Kroki"
	_kroki.z_index = KROKI_Z
	_kroki.z_as_relative = false
	add_child(_kroki)
	_kroki.draw.connect(_draw_kroki)
	rect = read_zone_rect()
	queue_redraw()
	_kroki.queue_redraw()


func _process(delta: float) -> void:
	if is_motion_reduced():
		return
	_t = fmod(_t + delta, PULSE_PERIOD)
	queue_redraw()


func is_motion_reduced() -> bool:
	return reduce_motion or Puppet.is_reduced_motion()


## Dolgu alfası `t` saniyede (hareket azaltmada sabit taban).
static func fill_alpha(t: float, reduced: bool) -> float:
	if reduced:
		return FILL_ALPHA
	return FILL_ALPHA + PULSE_AMPLITUDE * sin(TAU * t / PULSE_PERIOD)


## O anki dolgu alfası.
func current_fill_alpha() -> float:
	return fill_alpha(_t, is_motion_reduced())


func kroki() -> Node2D:
	return _kroki


## Bölgenin (ilk dikdörtgen şekli) bu düğüme göre dikdörtgeni; bölge ya da şekil yoksa Rect2().
func read_zone_rect() -> Rect2:
	var level: Node = get_parent()
	if level == null or not level.has_method(&"zone"):
		return Rect2()
	var zone: Area2D = level.call(&"zone", zone_name) as Area2D
	if zone == null:
		return Rect2()
	for child: Node in zone.get_children():
		var holder: CollisionShape2D = child as CollisionShape2D
		var shape: RectangleShape2D = holder.shape as RectangleShape2D if holder != null else null
		if shape == null:
			continue
		var center: Vector2 = to_local(holder.global_position) if holder.is_inside_tree() and is_inside_tree() \
			else zone.position + holder.position - position
		return Rect2(center - shape.size / 2.0, shape.size)
	return Rect2()


func _draw() -> void:
	if not rect.has_area():
		return
	var color: Color = ThemeTokens.GAMEPLAY_ESCAPE
	draw_rect(rect, Color(color, current_fill_alpha()))
	# Çapraz tarama (45°), dikdörtgene kırpılmış.
	var hatch := Color(color, HATCH_ALPHA)
	var span: float = rect.size.x + rect.size.y
	var x: float = 0.0
	while x < span:
		var a := Vector2(rect.position.x + x, rect.position.y)
		var b := Vector2(rect.position.x + x - rect.size.y, rect.end.y)
		var clipped: PackedVector2Array = _clip_segment(a, b, rect)
		if clipped.size() == 2:
			draw_line(clipped[0], clipped[1], hatch, HATCH_WIDTH)
		x += HATCH_STEP
	draw_rect(rect, color, false, EDGE_WIDTH)


func _draw_kroki() -> void:
	if not rect.has_area():
		return
	var color: Color = ThemeTokens.GAMEPLAY_ESCAPE
	_kroki.draw_rect(rect.grow(-EDGE_WIDTH), color, false, KROKI_EDGE_WIDTH)
	# Kaçış aracı silueti (yer tutucu): gövde, kabin camı, iki teker.
	var h: float = rect.size.y * VAN_HEIGHT_RATIO
	var body := Rect2(rect.get_center() - Vector2(h * VAN_ASPECT, h) / 2.0, Vector2(h * VAN_ASPECT, h))
	var ink := Color(color, SILHOUETTE_ALPHA)
	_kroki.draw_rect(body, ink)
	var glass := Rect2(body.end.x - body.size.x * 0.28, body.position.y + h * 0.15, body.size.x * 0.2, h * 0.35)
	_kroki.draw_rect(glass, ThemeTokens.tone().bg_color)
	var wheel_r: float = h * 0.2
	for fx: float in [0.22, 0.78]:
		var c := Vector2(body.position.x + body.size.x * fx, body.end.y)
		_kroki.draw_circle(c, wheel_r + 1.0, ThemeTokens.tone().bg_color)
		_kroki.draw_circle(c, wheel_r, ink)


## `a`-`b` doğru parçasının `r` içindeki kısmı (Liang–Barsky); dışarıdaysa boş.
static func _clip_segment(a: Vector2, b: Vector2, r: Rect2) -> PackedVector2Array:
	var d: Vector2 = b - a
	var t0: float = 0.0
	var t1: float = 1.0
	var checks: Array = [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y],
		[d.y, r.end.y - a.y]]
	for pq: Array in checks:
		var p: float = pq[0]
		var q: float = pq[1]
		if is_zero_approx(p):
			if q < 0.0:
				return PackedVector2Array()
			continue
		var t: float = q / p
		if p < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])
