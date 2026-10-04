class_name Perception
extends Node2D
## Perception component (US-006 AC2; S2, S11, §4, KR-019): child node of an NPC (guard, camera, civilian later). Vision cone + line of
## sight -> per-target visibility and suspicion fill. Rules live in core/ (`PerceptionRules`); here only the physics query and reading
## target state.
## - Position: this node's global position; look direction `facing` (global, unit). The brain writes it directly or turns it with
##   `turn_toward()` within the turn cap (tuning).
## - Targets: players in the `Interactable.ACTOR_GROUP` (`interaction_actors`) group. Identity = the node's authoritative peer; position =
##   `interaction_position()` (latest host-known, S7); movement mode = `net_mode` (synchronizer's latest, not the remote copy's ~100 ms
##   delayed interpolated `move_mode`), else `move_mode`, else walk (PlayerMotion.Mode).
## - Line of sight: ray on world (1) + vision_block (6); **bodies** in the `see_through` group (US-007: each `Window*` is a separate body,
##   S4 addendum) are passed, shelves and walls block (K1). The group works at body level only: a grouped shape on a shared body still
##   blocks. Player and NPC bodies are not in the mask.
## - Dark: `dark_query` (Callable(pos: Vector2) -> bool) is asked if given; otherwise everywhere is lit (no dark zone in levels yet).
## - Civilian addition (US-008, additive; defaults leave guard behaviour unchanged): if `factor_query` (Callable(target: Node) -> float)
##   is given, the civilian behaviour factor replaces the mode factor (CivilianRules; darkness still overrides); `set_cone()` overrides the
##   observer cone (civilian 50 deg / 224 px, narrows on the phone); `set_hysteresis()` widens the cone for a target already seen (50 deg /
##   224 -> 53 deg / 238 px; no flicker at the cone edge).
## - Meaningful on the host only (S2): the `Suspicion` component calls `observe()` on the host only; this node does nothing on its own.

## Observer kind: selects the cone settings.
enum Observer { GUARD, CAMERA }

const TUNING_PATH := "res://data/npc/perception_tuning.tres"
## Body group that lets sight through (S4/S11 addendum; US-007 puts windows in this group).
const SEE_THROUGH_GROUP := PhysicsLayers.SEE_THROUGH_GROUP
## Physics layers that block sight: world (1) and vision_block (6) (architecture §4).
const SIGHT_MASK := PhysicsLayers.SIGHT_MASK
## Maximum see-through obstacles skipped on one ray (infinite-loop guard).
const MAX_SEE_THROUGH := 8


## One target's observation this frame.
class Observation:
	extends RefCounted
	var peer_id: int = 0
	var position: Vector2 = Vector2.ZERO
	var band: PerceptionRules.Band = PerceptionRules.Band.NONE
	## Whether line of sight is clear (not queried outside the cone: false).
	var line_clear: bool = false
	var stance: PerceptionRules.Stance = PerceptionRules.Stance.WALK
	var in_dark: bool = false
	## Suspicion fill (units/s); 0 = not seen.
	var rate: float = 0.0
	## State factor used (mode or `factor_query`; dark_factor in the dark).
	var factor: float = 0.0


@export var tuning: PerceptionTuning
@export var observer: Observer = Observer.GUARD
## Global look direction (unit).
@export var facing: Vector2 = Vector2.RIGHT
## Dark-zone query: func(pos: Vector2) -> bool. Lit if empty.
var dark_query: Callable = Callable()
## Civilian behaviour factor (US-008): func(target: Node) -> float; mode factor (guard) if empty.
var factor_query: Callable = Callable()

var _params: PerceptionRules.Params = null
## Widened cone for targets being seen (null if no hysteresis).
var _wide: PerceptionRules.Params = null
## Cone override (0 = tuning) and hysteresis margins.
var _cone_half_angle: float = 0.0
var _cone_range: float = 0.0
var _hyst_angle: float = 0.0
var _hyst_range: float = 0.0
## Arm reach (px; 0 = off; IS-098): 360 deg near band, see `set_arm_reach`.
var _arm_reach: float = 0.0
## peer_id -> whether in cone with clear line of sight at the last observation (hysteresis).
var _inside: Dictionary = {}


func _ready() -> void:
	refresh()


## Core perception settings from tuning (cone by observer kind).
static func params_for(source: PerceptionTuning, kind: Observer) -> PerceptionRules.Params:
	var p := PerceptionRules.Params.new()
	match kind:
		Observer.CAMERA:
			p.half_angle_deg = source.camera_half_angle_deg
			p.view_range = source.camera_view_range
		_:
			p.half_angle_deg = source.guard_half_angle_deg
			p.view_range = source.guard_view_range
	p.near_ratio = source.near_ratio
	p.near_factor = source.near_factor
	p.far_factor = source.far_factor
	p.base_fill = source.base_fill_per_sec
	p.sprint_factor = source.sprint_factor
	p.walk_factor = source.walk_factor
	p.sneak_factor = source.sneak_factor
	p.dark_factor = source.dark_factor
	return p


## Current core settings (`refresh()` when tuning or observer kind changes).
func params() -> PerceptionRules.Params:
	if _params == null:
		refresh()
	return _params


