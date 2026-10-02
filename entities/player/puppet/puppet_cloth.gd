class_name PuppetCloth
extends RefCounted
## Kuklanın ikincil hareketi (US-014; GDD §14.1): atkı verlet zinciri ve koşu adımı tozu. Düğümsüz; noktalar
## dünya px'inde tutulur (oyuncu yürüdükçe atkı arkada savrulur, toz yerde kalır). PuppetRig her sabit adımda
## çağırır; atkı bağlantısını ve ölçeği o verir.

const SCARF_ITERATIONS := 4
## En kısa kısıt uzunluğu (sıfıra bölmeyi önler).
const MIN_DISTANCE := 0.0001
## Toz (kukla birimi): çıkış noktası (bakışın tersine), dağılma, hız, yükselme, yarıçap; sürüklenme (adım başına).
const DUST_BEHIND := 5.0
const DUST_DEPTH := 2.5
const DUST_SCATTER := Vector2(2.5, 1.0)
const DUST_SPEED := Vector2(10.0, 25.0)
const DUST_SPEED_SCATTER := 7.5
const DUST_RISE := Vector2(6.0, 5.0)
const DUST_RADIUS := Vector2(1.5, 3.0)
const DUST_DRAG := 0.96


## Toz parçacığı (dünya px).
class Dust extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var life: float = 0.0
	var max_life: float = 1.0


var _scarf: PackedVector2Array = []
var _scarf_prev: PackedVector2Array = []
var _dust: Array[Dust] = []


## Atkı noktaları (dünya px; ilk nokta bağlantı). Atkı yoksa boş.
func scarf_points() -> PackedVector2Array:
	return _scarf


func dust_particles() -> Array[Dust]:
	return _dust


func clear_dust() -> void:
	_dust.clear()


## Atkıyı bağlantıdan dümdüz aşağı, hızsız asar (`segments` 0 = atkı yok).
func reset_scarf(anchor: Vector2, segments: int, segment_px: float) -> void:
	_scarf.clear()
	_scarf_prev.clear()
	for i: int in segments:
		var p: Vector2 = anchor + Vector2(0.0, segment_px * i)
		_scarf.append(p)
		_scarf_prev.append(p)


## Bir verlet adımı: sönümlü atalet + yerçekimi düşüşü (`fall` px), sonra parça boyu kısıtları.
func step_scarf(anchor: Vector2, segments: int, segment_px: float, damping: float, fall: float) -> void:
	if _scarf.size() != segments:
		reset_scarf(anchor, segments, segment_px)
	if _scarf.is_empty():
		return
	_scarf[0] = anchor
	_scarf_prev[0] = anchor
	for i: int in range(1, _scarf.size()):
		var p: Vector2 = _scarf[i]
		var moved: Vector2 = (p - _scarf_prev[i]) * damping
		_scarf_prev[i] = p
		_scarf[i] = p + moved + Vector2(0.0, fall)
	for it: int in SCARF_ITERATIONS:
		for i: int in range(1, _scarf.size()):
			var a: Vector2 = _scarf[i - 1]
			var b: Vector2 = _scarf[i]
			var d: Vector2 = b - a
			var dist: float = maxf(d.length(), MIN_DISTANCE)
			var diff: Vector2 = d * ((dist - segment_px) / dist)
			if i == 1:
				_scarf[i] = b - diff
			else:
				_scarf[i - 1] = a + diff * 0.5
				_scarf[i] = b - diff * 0.5
		_scarf[0] = anchor


## Koşu adımında ayak arkasından toz (`facing` birim bakış yönü, `scale` kukla ölçeği).
func emit_dust(origin: Vector2, facing: Vector2, count: int, life: Vector2, scale: float,
		rng: RandomNumberGenerator) -> void:
	for i: int in count:
		var d := Dust.new()
		d.position = origin + Vector2(-facing.x * DUST_BEHIND + rng.randf_range(-1.0, 1.0) * DUST_SCATTER.x,
			-facing.y * DUST_DEPTH + rng.randf_range(-1.0, 1.0) * DUST_SCATTER.y) * scale
		d.velocity = Vector2(
			-facing.x * rng.randf_range(DUST_SPEED.x, DUST_SPEED.y) + rng.randf_range(-1.0, 1.0) * DUST_SPEED_SCATTER,
			-facing.y * DUST_RISE.x - rng.randf() * DUST_RISE.y) * scale
		d.radius = rng.randf_range(DUST_RADIUS.x, DUST_RADIUS.y) * scale
		d.max_life = rng.randf_range(life.x, life.y)
		_dust.append(d)


func step_dust(h: float) -> void:
	for i: int in range(_dust.size() - 1, -1, -1):
		var d: Dust = _dust[i]
		d.life += h
		d.position += d.velocity * h
		d.velocity *= DUST_DRAG
		if d.life > d.max_life:
			_dust.remove_at(i)
