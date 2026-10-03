class_name StoreOwner
extends CharacterBody2D
## Bakkal sahibi (US-008 AC1/AC10; GDD §9.3; mimari.md S2, S11). Kök CharacterBody2D (katman npcs, maske
## world: oyuncuları itmez); bileşenler `Perception`, `Suspicion`, `Agenda`, `NpcMover`, `CivilianSenses`,
## `Brain` (OwnerBrain), isteğe bağlı `Hearing` (S8/S11, US-009; yoksa genel sınıf `Hearing` varsa kurulur, duck
## typing: `heard(pos, radius, kind)` sinyali) ve görsel `Visual`. Seviyede `NPCs` altında durağan düğümdür
## (her peer'da aynı yol, yetki host).
##
## Host: her fizik adımında beyin hızı verir, `move_and_slide`, ağ alanları yazılır. Çoğaltma (15 Hz):
## konum/yön/ölçer güvenilmez sürekli (ON-04: "?"/"!" istemcide eşikten türetilir), durum/görev/alarm/tutulan
## değişince güvenilir. Sonuç olayları (`owner_question`, `owner_shrug`, `owner_shout`, `owner_held`,
## `owner_stagger`; AC10) güvenilir RPC ile her peer'da aynı sırada sinyal olur. İstemci konumu yumuşatarak izler.
## Döküm (S6, `--dump`): "owner" = {state, task, alarmed, events, event_peers, bubbles} + host'ta {detections,
## peak, agenda, states, rescues, discoveries, serves, register_opens}.
## US-016/US-039 ekleri: servis kancası ve müşteri API'si (`serve_customer(id)`, `serve_state`, `door_bell`), keşif
## olayları `owner_discover_register` / `owner_discover_cash` (balon; AC8) ve host API `discover(source)`.
## US-010 ekleri (bakkal etkileşimleri): host API `serve_player(peer)` / `can_serve_player(peer)` (SATIN AL),
## `send_to_backroom(peer)` / `can_send(peer)` (GÖNDER), `is_active()`, `has_shouted()` (çoğaltılan `net_shouted`:
## tezgâh istemleri gizlenir); sahibin üstünde `Talk` Interactable (OYALA: E, basılı tut, `talk_range`; masum
## eylem; her peer'da çoğaltılan durumdan etkin: sakin ajandada, servis/gönderilme dışında, bağırmadan önce);
## olay kanalı genişledi (`owner_serve`, `owner_talk`, `owner_sent`, `owner_listen`, `owner_again`,
## `owner_phone_found`, `owner_loiter`; balonlar NpcVisual'da). Döküm ekleri: her peer'da `talk_peer`, `facing`,
## `shouted`, `talk_gaze`; host'ta `loiter_s` (peer → sn), `player_serves`, `sent_windows`, `distractions`, `phones_found`.

signal owner_question(peer_id: int)
signal owner_shrug(peer_id: int)
signal owner_shout(peer_id: int)
signal owner_held(peer_id: int)
signal owner_stagger(peer_id: int)
## US-039 AC8: keşif balonu (peer her zaman 0).
signal owner_discover_register(peer_id: int)
signal owner_discover_cash(peer_id: int)
## US-010 olay kanalı (her peer'da aynı sırada; balon metinleri NpcVisual.BALLOON_KEYS).
signal owner_serve(peer_id: int)
signal owner_talk(peer_id: int)
signal owner_sent(peer_id: int)
signal owner_listen(peer_id: int)
signal owner_again(peer_id: int)
signal owner_phone_found(peer_id: int)
signal owner_loiter(peer_id: int)
## Her peer'da: görev değişti (çoğaltılan; görev ikonu US-011).
signal task_changed(task_name: StringName)
## Yalnız host (US-010): oyuncu aracı başarıyla uygulandı (OwnerBrain.social_action aktarımı; kind buy|talk|send|
## distract). US-042 `Tracker.note_social` buna bağlanır (koordinatör birleştirmesi).
signal social_action(peer_id: int, kind: StringName)
## US-010 izi / US-043 / US-044 olay kanalı (her peer'da): OYALA söndürmesi tükendi ("bir daha tutmaz"),
## YÖNLENDİR ("o tarafa kaçtı!"), vitrinden bakana kapıdan sorgu ("Bir şey mi arıyorsun?").
signal owner_soothe_refused(peer_id: int)
signal owner_misdirect(peer_id: int)
signal owner_question_window(peer_id: int)
## Yalnız host (US-044): sahip oyuncuyu tanıdı (vitrin sorgusu); Game iş sonucunda `recognized` +1 sayar.
signal recognized(peer_id: int)

