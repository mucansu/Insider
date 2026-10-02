extends TestCase
## Metin altyapısı (US-003 AC4, AC5, S9): i18n/texts.csv biçimi ve çeviri dosyalarıyla uyumu;
## ui/ altındaki .tscn/.gd dosyalarında anahtar olmayan sabit metin olmadığı (tarama) ve
## çalışan ekranlarda otomatik çevrilen her metnin bir anahtar olduğu.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const CSV_PATH := "res://i18n/texts.csv"
const LOCALES: Array[String] = ["tr", "en"]
## Anahtar biçimi: BÜYÜK_HARF_SAYI, alt çizgiyle başlamaz/bitmez (sonu _ olan önek sayılır, ör. "EVENT_").
const KEY_PATTERN := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$|^[A-Z][A-Z0-9]+$"
## Sahnelerde oyuncuya görünen metin özellikleri.
const TSCN_TEXT_PROPS := "text|placeholder_text|tooltip_text|title"
## Geliştirici günlüğü satırları (oyuncu görmez) taramadan muaf.
const LOG_CALLS: Array[String] = ["push_warning(", "push_error(", "print(", "printerr(", "print_debug("]


func test_csv_well_formed() -> void:
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if not is_true(f != null, "texts.csv açılamadı"):
		return
	eq(f.get_csv_line(), PackedStringArray(["keys", "tr", "en"]), "başlık")
	var key_re: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var seen: Dictionary = {}
	var line_no: int = 1
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		line_no += 1
		if row.size() == 1 and row[0].is_empty():
			continue  # dosya sonu
		if not eq(row.size(), 3, "satır %d sütun sayısı: %s" % [line_no, row]):
			continue
		var key: String = row[0]
		is_true(key_re.search(key) != null, "satır %d anahtar biçimi: %s" % [line_no, key])
		is_false(seen.has(key), "satır %d tekrar eden anahtar: %s" % [line_no, key])
		seen[key] = true
		is_false(row[1].strip_edges().is_empty(), "%s: tr boş" % key)
		is_false(row[2].strip_edges().is_empty(), "%s: en boş" % key)
		eq(_placeholders(row[2]), _placeholders(row[1]), "%s: tr ve en yer tutucuları aynı olmalı" % key)
	is_true(seen.size() >= 30, "anahtar sayısı beklenenden az")


func test_translations_match_csv() -> void:
	var table: Dictionary = _csv()
	var previous: String = TranslationServer.get_locale()
	for i: int in LOCALES.size():
		TranslationServer.set_locale(LOCALES[i])
		for key: String in table:
			eq(TranslationServer.translate(key), table[key][i], "%s [%s] (içe aktarma güncel mi?)" % [key, LOCALES[i]])
	TranslationServer.set_locale(previous)


func test_scenes_contain_only_keys() -> void:
	var table: Dictionary = _csv()
	var prop_re: RegEx = RegEx.create_from_string("^(%s) = \"(.*)\"$" % TSCN_TEXT_PROPS)
	var checked: int = 0
	for path: String in _files_under("res://ui", ".tscn"):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var m: RegExMatch = prop_re.search(lines[i])
			if m == null:
				continue
			checked += 1
			var value: String = m.get_string(2)
			is_true(table.has(value), "%s:%d anahtar olmayan metin: %s" % [path, i + 1, value])
	is_true(checked >= 20, "taranan sahne metni az (%d); desen değişti mi?" % checked)


func test_scripts_contain_no_literal_text() -> void:
	var table: Dictionary = _csv()
	var key_re: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var prose_re: RegEx = RegEx.create_from_string("[A-Za-z]\\s+[A-Za-z]|[^\\x00-\\x7F]")
	var assign_re: RegEx = RegEx.create_from_string("\\b(%s)\\s*=\\s*[&]?\"([^\"]*)\"" % TSCN_TEXT_PROPS)
	var tr_re: RegEx = RegEx.create_from_string("\\btr\\(\\s*[&]?\"([^\"]*)\"")
	var keys_seen: int = 0
	for path: String in _files_under("res://ui", ".gd"):
		var source: String = FileAccess.get_file_as_string(path)
		var lines: PackedStringArray = source.split("\n")
		var scan: Dictionary = _scan_gdscript(source)
		for lit: Dictionary in scan["literals"]:
			var text: String = lit["text"]
			var line: int = lit["line"]
			if _is_log_line(lines[line - 1]):
				continue
			var where: String = "%s:%d" % [path, line]
			if key_re.search(text) != null and text.contains("_"):
				keys_seen += 1
				is_true(table.has(text), "%s anahtar texts.csv'de yok: %s" % [where, text])
			is_true(prose_re.search(text) == null, "%s sabit metin (tr() + anahtar kullan): \"%s\"" % [where, text])
		var code: String = scan["code"]
		for m: RegExMatch in assign_re.search_all(code):
			var value: String = m.get_string(2)
			is_true(value.is_empty() or table.has(value), "%s metin özelliğine anahtar olmayan dize: \"%s\"" % [path, value])
		for m: RegExMatch in tr_re.search_all(code):
			is_true(table.has(m.get_string(1)), "%s tr() anahtarı yok: %s" % [path, m.get_string(1)])
	is_true(keys_seen >= 15, "betiklerde anahtar bulunamadı (%d); tarama bozuk mu?" % keys_seen)


