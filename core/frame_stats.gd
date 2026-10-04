class_name FrameStats
extends RefCounted
## Fixed-capacity ring buffer + pure statistics (IS-067, draw measurement; mimari.md S6 `--perf`).
## Node-free; callers supply the values (frame ms, draw calls, ...). When full it overwrites the oldest; `values()` returns a copy oldest-first.

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


## Copy ordered oldest to newest.
func values() -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	out.resize(_count)
	var start: int = (_head - _count + _buf.size()) % _buf.size()
	for i: int in _count:
		out[i] = _buf[(start + i) % _buf.size()]
	return out


## Longest suffix whose sum does not exceed `limit` (e.g. frame ms -> frames of the last N seconds). The last element is
## always returned (non-empty input yields at least one); `limit` <= 0 returns the whole array.
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


## Nearest-rank percentile of a sorted array (p 0..100): p=0 min, p=100 max; 0 if empty.
static func percentile_sorted(sorted_values: PackedFloat32Array, p: float) -> float:
	var n: int = sorted_values.size()
	if n == 0:
		return 0.0
	var rank: int = ceili(clampf(p, 0.0, 100.0) / 100.0 * n)
	return sorted_values[clampi(rank - 1, 0, n - 1)]


## {"count", "min", "avg", "p50", "p95", "p99", "max"}; all 0 for an empty array.
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


## Frame ms -> FPS summary: average (frames / total time), minimum (longest frame) and "1% low" (p99 frame time).
## All 0 if empty.
static func fps_summary(frame_ms: PackedFloat32Array) -> Dictionary:
	var s: Dictionary = summarize(frame_ms)
	return {
		"avg": _fps(float(s["avg"])),
		"min": _fps(float(s["max"])),
		"p1_low": _fps(float(s["p99"])),
	}


static func _fps(ms: float) -> float:
	return _r(1000.0 / ms) if ms > 0.0 else 0.0


## 3 decimals to keep dumps readable.
static func _r(v: float) -> float:
	return snappedf(v, 0.001)
