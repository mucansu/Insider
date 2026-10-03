class_name Suspicion
extends Node
## Suspicion component (US-006 AC2; S2, S11, GDD §6.1, KR-019): child of an NPC; runs a per-player 0-100 meter (`SuspicionMeter`, core/)
## from the sibling `Perception`'s observation. Runs on the host only (S2): each physics step `perception.observe()` -> meters ->
## `threshold_reached(peer_id, level)` for upward crossings (1 "?", 2 investigate, 3 detect; emitted on the host only).
## Replicated summary (host-authoritative MultiplayerSynchronizer, on change): `max_level` (level of the highest meter) and
## `focus_direction` (unit direction from the observer to that target's last seen position; ZERO at level 0; an unseen target's current
## position does not leak). The client visual reads only these ("?"/"!" indicator, head turn). Settings from perception.tuning
## (data/npc/perception_tuning.tres).
## Civilian addition (US-008, additive; defaults leave guard behaviour unchanged):
## - If `innocent_decay_per_sec` >= 0, the meter of a target in line of sight acting innocently (fill 0) drains at this rate
##   (GDD §6.1: 10/s; 20/s from tuning when unseen).
## - `apply_delta(peer_id, delta)` host API: changes a meter directly (US-010 STALL -40, PULL +100 to the rescuer); upward crossings emit
##   `threshold_reached`.
## - `latch_level`: the brain locks the summary level after detection (replicated `max_level` does not flicker during brief hiding).
## - `last_observations()`: last step's observations (for brain target choice and dump).

## Host only: the `level` threshold of `peer_id` was crossed upward.
signal threshold_reached(peer_id: int, level: int)

enum Level { CALM, NOTICE, INVESTIGATE, DETECT }

const SYNC_NAME := "SuspicionSync"
const SYNC_INTERVAL := 0.1
## Step of the replicated `focus_direction` components (S11 addendum: ON_CHANGE continuous values are rounded to 1/16).
const FOCUS_STEP := 1.0 / 16.0

@export var perception: Perception

## Replicated summary state (host writes).
var max_level: int = Level.CALM
var focus_direction: Vector2 = Vector2.ZERO
## Drain rate while seen and innocent (units/s); < 0 = none (drains as when unseen).
var innocent_decay_per_sec: float = -1.0
## Lower bound of the summary level (brain writes; 0 = no lock).
var latch_level: int = Level.CALM

## peer_id -> SuspicionMeter
var _meters: Dictionary = {}
## peer_id -> last seen position (global; last observation with fill > 0)
var _last_seen: Dictionary = {}
var _params: SuspicionMeter.Params = null
var _innocent: SuspicionMeter.Params = null
var _observations: Dictionary = {}


func _ready() -> void:
	if perception == null:
		push_error("Suspicion: perception atanmamış")
	add_child(_make_sync())


func _physics_process(delta: float) -> void:
	if perception == null or not multiplayer.is_server():
		return
	tick(delta)


## Core meter settings from tuning.
static func params_for(source: PerceptionTuning) -> SuspicionMeter.Params:
	var p := SuspicionMeter.Params.new()
	p.decay_per_sec = source.decay_per_sec
	p.thresholds = PackedFloat32Array([source.notice_threshold, source.investigate_threshold,
		source.detect_threshold])
	p.grace = source.grace_sec
	p.gap_tolerance = source.gap_tolerance_sec
	return p


