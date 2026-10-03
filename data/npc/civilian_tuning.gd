class_name CivilianTuning
extends Resource
## Civilian observer tuning (US-008; GDD §6.1 civilian factor table, §9.3; mimari.md S10 tuning-file pattern). Single source is `data/npc/civilian_tuning.tres`; defaults here are neutral.
## The maths lives in `CivilianRules` (core/, node-free); base fill, bands, thresholds and the player-favouring slack come from US-006 `perception_tuning.tres`. Starting numbers are tuned by playtest (KR-021 temporary).

@export_group("Koni")
## Civilian view cone: half angle (degrees) and range (px); near band via perception_tuning.near_ratio.
@export_range(0.0, 180.0, 0.5, "suffix:°") var half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var view_range: float = 0.0
## Cone edge hysteresis (AC8): for a target already seen the cone widens by this much (50°/224 -> 53°/238 px).
@export_range(0.0, 45.0, 0.5, "suffix:°") var hysteresis_angle_deg: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var hysteresis_range: float = 0.0

@export_group("Çarpan tablosu")
## Seconds in the customer zone treated as innocent; then the loiter factor.
@export_range(0.0, 600.0, 1.0, "suffix:s") var loiter_grace_sec: float = 0.0
@export_range(0.0, 10.0, 0.05) var loiter_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var sneak_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var sprint_factor: float = 0.0
## Staff side / back room / "staff only" door.
@export_range(0.0, 10.0, 0.05) var staff_factor: float = 0.0
## Carrying a bag, picking a lock.
@export_range(0.0, 10.0, 0.05) var bag_or_lock_factor: float = 0.0
## Register or cash interaction (while held).
@export_range(0.0, 10.0, 0.05) var cash_factor: float = 0.0
## Everyone after a shout (alert >= alarm_level).
@export_range(0.0, 10.0, 0.05) var alarm_factor: float = 0.0
@export_range(0, 5) var alarm_level: int = 0
## Decay while seen but innocent (factor 0) (units/s); when unseen perception_tuning.decay_per_sec.
@export_range(0.0, 1000.0, 0.5, "suffix:/s") var innocent_decay_per_sec: float = 0.0
## Cover (US-016, GDD §9.2): fill factor for players in the owner's customer zone while >= 1 customer is inside
## (staff side and register rows unaffected); 1 = no cover.
@export_range(0.0, 1.0, 0.05) var cover_factor: float = 1.0

@export_group("Vitrinden bakma")
## US-044: a player standing outside within `outside_stare_px` of the window, looking at it (cosine >= `outside_stare_dot`), slower than `outside_stare_max_speed`;
## after `outside_stare_grace_sec` the factor is `outside_stare_factor` (owner's context only; the owner must see through the glass by line of sight and cone).
## With this row suspicion stops at `outside_stare_cap`: the owner does not shout, asks from the door.
@export_range(0.0, 60.0, 0.5, "suffix:s") var outside_stare_grace_sec: float = 0.0
@export_range(0.0, 5.0, 0.01) var outside_stare_factor: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var outside_stare_px: float = 0.0
@export_range(-1.0, 1.0, 0.05) var outside_stare_dot: float = 0.7
@export_range(0.0, 500.0, 1.0, "suffix:px/s") var outside_stare_max_speed: float = 40.0
@export_range(0.0, 100.0, 1.0) var outside_stare_cap: float = 90.0

@export_group("Gösterge ve temas")
## The "?" bubble fades when the meter falls this far below the threshold (client, ON-04).
@export_range(0.0, 50.0, 0.5) var bubble_hysteresis: float = 0.0
## Hold/catch: reach (px) and uninterrupted contact time (s).
@export_range(0.0, 256.0, 1.0, "suffix:px") var contact_reach: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var contact_time: float = 0.0
## ON-03: cap on leading the player position along velocity (s; limited by RTT/2).
@export_range(0.0, 1.0, 0.01, "suffix:s") var lead_cap_sec: float = 0.0


## Core factor table; thresholds come from the perception tuning.
func rules_params(perception: PerceptionTuning) -> CivilianRules.Params:
	var p := CivilianRules.Params.new()
	p.loiter_grace = loiter_grace_sec
	p.loiter_factor = loiter_factor
	p.sneak_factor = sneak_factor
	p.sprint_factor = sprint_factor
	p.staff_factor = staff_factor
	p.bag_or_lock_factor = bag_or_lock_factor
	p.cash_factor = cash_factor
	p.alarm_factor = alarm_factor
	p.alarm_level = alarm_level
	p.innocent_decay = innocent_decay_per_sec
	p.bubble_hysteresis = bubble_hysteresis
	p.cover_factor = cover_factor
	p.window_stare_grace = outside_stare_grace_sec
	p.window_stare_factor = outside_stare_factor
	if perception != null:
		p.notice_at = perception.notice_threshold
		p.detect_at = perception.detect_threshold
	return p
