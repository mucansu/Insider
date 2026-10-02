class_name PuppetSpring
extends RefCounted
## Kukla yayı (US-014): sönümlü yay, yarı örtük Euler; PuppetRig'in sabit adımıyla ilerler. Gövde ezilmesi,
## eğilme ve gözler bununla yumuşar (lineer hareket yok; GDD §14.1).
## Kararlılık: yarı örtük Euler ω·h ve 2ζ·ω·h büyüyünce patlar (ör. 10 Hz × sönüm 2 ya da 20 Hz); adım, bu iki
## değer alt adım başına STABLE_LIMIT'i aşmayacak kadar alt adıma bölünür (en çok MAX_SUBSTEPS). Bu da
## yetmezse frekans ve sönüm o sınıra kenetlenir; sonlu olmayan durum hedefe sıfırlanır.

## Alt adım başına ω·h ve 2ζ·ω·h üst sınırı.
const STABLE_LIMIT := 0.5
const MAX_SUBSTEPS := 16

var x: float = 0.0
var v: float = 0.0


func _init(value: float = 0.0) -> void:
	x = value


func step(target: float, frequency: float, damping: float, h: float) -> void:
	var w: float = TAU * maxf(0.0, frequency)
	var zeta: float = maxf(0.0, damping)
	var stiffness: float = maxf(w * h, 2.0 * zeta * w * h)
	var count: int = clampi(ceili(stiffness / STABLE_LIMIT), 1, MAX_SUBSTEPS)
	var sub: float = h / count
	var limit: float = STABLE_LIMIT / sub
	w = minf(w, limit)
	zeta = minf(zeta, limit / maxf(2.0 * w, 0.0001))
	for i: int in count:
		v += (w * w * (target - x) - 2.0 * zeta * w * v) * sub
		x += v * sub
	if not (is_finite(x) and is_finite(v)):
		settle(target)


## Hedefe hızsız oturur (sessiz yeniden kurulum).
func settle(value: float) -> void:
	x = value
	v = 0.0
