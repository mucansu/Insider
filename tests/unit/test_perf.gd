extends TestCase
## IS-067 çizim ölçümü: Args `--perf`/`--perf-seconds`, FrameStats halka tamponu + istatistik (core), PerfReport
## döküm şeması (headless işaretli), PerfProbe (main.gd'nin --perf çocuğu) şeması ve kare başı ölçüm bağlantısı.

const ArgsScript := preload("res://autoload/args.gd")

const SUMMARY_KEYS: Array[String] = ["count", "min", "avg", "p50", "p95", "p99", "max"]


func _args() -> ArgsScript:
	return autofree(ArgsScript.new()) as ArgsScript


func _floats(values: Array) -> PackedFloat32Array:
	return PackedFloat32Array(values)


# --- Args --------------------------------------------------------------------------------------------------

func test_args_default_off() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray([]))
	is_false(a.perf)
	eq(a.perf_seconds, ArgsScript.DEFAULT_PERF_SECONDS)
	eq(ArgsScript.DEFAULT_PERF_SECONDS, 10.0)
	is_false(Args.perf, "test koşusu --perf vermez; autoload kapalı")


func test_args_perf_flag_and_seconds() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray(["--host", "--perf", "--perf-seconds=15", "--port=9001"]))
	is_true(a.perf)
	eq(a.perf_seconds, 15.0)
	is_true(a.want_host)
	eq(a.port, 9001)
	eq(a.unknown.size(), 0, "tanınan argümanlar unknown'a girmez")
	a.parse(PackedStringArray([" --perf-seconds= 2.5 "]))
	is_false(a.perf, "--perf-seconds tek başına ölçümü açmaz")
	eq(a.perf_seconds, 2.5)


func test_args_invalid_seconds_keep_default() -> void:
	var a: ArgsScript = _args()
	for bad: String in ["--perf-seconds=0", "--perf-seconds=-3", "--perf-seconds=abc", "--perf-seconds=",
			"--perf-seconds", "--perf-seconds=inf", "--perf-seconds=1e400", "--perf-seconds=601", "--perf-seconds=0.5"]:
		a.parse(PackedStringArray(["--perf", bad]))
		is_true(a.perf, bad)
		eq(a.perf_seconds, ArgsScript.DEFAULT_PERF_SECONDS, "geçersiz: " + bad)
		eq(a.unknown.size(), 0, "geçersiz değer de tanınan anahtardır: " + bad)
	eq(ArgsScript.parse_perf_seconds("1"), 1.0)
	eq(ArgsScript.parse_perf_seconds("600"), 600.0)
	eq(ArgsScript.parse_perf_seconds("600.01"), 0.0)


func test_args_flag_with_value_still_enables() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray(["--perf=1"]))
	is_true(a.perf, "değer uyarıyla yok sayılır, bayrak açılır")


func test_args_reparse_resets_and_keeps_unknown_order() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray(["--perf", "--perf-seconds=30"]))
	a.parse(PackedStringArray(["--filter=x", "--perfx", "--vision-mode=directional", "--timeout=5"]))
	is_false(a.perf)
	eq(a.perf_seconds, ArgsScript.DEFAULT_PERF_SECONDS)
	eq(a.unknown, PackedStringArray(["--filter=x", "--perfx", "--timeout=5"]))
	eq(a.vision_mode, "directional", "görüş bloğu etkilenmez")


# --- FrameStats ---------------------------------------------------------------------------------------------

func test_ring_buffer_order_and_wrap() -> void:
	var r := FrameStats.new(3)
	eq(r.capacity(), 3)
	eq(r.size(), 0)
	eq(r.values(), PackedFloat32Array())
	r.push(1.0)
	r.push(2.0)
	eq(r.values(), _floats([1.0, 2.0]))
	r.push(3.0)
	r.push(4.0)
	r.push(5.0)
	eq(r.size(), 3, "kapasiteyi aşmaz")
	eq(r.values(), _floats([3.0, 4.0, 5.0]), "eskiden yeniye, en eskiler ezildi")
	r.clear()
	eq(r.size(), 0)
	r.push(9.0)
	eq(r.values(), _floats([9.0]))
	eq(FrameStats.new(0).capacity(), 1, "kapasite en az 1")


