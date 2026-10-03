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
##
## Servis (US-016 AC3): müşteri kuyrukta `serve_customer(id)` çağırır; sahip AJANDA'daysa ve başka servis yoksa
## ajandasını keser (MÜŞTERİ kesmesi), ClerkSpot'a gelir, batıya döner, 6 sn servis eder. Servisin
## `register_open_sec`'inde (2. sn) "kasa açılır" kancası `register_opened(customer_id)` (US-039 satış tetiği;
## US-010 SATIN AL aynı kancayı kullanır). Müşteri sonucu `serve_state(id)` ile okur.
## Keşif (US-039): sahip suçüstü görmediyse soygunu kasayı açınca (servis kancası), arka oda görevine varıştan
## `backroom_check_sec` sonra (çanta yerinde değilse) ya da kasa boşken müşterisiz tezgâhta `idle_discover_sec`
## (toplam) sonra fark eder → DISCOVER (durur, balon, `owner_discover` oturum olayı; `discover_sec`) → bağırış
## akışı (uyarı 2, gürültü, komşu). Kaynak başına bir keşif; sahip zaten alarmdaysa (ya da uyarı ≥ bağırış
## kademesi) yalnız balon + komşu +1. İş bittikten sonra keşif yok. Sakinleşince (arama 30 sn) ajandanın ilk görevi
## arka odaya zorlanır (nakit alınmışsa doğal keşif; eski sabit "60 sn sonra yeniden bağırış" yok).
## Oyuncu araçları (US-010; GDD §9.3, KR-026; oyun-yz tur 2 #14-#15):
## - SATIN AL `serve_player(peer)`: müşteri servisinin aynısı (MÜŞTERİ kesmesi, `register_opened` kancası; servis
##   kimliği −peer), o oyuncuya şüphe 0 ve oyalanma 0, `owner_serve`. ARKA ODAYA GÖNDER `send_to_backroom(peer)`:
##   GÖNDERİLDİ kesmesi, `owner_sent`; gönderilmeden tezgâha dönüşe kadar geçen süre `sent_windows` (kasa penceresi).
##   İkisi de sakin durumlarda (AJANDA, BAK, SORGU) kabul edilir: BAK/SORGU'dan önce omuz silker (`owner_shrug`),
##   ajandaya döner, sonra keser (kesme API'si; tur 2 #14).
## - OYALA (konuşma): sahibin `Talk` Interactable'ını tutan oyuncu (`talk_item.busy_by`) varken sahip KONUŞ kesmesiyle
##   durur ve konuşana döner; bakış konuşma boyunca konuşana kilitli (koni onda, kasa ve D arkada). Başlarken
##   `owner_talk`; konuşanın oyalanma süresi eşiği (`loiter_grace`) geçince bir kez `owner_loiter` ("bu adam ne
##   istiyor"; şüphe sivil çarpan tablosunun oyalanma satırıyla dolar). Ajanda dışında ya da yüksek öncelikli
##   kesmede konuşma kesilir (`host_abort`).
## - DİKKAT DAĞIT: dikkat dağıtma sesleri (StoreToolsTuning.DISTRACTION_KINDS) DİNLE'ye sokar (`owner_listen`;
##   oturum olayı `owner_distracted`); kaynak (prop + tür) başına bir kez sayılır, ikinci ve sonrakinde sorumluya
##   `again_suspicion` ("yine mi?", `owner_again`); dikkat dağıtma dinlemesi şüphe SORGU eşiğine (60) varmadıkça BAK'a
##   bölünmez. Telefonun DİNLE noktasına varınca telefonu bulur (`owner_phone_found`, oturum olayı `phone_found`).

