extends TestCase
## mimari.md §6 layer matrix (KR-018; IS-010, IS-038). References from every `.gd` script in a source dir to other
## project dirs are scanned and compared with the RULES table. A reference is:
## - a project class name (`class_name`, ProjectSettings global class list) or autoload name (Game, Net, Args,
## NoiseBus), in code (outside strings) or as a whole StringName string (&"ThemeTokens"); a name after `.` (inner
## enum/class access) or one the file declares itself (e.g. `enum Level` in Suspicion) does not count;
## - a project path inside a string (`res://<dir>/...` or `<dir>/...` at string start; dynamic references count too);
## - `uid://` inside a string: resolved to a path via ResourceUID; an unresolvable uid (hidden/stale reference) is always a violation (IS-005).
## A dir may always reference itself; a target passes only via an allowed dir/file in RULES or a justified EXCEPTIONS
## row. Comments are not scanned. Limit: a `#` inside a multi-line (""") string counts as a comment; `.tscn` scene
## dependencies (e.g. prop scenes placed in a level) are out of scope.

## Source dir -> allowed targets (dir or single file, res:// relative). Matches §6 exactly.
const RULES := {
	"core": [],  # no project dir (portability to 3D)
	"autoload": ["core", "data", "levels/level.gd"],  # Level only via the S4 API
	"entities": ["core", "autoload", "data"],
	"levels": ["core", "data"],
	"ui": ["autoload", "data"],  # autoload contracts; data is a read-only Resource (IS-024 sound catalog)
}
## Deliberate exceptions. from: source file or dir prefix (ends with "/"); to: target files.
## line: this line only (exact except leading/trailing whitespace); token: the reference must start with this text.
## flag: an exception not in the §6 text, found in today's tree and passed with justification (reported under "Karar gereken").
const EXCEPTIONS: Array[Dictionary] = [
	{"from": "autoload/game.gd", "to": ["ui/hud.tscn"], "line": "const HUD_SCENE := \"res://ui/hud.tscn\"",
		"why": "§6/S3: HUD yol dizesinden load() ile eklenir; derleme bağımlılığı yok"},
	{"from": "autoload/noise.gd", "to": ["entities/fx/noise_ring.tscn"],
		"line": "const RING_SCENE := \"res://entities/fx/noise_ring.tscn\"",
		"why": "§6/S8 (US-009): gürültü halkası yol dizesinden load() ile eklenir; derleme bağımlılığı yok"},
	{"from": "autoload/game.gd", "to": ["levels/store_a.tscn"],
		"line": "const DEFAULT_LEVEL := \"res://levels/store_a.tscn\"",
		"why": "S3 sözleşme sabiti; seviye sahnesi start_level() ile yol dizesinden yüklenir, derleme bağımlılığı yok",
		"flag": "§6 'autoload → levels/level.gd' satırında seviye sahnesi yolu yazmıyor"},
	{"from": "autoload/game.gd", "to": ["entities/player/player.tscn"],
		"line": "const DEFAULT_PLAYER_SCENE := \"res://entities/player/player.tscn\"",
		"why": "S3 player_scene varsayılanı; yol dizesinden load(), derleme bağımlılığı yok",
		"flag": "§6 autoload → entities/ istisnası yazmıyor (S3'te varsayılan olarak geçiyor)"},
	{"from": "entities/", "to": ["ui/theme/tokens.gd", "ui/theme/tone.gd"],
		"why": "§6: görsel düğümler ThemeTokens okur (ThemeTokens.tone() -> Tone)"},
	{"from": "levels/", "to": ["ui/theme/tokens.gd", "ui/theme/tone.gd"],
		"why": "§6/S9: seviye çizimi renkleri ThemeTokens.tone()'dan okur"},
	{"from": "entities/player/player_input.gd", "to": ["ui/ui_input.gd"],
		"token": "UiInput.is_gameplay_input_blocked(",
		"why": "§6/S5: PlayerInput yalnız UiInput.is_gameplay_input_blocked() statik sorgusunu çağırır"},
]
const GAME := "res://autoload/game.gd"

static var _index: Dictionary = {}