func test_percentile_nearest_rank() -> void:
	var sorted_values := PackedFloat32Array()
	for i: int in range(1, 101):
		sorted_values.append(float(i))
	eq(FrameStats.percentile_sorted(sorted_values, 0.0), 1.0)
	eq(FrameStats.percentile_sorted(sorted_values, 50.0), 50.0)
	eq(FrameStats.percentile_sorted(sorted_values, 95.0), 95.0)
	eq(FrameStats.percentile_sorted(sorted_values, 99.0), 99.0)
	eq(FrameStats.percentile_sorted(sorted_values, 100.0), 100.0)
	eq(FrameStats.percentile_sorted(sorted_values, 250.0), 100.0, "aralık dışı kenetlenir")
	eq(FrameStats.percentile_sorted(PackedFloat32Array(), 50.0), 0.0)
	eq(FrameStats.percentile_sorted(_floats([7.0]), 99.0), 7.0)


func test_summarize_and_fps() -> void:
	# 99 kare 10 ms + 1 kare 50 ms (takılma): ortalama 10,4 ms, p99 = 10 (en yakın sıra), max 50.
	var frames := PackedFloat32Array()
	for i: int in 99:
		frames.append(10.0)
	frames.append(50.0)
	var s: Dictionary = FrameStats.summarize(frames)
	eq(s.keys(), SUMMARY_KEYS as Array)
	eq(s["count"], 100)
	near(s["avg"], 10.4, 0.001)
	eq(s["min"], 10.0)
	eq(s["p50"], 10.0)
	eq(s["p99"], 10.0)
	eq(s["max"], 50.0)
	var f: Dictionary = FrameStats.fps_summary(frames)
	near(f["avg"], 1000.0 / 10.4, 0.01, "ortalama = kare sayısı / toplam süre")
	near(f["min"], 20.0, 0.001, "en uzun kare 50 ms → 20 FPS")
	near(f["p1_low"], 100.0, 0.001)
	frames.append(40.0)  # artık en yavaş %1 iki kare: p99 40 ms
	near(FrameStats.fps_summary(frames)["p1_low"], 25.0, 0.001)
	var empty: Dictionary = FrameStats.summarize(PackedFloat32Array())
	eq(empty["count"], 0)
	eq(empty["avg"], 0.0)
	eq(FrameStats.fps_summary(PackedFloat32Array()), {"avg": 0.0, "min": 0.0, "p1_low": 0.0})


func test_summarize_does_not_reorder_input() -> void:
	var frames := _floats([3.0, 1.0, 2.0])
	FrameStats.summarize(frames)
	eq(frames, _floats([3.0, 1.0, 2.0]))


func test_tail_within_time_window() -> void:
	var frames := _floats([100.0, 10.0, 20.0, 30.0])
	eq(FrameStats.tail_within(frames, 60.0), _floats([10.0, 20.0, 30.0]), "toplam 60'ı aşmayan son ek")
	eq(FrameStats.tail_within(frames, 59.0), _floats([20.0, 30.0]))
	eq(FrameStats.tail_within(frames, 10.0), _floats([30.0]), "son kare tek başına aşsa da döner")
	eq(FrameStats.tail_within(frames, 1000.0), frames)
	eq(FrameStats.tail_within(frames, 0.0), frames, "sınır yoksa hepsi")
	eq(FrameStats.tail_within(PackedFloat32Array(), 10.0), PackedFloat32Array())


func test_cost_of_push_is_small() -> void:
	# Kare başına bir push + 8 monitör toplama; 10 sn × 1000 FPS tamponunda bile ihmal edilebilir olmalı.
	var r := FrameStats.new(10000)
	var t0: int = Time.get_ticks_usec()
	for i: int in 10000:
		r.push(16.6)
	var per_push_us: float = (Time.get_ticks_usec() - t0) / 10000.0
	is_true(per_push_us < 20.0, "push %.2f µs" % per_push_us)


# --- PerfReport şeması --------------------------------------------------------------------------------------

func _monitors(value: float) -> Dictionary:
	var out: Dictionary = {}
	for key: String in PerfReport.MONITOR_KEYS:
		out[key] = _floats([value, value * 2.0])
	return out


func test_report_windowed_schema() -> void:
	var frames := _floats([16.0, 17.0, 18.0])
	var info: Dictionary = {"adapter": "GPU X", "window": [1280, 720], "frames": 999}
	var r: Dictionary = PerfReport.build(false, frames, _monitors(1.0), _monitors(3.0), info, 10.0, 0.25)
	is_false(r["headless"])
	is_true(r["valid"])
	eq(r["note"], "")
	eq(r["window_s"], 10.0)
	eq(r["interval_s"], 0.25)
	eq(r["frames"], 3, "info taban anahtarı ezemez")
	near(r["measured_s"], 0.051, 0.0001)
	eq(r["adapter"], "GPU X")
	eq(r["window"], [1280, 720])
	eq((r["frame_ms"] as Dictionary).keys(), SUMMARY_KEYS as Array)
	eq((r["fps"] as Dictionary).keys(), ["avg", "min", "p1_low"] as Array)
	for key: String in PerfReport.MONITOR_KEYS:
		var s: Dictionary = r[key]
		eq(s.keys(), SUMMARY_KEYS as Array, key)
		near(s["avg"], 1.5, 0.001, key + " ortalama aralık ortalamalarından")
		eq(s["max"], 6.0, key + " max aralık tepelerinden")
	var json: String = JSON.stringify(Game.to_json_value(r))
	is_true(JSON.parse_string(json) is Dictionary, "JSON'a yazılabilir")


