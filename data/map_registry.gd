class_name MapRegistry
extends Resource
## Playable map registry (US-050, KR-044): the single list of maps a host may pick (main menu host card, heist end "Another shop").
## Test arenas and fixtures are not listed. Game validates every map switch against this list (`Game.request_map_switch`);
## the `--level=` argument stays free for automation/tests. Not an autoload: `load_default()` (resource cache).
## Adding a map = one MapEntry row in data/map_registry.tres + a MAP_<FILE> row in i18n/texts.csv; no code change.

const DEFAULT_PATH := "res://data/map_registry.tres"

@export var maps: Array[MapEntry] = []


## Default registry; an empty one (warning) if the file cannot be loaded.
static func load_default() -> MapRegistry:
	var registry: MapRegistry = load(DEFAULT_PATH) as MapRegistry
	if registry == null:
		push_warning("MapRegistry: %s yüklenemedi; harita listesi boş" % DEFAULT_PATH)
		registry = MapRegistry.new()
	return registry


## Level paths in list order.
func paths() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: MapEntry in maps:
		if entry != null and not entry.level_path.is_empty():
			out.append(entry.level_path)
	return out


func has_path(level_path: String) -> bool:
	return not level_path.is_empty() and paths().has(level_path)


## Name key of a listed map; "" if not listed.
func name_key_of(level_path: String) -> String:
	for entry: MapEntry in maps:
		if entry != null and entry.level_path == level_path:
			return entry.name_key
	return ""


## [{"path": String, "name_key": String}] in list order (copies; Game.map_list()).
func to_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: MapEntry in maps:
		if entry != null and not entry.level_path.is_empty():
			out.append({"path": entry.level_path, "name_key": entry.name_key})
	return out
