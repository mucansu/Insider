class_name NoiseRules
extends RefCounted
## Gürültü kuralları (US-009; mimari.md S8, S2, §6): duyulabilirlik (mesafe), duvar arkası zayıflama, ışın
## isabetinin sesi kesip kesmediği, istemci isteğinin host doğrulaması ve yayım temposu. Düğümsüz; yalnız
## değerlerle çalışır (fizik ışını dinleyici bileşeninde, host'ta; sonuç buraya girdi olarak gelir; KR-003).
## Sayısal ayarlar (yarıçaplar, zayıflama çarpanı, tempo) `data/noise_profile.tres`'te; buradaki sabitler
## yalnız kural payları.

## Host'un istemci gürültü isteğini reddetme nedenleri (OK = kabul).
enum Result { OK, BAD_POSITION, FOREIGN_PEER, KIND_NOT_ALLOWED, NO_ACTOR, TOO_FAR, SILENT, RATE }

## İstemcinin bildirdiği ses konumu ile host'un bildiği aktör konumu arasındaki en büyük fark (px). Host, aktörün
## eşitleyiciden gelen en güncel konumunu bilir (S7 `interaction_position`); güvenilir RPC ile 20 Hz güvenilmez
## eşitleme arasında en fazla ~1 eşitleme aralığı + kare kayması olur: koşu 220 px/sn × (0,05 + 0,05) sn ≈ 22 px
## (S2 menzil payı 24 px'in üstünde küçük bir pay). Aşan istek reddedilir: istemci uzak konumda ses üretemez.
const POSITION_TOLERANCE := 32.0
## Işın isabeti sesin kaynağına bu kadar yakınsa (px) ses kesilmez: kaynağın kendi gövdesi (ör. kapanan kapının
## kanadı, kapı noktasında yayılan ses) sesi boğmaz. Yarım karo (1 karo = 32 px, S4); duvara yaslanan oyuncunun
## duvar arkasındaki dinleyiciye uzaklığı ≥ duvar kalınlığı + gövde yarıçapı = 44 px olduğundan zayıflama sürer.
const SOURCE_MARGIN := 16.0
## İstemci isteklerinde gönderen başına en kısa aralık = adım aralığı × bu çarpan. İstemci kendi adımını zaten
## `step_interval`'da bir yollar; yarısı, güvenilir kanalın yeniden gönderimde paketleri yığmasına (~175 ms) pay
## bırakır. Aşan istek `RATE` ile reddedilir (ses düşer; oyuncu lehine).
const CLIENT_RATE_FACTOR := 0.5
## Süren iş sesinde (kasa boşaltma) bitişe bu kadar aralık kesri kala tempo sesi bastırılır: bitiş sesi zaten
## yayılır, aynı noktada art arda iki ses (US-008'de çift şüphe) olmaz.
const WORK_TICK_END_FACTOR := 0.5


## Görüş hattı yoksa (arada world/vision_block) yarıçap `wall_factor` ile çarpılır (S8: ×0,5).
static func effective_radius(radius: float, line_of_sight: bool, wall_factor: float) -> float:
	if radius <= 0.0:
		return 0.0
	return radius if line_of_sight else radius * clampf(wall_factor, 0.0, 1.0)


## Dinleyici sesin (etkin) yarıçapı içinde mi; sıfır yarıçaplı ses (yürüme, sızma) hiç duyulmaz.
static func can_hear(distance: float, radius: float) -> bool:
	return radius > 0.0 and distance <= radius


## Işın isabeti sesi keser mi: kaynağa SOURCE_MARGIN'den yakın isabet kaynağın kendisidir, kesmez.
static func hit_blocks(hit_point: Vector2, source: Vector2) -> bool:
	return hit_point.distance_to(source) > SOURCE_MARGIN


## Host: `sender`'ın (RPC gönderen kimliği) gürültü isteğini doğrular. `source_peer` istemcinin bildirdiği kaynak
## (0 ya da kendisi olmalı; başka peer adına ses yok); `kind_allowed` istemcinin bu türü üretebilmesi (yalnız kendi
## hareket sesi); `radius` host'un tanımdaki yarıçapı (istemcinin yarıçapına güvenilmez); `known` host'un bildiği
## aktör konumu (`has_actor` false ise aktör yok).
static func check_client(sender: int, source_peer: int, kind_allowed: bool, radius: float, claimed: Vector2,
		known: Vector2, has_actor: bool, tolerance: float = POSITION_TOLERANCE) -> Result:
	if not claimed.is_finite():
		return Result.BAD_POSITION
	if sender <= 0 or (source_peer != 0 and source_peer != sender):
		return Result.FOREIGN_PEER
	if not kind_allowed:
		return Result.KIND_NOT_ALLOWED
	if radius <= 0.0:
		return Result.SILENT
	if not has_actor or not known.is_finite():
		return Result.NO_ACTOR
	if claimed.distance_to(known) > tolerance:
		return Result.TOO_FAR
	return Result.OK


## Host: aynı göndericinin son kabul edilen isteğinden `since_last` sn geçti; tempo sınırı içinde mi.
static func within_rate(since_last: float, step_interval: float) -> bool:
	return since_last >= step_interval * CLIENT_RATE_FACTOR


## Süren işin tempo sesi (ör. kasa boşaltma; `progress`/`hold_time` sn) bu adımda yayılabilir mi: bitişe
## `interval × WORK_TICK_END_FACTOR`'dan az kaldıysa hayır (bitiş sesi onun yerine geçer).
static func work_tick_allowed(progress: float, hold_time: float, interval: float) -> bool:
	return hold_time <= 0.0 or progress + interval * WORK_TICK_END_FACTOR < hold_time


## Döküm ve log için ret nedeninin adı.
static func result_name(result: Result) -> String:
	return str(Result.keys()[result]).to_lower()


## Yayım temposu (koşu adımları, kasa boşaltma sesi): etkin olduğu sürece en fazla `interval` sn'de bir olay.
## `lead`: etkinleştikten sonra ilk olaya kadar beklenen süre (0 = hemen). Etkin değilken geçen süre de sayılır;
## bu yüzden kısa aralıklarla aç/kapa tempo sınırını aşamaz.
class Cadence:
	extends RefCounted

	var interval: float = 0.0
	var lead: float = 0.0
	var _since_last: float = INF
	var _active_for: float = 0.0

	func _init(interval_sec: float, lead_sec: float = 0.0) -> void:
		interval = maxf(interval_sec, 0.0)
		lead = maxf(lead_sec, 0.0)

	## Zamanı `delta` ilerletir; bu adımda bir olay yayılmalıysa true.
	func tick(delta: float, active: bool) -> bool:
		_since_last += delta
		if not active:
			_active_for = 0.0
			return false
		_active_for += delta
		if _active_for < lead or _since_last < interval:
			return false
		_since_last = 0.0
		return true
