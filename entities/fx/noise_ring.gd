class_name NoiseRing
extends Node2D
## Gürültü halkası görseli (US-009 AC5; mimari.md S8, S9; GDD §14.1 kural 2): NoiseBus her peer'da halka olayında
## seviyenin altına ekler. En az MIN_RADIUS'tan (1280×720'de 22 px çap) sesin yarıçapına DURATION sn'de
## genişler ve solar, sonra kendini kaldırır. Renk tonun ön plan rengi (KR-019: noir FG, ikinci renk yok).
## Hareket azaltmada (`reduced_motion`) genişleme yok: halka baştan tam yarıçapta görünür ve yalnız solar.
## Oyun kuralı taşımaz; yalnız kendi yaşını okur.

const DURATION := 0.4
## 22 px çap (GDD §14.1 kural 2: oyun işaretleri ≥ 22 px).
const MIN_RADIUS := 11.0
const LINE_WIDTH := 3.0
## Sonda kalan en düşük opaklık (kaybolana dek okunur).
const END_ALPHA := 0.3
const SEGMENTS := 48
const Z_INDEX := 20

## Hareket azaltma ayarı (oyuncu ayarı; UI ve kukla bayrağı bağlanınca oradan atanır).
static var reduced_motion: bool = false

var radius: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	z_index = Z_INDEX


## Sesin yarıçapı (px).
func setup(noise_radius: float) -> void:
	radius = noise_radius
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func age() -> float:
	return _age


func current_radius() -> float:
	return ring_radius(_age, radius, reduced_motion)


## `age` sn'deki çizim yarıçapı: MIN_RADIUS → max(yarıçap, MIN_RADIUS), yavaşlayarak; hareket azaltmada sabit.
static func ring_radius(at_age: float, noise_radius: float, reduced: bool) -> float:
	var full: float = maxf(noise_radius, MIN_RADIUS)
	if reduced:
		return full
	var t: float = clampf(at_age / DURATION, 0.0, 1.0)
	return lerpf(MIN_RADIUS, full, 1.0 - (1.0 - t) * (1.0 - t))


static func ring_alpha(at_age: float) -> float:
	return lerpf(1.0, END_ALPHA, clampf(at_age / DURATION, 0.0, 1.0))


func _draw() -> void:
	var color: Color = ThemeTokens.tone().fg_color
	color.a *= ring_alpha(_age)
	draw_arc(Vector2.ZERO, current_radius(), 0.0, TAU, SEGMENTS, color, LINE_WIDTH, true)