## Yalnız host: bağırış (ilk, keşif sonrası ya da alarmdayken keşif = komşu +1); `late` = keşiften (uyarı
## yöneticisi komşu üretir).
signal shouted(late: bool)
## Yalnız host: servisin "kasa açılır" anı (US-016 AC3 kancası; US-039, US-010).
signal register_opened(customer_id: int)
## Yalnız host: keşif (US-039; Source).
signal discovered(source: int)
## Yalnız host (US-010; US-042 strateji etiketi "sosyal" kancası): oyuncu aracı başarıyla uygulandı. `kind`: &"buy",
## &"talk", &"send", &"distract" (sahibin duyup DİNLE'ye girdiği yeni dikkat dağıtmanın sorumlusu).
signal social_action(peer_id: int, kind: StringName)
## Yalnız host (US-044): vitrinden bakan oyuncu kapıdan sorgulandı (tanındı).
signal recognized(peer_id: int)

enum State { AGENDA, LOOK, QUESTION, SHOUT, CHASE, HOLD, STAGGER, SEARCH, DISCOVER }
## Keşif kaynağı (US-039).
enum Source { REGISTER, CASH }
## Servis durumu (müşteri okur).
enum Serve { NONE, PENDING, ACTIVE, DONE, ABORTED }

const STATE_NAMES: Array[StringName] = [&"agenda", &"look", &"question", &"shout", &"chase", &"hold",
	&"stagger", &"search", &"discover"]
