class_name CivilianSenses
extends Node
## Civilian observer's player context (US-008 AC1/AC3/AC7; GDD §6.1, §9.3; S2, S4, S11). Meaningful on the host only. Reads players' zone
## (Level `Zones`: CustomerArea/StaffArea/Backroom), in-shop time (loitering), ongoing interaction (`Interactable.held_by`: register/cash ->
## CASH, other held ones -> TAMPER) and bag state (`is_carrying_bag()` if present) and turns them into a `CivilianRules` context;
## `factor_for` is the perception component's `factor_query`. Emits `door_crossed` (bell) on entering/leaving via the front door
## and `back_door_rang` when a player opens/closes or crosses the back-bell door (IS-104).
## Position is always the synchronizer's latest (`interaction_position()`, S7): decisions against the player (AC8). Reaches the level only
## via the S4 Level API (duck typing: `zone`, `marker`, `marker_sequence`, `props_root`).
## US-010 additions: loiter counter (`loiter_s`) resets on leaving the shop (GDD §9.3), dump `loiter_dump()`; innocent (social)
## interaction (`Interactable.innocent`: buy, talk, send) is not tampering; distraction source (`distraction_source(pos)`: the prop at
## that point offering `distraction_peer`).

## Host only: player crossed the front door threshold (in/out).
signal door_crossed(peer_id: int, door_pos: Vector2)
## Host only (IS-104, KR-034): a player opened/closed the back-bell door (`back_bell_door`) or crossed its threshold (in/out, within
## `bell_radius`); one ring per BACK_RING_REPEAT_S (open + step through = one ring). `door_pos` = the door prop's position.
signal back_door_rang(peer_id: int, door_pos: Vector2)

const ZONE_NAMES := {
	CivilianRules.Zone.CUSTOMER: &"CustomerArea",
	CivilianRules.Zone.STAFF: &"StaffArea",
	CivilianRules.Zone.BACKROOM: &"Backroom",
}
## US-042 cover-broken session event (Game HEIST_EVENT_COVER).
const COVER_EVENT := &"cover_broken"
## Back-bell rings closer together than this (s) count as one (IS-104: opening the door and stepping through).
const BACK_RING_REPEAT_S := 1.5
## Prop radius (px; from marker) at which backroom cash counts as "taken".
const CASH_PROP_RADIUS := 32.0
## Prop of a distraction sound: the sound is emitted at the prop position (px margin).
const DISTRACTION_SOURCE_PX := 2.0

var tuning: CivilianTuning
var rules: CivilianRules.Params = null
## Door marker that counts as the bell, and its radius (0 = no bell).
var bell_marker: StringName = &""
var bell_radius: float = 0.0
## Back-bell door (IS-104): Props node whose open/close or threshold crossing by a player emits `back_door_rang` (empty = none). Hooked
## on the first step.
var back_bell_door: StringName = &""
## Test/diagnostics: this value is used instead of RTT (ms) (< 0 = measured from Net).
var rtt_override_ms: int = -1
## Query for customers inside (US-016 cover; func() -> int). Only the population spawner connects it to the owner's senses;
## 0 if empty (no cover).
var customers_query: Callable = Callable()
## Loiter time query (US-016; func(peer_id) -> float): civilian witnesses read the owner's counter (the player's in-shop time must not
## depend on when the witness spawned). If empty, this sense's own counter.
var loiter_query: Callable = Callable()
## US-044: whether window-gazing time is tracked (only the owner enables it; off for civilians and neighbours).
var track_window_stare: bool = false
## Cover query `func(peer_id) -> bool` (test/diagnostics; replaces session events if given).
var cover_query: Callable = Callable()

var _level: Node = null
var _zones: Dictionary = {}
var _loiter: Dictionary = {}
var _inside: Dictionary = {}
## Marker name -> props initially next to it (prop_taken_near).
var _watched: Dictionary = {}
## Back-bell door prop once hooked, and whether the hook was tried (IS-104; once, on the first step).
var _back_door: Node2D = null
var _back_hook_tried: bool = false
## Time left until another back-bell ring counts (s).
var _back_ring_left: float = 0.0
## US-044: window (glass) rects (global) and peer -> continuous gazing time (s).
var _windows: Array[Rect2] = []
var _stare: Dictionary = {}
## US-042/US-043: peers whose cover broke (from the `cover_broken` session event on every peer).
var _cover_lost: Dictionary = {}
## IS-106: tile geometry of the level layout (built on first use; `map_grid`).
var _grid: MapGrid = null