const OWNER_TUNING_PATH := "res://data/npc/owner_tuning.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const DUMP_KEY := "owner"
const EVENT_KINDS: Array[StringName] = [&"owner_question", &"owner_shrug", &"owner_shout", &"owner_held",
	&"owner_stagger", &"owner_discover_register", &"owner_discover_cash", &"owner_serve", &"owner_talk",
	&"owner_sent", &"owner_listen", &"owner_again", &"owner_phone_found", &"owner_loiter", &"owner_soothe_refused",
	&"owner_misdirect", &"owner_question_window"]
## YÖNLENDİR bileşeninin istem anahtarı, gereken etiket (oyuncunun örtüsü sağlam; Player.interaction_tags) ve oturum
## olayı (HUD metni EVENT_MISDIRECT).
const MISDIRECT_ACTION_KEY := "INTERACT_MISDIRECT"
const COVER_TAG := &"cover"
const MISDIRECT_SESSION_EVENT := &"misdirect"
## OYALA'nın açık olduğu sahip durumları (US-010 izi: BAK/SORGU'daki sahip de konuşulup söndürülebilir).
const TALK_STATES: Array[int] = [OwnerBrain.State.AGENDA, OwnerBrain.State.LOOK, OwnerBrain.State.QUESTION]
## OYALA bileşeninin istem anahtarı (i18n) ve konuşmanın kapalı olduğu görevler (servis, gönderilme).
const TALK_ACTION_KEY := "INTERACT_OWNER_TALK"
const TALK_CLOSED_TASKS: Array[StringName] = [&"customer", &"sent"]
## İstemci yumuşatması (1/sn) ve sıçrama eşiği (px).
const SMOOTHING := 14.0
const SNAP_PX := 96.0
const HEARING_CLASS := &"Hearing"
## DİNLE kesmesinin çoğaltılan görev adı (Agenda.INTERRUPT_NAMES).
const LISTEN_TASK := &"listen"
## Dökümde tutulan en fazla olay.
const MAX_EVENTS := 128

@export var owner_tuning: OwnerTuning
@export var civilian_tuning: CivilianTuning
## false: testler `step()`'i elle sürer.
@export var auto_step: bool = true
## false: sahip yok sayılır (gizli, çarpışmasız, işlemez; NPC'siz etkileşim senaryoları için fikstür).
@export var active: bool = true
## ≥ 0 ise ajanda tohumu ayar dosyası yerine bu (test fikstürü: ör. ilk pencere görevi arka oda; US-039).
@export var agenda_seed_override: int = -1

## Çoğaltılan durum (host yazar).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.LEFT
var net_meter: float = 0.0
var net_state: int = 0
var net_task: StringName = &"":
	set = _set_task
var net_alarmed: bool = false
var net_hold_peer: int = 0
## Sahip bu işte bağırdı mı (US-010: tezgâh istemleri gizlenir).
var net_shouted: bool = false
## YÖNLENDİR bu işte kullanıldı mı (US-043: iş başına 1; istemler gizlenir).
var net_misdirected: bool = false
## Host kayıtları (döküm): YÖNLENDİR [{"peer", "chasers", "point"}].
var misdirects: Array[Dictionary] = []

## Görselin okuduğu durum (her peer'da).
var facing: Vector2 = Vector2.LEFT
var bubble: int = CivilianRules.Bubble.NONE
## Son olay ve üstünden geçen süre (balon metni).
var last_event: StringName = &""
var last_event_age: float = INF

var _rules: CivilianRules.Params = null
var _events: Array[StringName] = []
var _event_peers: Array[int] = []
var _bubbles: Array[int] = []

@onready var _perception: Perception = $Perception
@onready var _suspicion: Suspicion = $Suspicion
@onready var _agenda: Agenda = $Agenda
@onready var _mover: NpcMover = $Mover
@onready var _senses: CivilianSenses = $Senses
@onready var _brain: OwnerBrain = $Brain
@onready var _talk: Interactable = $Talk
@onready var _misdirect: Interactable = $Misdirect


