class_name Population
extends Node
## Venue population spawner (US-016 AC1/AC5/AC8; GDD §9.2; oyun-yz round 2 #13, #20; S2, S11). Static node under `NPCs` in the level; siblings
## `Owner` (StoreOwner), `StoreAlert` and `PopulationSpawner` (MultiplayerSpawner, spawn_path = NPCs). Only the host spawns/deletes; clients get
## them from the spawner (a late joiner sees existing civilians on join). Timing and plans in `PopulationRules.Schedule` (seeded, deterministic),
## spot reservation in `SpotRegistry`; settings in `data/npc/population.tres`.
## - Spawning: a customer at a street point (`customer_spawn_marker`), shelf spots picked from free ones with the order's dice and held;
##   a passerby at the first point of the street route. Names `Customer<n>` / `Passerby<n>` (n a single counter).
## - Limits: customers inside (active) <= `customer_max`, on the street <= `passerby_max`; total NPCs (owner + civilians + neighbours) +
##   neighbour allowance <= `max_npcs`; no new civilian while alert >= `pause_alert_level`. The alert manager's neighbour waits for room under
##   the cap (`StoreAlert.room_query`).
## - Cover: the owner's senses get the customers-inside count (`CivilianSenses.customers_query`; x0.5 rule in core); civilian witnesses read the
##   owner's loiter counter.
## - Conversion (oyun-yz #20): when the owner shouts (`OwnerBrain.shouted`) passersby within `convert_radius` of the owner are deleted and a
##   neighbour is spawned at the same spot (`StoreAlert.spawn_chaser_at`; NPC count unchanged).
## - Off: `active = false` (fixture; e.g. tests/fixtures/store_a_quiet.tscn, store_a_nopop.tscn) or an inactive owner spawns nothing.
## Dump "population" (S6 addendum): on every peer {npcs: [{name, role, state, events}], names (ordered), seen, events, event_peers}; on the host also
## {customers_inside, customers_spawned, passersby_spawned, served, tells, flees, looks, converted, cancelled, arrivals}.

const CIVILIAN_SCENE := "res://entities/npc/civilian/civilian.tscn"
const TUNING_PATH := "res://data/npc/population.tres"
const DUMP_KEY := "population"
const MAX_EVENTS := 128
const MAX_SEEN := 128

@export var tuning: PopulationTuning
@export var owner_path: NodePath = ^"../Owner"
@export var alert_path: NodePath = ^"../StoreAlert"
@export var spawner_path: NodePath = ^"../PopulationSpawner"
## False: tests drive `step()` by hand (civilians too).
@export var auto_step: bool = true
## False: spawns nothing (fixture).
@export var active: bool = true

## Host: spot registry and timer.
var registry := SpotRegistry.new()
var schedule: PopulationRules.Schedule = null

var _owner: StoreOwner = null
var _alert: StoreAlert = null
var _spawner: MultiplayerSpawner = null
var _scene: PackedScene = null
var _serial: int = 0
## Host: serial number -> order/shelf spots (spawn_function reads).
var _pending: Dictionary = {}
## On every peer: civilian names and events seen (in order).
var _seen: Array[String] = []
var _events: Array[StringName] = []
var _event_peers: Array[int] = []
## Host counters.
var _stats: Dictionary = {"customers_spawned": 0, "passersby_spawned": 0, "served": 0, "tells": 0, "flees": 0,
	"looks": 0, "converted": 0}


func _ready() -> void:
	if tuning == null:
		tuning = load(TUNING_PATH) as PopulationTuning
	_owner = get_node_or_null(owner_path) as StoreOwner
	_alert = get_node_or_null(alert_path) as StoreAlert
	_spawner = get_node_or_null(spawner_path) as MultiplayerSpawner
	_scene = load(CIVILIAN_SCENE) as PackedScene
	if _spawner != null:
		_spawner.spawn_function = _spawn_civilian
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, dump_state)
	if not _enabled():
		return
	var windows: int = _owner.senses().marker_names(tuning.window_prefix).size()
	schedule = PopulationRules.Schedule.new(tuning.rules_params(windows, _owner.owner_tuning.customer_sec),
		PopulationRules.schedule_seed(Game.session_seed(), tuning.population_seed))
	_owner.senses().customers_query = customers_inside
	_owner.brain().shouted.connect(_on_owner_shouted)
	if _alert != null:
		_alert.room_query = has_room


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


