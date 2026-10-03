extends TestCase
## External asset registry (IS-024; docs/notes/assetler.md): every external file under `assets/` (except import sidecars)
## has a table row in the registry; every `assets/...` path in the registry exists (no stale rows); every license copy is
## mentioned; a sound marked placeholder in the catalog has "yer tutucu" in its row.

const REGISTRY := "res://docs/notes/assetler.md"
const ASSETS_DIR := "res://assets"
const LICENSES_DIR := "res://assets/licenses"
const IGNORED_SUFFIXES: Array[String] = [".import", ".uid"]


func _registry() -> String:
	return FileAccess.get_file_as_string(REGISTRY)


## Table rows in the registry (starting with |).
func _rows() -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in _registry().split("\n"):
		if line.begins_with("|"):
			out.append(line)
	return out


static func _files_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		var skip: bool = false
		for suffix: String in IGNORED_SUFFIXES:
			skip = skip or f.ends_with(suffix)
		if not skip:
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(dir.path_join(d)))
	return out


func test_registry_exists() -> void:
	is_true(FileAccess.file_exists(REGISTRY), "docs/notes/assetler.md yok")


func test_every_asset_file_has_a_row() -> void:
	var rows: String = "\n".join(_rows())
	var files: PackedStringArray = _files_under(ASSETS_DIR)
	var checked: int = 0
	for path: String in files:
		if path.begins_with(LICENSES_DIR):
			continue
		var rel: String = path.trim_prefix("res://")
		has(rows, rel, "assetler.md'de satırı yok: %s" % rel)
		checked += 1
	is_true(checked >= 1, "assets/ altında taranacak dosya bulunamadı")


func test_every_license_copy_is_referenced() -> void:
	var text: String = _registry()
	for path: String in _files_under(LICENSES_DIR):
		has(text, path.get_file(), "lisans kopyası kayıtta anılmıyor: %s" % path)


func test_registry_paths_exist() -> void:
	var re := RegEx.create_from_string("assets/[A-Za-z0-9_./-]+\\.[a-z0-9]+")
	var found: int = 0
	for m: RegExMatch in re.search_all(_registry()):
		found += 1
		var path: String = "res://" + m.get_string()
		is_true(FileAccess.file_exists(path), "kayıttaki dosya yok (eski satır?): %s" % m.get_string())
	is_true(found >= 1, "kayıtta assets/ yolu yok")


func test_placeholder_rows_say_placeholder() -> void:
	var catalog: SfxCatalog = load(SfxCatalog.DEFAULT_PATH) as SfxCatalog
	if not is_true(catalog != null):
		return
	var rows: PackedStringArray = _rows()
	for entry: SfxEntry in catalog.entries:
		if entry == null or entry.stream == null:
			continue
		var rel: String = entry.stream.resource_path.trim_prefix("res://")
		var row: String = ""
		for r: String in rows:
			if r.contains(rel):
				row = r
				break
		if not is_true(not row.is_empty(), "katalog dosyasının satırı yok: %s" % rel):
			continue
		if entry.placeholder:
			has(row, "yer tutucu", "%s katalogda yer tutucu; satırda durum yazmalı" % rel)