## Level (ancestor with the Level API) and rules.
func setup(level: Node, civilian: CivilianTuning, perception: PerceptionTuning) -> void:
	_level = level
	_grid = null
	tuning = civilian
	rules = civilian.rules_params(perception)
	_zones = zone_rects(level)
	_windows = window_rects(level)
	if not Game.session_event.is_connected(_on_session_event):
		Game.session_event.connect(_on_session_event)


## Tile geometry of a level (IS-106, KR-037): its layout rows (Level `layout()` -> `rows`); an empty grid without a layout.
static func grid_of(level: Node) -> MapGrid:
	var layout: Object = level.call(&"layout") as Object if level != null and level.has_method(&"layout") else null
	var rows: Variant = layout.get(&"rows") if layout != null else null
	return MapGrid.new(rows as PackedStringArray if typeof(rows) == TYPE_PACKED_STRING_ARRAY else PackedStringArray())


## This level's tile geometry (cached).
func map_grid() -> MapGrid:
	if _grid == null:
		_grid = grid_of(_level)
	return _grid


## Facing at `spot` toward the adjacent shelf/counter/wall, `hint` preferred (MapGrid.face_block; the owner's agenda facing resolver,
## IS-106). Without a layout: the hint.
func face_block(spot: Vector2, hint: Vector2) -> Vector2:
	return map_grid().face_block(spot, hint)


## Window (glass) rects (global): rect shapes of bodies in the level's `see_through` group (S4 addendum `Window<n>`).
static func window_rects(level: Node) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if level == null or not level.is_inside_tree():
		return out
	for node: Node in level.get_tree().get_nodes_in_group(PhysicsLayers.SEE_THROUGH_GROUP):
		if not level.is_ancestor_of(node):
			continue
		for child: Node in node.find_children("*", "CollisionShape2D", false, false):
			var cs: CollisionShape2D = child as CollisionShape2D
			var box: RectangleShape2D = cs.shape as RectangleShape2D
			if box != null:
				var size: Vector2 = box.size * cs.global_scale.abs()
				out.append(Rect2(cs.global_position - size * 0.5, size))
	return out


## Whether cover (US-042) is tracked: heist running (Game knows cover state). If not, everyone counts as "broken" (old behaviour:
## neighbour chases everyone; test scenes with no cover events).
func cover_known() -> bool:
	return Game.cover_state() != -1


## Whether the player's cover is intact (US-043; false if no heist).
func cover_intact(peer_id: int) -> bool:
	if cover_query.is_valid():
		return bool(cover_query.call(peer_id))
	return cover_known() and not _cover_lost.has(peer_id)


func _on_session_event(kind: StringName, data: Dictionary) -> void:
	if kind == COVER_EVENT and typeof(data.get("peer")) == TYPE_INT:
		_cover_lost[int(data["peer"])] = true


## Continuous window-gazing time (s; US-044, 0 if not tracked).
func window_stare_of(peer_id: int) -> float:
	return float(_stare.get(peer_id, 0.0))


## Zone rects (global): Zone -> Array[Rect2]. Empty if the zone is missing (everywhere counts as outside).
static func zone_rects(level: Node) -> Dictionary:
	var out: Dictionary = {}
	if level == null or not level.has_method(&"zone"):
		return out
	for z: CivilianRules.Zone in ZONE_NAMES:
		var area: Area2D = level.call(&"zone", ZONE_NAMES[z]) as Area2D
		if area == null:
			continue
		var rects: Array[Rect2] = []
		for node: Node in area.find_children("*", "CollisionShape2D", false, false):
			var cs: CollisionShape2D = node as CollisionShape2D
			var box: RectangleShape2D = cs.shape as RectangleShape2D
			if box != null:
				var size: Vector2 = box.size * cs.global_scale.abs()
				rects.append(Rect2(cs.global_position - size * 0.5, size))
		out[z] = rects
	return out


