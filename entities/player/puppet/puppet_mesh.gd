class_name PuppetMesh
extends RefCounted
## Kukla çizim tamponu (US-014): parçalar (elips, dolgu, çizgi, şerit) renkli bir üçgen dizisinde toplanır ve
## tek komutla gönderilir (RenderingServer.canvas_item_add_triangle_array). Kenarlar ~1 px'te saydamlaşan bir
## "tüy" halkasıyla yumuşatılır (AA); ayrı kenar çizgisi yok. Ressam sırası korunur: sonra eklenen üstte.
##
## Hız (mekân nüfusu: 9+ kukla): elips noktaları önbellekteki birim daire şablonunun dönüşümüyle (C++ dizi
## işlemi) üretilir; indeksler parça dizisinin "topolojisine" (parça başına nokta sayısı) göre paylaşılan
## önbellekte tutulur — poz değişse de topoloji çoğu karede aynıdır, indeks dizisi yeniden kurulmaz.
## Doku yuvası olan parça için Puppet tamponu `flush` eder, dokuyu çizer ve devam eder (sıra bozulmaz).
## Düğüm bilmez; yalnız `flush` bir tuval öğesi (RID) alır.

## Kenar yumuşatma halkası (ekran px; `pixel_ratio` ile yerel px'e çevrilir).
const FEATHER := 0.9
## Elips kenar nokta sayısı: ekran px yarıçap başına, tam elipste en az / en çok.
const SEGMENTS_PER_PIXEL := 1.2
const MIN_SEGMENTS := 8
const MAX_SEGMENTS := 28
## Topoloji kodu: şerit = RIBBON_CODE + nokta sayısı; yelpaze = ±kenar nokta sayısı (+ kapalı, - açık yay).
const RIBBON_CODE := 1000
## Paylaşılan önbelleklerin üst sınırı (aşınca temizlenir).
const CACHE_LIMIT := 256
## Çok kısa çizgi parçası (px): yönü belirsiz.
const MIN_SEGMENT := 0.001

static var _unit_cache: Dictionary = {}
static var _index_cache: Dictionary = {}

## Eklenen noktaların dönüşümü (birim → düğüm yereli px).
var transform: Transform2D = Transform2D.IDENTITY
## Ekran px / düğüm yereli px (kamera yakınlaştırması dahil): tüy her ölçekte ~1 ekran px, yuvarlaklık ölçekle.
var pixel_ratio: float = 1.0

var _points: PackedVector2Array = []
var _colors: PackedColorArray = []
var _topology: PackedInt32Array = []
var _fill_colors: PackedColorArray = []
var _submissions: int = 0
var _triangles: int = 0


## Kare başı: tampon ve sayaçlar sıfırlanır.
func begin() -> void:
	_points.clear()
	_colors.clear()
	_topology.clear()
	_submissions = 0
	_triangles = 0
	transform = Transform2D.IDENTITY


## Bu karede gönderilen tampon komutu sayısı.
func submissions() -> int:
	return _submissions


func triangles() -> int:
	return _triangles


## Biriken üçgenleri tek komutla tuval öğesine ekler.
func flush(canvas_item: RID) -> void:
	if _topology.is_empty():
		return
	var key: String = str(_topology)
	var indices: PackedInt32Array = _index_cache.get(key, PackedInt32Array())
	if indices.is_empty():
		indices = build_indices(_topology)
		if _index_cache.size() >= CACHE_LIMIT:
			_index_cache.clear()
		_index_cache[key] = indices
	RenderingServer.canvas_item_add_triangle_array(canvas_item, indices, _points, _colors)
	_submissions += 1
	_triangles += indices.size() / 3
	_points.clear()
	_colors.clear()
	_topology.clear()


## Dolu elips ya da `from`..`to` dilimi (kirişle kapanır). `segments` 0 ise yarıçaptan.
func ellipse(center: Vector2, radius: Vector2, color: Color, from: float = 0.0, to: float = TAU,
		segments: int = 0) -> void:
	if radius.x <= 0.0 or radius.y <= 0.0 or color.a <= 0.0:
		return
	var span: float = to - from
	var full: bool = is_equal_approx(absf(span), TAU)
	var n: int = segments
	if n <= 0:
		n = clampi(ceili(maxf(radius.x, radius.y) * _scale() * pixel_ratio * SEGMENTS_PER_PIXEL * absf(span) / TAU),
			MIN_SEGMENTS if full else 2, MAX_SEGMENTS)
	var unit: PackedVector2Array = unit_arc(from, to, n)
	var fu: float = _feather() / _scale()
	var rim: PackedVector2Array = (transform * Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center)) * unit
	var outer: PackedVector2Array = (transform * Transform2D(Vector2(radius.x + fu, 0.0), Vector2(0.0, radius.y + fu),
		center)) * unit
	_push_fan(transform * center, rim, outer, color, full)


func circle(center: Vector2, radius: float, color: Color, segments: int = 0) -> void:
	ellipse(center, Vector2(radius, radius), color, 0.0, TAU, segments)