func test_rule_table_is_well_formed() -> void:
	for dir: String in RULES:
		is_true(_scripts_under("res://" + dir).size() >= 1, "kural dizininde betik yok: " + dir)
		for target: String in RULES[dir]:
			is_true(_exists(target), "%s kuralında olmayan hedef: %s" % [dir, target])
	for e: Dictionary in EXCEPTIONS:
		var from: String = e["from"]
		is_true(_exists(from.trim_suffix("/")), "istisna kaynağı yok: " + from)
		is_true(RULES.has(from.get_slice("/", 0)), "istisna kural dışı dizinde: " + from)
		for target: String in e["to"]:
			is_true(_exists(target), "istisna hedefi yok: " + target)
		is_true(str(e.get("why", "")).length() >= 20, "istisna gerekçesiz: %s" % e)


func test_layer_matrix_holds() -> void:
	var used: Dictionary = {}
	var scanned: int = 0
	for dir: String in RULES:
		for path: String in _scripts_under("res://" + dir):
			scanned += 1
			var result: Dictionary = scan(path, FileAccess.get_file_as_string(path))
			var problems: PackedStringArray = result["violations"]
			is_true(problems.is_empty(), "%s katman kuralını çiğniyor:\n  %s" % [path, "\n  ".join(problems)])
			for i: int in result["used"]:
				used[i] = true
	is_true(scanned >= 20, "taranan betik sayısı az: %d" % scanned)
	for i: int in EXCEPTIONS.size():
		is_true(used.has(i), "kullanılmayan (bayat) istisna: %s" % EXCEPTIONS[i])


## Each rule: adding a single violation to a copy of a real file is caught; an allowed reference stays clean.
func test_each_rule_catches_injected_violation() -> void:
	var cases := {
		"res://core/noise_rules.gd": [
			["var _m: Player = null", 1], ["var _g := Game.team_cash()", 1], ["var _p: NoiseProfile = null", 1],
			["var _l: Level = null", 1], ["var _t := ThemeTokens.BG", 1], ["const _S := \"res://data/noise_profile.tres\"", 1],
			["var _s: SuspicionMeter = null", 0], ["var _x := 1  # Player, res://ui/hud.tscn", 0],
		],
		"res://autoload/net.gd": [
			["var _p: Player = null", 1], ["var _d := preload(\"res://entities/props/door.tscn\")", 1],
			["var _l: LevelLayout = null", 1], ["var _s := load(\"res://levels/store_a.tscn\")", 1],
			["var _h: Hud = null", 1], ["const RING_SCENE := \"res://entities/fx/noise_ring.tscn\"", 1],
			["var _l: Level = null", 0], ["var _r: InteractionRules = null", 0], ["var _n: NoiseProfile = null", 0],
			["var _t := load(\"res://data/noise_profile.tres\")", 0], ["var _c := Game.team_cash()", 0],
			["var _v := \"res://levels/level.gd\"", 0],
		],
		"res://entities/player/player.gd": [
			["var _h: Hud = null", 1], ["var _l: Level = null", 1], ["\tif UiInput.is_gameplay_input_blocked(): return", 1],
			["\tMainMenu.open(get_tree())", 1], ["var _x := load(\"res://levels/store_a.tscn\")", 1],
			["var _s := 'ui/hud.tscn'", 1],
			["var _c := ThemeTokens.BG", 0], ["var _r: InteractionRules = null", 0], ["var _g := Game.team_cash()", 0],
			["\tNoiseBus.emit_noise(Vector2.ZERO, 1.0, &\"run\")", 0], ["var _d: Door = null", 0],
			["var _t := load(\"res://data/player_tuning.tres\")", 0], ["var _k := Kind.Level", 0],
		],
		"res://entities/player/player_input.gd": [
			["\tif UiInput.is_gameplay_input_blocked(): return", 0], ["\tUiInput.block_gameplay_input()", 1],
			["var _u: UiInput = null", 1],
		],
		"res://ui/hud.gd": [
			["var _p: Player = null", 1], ["var _r := InteractionRules.RANGE_TOLERANCE", 1], ["var _l: Level = null", 1],
			["var _s := \"res://levels/store_a.tscn\"", 1], ["var _d := preload(\"res://entities/props/door.tscn\")", 1],
			["var _c := ClassDB.class_exists(&\"Interactable\")", 1],
			["@export_subgroup(\"Level\")", 0], ["	get_node(^\"Level\")", 0],
			["var _a := Game.alert_level()", 0], ["var _t: Tone = null", 0], ["var _m: MainMenu = null", 0],
			["var _n := load(\"res://data/noise_profile.tres\")", 0], ["var _p: NoiseProfile = null", 0],
		],
		"res://levels/level_layout.gd": [
			["\tGame.current_level()", 1], ["var _d: Door = null", 1], ["var _s := \"res://entities/props/door.tscn\"", 1],
			["var _h: Hud = null", 1], ["\tif UiInput.is_gameplay_input_blocked(): return", 1],
			["var _r: InteractionRules = null", 0], ["var _n: NoiseProfile = null", 0], ["var _t := ThemeTokens.BG", 0],
			["var _l: Level = null", 0],
		],
	}
	for path: String in cases:
		var source: String = FileAccess.get_file_as_string(path)
		if not is_true(not source.is_empty(), "kopya kaynağı okunamadı: " + path):
			continue
		eq(violations(path, source).size(), 0, "temiz kaynak: " + path)
		for c: Array in cases[path]:
			var line: String = c[0]
			eq(violations(path, source + "\n" + line + "\n").size(), int(c[1]), "%s + `%s`" % [path, line.strip_edges()])


