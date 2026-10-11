class_name HeatNotice
extends RefCounted
## In-session heat notice (US-052, KR-044; AC4): short lines the HUD shows as toasts when a level opens (job prep): "The neighbourhood is
## on edge (heat 19): neighbours come sooner" when later jobs are hot, and "The shopkeeper knows you: <name>" for each player the owner
## starts suspicious of. Reads only Game's `session_heat_state()` ({"heat", "active", "known": [peer]}) and `players()` (S3, duck-typed;
## ui does not reference core). Empty when nothing carries over (first job, cool session) or the game object lacks the API.

const HOT_KEY := &"HUD_HEAT_HOT"
const KNOWN_KEY := &"HUD_HEAT_KNOWN"


## Notice lines in display order; `translator` supplies tr() (the HUD).
static func lines(game: Object, translator: Object) -> PackedStringArray:
	var out := PackedStringArray()
	if game == null or translator == null or not game.has_method(&"session_heat_state"):
		return out
	var state: Dictionary = game.call(&"session_heat_state") as Dictionary
	if bool(state.get("active", false)):
		out.append(translator.tr(HOT_KEY) % int(state.get("heat", 0)))
	var roster: Dictionary = game.call(&"players") as Dictionary if game.has_method(&"players") else {}
	for peer: Variant in state.get("known", []) as Array:
		var entry: Variant = roster.get(int(peer))
		if entry is Dictionary:
			out.append(translator.tr(KNOWN_KEY) % str((entry as Dictionary).get("name", "")))
	return out
