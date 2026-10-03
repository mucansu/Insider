class_name LookRules
extends RefCounted
## Bakış yönü kuralları (US-011b AC3; GDD §6.5, §2b; mimari.md S2). Düğümsüz, yalnız açı değerleriyle çalışır
## (KR-003). Oyuncu (`Player`) yerel bakışı bu kurallarla günceller ve 8 bit açıyla yayınlar; uzak kopya aynı
## dönüş tavanıyla ara değerlenen açıyı izler.
##
## - Dönüş: hedef açıya en kısa yönden; `smoothing` > 0 ise üstel yaklaşım (klavye-yalnız oyuncu: hareket yönüne
##   k = 9, ≈ 0,33 sn; kukla dönüşüyle aynı), her durumda adım başına tavan `max_rate` (rad/sn; 240°/sn).
## - Niceleme: açı [-π, π) → 0..255 (1,4° adım); geri çevirme adımın kendisini verir (yuvarlama, kayma yok).

## Açı adımı sayısı (8 bit).
const STEPS := 256
## Klavye-yalnız oyuncuda hareket yönüne yumuşak dönüş katsayısı (1/sn; kukla `turn_smoothing` ile aynı).
const KEYBOARD_SMOOTHING := 9.0
## Bu uzunluğun altındaki bakış girdisi yok sayılır (ölü bölge InputMap'te; bu yalnız sayısal pay).
const INPUT_EPSILON := 0.01


## Açıyı (rad) 0..255 adıma çevirir.
static func quantize(angle: float) -> int:
	var step: float = TAU / STEPS
	return posmod(roundi(wrapf(angle, -PI, PI) / step), STEPS)


## Adımı açıya (rad, [-π, π)) çevirir.
static func dequantize(step_index: int) -> float:
	return wrapf(posmod(step_index, STEPS) * TAU / STEPS, -PI, PI)


## Nicelenmiş açı (yayınlanan değerin karşı tarafta göreceği açı).
static func snap(angle: float) -> float:
	return dequantize(quantize(angle))


## `current`'tan `target`'a bir adım (rad). `max_rate` rad/sn tavanı (≤ 0: tavan yok); `smoothing` > 0 üstel
## yaklaşım katsayısı (1/sn), 0 ise doğrudan hedefe (tavanla sınırlı).
static func turn(current: float, target: float, delta: float, max_rate: float, smoothing: float = 0.0) -> float:
	var diff: float = angle_difference(current, target)
	var step: float = diff
	if smoothing > 0.0:
		step = diff * (1.0 - exp(-smoothing * maxf(delta, 0.0)))
	if max_rate > 0.0:
		var cap: float = max_rate * maxf(delta, 0.0)
		step = clampf(step, -cap, cap)
	return wrapf(current + step, -PI, PI)


## Bir bakış adımı: açık bakış girdisi (`look`, dünya yönü; fare/sağ çubuk/bot) varsa ona tavanla, yoksa hareket
## yönüne (`facing`) klavye yumuşatmasıyla döner.
static func step_look(current: float, look: Vector2, facing: Vector2, delta: float, max_rate: float) -> float:
	if look.length() >= INPUT_EPSILON:
		return turn(current, look.angle(), delta, max_rate)
	if facing.length() < INPUT_EPSILON:
		return current
	return turn(current, facing.angle(), delta, max_rate, KEYBOARD_SMOOTHING)
