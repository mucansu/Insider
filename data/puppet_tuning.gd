class_name PuppetTuning
extends Resource
## Character puppet tuning (US-014; GDD §14.1 timing table, KR-017; mimari S10 tuning-file pattern).
## Single source is `data/puppet_tuning.tres` (starting values are the docs/tasarim/kukla-denemesi.html defaults; tuned by the user's slider experiment). Defaults here are neutral.
## The maths is in PuppetRig (node-free), drawing in Puppet. Puppet geometry, bounce, hop, scarf and dust are in "puppet units" (x `puppet_scale` = px; the trial scene draws at scale 2, so its px = 2 units);
## movement speeds, stride lengths, teleport distance and marker anchor height are world px. Spring ranges are bounded for stability (PuppetSpring also guards with sub-steps).

@export_group("Yay (ezilme / eğilme)")
## Body spring frequency (Hz; 1.5-10: low = oscillating, high = agile).
@export_range(1.5, 10.0, 0.1, "suffix:Hz") var spring_frequency: float = 0.0
## Damping of the squash-stretch spring.
@export_range(0.05, 1.0, 0.01) var squash_damping: float = 0.0
## Damping of the lean spring.
@export_range(0.05, 1.0, 0.01) var lean_damping: float = 0.0
## Lean spring frequency = spring_frequency x this ratio.
@export_range(0.25, 1.5, 0.01) var lean_frequency_ratio: float = 0.0

@export_group("Çarpanlar (kaydırıcılar)")
## Bounce multiplier (0-2): step bounce and the squash impulse of footfall.
@export_range(0.0, 2.0, 0.1) var bounce: float = 0.0
## Exaggeration multiplier (0-2): lean, take-off dip and squash-stretch.
@export_range(0.0, 2.0, 0.1) var exaggeration: float = 0.0

@export_group("Yumuşatma")
## Visual speed approaching the observed speed (exponential, 1/s): while moving and when stopping.
@export_range(0.0, 50.0, 0.1) var speed_smoothing_start: float = 0.0
@export_range(0.0, 50.0, 0.1) var speed_smoothing_stop: float = 0.0
## Smoothing of acceleration measurement (1/s).
@export_range(0.0, 50.0, 0.1) var accel_smoothing: float = 0.0
## Turning (body and look together; 1/s).
@export_range(0.0, 50.0, 0.1) var turn_smoothing: float = 0.0
## At this speed (px/s) counts as "full movement"; below it the pose blends toward idle.
@export_range(1.0, 500.0, 1.0, "suffix:px/s") var moving_reference_speed: float = 0.0

@export_group("Kipler (sız / yürü / koş)")
## Per-mode values as Vector3: x = sneak, y = walk, z = sprint.
## Stride length (px; cadence = speed / stride length).
@export var stride: Vector3 = Vector3.ZERO
## Bob amplitude (puppet units).
@export var bob_amplitude: Vector3 = Vector3.ZERO
## Body (silhouette) scale; sneaking must read crouched and low.
@export var body_scale: Vector3 = Vector3.ZERO
## Mode factor for the footfall squash impulse.
@export var footfall_factor: Vector3 = Vector3.ZERO
## Foot swing amplitude (puppet units).
@export var foot_swing: Vector3 = Vector3.ZERO
## Body scale while interacting.
@export_range(0.0, 2.0, 0.01) var interact_scale: float = 0.0
## Footfall squash impulse (added to the spring velocity).
@export_range(0.0, 10.0, 0.05) var footfall_impulse: float = 0.0
## Minimum visual speed for a step to count (px/s).
@export_range(0.0, 200.0, 1.0, "suffix:px/s") var footfall_min_speed: float = 0.0

