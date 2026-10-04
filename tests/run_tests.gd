extends SceneTree
## Unit test runner (mimari.md §5). Plugin-free, headless:
## godot --headless --path . -s res://tests/run_tests.gd [-- --filter=TEXT --timeout=SEC --verbose-tests --dir=PATH]
## Finds tests/unit/test_*.gd (extends TestCase, tests/t.gd) and runs every argument-less `test_*` method
## on a fresh instance. Short mode (default, IS-090) prints only [FAIL]/[ORPHAN] lines plus one summary line
## ("N test: N geçti, M başarısız (T ms)"; format is fixed, scripts grep it). Verbose: `--verbose-tests` or TESTS_VERBOSE=1.
## `--dir=PATH` overrides the test dir (only for the runner's own test: tools/test_run_tests.py). Failure causes:
## assertion, script error during a test, disallowed push_error/engine error, timeout.
## Test hygiene (IS-046): the orphan node count (Performance.OBJECT_ORPHAN_NODE_COUNT) is compared before/after each test
## (autofree + one frame later); an increase prints `[ORPHAN] file::test +N` and is summarised at the end.
## Threshold 0: a single orphan node fails the run (no escape hatch).
## Exit code: 0 all passed; 1 any failure, orphan node, no tests to run, or timeout.

const UNIT_DIR := "res://tests/unit"
const DEFAULT_TIMEOUT_SEC := 30.0


## Collects errors reported by the engine and scripts (not warnings); callable from any thread.
class ErrorCapture extends Logger:
	var _mutex := Mutex.new()
	var _entries: Array[Dictionary] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text: String = code if rationale.is_empty() else rationale
		var where: String = "%s:%d, %s" % [file, line, function]
		# Show the location of engine errors (incl. push_error) as the script line that triggered them.
		if error_type != ERROR_TYPE_SCRIPT and not script_backtraces.is_empty() and script_backtraces[0].get_frame_count() > 0:
			var bt: ScriptBacktrace = script_backtraces[0]
			where = "%s:%d, %s" % [bt.get_frame_file(0), bt.get_frame_line(0), bt.get_frame_function(0)]
		_mutex.lock()
		_entries.append({"script": error_type == ERROR_TYPE_SCRIPT, "text": "%s (%s)" % [text, where]})
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[Dictionary]:
		_mutex.lock()
		var out: Array[Dictionary] = _entries
		_entries = []
		_mutex.unlock()
		return out


var _capture := ErrorCapture.new()
var _filter: String = ""
var _unit_dir: String = UNIT_DIR
var _verbose: bool = false
var _timeout_sec: float = DEFAULT_TIMEOUT_SEC
var _watch_id: int = 0
var _passed: int = 0
var _failed: int = 0
var _orphan_total: int = 0
var _orphan_tests: int = 0


func _initialize() -> void:
	OS.add_logger(_capture)
	_verbose = OS.get_environment("TESTS_VERBOSE") == "1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--timeout="):
			_timeout_sec = arg.trim_prefix("--timeout=").to_float()
		elif arg == "--verbose-tests":
			_verbose = true
		elif arg.begins_with("--dir="):
			_unit_dir = arg.trim_prefix("--dir=")
	_run.call_deferred()


func _run() -> void:
	await process_frame  # let the autoloads' _ready finish
	var started: int = Time.get_ticks_msec()
	var startup: Array[Dictionary] = _capture.take()
	if not startup.is_empty():
		_report("(açılış: autoload/ayar)", 0.0, _texts(startup, false))
	for path: String in _test_files():
		await _run_file(path)
	var total: int = _passed + _failed
	var summary: String = "%d test: %d geçti, %d başarısız (%d ms)" % [total, _passed, _failed, Time.get_ticks_msec() - started]
	print(("\n" if _verbose or _failed > 0 else "") + summary)
	if _verbose or _orphan_total > 0:
		print("Yetim düğüm farkı: toplam +%d (%d test)" % [_orphan_total, _orphan_tests])
	if total == 0:
		printerr("Koşulacak test yok (%s/test_*.gd%s)" % [_unit_dir, ", filtre: " + _filter if not _filter.is_empty() else ""])
		_finish(1)
	else:
		_finish(1 if _failed > 0 or _orphan_total > 0 else 0)