## One step (host only): timer -> spawn; if driven by hand (auto_step false) civilians are stepped too.
func step(delta: float) -> void:
	if not _enabled():
		return
	for order: PopulationRules.Order in schedule.tick(delta, counts()):
		_spawn(order)
	if not auto_step:
		for civ: Civilian in civilians():
			civ.auto_step = false
			civ.step(delta)


## Current counts (timer input).
func counts() -> PopulationRules.Counts:
	var c := PopulationRules.Counts.new()
	for civ: Civilian in civilians():
		if civ.is_customer():
			c.customers += 1
		else:
			c.passersby += 1
	c.npcs = npc_count()
	c.alert_level = Game.alert_level()
	return c


## All NPCs (active owner + civilians + neighbours; excluding those pending deletion).
func npc_count() -> int:
	var n: int = 0
	var root: Node = get_parent()
	if root == null:
		return 0
	for child: Node in root.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Civilian or child is Chaser:
			n += 1
		elif child is StoreOwner and (child as StoreOwner).active:
			n += 1
	return n


## Whether there is room under the cap (for the alert manager's neighbour; neighbour allowance not included).
func has_room() -> bool:
	return npc_count() < tuning.max_npcs


## Living civilians (in the tree, not pending deletion).
func civilians() -> Array[Civilian]:
	var out: Array[Civilian] = []
	var root: Node = get_parent()
	if root == null:
		return out
	for child: Node in root.get_children():
		if child is Civilian and not child.is_queued_for_deletion():
			out.append(child as Civilian)
	return out


## Customers inside (cover; discovery idle trigger): customers whose zone is inside.
func customers_inside() -> int:
	var n: int = 0
	if _owner == null:
		return 0
	var senses: CivilianSenses = _owner.senses()
	for civ: Civilian in civilians():
		if civ.is_customer() and CivilianRules.is_inside(senses.zone_of(civ.global_position)):
			n += 1
	return n


## Host: holds a free queue spot (order: QueueSpot1, QueueSpot2 ...); empty if none.
func claim_queue(serial: int) -> StringName:
	return registry.claim_first(_spots(tuning.queue_prefix), serial)


## Marker sequence names (`<prefix>1..N`); if there is no sequence and the prefix is a single marker, that one (e.g. a single shelf spot in a fixture).
func _spots(prefix: StringName) -> Array[StringName]:
	var senses: CivilianSenses = _owner.senses()
	var out: Array[StringName] = senses.marker_names(prefix)
	if out.is_empty() and senses.marker_position(prefix).is_finite():
		out.append(prefix)
	return out


## Host: releases the spots a civilian holds.
func release_spots(serial: int) -> void:
	registry.release(serial)


func dump_state() -> Dictionary:
	var rows: Array = []
	var names: Array[String] = []
	for civ: Civilian in civilians():
		rows.append(civ.dump_row())
		names.append(String(civ.name))
	names.sort()
	var out := {
		"active": active,
		"npcs": rows,
		"names": names,
		"seen": _seen.duplicate(),
		"events": _events.duplicate(),
		"event_peers": _event_peers.duplicate(),
	}
	if _host_side() and schedule != null:
		out.merge(_stats.duplicate())
		for civ: Civilian in civilians():
			if civ.brain().served:
				out["served"] = int(out["served"]) + 1  # served, not yet left
		out["customers_inside"] = customers_inside()
		out["cancelled"] = schedule.cancelled.size()
		var arrivals: Array = []
		for o: PopulationRules.Order in schedule.spawned:
			arrivals.append([PopulationRules.role_name(o.role), snappedf(o.at, 0.01)])
		out["arrivals"] = arrivals
	return out


