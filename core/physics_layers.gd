class_name PhysicsLayers
extends RefCounted
## Single source for physics layer bits, masks and game group names (IS-037; mimari.md §4, S4/S7/S8/S11 addenda).
## Constants (plus one group-membership helper); node-free (KR-003). Layer bits match the project.godot `layer_names/2d_physics/layer_N` names: constant name = upper-cased layer name, value = 1 << (N - 1) (checked by tests/unit/test_smoke.gd).
## Other scripts do not write layer numbers or group-name strings; they take them from here (scanned by tests/unit/test_physics_layers.gd). Layer values in .tscn files stay data; tests check them separately.

## Layer bits (§4).
const WORLD := 1
const PLAYERS := 2
const NPCS := 4
const INTERACTABLES := 8
const TRIGGERS := 16
const VISION_BLOCK := 32

## Layers that block sight and sound: world + vision_block (S11 Phase 2 addendum, S8). Player and NPC bodies excluded.
const SIGHT_MASK := WORLD | VISION_BLOCK

## Group of bodies that let sight (and sound) through (S4/S11 addendum; US-007 windows, each `Window*` a separate body).
const SEE_THROUGH_GROUP := &"see_through"
## Low obstacle class (IS-098, KR-031 addendum): bodies that stop walking but let sight and sound through for everyone (counter:
## each `Counter*` a separate body on the world layer). Same ray rule as glass; a separate group so window-only logic (window gazing,
## WindowLook) does not see counters.
const LOW_OBSTACLE_GROUP := &"low_obstacle"
## Body groups a sight/sound ray passes (glass + low obstacles); the group works at body level only.
const PASS_SIGHT_GROUPS: Array[StringName] = [SEE_THROUGH_GROUP, LOW_OBSTACLE_GROUP]
## Group of interaction components (Interactable) (S7).
const INTERACTABLES_GROUP := &"interactables"
## Group of actors that can interact (S7; the player adds itself and exposes `interaction_position()`).
const ACTORS_GROUP := &"interaction_actors"
## Group of noise listeners (S8; NoiseBus calls `hear_noise`).
const NOISE_LISTENER_GROUP := &"noise_listener"


## Whether a ray hit on a body with these groups (`get_groups()`) is passed by sight and sound (one of PASS_SIGHT_GROUPS).
static func passes_sight(groups: Array[StringName]) -> bool:
	for group: StringName in PASS_SIGHT_GROUPS:
		if groups.has(group):
			return true
	return false
