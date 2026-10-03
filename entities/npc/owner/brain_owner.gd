class_name OwnerBrain
extends Node
## Bakkal sahibinin beyni, üst katman (US-008 AC1/AC4/AC5/AC8; GDD §9.3; mimari.md S2, S11). Yalnız host'ta işler;
## StoreOwner (kök) her fizik adımında `step(delta)` çağırır, dönen hızı uygular. Kurallar core'da
## (`CivilianRules`, `Fsm`). HFSM-lite: bu sınıf AJANDA katmanını (Agenda bileşeni: tezgâh/raf/arka oda/telefon +
## kesmeler zil/müşteri/gönderildi/dinle) ve katman seçimini işletir; tepki durumları (LOOK → QUESTION → SHOUT →
## CHASE → HOLD → STAGGER / SEARCH) `OwnerReaction`'dadır. Tespit (100) her sakin durumdan bağırışa geçirir
## (`owner_shout` + gürültü 320 px, tespit kilidi); alarmdayken her 5 sn bağırış gürültüsü yinelenir.
## Adalet (AC8, S2): aleyhte kararlar (şüphe, temas) eşitleyicinin en güncel konumuyla; lehte 0,2 sn pay ve koni
## histerezisi algı bileşeninde. Döküm `detections` (muhafiz-davranisi §4 alanları + behaviour).
## Bileşen alanları (`body`, `perception` …) yalnız tepki katmanı ve testler için okunur; beyin dışında yazılmaz.

## Yalnız host: ilk bağırış ya da yeniden bağırış (uyarı yöneticisi komşu üretir).
signal shouted(recheck: bool)

enum State { AGENDA, LOOK, QUESTION, SHOUT, CHASE, HOLD, STAGGER, SEARCH }

const STATE_NAMES: Array[StringName] = [&"agenda", &"look", &"question", &"shout", &"chase", &"hold",
	&"stagger", &"search"]
## Beynin izinli geçişleri (I3/I7 testleri bu tabloya dayanır).
const EDGES := {
	State.AGENDA: [State.LOOK, State.SHOUT],
	State.LOOK: [State.AGENDA, State.QUESTION, State.SHOUT],
	State.QUESTION: [State.AGENDA, State.SHOUT],
	State.SHOUT: [State.CHASE],
	State.CHASE: [State.HOLD, State.SEARCH],
	State.HOLD: [State.CHASE, State.STAGGER],
	State.STAGGER: [State.CHASE, State.SEARCH],
	State.SEARCH: [State.CHASE, State.AGENDA],
}
const ALARM_STATES: Array[int] = [State.SHOUT, State.CHASE, State.HOLD, State.STAGGER, State.SEARCH]
const CALM_STATES: Array[int] = [State.AGENDA, State.LOOK, State.QUESTION]
## Ajanda noktasına varış payı (px) ve bağırış gürültü türü (S8).
const STAND_PX := 6.0
const SHOUT_KIND := &"shout"
const MAX_DETECTIONS := 64
## Sahibin kendi çıkardığı sesler: işitmesi bunlara tepki vermez (bağırış; US-011b ajanda sesleri).
const OWN_NOISE_KINDS: Array[StringName] = [SHOUT_KIND, NoiseProfile.KIND_PHONE, NoiseProfile.KIND_SHELF,
	NoiseProfile.KIND_BELL]

var owner_tuning: OwnerTuning
var civilian_tuning: CivilianTuning
## Ajanda tohumu (StoreOwner.agenda_seed() verir; I6).
var agenda_seed: int = 0
var fsm := Fsm.new(State.AGENDA, EDGES)
## Süren hedef (peer; 0 = yok).
var target: int = 0
## Kayıtlar (döküm, testler).
var detections: Array[Dictionary] = []
var rescues: Array[Dictionary] = []
## peer -> en yüksek şüphe (döküm "peak").
var peaks: Dictionary = {}
## Yayılan bağırış gürültüsü sayısı (ilk + her 5 sn yineleme; döküm/test).
var shout_noises: int = 0
## Yayılan ajanda sesleri (US-011b; tür -> sayı): telefon, raf düzeltme, kapı zili.
var agenda_noises: Dictionary = {}

## Bileşenler (setup bağlar; okunur).
var body: CharacterBody2D = null
var perception: Perception = null
var suspicion: Suspicion = null
var agenda: Agenda = null
var mover: NpcMover = null
var senses: CivilianSenses = null

var _reaction: OwnerReaction = null
var _shout_left: float = 0.0
var _recheck_left: float = -1.0
var _recheck_used: bool = false
var _notice_at: Dictionary = {}


