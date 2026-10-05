extends TestCase
## IS-102 (S3/S6 addendum): run marker `level_started` {run, level, seed} at every level start on the host ("Again" keeps the history;
## markers split it into runs, host-local: no signal, not broadcast), dump views without markers (heist.events_main / events_shared),
## MAX_EVENTS cap, and the `--log-on-exit` writer (session end, exit skip rule, unwritable path -> warning + user:// fallback).
## Args parsing of the flag: test_args.gd. Real process exit: IS-102 report (AC3).

const LEVEL := "res://tests/fixtures/empty_level.tscn"
const LEVEL_B := "res://tests/fixtures/empty_level_b.tscn"
const PLAYER := "res://tests/fixtures/dummy_player.tscn"
const LOG_DIR := "user://is102_test"

var _previous_scene: PackedScene = null
var _previous_log: String = ""


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _host() -> bool:
	_previous_scene = Game.player_scene
	_previous_log = Args.log_on_exit
	Game.player_scene = load(PLAYER) as PackedScene
	return eq(Net.host(free_udp_port()), OK)


func _leave() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = _previous_scene
	Args.log_on_exit = _previous_log
	Game._exit_log_written = ""


static func _kinds(events: Array) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in events:
		out.append(str(e["kind"]))
	return out


static func _remove_tree(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)
	for d: String in dir.get_directories():
		_remove_tree(dir_path.path_join(d))
		dir.remove(d)
	DirAccess.remove_absolute(dir_path)


static func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## AC1: "Again" keeps the history; each run starts with level_started (run 1, 2), events in between stay; dump views drop the markers.
func test_restart_keeps_history_split_by_run_markers() -> void:
	if not _host():
		return
	Game.start_level(LEVEL)
	Game.raise_session_event(&"alarm", {"n": 1})
	Game.request_restart()
	Game.raise_session_event(&"police_called", {"n": 2})
	var events: Array = Game.collect_dump()["events"]
	eq(_kinds(events), ["level_started", "alarm", "level_started", "police_called"], "geçmiş korunur, koşular ayrılır")
	eq(events[0]["data"], {"run": 1, "level": LEVEL, "seed": events[0]["data"]["seed"]})
	eq(events[2]["data"]["run"], 2, "Bir daha = koşu 2")
	eq(events[2]["data"]["level"], LEVEL)
	eq(events[2]["data"]["seed"], Game.session_seed(), "işin oturum tohumu işarette")
	var heist: Dictionary = Game._heist_dump()
	eq(_kinds(heist["events_main"]), ["alarm", "police_called"], "events_main koşu işaretini içermez")
	eq(_kinds(heist["events_shared"]), ["alarm", "police_called"], "events_shared = istemcilerin de aldığı olaylar")
	# Level change counts as a new run too.
	Game.start_level(LEVEL_B)
	var last: Dictionary = (Game.collect_dump()["events"] as Array).back()
	eq(last, {"kind": "level_started", "data": {"run": 3, "level": LEVEL_B, "seed": Game.session_seed()}})
	await _leave()
	eq(Game.collect_dump()["events"], [], "oturum sonu geçmişi siler")
	# A new session counts from 1 again.
	if not _host():
		return
	Game.start_level(LEVEL)
	eq((Game.collect_dump()["events"] as Array)[0]["data"]["run"], 1, "yeni oturum koşu 1'den başlar")
	await _leave()


## The marker precedes events raised while the level loads (e.g. from level_loaded listeners), so each run's events follow it.
func test_marker_precedes_events_raised_during_load() -> void:
	if not _host():
		return
	var raise: Callable = func(_level: Node) -> void: Game.raise_session_event(&"loaded_probe")
	Game.level_loaded.connect(raise)
	Game.start_level(LEVEL)
	Game.level_loaded.disconnect(raise)
	eq(_kinds(Game.collect_dump()["events"]), ["level_started", "loaded_probe"])
	await _leave()


func test_history_capped_at_max_events() -> void:
	if not _host():
		return
	Game.start_level(LEVEL)
	for i: int in Game.MAX_EVENTS + 5:
		Game.raise_session_event(&"tick", {"i": i})
	var events: Array = Game.collect_dump()["events"]
	eq(events.size(), Game.MAX_EVENTS, "tavan korunur")
	eq(events.back()["data"]["i"], Game.MAX_EVENTS + 4, "en yeni kalır")
	eq(events[0]["data"]["i"], 5, "en eskiler (işaret dahil) düşer")
	await _leave()


## `--log-on-exit` writer: dump + log_reason; the run marker and owner-independent keys are in the file.
func test_write_exit_log_writes_dump() -> void:
	if not _host():
		return
	Game.start_level(LEVEL)
	Game.raise_session_event(&"alarm")
	var path: String = LOG_DIR.path_join("alt/x.json")
	eq(Game._write_exit_log(path, "unit"), path, "eksik dizin oluşturulur")
	var d: Dictionary = _read_json(path)
	eq(d.get("log_reason"), "unit")
	eq(d.get("is_host"), true)
	eq(_kinds(d.get("events", [])), ["level_started", "alarm"])
	await _leave()
	_remove_tree(LOG_DIR)


## Unwritable path: warning (not an error) and a user://<file name> fallback.
func test_write_exit_log_unwritable_falls_back() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var blocker: FileAccess = FileAccess.open(LOG_DIR.path_join("dosya"), FileAccess.WRITE)
	blocker.store_string("x")
	blocker.close()
	var bad: String = LOG_DIR.path_join("dosya/is102_yedek.json")  # parent is a file
	eq(Game._write_exit_log(bad, "unit"), "user://is102_yedek.json", "yedek yol")
	is_true(FileAccess.file_exists("user://is102_yedek.json"))
	DirAccess.remove_absolute("user://is102_yedek.json")
	_remove_tree(LOG_DIR)
	Game._exit_log_written = ""


## Session end writes before cleanup ("session_end", events intact); the later exit hook does not overwrite it with an empty dump.
func test_session_end_writes_and_exit_skips() -> void:
	if not _host():
		return
	var path: String = LOG_DIR.path_join("oturum.json")
	Args.log_on_exit = path
	Game.start_level(LEVEL)
	Game.raise_session_event(&"alarm")
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	var d: Dictionary = _read_json(path)
	eq(d.get("log_reason"), Game.EXIT_LOG_SESSION_END)
	eq(_kinds(d.get("events", [])), ["level_started", "alarm"], "temizlikten önce yazıldı")
	Game._exit_log_final(Game.EXIT_LOG_QUIT)
	eq(_read_json(path).get("log_reason"), Game.EXIT_LOG_SESSION_END, "oturum bitmiş ve yazılmış: çıkış ezmez")
	await _leave()
	_remove_tree(LOG_DIR)


## Window close with an active session writes "window_close"; the finalising tree's hook then skips.
func test_window_close_writes_once() -> void:
	if not _host():
		return
	var path: String = LOG_DIR.path_join("kapat.json")
	Args.log_on_exit = path
	Game.start_level(LEVEL)
	Game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	eq(_read_json(path).get("log_reason"), Game.EXIT_LOG_WINDOW_CLOSE)
	DirAccess.remove_absolute(path)
	Game._exit_log_final(Game.EXIT_LOG_QUIT)
	is_false(FileAccess.file_exists(path), "kapatma isteği yazdı; ağaç kapanışı yeniden yazmaz")
	Args.log_on_exit = ""  # session end must not write in this test
	await _leave()
	_remove_tree(LOG_DIR)