func test_scanner_detects_literal_text() -> void:
	# Taramanın kendisi: yorumdaki metin sayılmaz, dizedeki metin ve # yakalanır.
	var scan: Dictionary = _scan_gdscript("var a := \"Merhaba dünya\" # \"yorum metni\"\nlabel.text = \"Host\"\nvar b := 'x # y'\n")
	var texts: Array[String] = []
	for lit: Dictionary in scan["literals"]:
		texts.append(str(lit["text"]))
	eq(texts, ["Merhaba dünya", "Host", "x # y"] as Array[String])
	has(str(scan["code"]), "label.text = \"Host\"")
	is_false(str(scan["code"]).contains("yorum metni"), "yorum koddan çıkarılır")


func test_running_screens_show_only_keys() -> void:
	var table: Dictionary = _csv()
	var pair: Array = Fakes.make_pair(self, true)  # görüş eki: menüde görüş seçimi de denetlenir
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.net = pair[0]
	menu.game = pair[1]
	viewport.add_child(menu)
	var hud: Hud = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	hud.net = pair[0]
	hud.game = pair[1]
	viewport.add_child(hud)
	await tree().process_frame
	var checked: int = 0
	for node: Node in _descendants(viewport):
		if not node.can_auto_translate():
			continue
		var values: PackedStringArray = []
		if node is Label:
			values.append((node as Label).text)
		elif node is Button:
			values.append((node as Button).text)
		elif node is LineEdit:
			values.append((node as LineEdit).placeholder_text)
		for v: String in values:
			if v.is_empty():
				continue
			checked += 1
			is_true(table.has(v), "%s otomatik çevrilen metin anahtar değil: %s" % [node.get_path(), v])
	is_true(checked >= 20, "denetlenen metin az: %d" % checked)


# --- yardımcılar ---

## anahtar -> [tr, en]
static func _csv() -> Dictionary:
	var out: Dictionary = {}
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() == 3:
			out[row[0]] = [row[1], row[2]]
	return out


## %s / %d / {ad} yer tutucuları, sıralı.
static func _placeholders(text: String) -> Array[String]:
	var out: Array[String] = []
	var re: RegEx = RegEx.create_from_string("%[sd]|\\{[a-z_]+\\}")
	for m: RegExMatch in re.search_all(text):
		out.append(m.get_string())
	out.sort()
	return out


static func _is_log_line(line: String) -> bool:
	for call: String in LOG_CALLS:
		if line.contains(call):
			return true
	return false


## GDScript kaynağındaki dize sabitleri ({text, line}) ve yorumları boşlukla değiştirilmiş kod.
static func _scan_gdscript(source: String) -> Dictionary:
	var literals: Array[Dictionary] = []
	var code: String = ""
	var i: int = 0
	var line: int = 1
	var n: int = source.length()
	while i < n:
		var c: String = source[i]
		if c == "#":
			while i < n and source[i] != "\n":
				code += " "
				i += 1
			continue
		if c == "\"" or c == "'":
			var triple: bool = source.substr(i, 3) == c.repeat(3)
			var close: String = c.repeat(3) if triple else c
			var start_line: int = line
			var j: int = i + close.length()
			var text: String = ""
			while j < n:
				if source[j] == "\\":
					text += source.substr(j, 2)
					j += 2
					continue
				if source.substr(j, close.length()) == close:
					j += close.length()
					break
				if source[j] == "\n":
					line += 1
				text += source[j]
				j += 1
			literals.append({"text": text, "line": start_line})
			code += source.substr(i, j - i)
			i = j
			continue
		if c == "\n":
			line += 1
		code += c
		i += 1
	return {"literals": literals, "code": code}


static func _descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in root.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


static func _files_under(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(dir.path_join(d), ext))
	return out
