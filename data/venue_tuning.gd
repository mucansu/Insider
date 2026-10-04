class_name VenueTuning
extends RefCounted
## Per-map tuning access point (IS-106, KR-037; mimari.md S10 addition). The global `data/` tuning files are defaults; a level overrides
## single fields with its root's `tuning_overrides` ({id: {field: value}}, e.g. {&"store_tools": {"topple_radius": 400.0}}; S4 Level).
## Every reader of an overridable tuning goes through `of(node, id, base)`: the nearest ancestor holding `tuning_overrides` (the level
## root) is found, its fields for `id` are applied to a copy of the base (`TuningOverrides.apply`; the global resource is never changed)
## and the copy is cached on that level. No level, or no overrides for `id` -> the base itself (store_a: identical behaviour).
## Overridable ids are the venue-dependent tuning files (PATHS); character/perception physics shared by every map (player, vision, noise,
## contact) and Game's heist tuning (autoload, not routed yet) are not listed. Unknown ids/fields: `errors` (the level reports them on
## ready; a unit test keeps every level scene clean).

const OWNER := &"owner"
const CIVILIAN := &"civilian"
const PERCEPTION := &"perception"
const POPULATION := &"population"
const STORE_TOOLS := &"store_tools"
const CHASER := &"chaser"
## id -> global default resource.
const PATHS: Dictionary = {
	OWNER: "res://data/npc/owner_tuning.tres",
	CIVILIAN: "res://data/npc/civilian_tuning.tres",
	PERCEPTION: "res://data/npc/perception_tuning.tres",
	POPULATION: "res://data/npc/population.tres",
	STORE_TOOLS: "res://data/props/store_tools.tres",
	CHASER: "res://data/npc/chaser_tuning.tres",
}
## Property of the level root holding the overrides.
const HOLDER_PROPERTY := &"tuning_overrides"
## Meta key of the per-level cache of resolved copies.
const CACHE_META := &"venue_tuning_cache"


## Global default of `id` (null + error if unknown).
static func base(id: StringName) -> Resource:
	if not PATHS.has(id):
		push_error("VenueTuning: bilinmeyen ayar adı '%s'" % id)
		return null
	return load(str(PATHS[id]))


## The tuning `id` as seen by `node`: `base_res` (null -> the global default) with the overrides of the nearest level applied.
static func of(node: Node, id: StringName, base_res: Resource = null) -> Resource:
	var res: Resource = base_res if base_res != null else base(id)
	if res == null or node == null:
		return res
	var holder: Node = holder_of(node)
	if holder == null:
		return res
	var fields: Dictionary = fields_for(holder.get(HOLDER_PROPERTY) as Dictionary, id)
	if fields.is_empty():
		return res
	var cache: Dictionary = holder.get_meta(CACHE_META, {}) as Dictionary
	if cache.values().has(res):
		return res  # already this level's copy (e.g. handed down by the spawner)
	var key: String = "%s#%d" % [id, res.get_instance_id()]
	if not cache.has(key):
		cache[key] = TuningOverrides.apply(res, fields, "%s %s" % [holder.name, id])
		holder.set_meta(CACHE_META, cache)
	return cache[key] as Resource


## Nearest node (itself or an ancestor) with a Dictionary `tuning_overrides`; null if none.
static func holder_of(node: Node) -> Node:
	var at: Node = node
	while at != null:
		if typeof(at.get(HOLDER_PROPERTY)) == TYPE_DICTIONARY:
			return at
		at = at.get_parent()
	return null


## Field overrides of `id` in an overrides dictionary (String or StringName keys); empty if none.
static func fields_for(overrides: Dictionary, id: StringName) -> Dictionary:
	for key: Variant in overrides:
		if StringName(str(key)) == id and typeof(overrides[key]) == TYPE_DICTIONARY:
			return overrides[key] as Dictionary
	return {}


## Problems of a level's overrides: unknown id, non-dictionary entry, unknown field or wrong type (TuningOverrides.errors). Empty = valid.
static func errors(overrides: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: Variant in overrides:
		var id := StringName(str(key))
		if not PATHS.has(id):
			out.append("bilinmeyen ayar adı: %s" % id)
		elif typeof(overrides[key]) != TYPE_DICTIONARY:
			out.append("%s: ezme bir sözlük olmalı" % id)
		else:
			out.append_array(TuningOverrides.errors(load(str(PATHS[id])), overrides[key] as Dictionary, String(id)))
	return out
