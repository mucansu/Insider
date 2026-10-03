class_name PlayerTuning
extends Resource
## Player movement and network tuning (US-004; S10 tuning-file pattern). Single source of values is `data/player_tuning.tres`
## (walk 140, sneak 70, sprint 220 px/s ...); defaults here are neutral, the player scene binds that file. Computation is in
## PlayerMotion (node-free), interpolation in SnapshotBuffer.

## Full speed of the movement modes (px/s; US-004 AC2).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var walk_speed: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var sneak_speed: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var sprint_speed: float = 0.0
## Acceleration toward the target speed while input is held (px/s^2).
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var acceleration: float = 0.0
## Braking when input is released or switching to a slower target (px/s^2).
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var deceleration: float = 0.0
## How far behind remote copies are drawn (s; GDD §12 "100 ms interpolation buffer", S2).
@export_range(0.0, 1.0, 0.005, "suffix:s") var interpolation_delay: float = 0.0
## Zoom of the local player's camera.
@export_range(0.25, 4.0, 0.05) var camera_zoom: float = 1.0
