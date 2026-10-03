class_name ContactTuning
extends Resource
## Player-NPC contact and shove tuning (US-037; KR-027; S10 tuning-file pattern). Single source is `data/npc/contact_tuning.tres`; defaults
## here are neutral. The rules live in `ContactRules` (core/, node-free).

const PATH := "res://data/npc/contact_tuning.tres"

@export_group("Temas")
## Circle overlap distance (px; two body radii, S4 character diameter ~24 px).
@export_range(0.0, 128.0, 1.0, "suffix:px") var contact_px: float = 0.0
## Highest alert level counted as calm (contact slowdown and shove costs); above it shoves cost nothing.
@export_range(0, 5) var calm_max_alert: int = 0
## Player speed factor while overlapping an NPC in calm.
@export_range(0.0, 1.0, 0.05) var calm_speed_factor: float = 1.0
## NPC drawing lean away from an overlapping player (px; visual, local).
@export_range(0.0, 32.0, 0.5, "suffix:px") var lean_px: float = 0.0

@export_group("İtme")
## Shove cone half angle around the sprinting player's heading (degrees).
@export_range(0.0, 180.0, 1.0, "suffix:°") var push_half_angle_deg: float = 0.0
## Minimum speed of a sprinting player that can shove (px/s).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var min_push_speed: float = 0.0
## NPC slide distance and duration.
@export_range(0.0, 128.0, 1.0, "suffix:px") var slide_px: float = 0.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var slide_sec: float = 0.0
## NPC stagger from the shove (brain stopped).
@export_range(0.0, 10.0, 0.05, "suffix:s") var stagger_sec: float = 0.0
## The same NPC cannot be shoved again within this.
@export_range(0.0, 10.0, 0.05, "suffix:s") var repush_sec: float = 0.0
## Pusher slowdown: duration and speed factor.
@export_range(0.0, 5.0, 0.01, "suffix:s") var pusher_slow_sec: float = 0.0
@export_range(0.0, 1.0, 0.05) var pusher_speed_factor: float = 1.0

@export_group("Sakin bedel")
## Shove counter window and cap (n).
@export_range(0.0, 120.0, 0.5, "suffix:s") var push_window_sec: float = 0.0
@export_range(1, 10) var push_count_cap: int = 1
## Suspicion per n: shoved NPC and observers with line of sight.
@export_range(0.0, 100.0, 1.0) var pushed_suspicion: float = 0.0
@export_range(0.0, 100.0, 1.0) var observer_suspicion: float = 0.0

@export_group("Kızışmış")
## Chaser stagger and shove immunity (from the shove).
@export_range(0.0, 10.0, 0.05, "suffix:s") var chaser_stagger_sec: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:s") var chaser_immune_sec: float = 0.0
## Chaser rear sector where contact is not a shove (half angle around its back).
@export_range(0.0, 180.0, 1.0, "suffix:°") var back_half_angle_deg: float = 0.0
## Host contact slack in hot alert (S2 tolerance in the player's favour; calm costs get none).
@export_range(0.0, 64.0, 1.0, "suffix:px") var hot_slack_px: float = 0.0

static var _default: ContactTuning = null


static func load_default() -> ContactTuning:
	if _default == null:
		_default = load(PATH) as ContactTuning
		if _default == null:
			push_error("ContactTuning: %s yüklenemedi" % PATH)
			_default = ContactTuning.new()
	return _default


func rules_params() -> ContactRules.Params:
	var p := ContactRules.Params.new()
	p.contact_px = contact_px
	p.calm_max_alert = calm_max_alert
	p.calm_speed_factor = calm_speed_factor
	p.lean_px = lean_px
	p.push_half_angle_deg = push_half_angle_deg
	p.min_push_speed = min_push_speed
	p.slide_px = slide_px
	p.slide_sec = slide_sec
	p.stagger_sec = stagger_sec
	p.repush_sec = repush_sec
	p.pusher_slow_sec = pusher_slow_sec
	p.pusher_speed_factor = pusher_speed_factor
	p.push_window_sec = push_window_sec
	p.push_count_cap = push_count_cap
	p.pushed_suspicion = pushed_suspicion
	p.observer_suspicion = observer_suspicion
	p.chaser_stagger_sec = chaser_stagger_sec
	p.chaser_immune_sec = chaser_immune_sec
	p.back_half_angle_deg = back_half_angle_deg
	p.hot_slack_px = hot_slack_px
	return p
