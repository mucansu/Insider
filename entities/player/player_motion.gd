class_name PlayerMotion
extends RefCounted
## Oyuncu hareket kuralları (US-004 AC2): kip seçimi, kipe göre hız, ivmelenme ve bakış yönü. Düğümsüz,
## yalnız değerlerle çalışır (KR-003; ileride core/'a taşınabilir). Player her fizik adımında çağırır.

enum Mode { WALK, SNEAK, SPRINT }

## Bu uzunluğun altındaki girdi yönü "hareket yok" sayılır (ölü bölge InputMap'te; bu yalnız sayısal pay).
const MOVE_EPSILON := 0.01


## Kip seçimi: sızma koşmaya baskındır (iki tuş birden basılıysa sessiz kalınır).
static func mode_for(sneak: bool, sprint: bool) -> int:
	if sneak:
		return Mode.SNEAK
	if sprint:
		return Mode.SPRINT
	return Mode.WALK


## Kipin tam hızı (px/sn); bilinmeyen kip yürüme sayılır.
static func speed_for(tuning: PlayerTuning, mode: int) -> float:
	match mode:
		Mode.SNEAK:
			return tuning.sneak_speed
		Mode.SPRINT:
			return tuning.sprint_speed
	return tuning.walk_speed


## Bir fizik adımı sonundaki hız. Hedef = yön (uzunluğu en fazla 1: analog çubukta kısmi hız) × kip hızı;
## hedefe hızlanırken `acceleration`, yavaşlarken ve girdi yokken `deceleration` ile yaklaşılır.
static func step_velocity(current: Vector2, direction: Vector2, mode: int, tuning: PlayerTuning,
		delta: float) -> Vector2:
	var dir: Vector2 = direction.limit_length(1.0)
	if dir.length() < MOVE_EPSILON:
		return current.move_toward(Vector2.ZERO, tuning.deceleration * delta)
	var target: Vector2 = dir * speed_for(tuning, mode)
	var rate: float = tuning.acceleration if target.length() >= current.length() else tuning.deceleration
	return current.move_toward(target, rate * delta)


## Bakış yönü (birim vektör): girdi varsa onun yönü, yoksa önceki yön korunur.
static func facing_for(current: Vector2, direction: Vector2) -> Vector2:
	if direction.length() < MOVE_EPSILON:
		return current
	return direction.normalized()
