class_name OwnerTuning
extends Resource
## Grocery owner tuning (US-008; GDD §9.3 attention loop and reaction chain; mimari.md S10 tuning-file pattern). Single source is `data/npc/owner_tuning.tres`; defaults here are neutral.
## Read by the owner's brain (`brain_owner.gd`) and the grocery alert manager (`store_alert.gd`). Starting numbers are tuned by playtest (KR-021 temporary).

@export_group("Ajanda")
## Agenda seed (same seed -> same task sequence, I6).
@export var agenda_seed: int = 0
## Tasks (home task + window tasks).
@export var tasks: Array[AgendaTask] = []
## Walking speed in the agenda (px/s).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var walk_speed: float = 0.0
## Interior doors the owner closes behind them (Props node name; IS-087 AC2: D) and the delay after passing (s).
## The front door stays open during business hours (not in the list).
@export var close_behind_doors: Array[StringName] = []
@export_range(0.0, 5.0, 0.05, "suffix:s") var close_behind_sec: float = 0.0

@export_group("Kesmeler")
## Door bell (s), customer service (s, US-016), sent to the back room (s, US-010), listening to a sound (s, US-009).
@export_range(0.0, 60.0, 0.1, "suffix:s") var bell_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var customer_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var sent_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var listen_sec: float = 0.0
## Hearing corner diffraction (px; Hearing.corner_spread_px, US-010: the owner at the counter also hears a shelf-end knock-over
## from a sound grazing a wall corner; 0 = off).
@export_range(0.0, 32.0, 0.5, "suffix:px") var hearing_corner_px: float = 0.0
## Arm reach (IS-098, KR-031 addendum): a player this close to the owner is in the near band in every direction (360 deg, no cone
## condition; line of sight still required; Perception.set_arm_reach). 0 = off.
@export_range(0.0, 128.0, 1.0, "suffix:px") var arm_reach_px: float = 0.0
## Radius for counting a front-door pass as a bell (px; from the door marker).
@export_range(0.0, 256.0, 1.0, "suffix:px") var bell_radius: float = 0.0
## Markers for customer service and the back-room interruption.
@export var counter_marker: StringName = &""
@export var backroom_marker: StringName = &""
@export var front_door_marker: StringName = &""

@export_group("Tepki")
## Stance after "?": min / max (s).
@export_range(0.0, 10.0, 0.05, "suffix:s") var look_min_sec: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var look_max_sec: float = 0.0
## Questioning: walking speed, stop distance, wait and longest question.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var question_speed: float = 0.0
@export_range(0.0, 512.0, 1.0, "suffix:px") var question_stop: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var question_wait_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var question_max_sec: float = 0.0
## Shout: noise radius, repeat interval; calm-down time if there is no sight.
@export_range(0.0, 2048.0, 1.0, "suffix:px") var shout_radius: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var shout_repeat_sec: float = 0.0
@export_range(0.0, 600.0, 1.0, "suffix:s") var calm_after_sec: float = 0.0
## Back-room cash marker (US-039 discovery: whether the bag was moved).
@export var cash_marker: StringName = &""

@export_group("Servis ve keşif")
## Look direction during customer service (global; GDD §9.2: turns west) and the "register opens" moment (which second of the service;
## US-039 sale trigger, US-010 BUY uses the same hook).
@export var serve_facing: Vector2 = Vector2.ZERO
@export_range(0.0, 60.0, 0.1, "suffix:s") var register_open_sec: float = 0.0
## Register marker (discovery: register `emptied`).
@export var register_marker: StringName = &""
## Discovery (US-039 AC4): DISCOVER state duration (s; stands still, bubble), then the shout flow.
@export_range(0.0, 10.0, 0.05, "suffix:s") var discover_sec: float = 0.0
## Back-room trigger (AC2): cash check this long after arriving at the back-room task (or being sent there) (s).
@export_range(0.0, 30.0, 0.1, "suffix:s") var backroom_check_sec: float = 0.0
## Back-room task name (AgendaTask.name; forced to the first task on calming down, AC6).
@export var backroom_task: StringName = &""
## Idle trigger (AC3): total time at the counter (ClerkSpot, home task) with an empty register and no customers inside (s;
## 0 = off).
@export_range(0.0, 600.0, 1.0, "suffix:s") var idle_discover_sec: float = 0.0
## Return check (IS-100, KR-032): after being away from the counter (any agenda task or interrupt), the owner looks at the register
## this long after arriving back at ClerkSpot; an emptied register -> DISCOVER (before the service / idle triggers). 0 = off.
@export_range(0.0, 10.0, 0.05, "suffix:s") var return_check_sec: float = 0.0
## SEND return cost (IS-100 AC3, GDD §9.3): when the owner is back at the counter after SEND, the player who sent them (if still free)
## gets this much suspicion. 0 = off.
@export_range(0.0, 100.0, 1.0) var send_return_suspicion: float = 0.0

@export_group("Tutma")
## Chase speed (px/s); hold window first / later (s); stagger after rescue (s) and suspicion on the rescuer.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var hold_speed: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var hold_window_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var hold_window_repeat_sec: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var stagger_sec: float = 0.0
@export_range(0.0, 100.0, 1.0) var rescuer_suspicion: float = 0.0

@export_group("Uyarı ve mahalleli")
## Seconds the owner must stay calm for alert 1 -> 0.
@export_range(0.0, 120.0, 0.5, "suffix:s") var alert_calm_sec: float = 0.0
## Time from the shout to the neighbour coming out (s) and max neighbours.
@export_range(0.0, 120.0, 0.5, "suffix:s") var neighbour_delay_sec: float = 0.0
@export_range(0, 6) var max_neighbours: int = 0
@export var neighbour_marker: StringName = &""
## Neighbour inside (alert 3) -> police timer (s).
@export_range(0.0, 600.0, 1.0, "suffix:s") var police_timer_sec: float = 0.0
## Door markers where a neighbour counts as "entered" and radius (px).
@export var entry_markers: Array[StringName] = []
@export_range(0.0, 256.0, 1.0, "suffix:px") var entry_radius: float = 0.0
