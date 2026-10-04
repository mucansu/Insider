extends SceneTree
## GDScript warning count (IS-047; measurement only, modifies no file). Run via tools/warn_count.py, not directly:
## godot --headless -d --path . -s res://tools/warn_count.gd
## Why: Godot 4.7 `--import` and `--check-only` do not print GDScript warnings; analyser warnings reach the Logger (with the code
## name, e.g. UNSAFE_METHOD_ACCESS) only while loading a script with the debugger active (`-d`).
## Flow: (1) all .gd files are loaded once with the project settings (so dependencies get cached); (2) all warning kinds are set to
## 1 (warn) in memory (ProjectSettings is not saved; settings_changed is handled one frame later, so wait two frames); (3) each file
## is re-analysed with CACHE_MODE_IGNORE and warnings belonging to that file are collected. Result is a single line: `@@WC_JSON {...}`
## (levels: levels in project.godot, files, warnings, errors, stray). Exit code 0; a load error is reported under `errors` in the JSON.
## `-- --gate-only` (run without the debugger, NO `-d`): only step (1); warnings at level 2 and other analysis errors are printed as
## the engine's own `SCRIPT ERROR: Parse Error: ...` lines (warn_count.py reads them). This run goes first: under `-d` an
## analysis error stops the local debugger (Debugger Break) and the process hangs.

const PREFIX: String = "debug/gdscript/warnings/"
const SELF_PATH: String = "res://tools/warn_count.gd"
const SKIP_DIRS: PackedStringArray = ["addons", "build", "docs"]
const JSON_MARKER: String = "@@WC_JSON "


## Collects warnings and errors the engine reports while loading.
class Capture extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _entries: Array[Dictionary] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		_entries.append({
			"warning": error_type == ERROR_TYPE_WARNING,
			"function": function,
			"file": file,
			"line": line,
			"code": code,
			"message": rationale if not rationale.is_empty() else code,
		})
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[Dictionary]:
		_mutex.lock()
		var out: Array[Dictionary] = _entries
		_entries = []
		_mutex.unlock()
		return out


var _capture: Capture = Capture.new()


func _initialize() -> void:
	OS.add_logger(_capture)
	_run.call_deferred()


func _run() -> void:
	await process_frame  # let the autoloads' _ready finish
	var files: PackedStringArray = _gd_files("res://")
	files.sort()
	for path: String in files:
		var _warm: Resource = ResourceLoader.load(path)
	var _startup: Array[Dictionary] = _capture.take()
	if OS.get_cmdline_user_args().has("--gate-only"):
		OS.remove_logger(_capture)
		print(JSON_MARKER + JSON.stringify({"mode": "gate", "files": files}))
		quit(0)
		return

	var levels: Dictionary[String, int] = {}
	for p: Dictionary in ProjectSettings.get_property_list():
		var key: String = p["name"]
		if key.begins_with(PREFIX) and int(p["type"]) == TYPE_INT:
			var warning_name: String = key.trim_prefix(PREFIX)
			levels[warning_name] = int(ProjectSettings.get_setting(key))
	for warning_name: String in levels:
		ProjectSettings.set_setting(PREFIX + warning_name, 1)
	await process_frame
	await process_frame

	var warnings: Array[Dictionary] = []
	var errors: Array[Dictionary] = []
	var stray: int = 0
	for path: String in files:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			errors.append({"file": path, "line": 0, "message": "yüklenemedi"})
		for e: Dictionary in _capture.take():
			if not bool(e["warning"]):
				errors.append({"file": e["file"], "line": e["line"], "message": e["message"]})
			elif e["file"] == path:
				warnings.append({
					"type": str(e["code"]).to_lower(),
					"file": path,
					"line": e["line"],
					"message": e["message"],
				})
			else:
				stray += 1

	for warning_name: String in levels:
		ProjectSettings.set_setting(PREFIX + warning_name, levels[warning_name])
	OS.remove_logger(_capture)
	var payload: Dictionary = {
		"godot": Engine.get_version_info()["string"],
		"levels": levels,
		"files": files,
		"warnings": warnings,
		"errors": errors,
		"stray": stray,
	}
	print(JSON_MARKER + JSON.stringify(payload))
	quit(0)


## .gd files under res://; hidden dirs (.godot, .tools ...), SKIP_DIRS and this script excluded.
func _gd_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		var path: String = dir.path_join(f)
		if f.ends_with(".gd") and path != SELF_PATH:
			out.append(path)
	for d: String in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or SKIP_DIRS.has(d):
			continue
		out.append_array(_gd_files(dir.path_join(d)))
	return out
