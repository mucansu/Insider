class_name NpcMover
extends Node
## NPC navigation component (US-008; S4 addendum, S11): host only. Moves to a target via NavigationServer2D paths; the brain reads
## `desired_velocity()` each step, the root body applies velocity (move_and_slide). Reaches the level only via the S4 Level API
## (duck typing: `navigation_region`, `props_root`, `door_link`).
## - Waits until the map is ready (iteration id 0: first ~5 physics frames), asks for no path.
## - Closed door: while a door link is closed the path does not cross it (Door sets link state). If there is no path to the target or the
##   path does not reach it, walks to the best closed door (shortest NPC -> door -> target total), opens it within range via the
##   Interactable host API (`host_use_by_npc`), then asks for a path again.
## - With neither path nor door `failed()` is true (NPC stops, does not push into walls; retries every REPATH_SEC): the brain counts it as
##   "arrived" and continues (I7: never freezes).
## - Repath is spread with a small per-NPC time offset (no batch query in one frame); a path not reaching the target is not "partial":
##   it is `failed` and reported to the brain via `path_failed`.
## - While on a door link (outside the NPC nav polygon) no repath: otherwise the nearest polygon point stays behind and the NPC oscillates
##   at the door threshold.
## IS-087 additions (host only):
## - Shortcut (`door_shortcut`): even with an open path to the target, a path through a closed door that is clearly shorter (gain >=
##   SHORTCUT_MIN_PX or >= SHORTCUT_RATIO x open path) is taken by opening the door (owner does not walk around via the street with the back
##   door open). Cost from nav path lengths (NPC -> door end + link + other end -> target).
## - Close behind (`close_behind`): after crossing the threshold of a listed door, `close_delay` s later (still in range; retries until the
##   leaf is clear) closes it via `host_close_by_npc`; no closing while `close_enabled` is false (owner on alarm).
## - Own door sound: open/close runs inside the sibling `Hearing`'s `ignore_own` (the NPC does not hear its own door sound).

## Host only: no path to the target found (and no door); the NPC stops.
signal path_failed(target: Vector2)

## Repath interval (s) and re-query when the target moves this far (px).
const REPATH_SEC := 0.5
## Upper bound of the per-NPC repath offset (s; deterministic from the node name).
const REPATH_SPREAD := 0.125
const REPATH_MOVE := 16.0
## Waypoint arrival (px).
const WAYPOINT_PX := 4.0
## If the path's last point is this close to the target it is a "path that reaches the target" (px).
const PATH_ARRIVE_PX := 32.0
## Door open distance (px; stays within the door range 40 + S2 margin).
const DOOR_REACH := 36.0
## Farther than this from the polygon counts as on the link (px).
const OFF_MESH_PX := 3.0
## Shortcut thresholds (IS-087 AC3): gain at least this many px or this ratio of the open path.
const SHORTCUT_MIN_PX := 160.0
const SHORTCUT_RATIO := 0.4
## Threshold crossing: side change within this distance along the door axis (px) counts as a crossing.
const CROSS_ALONG_PX := 24.0
## Close behind: retried for at most this many seconds after crossing.
const CLOSE_GIVE_UP_SEC := 3.0
const DOOR_NOISE_KIND := &"door"
const HEARING_NODE := ^"Hearing"

## Take the shortcut through a closed door (IS-087 AC3; owner).
var door_shortcut: bool = false
## Names of doors closed behind (node name under Props; IS-087 AC2) and delay (s).
var close_behind: Array[StringName] = []
var close_delay: float = 0.6
## False: close behind on hold (brain does not close on alarm).
var close_enabled: bool = true

var _target: Vector2 = Vector2.INF
var _speed: float = 0.0
var _stop: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _index: int = 0
var _repath_left: float = 0.0
var _path_target: Vector2 = Vector2.INF
var _failed: bool = false
var _spread: float = -1.0
var _door: Node2D = null
## Link end on the NPC side of the chosen door.
var _door_near: Vector2 = Vector2.INF
## Close behind: door name -> last side (+/-1); door name -> time since crossing (s).
var _door_side: Dictionary = {}
var _close_wait: Dictionary = {}
## Diagnostics (dump/test): number of doors opened, chosen for shortcut, and closed behind.
var doors_opened: int = 0
var shortcuts: int = 0
var doors_closed: int = 0


## Go to the target at `speed` px/s; within `stop_distance` counts as arrived.
func move_to(target: Vector2, speed: float, stop_distance: float = 0.0) -> void:
	if not target.is_finite():
		stop()
		return
	_speed = maxf(speed, 0.0)
	_stop = maxf(stop_distance, 0.0)
	if not _target.is_finite() or _target.distance_to(target) > REPATH_MOVE:
		_repath_left = 0.0
		_failed = false
	_target = target


func stop() -> void:
	_target = Vector2.INF
	_path = PackedVector2Array()
	_door = null
	_failed = false


func target() -> Vector2:
	return _target


func arrived() -> bool:
	return not _target.is_finite() or _body_pos().distance_to(_target) <= maxf(_stop, WAYPOINT_PX)


## Cannot reach the target (no path, no door to open).
func failed() -> bool:
	return _failed


