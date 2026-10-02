class_name Perception
extends Node2D
## Algı bileşeni (US-006 AC2; mimari.md S2, S11, §4, KR-019): NPC'nin (muhafız, kamera, ileride sivil) alt
## düğümü. Görüş konisi + görüş hattı → hedef başına görünürlük ve şüphe dolumu. Kurallar core/'da
## (`PerceptionRules`); burada yalnız fizik sorgusu ve hedeflerin durumunu okuma var.
##
## - Konum: bu düğümün global konumu; bakış yönü `facing` (global, birim). Beyin yönü doğrudan yazar ya da
##   `turn_toward()` ile dönüş tavanına (tuning) uyarak döndürür.
## - Hedefler: `Interactable.ACTOR_GROUP` (`interaction_actors`) grubundaki oyuncular. Kimlik = düğümün yetkili
##   peer'ı; konum = `interaction_position()` (host'un bildiği en güncel konum, S7); hareket kipi = `net_mode`
##   (eşitleyicinin en güncel değeri; uzak kopyanın ~100 ms geriden ara değerlenen `move_mode`'u değil), yoksa
##   `move_mode`, o da yoksa yürüme (PlayerMotion.Mode).
## - Görüş hattı: world (1) + vision_block (6) katmanlarına ışın; `see_through` grubundaki **gövdeler**
##   (US-007: her `Window*` ayrı gövde, S4 eki) geçilir, raflar ve duvarlar keser (K1). Grup yalnız gövde
##   düzeyinde geçerlidir: ortak bir gövdenin gruptaki şekli görüşü keser. Oyuncu ve NPC gövdeleri maskede değil.
## - Karanlık: `dark_query` (Callable(pos: Vector2) -> bool) verilmişse sorulur; yoksa her yer aydınlık
##   (karanlık bölge seviyede henüz yok).
## - Yalnız host'ta anlamlıdır (S2): `Suspicion` bileşeni `observe()`'u yalnız host'ta çağırır; bu düğüm kendi
##   başına işlem yapmaz.

## Gözlemci türü: koni ayarını seçer.
enum Observer { GUARD, CAMERA }

const TUNING_PATH := "res://data/npc/perception_tuning.tres"
## Görüşü geçiren gövde grubu (S4/S11 eki; US-007 camları bu gruba koyar).
const SEE_THROUGH_GROUP := PhysicsLayers.SEE_THROUGH_GROUP
## Görüşü kesen fizik katmanları: world (1) ve vision_block (6) (mimari.md §4).
const SIGHT_MASK := PhysicsLayers.SIGHT_MASK
## Bir ışında en fazla kaç görüşü geçiren engel atlanır (sonsuz döngü bekçisi).
const MAX_SEE_THROUGH := 8


## Bir hedefin bu karedeki gözlemi.
class Observation:
	extends RefCounted
	var peer_id: int = 0
	var position: Vector2 = Vector2.ZERO
	var band: PerceptionRules.Band = PerceptionRules.Band.NONE
	## Görüş hattı açık mı (koni dışındaysa sorgulanmaz, false).
	var line_clear: bool = false
	var stance: PerceptionRules.Stance = PerceptionRules.Stance.WALK
	var in_dark: bool = false
	## Şüphe dolumu (birim/sn); 0 = görülmüyor.
	var rate: float = 0.0


@export var tuning: PerceptionTuning
@export var observer: Observer = Observer.GUARD
## Global bakış yönü (birim).
@export var facing: Vector2 = Vector2.RIGHT
## Karanlık bölge sorgusu: func(pos: Vector2) -> bool. Boşsa aydınlık.
var dark_query: Callable = Callable()

var _params: PerceptionRules.Params = null


func _ready() -> void:
	refresh()


