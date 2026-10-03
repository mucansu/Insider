class_name Agenda
extends Node
## Ajanda bileşeni (US-008 AC1/AC2; GDD §9.2-9.3, mimari.md S11): NPC'nin görev listesi ({işaret, süre aralığı,
## bakış yönü, koni daralması}; `AgendaTask`) tohumlu RNG ile sıralanır: ev görevi (tezgâh) ↔ diğer görevlerden
## biri (aynı pencere görevi art arda gelmez). Görev süresi NPC işarete vardıktan sonra sayılır. Yalnız host'ta
## anlamlıdır; beyin her adımda `step()` çağırır ve hedef konum/yön/koniyi buradan okur. Ağ yok, düğüm yok.
##
## Kesmeler (kesme/geri alma API'si): `interrupt(kind, …)` süren görevi duraklatır (kalan süresi korunur),
## kesme bitince ya da `cancel_interrupt()` ile görev kaldığı yerden sürer. Öncelik (Karar ön önerisi):
## GÖNDERİLDİ > MÜŞTERİ > DİNLE > ZİL; düşük öncelikli kesme yüksek olanı kesmez, eşit olan yeniler. Kapı zili
## `bell_interrupts = false` görevi (telefon) kesmez.
## Belirlenimcilik (I6): aynı görev listesi + tohum + aynı varış anları → aynı görev dizisi (`sequence`).

signal task_changed(task_name: StringName)

enum Interrupt { NONE, BELL, LISTEN, CUSTOMER, SENT }

const INTERRUPT_NAMES: Array[StringName] = [&"", &"bell", &"listen", &"customer", &"sent"]
## `sequence` geçmişinde tutulan en fazla görev adı.
const MAX_SEQUENCE := 512

## Geçilen görev adları (kesmeler dahil; en fazla MAX_SEQUENCE).
var sequence: Array[StringName] = []

var _tasks: Array[AgendaTask] = []
## func(marker: StringName) -> Array[Vector2]: işaret ya da dizi konumları (global).
var _resolver: Callable = Callable()
var _rng := RandomNumberGenerator.new()
var _task: AgendaTask = null
var _spot: Vector2 = Vector2.INF
var _time_left: float = 0.0
var _arrived: bool = false
var _last_away: AgendaTask = null

var _interrupt: Interrupt = Interrupt.NONE
var _int_left: float = 0.0
var _int_spot: Vector2 = Vector2.INF
var _int_look: Vector2 = Vector2.INF
var _int_on_arrival: bool = false
var _int_arrived: bool = false
## Ajanda sesi (US-011b): o anki görevin temposu (görev değişince yeniden kurulur).
var _noise_task: AgendaTask = null
var _noise_cadence: NoiseRules.Cadence = null


## Listeyi ve tohumu kurar, ev görevinden başlar. `resolver`: func(marker) -> Array[Vector2].
func setup(tasks: Array[AgendaTask], agenda_seed: int, resolver: Callable) -> void:
	_tasks = tasks.duplicate()
	_resolver = resolver
	_rng.seed = agenda_seed
	_last_away = null
	_interrupt = Interrupt.NONE
	sequence.clear()
	_begin(_home())


## Bir adım: `at_goal` = NPC hedefe vardı (ya da gidemiyor: beyin donmasın diye vardı sayar, I7).
func step(delta: float, at_goal: bool) -> void:
	var dt: float = maxf(delta, 0.0)
	if _interrupt != Interrupt.NONE:
		if at_goal:
			_int_arrived = true
		if not _int_on_arrival or _int_arrived:
			_int_left -= dt
		if _int_left <= 0.0:
			_end_interrupt()
		return
	if _task == null:
		return
	if at_goal:
		_arrived = true
	if _arrived:
		_time_left -= dt
		if _time_left <= 0.0:
			_begin(_next())


## Bu adımda çıkan ajanda sesi (US-011b; görev noktasına varılmış, kesme yok, görevde `noise_kind` varsa
## `noise_interval_sec` aralıkla; ilk ses varıştan bir aralık sonra). Ses yoksa boş. `step`ten sonra çağrılır.
func take_noise(delta: float) -> StringName:
	var task: AgendaTask = _task if _interrupt == Interrupt.NONE and _arrived else null
	var active: bool = task != null and not task.noise_kind.is_empty() and task.noise_interval_sec > 0.0
	if active and task != _noise_task:
		_noise_task = task
		_noise_cadence = NoiseRules.Cadence.new(task.noise_interval_sec, task.noise_interval_sec)
	if _noise_cadence == null:
		return &""
	if not _noise_cadence.tick(maxf(delta, 0.0), active):
		return &""
	return _noise_task.noise_kind


