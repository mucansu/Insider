class_name PuppetEyes
extends RefCounted
## Kuklanın gözleri (US-014; GDD §14.1): gidilen yöne bakış, beklerken bakınma (etrafa ve ekip arkadaşına;
## %35 yeniden ileri), göz kırpma, şaşkınlıkta büyüme (fark edilince). Düğümsüz; PuppetRig her sabit adımda
## çağırır. Sapmalar kukla birimidir.

enum Look { FORWARD, ANGLE, FRIEND }

## Bakış sapması (birim), sızarken büyüme; yaylar (Hz, sönüm).
const RANGE := Vector2(3.3, 1.6)
const SNEAK_FACTOR := 1.15
const FREQUENCY := 6.0
const DAMPING := 0.7
const SIZE_FREQUENCY := 5.0
const SIZE_DAMPING := 0.35
## Arkadaş bu uzaklıktan (px²) yakınsa yönü belirsiz sayılır.
const FRIEND_MIN_DISTANCE_SQ := 1.0
## İlk kırpma ve bakınma zamanlayıcısı aralığı (sn).
const FIRST_BLINK := Vector2(1.0, 4.0)
const FIRST_LOOK := Vector2(1.0, 3.0)

var tuning: PuppetTuning = null
var x: PuppetSpring = PuppetSpring.new(0.0)
var y: PuppetSpring = PuppetSpring.new(0.0)
var size: PuppetSpring = PuppetSpring.new(1.0)
## Kalan kırpma süresi (sn); > 0 iken göz kapalı.
var blink: float = 0.0

var _rng: RandomNumberGenerator = null
var _blink_timer: float = 0.0
var _look_timer: float = 0.0
var _look: Look = Look.FORWARD
var _look_angle: float = 0.0


func _init(values: PuppetTuning, rng: RandomNumberGenerator) -> void:
	tuning = values
	_rng = rng
	_blink_timer = _rng.randf_range(FIRST_BLINK.x, FIRST_BLINK.y)
	_look_timer = _rng.randf_range(FIRST_LOOK.x, FIRST_LOOK.y)


func offset() -> Vector2:
	return Vector2(x.x, y.x)


func is_blinking() -> bool:
	return blink > 0.0


## Bakış yönüne hızsız oturur.
func settle(face: float) -> void:
	x.settle(cos(face) * RANGE.x)
	y.settle(sin(face) * RANGE.y)
	size.settle(1.0)
	_look = Look.FORWARD


## Göz büyümesi (yay hızına darbe).
func widen(impulse: float) -> void:
	size.v += impulse


## `idle`: beklerken bakınır; `from`/`friend`: dünya px (arkadaş yoksa has_friend false).
func step(h: float, face: float, idle: bool, sneaking: bool, from: Vector2, friend: Vector2,
		has_friend: bool) -> void:
	var look: float = face
	if idle:
		_look_timer -= h
		if _look_timer <= 0.0:
			_pick(face, has_friend)
		if _look == Look.ANGLE:
			look = _look_angle
		elif _look == Look.FRIEND and has_friend and friend.distance_squared_to(from) > FRIEND_MIN_DISTANCE_SQ:
			look = (friend - from).angle()
	else:
		_look = Look.FORWARD
	var mag: float = SNEAK_FACTOR if sneaking else 1.0
	x.step(cos(look) * RANGE.x * mag, FREQUENCY, DAMPING, h)
	y.step(sin(look) * RANGE.y * mag, FREQUENCY, DAMPING, h)
	size.step(1.0, SIZE_FREQUENCY, SIZE_DAMPING, h)
	_blink_timer -= h
	if _blink_timer <= 0.0:
		blink = tuning.blink_duration
		_blink_timer = _rng.randf_range(tuning.blink_interval.x, tuning.blink_interval.y)
	if blink > 0.0:
		blink -= h


func _pick(face: float, has_friend: bool) -> void:
	_look_timer = _rng.randf_range(tuning.look_interval.x, tuning.look_interval.y)
	var roll: float = _rng.randf()
	if roll < tuning.look_forward_chance:
		_look = Look.FORWARD
	elif has_friend and roll < tuning.look_forward_chance + tuning.look_friend_chance:
		_look = Look.FRIEND
	else:
		_look = Look.ANGLE
		_look_angle = face + _rng.randf_range(-tuning.look_range, tuning.look_range)
