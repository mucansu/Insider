extends Node
## Startup scene (mimari.md §2, S3, S6).
## - No args: switches to `res://ui/main_menu.tscn` if present, else warns (headless exits 0, windowed waits on an empty scene).
##   The UI (HUD) returns to the menu after a session; main.gd and Game never change scenes (avoids a double switch).
## - `--host`: opens a session and loads `--level` (default Game.DEFAULT_LEVEL); prints one READY_MARKER line to stdout when ready
##   (tools/net_smoke.py waits for it).
## - `--join=ADDR`: connects; prints READY_MARKER once accepted.
## - A session started by args never returns to the menu, it exits: host lost = code 0; join failure or host/level/player scene
##   failing to load = code 1 (the dump is written if requested).
## - Automation (`--dump` or `--quit-after`; Args.is_automated()):
##   · `--quit-after=SEC`: writes the dump at SEC, stays QUIT_LINGER_SEC longer (so other processes' dumps see the full session),
##     then Net.leave() and exit 0.
##   · On host loss the dump ("host_lost": true) is written immediately (no linger).
##   · Extra dump keys: "exit_reason" (quit_after | host_lost | connection_failed | error) and "samples": player positions in
##     wall-clock-aligned SAMPLE_INTERVAL_SEC slots [{"slot": int, "players": {"<peer_id>": [x, y]}}] so same-machine processes compare the same slot.
##   · Frame rate is capped at MAX_FPS_AUTOMATED (headless loop must not eat the CPU).
## - Screenshots (IS-022; `--screenshot-at=SEC[,SEC…]` + `--screenshot-dir=PATH`): at each time (same clock as --quit-after), after that frame
##   is drawn (RenderingServer.frame_post_draw) the root viewport is written to `PATH/shot_<NN>.png` (NN = moment index; see screenshot_file_name).
##   Times after --quit-after are skipped with a warning; headless has no renderer image (one warning, no file); a moment before the level loads
##   (client still connecting) is skipped. Each moment prints `INSIDERS_SCREENSHOT ok|skipped|failed at=SEC ...` to stdout.
##   `--window-size=WxH` sets the window size on windowed launch.
##   Dump: "screenshots": [{"at": SEC, "file": path, "ok": bool, "size": [w, h], "skipped": reason}].
## - At startup the viewport clear colour is set to the active tone's BG (IS-027).
## - Render measurement (IS-067; `--perf`, `--perf-seconds=N`): PerfProbe (perf_probe.gd), "render" section in the dump.

const MAIN_MENU := "res://ui/main_menu.tscn"
const READY_MARKER := "INSIDERS_READY"
const SCREENSHOT_MARKER := "INSIDERS_SCREENSHOT"
const QUIT_LINGER_SEC := 1.0
## Fallback quit for --quit-after: this long after the normal exit (if main was freed).
const BACKSTOP_SEC := 2.0
const SAMPLE_INTERVAL_SEC := 0.2
const MAX_SAMPLES := 3000
const MAX_FPS_AUTOMATED := 60

## Tests may override.
var menu_scene: String = MAIN_MENU

var _finishing: bool = false
var _exit_reason: String = ""
var _sampling: bool = false
var _samples: Array[Dictionary] = []
var _last_slot: int = -1
var _screenshots: Array[Dictionary] = []


func _ready() -> void:
	apply_clear_color()
	_start.call_deferred()


## Viewport clear colour = active tone's BG (IS-027, KR-005): dark outside the map instead of default grey (#4d4d4d).
static func apply_clear_color() -> void:
	RenderingServer.set_default_clear_color(ThemeTokens.tone().bg_color)


## Startup mode: &"host", &"join", &"menu" (menu scene exists) or &"none".
func start_mode(want_host: bool, join_address: String) -> StringName:
	if want_host:
		return &"host"
	if not join_address.is_empty():
		return &"join"
	if ResourceLoader.exists(menu_scene):
		return &"menu"
	return &"none"


