class_name PuppetEyes
extends RefCounted
## Puppet eyes (US-014; GDD §14.1): look toward travel, idle glances (around and at a teammate; 35% back to forward), blinking, growing
## when startled (on notice). Node-free; PuppetRig calls it each fixed step. Offsets are in puppet units.

enum Look { FORWARD, ANGLE, FRIEND }

## Look offset (units), growth when sneaking; springs (Hz, damping).
const RANGE := Vector2(3.3, 1.6)
const SNEAK_FACTOR := 1.15
const FREQUENCY := 6.0
const DAMPING := 0.7
const SIZE_FREQUENCY := 5.0
const SIZE_DAMPING := 0.35
## Teammate closer than this (px^2): direction counts as undefined.
const FRIEND_MIN_DISTANCE_SQ := 1.0
## Interval of the first blink and glance timers (s).
const FIRST_BLINK := Vector2(1.0, 4.0)
const FIRST_LOOK := Vector2(1.0, 3.0)

var tuning: PuppetTuning = null
var x: PuppetSpring = PuppetSpring.new(0.0)
var y: PuppetSpring = PuppetSpring.new(0.0)
var size: PuppetSpring = PuppetSpring.new(1.0)
## Remaining blink time (s); eye closed while > 0.
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


## Settles on the look direction with no velocity.
func settle(face: float) -> void:
	x.settle(cos(face) * RANGE.x)
	y.settle(sin(face) * RANGE.y)
	size.settle(1.0)
	_look = Look.FORWARD


## Eye growth (impulse to the spring velocity).
func widen(impulse: float) -> void:
	size.v += impulse


## `idle`: glances around when waiting; `from`/`friend`: world px (has_friend false if no teammate).
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
