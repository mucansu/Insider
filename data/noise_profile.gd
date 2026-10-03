class_name NoiseProfile
extends Resource
## Noise tuning (US-009; mimari.md S8, S10 tuning-file pattern). Single source is `data/noise_profile.tres` (walk 0, sneak 0, sprint 120, door 160, register 90, intimidate 140 px);
## defaults here are neutral. Rules are node-free in `core/noise_rules.gd`. Kind names are the StringNames sent over the network.

const PATH := "res://data/noise_profile.tres"

const KIND_WALK := &"walk"
const KIND_SNEAK := &"sneak"
const KIND_RUN := &"run"
const KIND_DOOR := &"door"
const KIND_REGISTER := &"register"
const KIND_INTIMIDATE := &"intimidate"
## Owner agenda sounds (US-011b AC6; GDD §6.5: without sight, "where is the owner" is answered by listening): phone call, shelf tidying, door bell.
## Born from the NPC brain on the host; the owner's own hearing ignores them.
const KIND_PHONE := &"phone"
const KIND_SHELF := &"shelf"
const KIND_BELL := &"bell"
## Kinds a client may produce for itself (S2: a client is authoritative only over its own movement).
## Result sounds such as door, register and intimidate are born on the host.
const MOVEMENT_KINDS: Array[StringName] = [KIND_WALK, KIND_SNEAK, KIND_RUN]

## Per-step radii (px); 0 = silent.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var walk_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var sneak_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var sprint_radius: float = 0.0
## Event radii (px).
@export_range(0.0, 1000.0, 1.0, "suffix:px") var door_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var register_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var intimidate_radius: float = 0.0
## Owner agenda sounds (px; US-011b): phone 160, shelf tidying 96, door bell 160. Cadence lives in the agenda task
## (`AgendaTask.noise_interval_sec`).
@export_range(0.0, 1000.0, 1.0, "suffix:px") var phone_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var shelf_radius: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var bell_radius: float = 0.0
## Minimum time between step sounds (s; S8 "at most ~3 Hz").
@export_range(0.0, 5.0, 0.01, "suffix:s") var step_interval: float = 0.0
## Below this real speed (px/s) no step sound is made (sprint key held but standing still or pushing a wall).
## Kept below every mode's speed (sneak 70): only the radius decides a mode's silence.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var step_min_speed: float = 0.0
## Sound interval while emptying the register (s; the first sound comes after this too); one more sound on completion.
@export_range(0.0, 10.0, 0.05, "suffix:s") var register_interval: float = 0.0
## Radius multiplier without line of sight (behind a wall) (S8: 0.5).
@export_range(0.0, 1.0, 0.05) var wall_factor: float = 1.0

static var _default: NoiseProfile = null


## `data/noise_profile.tres` (loaded once per process).
static func load_default() -> NoiseProfile:
	if _default == null:
		_default = load(PATH) as NoiseProfile
		if _default == null:
			push_error("NoiseProfile: %s yüklenemedi" % PATH)
			_default = NoiseProfile.new()
	return _default


## Radius of the kind (px); an unknown kind is silent (0).
func radius_for(kind: StringName) -> float:
	match kind:
		KIND_WALK:
			return walk_radius
		KIND_SNEAK:
			return sneak_radius
		KIND_RUN:
			return sprint_radius
		KIND_DOOR:
			return door_radius
		KIND_REGISTER:
			return register_radius
		KIND_INTIMIDATE:
			return intimidate_radius
		KIND_PHONE:
			return phone_radius
		KIND_SHELF:
			return shelf_radius
		KIND_BELL:
			return bell_radius
	return 0.0


static func is_movement_kind(kind: StringName) -> bool:
	return MOVEMENT_KINDS.has(kind)
