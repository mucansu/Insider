class_name PerfProbe
extends Node
## Render/performance measurement (IS-067; mimari.md S6 `--perf`, `--perf-seconds=N`). main.gd adds it as a child only with `--perf`;
## the dump's "render" key comes from `report()` (schema: core/perf_report.gd).
##
## What is measured:
## - Frame time: wall clock between consecutive `SceneTree.process_frame` signals (ms).
## - process_ms: `process_frame` → this node's `_process` (it runs last via the highest `process_priority`, so the span covers all `_process` callbacks).
## - physics_ms: per physics step `physics_frame` → this node's `_physics_process`, summed per frame (0 if no step); excludes the physics server step.
## - process_total_ms (windowed only): `process_frame` → `RenderingServer.frame_pre_draw`: callbacks + deferred calls + `_draw` recording + pre-draw sync.
##   No draw loop headless (signal never fires); written one frame late. `Performance.TIME_PROCESS`/`TIME_PHYSICS_PROCESS` are not per-frame
##   (updated once a second, hold the WORST frame), hence the separate `process_max_1s_ms`/`physics_max_1s_ms` fields.
## - Renderer monitors (draw calls, objects, primitives, viewport render CPU/GPU, frame setup): read every frame (value belongs to the previous drawn frame).
## Each monitor's 0.25 s interval mean and max go to separate ring buffers (sparse single samples would favour long frames) holding the last `seconds`.
## Measured only while a level is loaded, excluding `warmup_sec` after loading. In windowed runs automation's 60 FPS cap is lifted (vsync stays per project settings).

const INTERVAL_SEC := 0.25
## Time not measured after a level loads (load / first physics frame spikes).
const DEFAULT_WARMUP_SEC := 1.0
## Frame buffer capacity = seconds × this (full window up to 1000 FPS; the report trims to the last N seconds).
const FRAMES_PER_SEC_CAP := 1000
const _LAST := 2147483647

## Whether measurement is on (tests may override; default: a level is loaded in Game).
var level_query: Callable = func() -> bool: return Game.current_level() != null
var warmup_sec: float = DEFAULT_WARMUP_SEC

var _seconds: float = 10.0
var _render: bool = false
var _viewport: RID = RID()
var _frames: FrameStats = null
var _means: Array[FrameStats] = []  # interval means, in PerfReport.MONITOR_KEYS order
var _peaks: Array[FrameStats] = []  # interval maxima
var _sum: PackedFloat64Array = []
var _max: PackedFloat64Array = []
var _acc_frames: int = 0
var _active: bool = false
var _last_frame_usec: int = 0
var _process_start_usec: int = 0
var _physics_start_usec: int = 0
var _physics_usec: int = 0
var _total_ms: float = 0.0
var _level_since_usec: int = -1
var _next_flush_usec: int = 0


func _init() -> void:
	process_priority = _LAST
	process_physics_priority = _LAST
	set_process(false)
	set_physics_process(false)


## Starts measuring: `seconds` window, `render` = a renderer exists (windowed). The node must be in the tree.
func begin(seconds: float, render: bool) -> void:
	_seconds = seconds
	_render = render
	_frames = FrameStats.new(ceili(seconds * FRAMES_PER_SEC_CAP))
	var intervals: int = ceili(seconds / INTERVAL_SEC)
	_means.clear()
	_peaks.clear()
	for _key: String in PerfReport.MONITOR_KEYS:
		_means.append(FrameStats.new(intervals))
		_peaks.append(FrameStats.new(intervals))
	_sum.resize(PerfReport.MONITOR_KEYS.size())
	_sum.fill(0.0)
	_max.resize(PerfReport.MONITOR_KEYS.size())
	if render:
		_viewport = get_tree().root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_viewport, true)
		Engine.max_fps = 0
		RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	get_tree().process_frame.connect(_on_process_frame)
	get_tree().physics_frame.connect(_on_physics_frame)
	set_process(true)
	set_physics_process(true)


func _on_pre_draw() -> void:
	if _process_start_usec > 0:
		_total_ms = (Time.get_ticks_usec() - _process_start_usec) / 1000.0


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)


func _on_physics_frame() -> void:
	_physics_start_usec = Time.get_ticks_usec()


func _physics_process(_delta: float) -> void:
	if _physics_start_usec > 0:
		_physics_usec += Time.get_ticks_usec() - _physics_start_usec
		_physics_start_usec = 0


func _on_process_frame() -> void:
	var now: int = Time.get_ticks_usec()
	var last: int = _last_frame_usec
	_last_frame_usec = now
	_process_start_usec = now
	_active = false
	if not bool(level_query.call()):
		_level_since_usec = -1
		_physics_usec = 0
		return
	if _level_since_usec < 0:
		_level_since_usec = now
	if last == 0 or now - _level_since_usec < int(warmup_sec * 1000000.0):
		_physics_usec = 0
		_next_flush_usec = now + int(INTERVAL_SEC * 1000000.0)
		return
	_frames.push((now - last) / 1000.0)
	_active = true


func _process(_delta: float) -> void:
	if not _active:
		return
	_active = false
	var now: int = Time.get_ticks_usec()
	var values: PackedFloat64Array = _read((now - _process_start_usec) / 1000.0, _physics_usec / 1000.0)
	_physics_usec = 0
	for i: int in values.size():
		_sum[i] += values[i]
		_max[i] = values[i] if _acc_frames == 0 else maxf(_max[i], values[i])
	_acc_frames += 1
	if now < _next_flush_usec:
		return
	_next_flush_usec = now + int(INTERVAL_SEC * 1000000.0)
	for i: int in _sum.size():
		_means[i].push(_sum[i] / _acc_frames)
		_peaks[i].push(_max[i])
	_sum.fill(0.0)
	_acc_frames = 0


## This frame's values (PerfReport.MONITOR_KEYS order; times in ms).
func _read(process_ms: float, physics_ms: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = [
		process_ms,
		physics_ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
	]
	if not _viewport.is_valid():
		return out  # headless: RENDER_* not measured (0 in the report)
	out[4] = _total_ms  # previous frame's process step
	out[5] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	out[6] = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	out[7] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	out[8] = RenderingServer.viewport_get_measured_render_time_cpu(_viewport)
	out[9] = RenderingServer.viewport_get_measured_render_time_gpu(_viewport)
	out[10] = RenderingServer.get_frame_setup_time_cpu()
	return out


## Dump "render" section. The schema is complete even if `begin` was never called (counts 0).
func report() -> Dictionary:
	var means: Dictionary = {}
	var peaks: Dictionary = {}
	for i: int in _means.size():
		means[PerfReport.MONITOR_KEYS[i]] = _means[i].values()
		peaks[PerfReport.MONITOR_KEYS[i]] = _peaks[i].values()
	var screen: int = DisplayServer.window_get_current_screen()
	var info: Dictionary = {
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"api_version": RenderingServer.get_video_adapter_api_version(),
		"window": DisplayServer.window_get_size(),
		"screen": DisplayServer.screen_get_size(screen),
		"refresh_hz": snappedf(DisplayServer.screen_get_refresh_rate(screen), 0.01),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
	}
	var frames: PackedFloat32Array = PackedFloat32Array()
	if _frames != null:
		frames = FrameStats.tail_within(_frames.values(), _seconds * 1000.0)
	return PerfReport.build(not _render, frames, means, peaks, info, _seconds, INTERVAL_SEC)