func _ready() -> void:
	_suspicion.set_physics_process(false)  # beyin sırayla işletir (etkin değilse hiç işlemez)
	_setup_talk()
	_setup_misdirect()
	if not active:
		hide()
		collision_layer = 0
		set_physics_process(false)
		return
	if owner_tuning == null:
		owner_tuning = load(OWNER_TUNING_PATH) as OwnerTuning
	if civilian_tuning == null:
		civilian_tuning = load(CIVILIAN_TUNING_PATH) as CivilianTuning
	_rules = civilian_tuning.rules_params(_perception.tuning)
	net_position = position
	facing = _perception.facing
	net_facing = facing
	if _is_host():
		_senses.bell_marker = owner_tuning.front_door_marker
		_senses.bell_radius = owner_tuning.bell_radius
		_senses.setup(_level(), civilian_tuning, _perception.tuning)
		_brain.owner_tuning = owner_tuning
		_brain.civilian_tuning = civilian_tuning
		_brain.agenda_seed = agenda_seed()
		_brain.talk_item = _talk
		_brain.social_action.connect(social_action.emit)
		_brain.recognized.connect(recognized.emit)
		_brain.setup(self, _perception, _suspicion, _agenda, _mover, _senses)
		_bind_hearing()
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, dump_state)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


## Bir adım: host'ta beyin + hareket + yayın; istemcide yumuşatma. Gösterge her peer'da çoğaltılandan.
func step(delta: float) -> void:
	if not active:
		return
	if _is_host():
		velocity = _brain.step(delta)
		move_and_slide()
		_publish()
	else:
		_follow(delta)
	last_event_age += delta
	_refresh_talk()
	_refresh_misdirect()
	var next: int = CivilianRules.bubble(_rules, net_meter, net_alarmed, bubble)
	if next != bubble:
		bubble = next
		_bubbles.append(next)


func brain() -> OwnerBrain:
	return _brain


func agenda() -> Agenda:
	return _agenda


func perception() -> Perception:
	return _perception


## Her peer'da: sahip bir sesi dinliyor mu (DİNLE kesmesi; çoğaltılan görev adından). Görsel "?" çizer (IS-087 AC4).
func is_listening() -> bool:
	return net_task == LISTEN_TASK


func suspicion() -> Suspicion:
	return _suspicion


func senses() -> CivilianSenses:
	return _senses


## Host API (AC4; US-010 OYALA): o oyuncuya şüpheyi değiştirir.
func apply_suspicion(peer_id: int, delta: float) -> void:
	_suspicion.apply_delta(peer_id, delta)


## Host API (US-016 AC5): tanık sivil söyledi — o oyuncuya şüphe `delta`; `where` (tanığın gördüğü yer, sonlu
## ise) sahibin son görülen konumu olur (sorgu oraya yürür).
func report_suspicion(peer_id: int, delta: float, where: Vector2 = Vector2.INF) -> void:
	if not _is_host() or not active or peer_id == 0:
		return
	_suspicion.apply_delta(peer_id, delta)
	if where.is_finite():
		_suspicion.hint_position(peer_id, where)


## Host API (US-016): müşteri kuyrukta (kabul edilirse true; aynı müşterinin süren servisi de true).
func serve_customer(customer_id: int = 0) -> bool:
	return _brain.serve_customer(customer_id) if _is_host() and active else false


## Host API (US-016): müşterinin servis durumu (OwnerBrain.Serve).
func serve_state(customer_id: int) -> int:
	return _brain.serve_state(customer_id) if _is_host() and active else OwnerBrain.Serve.NONE


## Host API (US-016): müşteri ön kapıdan geçti (zil).
func door_bell(door_pos: Vector2) -> void:
	if _is_host() and active:
		_brain.door_bell(door_pos)


## Host API (US-039): soygunu fark et (OwnerBrain.Source).
func discover(source: int) -> bool:
	return _brain.discover(source) if _is_host() and active else false


## Host API (US-010 GÖNDER): "arkada X var mı?" (`peer_id` soran oyuncu; 0 = test).
func send_to_backroom(peer_id: int = 0) -> bool:
	return _brain.send_to_backroom(peer_id) if _is_host() and active else false


## Host API (US-010): GÖNDER şu an kabul edilir mi (tezgâhın host engeli).
func can_send(peer_id: int = 0) -> bool:
	return _brain.can_send(peer_id) if _is_host() and active else false


