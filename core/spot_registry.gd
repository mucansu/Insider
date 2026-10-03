class_name SpotRegistry
extends RefCounted
## Spot reservation (US-016 AC1; oyun-yz round 2 #12; GDD §9.2). Node-free: marker name (StringName) -> holder id (int, e.g. NPC index). Two holders cannot hold the same spot at once
## (two customers never go to the same shelf or queue point). A holder releases when its task ends, is cut or the NPC is removed. Host only (the population spawner keeps the single registry); no networking.

## spot -> holder (0 = none; not stored in the registry).
var _holders: Dictionary = {}


## Holds `spot` for `holder`. True if free or already theirs; false if someone else's. Invalid input is false.
func claim(spot: StringName, holder: int) -> bool:
	if spot.is_empty() or holder == 0:
		return false
	var current: int = int(_holders.get(spot, 0))
	if current != 0 and current != holder:
		return false
	_holders[spot] = holder
	return true


## Releases the spots `holder` holds; if `spot` is given only that one (untouched if someone else's).
func release(holder: int, spot: StringName = &"") -> void:
	if not spot.is_empty():
		if int(_holders.get(spot, 0)) == holder:
			_holders.erase(spot)
		return
	for key: StringName in _holders.keys():
		if int(_holders[key]) == holder:
			_holders.erase(key)


func is_free(spot: StringName) -> bool:
	return not _holders.has(spot)


## Holder of the spot (0 = free).
func holder_of(spot: StringName) -> int:
	return int(_holders.get(spot, 0))


## Spots held by `holder` (sorted by name).
func spots_of(holder: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in _holders:
		if int(_holders[key]) == holder:
			out.append(key)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Free ones among the candidates (candidate order kept).
func free_of(candidates: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for spot: StringName in candidates:
		if is_free(spot):
			out.append(spot)
	return out


## Holds the first free candidate for `holder`; empty StringName if none.
func claim_first(candidates: Array[StringName], holder: int) -> StringName:
	for spot: StringName in candidates:
		if claim(spot, holder):
			return spot
	return &""


func size() -> int:
	return _holders.size()


func clear() -> void:
	_holders.clear()
