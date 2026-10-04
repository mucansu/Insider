class_name ChaserTuning
extends Resource
## Neighbourhood chaser tuning (US-008 AC6; GDD §9.3; KR-021; ON-08). Single source is `data/npc/chaser_tuning.tres`; defaults here are neutral.
## Speed is below sprint (220): a sprinting player gains >= 1 tile over 10 tiles in the open (unit test), but gets caught at corners and doors.

## Run speed (px/s) and acceleration (px/s²).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var speed: float = 0.0
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var acceleration: float = 0.0
## Sight: no cone (looks at the wanted person), line of sight + range (px).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var sight_range: float = 0.0
## Seconds to search the last seen position when sight is lost; then waits at the front door.
@export_range(0.0, 120.0, 0.5, "suffix:s") var search_sec: float = 0.0
@export var wait_marker: StringName = &""
