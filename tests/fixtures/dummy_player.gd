extends CharacterBody2D
## Test fixture player (US-001): for network tests only; the real player is under entities/player/ (US-004).
## Root CharacterBody2D + MultiplayerSynchronizer (`position`, 0.05 s). Authority is given to peer_id in Game's spawn_function;
## only the authoritative copy moves and plays the `--bot` timeline (S6):
## {"t": SEC, "move": [x, y]}  -> velocity = direction (length <= 1) x SPEED
## {"t": SEC, "game": "add_team_cash", "args": [100]}            (fixture only: Game call)
## {"t": SEC, "game": "raise_session_event", "args": ["police_called", {...}]}
## {"t": SEC, "game": "set_local_name", "args": ["name"]}
## {"t": SEC, "game": "start_level", "args": ["res://..."]}       (deferred; this node is removed too)
## `t` is the physics time since the first local player in the process spawned ("game start"); the timeline is process-wide
## (static); a player respawned on level change resumes where it left off. Other step kinds (hold/press) are ignored.

const SPEED := 100.0

static var _steps: Array[Dictionary] = []
static var _loaded: bool = false
static var _next: int = 0
static var _t: float = 0.0
static var _move: Vector2 = Vector2.ZERO
static var _last_frame: int = -1

var _local: bool = false


func _ready() -> void:
	_local = is_multiplayer_authority()
	if _local and not _loaded:
		_loaded = true
		_steps = Args.bot_steps()


func _physics_process(delta: float) -> void:
	if not _local:
		return
	var frame: int = Engine.get_physics_frames()
	if frame != _last_frame:  # so two local copies (old + new) in the same frame do not advance time twice
		_last_frame = frame
		_t += delta
		while _next < _steps.size() and float(_steps[_next]["t"]) <= _t:
			_apply(_steps[_next])
			_next += 1
	velocity = _move * SPEED
	move_and_slide()


static func _apply(step: Dictionary) -> void:
	if step.has("move"):
		_move = (step["move"] as Vector2).limit_length(1.0)
	if not step.has("game"):
		return
	var args: Array = step.get("args", []) if typeof(step.get("args")) == TYPE_ARRAY else []
	match str(step["game"]):
		"add_team_cash":
			if args.size() == 1 and typeof(args[0]) in [TYPE_INT, TYPE_FLOAT]:
				Game.add_team_cash(int(args[0]))
		"raise_session_event":
			if args.size() >= 1:
				var data: Dictionary = args[1] if args.size() > 1 and typeof(args[1]) == TYPE_DICTIONARY else {}
				Game.raise_session_event(StringName(str(args[0])), data)
		"set_local_name":
			if args.size() == 1:
				Game.set_local_name(str(args[0]))
		"start_level":
			if args.size() == 1:
				Game.start_level.call_deferred(str(args[0]))
		_:
			push_warning("dummy_player: bilinmeyen bot çağrısı: %s" % str(step["game"]))
