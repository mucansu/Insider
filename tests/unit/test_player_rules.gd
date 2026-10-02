extends TestCase
## US-004 yapı kuralları (mimari.md §6, KR-003, KR-018):
## - Kapsülleme: entities/ betikleri başka nesnenin `_` önekli üyesine erişmez (`x._y`; self/super hariç).
## - Girdi yalnız PlayerInput'tan (S5): entities/player/ altında `Input.` yalnız player_input.gd'de.
## - Görsel yalnız durum okur (KR-003/KR-017): player_visual.gd girdi, ağ ve hareket koduna dokunmaz,
##   Player'ın alanlarına yazmaz.
## Yorumlar taranmaz (test_deps.gd'deki strip_comment).

const ENTITIES_DIR := "res://entities"
const PLAYER_DIR := "res://entities/player"
const INPUT_SCRIPT := "res://entities/player/player_input.gd"
const VISUAL_SCRIPT := "res://entities/player/player_visual.gd"
const Deps := preload("res://tests/unit/test_deps.gd")
## Görselde yasak başvurular (girdi, ağ, hareket, oturum).
const VISUAL_FORBIDDEN: Array[String] = [
	"\\bInput\\.", "\\bPlayerInput\\b", "\\bmultiplayer\\b", "\\brpc", "\\bNet\\.", "\\bGame\\.",
	"move_and_slide", "\\bArgs\\.",
]


func test_entities_do_not_touch_private_members() -> void:
	var files: PackedStringArray = scripts_under(ENTITIES_DIR)
	is_true(files.size() >= 7, "entities/ betikleri bulunmalı: %s" % files)
	for path: String in files:
		var problems: PackedStringArray = private_access(FileAccess.get_file_as_string(path))
		is_true(problems.is_empty(), "%s başka nesnenin özel üyesine erişiyor:\n  %s" % [path, "\n  ".join(problems)])


func test_private_access_scanner_detects_mutations() -> void:
	var caught: Array[String] = [
		"var x := other._secret",
		"\tplayer._wall_frames += 1",
		"Game._players.clear()",
		"\tif (a as Player)._local: pass",
		"get_parent()._input.poll(0.1)",
	]
	for line: String in caught:
		eq(private_access(line).size(), 1, "yakalanmalı: " + line)
	var clean: Array[String] = [
		"self._local = true",
		"super._ready()",
		"_input.poll(delta)",
		"var t := 1.0  # other._secret yorumda",
		"var s := Time.get_ticks_usec() / 1_000_000.0",
		"var v := Vector2._ZERO_LIKE",  # büyük harf: sabit/sınıf üyesi değil (yalnız küçük harf `_x` özel sayılır)
	]
	for line: String in clean:
		eq(private_access(line).size(), 0, "temiz sayılmalı: " + line)


func test_only_player_input_reads_input() -> void:
	var re := RegEx.create_from_string("\\bInput\\.")
	for path: String in scripts_under(PLAYER_DIR):
		if path == INPUT_SCRIPT:
			continue
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			is_true(re.search(Deps.strip_comment(line)) == null, "%s doğrudan Input okuyor: %s" % [path, line.strip_edges()])


func test_visual_only_reads_state() -> void:
	var source: String = FileAccess.get_file_as_string(VISUAL_SCRIPT)
	is_true(not source.is_empty())
	var assign := RegEx.create_from_string("\\b_player\\.\\w+\\s*[-+*/]?=[^=]")
	for line: String in source.split("\n"):
		var code: String = Deps.strip_comment(line)
		is_true(assign.search(code) == null, "görsel Player'a yazıyor: " + line.strip_edges())
		for pattern: String in VISUAL_FORBIDDEN:
			is_true(RegEx.create_from_string(pattern).search(code) == null,
				"görselde yasak başvuru (%s): %s" % [pattern, line.strip_edges()])


## `source` içinde başka nesnenin `_` önekli üyesine erişen satırlar (yorumlar hariç).
static func private_access(source: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var re := RegEx.create_from_string("([\\w)\\]]+)\\._[a-z]")
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		var code: String = Deps.strip_comment(lines[i])
		for m: RegExMatch in re.search_all(code):
			var owner_text: String = m.get_string(1)
			if owner_text == "self" or owner_text == "super":
				continue
			out.append("%d: %s" % [i + 1, lines[i].strip_edges()])
			break
	return out


## `dir` altındaki .gd dosyaları (alt dizinler dahil).
static func scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(scripts_under(dir.path_join(d)))
	return out
