class_name BotTimeline
extends RefCounted
## Bot input timeline (S6; US-004 AC3). Steps follow `Args.load_bot` / `Args.parse_bot_step` (`t` float, `move` Vector2, `dur` float).
## `advance(delta)` moves time forward and applies due steps; `t` is seconds since game start (S6); other fields are ignored:
##   {"t": S, "move": [x, y]}               move direction (length <= 1) until the next move
##   {"t": S, "hold": "sprint", "dur": S}  action held over [t, t + dur); held forever without dur
##   {"t": S, "press": "intimidate"}        action is "just pressed" (and held) only in the step it is applied
##   {"t": S, "look": [x, y]}               look direction (world; US-011b) until the next look; [0, 0] releases it
##                                           (look then follows movement smoothly, like keyboard-only)

var _steps: Array[Dictionary] = []
var _next: int = 0
var _time: float = 0.0
var _move: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
## Action -> last moment it stays held (exclusive).
var _hold_until: Dictionary = {}
## Actions newly pressed in this step.
var _pressed: Dictionary = {}
var _last_frame: int = -1


## Parsed steps (`Args.parse_bot_step` output); sorted by `t`.
func _init(steps: Array[Dictionary] = []) -> void:
	_steps = steps.duplicate(true)
	_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


## From a bot file (S6); empty timeline if unreadable (Args prints the warning).
static func from_file(path: String) -> BotTimeline:
	return BotTimeline.new(Args.load_bot(path))


## From a raw step list (dictionaries decoded from JSON); malformed steps are skipped with a warning.
static func from_raw(raw_steps: Array) -> BotTimeline:
	var steps: Array[Dictionary] = []
	for item: Variant in raw_steps:
		var step: Dictionary = Args.parse_bot_step(item)
		if step.is_empty():
			push_warning("BotTimeline: bozuk bot adımı atlandı: %s" % str(item))
			continue
		steps.append(step)
	return BotTimeline.new(steps)


## Advances time by `delta` and applies due steps.
func advance(delta: float) -> void:
	_pressed.clear()
	_time += delta
	while _next < _steps.size() and float(_steps[_next]["t"]) <= _time:
		_apply(_steps[_next])
		_next += 1


## Advances only once per physics frame (the timeline is process-wide; on a level change the old and new local player may ask in the
## same frame).
func tick(frame: int, delta: float) -> void:
	if frame == _last_frame:
		return
	_last_frame = frame
	advance(delta)


func time() -> float:
	return _time


func step_count() -> int:
	return _steps.size()


## Whether all steps have been applied.
func is_finished() -> bool:
	return _next >= _steps.size()


func move_vector() -> Vector2:
	return _move


## Bot look direction (unit, or zero = no explicit look).
func look_vector() -> Vector2:
	return _look


func is_held(action: StringName) -> bool:
	return _pressed.has(action) or _time < float(_hold_until.get(action, -INF))


func is_just_pressed(action: StringName) -> bool:
	return _pressed.has(action)


func _apply(step: Dictionary) -> void:
	if step.has("move"):
		_move = (step["move"] as Vector2).limit_length(1.0)
	if step.has("look"):
		_look = parse_look(step["look"])
	if step.has("hold"):
		var duration: float = float(step["dur"]) if step.has("dur") else INF
		_hold_until[StringName(str(step["hold"]))] = float(step["t"]) + duration
	if step.has("press"):
		_pressed[StringName(str(step["press"]))] = true


## Value of a `"look"` step: [x, y] number pair (or Vector2) -> unit direction; zero/malformed -> ZERO (warning if malformed).
static func parse_look(value: Variant) -> Vector2:
	var v: Vector2 = Vector2.ZERO
	if value is Vector2:
		v = value
	elif value is Array and (value as Array).size() == 2:
		var pair: Array = value
		if not (_is_number(pair[0]) and _is_number(pair[1])):
			push_warning("BotTimeline: bozuk look adımı yok sayıldı: %s" % str(value))
			return Vector2.ZERO
		v = Vector2(float(pair[0]), float(pair[1]))
	else:
		push_warning("BotTimeline: bozuk look adımı yok sayıldı: %s" % str(value))
		return Vector2.ZERO
	return v.normalized() if v.length() > 0.0001 else Vector2.ZERO


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
