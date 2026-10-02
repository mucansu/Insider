class_name PerfReport
extends RefCounted
## Döküm "render" bölümünün saf şema kurucusu (IS-067; mimari.md S6 `--perf`). Ölçümü PerfProbe yapar (motor
## tekilleri), burası yalnız değerleri özetler: düğümsüz, test edilir.

## Monitör adları (dökümdeki anahtarlar; PerfProbe bu sırayla okur). Süreler ms, kare başına:
## `process_ms`/`physics_ms` = _process/_physics_process geri çağrıları; `process_total_ms` = işleme adımının
## tamamı (geri çağrılar + ertelenmiş çağrılar + `_draw` kayıtları; yalnız pencereli). `*_max_1s_ms` motorun
## Performance.TIME_* değeridir (saniyede bir güncellenir, son saniyenin en kötü karesi — kare başı değil).
const MONITOR_KEYS: Array[String] = [
	"process_ms", "physics_ms", "process_max_1s_ms", "physics_max_1s_ms", "process_total_ms", "draw_calls",
	"objects", "primitives", "render_cpu_ms", "render_gpu_ms", "frame_setup_ms",
]
## Renderer gerektiren (headless'ta ölçülemeyen, 0 kalan) monitörler.
const RENDER_ONLY_KEYS: Array[String] = [
	"process_total_ms", "draw_calls", "objects", "primitives", "render_cpu_ms", "render_gpu_ms", "frame_setup_ms",
]


## `frames`: kare süreleri (ms); `means`/`peaks`: monitör adı -> aralık ortalamaları / aralık en büyükleri
## (PackedFloat32Array); `info`: donanım/pencere alanları (olduğu gibi kopyalanır; taban anahtarları ezemez).
## Şema: {"headless", "valid", "note", "window_s", "measured_s", "interval_s", "frames", "frame_ms": özet,
## "fps": {"avg","min","p1_low"}, <info alanları>, <her MONITOR_KEYS>: özet}; özet = FrameStats.summarize
## (ortalamalar), "max" = aralık en büyüklerinin en büyüğü. Headless'ta RENDER_ONLY_KEYS boş özet (hepsi 0),
## "valid": false ve "note" bunu söyler.
static func build(headless: bool, frames: PackedFloat32Array, means: Dictionary, peaks: Dictionary,
		info: Dictionary, window_s: float, interval_s: float) -> Dictionary:
	var measured: float = 0.0
	for ms: float in frames:
		measured += ms
	var note: String = ""
	if headless:
		note = "headless: renderer yok; %s 0 (ölçülmedi)" % ", ".join(PackedStringArray(RENDER_ONLY_KEYS))
	var report: Dictionary = {}
	for key: Variant in info:
		report[str(key)] = info[key]
	report.merge({
		"headless": headless,
		"valid": not headless and not frames.is_empty(),
		"note": note,
		"window_s": window_s,
		"measured_s": snappedf(measured / 1000.0, 0.001),
		"interval_s": interval_s,
		"frames": frames.size(),
		"frame_ms": FrameStats.summarize(frames),
		"fps": FrameStats.fps_summary(frames),
	}, true)
	for key: String in MONITOR_KEYS:
		var values: PackedFloat32Array = _floats(means.get(key))
		var tops: PackedFloat32Array = _floats(peaks.get(key))
		if headless and RENDER_ONLY_KEYS.has(key):
			values = PackedFloat32Array()
			tops = PackedFloat32Array()
		var summary: Dictionary = FrameStats.summarize(values)
		if not tops.is_empty():
			summary["max"] = maxf(float(summary["max"]), float(FrameStats.summarize(tops)["max"]))
		report[key] = summary
	return report


static func _floats(value: Variant) -> PackedFloat32Array:
	if typeof(value) == TYPE_PACKED_FLOAT32_ARRAY:
		return value
	if typeof(value) == TYPE_PACKED_FLOAT64_ARRAY or typeof(value) == TYPE_ARRAY:
		return PackedFloat32Array(value)
	return PackedFloat32Array()
