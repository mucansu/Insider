class_name NpcStage
extends RefCounted
## Scene helper for US-008 unit tests: adds store_a (owner + alert manager + neighbour spawner) to the tree, links its navigation to an
## isolated synchronous map (test_levels_nav pattern: the map is empty in the first frames, wait for the iteration id), turns off the
## NPCs' own stepping (tests drive a fixed step) and spawns remote player copies (authority 2+, no input; the test writes the
## position, `interaction_position()` = drawn position).
## US-016: with `with_population = true` the population spawner (Population) is stepped by hand too (civilians included); off by default
## (old tests run without population).

const STORE := "res://levels/store_a.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const DT := 1.0 / 60.0

var test: TestCase
var level: Level = null
var map: RID = RID()
## Whether the population spawner is stepped inside `run` (US-016).
var with_population: bool = false
## IS-087: doors start as in the scene (inner door D closed). Since `run` steps without waiting for a physics frame, when a door
## opens and closes (an NPC opens it / closes it behind) the wing body (Door applies deferred) and the navigation link (map
## iteration) are not updated within the step; after each step `run` applies the changed door's body at once and force-syncs
## the isolated map (`map_force_update`; the map is synchronous, single thread).
var _door_open: Dictionary = {}
var _forced: bool = false


func _init(owner_test: TestCase) -> void:
	test = owner_test


## Builds store_a; NPC steps by hand. `before_enter(level)` is called before adding to the tree (e.g. a fake component).
## Game's alert state (an autoload, persists between tests) is reset. Null on failure.
func enter(path: String = STORE, before_enter: Callable = Callable()) -> Level:
	Game.set_alert_level(0)
	Game.set_alert_timer(-1.0)
	level = (load(path) as PackedScene).instantiate() as Level
	if level == null:
		return null
	for child: Node in level.npcs_root().get_children():
		if &"auto_step" in child:
			child.set(&"auto_step", false)
	if before_enter.is_valid():
		before_enter.call(level)
	var region: NavigationRegion2D = level.navigation_region()
	var world_map: RID = test.tree().root.get_world_2d().navigation_map
	map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(map, NavigationServer2D.map_get_cell_size(world_map))
	NavigationServer2D.map_set_edge_connection_margin(map, NavigationServer2D.map_get_edge_connection_margin(world_map))
	NavigationServer2D.map_set_link_connection_radius(map, NavigationServer2D.map_get_link_connection_radius(world_map))
	NavigationServer2D.map_set_use_async_iterations(map, false)
	NavigationServer2D.map_set_active(map, true)
	region.set_navigation_map(map)
	NavigationServer2D.region_set_use_async_iterations(region.get_rid(), false)
	for link: Node in region.get_children():
		(link as NavigationLink2D).set_navigation_map(map)
	test.tree().root.add_child(level)
	await sync()
	await test.tree().physics_frame
	await test.tree().physics_frame
	return level


## Map sync (also called when a door link changes): waits physics frames until the iteration id rises
## (`map_force_update` is being deprecated in 4.7; not used).
func sync() -> void:
	if _forced and not _doors_dirty():
		_forced = false  # `run` already force-synced the map and no door has changed since
		return
	_forced = false
	var before: int = NavigationServer2D.map_get_iteration_id(map)
	for i: int in 30:
		await test.tree().physics_frame
		if NavigationServer2D.map_get_iteration_id(map) > before:
			return
	test.fail("gezinme haritası eşitlenmedi")


func leave() -> void:
	Game._events.clear()  # US-039: discovery session events (offline) must not leak into later tests' dumps
	if level != null and is_instance_valid(level):
		test.tree().root.remove_child(level)
		level.queue_free()
	if map.is_valid():
		NavigationServer2D.free_rid(map)
	map = RID()


func owner() -> StoreOwner:
	for child: Node in level.npcs_root().get_children():
		if child is StoreOwner:
			return child as StoreOwner
	return null


func population() -> Population:
	for child: Node in level.npcs_root().get_children():
		if child is Population:
			return child as Population
	return null


func alert() -> StoreAlert:
	for child: Node in level.npcs_root().get_children():
		if child is StoreAlert:
			return child as StoreAlert
	return null


func marker(marker_name: StringName) -> Vector2:
	return level.marker(marker_name).global_position


## Remote player copy (authority `peer_id` >= 2): under the level's Players.
func player(peer_id: int, at: Vector2) -> Player:
	var p: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	p.name = str(peer_id)
	p.set_multiplayer_authority(peer_id, true)
	p.position = at
	level.players_root().add_child(p)
	return p


## Owner + alert manager (+ neighbours) together for `seconds` s at a fixed step; `probe` after each step (if any).
func run(seconds: float, probe: Callable = Callable(), dt: float = DT) -> void:
	var o: StoreOwner = owner()
	var a: StoreAlert = alert()
	var pop: Population = population() if with_population else null
	for i: int in roundi(seconds / dt):
		for node: Node in test.tree().get_nodes_in_group(Interactable.GROUP):
			(node as Interactable).set_physics_process(false)
			(node as Interactable).step(dt)
		for p: Node in level.players_root().get_children():
			var status: PlayerStatus = p.get_node_or_null(^"Status") as PlayerStatus
			if status != null:
				status.set_physics_process(false)
				status.step(dt)
		o.step(dt)
		if pop != null:
			pop.step(dt)
		if a != null:
			a.step(dt)
			for c: Chaser in a.chasers():
				c.auto_step = false
				c.step(dt)
		_sync_doors()
		if probe.is_valid():
			probe.call()


## The changed door's body is applied at once, the navigation map is force-synced (see the `_door_open` note).
func _sync_doors() -> void:
	var changed: bool = false
	for child: Node in level.props_root().get_children():
		if not (&"is_open" in child):
			continue
		var open: bool = bool(child.get(&"is_open"))
		if _door_open.has(child.name) and bool(_door_open[child.name]) == open:
			continue
		var known: bool = _door_open.has(child.name)
		_door_open[child.name] = open
		if not known:
			continue  # first record: the state in the scene/given by the test is already synced
		var shape: CollisionShape2D = child.get_node_or_null(^"Body/CollisionShape2D") as CollisionShape2D
		if shape != null:
			shape.disabled = open
		changed = true
	if changed and map.is_valid():
		NavigationServer2D.map_force_update(map)
		_forced = true


## Whether any door has changed state since `run`'s last record (if the test changed it by hand it must wait for sync).
func _doors_dirty() -> bool:
	for child: Node in level.props_root().get_children():
		var known: bool = &"is_open" in child and _door_open.has(child.name)
		if known and bool(_door_open[child.name]) != bool(child.get(&"is_open")):
			return true
	return false