func rect(r: Rect2, color: Color) -> void:
	fill(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		color)


## Dışbükey dolgu (birim noktalar, az noktalı şekiller): merkezden yelpaze + dışa tüy.
func fill(local: PackedVector2Array, color: Color) -> void:
	var n: int = local.size()
	if n < 3 or color.a <= 0.0:
		return
	var px: PackedVector2Array = transform * local
	var c := Vector2.ZERO
	for p: Vector2 in px:
		c += p
	c /= n
	var outer: PackedVector2Array = []
	for p: Vector2 in px:
		outer.append(p + (p - c).normalized() * _feather())
	_push_fan(c, px, outer, color, true)


## Çizgi (birim noktalar, birim kalınlık; uçlar düz).
func stroke(local: PackedVector2Array, color: Color, width: float) -> void:
	var widths: PackedFloat32Array = []
	widths.resize(local.size())
	widths.fill(width * _scale())
	ribbon(transform * local, widths, color)


## Değişken kalınlıklı şerit (px noktalar, px kalınlıklar; dönüşüm uygulanmaz): atkı.
func ribbon(px: PackedVector2Array, widths: PackedFloat32Array, color: Color) -> void:
	var n: int = px.size()
	if n < 2 or color.a <= 0.0:
		return
	var clear := Color(color, 0.0)
	var feather: float = _feather()
	for i: int in n:
		var d: Vector2 = px[mini(i + 1, n - 1)] - px[maxi(i - 1, 0)]
		var normal: Vector2 = Vector2(-d.y, d.x).normalized() if d.length() > MIN_SEGMENT else Vector2.UP
		var half: float = widths[i] * 0.5
		_points.append_array([px[i] - normal * (half + feather), px[i] - normal * half, px[i] + normal * half,
			px[i] + normal * (half + feather)])
		_colors.append_array([clear, color, color, clear])
	_topology.append(RIBBON_CODE + n)


## Birim elips yayı (önbellekli): tam elipste `n`, yayda `n + 1` nokta.
static func unit_arc(from: float, to: float, n: int) -> PackedVector2Array:
	var key := Vector3(from, to, n)
	var cached: PackedVector2Array = _unit_cache.get(key, PackedVector2Array())
	if not cached.is_empty():
		return cached
	var span: float = to - from
	var full: bool = is_equal_approx(absf(span), TAU)
	var count: int = n if full else n + 1
	var pts: PackedVector2Array = []
	for i: int in count:
		var a: float = from + span * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)))
	if _unit_cache.size() >= CACHE_LIMIT:
		_unit_cache.clear()
	_unit_cache[key] = pts
	return pts


## Elips yayı noktaları (birim; çizgiler için).
static func arc_points(center: Vector2, radius: Vector2, from: float, to: float, n: int = 8) -> PackedVector2Array:
	return Transform2D(Vector2(radius.x, 0.0), Vector2(0.0, radius.y), center) * unit_arc(from, to, n)


## İkinci dereceden Bezier eğrisi noktaları (birim).
static func bezier(p0: Vector2, p1: Vector2, p2: Vector2, count: int = 9) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i: int in count:
		var t: float = float(i) / float(count - 1)
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return pts


## Topolojiden indeks dizisi (önbellek kaçağında; noktalar `_push_fan`/`ribbon` düzenindedir).
static func build_indices(topology: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = []
	var base: int = 0
	for code: int in topology:
		if code >= RIBBON_CODE:
			var m: int = code - RIBBON_CODE
			for i: int in m - 1:
				var a: int = base + i * 4
				for k: int in 3:
					out.append_array([a + k, a + k + 1, a + k + 5, a + k, a + k + 5, a + k + 4])
			base += m * 4
			continue
		var count: int = absi(code)
		var closed: bool = code > 0
		var edges: int = count if closed else count - 1
		for i: int in edges:
			var j: int = (i + 1) % count
			var ri: int = base + 1 + i
			var rj: int = base + 1 + j
			out.append_array([base, ri, rj, ri, rj, rj + count, ri, rj + count, ri + count])
		base += 1 + count * 2
	return out


## Yelpaze düzeni: merkez, kenar noktaları (renkli), dış halka (saydam).
func _push_fan(center: Vector2, rim: PackedVector2Array, outer: PackedVector2Array, color: Color, closed: bool) -> void:
	var count: int = rim.size()
	_points.append(center)
	_points.append_array(rim)
	_points.append_array(outer)
	_fill_colors.resize(count + 1)
	_fill_colors.fill(color)
	_colors.append_array(_fill_colors)
	_fill_colors.resize(count)
	_fill_colors.fill(Color(color, 0.0))
	_colors.append_array(_fill_colors)
	_topology.append(count if closed else -count)


## Tüy genişliği (düğüm yereli px).
func _feather() -> float:
	return FEATHER / maxf(0.0001, pixel_ratio)


## Dönüşümün ortalama ölçeği (px / birim).
func _scale() -> float:
	return maxf(0.0001, sqrt(absf(transform.determinant())))
