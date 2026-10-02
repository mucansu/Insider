class_name FrameStats
extends RefCounted
## Sabit kapasiteli halka tampon + saf istatistik (IS-067, çizim ölçümü; mimari.md S6 `--perf`).
## Düğümsüz ve motor tekillerine bağımsız: değerleri çağıran verir (kare süresi ms, draw call sayısı …).
## Tampon doluyken en eski değerin üstüne yazar; `values()` eskiden yeniye sıralı kopya döner.

var _buf: PackedFloat32Array = []
var _head: int = 0
var _count: int = 0


func _init(capacity: int = 64) -> void:
	_buf.resize(maxi(1, capacity))


func capacity() -> int:
	return _buf.size()


func size() -> int:
	return _count


func clear() -> void:
	_head = 0
	_count = 0


func push(value: float) -> void:
	_buf[_head] = value
	_head = (_head + 1) % _buf.size()
	_count = mini(_count + 1, _buf.size())


## Eskiden yeniye sıralı kopya.
func values() -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	out.resize(_count)
	var start: int = (_head - _count + _buf.size()) % _buf.size()
	for i: int in _count:
		out[i] = _buf[(start + i) % _buf.size()]
	return out


## Toplamı `limit`i aşmayan en uzun son ek (ör. kare süreleri ms → son N saniyenin kareleri). Son öğe tek başına
## sınırı aşsa da döner (boş olmayan dizide en az bir öğe); `limit` <= 0 ise tüm dizi.
static func tail_within(values: PackedFloat32Array, limit: float) -> PackedFloat32Array:
	if limit <= 0.0 or values.is_empty():
		return values.duplicate()
	var total: float = 0.0
	var start: int = values.size()
	while start > 0:
		var next: float = total + values[start - 1]
		if next > limit and start < values.size():
			break
		total = next
		start -= 1
	return values.slice(start)


## Sıralı dizide en yakın sıra yöntemiyle yüzdelik (p 0..100): p=0 en küçük, p=100 en büyük; boşsa 0.
static func percentile_sorted(sorted_values: PackedFloat32Array, p: float) -> float:
	var n: int = sorted_values.size()
	if n == 0:
		return 0.0
	var rank: int = ceili(clampf(p, 0.0, 100.0) / 100.0 * n)
	return sorted_values[clampi(rank - 1, 0, n - 1)]


## {"count", "min", "avg", "p50", "p95", "p99", "max"}; boş dizide hepsi 0.
static func summarize(values: PackedFloat32Array) -> Dictionary:
	var n: int = values.size()
	if n == 0:
		return {"count": 0, "min": 0.0, "avg": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted_values: PackedFloat32Array = values.duplicate()
	sorted_values.sort()
	var total: float = 0.0
	for v: float in sorted_values:
		total += v
	return {
		"count": n,
		"min": _r(sorted_values[0]),
		"avg": _r(total / n),
		"p50": _r(percentile_sorted(sorted_values, 50.0)),
		"p95": _r(percentile_sorted(sorted_values, 95.0)),
		"p99": _r(percentile_sorted(sorted_values, 99.0)),
		"max": _r(sorted_values[n - 1]),
	}


## Kare süreleri (ms) → FPS özeti: ortalama (kare sayısı / toplam süre), en düşük (en uzun kareden) ve
## "%1 düşük" (p99 kare süresinden; en yavaş %1 karenin eşiği). Boşsa hepsi 0.
static func fps_summary(frame_ms: PackedFloat32Array) -> Dictionary:
	var s: Dictionary = summarize(frame_ms)
	return {
		"avg": _fps(float(s["avg"])),
		"min": _fps(float(s["max"])),
		"p1_low": _fps(float(s["p99"])),
	}


static func _fps(ms: float) -> float:
	return _r(1000.0 / ms) if ms > 0.0 else 0.0


## Dökümde okunur kalsın diye 3 ondalık.
static func _r(v: float) -> float:
	return snappedf(v, 0.001)
