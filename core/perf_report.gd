class_name PerfReport
extends RefCounted
## Pure schema builder for the dump "render" section (IS-067; mimari.md S6 `--perf`). PerfProbe does the measuring (engine singletons); this only summarises values: node-free, testable.

## Monitor names (dump keys; PerfProbe reads in this order). Times are ms per frame: `process_ms`/`physics_ms` = _process/_physics_process callbacks;
## `process_total_ms` = the whole processing step (callbacks + deferred + `_draw` records; windowed only). `*_max_1s_ms` is the engine's Performance.TIME_* value (updated once per second: worst frame of the last second, not per frame).
const MONITOR_KEYS: Array[String] = [
	"process_ms", "physics_ms", "process_max_1s_ms", "physics_max_1s_ms", "process_total_ms", "draw_calls",
	"objects", "primitives", "render_cpu_ms", "render_gpu_ms", "frame_setup_ms",
]
## Monitors that need a renderer (cannot be measured headless, stay 0).
const RENDER_ONLY_KEYS: Array[String] = [
	"process_total_ms", "draw_calls", "objects", "primitives", "render_cpu_ms", "render_gpu_ms", "frame_setup_ms",
]


## `frames`: frame times (ms); `means`/`peaks`: monitor name -> interval means / interval maxima (PackedFloat32Array); `info`: hardware/window fields (copied as-is; cannot override base keys).
## Schema: {"headless", "valid", "note", "window_s", "measured_s", "interval_s", "frames", "frame_ms": summary, "fps": {"avg","min","p1_low"}, <info fields>, <each MONITOR_KEYS>: summary};
## summary = FrameStats.summarize (of means), "max" = largest of the interval maxima. Headless: RENDER_ONLY_KEYS get an empty summary (all 0), "valid": false and "note" says so.
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
