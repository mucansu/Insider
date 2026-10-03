class_name BagCarry
extends RefCounted
## Taşınan çantanın görsel tutuşu (IS-085; GDD §14.1, KR-017 tatlı/akıcı hareket): düğümsüz hesap (KR-003).
## Girdi = taşıyanın kukla durumu (gövde bakışı, iki elin taşıyana göre konumu, sırt dönük mü, hız); çıktı =
## tutuş noktası (`grip`, taşıyana göre px), sarkaç açısı (`angle`, rad) ve çizim katmanı (`front`).
## Mantığa, ağa ve çanta kurallarına dokunmaz: her peer kendi kopyasında, kendi gördüğü kukladan türetir.
##
## - Taraf: çanta yakın elde (sağa bakarken sağ el, sola bakarken sol el); bakış dikeye yakınken son taraf korunur
##   (titreme yok). Tutuş elin biraz üstünde: çanta kalça hizasında, ayak hizasında değil.
## - Yumuşak geçiş: tutuş hedefe üstel yaklaşır (taraf değişimi ~0,15 sn); ışınlanma/yeni taşıyan anında kurulur.
## - Salınım: kukla elinin yürüme salınımına ve taşıyanın yatay hızına bağlı sönümlü sarkaç; dururken söner. Hareket azaltmada
##   salınım yok (açı 0) ve el salınımsız duruş pozundan okunur (çağıran `rest` eller verir).

## Bakışın yatay bileşeni bu eşiği geçince taraf değişir; altında son taraf korunur.
const SIDE_THRESHOLD := 0.35
## Tutuş noktası elden bu kadar yukarıda (px).
const GRIP_LIFT := 3.0
## Tutuşun hedefe üstel yaklaşma hızı (1/sn).
const FOLLOW_RATE := 18.0
## Sarkaç hedef açısı (rad) = kukla elinin taşıyana göre yatay hızı × SWING_GAIN + taşıyanın yatay hızı ×
## DRAG_GAIN (rad / (px/sn)), en çok SWAY_MAX: yürüme salınımı küçük sallanma, yürüyüş hafif geride kalma.
const SWING_GAIN := 0.004
const DRAG_GAIN := 0.0006
const SWAY_MAX := 0.3
const SWAY_STIFFNESS := 90.0
const SWAY_DAMPING := 7.0
## Tek güncellemede işlenen en uzun süre (sn) ve iç adım (sn): takılan karede yay patlamasın.
const MAX_DELTA := 0.25
const STEP := 1.0 / 120.0
## Tutuş hedefe bundan uzaksa (px) ışınlanma sayılır: anında kurulur.
const SNAP_DISTANCE := 48.0

## Taşıyan el: +1 sağ, -1 sol.
var side: int = 1
## Tutuş noktası (taşıyanın merkezine göre px).
var grip: Vector2 = Vector2.ZERO
## Sarkaç açısı (rad; pozitif: çantanın altı sola, yani sağa giderken geride kalır).
var angle: float = 0.0
var angular_velocity: float = 0.0
## Taşıyanın önünde mi çizilir (sırt dönükken arkada).
var front: bool = true

var _built: bool = false


## Bakış yönüne göre taşıyan el: yatay bileşen eşiği geçince o yön, değilse `current`.
static func pick_side(face: Vector2, current: int) -> int:
	if face.x > SIDE_THRESHOLD:
		return 1
	if face.x < -SIDE_THRESHOLD:
		return -1
	return current


## Elin dizisi PuppetBody.hands sırasıyla [sol, sağ]; taraf → dizin.
static func hand_index(which_side: int) -> int:
	return 1 if which_side > 0 else 0


func is_built() -> bool:
	return _built


## Bir sonraki güncelleme anında kurar (taşıyan değişti, çanta düştü).
func reset() -> void:
	_built = false


## Bir kare. `face` gövde bakışı (birim), `hands` taşıyana göre px [sol, sağ], `back` sırt dönük,
## `carrier_velocity` taşıyan hızı (px/sn), `reduced` hareket azaltma.
func update(delta: float, face: Vector2, hands: PackedVector2Array, back: bool, carrier_velocity: Vector2,
		reduced: bool) -> void:
	if hands.size() < 2:
		return
	side = pick_side(face, side)
	front = not back
	var target: Vector2 = hands[hand_index(side)] + Vector2(0.0, -GRIP_LIFT)
	if not _built or grip.distance_to(target) > SNAP_DISTANCE:
		grip = target
		angle = 0.0
		angular_velocity = 0.0
		_built = true
		return
	var left: float = clampf(delta, 0.0, MAX_DELTA)
	if left <= 0.0:
		return
	var before: Vector2 = grip
	grip = target + (grip - target) * exp(-FOLLOW_RATE * left)
	if reduced:
		angle = 0.0
		angular_velocity = 0.0
		return
	var goal: float = (grip.x - before.x) / left * SWING_GAIN + carrier_velocity.x * DRAG_GAIN
	goal = clampf(goal, -SWAY_MAX, SWAY_MAX) if is_finite(goal) else 0.0
	while left > 0.0:
		var h: float = minf(STEP, left)
		left -= h
		angular_velocity += ((goal - angle) * SWAY_STIFFNESS - angular_velocity * SWAY_DAMPING) * h
		angle = clampf(angle + angular_velocity * h, -SWAY_MAX, SWAY_MAX)
