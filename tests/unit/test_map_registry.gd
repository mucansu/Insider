extends TestCase
## US-050 AC1/AC4: the playable map registry (data/map_registry.tres) and Game's map API (S3 addendum map_list / request_map_switch).
## The list is the three playable shops in order, every entry a loadable Level scene with a name key the score table also derives
## (SessionScores.map_key) and a text row; no test arena / fixture. A switch to an unlisted path is refused on the host, and a
## client cannot switch at all (Net client state; nothing loads).

const EXPECTED: Array[String] = ["res://levels/store_a.tscn", "res://levels/store_a_rush.tscn", "res://levels/store_b.tscn"]


func test_registry_lists_playable_shops_in_order() -> void:
	var registry: MapRegistry = MapRegistry.load_default()
	eq(Array(registry.paths()), EXPECTED as Array, "oynanabilir haritalar, sırayla")
	for path: String in registry.paths():
		is_false(path.begins_with("res://tests/"), "fikstür listede olmaz: " + path)
		is_false(path.get_file().begins_with("test_"), "test arenası listede olmaz: " + path)
	is_false(registry.has_path("res://levels/test_arena.tscn"))
	is_false(registry.has_path(""))
	is_true(registry.has_path("res://levels/store_a_rush.tscn"))


func test_entries_are_levels_with_name_keys() -> void:
	var registry: MapRegistry = MapRegistry.load_default()
	for entry: MapEntry in registry.maps:
		var path: String = entry.level_path
		eq(entry.name_key, SessionScores.map_key(path), "ad anahtarı skor tablosunun türettiğiyle aynı: " + path)
		ne(tr(entry.name_key), entry.name_key, "harita adı metni var: " + entry.name_key)
		is_true(ResourceLoader.exists(path), "sahne var: " + path)
		var scene: PackedScene = load(path) as PackedScene
		if not is_true(scene != null, "sahne yüklenir: " + path):
			continue
		var state: SceneState = scene.get_state()
		var script: Script = null
		for i: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"script":
				script = state.get_node_property_value(0, i) as Script
		is_true(script != null and script.resource_path == "res://levels/level.gd", "kök Level betiği: " + path)
	eq(registry.name_key_of("res://levels/store_a_rush.tscn"), "MAP_STORE_A_RUSH")
	eq(registry.name_key_of("res://levels/test_arena.tscn"), "", "listede olmayanın anahtarı yok")


func test_game_map_list_matches_registry() -> void:
	var list: Array[Dictionary] = Game.map_list()
	eq(list, MapRegistry.load_default().to_list())
	eq(list.size(), 3)
	eq(list[1], {"path": "res://levels/store_a_rush.tscn", "name_key": "MAP_STORE_A_RUSH"})
	list[0]["path"] = "res://x.tscn"
	eq(str(Game.map_list()[0]["path"]), EXPECTED[0], "kopya döner; kayıt değişmez")


func test_host_refuses_unlisted_path() -> void:
	# Offline counts as host authority; an unlisted path (fixture, test arena, traversal, empty) never reaches start_level.
	for path: String in ["res://tests/fixtures/empty_level.tscn", "res://levels/test_arena.tscn",
			"res://levels/../levels/store_a.tscn", "", "user://store_a.tscn"]:
		is_false(Game.request_map_switch(path), "kayıt dışı yol reddedilir: " + path)
	is_true(Game.current_level() == null, "seviye yüklenmedi")


func test_client_cannot_switch_map() -> void:
	# A client (here: a pending ENet client, no host) has no switch path: the call is refused, nothing loads, no RPC exists.
	var port: int = 20000 + randi() % 20000
	if not eq(Net.join("127.0.0.1", port), OK, "istemci kipi"):
		return
	is_false(Net.is_host())
	is_false(Game.request_map_switch(EXPECTED[1]), "istemci harita değiştiremez")
	is_true(Game.current_level() == null, "istemcide seviye yüklenmedi")
	Net.leave()
	await tree().process_frame