## One step (host): observation -> meters -> threshold signals -> summary. Meters of targets not in the observation (left) drain
## and are removed at zero.
func tick(delta: float) -> void:
	if _params == null:
		if perception.tuning == null:
			perception.refresh()
		_params = params_for(perception.tuning)
	if innocent_decay_per_sec >= 0.0 and (_innocent == null or _innocent.decay_per_sec != innocent_decay_per_sec):
		_innocent = params_for(perception.tuning)
		_innocent.decay_per_sec = innocent_decay_per_sec
	var observations: Dictionary = perception.observe()
	_observations = observations
	var reached: Array = []
	for peer_id: int in observations:
		var obs: Perception.Observation = observations[peer_id]
		var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
		if meter == null:
			meter = SuspicionMeter.new()
			_meters[peer_id] = meter
		var innocent_seen: bool = obs.rate <= 0.0 and innocent_decay_per_sec >= 0.0 and obs.line_clear \
				and obs.band != PerceptionRules.Band.NONE and not obs.in_dark
		if obs.rate > 0.0 or innocent_seen:
			_last_seen[peer_id] = obs.position  # civilian: innocent but the seen target's spot is still known (query)
		var p: SuspicionMeter.Params = _params
		if innocent_seen:
			p = _innocent
		for l: int in meter.step(p, obs.rate, delta):
			reached.append([peer_id, l])
	for peer_id: int in _meters.keys():
		if observations.has(peer_id):
			continue
		var gone: SuspicionMeter = _meters[peer_id]
		gone.step(_params, 0.0, delta)
		if gone.value <= 0.0:
			_meters.erase(peer_id)
			_last_seen.erase(peer_id)
	_update_summary()
	for item: Array in reached:
		threshold_reached.emit(int(item[0]), int(item[1]))


func value_of(peer_id: int) -> float:
	var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
	return meter.value if meter != null else 0.0


func level_of(peer_id: int) -> int:
	var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
	return meter.level if meter != null else Level.CALM


## Host API (US-008 AC4): changes a meter by `delta` (0..MAX). Upward crossings emit signals;
## the last seen position does not change (suspicion given unseen leaks no position).
func apply_delta(peer_id: int, delta: float) -> void:
	if perception == null or not multiplayer.is_server():
		return
	if _params == null:
		if perception.tuning == null:
			perception.refresh()
		_params = params_for(perception.tuning)
	var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
	if meter == null:
		meter = SuspicionMeter.new()
		_meters[peer_id] = meter
	meter.value = clampf(meter.value + delta, 0.0, SuspicionMeter.MAX_VALUE)
	var new_level: int = SuspicionMeter.level_for(_params, meter.value)
	var reached: PackedInt32Array = PackedInt32Array()
	for l: int in range(meter.level + 1, new_level + 1):
		reached.append(l)
	meter.level = new_level
	_update_summary()
	for l: int in reached:
		threshold_reached.emit(peer_id, l)


## Host API (US-016, additive): reports from outside the last seen position of a target that has a meter (where a witness said).
## Ignored if there is no meter (position does not leak).
func hint_position(peer_id: int, pos: Vector2) -> void:
	if _meters.has(peer_id) and pos.is_finite():
		_last_seen[peer_id] = pos


## Removes the target's meter (e.g. a caught player is no longer a target).
func forget(peer_id: int) -> void:
	_meters.erase(peer_id)
	_last_seen.erase(peer_id)
	_update_summary()


## Targets that have a meter.
func peers() -> Array[int]:
	var out: Array[int] = []
	for peer_id: int in _meters:
		out.append(peer_id)
	return out


## Last step's observations: peer_id -> Perception.Observation.
func last_observations() -> Dictionary:
	return _observations


## Target's last seen position (global); INF if never seen.
func last_seen_position(peer_id: int) -> Vector2:
	return _last_seen.get(peer_id, Vector2.INF)


## Resets all meters (e.g. when the brain switches state after detection).
func clear() -> void:
	_meters.clear()
	_last_seen.clear()
	max_level = Level.CALM
	focus_direction = Vector2.ZERO


func _update_summary() -> void:
	var best_peer: int = 0
	var best_value: float = 0.0
	for peer_id: int in _meters:
		var meter: SuspicionMeter = _meters[peer_id]
		if meter.value > best_value:
			best_value = meter.value
			best_peer = peer_id
	var top: SuspicionMeter = _meters.get(best_peer) as SuspicionMeter
	max_level = maxi(top.level if top != null else Level.CALM, latch_level)
	focus_direction = Vector2.ZERO
	if max_level > Level.CALM and _last_seen.has(best_peer):
		# S11 addendum (US-008): a continuous value is rounded to 1/16 steps before ON_CHANGE replication (so it does not produce a reliable
		# delta every frame).
		var dir: Vector2 = ((_last_seen[best_peer] as Vector2) - perception.global_position).normalized()
		focus_direction = dir.snapped(Vector2.ONE * FOCUS_STEP)


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:max_level", ".:focus_direction"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.delta_interval = SYNC_INTERVAL
	sync.replication_config = config
	return sync