## Host API (US-010 SATIN AL): oyuncuyu servis eder (kasa kancası dahil). Kabul edilirse true.
func serve_player(peer_id: int) -> bool:
	return _brain.serve_player(peer_id) if _is_host() and active else false


## Host API (US-010): SATIN AL şu an kabul edilir mi (tezgâhın host engeli).
func can_serve_player(peer_id: int) -> bool:
	return _brain.can_serve_player(peer_id) if _is_host() and active else false


## Her peer'da: sahip etkin mi (fikstürde kapalı olabilir; tezgâh istemleri buna bakar).
func is_active() -> bool:
	return active


## Her peer'da: sahip bu işte bağırdı mı (çoğaltılan).
func has_shouted() -> bool:
	return net_shouted


## Her peer'da: bakışın konuşan oyuncuya yönelimi (bakış · yön; konuşma yoksa 0). OYALA bakış kilidinin ölçüsü.
func talk_gaze() -> float:
	var talker: int = _talk.busy_by
	if talker == 0:
		return 0.0
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == talker and node is Node2D:
			var to: Vector2 = (node as Node2D).global_position - global_position
			return facing.normalized().dot(to.normalized()) if not to.is_zero_approx() else 1.0
	return 0.0


## YÖNLENDİR bileşeni (testler).
func misdirect_interactable() -> Interactable:
	return _misdirect


## Her peer'da: YÖNLENDİR şu an açık mı (sahip ve mahalleli istemleri; uyarı ≥ eşik, iş başına 1). Örtü koşulu
## Interactable gereksiniminde (etiket `cover`).
func misdirect_open() -> bool:
	return active and not net_misdirected \
		and Game.alert_level() >= StoreToolsTuning.load_default().misdirect_min_alert


## Host API (US-043 YÖNLENDİR "o tarafa kaçtı!"): örtüsü sağlam `peer_id` gösterir → söyleyene `misdirect_radius`
## içindeki mahalleliler `misdirect_run_sec` boyunca kaçış noktasının tersine (`CivilianRules.misdirect_point`)
## koşar; söyleyene sahipte +`misdirect_suspicion`; iş başına 1 (`net_misdirected`). Sahibin ve mahallelinin
## bileşeni buraya bağlanır. Kabul edilirse true.
func misdirect(peer_id: int) -> bool:
	if not _is_host() or not misdirect_open() or peer_id <= 0 or not _senses.cover_intact(peer_id):
		return false
	var player: Node2D = _senses.player(peer_id)
	if player == null:
		return false
	var tools: StoreToolsTuning = StoreToolsTuning.load_default()
	var at: Vector2 = CivilianSenses.position_of(player)
	var level: Node = _level()
	var point: Vector2 = CivilianRules.misdirect_point(at, _escape_point(level), tools.misdirect_run_px)
	var misled: int = 0
	var npcs: Node = level.call(&"npcs_root") as Node if level != null and level.has_method(&"npcs_root") else null
	if npcs != null:
		for node: Node in npcs.get_children():
			var npc: Node2D = node as Node2D
			if npc == null or not npc.has_method(&"mislead") or npc.global_position.distance_to(at) > tools.misdirect_radius:
				continue
			if bool(npc.call(&"mislead", point, tools.misdirect_run_sec)):
				misled += 1
	net_misdirected = true
	_suspicion.apply_delta(peer_id, tools.misdirect_suspicion)
	misdirects.append({"peer": peer_id, "chasers": misled, "point": [roundf(point.x), roundf(point.y)]})
	host_event(&"owner_misdirect", peer_id)
	Game.raise_session_event(MISDIRECT_SESSION_EVENT, {"peer": peer_id})
	social_action.emit(peer_id, &"misdirect")
	_refresh_misdirect()
	return true


## Kaçış noktası: Game'in (S3 eki), yoksa seviyenin `EscapeZone` bölgesinin ilk şeklinin merkezi (S4 eki); yoksa INF.
static func _escape_point(level: Node) -> Vector2:
	var p: Vector2 = Game.escape_point()
	if p.is_finite() or level == null or not level.has_method(&"zone"):
		return p
	var zone: Area2D = level.call(&"zone", &"EscapeZone") as Area2D
	if zone == null:
		return Vector2.INF
	for node: Node in zone.find_children("*", "CollisionShape2D", false, false):
		return (node as CollisionShape2D).global_position
	return zone.global_position


