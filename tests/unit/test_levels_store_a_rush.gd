extends TestCase
## IS-113 (KR-044): "Kalabalık saat" variant `store_a_rush` = store_a geometry with a rhythm-only override set
## (levels/store_a_rush.tscn root `tuning_overrides`, IS-106 VenueTuning). Checks: same geometry and names as store_a,
## the overrides are valid and really reach the population/register readers, store_a itself keeps no overrides.
## Generic S4 checks of the scene run in test_levels*.gd (LEVELS list).

const STORE_A := "res://levels/store_a.tscn"
const RUSH := "res://levels/store_a_rush.tscn"
const TILE := 32
const GROUPS: Array[String] = ["Markers", "SpawnPoints", "Zones", "Props", "NPCs", "Navigation"]
## Rhythm fields the variant changes, with the value store_a's global population.tres gives (for the halving check).
const HALVED: Dictionary = {"customer_first_min": 10.0, "customer_first_max": 20.0, "customer_interval": 35.0, "customer_jitter": 15.0}


func test_rush_geometry_equals_store_a() -> void:
	var a: Level = _load(STORE_A)
	var r: Level = _load(RUSH)
	if a == null or r == null:
		return
	var ta: LevelLayout = a.layout()
	var tr: LevelLayout = r.layout()
	eq(tr.size_in_tiles(), ta.size_in_tiles(), "store_a_rush: karo boyutu store_a ile aynı")
	var same_kinds: int = 0
	for y: int in ta.size_in_tiles().y:
		for x: int in ta.size_in_tiles().x:
			var cell := Vector2i(x, y)
			if tr.kind_at(cell) == ta.kind_at(cell):
				same_kinds += 1
	eq(same_kinds, ta.size_in_tiles().x * ta.size_in_tiles().y, "store_a_rush: her karonun türü store_a ile aynı")
	for group: String in GROUPS:
		for child: Node in a.get_node(group).get_children():
			var path := NodePath("%s/%s" % [group, child.name])
			var twin: Node = r.get_node_or_null(path)
			if not is_true(twin != null, "store_a_rush: %s yok (store_a'da var)" % path):
				continue
			eq(twin.get_class(), child.get_class(), "store_a_rush: %s türü" % path)
			if child is Node2D and twin is Node2D:
				near((twin as Node2D).position, (child as Node2D).position, 0.01, "store_a_rush: %s konumu" % path)
	eq(r.spawn_count(), a.spawn_count(), "store_a_rush: spawn sayısı")


func test_rush_overrides_are_valid_and_limited() -> void:
	var r: Level = _load(RUSH)
	if r == null:
		return
	eq(VenueTuning.errors(r.tuning_overrides), PackedStringArray(), "store_a_rush: tuning_overrides geçerli")
	eq(r.tuning_overrides.keys(), ["population"], "store_a_rush: yalnız nüfus ezmesi (sahip/kasa ayrı yolda)")
	var fields: Dictionary = VenueTuning.fields_for(r.tuning_overrides, VenueTuning.POPULATION)
	eq(fields.keys().size(), HALVED.size(), "store_a_rush: nüfus ezme alanı sayısı")


func test_rush_population_is_halved_and_customers_stay_two() -> void:
	var r: Level = _load(RUSH)
	if r == null:
		return
	var pop: Node = r.npcs_root().get_node_or_null(^"Population")
	if not is_true(pop != null, "store_a_rush: NPCs/Population yok"):
		return
	var base: Resource = VenueTuning.base(VenueTuning.POPULATION)
	var eff: Resource = VenueTuning.of(pop, VenueTuning.POPULATION, base)
	is_true(eff != base, "store_a_rush: nüfus ayarı ezilmiş kopya")
	for field: String in HALVED:
		near(float(eff.get(field)), float(HALVED[field]) * 0.5, 0.001, "store_a_rush: %s yarıya indi" % field)
	is_true(int(eff.get("customer_max")) >= 2, "store_a_rush: aynı anda müşteri tavanı >= 2")
	near(float(base.get("customer_interval")), 35.0, 0.001, "store_a_rush: global nüfus ayarı değişmedi")


func test_rush_register_holds_250() -> void:
	var a: Level = _load(STORE_A)
	var r: Level = _load(RUSH)
	if a == null or r == null:
		return
	var reg_a: Node = a.props_root().get_node_or_null(^"Register")
	var reg_r: Node = r.props_root().get_node_or_null(^"Register")
	if not is_true(reg_a != null and reg_r != null, "Props/Register her iki haritada"):
		return
	eq((reg_a.get("def") as PropDef).cash_value, 150, "store_a kasası 150")
	eq((reg_r.get("def") as PropDef).cash_value, 250, "store_a_rush kasası 250")


func test_store_a_keeps_no_overrides() -> void:
	var a: Level = _load(STORE_A)
	if a == null:
		return
	eq(a.tuning_overrides.size(), 0, "store_a ezme taşımaz (davranışı değişmez)")


func _load(path: String) -> Level:
	var scene: PackedScene = load(path) as PackedScene
	if not is_true(scene != null, "%s yüklenemedi" % path):
		return null
	var level: Level = scene.instantiate() as Level
	if not is_true(level != null, "%s kökü Level olmalı" % path):
		return null
	return autofree(level) as Level
