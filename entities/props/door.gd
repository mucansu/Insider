class_name Door
extends Node2D
## Kapı (US-005 AC3; mimari.md S7, S4): `data/props/door.tres`. Anında aç/kapa (basılı tutma yok); kapalıyken
## `Body` (StaticBody2D, katman world) geçişi engeller, açıkken engel yok. Konum = S4 kapı işareti (1 karoluk
## boşluğun merkezi); dönüş 0° yatay duvarda, 90° dikey duvarda (kanat yerel x ekseni boyunca).
## Durum (`is_open`, host'un duvar saatiyle `changed_at`) host yetkili MultiplayerSynchronizer ile değişince
## yayılır; başlangıç durumu sahnede `is_open` (ör. ön kapı mesai saatinde açık). Görsel yalnız durumu okur.
## Kapanma engeli (IS-014): açık kapı, kapanınca kanadı (Body şekli) players katmanındaki bir aktörün gövdesiyle
## örtüşecekse kapanmaz: host isteği `blocked` ile reddeder (istem görünür kalır). Gövde, host'un bildiği iki
## konumda denenir: çizilen (`global_position`) ve en güncel (`interaction_position()`); yarıçap gövdenin daire
## şeklinden (yoksa 0). Açma her zaman serbest. Kural: InteractionRules.circle_overlaps_box.
## Döküm (S6 "props"): {"open", "flips" (bu süreçte görülen durum değişimi), "visible_delay_ms" (son değişimin
## host kararından bu süreçte görünmesine; değişim yoksa -1), "consistent" (son durum = başlangıç durumu +
## görülen değişim sayısının paritesi: bu süreç her değişimi gördü), "interact": Interactable.stats()}.
## Gürültü (US-009, S8): host her açma/kapamada kapı konumunda `NoiseProfile.KIND_DOOR` sesi yayar.

const DEF_PATH := "res://data/props/door.tres"
## Kapanmayı engelleyen gövdelerin fizik katmanı: players (mimari.md §4, 2. katman).
const BLOCKER_LAYERS := 1 << 1

@export var def: PropDef

## Çoğaltılan durum (host yazar); sahnedeki değer başlangıç durumudur.
@export var is_open: bool = false:
	set = _set_open
var changed_at: float = 0.0

var _flips: int = 0
var _start_open: bool = false
var _seen_at: float = -1.0

@onready var _interactable: Interactable = $Interactable
@onready var _shape: CollisionShape2D = $Body/CollisionShape2D


func _ready() -> void:
	if def == null:
		push_error("Door: def atanmamış; %s yükleniyor" % DEF_PATH)
		def = load(DEF_PATH) as PropDef
	_interactable.hold_time = def.hold_time
	_interactable.interact_range = def.interact_range
	_interactable.requirement = def.requirement
	_interactable.completed.connect(_on_completed)
	_interactable.start_blocker = is_closing_blocked
	_start_open = is_open
	_apply(false)
	add_to_group(PropDump.GROUP)
	PropDump.register()


## Kanat şu an geçişi engelliyor mu (fizik durumu; açılıp kapanma bir sonraki fizik adımında işler).
func is_blocking() -> bool:
	return not _shape.disabled


## Açık kapı şimdi kapansa kanat bir oyuncu gövdesine çarpar mı (kapalıyken her zaman false: açma serbest).
func is_closing_blocked() -> bool:
	if not is_open:
		return false
	var leaf: RectangleShape2D = _shape.shape as RectangleShape2D
	if leaf == null:
		return false
	var half: Vector2 = leaf.size * 0.5 * _shape.global_scale.abs()
	var center: Vector2 = _shape.global_position
	var angle: float = _shape.global_rotation
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		var body: CollisionObject2D = node as CollisionObject2D
		if body == null or (body.collision_layer & BLOCKER_LAYERS) == 0:
			continue
		var radius: float = _body_radius(body)
		var spots: Array[Vector2] = [body.global_position]
		if body.has_method(&"interaction_position"):
			var latest: Variant = body.call(&"interaction_position")
			if latest is Vector2:
				spots.append(latest)
		for spot: Vector2 in spots:
			if InteractionRules.circle_overlaps_box(spot, radius, center, half, angle):
				return true
	return false


## Gövdenin (genel fizik API'si: şekil sahipleri) ilk daire şeklinin yarıçapı; daire yoksa 0 (nokta).
static func _body_radius(body: CollisionObject2D) -> float:
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		for i: int in body.shape_owner_get_shape_count(owner_id):
			var circle: CircleShape2D = body.shape_owner_get_shape(owner_id, i) as CircleShape2D
			if circle != null:
				return circle.radius
	return 0.0


func dump_state() -> Dictionary:
	return {
		"open": is_open,
		"flips": _flips,
		"consistent": is_open == (_start_open != (_flips % 2 == 1)),
		"visible_delay_ms": (_seen_at - changed_at) * 1000.0 if _seen_at >= 0.0 else -1.0,
		"interact": _interactable.stats(),
	}


## Yalnız host'ta (Interactable.completed).
func _on_completed(peer_id: int) -> void:
	changed_at = PropDump.wall_time()
	is_open = not is_open
	var noise: NoiseProfile = NoiseProfile.load_default()
	NoiseBus.emit_noise(global_position, noise.radius_for(NoiseProfile.KIND_DOOR), NoiseProfile.KIND_DOOR, peer_id)


func _set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if not is_node_ready():
		return  # sahne yüklenirken başlangıç değeri: değişim sayılmaz
	_flips += 1
	_seen_at = PropDump.wall_time()
	_apply(true)


## `deferred`: fizik geri çağrısı ya da ağ eşitlemesi sırasında şekil bir sonraki boşta değişir.
func _apply(deferred: bool) -> void:
	if deferred:
		_shape.set_deferred(&"disabled", is_open)
	else:
		_shape.disabled = is_open
	var alt: String = def.alt_action_key if not def.alt_action_key.is_empty() else def.action_key
	_interactable.action_key = alt if is_open else def.action_key