## Şu an gidilecek konum (global); INF = olduğu yerde dur.
func goal_position() -> Vector2:
	if _interrupt != Interrupt.NONE:
		return _int_spot
	return _spot


## Varınca bakılacak yön (`from` NPC konumu): kesmede bakılan nokta, görevde görevin yönü; sıfır = koru.
func goal_facing(from: Vector2) -> Vector2:
	if _interrupt != Interrupt.NONE:
		if _int_look.is_finite() and not from.is_equal_approx(_int_look):
			return (_int_look - from).normalized()
		return Vector2.ZERO
	return _task.facing.normalized() if _task != null else Vector2.ZERO


## Koni yarım açısı (derece); 0 = NPC'nin varsayılanı.
func half_angle_deg() -> float:
	if _interrupt != Interrupt.NONE or _task == null:
		return 0.0
	return _task.half_angle_deg


## Şimdiki görevin (kesme varsa kesmenin) adı.
func task_name() -> StringName:
	if _interrupt != Interrupt.NONE:
		return INTERRUPT_NAMES[_interrupt]
	return _task.name if _task != null else &""


func current_task() -> AgendaTask:
	return _task


func current_interrupt() -> Interrupt:
	return _interrupt


## Görev ya da kesme süresinden kalan (sn; varılmadıysa tam süre).
func time_left() -> float:
	return _int_left if _interrupt != Interrupt.NONE else _time_left


## Kesme: `duration` sn; `spot` gidilecek nokta (INF = dur), `look_at` bakılacak nokta (INF = yok);
## `count_on_arrival` ise süre varınca başlar. Kabul edilmezse (öncelik, zil kesmeyen görev) false.
func interrupt(kind: Interrupt, duration: float, spot: Vector2 = Vector2.INF, look_at: Vector2 = Vector2.INF,
		count_on_arrival: bool = false) -> bool:
	if kind == Interrupt.NONE or kind < _interrupt:
		return false
	if kind == Interrupt.BELL and _interrupt == Interrupt.NONE and _task != null and not _task.bell_interrupts:
		return false
	var before: StringName = task_name()
	_interrupt = kind
	_int_left = maxf(duration, 0.0)
	_int_spot = spot
	_int_look = look_at
	_int_on_arrival = count_on_arrival
	_int_arrived = false
	_note(before)
	return true


## Süren kesmeyi bırakır; görev kaldığı yerden sürer.
func cancel_interrupt() -> void:
	if _interrupt != Interrupt.NONE:
		_end_interrupt()


## Ajandayı ev görevinden yeniden başlatır (alarm sonrası dönüş); tohum dizisi sürer.
func restart_home() -> void:
	_interrupt = Interrupt.NONE
	_begin(_home())


func _end_interrupt() -> void:
	var before: StringName = task_name()
	_interrupt = Interrupt.NONE
	_int_left = 0.0
	_int_spot = Vector2.INF
	_int_look = Vector2.INF
	_arrived = false  # görev noktasına geri yürür; kalan süre korunur
	_note(before)


func _begin(task: AgendaTask) -> void:
	var before: StringName = task_name()
	_task = task
	_arrived = false
	_spot = Vector2.INF
	_time_left = 0.0
	if task == null:
		_note(before)
		return
	var spots: Array[Vector2] = _spots_for(task.marker)
	if not spots.is_empty():
		_spot = spots[_rng.randi_range(0, spots.size() - 1)] if spots.size() > 1 else spots[0]
	_time_left = _rng.randf_range(minf(task.min_sec, task.max_sec), maxf(task.min_sec, task.max_sec))
	if not task.home:
		_last_away = task
	_note(before, true)


func _note(before: StringName, force: bool = false) -> void:
	var now: StringName = task_name()
	if now == before and not force:
		return
	sequence.append(now)
	if sequence.size() > MAX_SEQUENCE:
		sequence.pop_front()
	task_changed.emit(now)


func _next() -> AgendaTask:
	if _task != null and not _task.home:
		return _home()
	var away: Array[AgendaTask] = []
	for t: AgendaTask in _tasks:
		if t != null and not t.home and (t != _last_away or _away_count() == 1):
			away.append(t)
	if away.is_empty():
		return _home()
	return away[_rng.randi_range(0, away.size() - 1)]


func _home() -> AgendaTask:
	for t: AgendaTask in _tasks:
		if t != null and t.home:
			return t
	return _tasks[0] if not _tasks.is_empty() else null


func _away_count() -> int:
	var n: int = 0
	for t: AgendaTask in _tasks:
		if t != null and not t.home:
			n += 1
	return n


func _spots_for(marker: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not _resolver.is_valid() or marker.is_empty():
		return out
	var got: Variant = _resolver.call(marker)
	if got is Array:
		for v: Variant in got:
			if v is Vector2:
				out.append(v)
	return out