@export_group("Eğilme")
## Lean = velocity.x / lean_reference_speed x lean_gain (rad); x lean_sprint_factor when sprinting; capped at +/- lean_max.
@export_range(0.0, 1.0, 0.01, "suffix:rad") var lean_gain: float = 0.0
@export_range(1.0, 1000.0, 1.0, "suffix:px/s") var lean_reference_speed: float = 0.0
@export_range(0.0, 3.0, 0.05) var lean_sprint_factor: float = 0.0
@export_range(0.0, 1.0, 0.01, "suffix:rad") var lean_max: float = 0.0
## Extra forward overshoot on acceleration / overshoot and spring-back when stopping (rad / (px/s²)).
@export var lean_accel_gain: float = 0.0
## Take-off dip: share of forward acceleration subtracted from the squash target (1 / (px/s²)).
@export var squash_accel_gain: float = 0.0

@export_group("Bekleme")
## Breathing period (s) and scale amplitude (idle only).
@export_range(0.0, 10.0, 0.01, "suffix:s") var breath_period: float = 0.0
@export_range(0.0, 0.2, 0.001) var breath_amount: float = 0.0
## Blink duration and interval (s).
@export_range(0.0, 1.0, 0.01, "suffix:s") var blink_duration: float = 0.0
@export var blink_interval: Vector2 = Vector2.ZERO
## Look-around interval (s), angle range (+/- rad) and chance of looking forward again.
@export var look_interval: Vector2 = Vector2.ZERO
@export_range(0.0, 3.14, 0.01, "suffix:rad") var look_range: float = 0.0
@export_range(0.0, 1.0, 0.01) var look_forward_chance: float = 0.0
## Chance of looking at a teammate while looking around (if a friend is known; when not looking forward).
@export_range(0.0, 1.0, 0.01) var look_friend_chance: float = 0.0

@export_group("Tepki")
## Bubble pop time (easeOutBack) and "!" shake time (s).
@export_range(0.0, 2.0, 0.01, "suffix:s") var bubble_pop_time: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var alert_shake_time: float = 0.0
## "!" shake amplitude (px, at the start; fades over the duration).
@export_range(0.0, 20.0, 0.1, "suffix:px") var alert_shake_amplitude: float = 0.0
## Hop on noticing (units/s) and gravity (units/s²; airtime ~2 x speed / gravity s); squash impulse on landing.
@export_range(0.0, 1000.0, 1.0, "suffix:u/s") var jump_speed: float = 0.0
@export_range(0.0, 5000.0, 1.0, "suffix:u/s²") var gravity: float = 0.0
@export_range(0.0, 10.0, 0.05) var land_impulse: float = 0.0
## Eye widening on noticing (velocity added to the eye scale spring).
@export_range(0.0, 20.0, 0.1) var alert_eye_impulse: float = 0.0

@export_group("Atkı ve toz")
@export_range(2, 12, 1) var scarf_segments: int = 0
@export_range(0.0, 1.0, 0.01) var scarf_damping: float = 0.0
## Scarf gravity (units/s²).
@export_range(0.0, 10000.0, 10.0, "suffix:u/s²") var scarf_gravity: float = 0.0
## Scarf segment length (puppet units).
@export_range(0.0, 20.0, 0.1) var scarf_segment_length: float = 0.0
## Dust particle count and lifetime (s) on a sprint step.
@export_range(0, 10, 1) var dust_per_step: int = 0
@export var dust_life: Vector2 = Vector2.ZERO

@export_group("Ölçek ve bağlantı")
## Puppet unit -> px (GDD: total ~44 units x puppet scale).
@export_range(0.1, 4.0, 0.05) var puppet_scale: float = 0.0
## A position jump longer than this in one frame counts as a teleport: the animation is rebuilt silently (px).
@export_range(1.0, 1000.0, 1.0, "suffix:px") var teleport_distance: float = 0.0
## Fixed anchor height (px, up from body centre) for game-info markers (name tag, bubble, interaction badge);
## the animation does not move it.
@export_range(0.0, 200.0, 1.0, "suffix:px") var marker_anchor_height: float = 0.0

@export_group("Görünüm")
## Player puppet looks in join-slot order (placeholder until roles/loadouts arrive).
@export var player_looks: Array[PuppetLook] = []
