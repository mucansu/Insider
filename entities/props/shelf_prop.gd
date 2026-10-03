class_name ShelfProp
extends Node2D
## Raf ucu (US-010 AC5 DİKKAT DAĞIT; GDD §9.3, KR-026; mimari.md S2, S7, S8). store_a `ShelfProp1..3` işaretlerinde
## (`Props/ShelfProp<n>`). İki Interactable:
## - `Topple` (E, `interact`, anında, tek kullanımlık): ürünleri devirir → host `NoiseBus` gürültüsü
##   `StoreToolsTuning.KIND_TOPPLE` (`topple_radius` 320 px). Sahip tezgâhtayken (ClerkSpot) duyar → DİNLE (sese yürür,
##   yönü bu prop); arka odadan ve telefon başından duyulmaz (duvar ×0,5 / mesafe).
## - `Phone` (Q, `intimidate`, 0,5 sn tut): oyuncu telefonunu rafa bırakır (iş başına 1 telefon, bütün raf uçları
##   için; her peer kardeş prop'ların çoğaltılan durumundan türetir) → `phone_delay_sec` sonra çalar
##   (`KIND_CELLPHONE`, `phone_radius` 240 px; `phone_ring_interval_sec` aralıkla en çok `phone_ring_max` kez) →
##   sahip sese gider; DİNLE noktasına varınca telefonu bulur (`host_take_phone`), çalma biter.
## Durum (host yazar, çoğaltılır): `toppled`, `phone_state` (CivilianRules.Phone). Saat `CivilianRules.PhoneClock`'ta
## (düğümsüz). Sorumlu peer'lar yalnız host'ta (`distraction_peer(kind)`; sahibin "yine mi?" bedeli).
## Döküm (S6 "props"): {"toppled", "phone", "rings", "topple", "phone_drop"}.

const TOPPLE_DEF_PATH := "res://data/props/shelf_topple.tres"
const PHONE_DEF_PATH := "res://data/props/shelf_phone.tres"
const GROUP := &"shelf_props"

@export var topple_def: PropDef
@export var phone_def: PropDef
@export var tuning: StoreToolsTuning

## Çoğaltılan durum (host yazar).
var toppled: bool = false
var phone_state: int = CivilianRules.Phone.NONE

var _topple_peer: int = 0
var _clock: CivilianRules.PhoneClock = null

@onready var _topple: Interactable = $Topple
@onready var _phone: Interactable = $Phone


func _ready() -> void:
	if topple_def == null:
		topple_def = load(TOPPLE_DEF_PATH) as PropDef
	if phone_def == null:
		phone_def = load(PHONE_DEF_PATH) as PropDef
	if tuning == null:
		tuning = StoreToolsTuning.load_default()
	_setup(_topple, topple_def)
	_setup(_phone, phone_def)
	_phone.input_action = &"intimidate"
	_topple.completed.connect(_on_topple)
	_phone.completed.connect(_on_phone)
	_clock = CivilianRules.PhoneClock.new(tuning.phone_delay_sec, tuning.phone_ring_interval_sec, tuning.phone_ring_max)
	add_to_group(GROUP)
	_refresh()
	add_to_group(PropDump.GROUP)
	PropDump.register()


func _physics_process(delta: float) -> void:
	step(delta)


## Bir adım: host'ta telefon saati; her peer'da istem satırları.
func step(delta: float) -> void:
	if multiplayer.is_server() and _clock.state != CivilianRules.Phone.NONE:
		if _clock.step(delta):
			NoiseBus.emit_noise(global_position, tuning.phone_radius, StoreToolsTuning.KIND_CELLPHONE, _clock.peer)
		phone_state = _clock.state
	_refresh()


## Bu raf ucunda telefon bırakıldı mı (her peer; çoğaltılan durum).
func has_phone() -> bool:
	return phone_state != CivilianRules.Phone.NONE


## Telefon çalıyor mu (her peer).
func is_ringing() -> bool:
	return phone_state == CivilianRules.Phone.RINGING


## Yalnız host: dikkat dağıtmanın sorumlusu (tür: KIND_TOPPLE / KIND_CELLPHONE); yoksa 0.
func distraction_peer(kind: StringName) -> int:
	if kind == StoreToolsTuning.KIND_TOPPLE:
		return _topple_peer
	if kind == StoreToolsTuning.KIND_CELLPHONE and _clock != null:
		return _clock.peer
	return 0


## Yalnız host: sahip telefonu buldu (çalıyorsa ya da çalmayı bitirdiyse). Alındıysa true.
func host_take_phone() -> bool:
	if not multiplayer.is_server() or not _clock.take():
		return false
	phone_state = _clock.state
	return true


func dump_state() -> Dictionary:
	return {
		"toppled": toppled,
		"phone": CivilianRules.PHONE_NAMES[clampi(phone_state, 0, CivilianRules.PHONE_NAMES.size() - 1)],
		"rings": _clock.rings if _clock != null else 0,
		"topple": _topple.stats(),
		"phone_drop": _phone.stats(),
	}


## İstem satırları (her peer): devirme tek kullanımlık; telefon iş başına bir (hiçbir raf ucunda yokken).
func _refresh() -> void:
	_topple.enabled = not toppled
	_phone.enabled = not _any_phone()


func _any_phone() -> bool:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method(&"has_phone") and bool(node.call(&"has_phone")):
			return true
	return false


## Yalnız host (Interactable.completed).
func _on_topple(peer_id: int) -> void:
	if toppled:
		return
	toppled = true
	_topple_peer = peer_id
	_refresh()
	NoiseBus.emit_noise(global_position, tuning.topple_radius, StoreToolsTuning.KIND_TOPPLE, peer_id)


## Yalnız host (Interactable.completed).
func _on_phone(peer_id: int) -> void:
	if _any_phone() or not _clock.plant(peer_id):
		return
	phone_state = _clock.state
	_refresh()


static func _setup(item: Interactable, def: PropDef) -> void:
	item.action_key = def.action_key
	item.hold_time = def.hold_time
	item.interact_range = def.interact_range
	item.requirement = def.requirement