## IS-010 cases: core/ and autoload/ do not reference ui/ (on a copy of game.gd).
func test_scanner_detects_ui_mutations() -> void:
	var caught: Array[String] = [
		"var c: Color = ThemeTokens.BG",
		"const HUD := preload(\"res://ui/hud.tscn\")",
		"var t: Resource = load(\"res://ui/theme/noir.tres\")",
		"\tif UiInput.is_gameplay_input_blocked(): return",
		"func f(t: Tone) -> void:",
		"\tMainMenu.open(get_tree())",
		"var b := ThemeBuilder",
		"var h: Hud = null",
		"var p := \"a#b\" + str(ThemeTokens.FG)  # dizedeki # yorum başlatmaz",
		"var s: String = 'ui/hud.tscn'",
		"var n := ClassDB.class_exists(&\"ThemeTokens\")",
		"const HUD_SCENE := \"res://ui/hud.tscn\"  # istisna yalnız birebir satır",
	]
	for line: String in caught:
		eq(violations(GAME, line).size(), 1, "yakalanmalı: " + line)
	eq(violations("res://autoload/net.gd", "const HUD_SCENE := \"res://ui/hud.tscn\"").size(), 1,
		"istisna yalnız game.gd'de")
	eq(violations("res://core/noise_rules.gd", "var c: Color = ThemeTokens.BG").size(), 1, "core → ui")
	var clean: Array[String] = [
		"const HUD_SCENE := \"res://ui/hud.tscn\"",
		"\tconst HUD_SCENE := \"res://ui/hud.tscn\"",
		"## Menüye dönüşü arayüz (ThemeTokens, res://ui/main_menu.tscn) yapar",
		"var x := \"#\" + str(1)  # ui/ yorumda",
		"var toned: int = 1  # Tone",
		"var gui_path := \"res://gui/x.tscn\"",
		"layer.name = \"HUD\"",
	]
	for line: String in clean:
		eq(violations(GAME, line).size(), 0, "temiz sayılmalı: " + line)
	# Mutation on a real file: a single ui reference added to game.gd is caught.
	var source: String = FileAccess.get_file_as_string(GAME)
	eq(violations(GAME, source).size(), 0)
	eq(violations(GAME, source + "\nvar _mut: Color = ThemeTokens.PLAYER_COLORS[0]\n").size(), 1)
	eq(violations(GAME, source.replace("load(HUD_SCENE)", "load(\"res://ui/hud.tscn\")")).size(), 1)