func _start() -> void:
	var automated: bool = Args.is_automated()
	if automated:
		Engine.max_fps = MAX_FPS_AUTOMATED
		Game.register_dump_provider("exit_reason", func() -> String: return _exit_reason)
		if not Args.dump_path.is_empty():
			_sampling = true
			Game.register_dump_provider("samples", func() -> Array[Dictionary]: return _samples)
		if Args.quit_after > 0.0:
			get_tree().create_timer(Args.quit_after).timeout.connect(_finish.bind(0, "quit_after"))
			# Fallback: if main is freed meanwhile (scene changed) the process still quits.
			var backstop: SceneTreeTimer = get_tree().create_timer(Args.quit_after + QUIT_LINGER_SEC + BACKSTOP_SEC)
			backstop.timeout.connect(Net.leave)
			backstop.timeout.connect(get_tree().quit.bind(0))
	_start_perf()  # IS-067 (block at end of file; no-op without --perf)
	if Args.window_size != Vector2i.ZERO and capture_supported():
		get_window().size = Args.window_size
	if Args.wants_screenshots():
		_schedule_screenshots()
	if not Args.player_scene.is_empty():
		var scene: PackedScene = null
		if ResourceLoader.exists(Args.player_scene):
			scene = load(Args.player_scene) as PackedScene
		if scene == null:
			_fail("oyuncu sahnesi yüklenemedi: " + Args.player_scene)
			return
		Game.player_scene = scene
	if not Args.player_name.is_empty():
		Game.set_local_name(Args.player_name)
	match start_mode(Args.want_host, Args.join_address):
		&"host":
			_start_host()
		&"join":
			_start_join()
		&"menu":
			if automated:
				push_warning("main: otomasyon kipinde oturum argümanı yok; menüye geçilmiyor")
			else:
				get_tree().change_scene_to_file.call_deferred(menu_scene)
		_:
			push_warning("main: %s yok; menüsüz açılış (oturum için --host ya da --join=ADDR)" % menu_scene)
			if DisplayServer.get_name() == "headless" and not automated:
				get_tree().quit(0)


func _start_host() -> void:
	var err: Error = Net.host(Args.port)
	if err != OK:
		_fail("host açılamadı: port %d (%s)" % [Args.port, error_string(err)])
		return
	var level: String = Args.level if not Args.level.is_empty() else Game.DEFAULT_LEVEL
	if not ResourceLoader.exists(level):
		_fail("seviye bulunamadı: " + level)
		return
	Game.start_level(level)
	if Game.current_level() == null:
		_fail("seviye yüklenemedi: " + level)
		return
	print("%s host port=%d level=%s" % [READY_MARKER, Args.port, level])


func _start_join() -> void:
	Net.connected_to_host.connect(_on_connected_to_host)
	Net.connection_failed.connect(_on_connection_failed)
	Net.host_disconnected.connect(_on_host_disconnected)
	Net.join(Args.join_address, Args.port)  # on error connection_failed is emitted too


func _on_connected_to_host() -> void:
	print("%s client peer=%d" % [READY_MARKER, Net.local_peer_id()])


func _on_connection_failed() -> void:
	push_warning("main: %s:%d adresine bağlanılamadı" % [Args.join_address, Args.port])
	_finish(1, "connection_failed")


func _on_host_disconnected() -> void:
	if _finishing:
		return  # host leaving during exit (linger) is expected
	push_warning("main: host bağlantısı koptu")
	_finish(0, "host_lost")


func _fail(message: String) -> void:
	push_error("main: " + message)
	_finish(1, "error")


func _finish(code: int, reason: String) -> void:
	if _finishing:
		return
	_finishing = true
	_exit_reason = reason
	_write_dump()
	var tree: SceneTree = get_tree()
	if reason == "quit_after" and Net.is_online():
		# main may be freed during the linger (windowed: HUD goes to the menu when the host leaves), so
		# no await: the timer is bound directly to Net.leave and tree.quit (not to main).
		var timer: SceneTreeTimer = tree.create_timer(QUIT_LINGER_SEC)
		timer.timeout.connect(Net.leave)
		timer.timeout.connect(tree.quit.bind(code))
		return
	Net.leave()
	tree.quit(code)


## Whether this is a windowed (real renderer) launch; headless has no viewport image.
static func capture_supported() -> bool:
	return DisplayServer.get_name() != "headless"


