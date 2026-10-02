class_name NpcStage
extends RefCounted
## US-008 birim testleri için sahne yardımcısı: store_a'yı (sahip + uyarı yöneticisi + mahalleli üreticisi)
## ağaca ekler, gezinmesini yalıtık ve eşzamanlı bir haritaya bağlar (test_levels_nav kalıbı: harita ilk karelerde
## boş, yineleme kimliği beklenir), NPC'lerin kendiliğinden adımını kapatır (testler sabit adımla sürer) ve uzak
## oyuncu kopyaları üretir (yetki 2+, girdi yok; konumu test yazar, `interaction_position()` = çizilen konum).

const STORE := "res://levels/store_a.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const DT := 1.0 / 60.0

var test: TestCase
var level: Level = null
var map: RID = RID()


func _init(owner_test: TestCase) -> void:
	test = owner_test


## store_a'yı kurar; NPC adımları elle. `before_enter(level)` ağaca eklemeden önce çağrılır (ör. sahte bileşen).
## Game'in uyarı durumu (autoload, testler arası kalır) sıfırlanır. Başarısızsa null.
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


## Harita eşitlemesi (kapı bağı değişince de çağrılır): yineleme kimliği artana kadar fizik karesi beklenir
## (`map_force_update` 4.7'de kullanımdan kalkıyor; kullanılmaz).
func sync() -> void:
	var before: int = NavigationServer2D.map_get_iteration_id(map)
	for i: int in 30:
		await test.tree().physics_frame
		if NavigationServer2D.map_get_iteration_id(map) > before:
			return
	test.fail("gezinme haritası eşitlenmedi")


func leave() -> void:
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


func alert() -> StoreAlert:
	for child: Node in level.npcs_root().get_children():
		if child is StoreAlert:
			return child as StoreAlert
	return null


func marker(marker_name: StringName) -> Vector2:
	return level.marker(marker_name).global_position


## Uzak oyuncu kopyası (yetki `peer_id` ≥ 2): seviyenin Players altında.
func player(peer_id: int, at: Vector2) -> Player:
	var p: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	p.name = str(peer_id)
	p.set_multiplayer_authority(peer_id, true)
	p.position = at
	level.players_root().add_child(p)
	return p


## Sahip + uyarı yöneticisi (+ mahalleliler) birlikte `seconds` sn sabit adım; her adımdan sonra `probe` (varsa).
func run(seconds: float, probe: Callable = Callable(), dt: float = DT) -> void:
	var o: StoreOwner = owner()
	var a: StoreAlert = alert()
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
		if a != null:
			a.step(dt)
			for c: Chaser in a.chasers():
				c.auto_step = false
				c.step(dt)
		if probe.is_valid():
			probe.call()
