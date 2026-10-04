class_name PopulationTuning
extends Resource
## Venue population profile (US-016 AC1-AC5; GDD §9.2 table; mimari.md S10 tuning-file pattern). Single source is `data/npc/population.tres`; defaults here are neutral (interval 0 = role off).
## Read by the population spawner (`entities/npc/population.gd`) and the civilian brain (`entities/npc/civilian/brain_civilian.gd`); rules in `core/population_rules.gd`. Starting numbers are tuned by playtest (KR-021 temporary).

@export_group("Üretim")
## Seed (same seed -> same arrival times and plans, I6).
@export var population_seed: int = 0
## NPC cap (owner + civilians + neighbour) and the space reserved for the neighbour.
@export_range(0, 16) var max_npcs: int = 0
@export_range(0, 6) var neighbour_reserve: int = 0
## From this alert level on no new civilians arrive and customers inside flee (0 = never).
@export_range(0, 5) var pause_alert_level: int = 0

@export_group("Müşteri")
## First arrival [min, max] s; then interval +/- jitter (s; 0 = no customers).
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_first_min: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_first_max: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_interval: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_jitter: float = 0.0
## Max customers at once.
@export_range(0, 6) var customer_max: int = 0
## Stay [min, max] s; shelf spot count [min, max] and time per spot [min, max] s.
@export_range(0.0, 600.0, 0.5, "suffix:s") var stay_min_sec: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var stay_max_sec: float = 0.0
@export_range(0, 5) var shop_spots_min: int = 1
@export_range(0, 5) var shop_spots_max: int = 1
@export_range(0.0, 120.0, 0.5, "suffix:s") var shop_min_sec: float = 0.0
@export_range(0.0, 120.0, 0.5, "suffix:s") var shop_max_sec: float = 0.0
## Walking margin (s) for checking whether two shelf spots fit in the stay plan.
@export_range(0.0, 120.0, 0.5, "suffix:s") var walk_margin_sec: float = 0.0
## Max wait in the queue for service (s; then gives up and leaves).
@export_range(0.0, 120.0, 0.5, "suffix:s") var queue_wait_sec: float = 0.0
## Walking speed (px/s).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var customer_speed: float = 0.0
## Markers: street spawn/exit points, front door, shelf spot and queue prefixes, the marker looked at in the queue.
@export var customer_spawn_marker: StringName = &""
@export var customer_exit_marker: StringName = &""
@export var front_door_marker: StringName = &""
@export var shop_prefix: StringName = &""
@export var queue_prefix: StringName = &""
@export var queue_look_marker: StringName = &""
## View cone: half angle (degrees), range (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var customer_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var customer_view_range: float = 0.0

@export_group("Yoldan geçen")
## Arrival interval +/- jitter (s; 0 = no passers-by) and max on the street.
@export_range(0.0, 600.0, 0.5, "suffix:s") var passerby_interval: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var passerby_jitter: float = 0.0
@export_range(0, 6) var passerby_max: int = 0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var passerby_speed: float = 0.0
## Chance of looking inside at each window pane, and look time (s).
@export_range(0.0, 1.0, 0.01) var look_chance: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var look_sec: float = 0.0
## Route and window-front marker prefixes.
@export var route_prefix: StringName = &""
@export var window_prefix: StringName = &""
## View cone (sees through glass): half angle (degrees), range (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var passerby_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var passerby_view_range: float = 0.0

@export_group("Tanık")
## Stance after "?": returns to its business this long after dropping below the threshold (s).
@export_range(0.0, 10.0, 0.05, "suffix:s") var watch_release_sec: float = 0.0
## Seeing the owner: line of sight + this range (px).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var owner_sight_range: float = 0.0
## Telling the owner: walking speed, telling distance (px), min / max time (s) and suspicion added to the owner's.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var tell_speed: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var tell_reach: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var tell_min_sec: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var tell_max_sec: float = 0.0
@export_range(0.0, 100.0, 1.0) var tell_suspicion: float = 0.0
## Flee speed (px/s).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var flee_speed: float = 0.0

@export_group("Dönüşüm")
## When the owner shouts, passers-by within this radius (px; from the owner's position) turn into neighbours (0 = none).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var convert_radius: float = 0.0


## Core settings (`PopulationRules.Params`). `window_count` = number of window-front markers; `serve_sec` = owner's service time.
func rules_params(window_count: int, serve_sec: float) -> PopulationRules.Params:
	var p := PopulationRules.Params.new()
	p.customer_first_min = customer_first_min
	p.customer_first_max = customer_first_max
	p.customer_interval = customer_interval
	p.customer_jitter = customer_jitter
	p.customer_max = customer_max
	p.stay_min = stay_min_sec
	p.stay_max = stay_max_sec
	p.min_spots = shop_spots_min
	p.max_spots = shop_spots_max
	p.shop_min = shop_min_sec
	p.shop_max = shop_max_sec
	p.serve_sec = serve_sec
	p.walk_margin_sec = walk_margin_sec
	p.passerby_interval = passerby_interval
	p.passerby_jitter = passerby_jitter
	p.passerby_max = passerby_max
	p.look_chance = look_chance
	p.look_sec = look_sec
	p.window_count = window_count
	p.max_npcs = max_npcs
	p.reserve = neighbour_reserve
	p.pause_alert_level = pause_alert_level
	return p
