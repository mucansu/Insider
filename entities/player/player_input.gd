class_name PlayerInput
extends Node
## Player input abstraction (S5, S6; US-004 AC3). Player calls `poll(delta)` at the start of each physics step and reads only from here;
## player code never touches `Input` directly. Source is chosen in `_ready`: a remote copy (authority on another peer) reads no input;
## the local player uses the `--bot` timeline (S6) if given, else keyboard/gamepad (S5 actions, analog included). While an in-game menu is
## open (`UiInput.is_gameplay_input_blocked()`, S5; the only ui/ exception in §6) device input is not read and held actions count as
## released; bot input is unaffected. The `--bot` timeline is process-wide: a local player respawned on a level change continues where it
## left off ("game start" = first physics step of the first local player in the process).
## Look (US-011b AC3; GDD §6.5): `look_vector(origin)` is a world direction or ZERO (no explicit look -> the player turns smoothly toward
## movement, keyboard-only). On a device the last-used look device wins: mouse motion -> mouse (world direction from player to cursor),
## right stick (`look_*`, S5) outside the dead zone -> stick direction; releasing the stick means no explicit look. Bot: the timeline's
## `"look"` step (S6 addendum).

enum Source { NONE, DEVICE, BOT }

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
## Actions tracked for held / just pressed (S5).
const ACTIONS: Array[StringName] = [&"sprint", &"sneak", &"interact", &"intimidate"]
const LOOK_LEFT := &"look_left"
const LOOK_RIGHT := &"look_right"
const LOOK_UP := &"look_up"
const LOOK_DOWN := &"look_down"
## Last-used look device.
enum LookDevice { NONE, MOUSE, STICK }

## Process-wide timeline of the `--bot` file (loaded on the first local player).
static var _process_bot: BotTimeline = null

var _source: Source = Source.NONE
var _bot: BotTimeline = null
var _move: Vector2 = Vector2.ZERO
var _held: Dictionary = {}
var _just_pressed: Dictionary = {}
var _look: Vector2 = Vector2.ZERO
var _look_device: LookDevice = LookDevice.NONE


func _ready() -> void:
	if not is_multiplayer_authority():
		use_none()
	elif not Args.bot_path.is_empty():
		if _process_bot == null:
			_process_bot = BotTimeline.from_file(Args.bot_path)
		use_bot(_process_bot)
	else:
		use_device()


func source() -> Source:
	return _source


## Keyboard/gamepad (S5).
func use_device() -> void:
	_set_source(Source.DEVICE, null)


## Given timeline (S6); tests may supply their own.
func use_bot(timeline: BotTimeline) -> void:
	_set_source(Source.BOT if timeline != null else Source.NONE, timeline)


## No input (remote copy).
func use_none() -> void:
	_set_source(Source.NONE, null)


## Reads this step's input; Player calls it once at the start of each physics step.
func poll(delta: float) -> void:
	_move = Vector2.ZERO
	_look = Vector2.ZERO
	_held.clear()
	_just_pressed.clear()
	match _source:
		Source.BOT:
			_bot.tick(Engine.get_physics_frames(), delta)
			_move = _bot.move_vector()
			_look = _bot.look_vector()
			for action: StringName in ACTIONS:
				_held[action] = _bot.is_held(action)
				_just_pressed[action] = _bot.is_just_pressed(action)
		Source.DEVICE:
			if UiInput.is_gameplay_input_blocked():
				return
			_move = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN)
			var stick: Vector2 = Input.get_vector(LOOK_LEFT, LOOK_RIGHT, LOOK_UP, LOOK_DOWN)
			if stick.length() >= LookRules.INPUT_EPSILON:
				_look_device = LookDevice.STICK
				_look = stick.normalized()
			for action: StringName in ACTIONS:
				_held[action] = Input.is_action_pressed(action)
				_just_pressed[action] = Input.is_action_just_pressed(action)


## Movement direction; length <= 1 (partial on an analog stick).
func move_vector() -> Vector2:
	return _move


## Explicit look direction this step (world, unit) or ZERO. `origin`: player's world position (mouse look aims from there to the cursor).
func look_vector(origin: Vector2) -> Vector2:
	var mouse: bool = _source == Source.DEVICE and _look_device == LookDevice.MOUSE and is_inside_tree()
	if mouse and not UiInput.is_gameplay_input_blocked():
		var viewport: Viewport = get_viewport()
		var world: Vector2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
		var toward: Vector2 = world - origin
		return toward.normalized() if toward.length() >= 1.0 else Vector2.ZERO
	return _look


func look_device() -> LookDevice:
	return _look_device


func is_held(action: StringName) -> bool:
	return bool(_held.get(action, false))


func is_just_pressed(action: StringName) -> bool:
	return bool(_just_pressed.get(action, false))


func _input(event: InputEvent) -> void:
	if _source == Source.DEVICE and event is InputEventMouseMotion:
		_look_device = LookDevice.MOUSE


func _set_source(value: Source, timeline: BotTimeline) -> void:
	_source = value
	_bot = timeline
	_move = Vector2.ZERO
	_look = Vector2.ZERO
	_look_device = LookDevice.NONE
	_held.clear()
	_just_pressed.clear()