func test_report_headless_marks_render_fields() -> void:
	var r: Dictionary = PerfReport.build(true, _floats([16.6, 16.7]), _monitors(5.0), _monitors(9.0), {}, 10.0, 0.25)
	is_true(r["headless"])
	is_false(r["valid"])
	has(r["note"] as String, "headless")
	for key: String in PerfReport.RENDER_ONLY_KEYS:
		eq((r[key] as Dictionary)["count"], 0, key + " headless'ta ölçülmez")
		eq((r[key] as Dictionary)["avg"], 0.0, key)
		has(r["note"] as String, key)
	near((r["process_ms"] as Dictionary)["avg"], 7.5, 0.001, "process headless'ta da ölçülür")
	eq((r["frame_ms"] as Dictionary)["count"], 2)


func test_report_tolerates_missing_and_untyped_monitors() -> void:
	var r: Dictionary = PerfReport.build(false, PackedFloat32Array(), {"draw_calls": [3, 5]}, {}, {}, 5.0, 0.25)
	is_false(r["valid"], "kare yoksa geçersiz")
	eq((r["draw_calls"] as Dictionary)["avg"], 4.0, "Array da kabul edilir")
	eq((r["render_gpu_ms"] as Dictionary)["count"], 0)


func test_probe_report_before_begin_is_headless_schema() -> void:
	# Ağaca eklenmeden, ölçüm başlamadan: şema tam, headless işaretli, motor bilgisi alanları var.
	var probe := autofree(PerfProbe.new()) as PerfProbe
	var r: Dictionary = probe.report()
	is_true(r["headless"])
	is_false(r["valid"])
	eq(r["renderer"], "gl_compatibility")
	for key: String in ["driver", "adapter", "vendor", "api_version", "window", "screen", "refresh_hz", "vsync",
			"max_fps"]:
		has(r, key)
	for key: String in PerfReport.MONITOR_KEYS:
		has(r, key)
	eq(probe.process_priority, 2147483647, "en son işlenir: process_ms tüm _process geri çağrılarını kapsar")
	eq(probe.process_physics_priority, 2147483647)


class _Busy extends Node:
	## Her karede ~3 ms _process, ~1 ms _physics_process harcar (ölçülen süreye girmeli).
	func _process(_delta: float) -> void:
		var t: int = Time.get_ticks_usec()
		while Time.get_ticks_usec() - t < 3000:
			pass

	func _physics_process(_delta: float) -> void:
		var t: int = Time.get_ticks_usec()
		while Time.get_ticks_usec() - t < 1000:
			pass


func test_probe_measures_process_and_physics_per_frame() -> void:
	# begin → process_frame/physics_frame bağlantıları gerçek ağaçta koşar; seviye sorgusu ve ısınma test için açık.
	var busy := autofree(_Busy.new()) as Node
	var probe := autofree(PerfProbe.new()) as PerfProbe
	probe.level_query = func() -> bool: return true
	probe.warmup_sec = 0.0
	tree().root.add_child(busy)
	tree().root.add_child(probe)
	probe.begin(2.0, false)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await tree().process_frame
	var r: Dictionary = probe.report()
	tree().root.remove_child(probe)
	tree().root.remove_child(busy)
	is_true(int(r["frames"]) > 5, "kareler sayıldı: %s" % r["frames"])
	var process: Dictionary = r["process_ms"]
	var physics: Dictionary = r["physics_ms"]
	is_true(int(process["count"]) >= 2, "0,25 sn aralıkları yazıldı")
	is_true(float(process["avg"]) >= 2.5, "_process maliyeti kare başına ölçülür: %s ms" % process["avg"])
	is_true(float(process["avg"]) < float(r["frame_ms"]["avg"]) + 0.5, "process ≤ kare süresi")
	# Fizik adımı her karede olmayabilir (FPS > 60): adımlı karelerin tepesi ~1 ms olmalı.
	is_true(float(physics["max"]) >= 0.9, "_physics_process maliyeti ölçülür: max %s ms" % physics["max"])
	has(r, "process_max_1s_ms")
	is_true(r["headless"])
	eq((r["draw_calls"] as Dictionary)["count"], 0, "headless'ta renderer alanı boş")
