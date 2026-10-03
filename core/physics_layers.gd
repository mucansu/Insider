class_name PhysicsLayers
extends RefCounted
## Single source for physics layer bits, masks and game group names (IS-037; mimari.md §4, S4/S7/S8/S11 addenda).
## Constants only; node-free (KR-003). Layer bits match the project.godot `layer_names/2d_physics/layer_N` names: constant name = upper-cased layer name, value = 1 << (N - 1) (checked by tests/unit/test_smoke.gd).
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
## Group of interaction components (Interactable) (S7).
const INTERACTABLES_GROUP := &"interactables"
## Group of actors that can interact (S7; the player adds itself and exposes `interaction_position()`).
const ACTORS_GROUP := &"interaction_actors"
## Group of noise listeners (S8; NoiseBus calls `hear_noise`).
const NOISE_LISTENER_GROUP := &"noise_listener"
