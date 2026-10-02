class_name Hearing
extends Node2D
## Duyma bileşeni (US-009; mimari.md S8, S11, KR-018): NPC'nin alt düğümü, konumu kulak konumudur.
## `noise_listener` grubundadır; NoiseBus host'ta her ses için `hear_noise(pos, radius, kind)` çağırır.
## Yalnız host'ta işler: ses yarıçapın dışındaysa ışın atılmaz; içindeyse kulaktan sese fizik ışını (görüş hattı,
## `SightLine`: world (1) + vision_block (6) keser, `see_through` grubundaki gövdeler geçirir; S11 Faz 2 eki) atılır,
## görüş hattı yoksa yarıçap `NoiseProfile.wall_factor` ile küçülür. Kurallar NoiseRules'ta (düğümsüz).
## Duyunca `heard(pos, radius, kind)` yayılır; `radius` zayıflamadan sonraki etkin yarıçaptır. Şüpheye bağlama
## gözlemci kaleminde (US-008); bu bileşen yalnız sinyal yayar.

## Yalnız host'ta.
signal heard(pos: Vector2, radius: float, kind: StringName)

const GROUP := PhysicsLayers.NOISE_LISTENER_GROUP
## Sesi kesen fizik katmanları: world (1) + vision_block (6) (mimari.md §4; SightLine).
const BLOCK_MASK := SightLine.MASK
## Bu gruptaki gövdeler (camlar, S4 eki) sesi kesmez (SightLine).
const SEE_THROUGH_GROUP := SightLine.SEE_THROUGH_GROUP

@export var profile: NoiseProfile
@export var enabled: bool = true

var _heard_count: int = 0


func _ready() -> void:
	if profile == null:
		profile = NoiseProfile.load_default()
	add_to_group(GROUP)


## NoiseBus (host) çağırır.
func hear_noise(pos: Vector2, radius: float, kind: StringName) -> void:
	if not enabled or not multiplayer.is_server() or not is_inside_tree():
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
	var hit: Dictionary = SightLine.first_blocker(get_world_2d().direct_space_state, global_position, to, BLOCK_MASK)
	return hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, to)


## Bu bileşenin duyduğu ses sayısı (teşhis).
func heard_count() -> int:
	return _heard_count