## One step: players' zones, loiter time, front-door and back-bell door crossing.
func step(delta: float) -> void:
	if not _back_hook_tried and not back_bell_door.is_empty():
		_back_hook_tried = true
		_hook_back_door()
	_back_ring_left = maxf(_back_ring_left - maxf(delta, 0.0), 0.0)
	var door: Vector2 = marker_position(bell_marker)
	var back: Vector2 = _back_door.global_position if is_instance_valid(_back_door) else Vector2.INF
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if not node.has_method(&"interaction_position"):
			continue
		var peer_id: int = node.get_multiplayer_authority()
		var pos: Vector2 = position_of(node as Node2D)
		var inside: bool = CivilianRules.is_inside(zone_of(pos))
		var was: Variant = _inside.get(peer_id)
		if inside:
			_loiter[peer_id] = float(_loiter.get(peer_id, 0.0)) + maxf(delta, 0.0)
		elif was != null and bool(was):
			_loiter[peer_id] = 0.0  # leaving the shop resets loitering (US-010, GDD §9.3)
		_inside[peer_id] = inside
		if track_window_stare:
			_stare[peer_id] = (float(_stare.get(peer_id, 0.0)) + maxf(delta, 0.0)) \
				if not inside and _is_staring(node as Node2D, pos) else 0.0
		if was != null and bool(was) != inside and door.is_finite() and bell_radius > 0.0 \
				and pos.distance_to(door) <= bell_radius:
			door_crossed.emit(peer_id, door)
		if was != null and bool(was) != inside and back.is_finite() and bell_radius > 0.0 \
				and pos.distance_to(back) <= bell_radius:
			_ring_back(peer_id)


## Back-bell door (IS-104): connects the prop's Interactable `completed` (host only; every completion opens or closes the door).
func _hook_back_door() -> void:
	if _level == null or not _level.has_method(&"props_root"):
		return
	var props: Node = _level.call(&"props_root") as Node
	var door: Node2D = props.get_node_or_null(NodePath(String(back_bell_door))) as Node2D if props != null else null
	var item: Interactable = door.get_node_or_null(^"Interactable") as Interactable if door != null else null
	if item == null:
		return
	_back_door = door
	item.completed.connect(_on_back_door_used)


## NPC completions (peer 0: an NPC closing the door behind it) do not ring.
func _on_back_door_used(peer_id: int) -> void:
	if peer_id != 0:
		_ring_back(peer_id)


func _ring_back(peer_id: int) -> void:
	if _back_ring_left > 0.0 or not is_instance_valid(_back_door):
		return
	_back_ring_left = BACK_RING_REPEAT_S
	back_door_rang.emit(peer_id, _back_door.global_position)


## Whether gazing through a window (US-044): within `outside_stare_px` of a window, look (`look_dir`) toward it, slow.
func _is_staring(target: Node2D, pos: Vector2) -> bool:
	if target == null or _windows.is_empty() or tuning == null:
		return false
	var vel: Variant = target.get(&"velocity")
	if vel is Vector2 and (vel as Vector2).length() > tuning.outside_stare_max_speed:
		return false
	var look_v: Variant = target.get(&"look_dir")
	if not look_v is Vector2 or (look_v as Vector2).is_zero_approx():
		return false
	var look: Vector2 = (look_v as Vector2).normalized()
	for r: Rect2 in _windows:
		var nearest := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
		var to: Vector2 = nearest - pos
		if to.length() > tuning.outside_stare_px:
			continue
		var dir: Vector2 = (r.get_center() - pos).normalized() if to.is_zero_approx() else to.normalized()
		if look.dot(dir) >= tuning.outside_stare_dot:
			return true
	return false


## Customers inside (US-016 cover and discovery; 0 if no query).
func customers_inside() -> int:
	return int(customers_query.call()) if customers_query.is_valid() else 0


func zone_of(pos: Vector2) -> CivilianRules.Zone:
	return CivilianRules.zone_at(pos, _zones)


