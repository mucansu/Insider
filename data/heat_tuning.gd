class_name HeatTuning
extends Resource
## In-session heat/recognition effects (US-052, KR-044; mimari.md S10 tuning-file pattern). Single source is `data/heat_tuning.tres`;
## defaults here are neutral (no effect). Per-map overridable through VenueTuning id `heat` (IS-106). Rules are node-free in
## `SessionHeat` (core/session_heat.gd); readers: StoreAlert (neighbour delay), population spawner (passer-by cap), StoreOwner
## (recognised player's starting suspicion), Game (HUD notice state).

const PATH := "res://data/heat_tuning.tres"

## Session heat at/above which later jobs are hot (0 = never).
@export_range(0, 200) var heat_threshold: int = 0
## Hot: seconds taken off the owner tuning's `neighbour_delay_sec` (never below 0).
@export_range(0.0, 60.0, 0.5, "suffix:s") var neighbour_delay_cut_s: float = 0.0
## Hot: extra passers-by allowed on the street at once (population `passerby_max` + this).
@export_range(0, 6) var passerby_bonus: int = 0
## Recognitions this session needed for the owner's head start (0 = off).
@export_range(0, 10) var recognized_min: int = 0
## Suspicion the owner starts a recognised player at when first seeing them in a new job ("You again?").
@export_range(0.0, 100.0, 1.0) var recognized_start: float = 0.0


## Rule parameters (SessionHeat.Params).
func rules_params() -> SessionHeat.Params:
	var p := SessionHeat.Params.new()
	p.threshold = heat_threshold
	p.neighbour_delay_cut_s = neighbour_delay_cut_s
	p.passerby_bonus = passerby_bonus
	p.recognized_min = recognized_min
	p.recognized_start = recognized_start
	return p
