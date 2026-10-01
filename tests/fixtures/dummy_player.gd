extends CharacterBody2D
## Test fikstürü oyuncu (US-001): yalnız ağ testleri için; gerçek oyuncu entities/player/ altında (US-004).
## Kök CharacterBody2D + MultiplayerSynchronizer (`position`, 0,05 sn). Yetki Game'in spawn_function'ında
## peer_id'ye verilir; yalnız yetkili kopya hareket eder ve `--bot` zaman çizelgesini (S6) oynatır:
##   {"t": SN, "move": [x, y]}  -> hız = yön (uzunluk ≤ 1) × SPEED
##   {"t": SN, "game": "add_team_cash", "args": [100]}            (yalnız fikstür: Game çağrısı)
##   {"t": SN, "game": "raise_session_event", "args": ["police_called", {...}]}
##   {"t": SN, "game": "set_local_name", "args": ["ad"]}
##   {"t": SN, "game": "start_level", "args": ["res://..."]}       (ertelenmiş; bu düğüm de kaldırılır)
## `t` süreçteki ilk yerel oyuncunun doğuşundan beri geçen fizik süresidir ("oyun başlangıcı"); zaman çizelgesi
## süreç genelidir (static), seviye değişiminde yeniden doğan oyuncu kaldığı yerden sürdürür.
## Diğer adım türleri (hold/press) yok sayılır.

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
	if frame != _last_frame:  # aynı karede iki yerel kopya (eski + yeni) zamanı iki kez ilerletmesin
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