## Moments to capture: if quit_after > 0 later moments are dropped (the process won't live that long).
static func screenshot_plan(moments: PackedFloat64Array, quit_after: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = []
	for t: float in moments:
		if quit_after > 0.0 and t > quit_after:
			continue
		out.append(t)
	return out


## File name of moment `index` (tools/screenshot.py expects the same naming).
static func screenshot_file_name(index: int) -> String:
	return "shot_%02d.png" % index


func _schedule_screenshots() -> void:
	Game.register_dump_provider("screenshots", func() -> Array[Dictionary]: return _screenshots)
	if not capture_supported():
		push_warning("main: headless açılışta ekran görüntüsü alınamaz; --screenshot-at yok sayıldı")
		return
	var dir: String = ProjectSettings.globalize_path(Args.screenshot_dir)
	var err: Error = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("main: görüntü dizini açılamadı: %s (%s)" % [dir, error_string(err)])
		return
	var plan: PackedFloat64Array = screenshot_plan(Args.screenshot_at, Args.quit_after)
	if plan.size() < Args.screenshot_at.size():
		push_warning("main: --quit-after (%s sn) sonrasındaki %d görüntü anı atlandı"
				% [Args.quit_after, Args.screenshot_at.size() - plan.size()])
	for i: int in plan.size():
		var path: String = dir.path_join(screenshot_file_name(i))
		get_tree().create_timer(plan[i]).timeout.connect(take_screenshot.bind(plan[i], path))


## Reason no image is taken ("" = taken): "headless" without a window, "level_not_loaded" if the level isn't loaded yet
## (client connecting/loading; blank screen).
static func screenshot_skip_reason(can_capture: bool, level_loaded: bool) -> String:
	if not can_capture:
		return "headless"
	if not level_loaded:
		return "level_not_loaded"
	return ""


## When this frame is drawn, writes the root viewport to `path` as PNG; the result goes to the dump's "screenshots" list
## and one line is printed to stdout: `SCREENSHOT_MARKER ok|skipped|failed at=SEC ...` (read by tools/screenshot.py).
## A moment before the level loads is skipped (no blank frame written).
func take_screenshot(at: float, path: String) -> void:
	var entry: Dictionary = {"at": at, "file": path, "ok": false}
	_screenshots.append(entry)
	var reason: String = screenshot_skip_reason(capture_supported(), Game.current_level() != null)
	if reason == "headless":
		return
	if not reason.is_empty():
		entry["skipped"] = reason
		print("%s skipped at=%s reason=%s" % [SCREENSHOT_MARKER, at, reason])
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_warning("main: %s sn görüntüsü boş geldi" % at)
		print("%s failed at=%s reason=empty_image" % [SCREENSHOT_MARKER, at])
		return
	entry["size"] = [image.get_width(), image.get_height()]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("main: görüntü yazılamadı: %s (%s)" % [path, error_string(err)])
		return
	entry["ok"] = true
	print("%s ok at=%s file=%s" % [SCREENSHOT_MARKER, at, path])


## For tests: recorded taken/attempted screenshots.
func screenshot_records() -> Array[Dictionary]:
	return _screenshots


func _write_dump() -> void:
	if Args.dump_path.is_empty():
		return
	var file: FileAccess = FileAccess.open(Args.dump_path, FileAccess.WRITE)
	if file == null:
		push_error("main: döküm yazılamadı: %s (%s)" % [Args.dump_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(Game.collect_dump(), "  ", true))
	file.close()


func _process(_delta: float) -> void:
	if not _sampling or _finishing:
		return
	var slot: int = floori(Time.get_unix_time_from_system() / SAMPLE_INTERVAL_SEC)
	if slot == _last_slot:
		return
	_last_slot = slot
	var level: Level = Game.current_level() as Level
	var root: Node2D = level.players_root() if level != null else null
	if root == null:
		return
	var positions: Dictionary = {}
	for child: Node in root.get_children():
		if child is Node2D:
			var p: Vector2 = (child as Node2D).position
			positions[str(child.name)] = [p.x, p.y]
	if positions.is_empty() or _samples.size() >= MAX_SAMPLES:
		return
	_samples.append({"slot": slot, "players": positions})


# --- IS-067: render/perf measurement (`--perf`; measured by perf_probe.gd, schema core/perf_report.gd) ---------------

## With `--perf` builds the PerfProbe child and adds the "render" provider to the dump; otherwise a no-op.
func _start_perf() -> void:
	if not Args.perf:
		return
	var probe := PerfProbe.new()
	probe.name = "PerfProbe"
	add_child(probe)
	probe.begin(Args.perf_seconds, capture_supported())
	Game.register_dump_provider("render", probe.report)