## OYALA bileşeni (testler, görsel).
func talk_interactable() -> Interactable:
	return _talk


## Host API (US-010 SATIN AL): oyalanma sayacı sıfır.
func reset_loiter(peer_id: int) -> void:
	_senses.reset_loiter(peer_id)


## Ajandanın tohumu (host; tek nokta). Şimdilik veriden (owner_tuning.agenda_seed); oturum tohumu
## (`Game.session_seed()`, `--seed=`) gelince onunla birleştirilir (IS-058).
func agenda_seed() -> int:
	return agenda_seed_override if agenda_seed_override >= 0 else owner_tuning.agenda_seed


## Görselin konisi: yarım açı (derece; görev daraltıyorsa o) ve menzil (px).
func cone_half_angle() -> float:
	for task: AgendaTask in owner_tuning.tasks:
		if task != null and task.name == net_task and task.half_angle_deg > 0.0:
			return task.half_angle_deg
	return civilian_tuning.half_angle_deg


func cone_range() -> float:
	return civilian_tuning.view_range


## Tutulan oyuncunun çizilen konumu (görsel; yoksa INF).
func held_position() -> Vector2:
	if net_hold_peer == 0:
		return Vector2.INF
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == net_hold_peer and node is Node2D:
			return (node as Node2D).global_position
	return Vector2.INF


