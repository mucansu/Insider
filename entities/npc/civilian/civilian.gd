class_name Civilian
extends CharacterBody2D
## Sivil (US-016; GDD §9.2 "Mekân nüfusu"; mimari.md S2, S11): müşteri ya da yoldan geçen. Nüfus üreticisi
## (`Population`, yalnız host) `PopulationSpawner` (MultiplayerSpawner, spawn_path = NPCs) ile üretir ve siler;
## istemciler spawner'dan alır (geç katılan mevcut sivilleri ilk paketle görür). Kök CharacterBody2D (katman
## npcs, maske world: oyuncuları itmez, oyuncular da onu itmez — AC7; iç içe geçince görsel yarı saydam). Bileşenler
## `Perception` + `Suspicion` (sivil çarpan tablosu, `CivilianSenses.factor_for`), `Agenda` (lineer rota kipi),
## `Mover`, `Senses`, `Brain` (CivilianBrain) ve görsel `Visual` (NpcVisual; "?"/"!" ve balon).
##
## Host: beyin + hareket + yayın. Çoğaltma (S11 kalıbı, 15 Hz): konum/yön/ölçer güvenilmez sürekli, durum
## değişince güvenilir; rol ve sıra numarası spawn verisinde. Sonuç olayları (`customer_enter`, `customer_tell`,
## `customer_flee`, `passerby_tell`, `passerby_flee`; AC5, SFX adları) güvenilir RPC ile her peer'da aynı sırada
## `event_raised` sinyali olur (Population dökümü toplar). İstemci konumu yumuşatarak izler.

## Her peer'da: sonuç olayı (kind, ilgili oyuncu; yoksa 0).
signal event_raised(civilian: Civilian, kind: StringName, peer_id: int)

const TUNING_PATH := "res://data/npc/population.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const EVENT_KINDS: Array[StringName] = [&"customer_enter", &"customer_tell", &"customer_flee", &"passerby_tell",
	&"passerby_flee"]
const SMOOTHING := 14.0
const SNAP_PX := 96.0
const MAX_EVENTS := 32

@export var tuning: PopulationTuning
@export var civilian_tuning: CivilianTuning
## false: testler `step()`'i elle sürer.
@export var auto_step: bool = true

## Spawn verisi (her peer'da): rol (PopulationRules.Role) ve sıra numarası (registry sahibi kimliği).
var role: int = PopulationRules.Role.CUSTOMER
var serial: int = 0
## Yalnız host: üretim siparişi ve plan (Population verir), sahip ve nüfus üreticisi.
var order: PopulationRules.Order = null
var shop_spots: Array[StringName] = []
var population: Node = null
var store_owner: Node = null

## Çoğaltılan durum (host yazar).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.DOWN
var net_meter: float = 0.0
var net_state: int = 0

## Görselin okuduğu durum (her peer'da).
var facing: Vector2 = Vector2.DOWN
var bubble: int = CivilianRules.Bubble.NONE
var last_event: StringName = &""
var last_event_age: float = INF

var _rules: CivilianRules.Params = null
var _events: Array[StringName] = []
var _bubbles: Array[int] = []

@onready var _perception: Perception = $Perception
@onready var _suspicion: Suspicion = $Suspicion
@onready var _agenda: Agenda = $Agenda
@onready var _mover: NpcMover = $Mover
@onready var _senses: CivilianSenses = $Senses
@onready var _brain: CivilianBrain = $Brain
@onready var _visual: NpcVisual = $Visual


func _ready() -> void:
	_suspicion.set_physics_process(false)  # beyin sırayla işletir
	if tuning == null:
		tuning = load(TUNING_PATH) as PopulationTuning
	if civilian_tuning == null:
		civilian_tuning = load(CIVILIAN_TUNING_PATH) as CivilianTuning
	_rules = civilian_tuning.rules_params(_perception.tuning)
	_visual.role = NpcVisual.Role.PASSERBY if role == PopulationRules.Role.PASSERBY else NpcVisual.Role.CUSTOMER
	net_position = position
	if _host_side():
		_perception.set_cone(cone_half_angle(), cone_range())
		_senses.setup(_level(), civilian_tuning, _perception.tuning)
		_brain.tuning = tuning
		_brain.civilian_tuning = civilian_tuning
		_brain.setup(self, _perception, _suspicion, _agenda, _mover, _senses)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(delta: float) -> void:
	if _host_side():
		velocity = _brain.step(delta)
		move_and_slide()
		net_position = position
		facing = _perception.facing
		net_facing = facing
		net_state = _brain.fsm.state
		var top: float = 0.0
		for peer_id: int in _suspicion.peers():
			top = maxf(top, _suspicion.value_of(peer_id))
		net_meter = top
	else:
		if position.distance_to(net_position) > SNAP_PX:
			position = net_position
		else:
			position = position.lerp(net_position, 1.0 - exp(-SMOOTHING * delta))
		if not net_facing.is_zero_approx():
			facing = facing.slerp(net_facing.normalized(), 1.0 - exp(-SMOOTHING * delta)).normalized()
	last_event_age += delta
	var next: int = CivilianRules.bubble(_rules, net_meter, false, bubble)
	if next != bubble:
		bubble = next
		_bubbles.append(next)


func brain() -> CivilianBrain:
	return _brain


func agenda() -> Agenda:
	return _agenda


func perception() -> Perception:
	return _perception


func suspicion() -> Suspicion:
	return _suspicion


func senses() -> CivilianSenses:
	return _senses


func role_name() -> StringName:
	return PopulationRules.role_name(role)


## Çoğaltılan durumun adı (CivilianBrain.State).
func state_name() -> StringName:
	return CivilianBrain.STATE_NAMES[clampi(net_state, 0, CivilianBrain.STATE_NAMES.size() - 1)]


func is_customer() -> bool:
	return role == PopulationRules.Role.CUSTOMER


## Görselin konisi (derece, px): rolün konisi.
func cone_half_angle() -> float:
	return tuning.passerby_half_angle_deg if role == PopulationRules.Role.PASSERBY else tuning.customer_half_angle_deg


func cone_range() -> float:
	return tuning.passerby_view_range if role == PopulationRules.Role.PASSERBY else tuning.customer_view_range


## Host: sonuç olayını herkese yayar (her peer'da aynı sırada).
func host_event(kind: StringName, peer_id: int) -> void:
	if not _host_side() or not EVENT_KINDS.has(kind):
		return
	if Net.is_online() and is_inside_tree():
		_rpc_event.rpc(kind, peer_id)
	else:
		_rpc_event(kind, peer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_event(kind: StringName, peer_id: int) -> void:
	if not EVENT_KINDS.has(kind):
		return
	if _events.size() < MAX_EVENTS:
		_events.append(kind)
	last_event = kind
	last_event_age = 0.0
	event_raised.emit(self, kind, peer_id)


func events() -> Array[StringName]:
	return _events.duplicate()


func dump_row() -> Dictionary:
	return {"name": String(name), "role": role_name(), "state": state_name(), "events": _events.duplicate()}


## En yakın Level API'li ata (S4; duck typing).
func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"marker"):
		node = node.get_parent()
	return node


## Host ya da çevrimdışı (S2; Net bayraklarından, Game ile aynı kalıp).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