func _test_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(_unit_dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(_unit_dir.path_join(f))
	out.sort()
	return out


func _run_file(path: String) -> void:
	var file_label: String = path.get_file()
	var script: GDScript = load(path) as GDScript
	var load_errors: Array[Dictionary] = _capture.take()
	if script == null or not script.can_instantiate():
		var problems: PackedStringArray = ["betik yüklenemedi"]
		problems.append_array(_texts(load_errors, false))
		_report(file_label, 0.0, problems)
		return
	var methods: PackedStringArray = []
	var seen: PackedStringArray = []
	for m: Dictionary in script.get_script_method_list():
		var method: String = m["name"]
		if not method.begins_with("test_") or seen.has(method):
			continue
		seen.append(method)
		if (m["args"] as Array).is_empty():
			methods.append(method)
		else:
			_report("%s::%s" % [file_label, method], 0.0, ["test metodu argüman almamalı"])
	for method: String in methods:
		var label: String = "%s::%s" % [file_label, method]
		if _filter.is_empty() or label.contains(_filter):
			await _run_test(script, method, label)


func _run_test(script: GDScript, method: String, label: String) -> void:
	var orphans_before: int = _orphan_count()
	var instance: Variant = script.new()
	var case: TestCase = instance as TestCase
	if case == null:
		if instance is Node:
			(instance as Node).free()
		_report(label, 0.0, ["test dosyası TestCase'ten türemiyor (extends TestCase)"])
		return
	_capture.take()
	_watch_id += 1
	_arm_watchdog(_watch_id, label)
	var t0: int = Time.get_ticks_usec()
	await case.call(method)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	case.free_tracked()
	await process_frame  # deferred calls' errors are attributed to this test too
	_watch_id += 1  # cancel the watchdog
	var problems: PackedStringArray = case.failures().duplicate()
	problems.append_array(_texts(_capture.take(), case.errors_allowed()))
	_report(label, ms, problems)
	var leaked: int = _orphan_count() - orphans_before
	if leaked > 0:
		await process_frame  # one more frame so late queue_free calls do not cause false positives
		leaked = _orphan_count() - orphans_before
	if leaked > 0:
		_orphan_total += leaked
		_orphan_tests += 1
		print("[ORPHAN] %s +%d" % [label, leaked])


## Count of parentless nodes outside the scene tree (same set as Node.print_orphan_nodes).
func _orphan_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


func _arm_watchdog(id: int, label: String) -> void:
	var timer: SceneTreeTimer = create_timer(_timeout_sec, true, false, true)
	timer.timeout.connect(func() -> void:
		if id == _watch_id:
			print("[FAIL] %s  zaman aşımı (> %s sn); koşu durduruldu" % [label, _timeout_sec])
			_finish(1)
	)


## Turns error records into report lines; with `errors_allowed` only script errors count.
func _texts(entries: Array[Dictionary], errors_allowed: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in entries:
		if e["script"]:
			out.append("betik hatası: " + str(e["text"]))
		elif not errors_allowed:
			out.append("hata: " + str(e["text"]))
	return out


func _report(label: String, ms: float, problems: PackedStringArray) -> void:
	if problems.is_empty():
		_passed += 1
		if _verbose:
			print("[PASS] %s  %.1f ms" % [label, ms])
		return
	_failed += 1
	print("[FAIL] %s  %.1f ms" % [label, ms])
	for p: String in problems:
		print("       - " + p)


func _finish(code: int) -> void:
	OS.remove_logger(_capture)  # keep shutdown engine logs from hitting the script
	quit(code)
