class_name BotTimeline
extends RefCounted
## Bot girdisi zaman çizelgesi (mimari.md S6; US-004 AC3). Adımlar `Args.load_bot` / `Args.parse_bot_step`
## biçimindedir (`t` float, `move` Vector2, `dur` float). `advance(delta)` zamanı ilerletir ve vakti gelen
## adımları uygular:
##   {"t": SN, "move": [x, y]}                 hareket yönü (uzunluğu en fazla 1) bir sonraki move'a kadar
##   {"t": SN, "hold": "sprint", "dur": SN}    eylem [t, t + dur) aralığında basılı; dur yoksa hep basılı
##   {"t": SN, "press": "intimidate"}          eylem yalnız uygulandığı adımda "yeni basıldı" (ve basılı)
##   {"t": SN, "look": [x, y]}                 bakış yönü (dünya yönü; US-011b) bir sonraki look'a kadar; [0, 0]
##                                             bırakır (bakış hareket yönünü yumuşak izler, klavye-yalnız gibi)
## `t` oyun başlangıcından beri geçen süredir (S6). Diğer alanlar (fikstür oyuncunun "game" çağrıları gibi)
## yok sayılır.

var _steps: Array[Dictionary] = []
var _next: int = 0
var _time: float = 0.0
var _move: Vector2 = Vector2.ZERO
var _look: Vector2 = Vector2.ZERO
## Eylem -> basılı kalacağı son an (hariç).
var _hold_until: Dictionary = {}
## Bu adımda yeni basılan eylemler.
var _pressed: Dictionary = {}
var _last_frame: int = -1


## Ayrıştırılmış adımlar (`Args.parse_bot_step` çıktısı); `t`'ye göre sıralanır.
func _init(steps: Array[Dictionary] = []) -> void:
	_steps = steps.duplicate(true)
	_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


## Bot dosyasından (S6); okunamazsa boş zaman çizelgesi (uyarıyı Args basar).
static func from_file(path: String) -> BotTimeline:
	return BotTimeline.new(Args.load_bot(path))


## Ham adım listesinden (JSON'dan çözülmüş sözlükler); bozuk adımlar uyarıyla atlanır.
static func from_raw(raw_steps: Array) -> BotTimeline:
	var steps: Array[Dictionary] = []
	for item: Variant in raw_steps:
		var step: Dictionary = Args.parse_bot_step(item)
		if step.is_empty():
			push_warning("BotTimeline: bozuk bot adımı atlandı: %s" % str(item))
			continue
		steps.append(step)
	return BotTimeline.new(steps)


## Zamanı `delta` kadar ilerletir ve vakti gelen adımları uygular.
func advance(delta: float) -> void:
	_pressed.clear()
	_time += delta
	while _next < _steps.size() and float(_steps[_next]["t"]) <= _time:
		_apply(_steps[_next])
		_next += 1


## Aynı fizik karesinde yalnız bir kez ilerler (zaman çizelgesi süreç geneli paylaşılır; seviye değişiminde
## eski ve yeni yerel oyuncu aynı karede sorabilir).
func tick(frame: int, delta: float) -> void:
	if frame == _last_frame:
		return
	_last_frame = frame
	advance(delta)


func time() -> float:
	return _time


func step_count() -> int:
	return _steps.size()


## Bütün adımlar uygulandı mı.
func is_finished() -> bool:
	return _next >= _steps.size()


func move_vector() -> Vector2:
	return _move


## Bot bakış yönü (birim ya da sıfır = açık bakış yok).
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


## `"look"` adımının değeri: [x, y] sayı çifti (ya da Vector2) → birim yön; sıfır/bozuk → ZERO (bozuksa uyarı).
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
