class_name Hearing
extends Node2D
## Duyma bileşeni (US-009; mimari.md S8, S11, KR-018): NPC'nin alt düğümü, konumu kulak konumudur.
## `noise_listener` grubundadır; NoiseBus host'ta her ses için `hear_noise(pos, radius, kind)` çağırır.
## Yalnız host'ta işler: ses yarıçapın dışındaysa ışın atılmaz; içindeyse kulaktan sese fizik ışını (görüş hattı,
## `SightLine`: world (1) + vision_block (6) keser, `see_through` grubundaki gövdeler geçirir; S11 Faz 2 eki) atılır,
## görüş hattı yoksa yarıçap `NoiseProfile.wall_factor` ile küçülür. Kurallar NoiseRules'ta (düğümsüz).
## Duyunca `heard(pos, radius, kind)` yayılır; `radius` zayıflamadan sonraki etkin yarıçaptır. Şüpheye bağlama
## gözlemci kaleminde (US-008); bu bileşen yalnız sinyal yayar.
## Alçak engel (US-010, KR-026): tezgâh (`Counter*` çarpışma şekilleri, S4) görüşü keser ama sesi kesmez — ses
## üstünden geçer; ışın tezgâhın içinden sürdürülür (tezgâhtaki sahip satış alanındaki raf devirmeyi duyar).
## Köşe kırınımı (US-010; isteğe bağlı, `corner_spread_px` > 0): orta ışın kesilirse kulaktan ±`corner_spread_px`
## kaydırılmış iki paralel ışın denenir; biri açıksa görüş hattı var sayılır (ses duvar köşesini sıyırarak geçer; kalın
## duvar yine keser). Varsayılan 0 (kapalı); sahip ayarından açar.
## Kendi sesi (IS-087 AC1): NPC'nin kendi eylemiyle (ör. kendi açtığı/kapattığı kapı) çıkan ses `ignore_own(pos,
## kind, action)` ile sarılır; eylem sürerken o noktadaki o türden ses bu bileşende yok sayılır (host'ta yayım
## eşzamanlıdır: NoiseBus dinleyicileri aynı çağrıda dolaşır). Başka NPC'lerin ve oyuncuların sesi aynen işler.

## Yalnız host'ta.
signal heard(pos: Vector2, radius: float, kind: StringName)

const GROUP := PhysicsLayers.NOISE_LISTENER_GROUP
## Sesi kesen fizik katmanları: world (1) + vision_block (6) (mimari.md §4; SightLine).
const BLOCK_MASK := SightLine.MASK
## Bu gruptaki gövdeler (camlar, S4 eki) sesi kesmez (SightLine).
const SEE_THROUGH_GROUP := SightLine.SEE_THROUGH_GROUP
## Kendi sesi eşleşmesinde konum payı (px; ses kaynağın kendi konumunda yayılır).
const OWN_NOISE_PX := 1.0
## Sesi kesmeyen alçak engellerin şekil adı önekleri (S4 çarpışma şekil adları) ve ışını sürdürme adımı (px).
const LOW_SHAPE_PREFIXES: Array[String] = ["Counter"]
const LOW_STEP_PX := 1.0
## Bir ışında en fazla kaç alçak engel geçilir (sonsuz döngü bekçisi).
const MAX_LOW_HITS := 4

@export var profile: NoiseProfile
@export var enabled: bool = true
## Köşe kırınımı: paralel ışınların kaydırması (px; 0 = kapalı).
@export_range(0.0, 32.0, 0.5, "suffix:px") var corner_spread_px: float = 0.0

var _heard_count: int = 0
var _ignored_own: int = 0
## Süren kendi eylemleri: [konum, tür] (ignore_own içinde).
var _own: Array[Array] = []


func _ready() -> void:
	if profile == null:
		profile = NoiseProfile.load_default()
	add_to_group(GROUP)


## NoiseBus (host) çağırır.
func hear_noise(pos: Vector2, radius: float, kind: StringName) -> void:
	if not enabled or not multiplayer.is_server() or not is_inside_tree():
		return
	if is_own(pos, kind):
		_ignored_own += 1
		return
	var distance: float = global_position.distance_to(pos)
	if not NoiseRules.can_hear(distance, radius):
		return
	var effective: float = NoiseRules.effective_radius(radius, has_line_of_sight(pos), profile.wall_factor)
	if not NoiseRules.can_hear(distance, effective):
		return
	_heard_count += 1
	heard.emit(pos, effective, kind)


## Kulaktan `to` noktasına görüş hattı var mı (SightLine: görüş kuralıyla aynı ışın; kaynağa SOURCE_MARGIN'den
## yakın ilk isabet kaynağın kendi gövdesidir, kesmez).
func has_line_of_sight(to: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position
	if _ray_clear(space, from, to):
		return true
	if corner_spread_px <= 0.0:
		return false
	var side: Vector2 = (to - from).normalized().orthogonal() * corner_spread_px
	return _ray_clear(space, from + side, to + side) or _ray_clear(space, from - side, to - side)


## Tek ışın: alçak engeller (tezgâh) geçilir, kaynağın kendi gövdesi kesmez.
static func _ray_clear(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var dir: Vector2 = (to - from).normalized()
	for _i: int in MAX_LOW_HITS + 1:
		var hit: Dictionary = SightLine.first_blocker(space, from, to, BLOCK_MASK)
		if hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, to):
			return true
		if not is_low_obstacle(hit):
			return false
		from = (hit["position"] as Vector2) + dir * LOW_STEP_PX  # alçak engelin içinden sür (içeriden isabet yok)
	return false


## Işın isabeti alçak engel mi (tezgâh: şekil adı LOW_SHAPE_PREFIXES ile başlar).
static func is_low_obstacle(hit: Dictionary) -> bool:
	var body: CollisionObject2D = hit.get("collider") as CollisionObject2D
	if body == null or not hit.has("shape"):
		return false
	var owner_id: int = body.shape_find_owner(int(hit["shape"]))
	var shape_node: Node = body.shape_owner_get_owner(owner_id) as Node
	if shape_node == null:
		return false
	for prefix: String in LOW_SHAPE_PREFIXES:
		if String(shape_node.name).begins_with(prefix):
			return true
	return false


## Bu bileşenin duyduğu ses sayısı (teşhis).
func heard_count() -> int:
	return _heard_count


## Kendi sesi olduğu için yok sayılan ses sayısı (teşhis, IS-087).
func ignored_own_count() -> int:
	return _ignored_own


## `action` çalışırken `pos`ta çıkan `kind` sesi kendi sesidir, duyulmaz (IS-087 AC1). `action`ın dönüşünü verir.
func ignore_own(pos: Vector2, kind: StringName, action: Callable) -> Variant:
	_own.append([pos, kind])
	var result: Variant = action.call()
	_own.pop_back()
	return result


## Bu ses süren bir kendi eyleminin sesi mi.
func is_own(pos: Vector2, kind: StringName) -> bool:
	for own: Array in _own:
		if StringName(own[1]) == kind and (own[0] as Vector2).distance_to(pos) <= OWN_NOISE_PX:
			return true
	return false
