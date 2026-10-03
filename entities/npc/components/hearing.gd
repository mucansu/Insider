class_name Hearing
extends Node2D
## Hearing component (US-009; S8, S11, KR-018): NPC child node, its position is the ear position. In the `noise_listener` group;
## NoiseBus calls `hear_noise(pos, radius, kind)` on the host for every sound. Runs on the host only: a sound outside the radius casts no
## ray; inside, a physics ray from ear to sound (line of sight, `SightLine`: blocked by world (1) + vision_block (6), `see_through` bodies
## pass; S11 Phase 2 addendum) is cast, and without line of sight the radius shrinks by `NoiseProfile.wall_factor`. Rules live in
## NoiseRules (node-free). On hearing it emits `heard(pos, radius, kind)` with the effective radius after attenuation. Linking to suspicion
## is the observer item's job (US-008); this component only emits the signal.
## Low obstacle (US-010, KR-026; IS-098 KR-031 addendum): the counter is a `low_obstacle` body (S4) that blocks walking but neither sight
## nor sound - the same class rule as glass (PhysicsLayers.passes_sight via SightLine), no shape-name exception here (the owner at the
## counter hears a shelf toppled on the shop floor).
## Corner diffraction (US-010; optional, `corner_spread_px` > 0): if the center ray is blocked, two parallel rays offset +/-`corner_spread_px`
## from the ear are tried; if either is clear there is line of sight (sound grazes a wall corner; a thick wall still blocks). Default 0
## (off); the owner's tuning enables it.
## Own sound (IS-087 AC1): a sound from the NPC's own action (e.g. a door it opened/closed) is wrapped with `ignore_own(pos, kind, action)`;
## while the action runs, that kind of sound at that point is ignored here (host emission is synchronous: NoiseBus listeners are visited in
## the same call). Other NPCs' and players' sounds work as usual.

## Host only.
signal heard(pos: Vector2, radius: float, kind: StringName)

const GROUP := PhysicsLayers.NOISE_LISTENER_GROUP
## Physics layers that block sound: world (1) + vision_block (6) (architecture §4; SightLine).
const BLOCK_MASK := SightLine.MASK
## Bodies in this group (windows, S4 addendum) and in `low_obstacle` (counter, IS-098) do not block sound (SightLine).
const SEE_THROUGH_GROUP := SightLine.SEE_THROUGH_GROUP
## Position margin in the own-sound match (px; the sound is emitted at the source's own position).
const OWN_NOISE_PX := 1.0

@export var profile: NoiseProfile
@export var enabled: bool = true
## Corner diffraction: offset of the parallel rays (px; 0 = off).
@export_range(0.0, 32.0, 0.5, "suffix:px") var corner_spread_px: float = 0.0

var _heard_count: int = 0
var _ignored_own: int = 0
## Ongoing own actions: [position, kind] (inside ignore_own).
var _own: Array[Array] = []


func _ready() -> void:
	if profile == null:
		profile = NoiseProfile.load_default()
	add_to_group(GROUP)


## Called by NoiseBus (host).
func hear_noise(pos: Vector2, radius: float, kind: StringName) -> void:
	if not enabled or not multiplayer.is_server() or not is_inside_tree():
		return
	if is_own(pos, kind):
		_ignored_own += 1
		return
	var distance: float = global_position.distance_to(pos)
	if not NoiseRules.can_hear(distance, radius):
		return
	var effective: float = NoiseRules.effective_radius(radius, has_line_of_sight(pos), profile.wall_factor)
	if not NoiseRules.can_hear(distance, effective):
		return
	_heard_count += 1
	heard.emit(pos, effective, kind)


## Whether there is line of sight from the ear to `to` (SightLine: same ray as vision; the first hit within SOURCE_MARGIN of the source
## is the source's own body and does not block).
func has_line_of_sight(to: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = global_position
	if _ray_clear(space, from, to):
		return true
	if corner_spread_px <= 0.0:
		return false
	var side: Vector2 = (to - from).normalized().orthogonal() * corner_spread_px
	return _ray_clear(space, from + side, to + side) or _ray_clear(space, from - side, to - side)


## One ray: passed bodies (glass, low obstacles - SightLine) do not block, nor does the source's own body (NoiseRules.hit_blocks).
static func _ray_clear(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var hit: Dictionary = SightLine.first_blocker(space, from, to, BLOCK_MASK)
	return hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, to)


## Number of sounds this component heard (diagnostics).
func heard_count() -> int:
	return _heard_count


## Number of sounds ignored as own sound (diagnostics, IS-087).
func ignored_own_count() -> int:
	return _ignored_own


## While `action` runs, a `kind` sound at `pos` is own sound and not heard (IS-087 AC1). Returns `action`'s result.
func ignore_own(pos: Vector2, kind: StringName, action: Callable) -> Variant:
	_own.append([pos, kind])
	var result: Variant = action.call()
	_own.pop_back()
	return result


## Whether this sound belongs to an ongoing own action.
func is_own(pos: Vector2, kind: StringName) -> bool:
	for own: Array in _own:
		if StringName(own[1]) == kind and (own[0] as Vector2).distance_to(pos) <= OWN_NOISE_PX:
			return true
	return false