func loiter_time(peer_id: int) -> float:
	if loiter_query.is_valid():
		return float(loiter_query.call(peer_id))
	return float(_loiter.get(peer_id, 0.0))


## Resets the loiter counter (US-010 BUY).
func reset_loiter(peer_id: int) -> void:
	_loiter[peer_id] = 0.0


## Dump (US-010 `loiter_s`): peer (string) -> in-shop time (s, 0.1 step).
func loiter_dump() -> Dictionary:
	var out: Dictionary = {}
	for peer_id: int in _loiter:
		out[str(peer_id)] = snappedf(float(_loiter[peer_id]), 0.1)
	return out


## Source of a distraction sound (US-010): the prop at `pos` offering `distraction_peer(kind)`; null if none.
func distraction_source(pos: Vector2) -> Node2D:
	if _level == null or not _level.has_method(&"props_root"):
		return null
	var props: Node = _level.call(&"props_root") as Node
	if props == null:
		return null
	for child: Node in props.get_children():
		var prop: Node2D = child as Node2D
		if prop == null or not prop.has_method(&"distraction_peer"):
			continue
		if prop.global_position.distance_to(pos) <= DISTRACTION_SOURCE_PX:
			return prop
	return null


## Target's current context.
func context_for(target: Node) -> CivilianRules.Context:
	var ctx := CivilianRules.Context.new()
	var peer_id: int = target.get_multiplayer_authority()
	ctx.zone = zone_of(position_of(target as Node2D))
	ctx.stance = Perception.stance_of(target)
	ctx.interaction = interaction_of(peer_id)
	ctx.carrying_bag = target.has_method(&"is_carrying_bag") and bool(target.call(&"is_carrying_bag"))
	ctx.alert_level = Game.alert_level()
	ctx.loiter_time = loiter_time(peer_id)
	ctx.customers_inside = customers_inside()
	ctx.window_stare = window_stare_of(peer_id)
	return ctx


## Perception's `factor_query`: a held/caught player is 0 (not a target).
func factor_for(target: Node) -> float:
	if target.has_method(&"is_free") and not bool(target.call(&"is_free")):
		return 0.0
	return CivilianRules.factor(rules, context_for(target))


func behaviour_for(target: Node) -> CivilianRules.Behaviour:
	return CivilianRules.behaviour(rules, context_for(target))


## Kind of interaction the player is running (host's `busy_by`).
func interaction_of(peer_id: int) -> CivilianRules.Interaction:
	var item: Interactable = Interactable.held_by(get_tree(), peer_id)
	if item == null or item.innocent:
		return CivilianRules.Interaction.NONE
	var def: Variant = item.get_parent().get(&"def") if item.get_parent() != null else null
	if def is PropDef and (def as PropDef).cash_value > 0:
		return CivilianRules.Interaction.CASH
	return CivilianRules.Interaction.TAMPER if item.hold_time > 0.0 else CivilianRules.Interaction.NONE


## That peer's player from the `interaction_actors` group (null if none).
func player(peer_id: int) -> Node2D:
	if peer_id == 0:
		return null
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == peer_id and node is Node2D:
			return node as Node2D
	return null


## Latest host-known position (S7); the drawn position if none.
static func position_of(target: Node2D) -> Vector2:
	if target == null:
		return Vector2.INF
	if target.has_method(&"interaction_position"):
		var pos: Variant = target.call(&"interaction_position")
		if pos is Vector2:
			return pos
	return target.global_position


## ON-03: for contact decisions the position is advanced along velocity by min(RTT/2, cap) (on the host RTT is that peer's ping).
func predicted(target: Node2D, cap_sec: float) -> Vector2:
	if target == null:
		return Vector2.INF
	var vel: Variant = target.get(&"velocity")
	var velocity: Vector2 = vel if vel is Vector2 else Vector2.ZERO
	var rtt: int = rtt_of(target.get_multiplayer_authority())
	return CivilianRules.predicted_position(position_of(target), velocity, float(rtt), cap_sec)


## RTT from the host to that peer (ms; 0 if unknown).
func rtt_of(peer_id: int) -> int:
	if rtt_override_ms >= 0:
		return rtt_override_ms
	return maxi(Net.get_ping_ms(peer_id), 0) if Net.is_online() else 0


