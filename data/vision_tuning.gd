class_name VisionTuning
extends Resource
## Player vision and fog tuning (US-011a AC1; GDD §6.5, KR-022/KR-023; mimari.md S10 tuning-file pattern). Single source is `data/vision_tuning.tres`; defaults here are neutral.
## The maths is in core/ (`VisionGrid`); the fog layer (`FogLayer`, levels/fog) reads this resource and converts it to `VisionGrid.Params`. Starting numbers are tuned by playtest (GDD §6.5 "starting values").

const PATH := "res://data/vision_tuning.tres"

@export_group("Menzil")
## View radius in light (px): NPC range + 1 tile.
@export_range(0.0, 2048.0, 1.0, "suffix:px") var view_radius: float = 0.0
## Radius of a player standing in a dark zone (px; KR-019 binary light).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var dark_radius: float = 0.0
## View-edge fade (visual only, px): the last this-much of the radius slides to the memory tone.
@export_range(0.0, 256.0, 1.0, "suffix:px") var soft_edge_px: float = 0.0

@export_group("Kip")
## Default vision mode (VisionGrid.Mode: 0 peripheral = 360 deg, 1 directional). Host rule; chosen in US-011b/US-011d.
@export_enum("Peripheral", "Directional") var default_mode: int = 0
## Directional mode: sharp cone half angle (degrees; 45 -> 90 deg cone), range = view_radius.
@export_range(0.0, 180.0, 0.5, "suffix:°") var cone_half_angle_deg: float = 0.0
## Directional mode: peripheral zone half angle (degrees; 90 -> 180 deg ahead) and its range (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var peripheral_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var peripheral_radius: float = 0.0
## 360 deg near ring (px): in every mode this distance is visible in every direction (line of sight still required).
@export_range(0.0, 512.0, 1.0, "suffix:px") var near_radius: float = 0.0
## Look turn-rate cap (degrees/s); US-011b applies the look input, here only the number.
@export_range(0.0, 1080.0, 1.0, "suffix:°/s") var max_turn_deg_per_sec: float = 0.0

@export_group("Zamanlama ve hafıza")
## Grid update interval (s).
@export_range(0.01, 1.0, 0.01, "suffix:s") var update_interval_sec: float = 0.1
## A seen tile stays in memory after leaving sight (within a phase; reset when a level loads).
@export var memory_enabled: bool = true
## Tile tone transition (s); instant when reduce motion is on.
@export_range(0.0, 2.0, 0.01, "suffix:s") var transition_sec: float = 0.0
## Tile edge softening (px; visual only).
@export_range(0.0, 32.0, 1.0, "suffix:px") var edge_blur_px: float = 0.0
