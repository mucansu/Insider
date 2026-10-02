class_name PerceptionRules
extends RefCounted
## Algı kuralları (US-006 AC1; mimari.md S11, GDD §6.1, KR-019). Düğümsüz: yalnız değerlerle (Vector2, float,
## int, bool) çalışır, sahne ağacını, fizik uzayını ve proje dizinlerini bilmez (KR-003, KR-018). Görüş hattı
## (raycast) bileşende yapılır, sonucu buraya `visible: bool` olarak girer.
##
## Model (KR-019, "dijital" okunabilirlik): gözlemcinin görüş konisi (konum, yön, yarım açı, menzil) iki banda
## ayrılır: yakın bant (mesafe ≤ menzil × near_ratio) ×near_factor, uzak bant ×far_factor. Görünen hedefin
## şüphe dolumu (birim/sn) = base_fill × bant çarpanı × durum çarpanı; durum = hareket kipi (koşu/yürüme/sızma)
## ya da karanlık bölge (ikili ışık/gölge: karanlıkta çarpan dark_factor, başlangıçta 0). Dolum ölçere
## `SuspicionMeter` (core/suspicion.gd) uygular; sayılar `data/npc/perception_tuning.tres`'ten bileşen
## aracılığıyla `Params`'a gelir (buradaki varsayılanlar nötrdür).

enum Band { NONE, FAR, NEAR }
## Hedefin algıya giren hareket durumu (oyuncu kipinden bileşen eşler).
enum Stance { WALK, SNEAK, SPRINT }

## Koni sınırlarında kayan nokta payı (açı kosinüsü ve px).
const EPSILON := 0.0001


## Algı ayarları (değer nesnesi; bileşen tuning'den doldurur).
class Params:
	extends RefCounted
	## Koninin yarım açısı (derece) ve menzili (px).
	var half_angle_deg: float = 0.0
	var view_range: float = 0.0
	## Yakın bant sınırı: menzilin bu oranı (KR-019: R/2).
	var near_ratio: float = 0.0
	var near_factor: float = 0.0
	var far_factor: float = 0.0
	## Temel dolum (birim/sn) ve durum çarpanları.
	var base_fill: float = 0.0
	var sprint_factor: float = 0.0
	var walk_factor: float = 0.0
	var sneak_factor: float = 0.0
	var dark_factor: float = 0.0


## Hedef koninin içinde mi: menzil (sınır dahil) ve yarım açı (sınır dahil). Yön sıfırsa koni yok (false);
## hedef gözlemcinin tam üstündeyse içeride sayılır.
static func in_cone(observer_pos: Vector2, facing: Vector2, half_angle_deg: float, view_range: float,
		target_pos: Vector2) -> bool:
	if facing.is_zero_approx() or view_range <= 0.0:
		return false
	var offset: Vector2 = target_pos - observer_pos
	var dist: float = offset.length()
	if dist > view_range + EPSILON:
		return false
	if dist <= EPSILON:
		return true
	var cos_limit: float = cos(deg_to_rad(clampf(half_angle_deg, 0.0, 180.0)))
	return offset.dot(facing.normalized()) / dist >= cos_limit - EPSILON


## Hedefin bandı: koni dışında NONE; içinde mesafe ≤ menzil × near_ratio ise NEAR, değilse FAR.
static func band(params: Params, observer_pos: Vector2, facing: Vector2, target_pos: Vector2) -> Band:
	if not in_cone(observer_pos, facing, params.half_angle_deg, params.view_range, target_pos):
		return Band.NONE
	if observer_pos.distance_to(target_pos) <= params.view_range * params.near_ratio + EPSILON:
		return Band.NEAR
	return Band.FAR


static func band_factor(params: Params, which: Band) -> float:
	match which:
		Band.NEAR:
			return params.near_factor
		Band.FAR:
			return params.far_factor
	return 0.0


## Durum çarpanı: karanlık bölge her kipi ezer (ikili ışık/gölge); bilinmeyen kip yürüme sayılır.
static func stance_factor(params: Params, stance: Stance, in_dark: bool) -> float:
	if in_dark:
		return params.dark_factor
	match stance:
		Stance.SPRINT:
			return params.sprint_factor
		Stance.SNEAK:
			return params.sneak_factor
	return params.walk_factor


## Şüphe dolumu (birim/sn): görüş hattı kesikse ya da koni dışındaysa 0.
static func fill_rate(params: Params, which: Band, stance: Stance, in_dark: bool, visible: bool) -> float:
	if not visible or which == Band.NONE:
		return 0.0
	return maxf(0.0, params.base_fill * band_factor(params, which) * stance_factor(params, stance, in_dark))


## Tek çağrıda: konum/yön + görüş hattı sonucu + hedef durumu → dolum (birim/sn).
static func rate_for(params: Params, observer_pos: Vector2, facing: Vector2, target_pos: Vector2,
		visible: bool, stance: Stance, in_dark: bool) -> float:
	return fill_rate(params, band(params, observer_pos, facing, target_pos), stance, in_dark, visible)


## Bakış yönünü `desired` yönüne en fazla `max_turn_deg_per_sec × delta` derece döndürür (KR-019: muhafız dönüş
## tavanı). Birim vektör döner; `desired` sıfırsa yön korunur, `current` sıfırsa doğrudan `desired`'a geçer.
static func turn_toward(current: Vector2, desired: Vector2, max_turn_deg_per_sec: float, delta: float) -> Vector2:
	if desired.is_zero_approx():
		return current.normalized() if not current.is_zero_approx() else current
	var want: Vector2 = desired.normalized()
	if current.is_zero_approx():
		return want
	var from: Vector2 = current.normalized()
	var angle: float = from.angle_to(want)
	var step: float = deg_to_rad(maxf(max_turn_deg_per_sec, 0.0)) * maxf(delta, 0.0)
	if absf(angle) <= step:
		return want
	return from.rotated(signf(angle) * step)