## Marker position (global); INF if missing.
func marker_position(marker_name: StringName) -> Vector2:
	if _level == null or marker_name.is_empty() or not _level.has_method(&"marker"):
		return Vector2.INF
	var node: Node2D = _level.call(&"marker", marker_name) as Node2D
	return node.global_position if node != null else Vector2.INF


## Names of an ordered marker sequence (`<prefix>1..N`; Level `marker_sequence`; US-016 street route, window spots).
func marker_names(prefix: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _level == null or prefix.is_empty() or not _level.has_method(&"marker_sequence"):
		return out
	for node: Variant in _level.call(&"marker_sequence", prefix):
		if node is Node:
			out.append(StringName((node as Node).name))
	return out


## Rects of the interior (customer, staff, backroom zones; global; US-016 look through the window).
func inside_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for z: Variant in _zones:
		for r: Rect2 in _zones[z]:
			out.append(r)
	return out


## Agenda resolver: positions of the `<name>1..N` sequence if present, else the single marker.
func marker_positions(marker_name: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _level == null:
		return out
	if _level.has_method(&"marker_sequence"):
		for node: Variant in _level.call(&"marker_sequence", marker_name):
			if node is Node2D:
				out.append((node as Node2D).global_position)
	if out.is_empty():
		var single: Vector2 = marker_position(marker_name)
		if single.is_finite():
			out.append(single)
	return out


## Whether a prop that started next to the marker was taken (backroom cash): a bag (US-012 Bag, duck typing `is_carried()`) is carried
## or moved; for other props a bool `taken`/`emptied` field. Props are remembered as the ones next to the marker on the first query
## (a carried bag moves away from the marker).
func prop_taken_near(marker_name: StringName) -> bool:
	var at: Vector2 = marker_position(marker_name)
	if not at.is_finite():
		return false
	if not _watched.has(marker_name):
		_watched[marker_name] = _props_near(at)
	for prop: Node2D in _watched[marker_name]:
		if not is_instance_valid(prop):
			continue
		if prop.has_method(&"is_carried"):
			if bool(prop.call(&"is_carried")) or prop.global_position.distance_to(at) > CASH_PROP_RADIUS:
				return true
			continue
		for flag: StringName in [&"taken", &"emptied"]:
			var v: Variant = prop.get(flag) if flag in prop else null
			if v is bool and bool(v):
				return true
	return false


func _props_near(at: Vector2) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if _level == null or not _level.has_method(&"props_root"):
		return out
	var props: Node = _level.call(&"props_root") as Node
	if props == null:
		return out
	for child: Node in props.get_children():
		var prop: Node2D = child as Node2D
		if prop != null and prop.global_position.distance_to(at) <= CASH_PROP_RADIUS:
			out.append(prop)
	return out


## Detection record (AC8; muhafiz-davranisi §4): band, mode, light, "?" and detection time, RTT, distance, behaviour;
## `flagged` = possibly caused by network latency (t_detect - t_question < 0.5 + RTT).
func detection_record(peer_id: int, obs: Perception.Observation, observer: Vector2, t_question: float,
		t_detect: float) -> Dictionary:
	var target: Node2D = player(peer_id)
	var rtt_ms: int = rtt_of(peer_id)
	var record := {
		"peer": peer_id,
		"t_question": t_question,
		"t_detect": t_detect,
		"rtt_ms": rtt_ms,
		"band": -1,
		"mode": -1,
		"lit": true,
		"dist_px": -1.0,
		"behaviour": &"",
		"zone": &"",
	}
	if obs != null:
		record["band"] = int(obs.band)
		record["mode"] = int(obs.stance)
		record["lit"] = not obs.in_dark
		record["dist_px"] = observer.distance_to(obs.position)
	if target != null:
		record["behaviour"] = CivilianRules.behaviour_name(behaviour_for(target))
		record["zone"] = CivilianRules.zone_name(zone_of(position_of(target)))
	record["flagged"] = t_question < 0.0 or t_detect - t_question < 0.5 + rtt_ms / 1000.0
	return record
