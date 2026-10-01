extends TestCase
## IS-010 / mimari.md §6 bağımlılık yönü (KR-018): `core/` ve `autoload/` betikleri `ui/`'ye başvurmaz:
## ne `ui/` yolu (preload/load dizesi) ne de ui/ sınıf adı (ThemeTokens, UiInput, MainMenu, ThemeBuilder, Tone
## ve ui/ altındaki diğer class_name'ler). Tek bilinçli istisna Game'in HUD'u yol dizesinden `load()` ile eklemesi
## (`HUD_SCENE` sabiti; derleme bağımlılığı yok, S3). Yorumlar taranmaz; dizeler taranır (dinamik başvuru da
## bağımlılıktır). Sınır: çok satırlı (""") dize içindeki `#` yorum sayılır.

const SCANNED_DIRS: Array[String] = ["res://core", "res://autoload"]
const UI_DIR := "res://ui/"
## Kalem tanımındaki ui/ sınıfları; ui/ altındaki diğer class_name'ler çalışma anında eklenir.
const UI_CLASSES: Array[String] = ["ThemeTokens", "UiInput", "MainMenu", "ThemeBuilder", "Tone"]
## Dosya -> izinli satırlar (baştaki/sondaki boşluk hariç birebir).
const ALLOWED := {
	"res://autoload/game.gd": ["const HUD_SCENE := \"res://ui/hud.tscn\""],
}
const GAME := "res://autoload/game.gd"


func test_core_and_autoload_do_not_reference_ui() -> void:
	var names: PackedStringArray = ui_class_names()
	for cls: String in UI_CLASSES:
		has(names, cls, "ui/ sınıfı bulunamadı (liste güncel mi?): " + cls)
	var files: PackedStringArray = []
	for dir: String in SCANNED_DIRS:
		files.append_array(_scripts_under(dir))
	is_true(files.size() >= 4, "autoload/ betikleri taranmalı, bulunan: %s" % files)
	has(files, GAME)
	for path: String in files:
		var problems: PackedStringArray = violations(path, FileAccess.get_file_as_string(path), names)
		is_true(problems.is_empty(), "%s ui/'ye başvuruyor:\n  %s" % [path, "\n  ".join(problems)])


func test_scanner_detects_mutations() -> void:
	var names: PackedStringArray = ui_class_names()
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
		eq(violations(GAME, line, names).size(), 1, "yakalanmalı: " + line)
	eq(violations("res://autoload/net.gd", "const HUD_SCENE := \"res://ui/hud.tscn\"", names).size(), 1,
		"istisna yalnız game.gd'de")
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
		eq(violations(GAME, line, names).size(), 0, "temiz sayılmalı: " + line)
	# Gerçek dosyaya mutasyon: game.gd'ye eklenen tek bir ui başvurusu yakalanır.
	var source: String = FileAccess.get_file_as_string(GAME)
	eq(violations(GAME, source, names).size(), 0)
	eq(violations(GAME, source + "\nvar _mut: Color = ThemeTokens.PLAYER_COLORS[0]\n", names).size(), 1)
	eq(violations(GAME, source.replace("load(HUD_SCENE)", "load(\"res://ui/hud.tscn\")"), names).size(), 1)


## ui/ altındaki betiklerin class_name'leri.
static func ui_class_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if str(info["path"]).begins_with(UI_DIR):
			out.append(str(info["class"]))
	for cls: String in UI_CLASSES:
		if not out.has(cls):
			out.append(cls)
	return out


## `source` içindeki ui/ başvuruları ("satır: kod" biçiminde); izinli satırlar ve yorumlar hariç.
static func violations(path: String, source: String, class_names: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	var allowed: Array = ALLOWED.get(path, [])
	var ui_path := RegEx.create_from_string("\\bui/")
	var classes := RegEx.create_from_string("\\b(" + "|".join(class_names) + ")\\b")
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		if allowed.has(lines[i].strip_edges()):
			continue
		var code: String = strip_comment(lines[i])
		if ui_path.search(code) != null or classes.search(code) != null:
			out.append("%d: %s" % [i + 1, lines[i].strip_edges()])
	return out


## Satırdan dize dışındaki ilk `#`'tan sonrasını atar (tek satırlık "..." / '...' dizeleri, kaçışlarla).
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
