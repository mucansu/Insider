extends SceneTree
## GDScript uyarı sayımı (IS-047; yalnız ölçüm, hiçbir dosyayı değiştirmez). Doğrudan değil, tools/warn_count.py
## üzerinden koşar:
##   godot --headless -d --path . -s res://tools/warn_count.gd
## Neden böyle: Godot 4.7 `--import` ve `--check-only` GDScript uyarılarını basmaz; çözümleyici uyarıları yalnız
## hata ayıklayıcı etkinken (`-d`) betik yüklenirken Logger'a (kod adıyla, ör. UNSAFE_METHOD_ACCESS) iletilir.
## Akış: (1) bütün .gd dosyaları proje ayarlarıyla bir kez yüklenir (bağımlılıklar önbelleğe girsin);
## (2) bellekte bütün uyarı türleri 1'e (uyar) çekilir (ProjectSettings kaydedilmez; settings_changed bir kare
## sonra işlendiğinden iki kare beklenir); (3) her dosya CACHE_MODE_IGNORE ile yeniden çözümlenir ve o dosyaya ait
## uyarılar toplanır. Sonuç tek satır: `@@WC_JSON {...}` (levels: project.godot'taki düzeyler, files, warnings,
## errors, stray). Çıkış kodu 0; yükleme hatası JSON'da `errors` altında raporlanır.
## `-- --gate-only` (hata ayıklayıcısız koşu, `-d` YOK): yalnız (1). adım; düzeyi 2 olan uyarılar ve diğer çözümleme
## hataları motorun kendi `SCRIPT ERROR: Parse Error: ...` satırlarıyla basılır (warn_count.py okur). Önce bu koşu
## yapılır: `-d` altında çözümleme hatası yerel hata ayıklayıcıyı durdurur (Debugger Break) ve süreç takılır.

const PREFIX: String = "debug/gdscript/warnings/"
const SELF_PATH: String = "res://tools/warn_count.gd"
const SKIP_DIRS: PackedStringArray = ["addons", "build", "docs"]
const JSON_MARKER: String = "@@WC_JSON "


## Yükleme sırasında motorun bildirdiği uyarı ve hataları toplar.
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
	await process_frame  # autoload'ların _ready'si tamamlansın
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


## res:// altındaki .gd dosyaları; gizli dizinler (.godot, .tools ...), SKIP_DIRS ve bu betik hariç.
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
