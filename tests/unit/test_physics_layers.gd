extends TestCase
## IS-037: fizik katmanı bitleri, maskeler ve oyun grubu adları tek kaynakta (core/physics_layers.gd, PhysicsLayers).
## (1) Eski yerel adlar aynı değeri taşır (davranış aynı; değerler burada bilinçli olarak sayıyla yazılır).
## (2) Tarama: tests/ dışındaki betiklerde (yorumlar hariç) katman sayısı ya da grup adı dizesi yalnız
## physics_layers.gd'de geçer. Kurallar: fizik bağlamında `1 <<`; `collision_layer/mask`'e sıfırdan farklı sayı;
## adı katman/maske olan sabite sayı (`*_MASK`, `*_LAYERS`, `*_LAYER_BIT`, `<KATMAN>_LAYER`); ışın sorgusuna sayı
## maske; PhysicsLayers'taki grup adlarının dize hâli. Sahne (.tscn) değerleri veri olarak kapsam dışı.
## Tarayıcının kendisi mutantlarla denetlenir (her kural bir ihlali yakalar; temiz örnek ihlal vermez).

const Deps := preload("res://tests/unit/test_deps.gd")
const SOURCE := "res://core/physics_layers.gd"
const SKIP_DIRS: Array[String] = ["res://tests", "res://addons"]
const LAYER_WORDS := "WORLD|PLAYERS|NPCS|INTERACTABLES|TRIGGERS|VISION_BLOCK"


func test_aliases_keep_values() -> void:
	eq(PhysicsLayers.WORLD, 1)
	eq(PhysicsLayers.PLAYERS, 2)
	eq(PhysicsLayers.NPCS, 4)
	eq(PhysicsLayers.INTERACTABLES, 8)
	eq(PhysicsLayers.TRIGGERS, 16)
	eq(PhysicsLayers.VISION_BLOCK, 32)
	eq(PhysicsLayers.SIGHT_MASK, 33, "world (1) + vision_block (6)")
	eq(Perception.SIGHT_MASK, 33)
	eq(SightLine.MASK, 33)
	eq(Hearing.BLOCK_MASK, 33)
	eq(Door.BLOCKER_LAYERS, 2, "players")
	eq(Interactable.LAYER_BIT, 8, "interactables")
	eq(Player.WORLD_MASK, 1, "world")
	eq(Perception.SEE_THROUGH_GROUP, &"see_through")
	eq(SightLine.SEE_THROUGH_GROUP, &"see_through")
	eq(Hearing.SEE_THROUGH_GROUP, &"see_through")
	eq(Hearing.GROUP, &"noise_listener")
	eq(Interactable.GROUP, &"interactables")
	eq(Interactable.ACTOR_GROUP, &"interaction_actors")
	var bus: Script = load("res://autoload/noise.gd") as Script
	var bus_consts: Dictionary = bus.get_script_constant_map()
	eq(bus_consts.get("LISTENER_GROUP"), &"noise_listener")
	eq(bus_consts.get("ACTOR_GROUP"), &"interaction_actors")
	var builder: Dictionary = (load("res://levels/tools/build_levels.gd") as Script).get_script_constant_map()
	eq(builder.get("WORLD_LAYER"), 1)
	eq(builder.get("PLAYERS_LAYER"), 2)
	eq(builder.get("TRIGGERS_LAYER"), 16)
	eq(builder.get("SEE_THROUGH_GROUP"), &"see_through")


func test_no_copies_outside_source() -> void:
	var groups: PackedStringArray = _group_names()
	is_true(groups.size() >= 4, "PhysicsLayers grup adları")
	var paths: PackedStringArray = _scripts_under("res://")
	is_true(paths.size() > 10, "taranan betik")
	has(paths, SOURCE)
	for path: String in paths:
		if path == SOURCE:
			continue
		for v: String in violations(FileAccess.get_file_as_string(path), groups):
			fail("%s: katman/grup kopyası (PhysicsLayers kullan): %s" % [path, v])


