class_name Door
extends Node2D
## Kapı (US-005 AC3; mimari.md S7, S4): `data/props/door.tres`. Anında aç/kapa (basılı tutma yok); kapalıyken
## `Body` (StaticBody2D, katman world) geçişi engeller, açıkken engel yok. Konum = S4 kapı işareti (1 karoluk
## boşluğun merkezi); dönüş 0° yatay duvarda, 90° dikey duvarda (kanat yerel x ekseni boyunca).
## Durum (`is_open`, host'un duvar saatiyle `changed_at`) host yetkili MultiplayerSynchronizer ile değişince
## yayılır; başlangıç durumu sahnede `is_open` (ör. ön kapı mesai saatinde açık). Görsel yalnız durumu okur.
## Kapanma engeli (IS-014): açık kapı, kapanınca kanadı (Body şekli) players katmanındaki bir aktörün gövdesiyle
## örtüşecekse kapanmaz: host isteği `blocked` ile reddeder (istem görünür kalır). Oyuncu gövdesi host'un bildiği
## en güncel konumda (`interaction_position()`; ~100 ms geriden çizilen konum sayılmaz — US-008 / IS-014 nit)
## denenir; yarıçap gövdenin daire şeklinden (yoksa 0). NPC gövdeleri (npcs katmanı; konumları host'ta yetkili)
## de engeldir (US-008). Açma her zaman serbest. Kural: InteractionRules.circle_overlaps_box.
## Gezinme bağı (US-008, S4 eki): kapı durumu seviyenin aynı adlı `door_link`'ine yazılır (kapalı kapıdan yol
## geçmez); seviye API'si yoksa (test_arena gibi bağı olmayan seviye ya da seviye dışı) atlanır.
## Döküm (S6 "props"): {"open", "flips" (bu süreçte görülen durum değişimi), "visible_delay_ms" (son değişimin
## host kararından bu süreçte görünmesine; değişim yoksa -1), "consistent" (son durum = başlangıç durumu +
## görülen değişim sayısının paritesi: bu süreç her değişimi gördü), "interact": Interactable.stats()}.
## Gürültü (US-009, S8): host her açma/kapamada kapı konumunda `NoiseProfile.KIND_DOOR` sesi yayar.
## NPC kapatması (IS-087 AC2): NPC kapıyı yalnız `host_close_by_npc(actor_pos)` ile kapatır (iç kapıyı arkasından);
## aynı Interactable NPC yolundan geçer (menzil + S2 payı, tekrar beklemesi, kanat engeli `is_closing_blocked`).

const DEF_PATH := "res://data/props/door.tres"
## Kapanmayı engelleyen gövdelerin fizik katmanı: players (mimari.md §4, 2. katman).
const BLOCKER_LAYERS := PhysicsLayers.PLAYERS
## Kapanmayı engelleyen NPC gövdeleri: npcs (mimari.md §4, 3. katman; US-008).
const NPC_LAYERS := PhysicsLayers.NPCS

@export var def: PropDef

## Çoğaltılan durum (host yazar); sahnedeki değer başlangıç durumudur.
@export var is_open: bool = false:
	set = _set_open
var changed_at: float = 0.0

var _flips: int = 0
## host_close_by_npc sürerken true: NPC tamamlaması (peer 0) kapatabilir.
var _npc_closing: bool = false
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
	SfxEmitter.of(self)  # IS-024: ilk eşitleme (taban durum) sessiz kalsın diye çalar baştan kurulur
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
		var spot: Vector2 = body.global_position
		if body.has_method(&"interaction_position"):
			var latest: Variant = body.call(&"interaction_position")
			if latest is Vector2:
				spot = latest
		if InteractionRules.circle_overlaps_box(spot, _body_radius(body), center, half, angle):
			return true
	return _npc_in_leaf(leaf, center, angle)


## Kanadın yerinde npcs katmanında bir gövde var mı (fizik sorgusu; NPC konumu host'ta yetkili).
func _npc_in_leaf(leaf: RectangleShape2D, center: Vector2, angle: float) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = leaf
	query.transform = Transform2D(angle, _shape.global_scale.abs(), 0.0, center)
	query.collision_mask = NPC_LAYERS
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


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
		"sfx": SfxEmitter.of(self).stats(),
	}


## Yalnız host: NPC açık kapıyı kapatır (IS-087 AC2; `actor_pos` NPC konumu). Kapandıysa true; kapı kapalıysa,
## NPC menzil dışındaysa ya da kanat bir gövdeye değecekse false.
func host_close_by_npc(actor_pos: Vector2) -> bool:
	if not is_open:
		return false
	_npc_closing = true
	var done: bool = _interactable.host_use_by_npc(actor_pos)
	_npc_closing = false
	return done and not is_open


## Yalnız host'ta (Interactable.completed). NPC (peer 0) kapıyı açar; açık kapıya yalnız host_close_by_npc içinde
## dokunur (US-008 t2, IS-087).
func _on_completed(peer_id: int) -> void:
	if peer_id == 0 and is_open and not _npc_closing:
		return
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
	SfxEmitter.play_on_change(self, &"door_open" if is_open else &"door_close")  # IS-024: yerel ses


## `deferred`: fizik geri çağrısı ya da ağ eşitlemesi sırasında şekil bir sonraki boşta değişir.
func _apply(deferred: bool) -> void:
	if deferred:
		_shape.set_deferred(&"disabled", is_open)
	else:
		_shape.disabled = is_open
	var alt: String = def.alt_action_key if not def.alt_action_key.is_empty() else def.action_key
	_interactable.action_key = alt if is_open else def.action_key
	_sync_nav_link()


## Kapı durumunu seviyenin gezinme bağına yazar (Level.door_link, S4 eki; duck typing: entities levels/'i bilmez).
func _sync_nav_link() -> void:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"door_link"):
		node = node.get_parent()
	if node == null:
		return
	var link: NavigationLink2D = node.call(&"door_link", StringName(name)) as NavigationLink2D
	if link != null:
		link.enabled = is_open
