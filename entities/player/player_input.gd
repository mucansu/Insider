class_name PlayerInput
extends Node
## Oyuncu girdisi soyutlaması (mimari.md S5, S6; US-004 AC3). Player her fizik adımının başında `poll(delta)`
## çağırır, sonra yalnız buradan okur; oyuncu kodu `Input`'a doğrudan dokunmaz.
## Kaynak `_ready`'de seçilir: uzak kopyada (yetki başka peer'da) girdi okunmaz; yerel oyuncuda `--bot`
## verildiyse bot zaman çizelgesi (S6), yoksa klavye/gamepad (S5 eylemleri, analog dahil).
## Oyun içi menü açıkken (`UiInput.is_gameplay_input_blocked()`, S5; §6'daki tek ui/ istisnası) cihaz girdisi
## okunmaz, basılı eylemler bırakılmış sayılır; bot girdisi bundan etkilenmez.
## `--bot` zaman çizelgesi süreç genelidir: seviye değişiminde yeniden doğan yerel oyuncu kaldığı yerden sürdürür
## ("oyun başlangıcı" = süreçteki ilk yerel oyuncunun ilk fizik adımı).

enum Source { NONE, DEVICE, BOT }

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
## Basılı / yeni basıldı durumu izlenen eylemler (S5).
const ACTIONS: Array[StringName] = [&"sprint", &"sneak", &"interact", &"intimidate"]

## `--bot` dosyasının süreç geneli zaman çizelgesi (ilk yerel oyuncuda yüklenir).
static var _process_bot: BotTimeline = null

var _source: Source = Source.NONE
var _bot: BotTimeline = null
var _move: Vector2 = Vector2.ZERO
var _held: Dictionary = {}
var _just_pressed: Dictionary = {}


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


## Klavye/gamepad (S5).
func use_device() -> void:
	_set_source(Source.DEVICE, null)


## Verilen zaman çizelgesi (S6); testler kendi çizelgesini verebilir.
func use_bot(timeline: BotTimeline) -> void:
	_set_source(Source.BOT if timeline != null else Source.NONE, timeline)


## Girdi yok (uzak kopya).
func use_none() -> void:
	_set_source(Source.NONE, null)


## Bu adımın girdisini okur; Player her fizik adımının başında bir kez çağırır.
func poll(delta: float) -> void:
	_move = Vector2.ZERO
	_held.clear()
	_just_pressed.clear()
	match _source:
		Source.BOT:
			_bot.tick(Engine.get_physics_frames(), delta)
			_move = _bot.move_vector()
			for action: StringName in ACTIONS:
				_held[action] = _bot.is_held(action)
				_just_pressed[action] = _bot.is_just_pressed(action)
		Source.DEVICE:
			if UiInput.is_gameplay_input_blocked():
				return
			_move = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN)
			for action: StringName in ACTIONS:
				_held[action] = Input.is_action_pressed(action)
				_just_pressed[action] = Input.is_action_just_pressed(action)


## Hareket yönü; uzunluğu en fazla 1 (analog çubukta kısmi).
func move_vector() -> Vector2:
	return _move


func is_held(action: StringName) -> bool:
	return bool(_held.get(action, false))


func is_just_pressed(action: StringName) -> bool:
	return bool(_just_pressed.get(action, false))


func _set_source(value: Source, timeline: BotTimeline) -> void:
	_source = value
	_bot = timeline
	_move = Vector2.ZERO
	_held.clear()
	_just_pressed.clear()