func refresh() -> void:
	if tuning == null:
		push_error("Perception: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PerceptionTuning
	_params = params_for(tuning, observer)
	if _cone_half_angle > 0.0:
		_params.half_angle_deg = _cone_half_angle
	if _cone_range > 0.0:
		_params.view_range = _cone_range
	_params.reach_px = _arm_reach
	_wide = null
	if _hyst_angle > 0.0 or _hyst_range > 0.0:
		_wide = params_for(tuning, observer)
		_wide.half_angle_deg = _params.half_angle_deg + _hyst_angle
		_wide.view_range = _params.view_range + _hyst_range
		_wide.reach_px = _arm_reach


## Overrides the observer cone (half angle degrees, range px; 0 = the tuning cone).
func set_cone(half_angle_deg: float, view_range: float) -> void:
	if is_equal_approx(half_angle_deg, _cone_half_angle) and is_equal_approx(view_range, _cone_range) \
			and _params != null:
		return
	_cone_half_angle = maxf(half_angle_deg, 0.0)
	_cone_range = maxf(view_range, 0.0)
	refresh()


## Cone edge hysteresis: the cone widens by `angle_deg` / `range_px` for a target being seen (0 = none).
func set_hysteresis(angle_deg: float, range_px: float) -> void:
	_hyst_angle = maxf(angle_deg, 0.0)
	_hyst_range = maxf(range_px, 0.0)
	refresh()


## Arm reach (IS-098, KR-031 addendum; owner only, from `owner_tuning.arm_reach_px`): a target within `px` is in the near band in
## every direction (no cone condition; line of sight still required). 0 = off (default: civilians, chaser unchanged).
func set_arm_reach(px: float) -> void:
	_arm_reach = maxf(px, 0.0)
	refresh()


func arm_reach() -> float:
	return _arm_reach


## Whether the target was seen at the last observation (cone + line of sight; hysteresis input).
func was_seen(peer_id: int) -> bool:
	return bool(_inside.get(peer_id, false))


## Turns the look toward `direction` within the turn cap (tuning, degrees/s).
func turn_toward(direction: Vector2, delta: float) -> void:
	if tuning == null:
		refresh()
	facing = PerceptionRules.turn_toward(facing, direction, tuning.max_turn_deg_per_sec, delta)


## Observation of all targets: peer_id -> Observation. Does physics queries (on the host, called in the physics step).
func observe() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if not node.has_method(&"interaction_position"):
			continue
		var obs: Observation = observe_target(node)
		if obs != null:
			out[obs.peer_id] = obs
	return out


## Observation of one target (null if its position cannot be read).
func observe_target(target: Node) -> Observation:
	var pos: Variant = target.call(&"interaction_position")
	if not pos is Vector2 or not (pos as Vector2).is_finite():
		return null
	var p: PerceptionRules.Params = params()
	var obs := Observation.new()
	obs.peer_id = target.get_multiplayer_authority()
	obs.position = pos
	obs.stance = stance_of(target)
	var cone: PerceptionRules.Params = _wide if _wide != null and was_seen(obs.peer_id) else p
	obs.band = PerceptionRules.band(cone, global_position, facing, obs.position)
	if obs.band != PerceptionRules.Band.NONE and cone != p:
		# Hysteresis only on the cone's outer limit: the near/far band limit is unchanged.
		var near_limit: float = p.view_range * p.near_ratio + PerceptionRules.EPSILON
		var near: bool = global_position.distance_to(obs.position) <= near_limit \
			or PerceptionRules.in_reach(p, global_position, obs.position)
		obs.band = PerceptionRules.Band.NEAR if near else PerceptionRules.Band.FAR
	if obs.band != PerceptionRules.Band.NONE:
		obs.line_clear = has_line_of_sight(global_position, obs.position)
		obs.in_dark = is_dark(obs.position)
	if factor_query.is_valid():
		obs.factor = p.dark_factor if obs.in_dark else maxf(float(factor_query.call(target)), 0.0)
		var seen: bool = obs.line_clear and obs.band != PerceptionRules.Band.NONE
		obs.rate = p.base_fill * PerceptionRules.band_factor(p, obs.band) * obs.factor if seen else 0.0
	else:
		obs.factor = PerceptionRules.stance_factor(p, obs.stance, obs.in_dark)
		obs.rate = PerceptionRules.fill_rate(p, obs.band, obs.stance, obs.in_dark, obs.line_clear)
	_inside[obs.peer_id] = obs.line_clear and obs.band != PerceptionRules.Band.NONE
	return obs


## Target's perception state: player mode (`net_mode`, else `move_mode`; PlayerMotion.Mode) -> Stance; walk if none.
static func stance_of(target: Node) -> PerceptionRules.Stance:
	var mode: Variant = target.get(&"net_mode")
	if typeof(mode) != TYPE_INT:
		mode = target.get(&"move_mode")
	if typeof(mode) != TYPE_INT:
		return PerceptionRules.Stance.WALK
	match int(mode):
		PlayerMotion.Mode.SPRINT:
			return PerceptionRules.Stance.SPRINT
		PlayerMotion.Mode.SNEAK:
			return PerceptionRules.Stance.SNEAK
	return PerceptionRules.Stance.WALK


func is_dark(pos: Vector2) -> bool:
	if not dark_query.is_valid():
		return false
	return bool(dark_query.call(pos))


## Whether line of sight is clear from `from` to `to` (world + vision_block block; `see_through` and `low_obstacle` bodies
## (PhysicsLayers.passes_sight: glass, counter - IS-098) are excluded and the ray
## re-cast from the start - no continuation point is computed, so a wall adjacent to a window cannot be skipped).
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var exclude: Array[RID] = []
	for _i: int in MAX_SEE_THROUGH + 1:
		var query := PhysicsRayQueryParameters2D.create(from, to, SIGHT_MASK, exclude)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Node = hit.get("collider") as Node
		if collider != null and PhysicsLayers.passes_sight(collider.get_groups()):
			exclude.append(hit["rid"] as RID)
			continue
		return false
	return false
