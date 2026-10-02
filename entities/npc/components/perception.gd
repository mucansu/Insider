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
## - Sivil eki (US-008, yalnız ekleme; varsayılanlar muhafız davranışını değiştirmez): `factor_query`
##   (Callable(target: Node) -> float) verilmişse kip çarpanının yerine sivil davranış çarpanı kullanılır
##   (CivilianRules; karanlık yine ezer); `set_cone()` gözlemci konisini geçersiz kılar (sivil 50°/224 px,
##   telefonda daralır); `set_hysteresis()` görülmekte olan hedef için koniyi genişletir (50°/224 → 53°/238 px;
##   koni kenarında titreme yok).
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
	## Kullanılan durum çarpanı (kip ya da `factor_query`; karanlıkta dark_factor).
	var factor: float = 0.0


@export var tuning: PerceptionTuning
@export var observer: Observer = Observer.GUARD
## Global bakış yönü (birim).
@export var facing: Vector2 = Vector2.RIGHT
## Karanlık bölge sorgusu: func(pos: Vector2) -> bool. Boşsa aydınlık.
var dark_query: Callable = Callable()
## Sivil davranış çarpanı (US-008): func(target: Node) -> float; boşsa kip çarpanı (muhafız).
var factor_query: Callable = Callable()

var _params: PerceptionRules.Params = null
## Görülmekte olan hedeflerin genişletilmiş konisi (histerezis yoksa null).
var _wide: PerceptionRules.Params = null
## Koni geçersiz kılma (0 = tuning) ve histerezis payları.
var _cone_half_angle: float = 0.0
var _cone_range: float = 0.0
var _hyst_angle: float = 0.0
var _hyst_range: float = 0.0
## peer_id -> son gözlemde koni içinde ve görüş hattı açık mıydı (histerezis).
var _inside: Dictionary = {}


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
	if _cone_half_angle > 0.0:
		_params.half_angle_deg = _cone_half_angle
	if _cone_range > 0.0:
		_params.view_range = _cone_range
	_wide = null
	if _hyst_angle > 0.0 or _hyst_range > 0.0:
		_wide = params_for(tuning, observer)
		_wide.half_angle_deg = _params.half_angle_deg + _hyst_angle
		_wide.view_range = _params.view_range + _hyst_range


## Gözlemci konisini geçersiz kılar (yarım açı derece, menzil px; 0 = tuning'deki koni).
func set_cone(half_angle_deg: float, view_range: float) -> void:
	if is_equal_approx(half_angle_deg, _cone_half_angle) and is_equal_approx(view_range, _cone_range) \
			and _params != null:
		return
	_cone_half_angle = maxf(half_angle_deg, 0.0)
	_cone_range = maxf(view_range, 0.0)
	refresh()


## Koni kenarı histerezisi: görülmekte olan hedef için koni `angle_deg` / `range_px` genişler (0 = yok).
func set_hysteresis(angle_deg: float, range_px: float) -> void:
	_hyst_angle = maxf(angle_deg, 0.0)
	_hyst_range = maxf(range_px, 0.0)
	refresh()


## Hedef son gözlemde görülüyor muydu (koni + görüş hattı; histerezis girdisi).
func was_seen(peer_id: int) -> bool:
	return bool(_inside.get(peer_id, false))


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
	var cone: PerceptionRules.Params = _wide if _wide != null and was_seen(obs.peer_id) else p
	obs.band = PerceptionRules.band(cone, global_position, facing, obs.position)
	if obs.band != PerceptionRules.Band.NONE and cone != p:
		# Histerezis yalnız koninin dış sınırına: yakın/uzak bant sınırı değişmez.
		var near_limit: float = p.view_range * p.near_ratio + PerceptionRules.EPSILON
		var near: bool = global_position.distance_to(obs.position) <= near_limit
		obs.band = PerceptionRules.Band.NEAR if near else PerceptionRules.Band.FAR
	if obs.band != PerceptionRules.Band.NONE:
		obs.line_clear = has_line_of_sight(global_position, obs.position)
		obs.in_dark = is_dark(obs.position)
	if factor_query.is_valid():
		obs.factor = p.dark_factor if obs.in_dark else maxf(float(factor_query.call(target)), 0.0)
		var seen: bool = obs.line_clear and obs.band != PerceptionRules.Band.NONE
		obs.rate = p.base_fill * PerceptionRules.band_factor(p, obs.band) * obs.factor if seen else 0.0
	else:
		obs.factor = PerceptionRules.stance_factor(p, obs.stance, obs.in_dark)
		obs.rate = PerceptionRules.fill_rate(p, obs.band, obs.stance, obs.in_dark, obs.line_clear)
	_inside[obs.peer_id] = obs.line_clear and obs.band != PerceptionRules.Band.NONE
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
