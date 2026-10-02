class_name NoiseProfile
extends Resource
## Gürültü ayarları (US-009; mimari.md S8, S10 ayar dosyası kalıbı). Değerlerin tek kaynağı
## `data/noise_profile.tres` (yürüme 0, sızma 0, koşma 120, kapı 160, kasa 90, sindirme 140 px); buradaki
## varsayılanlar nötrdür. Kurallar `core/noise_rules.gd`'de (düğümsüz). Tür adları ağda giden StringName'lerdir.

const PATH := "res://data/noise_profile.tres"

const KIND_WALK := &"walk"
const KIND_SNEAK := &"sneak"
const KIND_RUN := &"run"
const KIND_DOOR := &"door"
const KIND_REGISTER := &"register"
const KIND_INTIMIDATE := &"intimidate"
## İstemcinin kendi adına üretebileceği türler (S2: istemci yalnız kendi hareketinde yetkili). Kapı, kasa,
## sindirme gibi sonuç sesleri host'ta doğar.
const MOVEMENT_KINDS: Array[StringName] = [KIND_WALK, KIND_SNEAK, KIND_RUN]

## Adım başına yarıçaplar (px); 0 = sessiz.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var walk_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var sneak_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var sprint_radius: float = 0.0
## Olay yarıçapları (px).
@export_range(0.0, 1000.0, 1.0, "suffix:px") var door_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var register_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var intimidate_radius: float = 0.0
## Adım sesleri arası en kısa süre (sn; S8 "en fazla ~3 Hz").
@export_range(0.0, 5.0, 0.01, "suffix:s") var step_interval: float = 0.0
## Bu gerçek hızın altında (px/sn) adım sesi çıkmaz (koşu tuşu basılı ama duruyor/duvara itiyor). Her kipin
## hızından (sızma 70) küçük tutulur: kipin sessizliğini yalnız yarıçapı belirler.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var step_min_speed: float = 0.0
## Kasa boşaltılırken ses aralığı (sn; ilk ses de bu kadar sonra); tamamlanınca ayrıca bir ses.
@export_range(0.0, 10.0, 0.05, "suffix:s") var register_interval: float = 0.0
## Görüş hattı yoksa (duvar arkası) yarıçap çarpanı (S8: 0,5).
@export_range(0.0, 1.0, 0.05) var wall_factor: float = 1.0

static var _default: NoiseProfile = null


## `data/noise_profile.tres` (süreç başına bir kez yüklenir).
static func load_default() -> NoiseProfile:
	if _default == null:
		_default = load(PATH) as NoiseProfile
		if _default == null:
			push_error("NoiseProfile: %s yüklenemedi" % PATH)
			_default = NoiseProfile.new()
	return _default


## Türün yarıçapı (px); bilinmeyen tür sessiz (0).
func radius_for(kind: StringName) -> float:
	match kind:
		KIND_WALK:
			return walk_radius
		KIND_SNEAK:
			return sneak_radius
		KIND_RUN:
			return sprint_radius
		KIND_DOOR:
			return door_radius
		KIND_REGISTER:
			return register_radius
		KIND_INTIMIDATE:
			return intimidate_radius
	return 0.0


static func is_movement_kind(kind: StringName) -> bool:
	return MOVEMENT_KINDS.has(kind)
