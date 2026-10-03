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
## peak, agenda, states, rescues}.

signal owner_question(peer_id: int)
signal owner_shrug(peer_id: int)
signal owner_shout(peer_id: int)
signal owner_held(peer_id: int)
signal owner_stagger(peer_id: int)
## Her peer'da: görev değişti (çoğaltılan; görev ikonu US-011).
signal task_changed(task_name: StringName)

const OWNER_TUNING_PATH := "res://data/npc/owner_tuning.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const DUMP_KEY := "owner"
const EVENT_KINDS: Array[StringName] = [&"owner_question", &"owner_shrug", &"owner_shout", &"owner_held",
	&"owner_stagger"]
## İstemci yumuşatması (1/sn) ve sıçrama eşiği (px).
const SMOOTHING := 14.0
const SNAP_PX := 96.0
const HEARING_CLASS := &"Hearing"
## Dökümde tutulan en fazla olay.
const MAX_EVENTS := 128

@export var owner_tuning: OwnerTuning
@export var civilian_tuning: CivilianTuning
## false: testler `step()`'i elle sürer.
@export var auto_step: bool = true
## false: sahip yok sayılır (gizli, çarpışmasız, işlemez; NPC'siz etkileşim senaryoları için fikstür).
@export var active: bool = true

## Çoğaltılan durum (host yazar).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.LEFT
var net_meter: float = 0.0
var net_state: int = 0
var net_task: StringName = &"":
	set = _set_task
var net_alarmed: bool = false
var net_hold_peer: int = 0

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


func _ready() -> void:
	_suspicion.set_physics_process(false)  # beyin sırayla işletir (etkin değilse hiç işlemez)
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


func suspicion() -> Suspicion:
	return _suspicion


func senses() -> CivilianSenses:
	return _senses


## Host API (AC4; US-010 OYALA): o oyuncuya şüpheyi değiştirir.
func apply_suspicion(peer_id: int, delta: float) -> void:
	_suspicion.apply_delta(peer_id, delta)


## Host API (US-016): müşteri kuyrukta.
func serve_customer() -> bool:
	return _brain.serve_customer() if _is_host() else false


## Host API (US-010): "arkada X var mı?".
func send_to_backroom() -> bool:
	return _brain.send_to_backroom() if _is_host() else false


## Host API (US-010 SATIN AL): oyalanma sayacı sıfır.
func reset_loiter(peer_id: int) -> void:
	_senses.reset_loiter(peer_id)


## Ajandanın tohumu (host; tek nokta). Şimdilik veriden (owner_tuning.agenda_seed); oturum tohumu
## (`Game.session_seed()`, `--seed=`) gelince onunla birleştirilir (IS-058).
func agenda_seed() -> int:
	return owner_tuning.agenda_seed


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


func dump_state() -> Dictionary:
	var out := {
		"state": OwnerBrain.STATE_NAMES[clampi(net_state, 0, OwnerBrain.STATE_NAMES.size() - 1)],
		"task": net_task,
		"alarmed": net_alarmed,
		"events": _events.duplicate(),
		"event_peers": _event_peers.duplicate(),
		"bubbles": _bubbles.duplicate(),
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
	return out


func _publish() -> void:
	net_position = position
	facing = _perception.facing
	net_facing = facing
	net_state = _brain.state()
	net_task = _agenda.task_name() if _brain.state() == OwnerBrain.State.AGENDA else &""
	net_alarmed = _brain.is_alarmed()
	net_hold_peer = _brain.held_peer()
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