func test_scanner_catches_mutants() -> void:
	var groups: PackedStringArray = _group_names()
	var mutants: Array[String] = [
		"const MASK := (1 << 0) | (1 << 5)",
		"const BLOCKER_LAYERS := 1 << 1",
		"const LAYER_BIT := 8",
		"const WORLD_MASK := 1",
		"const WORLD_LAYER := 1",
		"const SIGHT_MASK: int = 33",
		"\tbody.collision_layer = 16",
		"\tquery.collision_mask = 1",
		"\tbody.set_collision_mask_value(2, true)",
		"\tvar q := PhysicsRayQueryParameters2D.create(a, b, 33)",
		"const SEE_THROUGH_GROUP := &\"see_through\"",
		"\tadd_to_group(\"interaction_actors\")",
		"\tfor n: Node in get_tree().get_nodes_in_group(&\"noise_listener\"):",
		"\tif body.is_in_group(\"interactables\"):",
	]
	for line: String in mutants:
		eq(violations(line + "\n", groups).size(), 1, "yakalanmalı: " + line.strip_edges())
	var clean: String = "\n".join([
		"const HUD_LAYER := 10",
		"const SIGHT_RANGE := 200.0",
		"const MASK := PhysicsLayers.SIGHT_MASK",
		"const WORLD_LAYER := PhysicsLayers.WORLD  # katman 1 `world`, 1 << 0",
		"\twalls.collision_mask = 0",
		"\tbody.add_to_group(PhysicsLayers.SEE_THROUGH_GROUP, true)",
		"## `see_through` grubu; \"interactables\" yorumda serbest; collision_layer = 2",
		"\tvar flags: int = 1 << bit",
		"\tvar q := PhysicsRayQueryParameters2D.create(a, b, PhysicsLayers.SIGHT_MASK, exclude)",
	])
	eq(violations(clean, groups), PackedStringArray(), "temiz örnek ihlal vermez")


## Kaynaktaki ihlal satırları (yorumlar atılmış kod; her satır en fazla bir kez).
static func violations(source: String, groups: PackedStringArray) -> PackedStringArray:
	var rules: Array[RegEx] = [
		RegEx.create_from_string("(?i)^(?=.*\\b1\\s*<<)(?=.*(layer|mask|collision))"),
		RegEx.create_from_string("collision_(layer|mask)\\s*=\\s*[1-9]"),
		RegEx.create_from_string("set_collision_(layer|mask)(_value)?\\(\\s*[1-9]"),
		RegEx.create_from_string(
			"\\bconst\\s+(\\w*(MASK|_LAYERS|LAYER_BIT)|\\w*(%s)\\w*_LAYER)\\s*(:\\s*int\\s*)?:?=\\s*[\\d(]" % LAYER_WORDS),
		RegEx.create_from_string("PhysicsRayQueryParameters2D\\.create\\([^,]+,[^,]+,\\s*[1-9]"),
	]
	if not groups.is_empty():
		rules.append(RegEx.create_from_string("[\"'](%s)[\"']" % "|".join(groups)))
	var out: PackedStringArray = []
	for line: String in source.split("\n"):
		var code: String = Deps.strip_comment(line)
		for rule: RegEx in rules:
			if rule.search(code) != null:
				out.append(line.strip_edges())
				break
	return out


## PhysicsLayers'taki grup adları (StringName sabitleri).
static func _group_names() -> PackedStringArray:
	var out: PackedStringArray = []
	var consts: Dictionary = (load(SOURCE) as Script).get_script_constant_map()
	for key: String in consts:
		if typeof(consts[key]) == TYPE_STRING_NAME:
			out.append(str(consts[key]))
	return out


static func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if SKIP_DIRS.has(dir.trim_suffix("/")) or FileAccess.file_exists(dir.path_join(".gdignore")):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts_under(dir.path_join(d)))
	return out