## Whether the nav map is ready (iteration id > 0).
func map_ready() -> bool:
	var map: RID = _map()
	return map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0


## Desired velocity this step (global px/s). Close behind runs on every call (even when arrived).
func desired_velocity(delta: float) -> Vector2:
	_track_doors(delta)
	if arrived():
		return Vector2.ZERO
	var here: Vector2 = _body_pos()
	if not map_ready():
		return Vector2.ZERO
	_repath_left -= maxf(delta, 0.0)
	if _failed:
		if _repath_left > 0.0:
			return Vector2.ZERO
		_plan(here)  # there was no path: retries at an interval (door may have opened, map updated)
		if _failed:
			return Vector2.ZERO
	var due: bool = _repath_left <= 0.0 or _path.is_empty() or _path_target.distance_to(_target) > REPATH_MOVE
	if due and (_path.is_empty() or not _on_link(here)):
		_plan(here)
	if _door != null and here.distance_to(_door.global_position) <= DOOR_REACH:
		_open(_door, here)
		_repath_left = 0.0
		return Vector2.ZERO
	while _index < _path.size() and here.distance_to(_path[_index]) <= WAYPOINT_PX:
		_index += 1
	if _index >= _path.size():
		if _door != null:
			var to_door: Vector2 = _door.global_position - here
			return to_door.limit_length(_speed) if to_door.length() > WAYPOINT_PX else Vector2.ZERO
		var rest: Vector2 = _target - here
		return rest.normalized() * minf(_speed, rest.length() / maxf(delta, 0.0001))
	var step: Vector2 = _path[_index] - here
	return step.normalized() * _speed


func _plan(here: Vector2) -> void:
	if _spread < 0.0:
		var key: String = String(get_parent().name) if get_parent() != null else ""
		_spread = float(absi(key.hash()) % 1000) / 1000.0 * REPATH_SPREAD
	_repath_left = REPATH_SEC + _spread
	_path_target = _target
	_door = null
	_index = 0
	_path = _query(here, _target)
	if _reaches(_path, _target):
		_failed = false
		if door_shortcut:
			var shortcut: Node2D = _shortcut_door(here, _target, path_length(_path))
			if shortcut != null:
				shortcuts += 1
				_door = shortcut
				_path = _query(here, _door_near)
		return
	var door: Node2D = _best_closed_door(here, _target)
	if door == null:
		var was: bool = _failed
		_failed = here.distance_to(_target) > PATH_ARRIVE_PX  # no path to the target: does not push into walls, stops
		_path = PackedVector2Array()
		if _failed and not was:
			path_failed.emit(_target)
		return
	_door = door
	_path = _query(here, _door_near)
	_failed = false


func _on_link(here: Vector2) -> bool:
	var map: RID = _map()
	return map.is_valid() and NavigationServer2D.map_get_closest_point(map, here).distance_to(here) > OFF_MESH_PX


func _query(from: Vector2, to: Vector2) -> PackedVector2Array:
	var map: RID = _map()
	if not map.is_valid():
		return PackedVector2Array()
	return NavigationServer2D.map_get_path(map, from, to, true)


static func _reaches(path: PackedVector2Array, to: Vector2) -> bool:
	return path.size() >= 2 and path[path.size() - 1].distance_to(to) <= PATH_ARRIVE_PX


## Among closed doors cutting the path to the target, the one with the shortest NPC -> door -> target total (only doors whose NPC side
## reaches the door and whose far side reaches the target: if opening will not lead to the target, the door is left alone).
func _best_closed_door(from: Vector2, to: Vector2) -> Node2D:
	var level: Node = _level()
	if level == null or not level.has_method(&"props_root"):
		return null
	var props: Node = level.call(&"props_root") as Node
	if props == null:
		return null
	var best: Node2D = null
	var best_cost: float = INF
	for child: Node in props.get_children():
		var door: Node2D = child as Node2D
		if door == null or not (&"is_open" in door) or bool(door.get(&"is_open")):
			continue
		if level.call(&"door_link", StringName(door.name)) == null:
			continue
		var near: Vector2 = _near_end(door, from, to)
		if not near.is_finite():
			continue  # opening this door does not lead to the target
		var cost: float = from.distance_to(door.global_position) + door.global_position.distance_to(to)
		if cost < best_cost:
			best_cost = cost
			best = door
			_door_near = near
	return best


## Door link end on the NPC side: the end reachable from `from` if the other end reaches `to`; else INF.
func _near_end(door: Node2D, from: Vector2, to: Vector2) -> Vector2:
	var link: NavigationLink2D = _level().call(&"door_link", StringName(door.name)) as NavigationLink2D
	if link == null:
		return Vector2.INF
	var ends: Array[Vector2] = [link.to_global(link.start_position), link.to_global(link.end_position)]
	for i: int in 2:
		var near: Vector2 = ends[i]
		var far: Vector2 = ends[1 - i]
		if _reaches(_query(from, near), near) and _reaches(_query(far, to), to):
			return near
	return Vector2.INF