## Bileşenleri bağlar (StoreOwner `_ready`'de, host'ta).
func setup(owner_body: CharacterBody2D, owner_perception: Perception, owner_suspicion: Suspicion,
		owner_agenda: Agenda, owner_mover: NpcMover, owner_senses: CivilianSenses) -> void:
	body = owner_body
	perception = owner_perception
	suspicion = owner_suspicion
	agenda = owner_agenda
	mover = owner_mover
	senses = owner_senses
	_reaction = OwnerReaction.new(self)
	perception.set_cone(civilian_tuning.half_angle_deg, civilian_tuning.view_range)
	perception.set_hysteresis(civilian_tuning.hysteresis_angle_deg, civilian_tuning.hysteresis_range)
	perception.factor_query = senses.factor_for
	suspicion.innocent_decay_per_sec = civilian_tuning.innocent_decay_per_sec
	suspicion.threshold_reached.connect(_on_threshold)
	agenda.setup(owner_tuning.tasks, agenda_seed, senses.marker_positions)
	senses.door_crossed.connect(_on_door_crossed)


func state() -> int:
	return fsm.state


func state_name() -> StringName:
	return STATE_NAMES[fsm.state]


func is_alarmed() -> bool:
	return ALARM_STATES.has(fsm.state)


## Uyarı yöneticisine: sahibin istediği kademe (0 sakin, 1 şüphe/sorgu, 2 bağırdı).
func alarm_want() -> int:
	if is_alarmed():
		return 2
	if fsm.state != State.AGENDA or suspicion.max_level >= Suspicion.Level.NOTICE:
		return 1
	return 0


func target_peer() -> int:
	return target


func held_peer() -> int:
	return _reaction.held_peer if _reaction != null else 0


## Bir adım (host): duyular → şüphe → katman seçimi → istenen hız (global px/sn).
func step(delta: float) -> Vector2:
	senses.step(delta)
	suspicion.tick(delta)
	_record_peaks()
	fsm.step(delta)
	_tick_shouts(delta)
	var level: int = _top_level()
	if CALM_STATES.has(fsm.state) and level >= Suspicion.Level.DETECT:
		shout(top_peer(), false)
	if fsm.state == State.AGENDA:
		return _agenda_step(delta, level)
	return _reaction.step(delta, level)


## --- Kesme API'si (US-016 müşteri, US-010 gönder, US-009 ses; yalnız AJANDA'da kabul) ---

## Müşteri kuyrukta: tezgâha gelir, kapıya bakar, servis eder.
func serve_customer() -> bool:
	return _interrupt(Agenda.Interrupt.CUSTOMER, owner_tuning.customer_sec,
		senses.marker_position(owner_tuning.counter_marker), senses.marker_position(owner_tuning.front_door_marker),
		true)


## "Arkada X var mı?": arka odaya gider, arar.
func send_to_backroom() -> bool:
	return _interrupt(Agenda.Interrupt.SENT, owner_tuning.sent_sec,
		senses.marker_position(owner_tuning.backroom_marker), Vector2.INF, true)


## Kapı zili: durur, kapıya bakar.
func ring_bell(door_pos: Vector2) -> bool:
	return _interrupt(Agenda.Interrupt.BELL, owner_tuning.bell_sec, Vector2.INF, door_pos, false)


## Ses duyuldu (Hearing `heard`, S8/S11): sese doğru yürür (64 px kala durur) ve bakar. Kendi sesleri
## (bağırış, ajanda sesleri, zil) hariç.
func hear(pos: Vector2, _radius: float, kind: StringName) -> bool:
	if OWN_NOISE_KINDS.has(kind) or not pos.is_finite():
		return false
	var here: Vector2 = body.global_position
	var spot: Vector2 = Vector2.INF
	if here.distance_to(pos) > owner_tuning.question_stop:
		spot = pos + (here - pos).normalized() * owner_tuning.question_stop
	return _interrupt(Agenda.Interrupt.LISTEN, owner_tuning.listen_sec, spot, pos, false)


func _interrupt(kind: Agenda.Interrupt, duration: float, spot: Vector2, look: Vector2, on_arrival: bool) -> bool:
	if fsm.state != State.AGENDA:
		return false
	return agenda.interrupt(kind, duration, spot, look, on_arrival)


func _on_door_crossed(_peer_id: int, door_pos: Vector2) -> void:
	_agenda_noise(NoiseProfile.KIND_BELL, door_pos)  # zil kapıda çalar (US-011b; sahip nerede olursa olsun)
	ring_bell(door_pos)


## --- AJANDA katmanı ---

func _agenda_step(delta: float, level: int) -> Vector2:
	if _recheck_left >= 0.0:
		_recheck_left -= delta
		if _recheck_left < 0.0:
			shout(0, true)
			return Vector2.ZERO
	if level >= Suspicion.Level.NOTICE:
		target = top_peer()
		_reaction.reset()
		fsm.go(State.LOOK)
		mover.stop()
		return Vector2.ZERO
	var goal: Vector2 = agenda.goal_position()
	if goal.is_finite():
		mover.move_to(goal, owner_tuning.walk_speed, STAND_PX)
	else:
		mover.stop()
	agenda.step(delta, mover.arrived() or mover.failed())
	var sound: StringName = agenda.take_noise(delta)
	if not sound.is_empty():
		_agenda_noise(sound, body.global_position)
	var narrowed: float = agenda.half_angle_deg()
	perception.set_cone(narrowed if narrowed > 0.0 else civilian_tuning.half_angle_deg, civilian_tuning.view_range)
	var velocity: Vector2 = mover.desired_velocity(delta)
	if velocity.length() > 1.0:
		turn(velocity, delta)
	else:
		var look: Vector2 = agenda.goal_facing(body.global_position)
		if not look.is_zero_approx():
			turn(look, delta)
	return velocity