func test_scanner_resolves_uid_references() -> void:
	var ui_uid: String = _uid_text("res://ui/hud.tscn")
	var level_uid: String = _uid_text("res://levels/store_a.tscn")
	var data_uid: String = _uid_text("res://data/player_tuning.tres")
	if not is_true(ui_uid.begins_with("uid://") and level_uid.begins_with("uid://") and data_uid.begins_with("uid://"),
			"uid bulunamadı (içe aktarma?)"):
		return
	var caught: Array[String] = [
		"var hud: PackedScene = load(\"%s\")" % ui_uid,
		"const HUD := preload(\"%s\")" % ui_uid,
		"var u := \"%s\"  # yorum" % ui_uid,
		"var level: PackedScene = load(\"%s\")" % level_uid,  # autoload -> levels scene (only level.gd allowed)
		"var stale := load(\"uid://zzzzzzzzzzzzz\")",  # unresolvable uid
	]
	for line: String in caught:
		eq(violations(GAME, line).size(), 1, "yakalanmalı: " + line)
	var clean: Array[String] = [
		"var profile: Resource = load(\"%s\")" % data_uid,
		"var x := 1  # %s yorumda" % ui_uid,
	]
	for line: String in clean:
		eq(violations(GAME, line).size(), 0, "temiz sayılmalı: " + line)
	eq(violations("res://ui/hud.gd", "var l := load(\"%s\")" % level_uid).size(), 1, "ui → levels uid ile de yakalanır")
	# Mutation on a real file: writing the uid in place of the HUD path is caught too.
	var source: String = FileAccess.get_file_as_string(GAME)
	eq(violations(GAME, source.replace("load(HUD_SCENE)", "load(\"%s\")" % ui_uid)).size(), 1)


## Rule-breaking references in `source` (format "line: code -> targets", one record per line).
static func violations(path: String, source: String) -> PackedStringArray:
	return scan(path, source)["violations"]


## {"violations": PackedStringArray, "used": Array[int] (indices of matched EXCEPTIONS)}.
static func scan(path: String, source: String) -> Dictionary:
	var index: Dictionary = _class_index()
	var rel: String = path.trim_prefix("res://")
	var lines: PackedStringArray = source.split("\n")
	var local: Dictionary = _local_names(lines)
	var names: PackedStringArray = []
	for cls: String in index:
		if not local.has(cls):
			names.append(cls)
	var class_re := RegEx.create_from_string("(?<![.\\w])(" + "|".join(names) + ")\\b")
	var path_re := RegEx.create_from_string("^(?:res://)?((?:" + "|".join(_top_dirs()) + ")/[^\\s]*)")
	var uid_re := RegEx.create_from_string("uid://[0-9a-z]+")
	var out: PackedStringArray = []
	var used: Array[int] = []
	for i: int in lines.size():
		var parts: Array = split_strings(strip_comment(lines[i]))
		var code: String = parts[0]
		var refs: Array[Array] = []  # [target (res:// relative), position in code or -1]
		for m: RegExMatch in class_re.search_all(code):
			refs.append([index[m.get_string(1)], m.get_start(1)])
		for text: String in parts[2]:
			if index.has(text):
				refs.append([index[text], -1])  # &"Class" (plain string: node name, @export_subgroup; does not count)
		for text: String in parts[1]:
			var pm: RegExMatch = path_re.search(text)
			if pm != null:
				refs.append([pm.get_string(1), -1])
			for um: RegExMatch in uid_re.search_all(text):
				var id: int = ResourceUID.text_to_id(um.get_string())
				var resolved: bool = id != ResourceUID.INVALID_ID and ResourceUID.has_id(id)
				refs.append([ResourceUID.get_id_path(id).trim_prefix("res://") if resolved else "?" + um.get_string(), -1])
		var bad: PackedStringArray = []
		for ref: Array in refs:
			var target: String = ref[0]
			if target == rel or _allowed(rel, target):
				continue
			var exception: int = _exception_for(rel, target, lines[i], code, int(ref[1]))
			if exception >= 0:
				used.append(exception)
			elif not bad.has(target):
				bad.append(target)
		if not bad.is_empty():
			out.append("%d: %s → %s" % [i + 1, lines[i].strip_edges(), ", ".join(bad)])
	return {"violations": out, "used": used}