## Host: sonuç olayını herkese yayar (her peer'da aynı sırada sinyal).
func host_event(kind: StringName, peer_id: int) -> void:
	if not _is_host() or not EVENT_KINDS.has(kind):
		return
	if Net.is_online():
		_rpc_event.rpc(kind, peer_id)
	else:
		_rpc_event(kind, peer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_event(kind: StringName, peer_id: int) -> void:
	if not EVENT_KINDS.has(kind):
		return
	if _events.size() < MAX_EVENTS:
		_events.append(kind)
		_event_peers.append(peer_id)
	last_event = kind
	last_event_age = 0.0
	emit_signal(kind, peer_id)


## Bu peer'da görülen sonuç olayları (sırayla; en fazla MAX_EVENTS).
func events() -> Array[StringName]:
	return _events.duplicate()


func dump_state() -> Dictionary:
	var out := {
		"state": OwnerBrain.STATE_NAMES[clampi(net_state, 0, OwnerBrain.STATE_NAMES.size() - 1)],
		"task": net_task,
		"alarmed": net_alarmed,
		"events": _events.duplicate(),
		"event_peers": _event_peers.duplicate(),
		"bubbles": _bubbles.duplicate(),
		"talk_peer": _talk.busy_by,
		"talk_gaze": snappedf(talk_gaze(), 0.01),
		"facing": [snappedf(facing.x, 0.01), snappedf(facing.y, 0.01)],
		"shouted": net_shouted,
		"misdirected": net_misdirected,
	}
	if _is_host():
		var states: Array = _brain.fsm.history_rows(OwnerBrain.STATE_NAMES)
		var peaks: Dictionary = {}
		for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
			peaks[str(node.get_multiplayer_authority())] = 0.0  # hiç ölçeri olmayan oyuncu da 0 görünsün
		for peer_id: int in _brain.peaks:
			peaks[str(peer_id)] = snappedf(float(_brain.peaks[peer_id]), 0.01)
		out["detections"] = _brain.detections.duplicate(true)
		out["peak"] = peaks
		out["agenda"] = _agenda.sequence.duplicate()
		out["states"] = states
		out["rescues"] = _brain.rescues.duplicate(true)
		out["shout_noises"] = _brain.shout_noises
		out["agenda_noises"] = _brain.agenda_noises.duplicate()
		out["discoveries"] = _brain.discoveries.duplicate(true)
		out["serves"] = _brain.serves_done
		out["register_opens"] = _brain.register_opens
		out["loiter_s"] = _senses.loiter_dump()
		out["player_serves"] = _brain.player_serves
		out["sent_windows"] = _brain.sent_windows.duplicate()
		out["distractions"] = _brain.distractions.count
		out["phones_found"] = _brain.phones_found
		out["soothed"] = _brain.soothed.duplicate(true)
		out["misdirects"] = misdirects.duplicate(true)
		out["window_questions"] = _brain.window_questions.duplicate()
	return out


func _publish() -> void:
	net_position = position
	facing = _perception.facing
	net_facing = facing
	net_state = _brain.state()
	net_task = _agenda.task_name() if _brain.state() == OwnerBrain.State.AGENDA else &""
	net_alarmed = _brain.is_alarmed()
	net_hold_peer = _brain.held_peer()
	net_shouted = net_shouted or _brain.has_shouted
	var top: float = 0.0
	for peer_id: int in _suspicion.peers():
		top = maxf(top, _suspicion.value_of(peer_id))
	net_meter = SuspicionMeter.MAX_VALUE if net_alarmed else top


func _follow(delta: float) -> void:
	if position.distance_to(net_position) > SNAP_PX:
		position = net_position
	else:
		position = position.lerp(net_position, 1.0 - exp(-SMOOTHING * delta))
	if not net_facing.is_zero_approx():
		facing = facing.slerp(net_facing.normalized(), 1.0 - exp(-SMOOTHING * delta)).normalized()


func _set_task(value: StringName) -> void:
	if value == net_task:
		return
	net_task = value
	task_changed.emit(value)


## OYALA bileşeni (US-010): değerler StoreToolsTuning'den; sahip etkin değilse hiç açılmaz.
func _setup_talk() -> void:
	var tools: StoreToolsTuning = StoreToolsTuning.load_default()
	_talk.action_key = TALK_ACTION_KEY
	_talk.hold_time = tools.talk_max_sec
	_talk.interact_range = tools.talk_range
	_talk.innocent = true
	_refresh_talk()


## Her peer'da çoğaltılan durumdan: sakin durumlarda (ajanda, BAK, SORGU; servis ve gönderilme dışında), bağırmadan
## önce konuşulur.
func _refresh_talk() -> void:
	_talk.enabled = active and not net_shouted and TALK_STATES.has(net_state) \
		and not TALK_CLOSED_TASKS.has(net_task) and not misdirect_open()


## YÖNLENDİR bileşeni (US-043): E, basılı tut, menzil; masum eylem; yalnız örtüsü sağlam oyuncu (etiket `cover`).
func _setup_misdirect() -> void:
	var tools: StoreToolsTuning = StoreToolsTuning.load_default()
	setup_misdirect_item(_misdirect, tools)
	_misdirect.completed.connect(func(peer_id: int) -> void: misdirect(peer_id))
	_refresh_misdirect()


## Sahip ve mahallelinin YÖNLENDİR bileşeni aynı ayarla kurulur.
static func setup_misdirect_item(item: Interactable, tools: StoreToolsTuning) -> void:
	item.action_key = MISDIRECT_ACTION_KEY
	item.hold_time = tools.misdirect_hold_sec
	item.interact_range = tools.misdirect_range
	item.innocent = true
	var need := InteractionRequirement.new()
	need.required_tag = COVER_TAG
	item.requirement = need


func _refresh_misdirect() -> void:
	_misdirect.enabled = misdirect_open()


## İşitme bileşeni: sahnede `Hearing` yoksa genel sınıf varsa kurulur (US-009 birleşince kod değişmez).
func _bind_hearing() -> void:
	var hearing: Node = get_node_or_null(NodePath(String(HEARING_CLASS)))
	if hearing == null:
		var script: GDScript = _global_script(HEARING_CLASS) as GDScript
		if script != null and script.can_instantiate():
			hearing = script.new() as Node
			if hearing != null:
				hearing.name = String(HEARING_CLASS)
				add_child(hearing)
	if hearing != null and &"corner_spread_px" in hearing:
		hearing.set(&"corner_spread_px", owner_tuning.hearing_corner_px)  # US-010: raf ucu sesi köşeden
	if hearing != null and hearing.has_signal(&"heard"):
		hearing.connect(&"heard", _brain.hear)


static func _global_script(cls: StringName) -> Script:
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(info.get("class", "")) == cls:
			return load(str(info["path"])) as Script
	return null


## En yakın Level API'li ata (S4; duck typing).
func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"marker"):
		node = node.get_parent()
	return node


func _is_host() -> bool:
	return _host_side()


## Host ya da çevrimdışı (S2). Net bayraklarından okunur: kopuş anında (döküm, son kareler) kapanmış taşımaya
## `multiplayer.is_server()` sorup hata basmasın (Game ile aynı kalıp).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