func _open(door: Node2D, here: Vector2) -> void:
	var item: Interactable = door.get_node_or_null(^"Interactable") as Interactable
	if item != null and &"is_open" in door and not bool(door.get(&"is_open")):
		# "open" only: an open door is not touched (does not close); does not hear its own door sound (IS-087 AC1)
		if bool(_as_own_noise(door.global_position, func() -> bool: return item.host_use_by_npc(here))):
			doors_opened += 1
	_door = null


## Nearest point to `point` on the nav network (`point` itself if no map; US-043 run-the-wrong-way target).
func closest_reachable(point: Vector2) -> Vector2:
	var map: RID = _map()
	if not map.is_valid() or not point.is_finite():
		return point
	return NavigationServer2D.map_get_closest_point(map, point)


## Path length (px).
static func path_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## Shortcut (IS-087 AC3): a closed door clearly shorter than the open path (`open_length`); null if none. If chosen,
## `_door_near` is the NPC-side end.
func _shortcut_door(from: Vector2, to: Vector2, open_length: float) -> Node2D:
	var level: Node = _level()
	if level == null or not level.has_method(&"props_root"):
		return null
	var props: Node = level.call(&"props_root") as Node
	if props == null:
		return null
	var best: Node2D = null
	var best_cost: float = INF
	var best_near: Vector2 = Vector2.INF
	for child: Node in props.get_children():
		var door: Node2D = child as Node2D
		if door == null or not (&"is_open" in door) or bool(door.get(&"is_open")):
			continue
		var link: NavigationLink2D = level.call(&"door_link", StringName(door.name)) as NavigationLink2D
		if link == null:
			continue
		var ends: Array[Vector2] = [link.to_global(link.start_position), link.to_global(link.end_position)]
		for i: int in 2:
			var near_path: PackedVector2Array = _query(from, ends[i])
			if not _reaches(near_path, ends[i]):
				continue
			var far_path: PackedVector2Array = _query(ends[1 - i], to)
			if not _reaches(far_path, to):
				continue
			var cost: float = path_length(near_path) + ends[0].distance_to(ends[1]) + path_length(far_path)
			if cost < best_cost:
				best_cost = cost
				best = door
				best_near = ends[i]
	if best == null:
		return null
	var saving: float = open_length - best_cost
	if saving < SHORTCUT_MIN_PX and saving < SHORTCUT_RATIO * open_length:
		return null
	_door_near = best_near
	return best


## Close behind (IS-087 AC2): closes a listed door `close_delay` after crossing its threshold.
func _track_doors(delta: float) -> void:
	if close_behind.is_empty():
		return
	var level: Node = _level()
	if level == null or not level.has_method(&"props_root"):
		return
	var props: Node = level.call(&"props_root") as Node
	if props == null:
		return
	var here: Vector2 = _body_pos()
	for door_name: StringName in close_behind:
		var door: Node2D = props.get_node_or_null(NodePath(String(door_name))) as Node2D
		if door == null or not (&"is_open" in door):
			continue
		var offset: Vector2 = here - door.global_position
		var normal: Vector2 = Vector2.DOWN.rotated(door.global_rotation)
		var side: float = signf(offset.dot(normal))
		var was: float = float(_door_side.get(door_name, side))
		if side != 0.0:
			_door_side[door_name] = side
		if side != 0.0 and was != 0.0 and side != was and absf(offset.dot(normal.orthogonal())) <= CROSS_ALONG_PX:
			_close_wait[door_name] = 0.0
		if not _close_wait.has(door_name):
			continue
		var waited: float = float(_close_wait[door_name]) + maxf(delta, 0.0)
		_close_wait[door_name] = waited
		if not bool(door.get(&"is_open")) or waited > CLOSE_GIVE_UP_SEC:
			_close_wait.erase(door_name)
		elif close_enabled and waited >= close_delay and door.has_method(&"host_close_by_npc"):
			var closer := func() -> bool: return bool(door.call(&"host_close_by_npc", here))
			if bool(_as_own_noise(door.global_position, closer)):
				doors_closed += 1
				_close_wait.erase(door_name)


## Own action: if a sibling Hearing exists, the action's door sound is not heard (IS-087 AC1).
func _as_own_noise(at: Vector2, action: Callable) -> Variant:
	var body: Node = get_parent()
	var hearing: Node = body.get_node_or_null(HEARING_NODE) if body != null else null
	if hearing != null and hearing.has_method(&"ignore_own"):
		return hearing.call(&"ignore_own", at, DOOR_NOISE_KIND, action)
	return action.call()


func _map() -> RID:
	var level: Node = _level()
	if level != null and level.has_method(&"navigation_region"):
		var region: NavigationRegion2D = level.call(&"navigation_region") as NavigationRegion2D
		if region != null and region.is_inside_tree():
			return region.get_navigation_map()
	var body: Node2D = get_parent() as Node2D
	return body.get_world_2d().navigation_map if body != null and body.is_inside_tree() else RID()


## Nearest ancestor with the Level API (S4; duck typing).
func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"door_link"):
		node = node.get_parent()
	return node


func _body_pos() -> Vector2:
	var body: Node2D = get_parent() as Node2D
	return body.global_position if body != null else Vector2.ZERO