## Whether source `rel`'s reference to `target` is allowed by RULES (own dir is always allowed).
static func _allowed(rel: String, target: String) -> bool:
	if target.begins_with("?"):
		return false  # unresolvable uid
	var from_dir: String = rel.get_slice("/", 0)
	if target.get_slice("/", 0) == from_dir:
		return true
	for entry: String in RULES.get(from_dir, []):
		if target == entry or target.begins_with(entry + "/"):
			return true
	return false


## Index of the matching exception; -1 if none.
static func _exception_for(rel: String, target: String, line: String, code: String, at: int) -> int:
	for i: int in EXCEPTIONS.size():
		var e: Dictionary = EXCEPTIONS[i]
		var from: String = e["from"]
		if not (rel == from or (from.ends_with("/") and rel.begins_with(from))):
			continue
		if not (e["to"] as Array).has(target):
			continue
		if e.has("line") and line.strip_edges() != str(e["line"]):
			continue
		if e.has("token") and (at < 0 or not code.substr(at).begins_with(str(e["token"]))):
			continue
		return i
	return -1


## Project class names and autoload names -> script path (res:// relative). Tests (TestCase) excluded.
static func _class_index() -> Dictionary:
	if not _index.is_empty():
		return _index
	for info: Dictionary in ProjectSettings.get_global_class_list():
		var p: String = str(info["path"])
		if not p.begins_with("res://tests/"):
			_index[str(info["class"])] = p.trim_prefix("res://")
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("autoload/"):
			_index[key.trim_prefix("autoload/")] = str(ProjectSettings.get_setting(key)).trim_prefix("*").trim_prefix("res://")
	return _index


## Names the file declares itself (enum/class/const/var/func/signal); shadows a project class of the same name.
static func _local_names(lines: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.create_from_string("^\\s*(?:static\\s+)?(?:enum|class|const|var|func|signal)\\s+([A-Za-z_]\\w*)")
	for line: String in lines:
		var m: RegExMatch = re.search(line)
		if m != null:
			out[m.get_string(1)] = true
	return out


## Dir names at the project root (hidden dirs excluded).
static func _top_dirs() -> PackedStringArray:
	var out: PackedStringArray = []
	for d: String in DirAccess.get_directories_at("res://"):
		if not d.begins_with("."):
			out.append(d)
	return out


static func _exists(rel: String) -> bool:
	return FileAccess.file_exists("res://" + rel) or DirAccess.dir_exists_absolute("res://" + rel)


static func _uid_text(path: String) -> String:
	var id: int = ResourceLoader.get_resource_uid(path)
	return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else ""


## Splits a line into [code outside strings (string bodies emptied), all string contents, StringName (&"") contents]
## (single-line "..." / '...' strings, with escapes; &"" and ^"" prefixes stay in code).
static func split_strings(line: String) -> Array:
	var code: String = ""
	var strings: PackedStringArray = []
	var string_names: PackedStringArray = []
	var is_name: bool = false
	var quote: String = ""
	var body: String = ""
	var i: int = 0
	while i < line.length():
		var ch: String = line[i]
		if not quote.is_empty():
			if ch == "\\" and i + 1 < line.length():
				body += line[i + 1]
				i += 1
			elif ch == quote:
				strings.append(body)
				if is_name:
					string_names.append(body)
				body = ""
				quote = ""
				code += ch
			else:
				body += ch
		elif ch == "\"" or ch == "'":
			quote = ch
			is_name = code.ends_with("&")
			code += ch
		else:
			code += ch
		i += 1
	if not quote.is_empty():
		strings.append(body)
	return [code, strings, string_names]


## Drops everything after the first `#` outside strings (single-line "..." / '...' strings, with escapes).
static func strip_comment(line: String) -> String:
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var ch: String = line[i]
		if not quote.is_empty():
			if ch == "\\":
				i += 1
			elif ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			return line.left(i)
		i += 1
	return line


static func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(d)))
	return out
