class_name InteractionRules
extends RefCounted
## Etkileşim kuralları (US-005; mimari.md S2, S7). Düğümsüz: yalnız değerlerle (Vector2, float, int) çalışır,
## sahne ağacını ve proje dizinlerini bilmez (KR-003, KR-018). Aynı kurallar iki yerde koşar:
## - istemci (yerel oyuncu): hedef seçimi ve istem; toleranssız (istem yalnız gerçekten menzildeyken),
## - host: isteğin doğrulanması ve süre sayımı; S2 gecikme toleransıyla (menzil +24 px, taraf eşiği -16 px,
##   süre +0,25 sn).
## Hedefin durumu `Target` değer nesnesinde taşınır (Interactable doldurur).

enum Result { OK, DISABLED, BUSY, COOLDOWN, OUT_OF_RANGE, WRONG_SIDE, MISSING_TAG, NO_ACTOR }

## S2: host istemci isteğini doğrularken menzile verdiği pay (px).
const RANGE_TOLERANCE := 24.0
## S2 ilkesi (GDD §12 oyuncu lehine): host taraf kısıtının eşiğinden düştüğü pay (px). Host istemcinin konumunu
## eşitleyiciden ~bir senkron aralığı + gecikme geriden görür (yürüme 140 px/sn × 0,1 sn ≈ 14 px); istem
## görünür görünmez basan oyuncu reddedilmesin. Kasada eşik 16 → 0: müşteri tarafı (tezgâh kenarı 546 px,
## yarıçap 12 → en fazla -26 px) yine reddedilir.
const SIDE_TOLERANCE := 16.0
## S2: zamana verilen pay (sn). Basılı tutma süresinin son payı içinde bırakılan istek tamamlanmış sayılır
## (yerelde çubuk dolmuşken bırakan oyuncu, host'ta süre RTT kadar geriden dolduğu için cezalanmaz).
const TIME_TOLERANCE := 0.25
## Bir etkileşim bittikten sonra host'un aynı hedefe yeni isteği reddettiği süre (sn): anlık eylemlerde
## (kapı) aynı anda basan iki oyuncu hedefi iki kez çevirmesin, yalnız biri geçsin (AC4).
const REPEAT_COOLDOWN := 0.25

const _RESULT_NAMES: Dictionary = {
	Result.OK: "ok",
	Result.DISABLED: "disabled",
	Result.BUSY: "busy",
	Result.COOLDOWN: "cooldown",
	Result.OUT_OF_RANGE: "out_of_range",
	Result.WRONG_SIDE: "wrong_side",
	Result.MISSING_TAG: "missing_tag",
	Result.NO_ACTOR: "no_actor",
}


## Etkileşim hedefinin kurallara giren durumu (konumlar aynı 2D düzlemde, ör. global koordinat).
class Target:
	extends RefCounted
	var position: Vector2 = Vector2.ZERO
	var interact_range: float = 40.0
	var enabled: bool = true
	## Hedefi tutan peer (0 = boş).
	var busy_by: int = 0
	## Taraf kısıtı: aktörün bulunması gereken yön (birim olmayabilir; ZERO = kısıt yok) ve hedef merkezinden
	## bu yön boyunca en az ne kadar ötede olması gerektiği (px).
	var side: Vector2 = Vector2.ZERO
	var side_min: float = 0.0
	## Gereken etiket (boş = yok) ve en düşük kademesi.
	var tag: StringName = &""
	var tier: int = 0


## `actor_pos`, hedefin menzili (+ tolerans) içinde mi.
static func in_range(actor_pos: Vector2, target_pos: Vector2, interact_range: float, tolerance: float = 0.0) -> bool:
	return actor_pos.distance_to(target_pos) <= interact_range + maxf(tolerance, 0.0)


## Taraf kısıtı: aktör, hedef merkezinden `side` yönünde en az `min_offset` ötede mi (side ZERO ise her zaman).
static func on_side(actor_pos: Vector2, target_pos: Vector2, side: Vector2, min_offset: float) -> bool:
	if side.is_zero_approx():
		return true
	return (actor_pos - target_pos).dot(side.normalized()) >= min_offset