const SOURCE_NAMES: Array[StringName] = [&"register", &"cash"]
## Keşif balonu olayı (kök yayar; AC8) ve oturum olayı (HUD metni EVENT_OWNER_DISCOVERED).
const DISCOVER_EVENTS: Array[StringName] = [&"owner_discover_register", &"owner_discover_cash"]
const DISCOVER_SESSION_EVENT := &"owner_discover"
## Servis bakışı verilmemişse bakılan nokta uzaklığı (px).
const SERVE_LOOK_PX := 64.0
## Beynin izinli geçişleri (I3/I7 testleri bu tabloya dayanır).
const EDGES := {
	State.AGENDA: [State.LOOK, State.SHOUT, State.DISCOVER],
	State.LOOK: [State.AGENDA, State.QUESTION, State.SHOUT, State.DISCOVER],
	State.QUESTION: [State.AGENDA, State.SHOUT, State.DISCOVER],
	State.DISCOVER: [State.SHOUT],
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
## Oyuncu servisinin kimliği −peer (müşteri seri numaraları pozitif; US-010).
const DISTRACTED_SESSION_EVENT := &"owner_distracted"
const PHONE_FOUND_SESSION_EVENT := &"phone_found"

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
## Keşif kayıtları (döküm; US-039): {"source", "t", "full"}.
var discoveries: Array[Dictionary] = []
## Tamamlanan servis ve "kasa açılır" sayısı (döküm; US-016).
var serves_done: int = 0
var register_opens: int = 0
## US-010: oyuncu araçları ayarı, konuşma bileşeni (StoreOwner bağlar; yoksa konuşma yok) ve kayıtlar (döküm).
var tools: StoreToolsTuning = null
var talk_item: Interactable = null
var player_serves: int = 0
var sent_windows: Array[float] = []
var phones_found: int = 0
var distractions := CivilianRules.DistractionLog.new()
## İlk bağırış oldu mu (tezgâh istemleri gizlenir; çoğaltılır).
var has_shouted: bool = false
## OYALA söndürmeleri (döküm/test): [{"peer", "amount"}].
var soothed: Array[Dictionary] = []
## Vitrin sorguları (US-044; döküm/test): sorgulanan peer'lar sırayla.
var window_questions: Array[int] = []

## Bileşenler (setup bağlar; okunur).
var body: CharacterBody2D = null
var perception: Perception = null
var suspicion: Suspicion = null
var agenda: Agenda = null
var mover: NpcMover = null
var senses: CivilianSenses = null

var _reaction: OwnerReaction = null
var _shout_left: float = 0.0
var _notice_at: Dictionary = {}
## Süren servis (US-016): müşteri kimliği, kasa açıldı mı; sonuçlar id -> Serve.
var _serving: bool = false
var _serve_id: int = 0
var _serve_opened: bool = false
var _serve_results: Dictionary = {}
## Keşif (US-039): kaynak -> true; arka oda kontrolü bu ziyarette yapıldı mı; kasa boşken müşterisiz tezgâh süresi.
var _discovered: Dictionary = {}
var _backroom_checked: bool = false
var _idle_empty: float = 0.0
## US-010: konuşulan oyuncu (KONUŞ kesmesi), "bu adam ne istiyor" denilenler, gönderilme anı (yoksa < 0), dikkat
## dağıtma dinlemesi (kilit) ve dinlenen telefonun prop'u.
var _talking: int = 0
var _loiter_said: Dictionary = {}
var _sent_at: float = -1.0
var _distraction_listen: bool = false
var _listen_phone: Node2D = null
## OYALA söndürmesi: peer -> kullanım sayısı; bu konuşma değerlendirildi mi (konuşan peer).
var _soothes: Dictionary = {}
var _soothed_talk: int = 0
## Süren sorgu vitrin sorgusu mu (US-044; sorgulanan peer, yoksa 0).
var _door_question: int = 0


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
	perception.factor_query = _factor_for
	senses.track_window_stare = true  # US-044: vitrinden bakma yalnız sahibin bağlamında
	suspicion.innocent_decay_per_sec = civilian_tuning.innocent_decay_per_sec
	suspicion.threshold_reached.connect(_on_threshold)
	agenda.setup(owner_tuning.tasks, agenda_seed, senses.marker_positions)
	mover.door_shortcut = true  # IS-087 AC3: arka kapı açıkken caddeden dolaşmaz
	if tools == null:
		tools = StoreToolsTuning.load_default()
	mover.close_behind = owner_tuning.close_behind_doors.duplicate()
	mover.close_delay = owner_tuning.close_behind_sec
	agenda.interrupt_ended.connect(_on_interrupt_ended)
	senses.door_crossed.connect(_on_door_crossed)
	# Keşif kaynaklarının prop'ları başta (yerlerindeyken) hatırlanır: ilk sorgu çanta taşındıktan sonra gelirse
	# işaretin yanında prop bulunmaz ve "alındı" hiç görülmezdi (US-039).
	senses.prop_taken_near(owner_tuning.cash_marker)
	senses.prop_taken_near(owner_tuning.register_marker)


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
	mover.close_enabled = not is_alarmed()  # IS-087 AC2: iç kapıyı yalnız sakinken arkasından kapatır
	_record_peaks()
	fsm.step(delta)
	_tick_shouts(delta)
	var level: int = _top_level()
	if CALM_STATES.has(fsm.state) and level >= Suspicion.Level.DETECT:
		shout(top_peer(), false)
	if fsm.state == State.DISCOVER:
		_end_talk()
		return _discover_step()
	if fsm.state == State.AGENDA:
		return _agenda_step(delta, level)
	if (fsm.state == State.LOOK or fsm.state == State.QUESTION) and _soothe_step():
		return Vector2.ZERO
	_end_talk()
	return _reaction.step(delta, level)


## --- Kesme API'si (US-016 müşteri, US-010 gönder, US-009 ses; yalnız AJANDA'da kabul) ---

## Müşteri kuyrukta (US-016 AC3): sahip AJANDA'da ve başka servis yoksa tezgâha (ClerkSpot) gelir, batıya döner,
## `customer_sec` servis eder. Aynı müşterinin süren servisi için true; başkası servisteyken false.
func serve_customer(customer_id: int = 0) -> bool:
	if _serving and agenda.current_interrupt() == Agenda.Interrupt.CUSTOMER:
		return customer_id == _serve_id
	var clerk: Vector2 = senses.marker_position(owner_tuning.counter_marker)
	var look: Vector2 = senses.marker_position(owner_tuning.front_door_marker)
	if clerk.is_finite() and not owner_tuning.serve_facing.is_zero_approx():
		look = clerk + owner_tuning.serve_facing.normalized() * SERVE_LOOK_PX
	if not _interrupt(Agenda.Interrupt.CUSTOMER, owner_tuning.customer_sec, clerk, look, true):
		return false
	_serving = true
	_serve_id = customer_id
	_serve_opened = false
	_serve_results[customer_id] = Serve.PENDING
	return true


## Müşterinin servis durumu (Serve): PENDING sahip tezgâha geliyor, ACTIVE servis sürüyor, DONE bitti, ABORTED
## bırakıldı (bağırış, sorgu), NONE hiç kabul edilmedi.
func serve_state(customer_id: int) -> int:
	if _serving and customer_id == _serve_id and agenda.current_interrupt() == Agenda.Interrupt.CUSTOMER:
		return Serve.ACTIVE if agenda.has_arrived() else Serve.PENDING
	return int(_serve_results.get(customer_id, Serve.NONE))


## Ön kapıdan geçen müşteri (US-016 AC2): zil çalar, sahip 1 sn kapıya bakar (oyuncu geçişiyle aynı akış).
func door_bell(door_pos: Vector2) -> void:
	_on_door_crossed(0, door_pos)


## "Arkada X var mı?": arka odaya gider, arar (US-010 GÖNDER; `peer_id` soran oyuncu, 0 = test/NPC). Sakin
## durumlarda kabul (BAK/SORGU'dan önce omuz silker).
func send_to_backroom(peer_id: int = 0) -> bool:
	if not can_send(peer_id):
		return false
	_settle_for_interrupt()
	var ok: bool = _interrupt(Agenda.Interrupt.SENT, owner_tuning.sent_sec,
		senses.marker_position(owner_tuning.backroom_marker), Vector2.INF, true)
	if ok:
		_sent_at = fsm.clock
		if peer_id != 0:
			event(&"owner_sent", peer_id)
			social_action.emit(peer_id, &"send")
	return ok


## GÖNDER şu an kabul edilir mi (sakin durum, zaten gönderilmemiş).
func can_send(_peer_id: int = 0) -> bool:
	return CALM_STATES.has(fsm.state) and agenda.current_interrupt() != Agenda.Interrupt.SENT


## SATIN AL (US-010 AC2): oyuncuyu müşteri gibi servis eder (servis kimliği −peer; `register_opened` kancası aynı).
## O oyuncuya şüphe 0 ve oyalanma 0 (GDD §9.3). Kabul edilirse true ve `owner_serve`.
func serve_player(peer_id: int) -> bool:
	if not can_serve_player(peer_id):
		return false
	_settle_for_interrupt()
	if not serve_customer(-peer_id):
		return false
	suspicion.forget(peer_id)
	senses.reset_loiter(peer_id)
	player_serves += 1
	event(&"owner_serve", peer_id)
	social_action.emit(peer_id, &"buy")
	return true


## SATIN AL şu an kabul edilir mi: sakin durum, süren servis yok, gönderilmemiş.
func can_serve_player(peer_id: int) -> bool:
	if peer_id <= 0 or not CALM_STATES.has(fsm.state):
		return false
	var current: Agenda.Interrupt = agenda.current_interrupt()
	return not _serving and current != Agenda.Interrupt.SENT and current != Agenda.Interrupt.CUSTOMER


## BAK/SORGU'dan kesmeye: omuz silker, ajandaya döner (kesme API'si LOOK/QUESTION'da da çalışır; tur 2 #14).
func _settle_for_interrupt() -> void:
	if fsm.state == State.LOOK or fsm.state == State.QUESTION:
		shrug()


## Kapı zili: durur, kapıya bakar.
func ring_bell(door_pos: Vector2) -> bool:
	return _interrupt(Agenda.Interrupt.BELL, owner_tuning.bell_sec, Vector2.INF, door_pos, false)


## Ses duyuldu (Hearing `heard`, S8/S11): sese doğru yürür (64 px kala durur) ve bakar. Kendi sesleri
## (bağırış, ajanda sesleri, zil) hariç.
func hear(pos: Vector2, _radius: float, kind: StringName) -> bool:
	if OWN_NOISE_KINDS.has(kind) or not pos.is_finite():
		return false
	var distraction: bool = StoreToolsTuning.DISTRACTION_KINDS.has(kind)
	var source: Node2D = senses.distraction_source(pos) if distraction else null
	var fresh: bool = distraction and distractions.note(_distraction_key(source, pos, kind))
	if fresh and distractions.is_again():
		var culprit: int = int(source.call(&"distraction_peer", kind)) if source != null else 0
		if culprit != 0 and CALM_STATES.has(fsm.state):
			suspicion.apply_delta(culprit, tools.again_suspicion)  # "yine mi?" (US-010 AC5)
			event(&"owner_again", culprit)
	var here: Vector2 = body.global_position
	var spot: Vector2 = Vector2.INF
	if here.distance_to(pos) > owner_tuning.question_stop:
		spot = pos + (here - pos).normalized() * owner_tuning.question_stop
	var was_listening: bool = agenda.current_interrupt() == Agenda.Interrupt.LISTEN
	if not _interrupt(Agenda.Interrupt.LISTEN, owner_tuning.listen_sec, spot, pos, false):
		return false
	_distraction_listen = distraction
	_listen_phone = source if kind == StoreToolsTuning.KIND_CELLPHONE else null
	if not was_listening:
		event(&"owner_listen", 0)
	if fresh:
		Game.raise_session_event(DISTRACTED_SESSION_EVENT, {"kind": String(kind)})
		var by: int = int(source.call(&"distraction_peer", kind)) if source != null else 0
		if by != 0:
			social_action.emit(by, &"distract")
	return true


static func _distraction_key(source: Node2D, pos: Vector2, kind: StringName) -> String:
	var where: String = String(source.name) if source != null else str(pos.round())
	return "%s:%s" % [where, kind]


func _interrupt(kind: Agenda.Interrupt, duration: float, spot: Vector2, look: Vector2, on_arrival: bool) -> bool:
	if fsm.state != State.AGENDA:
		return false
	return agenda.interrupt(kind, duration, spot, look, on_arrival)


func _on_door_crossed(_peer_id: int, door_pos: Vector2) -> void:
	_agenda_noise(NoiseProfile.KIND_BELL, door_pos)  # zil kapıda çalar (US-011b; sahip nerede olursa olsun)
	ring_bell(door_pos)


func _on_interrupt_ended(kind: Agenda.Interrupt, completed: bool) -> void:
	if kind != Agenda.Interrupt.CUSTOMER or not _serving:
		return
	_serving = false
	_serve_results[_serve_id] = Serve.DONE if completed else Serve.ABORTED
	if completed:
		serves_done += 1


## --- Keşif (US-039) ---

## Soygunu fark et: kaynak başına bir kez, iş sürüyorken. Sakinse DISCOVER → bağırış; zaten alarmdaysa (ya da uyarı
## bağırış kademesinde) yalnız balon + komşu +1. Kabul edilirse true.
func discover(source: int) -> bool:
	if source < 0 or source >= SOURCE_NAMES.size() or _discovered.has(source) or not _heist_running():
		return false
	_discovered[source] = true
	var full: bool = not is_alarmed() and fsm.state != State.DISCOVER \
		and Game.alert_level() < maxi(civilian_tuning.alarm_level, 1)
	discoveries.append({"source": SOURCE_NAMES[source], "t": snappedf(fsm.clock, 0.01), "full": full})
	discovered.emit(source)
	event(DISCOVER_EVENTS[source], 0)
	if not full:
		shouted.emit(true)  # alarmdayken ikinci kaynak: yalnız balon + komşu +1 (max_neighbours korunur)
		return true
	Game.raise_session_event(DISCOVER_SESSION_EVENT, {"source": String(SOURCE_NAMES[source])})
	target = 0
	mover.stop()
	agenda.cancel_interrupt()
	_reaction.reset()
	fsm.go(State.DISCOVER)
	return true


## DISCOVER: durur (balon görselde), süre dolunca bağırış akışı (hedefsiz; uyarı ≥ 2 satırı herkese işler).
func _discover_step() -> Vector2:
	mover.stop()
	if fsm.time_in_state >= owner_tuning.discover_sec:
		shout(0, true)
	return Vector2.ZERO


## Ajandadaki keşif tetikleri: servisin "kasa açılır" anı, arka oda varışı + 1 sn, müşterisiz tezgâhta boş kasa.
## Durum değiştiyse true (adım kesilir).
func _agenda_triggers(delta: float) -> bool:
	if _serving and not _serve_opened and agenda.current_interrupt() == Agenda.Interrupt.CUSTOMER \
			and agenda.has_arrived() and agenda.interrupt_elapsed() >= owner_tuning.register_open_sec:
		_serve_opened = true
		register_opens += 1
		register_opened.emit(_serve_id)
		if senses.prop_taken_near(owner_tuning.register_marker) and discover(Source.REGISTER):
			return fsm.state != State.AGENDA
	var interrupt: Agenda.Interrupt = agenda.current_interrupt()
	var task: AgendaTask = agenda.current_task()
	var backroom: bool = interrupt == Agenda.Interrupt.SENT or (interrupt == Agenda.Interrupt.NONE \
		and task != null and task.name == owner_tuning.backroom_task)
	if not backroom:
		_backroom_checked = false
	elif not _backroom_checked and agenda.has_arrived() and agenda.arrived_for() >= owner_tuning.backroom_check_sec:
		_backroom_checked = true
		if senses.prop_taken_near(owner_tuning.cash_marker) and discover(Source.CASH):
			return fsm.state != State.AGENDA
	var at_counter: bool = interrupt == Agenda.Interrupt.NONE and task != null and task.home and agenda.has_arrived()
	if owner_tuning.idle_discover_sec > 0.0 and at_counter and senses.customers_inside() == 0 \
			and not _discovered.has(Source.REGISTER) and senses.prop_taken_near(owner_tuning.register_marker):
		_idle_empty += maxf(delta, 0.0)
		if _idle_empty >= owner_tuning.idle_discover_sec and discover(Source.REGISTER):
			return fsm.state != State.AGENDA
	return false


## İş sürüyor mu (sonuç yayılmadıysa; US-039 AC7: iş bittikten sonra keşif yok).
func _heist_running() -> bool:
	return Game.heist_result().is_empty()


## --- AJANDA katmanı ---

func _agenda_step(delta: float, level: int) -> Vector2:
	var listening: bool = agenda.current_interrupt() == Agenda.Interrupt.LISTEN
	if not listening:
		_distraction_listen = false
		_listen_phone = null
	# Dikkat dağıtma dinlemesi "yine mi?" şüphesiyle BAK'a bölünmez; SORGU eşiğinde (60) bölünür (US-010).
	var held_by_listen: bool = listening and _distraction_listen and level < Suspicion.Level.INVESTIGATE
	if level >= Suspicion.Level.NOTICE and not held_by_listen:
		target = top_peer()
		_reaction.reset()
		_end_talk()
		fsm.go(State.LOOK)
		mover.stop()
		return Vector2.ZERO
	_talk_step()
	_sent_window_step()
	if listening and _listen_phone != null and agenda.has_arrived():
		_find_phone()
	var goal: Vector2 = agenda.goal_position()
	if goal.is_finite():
		mover.move_to(goal, owner_tuning.walk_speed, STAND_PX)
	else:
		mover.stop()
	agenda.step(delta, mover.arrived() or mover.failed())
	if _agenda_triggers(delta):
		return Vector2.ZERO
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


## --- oyuncu araçları (US-010) ---

## KONUŞ: `talk_item`'ı tutan oyuncu varken sahip durur ve ona döner (bakış kilitli); bırakınca ajanda sürer.
func _talk_step() -> void:
	var talker: int = talk_item.busy_by if talk_item != null else 0
	var current: Agenda.Interrupt = agenda.current_interrupt()
	if talker == 0:
		_talking = 0
		if current == Agenda.Interrupt.TALK:
			agenda.cancel_interrupt()
		return
	var player: Node2D = senses.player(talker)
	var at: Vector2 = CivilianSenses.position_of(player) if player != null else Vector2.INF
	if current == Agenda.Interrupt.TALK and _talking == talker:
		agenda.retarget_look(at)
	elif agenda.interrupt(Agenda.Interrupt.TALK, tools.talk_max_sec + 1.0, Vector2.INF, at, false):
		_talking = talker
		mover.stop()
		event(&"owner_talk", talker)
		social_action.emit(talker, &"talk")
	else:
		_end_talk()  # yüksek öncelikli kesme (müşteri, gönderilme) sürüyor: konuşma olmaz
		return
	var grace: float = senses.rules.loiter_grace if senses.rules != null else 0.0
	if grace > 0.0 and not _loiter_said.has(talker) and senses.loiter_time(talker) >= grace:
		_loiter_said[talker] = true
		event(&"owner_loiter", talker)  # "bu adam ne istiyor" (şüphe oyalanma satırıyla dolar)


## Konuşmayı keser (host): bileşen bırakılır, KONUŞ kesmesi biter.
func _end_talk() -> void:
	if talk_item != null and talk_item.busy_by != 0:
		talk_item.host_abort()
	if _talking != 0 and agenda.current_interrupt() == Agenda.Interrupt.TALK:
		agenda.cancel_interrupt()
	_talking = 0


## Algının çarpan sorgusu: sivil tablo; vitrinden bakma satırı (US-044) şüpheyi `outside_stare_cap`'te durdurur
## (bağırmaz, yalnız sorar).
func _factor_for(target: Node) -> float:
	var f: float = senses.factor_for(target)
	if f <= 0.0 or senses.behaviour_for(target) != CivilianRules.Behaviour.WINDOW_STARE:
		return f
	var cap: float = civilian_tuning.outside_stare_cap
	return 0.0 if suspicion.value_of(target.get_multiplayer_authority()) >= cap else f


## Sorgu noktası: vitrinden bakan (dışarıda) oyuncuya sahip ön kapıya yürür (US-044); diğerlerinde son görülen konum.
## Bir sorgu boyunca karar kalıcıdır (bakan bir an başını çevirse de sahip dışarı yürümez).
func question_spot(peer_id: int) -> Vector2:
	if _door_question == peer_id or is_window_starer(peer_id):
		var door: Vector2 = senses.marker_position(owner_tuning.front_door_marker)
		if door.is_finite():
			_door_question = peer_id
			return door
	return seen_at(peer_id)


## Oyuncu dışarıda vitrinden bakıyor mu (US-044; bağlamın vitrin süresi > 0).
func is_window_starer(peer_id: int) -> bool:
	var player: Node2D = senses.player(peer_id)
	if player == null or senses.window_stare_of(peer_id) <= 0.0:
		return false
	return senses.zone_of(CivilianSenses.position_of(player)) == CivilianRules.Zone.OUTSIDE


## Sorgu anı (OwnerReaction): vitrinden bakana "Bir şey mi arıyorsun?" (tanındı), diğerlerine "Ne yapıyorsun?".
func ask(peer_id: int) -> void:
	if _door_question == peer_id:
		window_questions.append(peer_id)
		event(&"owner_question_window", peer_id)
		recognized.emit(peer_id)
	else:
		event(&"owner_question", peer_id)


## OYALA söndürmesi (GDD §9.3, US-010 izi): BAK/SORGU'daki sahiple konuşma başlayınca o oyuncunun sayacına göre
## şüphesi düşer (40 / 20 / 0), sahip omuz silker ve ajandada konuşmaya geçer (true). Sayaç tükenmişse ("bir daha
## tutmaz") `owner_soothe_refused` ve konuşma kesilir (false). Bir konuşma bir kez değerlendirilir.
func _soothe_step() -> bool:
	var talker: int = talk_item.busy_by if talk_item != null else 0
	if talker == 0:
		_soothed_talk = 0
		return false
	if _soothed_talk == talker:
		return false
	_soothed_talk = talker
	var uses: int = int(_soothes.get(talker, 0))
	_soothes[talker] = uses + 1
	var amount: float = CivilianRules.soothe_amount(uses, tools.talk_soothe_steps)
	if amount <= 0.0:
		event(&"owner_soothe_refused", talker)
		return false
	suspicion.apply_delta(talker, -amount)
	soothed.append({"peer": talker, "amount": amount})
	shrug()
	return true


## Şu an konuşulan oyuncu (0 = yok).
func talking_to() -> int:
	return _talking


## Kasa penceresi ölçümü: gönderilmeden tezgâha (ev görevi) dönüşe kadar geçen süre.
func _sent_window_step() -> void:
	if _sent_at < 0.0 or agenda.current_interrupt() != Agenda.Interrupt.NONE:
		return
	var task: AgendaTask = agenda.current_task()
	if task != null and task.home and agenda.has_arrived():
		sent_windows.append(snappedf(fsm.clock - _sent_at, 0.01))
		_sent_at = -1.0


## Telefonun DİNLE noktasına varıldı: telefonu bulur.
func _find_phone() -> void:
	var phone: Node2D = _listen_phone
	_listen_phone = null
	if phone == null or not is_instance_valid(phone) or not phone.has_method(&"host_take_phone"):
		return
	if body.global_position.distance_to(phone.global_position) > maxf(tools.phone_find_px, owner_tuning.question_stop):
		return
	if bool(phone.call(&"host_take_phone")):
		phones_found += 1
		event(&"owner_phone_found", 0)
		Game.raise_session_event(PHONE_FOUND_SESSION_EVENT, {})


## --- tepki katmanının kullandığı genel yardımcılar ---

## Bağırış: tespit kilidi, gürültü, olay; `late` = keşiften (US-039).
func shout(peer_id: int, late: bool) -> void:
	if peer_id != 0:
		target = peer_id
	suspicion.latch_level = Suspicion.Level.DETECT
	has_shouted = true
	mover.stop()
	agenda.cancel_interrupt()
	_shout_left = owner_tuning.shout_repeat_sec
	_reaction.reset()
	if fsm.state != State.SHOUT:
		fsm.go(State.SHOUT)
	event(&"owner_shout", target)
	_noise()
	shouted.emit(late)


## Sakinleşme: kilit kalkar, ajanda tezgâhtan yeniden başlar; `check_backroom` (alarm sonrası, US-039 AC6) ilk
## görevi arka odaya zorlar (nakit alınmışsa varışta doğal keşif).
func back_to_agenda(check_backroom: bool = false) -> void:
	suspicion.latch_level = Suspicion.Level.CALM
	target = 0
	_door_question = 0
	_reaction.reset()
	fsm.go(State.AGENDA)
	agenda.restart_home()
	if check_backroom:
		agenda.begin_task(owner_tuning.backroom_task)
	restore_cone()


func shrug() -> void:
	event(&"owner_shrug", target)
	back_to_agenda()


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
