class_name SuspicionMeter
extends RefCounted
## Bir gözlemcinin bir hedefe karşı şüphe ölçeri (US-006 AC1; mimari.md S2, S11, GDD §6.1/§12, KR-019).
## Düğümsüz; dolum hızı (`PerceptionRules.rate_for`) ve adım süresiyle ilerler, sabit adımdan bağımsızdır.
##
## - Değer 0..MAX_VALUE; eşikler (KR-019: "?" 30, inceleme 60, tespit 100) düzeyi verir: 0 sakin, 1..N eşik sırası.
## - Görülürken (dolum > 0) değer `fill × sn` artar; görülmezken (görüş hattı kesik, koni dışı, karanlık)
##   `decay_per_sec` ile azalır, düzey de değerle birlikte iner.
## - Görülme dizisi: görülen adımlar ve aralarındaki `gap_tolerance`'tan kısa kesintiler tek dizidir
##   (`seen_for` dizinin süresi, kesinti dahil). Kısa kesintide dolum o anda durur ama dizi sürer ve boşalma
##   başlamaz: kenarda kıpırdayarak bakma (11/1, 9/3 kare) ya da 20 Hz eşitleme titremesi ölçeri sıfırlamaz,
##   tespitten sonra tek karelik kayıp düzeyi düşürmez. Kesinti toleransı aşınca dizi biter, boşalma toleransın
##   ötesindeki süre için işler (gerçek saklanma).
## - Oyuncu lehine pay (S2, GDD §12: host oyuncuyu ~100-175 ms eski konumda görür): dizinin ilk `grace` sn'sinde
##   dolum yok ("görüldü" başlangıcı geç başlar); görüş hattından çıkışta dolum o anda durur. Sonuç: `grace`'ten
##   kısa bakış iz bırakmaz, host'un eski görüntüsüyle saklanan oyuncunun son ~0,2 sn'lik görüntüsü tespite
##   yetişmez. Sürekli görülen hedefte tespit = grace + MAX / dolum (koşan, yakın bant: 0,2 + 1,0 sn; KR kararı
##   US-006 t2). Pay süresince değer ne dolar ne boşalır.
## - `step()` bu adımda yukarı doğru geçilen eşik düzeylerini sırayla döndürür (bileşen sinyale çevirir).

## Ölçer tavanı (GDD §6.1: 0-100).
const MAX_VALUE := 100.0
## Eşik karşılaştırmasında kayan nokta payı (adım toplamının 99,9999'da kalmaması için).
const EPSILON := 0.0001


## Ölçer ayarları (değer nesnesi; bileşen tuning'den doldurur).
class Params:
	extends RefCounted
	## Görülmezken boşalma (birim/sn).
	var decay_per_sec: float = 0.0
	## Artan eşikler; düzey = geçilen eşik sayısı.
	var thresholds: PackedFloat32Array = PackedFloat32Array()
	## Oyuncu lehine pay (sn).
	var grace: float = 0.0
	## Görülme dizisini bozmayan kesinti süresi (sn; 0 = her kesinti diziyi bitirir).
	var gap_tolerance: float = 0.0


var value: float = 0.0
var level: int = 0
## Süren görülme dizisinin süresi (sn; tolere edilen kesintiler dahil; dizi yoksa 0).
var seen_for: float = 0.0
## Süren kesintinin süresi (sn; görülürken 0).
var gap_for: float = 0.0


## Bir adım ilerletir. `fill_rate` > 0 ise hedef bu adım boyunca görüldü sayılır. Yukarı geçilen düzeyler
## (küçükten büyüğe) döner; düzey inişleri döndürülmez.
func step(params: Params, fill_rate: float, delta: float) -> PackedInt32Array:
	var dt: float = maxf(delta, 0.0)
	if fill_rate > 0.0:
		gap_for = 0.0
		var before: float = seen_for
		seen_for += dt
		var credited: float = seen_for - maxf(before, params.grace)
		if credited > 0.0:
			value += fill_rate * minf(credited, dt)
	else:
		var decaying: float = dt
		if seen_for > 0.0:
			var tolerated: float = clampf(params.gap_tolerance - gap_for, 0.0, dt)
			gap_for += dt
			if gap_for < params.gap_tolerance:
				seen_for += dt
				decaying = 0.0
			else:
				seen_for = 0.0
				gap_for = 0.0
				decaying = dt - tolerated
		value -= maxf(params.decay_per_sec, 0.0) * decaying
	value = clampf(value, 0.0, MAX_VALUE)
	var new_level: int = level_for(params, value)
	var reached := PackedInt32Array()
	for l: int in range(level + 1, new_level + 1):
		reached.append(l)
	level = new_level
	return reached


## Değerin düzeyi: geçilen (≥, EPSILON payıyla) eşik sayısı.
static func level_for(params: Params, amount: float) -> int:
	var out: int = 0
	for t: float in params.thresholds:
		if amount >= t - EPSILON:
			out += 1
	return out


func reset() -> void:
	value = 0.0
	level = 0
	seen_for = 0.0
	gap_for = 0.0