## Etiket kısıtı: `actor_tags` etiket -> kademe (int); etiket gerekmiyorsa her zaman.
static func has_tag(tag: StringName, min_tier: int, actor_tags: Dictionary) -> bool:
	if tag == &"":
		return true
	var tier: Variant = actor_tags.get(tag, actor_tags.get(String(tag)))
	return tier != null and int(tier) >= min_tier


## `peer_id` bu hedefle etkileşime başlayabilir mi. Sıra: kapalı → meşgul → menzil → taraf → etiket.
## İstemci toleranssız (0), host RANGE_TOLERANCE ve SIDE_TOLERANCE ile çağırır. Hedefi zaten bu peer
## tutuyorsa meşgul sayılmaz.
static func check(target: Target, peer_id: int, actor_pos: Vector2, actor_tags: Dictionary,
		tolerance: float = 0.0, side_tolerance: float = 0.0) -> Result:
	if not target.enabled:
		return Result.DISABLED
	if target.busy_by != 0 and target.busy_by != peer_id:
		return Result.BUSY
	if not in_range(actor_pos, target.position, target.interact_range, tolerance):
		return Result.OUT_OF_RANGE
	if not on_side(actor_pos, target.position, target.side, target.side_min - maxf(side_tolerance, 0.0)):
		return Result.WRONG_SIDE
	if not has_tag(target.tag, target.tier, actor_tags):
		return Result.MISSING_TAG
	return Result.OK


## Host doğrulaması: yeni etkileşimden önce bekleme süresi, sonra `check` (S2 menzil ve taraf toleransıyla).
static func host_check(target: Target, peer_id: int, actor_pos: Vector2, actor_tags: Dictionary,
		cooldown_left: float) -> Result:
	if cooldown_left > 0.0 and target.busy_by != peer_id:
		return Result.COOLDOWN
	return check(target, peer_id, actor_pos, actor_tags, RANGE_TOLERANCE, SIDE_TOLERANCE)


## Süren etkileşim devam edebilir mi (host ve istemci; S2 menzil toleransıyla).
static func keeps_going(target: Target, actor_pos: Vector2) -> bool:
	return in_range(actor_pos, target.position, target.interact_range, RANGE_TOLERANCE)


## İlerlemeyi bir adım ilerletir (negatif değerler sıfırlanır).
static func advance(progress: float, delta: float) -> float:
	return maxf(progress, 0.0) + maxf(delta, 0.0)


## Basılı tutma süresi doldu mu (süre 0 ya da negatifse anlık eylem: hemen tamam).
static func is_complete(progress: float, hold_time: float) -> bool:
	return progress >= hold_time


## Oyuncu bıraktığında: ilerleme sürenin son TIME_TOLERANCE payı içindeyse tamamlanmış sayılır, değilse iptal
## (yarıda bırakılan ilerleme sıfırlanır; sıfırlamayı çağıran yapar).
static func release_completes(progress: float, hold_time: float) -> bool:
	return progress >= hold_time - TIME_TOLERANCE


## 0..1 ilerleme oranı (süre 0 ise ilerleme varsa 1).
static func ratio(progress: float, hold_time: float) -> float:
	if hold_time <= 0.0:
		return 1.0 if progress > 0.0 else 0.0
	return clampf(progress / hold_time, 0.0, 1.0)


## `positions` içinde `actor_pos`'a en yakın olanın indisi (eşitlikte ilk); liste boşsa -1.
static func nearest(actor_pos: Vector2, positions: PackedVector2Array) -> int:
	var best: int = -1
	var best_dist: float = INF
	for i: int in positions.size():
		var d: float = actor_pos.distance_squared_to(positions[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best


## Sonucun döküm/günlük adı ("busy", "out_of_range" …).
static func result_name(result: Result) -> String:
	return str(_RESULT_NAMES.get(result, "unknown"))
