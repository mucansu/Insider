class_name Chaser
extends CharacterBody2D
## Mahalleli (US-008 AC6; GDD §9.3; KR-021, ON-08): sahip bağırınca bakkalın uyarı yöneticisi (`StoreAlert`)
## `NeighbourSpawn`'da üretir (MultiplayerSpawner, host; özel spawn_function konumu ve koşu hedefini verir).
## Kök CharacterBody2D (katman npcs, maske world: oyuncuları itmez); bileşenler `Perception` (yalnız görüş
## hattı), `Mover`, `Senses`, `Brain` (ChaserBrain) ve `Visual`. Host: beyin + ivmeli hareket + yayın (15 Hz,
## konum/yön güvenilmez, durum güvenilir); istemci yumuşatarak izler. Görsel her zaman "!" gösterir.
## Döküm: StoreAlert "chasers" anahtarında.
## US-043: `Misdirect` Interactable (YÖNLENDİR "o tarafa kaçtı!"; sahibinkiyle aynı ayar, etiket `cover`); her peer'da
## sahibin `misdirect_open()`ından etkin; tamamlanınca host sahibin `misdirect(peer)`ini çağırır. Tutulurken mahalleli
## durur (beyin `listening`). `mislead(nokta, sn)` host API'si (sahip çağırır).

const TUNING_PATH := "res://data/npc/chaser_tuning.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const SMOOTHING := 14.0
const SNAP_PX := 96.0

@export var tuning: ChaserTuning
@export var civilian_tuning: CivilianTuning
@export var auto_step: bool = true

## Çoğaltılan durum (host yazar).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.LEFT
var net_state: int = 0

## Görselin okuduğu durum.
var facing: Vector2 = Vector2.LEFT
var bubble: int = CivilianRules.Bubble.ALARM
## Koşu hedefi (spawn verisi; host).
var goal: Vector2 = Vector2.INF

@onready var _perception: Perception = $Perception
@onready var _mover: NpcMover = $Mover
@onready var _senses: CivilianSenses = $Senses
@onready var _brain: ChaserBrain = $Brain
@onready var _misdirect: Interactable = $Misdirect


func _ready() -> void:
	if tuning == null:
		tuning = load(TUNING_PATH) as ChaserTuning
	if civilian_tuning == null:
		civilian_tuning = load(CIVILIAN_TUNING_PATH) as CivilianTuning
	net_position = position
	StoreOwner.setup_misdirect_item(_misdirect, StoreToolsTuning.load_default())
	_misdirect.completed.connect(_on_misdirect)
	_refresh_misdirect()
	if _host_side():
		_senses.setup(_level(), civilian_tuning, _perception.tuning)
		_brain.tuning = tuning
		_brain.civilian_tuning = civilian_tuning
		_brain.cover_query = _cover_intact
		_brain.setup(self, _perception, _mover, _senses, goal if goal.is_finite() else global_position)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(delta: float) -> void:
	_refresh_misdirect()
	if _host_side():
		_brain.listening = _misdirect.busy_by != 0
		var want: Vector2 = _brain.step(delta)
		velocity = velocity.move_toward(want, tuning.acceleration * delta)
		move_and_slide()
		if velocity.length() > 1.0:
			facing = velocity.normalized()
		net_position = position
		net_facing = facing
		net_state = _brain.fsm.state
		return
	if position.distance_to(net_position) > SNAP_PX:
		position = net_position
	else:
		position = position.lerp(net_position, 1.0 - exp(-SMOOTHING * delta))
	if not net_facing.is_zero_approx():
		facing = facing.slerp(net_facing.normalized(), 1.0 - exp(-SMOOTHING * delta)).normalized()


func brain() -> ChaserBrain:
	return _brain


## Host API (US-043): yanlış yöne koşturulur; kabul edilirse true.
func mislead(point: Vector2, sec: float) -> bool:
	return _brain.mislead(point, sec) if _host_side() else false


func misdirect_interactable() -> Interactable:
	return _misdirect


## Bakkal sahibi (S4 `npcs_root` altında `misdirect` sunan); yoksa null.
func shop_owner() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for node: Node in parent.get_children():
		if node.has_method(&"misdirect"):
			return node
	return null


## Oyuncunun örtüsü sağlam mı (sahibin duyusundan; sahip yoksa false: herkes kovalanır).
func _cover_intact(peer_id: int) -> bool:
	var o: Node = shop_owner()
	if o == null or not o.has_method(&"senses"):
		return false
	var senses: CivilianSenses = o.call(&"senses") as CivilianSenses
	return senses != null and senses.cover_intact(peer_id)


func _refresh_misdirect() -> void:
	var o: Node = shop_owner()
	_misdirect.enabled = o != null and bool(o.call(&"misdirect_open"))


func _on_misdirect(peer_id: int) -> void:
	var o: Node = shop_owner()
	if o != null:
		o.call(&"misdirect", peer_id)


func state_name() -> StringName:
	return ChaserBrain.STATE_NAMES[clampi(net_state, 0, ChaserBrain.STATE_NAMES.size() - 1)]


func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"marker"):
		node = node.get_parent()
	return node


## Host ya da çevrimdışı (S2). Net bayraklarından okunur: kopuş anında (döküm, son kareler) kapanmış taşımaya
## `multiplayer.is_server()` sorup hata basmasın (Game ile aynı kalıp).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
