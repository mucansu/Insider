class_name PerceptionTuning
extends Resource
## Perception and suspicion tuning (US-006 AC3; mimari.md S10 tuning-file pattern, S11, KR-019). Single source is `data/npc/perception_tuning.tres`; defaults here are neutral.
## The maths is in core/ (PerceptionRules, SuspicionMeter); the Perception/Suspicion components read this resource and convert it to core value objects. Starting numbers are tuned by playtest (KR-019 temporary).

@export_group("Koni")
## Guard view cone: half angle (degrees) and range (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var guard_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var guard_view_range: float = 0.0
## Camera view cone (a camera = a stationary observer, same perception code).
@export_range(0.0, 180.0, 0.5, "suffix:°") var camera_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var camera_view_range: float = 0.0
## Near band limit: ratio of the range (R/2 -> 0.5).
@export_range(0.0, 1.0, 0.01) var near_ratio: float = 0.0
## Band factors.
@export_range(0.0, 10.0, 0.05) var near_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var far_factor: float = 0.0
## Observer turn-rate cap (degrees/s).
@export_range(0.0, 1080.0, 1.0, "suffix:°/s") var max_turn_deg_per_sec: float = 0.0

@export_group("Dolum")
## Base fill (units/s): fill = base x band x state.
@export_range(0.0, 1000.0, 0.5, "suffix:/s") var base_fill_per_sec: float = 0.0
## State factors (movement mode); a dark zone overrides the mode.
@export_range(0.0, 10.0, 0.05) var sprint_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var walk_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var sneak_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var dark_factor: float = 0.0
## Decay while unseen (units/s).
@export_range(0.0, 1000.0, 0.5, "suffix:/s") var decay_per_sec: float = 0.0

@export_group("Eşikler")
## "?" (observer looks), inspect, detect (0-100).
@export_range(0.0, 100.0, 1.0) var notice_threshold: float = 0.0
@export_range(0.0, 100.0, 1.0) var investigate_threshold: float = 0.0
@export_range(0.0, 100.0, 1.0) var detect_threshold: float = 0.0
## Player-favouring slack (s; S2, GDD §12).
@export_range(0.0, 2.0, 0.01, "suffix:s") var grace_sec: float = 0.0
## Short gap that does not break a seen sequence (s): sight loss shorter than this neither resets the slack nor starts decay.
@export_range(0.0, 2.0, 0.01, "suffix:s") var gap_tolerance_sec: float = 0.0