## --- tepki katmanının kullandığı genel yardımcılar ---

## Bağırış: tespit kilidi, gürültü, olay; `recheck` = arka oda nakdi kontrolünden sonra yeniden bağırış.
func shout(peer_id: int, recheck: bool) -> void:
	if peer_id != 0:
		target = peer_id
	suspicion.latch_level = Suspicion.Level.DETECT
	mover.stop()
	agenda.cancel_interrupt()
	_recheck_left = -1.0
	_shout_left = owner_tuning.shout_repeat_sec
	_reaction.reset()
	if fsm.state != State.SHOUT:
		fsm.go(State.SHOUT)
	event(&"owner_shout", target)
	_noise()
	shouted.emit(recheck)


## Sakinleşme: kilit kalkar, ajanda tezgâhtan yeniden başlar.
func back_to_agenda() -> void:
	suspicion.latch_level = Suspicion.Level.CALM
	target = 0
	_reaction.reset()
	fsm.go(State.AGENDA)
	agenda.restart_home()
	restore_cone()


func shrug() -> void:
	event(&"owner_shrug", target)
	back_to_agenda()


## Ajandada `seconds` sonra yeniden bağır (arka oda nakdi alınmışsa; +1 komşu). GDD §9.3: oturum başına bir kez.
func schedule_recheck(seconds: float) -> void:
	if _recheck_used:
		return
	_recheck_used = true
	_recheck_left = seconds


func restore_cone() -> void:
	perception.set_cone(civilian_tuning.half_angle_deg, civilian_tuning.view_range)


func walk(delta: float, look_at: Vector2) -> Vector2:
	var velocity: Vector2 = mover.desired_velocity(delta)
	if velocity.length() > 1.0:
		turn(velocity, delta)
	elif look_at.is_finite():
		turn(look_at - body.global_position, delta)
	return velocity


func face(point: Vector2) -> Vector2:
	if point.is_finite():
		turn(point - body.global_position, get_physics_process_delta_time())
	return Vector2.ZERO


func turn(direction: Vector2, delta: float) -> void:
	perception.turn_toward(direction, delta)


func seen_at(peer_id: int) -> Vector2:
	return suspicion.last_seen_position(peer_id) if peer_id != 0 else Vector2.INF


## En şüpheli serbest oyuncu (yoksa 0).
func top_peer() -> int:
	var best: int = 0
	var best_value: float = 0.0
	for peer_id: int in suspicion.peers():
		var player: Node = senses.player(peer_id)
		if player != null and not bool(player.call(&"is_free")):
			continue
		var value: float = suspicion.value_of(peer_id)
		if value > best_value:
			best_value = value
			best = peer_id
	return best


## Sonuç olayı (AC10): kök herkese güvenilir RPC ile yayar.
func event(kind: StringName, peer: int) -> void:
	if body.has_method(&"host_event"):
		body.call(&"host_event", kind, peer)


func _top_level() -> int:
	var peer: int = top_peer()
	return suspicion.level_of(peer) if peer != 0 else Suspicion.Level.CALM


func _tick_shouts(delta: float) -> void:
	if not is_alarmed():
		return
	_shout_left -= delta
	if _shout_left <= 0.0:
		_shout_left = owner_tuning.shout_repeat_sec
		_noise()


func _noise() -> void:
	shout_noises += 1
	NoiseBus.emit_noise(body.global_position, owner_tuning.shout_radius, SHOUT_KIND)


## Ajanda sesi (US-011b, S8): yarıçap NoiseProfile'dan; NoiseBus host'ta dinleyicilere ve halka olayına yayar.
func _agenda_noise(kind: StringName, at: Vector2) -> void:
	agenda_noises[kind] = int(agenda_noises.get(kind, 0)) + 1
	NoiseBus.emit_noise(at, NoiseProfile.load_default().radius_for(kind), kind)


func _record_peaks() -> void:
	for peer_id: int in suspicion.peers():
		peaks[peer_id] = maxf(float(peaks.get(peer_id, 0.0)), suspicion.value_of(peer_id))


## Eşik geçişleri: "?" anı ve tespit kaydı (AC8 döküm; zaman = beyin saati, Fsm.clock).
func _on_threshold(peer_id: int, level: int) -> void:
	if level == Suspicion.Level.NOTICE:
		_notice_at[peer_id] = fsm.clock
	elif level == Suspicion.Level.DETECT and detections.size() < MAX_DETECTIONS:
		var obs: Perception.Observation = suspicion.last_observations().get(peer_id) as Perception.Observation
		detections.append(senses.detection_record(peer_id, obs, perception.global_position,
			float(_notice_at.get(peer_id, -1.0)), fsm.clock))
