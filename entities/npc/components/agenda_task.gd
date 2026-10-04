class_name AgendaTask
extends Resource
## Agenda task (US-008 AC1; GDD §9.3 owner attention loop): {marker, duration range, look direction, cone narrowing}. The `Agenda`
## component orders the list with a seeded RNG; the single source of numbers is the NPC tuning file (e.g. sub-resources of
## `data/npc/owner_tuning.tres`). Time counts after the NPC reaches the marker.

## Task name (task_changed signal, dump; e.g. &"counter", &"restock").
@export var name: StringName = &""
## Level marker (S4 Markers). If the prefix is a sequence (`RestockSpot` -> RestockSpot1..N) one is chosen each time.
@export var marker: StringName = &""
@export_range(0.0, 600.0, 0.5, "suffix:s") var min_sec: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var max_sec: float = 0.0
## Look direction after arrival (global, unit; zero = keep arrival direction).
@export var facing: Vector2 = Vector2.ZERO
## Cone half angle (degrees); 0 = NPC default cone (phone: narrows).
@export_range(0.0, 180.0, 0.5, "suffix:°") var half_angle_deg: float = 0.0
## Home task (counter): the agenda alternates home <-> other tasks.
@export var home: bool = false
## Whether the door bell interrupts this task (the phone does not).
@export var bell_interrupts: bool = true
## Agenda sound while at the task point (US-011b; NoiseProfile kind, e.g. &"phone", &"shelf"; empty = silent) and its
## interval (s; first sound also this long after arrival). Radius from NoiseProfile.
@export var noise_kind: StringName = &""
@export_range(0.0, 60.0, 0.1, "suffix:s") var noise_interval_sec: float = 0.0