func _spawn(order: PopulationRules.Order) -> void:
	if _spawner == null or _scene == null:
		return
	_serial += 1
	var spots: Array[StringName] = []
	var at: Vector2 = Vector2.INF
	var senses: CivilianSenses = _owner.senses()
	if order.role == PopulationRules.Role.CUSTOMER:
		var free: Array[StringName] = registry.free_of(_spots(tuning.shop_prefix))
		for roll: float in order.picks:
			var spot: StringName = PopulationRules.pick(free, roll)
			if spot.is_empty() or not registry.claim(spot, _serial):
				continue
			free.erase(spot)
			spots.append(spot)
		at = senses.marker_position(tuning.customer_spawn_marker)
		_stats["customers_spawned"] = int(_stats["customers_spawned"]) + 1
	else:
		var route: Array[StringName] = senses.marker_names(tuning.route_prefix)
		at = senses.marker_position(route[0]) if not route.is_empty() else Vector2.INF
		_stats["passersby_spawned"] = int(_stats["passersby_spawned"]) + 1
	if not at.is_finite():
		registry.release(_serial)
		push_warning("Population: doğma işareti yok; sivil üretilmedi")
		return
	_pending[_serial] = {"order": order, "spots": spots}
	var root: Node2D = get_parent() as Node2D
	_spawner.spawn({"n": _serial, "role": int(order.role), "pos": root.to_local(at) if root != null else at})
	_pending.erase(_serial)


## Spawner's spawn_function (in spawn() on the host, when the packet arrives on a client).
func _spawn_civilian(data: Variant) -> Node:
	var d: Dictionary = data if data is Dictionary else {}
	var civ: Civilian = _scene.instantiate() as Civilian
	var n: int = int(d.get("n", 0))
	civ.serial = n
	civ.tuning = tuning  # population profile (a fixture may give its own); same on every peer
	civ.role = int(d.get("role", PopulationRules.Role.CUSTOMER))
	civ.name = "%s%d" % ["Passerby" if civ.role == PopulationRules.Role.PASSERBY else "Customer", n]
	if d.get("pos") is Vector2:
		civ.position = d["pos"]
	if _host_side() and _pending.has(n):
		var p: Dictionary = _pending[n]
		civ.order = p["order"] as PopulationRules.Order
		civ.shop_spots = p["spots"]
		civ.population = self
		civ.store_owner = _owner
		civ.ready.connect(_on_civilian_ready.bind(civ), CONNECT_ONE_SHOT)
	civ.event_raised.connect(_on_civilian_event)
	if _seen.size() < MAX_SEEN:
		_seen.append(String(civ.name))
	return civ


func _on_civilian_ready(civ: Civilian) -> void:
	civ.senses().loiter_query = _owner.senses().loiter_time
	civ.brain().gone.connect(_on_civilian_gone.bind(civ), CONNECT_ONE_SHOT)


func _on_civilian_gone(civ: Civilian) -> void:
	if not is_instance_valid(civ):
		return
	var b: CivilianBrain = civ.brain()
	if b.served:
		_stats["served"] = int(_stats["served"]) + 1
	_stats["looks"] = int(_stats["looks"]) + b.looks
	_despawn(civ)


func _despawn(civ: Civilian) -> void:
	registry.release(civ.serial)
	civ.queue_free()  # spawner deletes on clients too


func _on_civilian_event(_civ: Civilian, kind: StringName, peer_id: int) -> void:
	if _events.size() < MAX_EVENTS:
		_events.append(kind)
		_event_peers.append(peer_id)
	if not _host_side():
		return
	if String(kind).ends_with("_tell"):
		_stats["tells"] = int(_stats["tells"]) + 1
	elif String(kind).ends_with("_flee"):
		_stats["flees"] = int(_stats["flees"]) + 1


## Owner shouted (host): passersby in range turn into neighbours (oyun-yz #20).
func _on_owner_shouted(_late: bool) -> void:
	if _alert == null or tuning.convert_radius <= 0.0:
		return
	var at: Vector2 = _owner.global_position
	for civ: Civilian in civilians():
		if civ.is_customer() or civ.global_position.distance_to(at) > tuning.convert_radius:
			continue
		var pos: Vector2 = civ.global_position
		_stats["looks"] = int(_stats["looks"]) + civ.brain().looks
		_despawn(civ)
		if _alert.spawn_chaser_at(pos, at) != null:
			_stats["converted"] = int(_stats["converted"]) + 1


func _enabled() -> bool:
	return active and _host_side() and tuning != null and _owner != null and _owner.active and _spawner != null


## Host or offline (S2; from Net flags, same pattern as Game).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