## Tuning'den core algı ayarları (gözlemci türüne göre koni).
static func params_for(source: PerceptionTuning, kind: Observer) -> PerceptionRules.Params:
	var p := PerceptionRules.Params.new()
	match kind:
		Observer.CAMERA:
			p.half_angle_deg = source.camera_half_angle_deg
			p.view_range = source.camera_view_range
		_:
			p.half_angle_deg = source.guard_half_angle_deg
			p.view_range = source.guard_view_range
	p.near_ratio = source.near_ratio
	p.near_factor = source.near_factor
	p.far_factor = source.far_factor
	p.base_fill = source.base_fill_per_sec
	p.sprint_factor = source.sprint_factor
	p.walk_factor = source.walk_factor
	p.sneak_factor = source.sneak_factor
	p.dark_factor = source.dark_factor
	return p


## Geçerli core ayarları (tuning ya da gözlemci değişince `refresh()`).
func params() -> PerceptionRules.Params:
	if _params == null:
		refresh()
	return _params


func refresh() -> void:
	if tuning == null:
		push_error("Perception: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PerceptionTuning
	_params = params_for(tuning, observer)


## Bakışı `direction`'a dönüş tavanıyla (tuning, derece/sn) döndürür.
func turn_toward(direction: Vector2, delta: float) -> void:
	if tuning == null:
		refresh()
	facing = PerceptionRules.turn_toward(facing, direction, tuning.max_turn_deg_per_sec, delta)


## Bütün hedeflerin gözlemi: peer_id -> Observation. Fizik sorgusu yapar (host'ta, fizik adımında çağrılır).
func observe() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if not node.has_method(&"interaction_position"):
			continue
		var obs: Observation = observe_target(node)
		if obs != null:
			out[obs.peer_id] = obs
	return out


## Tek hedefin gözlemi (konumu okunamazsa null).
func observe_target(target: Node) -> Observation:
	var pos: Variant = target.call(&"interaction_position")
	if not pos is Vector2 or not (pos as Vector2).is_finite():
		return null
	var p: PerceptionRules.Params = params()
	var obs := Observation.new()
	obs.peer_id = target.get_multiplayer_authority()
	obs.position = pos
	obs.stance = stance_of(target)
	obs.band = PerceptionRules.band(p, global_position, facing, obs.position)
	if obs.band != PerceptionRules.Band.NONE:
		obs.line_clear = has_line_of_sight(global_position, obs.position)
		obs.in_dark = is_dark(obs.position)
	obs.rate = PerceptionRules.fill_rate(p, obs.band, obs.stance, obs.in_dark, obs.line_clear)
	return obs


## Hedefin algı durumu: oyuncu kipi (`net_mode`, yoksa `move_mode`; PlayerMotion.Mode) → Stance; yoksa yürüme.
static func stance_of(target: Node) -> PerceptionRules.Stance:
	var mode: Variant = target.get(&"net_mode")
	if typeof(mode) != TYPE_INT:
		mode = target.get(&"move_mode")
	if typeof(mode) != TYPE_INT:
		return PerceptionRules.Stance.WALK
	match int(mode):
		PlayerMotion.Mode.SPRINT:
			return PerceptionRules.Stance.SPRINT
		PlayerMotion.Mode.SNEAK:
			return PerceptionRules.Stance.SNEAK
	return PerceptionRules.Stance.WALK


func is_dark(pos: Vector2) -> bool:
	if not dark_query.is_valid():
		return false
	return bool(dark_query.call(pos))


## `from` → `to` görüş hattı açık mı (world + vision_block keser; `see_through` gövdeleri dışlanıp ışın
## baştan yeniden atılır — devam noktası hesaplanmadığı için bitişik duvar atlanamaz).
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	for _i: int in MAX_SEE_THROUGH + 1:
		var query := PhysicsRayQueryParameters2D.create(from, to, SIGHT_MASK, exclude)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.is_in_group(SEE_THROUGH_GROUP):
			exclude.append(hit["rid"] as RID)
			continue
		return false
	return false
