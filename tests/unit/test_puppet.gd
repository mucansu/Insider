extends TestCase
## US-014 puppet maths (PuppetRig, no node): tuning read (GDD §14.1 table), mode -> silhouette scale/crouch mapping, fixed step
## (independent of frame time), no "pop" on teleport, visual overshoot <= 6 px, reduced motion, reaction API, idle (breathing,
## blinking, looking around), start/stop anticipation-follow-through.
## Scene/network side and dependency direction: test_puppet_scene.gd.

const TUNING := "res://data/puppet_tuning.tres"
const DT := 1.0 / 60.0
const RIGHT := Vector2.RIGHT
const SPEEDS := {PuppetRig.Gait.SNEAK: 70.0, PuppetRig.Gait.WALK: 140.0, PuppetRig.Gait.SPRINT: 220.0}


func _tuning() -> PuppetTuning:
	return load(TUNING) as PuppetTuning


func _rig(rng_seed: int = 7) -> PuppetRig:
	var rig := PuppetRig.new(_tuning(), rng_seed)
	rig.update(DT, Vector2.ZERO, Vector2.ZERO, Vector2.DOWN, PuppetRig.Gait.WALK, false)
	return rig


## Runs at a constant speed for `seconds` (position from speed); returns the final position.
func _run(rig: PuppetRig, seconds: float, vel: Vector2, gait: PuppetRig.Gait, dt: float = DT,
		working: bool = false) -> Vector2:
	var pos: Vector2 = rig.target_position
	var facing: Vector2 = vel.normalized() if vel != Vector2.ZERO else rig.target_facing
	for i: int in roundi(seconds / dt):
		pos += vel * dt
		rig.update(dt, pos, vel, facing, gait, working)
	return pos


# --- settings ---

func test_tuning_reads_data_file() -> void:
	var t: PuppetTuning = _tuning()
	if not is_true(t != null, "data/puppet_tuning.tres PuppetTuning olmalı"):
		return
	# GDD §14.1 timing table (kukla-denemesi.html defaults).
	near(t.spring_frequency, 4.5, 0.001)
	near(t.squash_damping, 0.32, 0.001)
	near(t.lean_damping, 0.42, 0.001)
	near(t.bounce, 1.0, 0.001)
	near(t.exaggeration, 1.0, 0.001)
	near(t.speed_smoothing_start, 10.0, 0.001)
	near(t.speed_smoothing_stop, 13.0, 0.001)
	near(t.turn_smoothing, 9.0, 0.001)
	eq(t.stride, Vector3(13, 20, 30), "adım boyu sız/yürü/koş")
	eq(t.bob_amplitude, Vector3(0.9, 2.2, 3.4), "sekme genliği")
	eq(t.body_scale, Vector3(0.84, 1.0, 1.07), "gövde ölçeği")
	near(t.interact_scale, 0.95, 0.001, "etkileşimde 0,95")
	near(t.footfall_impulse, 0.9, 0.001)
	eq(t.footfall_factor, Vector3(0.45, 1.0, 1.4), "adım darbesi: sızma ×0,45, koşu ×1,4")
	near(t.lean_gain / t.lean_reference_speed, 0.16 / 220.0, 1e-6, "eğilme hız/220 × 0,16")
	near(t.lean_sprint_factor, 1.35, 0.001)
	near(t.lean_max, 0.38, 0.001, "tavan ±0,38 rad")
	near(t.breath_period, 2.73, 0.01, "nefes ~2,7 sn")
	near(t.breath_amount, 0.024, 0.0001, "±%2,4")
	near(t.blink_duration, 0.13, 0.001)
	eq(t.blink_interval, Vector2(2.0, 5.5))
	eq(t.look_interval, Vector2(1.4, 3.6))
	near(t.look_range, 1.2, 0.001)
	near(t.look_forward_chance, 0.35, 0.001)
	near(t.bubble_pop_time, 0.2, 0.001)
	near(t.alert_shake_time, 0.4, 0.001)
	near(2.0 * t.jump_speed / t.gravity, 0.35, 0.01, "sıçramada ~0,35 sn havada")
	eq(t.scarf_segments, 6)
	near(t.scarf_damping, 0.92, 0.001)
	eq(t.dust_per_step, 3)
	eq(t.dust_life, Vector2(0.45, 0.7))
	is_true(t.player_looks.size() >= 4, "dört oyuncu yuvası için görünüm")
	# Source of values is the file: script defaults are neutral.
	var blank := PuppetTuning.new()
	eq(blank.spring_frequency, 0.0)
	eq(blank.body_scale, Vector3.ZERO)
	eq(blank.scarf_segments, 0)


# --- mode -> silhouette ---

func test_gait_to_silhouette_mapping() -> void:
	var t: PuppetTuning = _tuning()
	near(PuppetBody.target_squash(t, PuppetRig.Gait.SNEAK, 1.0, false, 1.0), 0.84, 1e-6, "sızma çömelik")
	near(PuppetBody.target_squash(t, PuppetRig.Gait.WALK, 1.0, false, 1.0), 1.0, 1e-6, "yürüme dik")
	near(PuppetBody.target_squash(t, PuppetRig.Gait.SPRINT, 1.0, false, 1.0), 1.07, 1e-6, "koşu uzamış")
	near(PuppetBody.target_squash(t, PuppetRig.Gait.SPRINT, 1.0, true, 1.0), 0.95, 1e-6, "etkileşimde 0,95")
	near(PuppetBody.target_squash(t, PuppetRig.Gait.SNEAK, 0.0, false, 1.0), 1.0, 1e-6, "dururken dik")
	near(PuppetBody.target_squash(t, PuppetRig.Gait.SNEAK, 1.0, false, 2.0), 0.68, 1e-6, "abartı ölçekler")
	eq(PlayerVisual.gait_for(PlayerMotion.Mode.SNEAK), PuppetRig.Gait.SNEAK)
	eq(PlayerVisual.gait_for(PlayerMotion.Mode.WALK), PuppetRig.Gait.WALK)
	eq(PlayerVisual.gait_for(PlayerMotion.Mode.SPRINT), PuppetRig.Gait.SPRINT)


func test_settled_silhouette_per_gait() -> void:
	var height := {}
	var lean := {}
	for gait: PuppetRig.Gait in [PuppetRig.Gait.SNEAK, PuppetRig.Gait.WALK, PuppetRig.Gait.SPRINT]:
		var rig: PuppetRig = _rig()
		var vel: Vector2 = RIGHT * float(SPEEDS[gait])
		_run(rig, 1.5, vel, gait)
		var sum: float = 0.0
		var lean_sum: float = 0.0
		var n: int = 60
		for i: int in n:
			_run(rig, DT, vel, gait)
			sum += rig.squash_y()
			lean_sum += rig.lean.x
		height[gait] = sum / n
		lean[gait] = lean_sum / n
		near(float(height[gait]), PuppetBody.per_gait(_tuning().body_scale, gait), 0.04,
			"kip %d ortalama siluet ölçeği" % gait)
		if gait == PuppetRig.Gait.SNEAK:
			var hands: PackedVector2Array = rig.hand_offsets()
			is_true(hands[0].x > 0.0 and hands[1].x > 0.0, "sızmada eller öne (sağa giderken x > 0): %s" % hands)
		if gait == PuppetRig.Gait.SPRINT:
			is_true(rig.footfalls > 0, "koşuda adımlar sayılır")
	is_true(float(height[PuppetRig.Gait.SNEAK]) + 0.1 < float(height[PuppetRig.Gait.WALK]), "sızma belirgin alçak")
	is_true(float(height[PuppetRig.Gait.WALK]) < float(height[PuppetRig.Gait.SPRINT]), "koşu uzamış")
	is_true(float(lean[PuppetRig.Gait.SPRINT]) > float(lean[PuppetRig.Gait.WALK]) + 0.05, "koşuda daha çok eğilme")
	is_true(float(lean[PuppetRig.Gait.WALK]) > 0.05, "gidilen yöne eğilme")


# --- fixed step ---

## The same motion yields the same pose at 30 and 144 FPS (springs and smoothing are independent of frame time).
func test_fixed_step_independent_of_frame_rate() -> void:
	var slow: PuppetRig = _sim_profile(1.0 / 30.0)
	var fast: PuppetRig = _sim_profile(1.0 / 144.0)
	near(slow.squash.x, fast.squash.x, 1e-4, "ezilme")
	near(slow.lean.x, fast.lean.x, 1e-4, "eğilme")
	near(slow.phase, fast.phase, 1e-3, "adım fazı")
	near(slow.face, fast.face, 1e-4, "yön")
	near(slow.velocity, fast.velocity, 1e-3, "görsel hız")
	eq(slow.footfalls, fast.footfalls, "adım sayısı")
	var a: PackedVector2Array = slow.scarf_points()
	var b: PackedVector2Array = fast.scarf_points()
	if eq(a.size(), b.size()):
		near(a[a.size() - 1], b[b.size() - 1], 0.01, "atkı ucu")


## 0-1 s walk right, 1-2 s run up, 2-3 s stop (times are multiples of both frame times).
func _sim_profile(dt: float) -> PuppetRig:
	var rig := PuppetRig.new(_tuning(), 3)
	var pos := Vector2.ZERO
	rig.update(dt, pos, Vector2.ZERO, Vector2.DOWN, PuppetRig.Gait.WALK, false)
	var frames: int = roundi(3.0 / dt)
	for k: int in range(1, frames + 1):
		var t: float = k * dt
		var vel := Vector2(140.0, 0.0)
		var gait: PuppetRig.Gait = PuppetRig.Gait.WALK
		if t > 2.0 + 1e-6:
			vel = Vector2.ZERO
		elif t > 1.0 + 1e-6:
			vel = Vector2(0.0, -220.0)
			gait = PuppetRig.Gait.SPRINT
		pos += vel * dt
		var facing: Vector2 = Vector2.UP if t > 1.0 + 1e-6 else Vector2.RIGHT
		rig.update(dt, pos, vel, facing, gait, false)
	return rig


# --- teleport ---

## When the buffer resets on a remote copy (or the level changes) the position jumps: the animation is silently rebuilt; the scarf
## is at the new position, the pose does not jump, dust is cleared.
func test_teleport_rebuilds_without_pop() -> void:
	var t: PuppetTuning = _tuning()
	var rig: PuppetRig = _rig()
	var pos: Vector2 = _run(rig, 1.0, RIGHT * 220.0, PuppetRig.Gait.SPRINT)
	var before_sq: float = rig.squash_y()
	var before_lean: float = rig.lean.x
	var rebuilds: int = rig.rebuilds
	var target: Vector2 = pos + Vector2(300.0, -200.0)
	rig.update(DT, target, RIGHT * 220.0, RIGHT, PuppetRig.Gait.SPRINT, false)
	eq(rig.rebuilds, rebuilds + 1, "ışınlanma yeniden kurar")
	eq(rig.position, target)
	is_true(rig.dust_particles().is_empty(), "eski toz silinir")
	## The Verlet constraint resolves in a few iterations: the chain may stretch a little while running (30% margin); a break would be hundreds of px.
	var chain: float = t.scarf_segment_length * t.puppet_scale * (t.scarf_segments - 1) * 1.3
	var max_jump: float = 0.0
	var max_scarf: float = 0.0
	var prev_sq: float = rig.squash_y()
	var prev_lean: float = rig.lean.x
	near(prev_sq, before_sq, 0.12, "ölçek sıçramaz")
	near(prev_lean, before_lean, 0.12, "eğilme sıçramaz")
	for i: int in 30:
		target += RIGHT * 220.0 * DT
		rig.update(DT, target, RIGHT * 220.0, RIGHT, PuppetRig.Gait.SPRINT, false)
		max_jump = maxf(max_jump, maxf(absf(rig.squash_y() - prev_sq), absf(rig.lean.x - prev_lean)))
		prev_sq = rig.squash_y()
		prev_lean = rig.lean.x
		var pts: PackedVector2Array = rig.scarf_points()
		for p: Vector2 in pts:
			max_scarf = maxf(max_scarf, p.distance_to(pts[0]))
	is_true(max_jump < 0.06, "kare başı ölçek/eğilme değişimi küçük: %.3f" % max_jump)
	is_true(max_scarf <= chain, "atkı bağlantıdan zincir boyundan uzağa savrulmaz: %.1f > %.1f" % [max_scarf, chain])


# --- visual overshoot ---

## Start, stop, sudden turn, run: body centre within 6 px of the collision centre, shadow/footprint within 12 + 6 px
## (GDD §14.1 rule 3); for all player look widths.
func test_visual_overshoot_bounded() -> void:
	var widest: float = 0.0
	for look: PuppetLook in _tuning().player_looks:
		var rig: PuppetRig = _rig()
		rig.set_look(look.width, look.has_scarf)
		var worst_torso: float = 0.0
		var worst_foot: float = 0.0
		var legs: Array = [
			[RIGHT * 220.0, PuppetRig.Gait.SPRINT, 0.6], [Vector2.ZERO, PuppetRig.Gait.SPRINT, 0.6],
			[Vector2.LEFT * 220.0, PuppetRig.Gait.SPRINT, 0.4], [RIGHT * 220.0, PuppetRig.Gait.SPRINT, 0.4],
			[Vector2(0, 140), PuppetRig.Gait.WALK, 0.5], [Vector2.LEFT * 70.0, PuppetRig.Gait.SNEAK, 0.6],
			[Vector2.ZERO, PuppetRig.Gait.WALK, 1.0],
		]
		for leg: Array in legs:
			var frames: int = roundi(float(leg[2]) / DT)
			for i: int in frames:
				_run(rig, DT, leg[0] as Vector2, leg[1] as PuppetRig.Gait)
				worst_torso = maxf(worst_torso, rig.torso_offset())
				worst_foot = maxf(worst_foot, rig.footprint_radius())
		is_true(worst_torso <= 6.0, "gövde aşması ≤ 6 px (genişlik %.2f): %.2f" % [look.width, worst_torso])
		is_true(worst_foot <= 18.0, "ayak izi ≤ 12 + 6 px (genişlik %.2f): %.2f" % [look.width, worst_foot])
		widest = maxf(widest, worst_foot)
	is_true(widest > 12.0, "ölçüm anlamlı (gölge gövde çapını biraz aşar): %.2f" % widest)


# --- reduced motion ---

func test_reduced_motion_disables_bob_lean_dust() -> void:
	var rig: PuppetRig = _rig()
	rig.reduced_motion = true
	var max_bob: float = 0.0
	var max_lean: float = 0.0
	for i: int in 90:
		_run(rig, DT, RIGHT * 220.0, PuppetRig.Gait.SPRINT)
		max_bob = maxf(max_bob, rig.bob())
		max_lean = maxf(max_lean, absf(rig.lean.x))
	eq(max_bob, 0.0, "sekme yok")
	near(max_lean, 0.0, 1e-6, "eğilme yok")
	is_true(rig.dust_particles().is_empty(), "toz yok")
	is_true(rig.footfalls > 0, "adımlar yine sayılır (kip okunur)")
	near(rig.squash_y(), 1.07, 0.03, "kip silueti kalır")
	rig.react(PuppetRig.Reaction.QUESTION)
	_run(rig, 0.3, Vector2.ZERO, PuppetRig.Gait.WALK)
	near(rig.bubble_scale(), 1.0, 0.001, "balonlar kalır")
	# The same run without reduced motion produces bounce, lean and dust (the test is meaningful).
	var normal: PuppetRig = _rig()
	var bob_seen: float = 0.0
	var dust_seen: int = 0
	for i: int in 90:
		_run(normal, DT, RIGHT * 220.0, PuppetRig.Gait.SPRINT)
		bob_seen = maxf(bob_seen, normal.bob())
		dust_seen = maxi(dust_seen, normal.dust_particles().size())
	is_true(bob_seen > 2.0 and dust_seen > 0 and normal.lean.x > 0.1, "normalde sekme/toz/eğilme var")


# --- reaction ---

func test_reaction_api() -> void:
	var t: PuppetTuning = _tuning()
	var rig: PuppetRig = _rig()
	eq(rig.bubble_scale(), 0.0, "balon yok")
	rig.react(PuppetRig.Reaction.QUESTION)
	eq(rig.reaction, PuppetRig.Reaction.QUESTION)
	_run(rig, 0.1, Vector2.ZERO, PuppetRig.Gait.WALK)
	var mid: float = rig.bubble_scale()
	is_true(mid > 0.5 and mid < 1.2, "pop sürüyor: %.2f" % mid)
	eq(rig.hop, 0.0, "'?' sıçratmaz")
	_run(rig, 0.15, Vector2.ZERO, PuppetRig.Gait.WALK)
	near(rig.bubble_scale(), 1.0, 0.001, "pop 0,2 sn'de tamam")
	# "!": overshooting pop, shake, jump, eye widening, squash on landing.
	rig.react(PuppetRig.Reaction.ALERT)
	var peak_scale: float = 0.0
	var peak_hop: float = 0.0
	var peak_eyes: float = 0.0
	var air: float = 0.0
	var min_sq: float = 2.0
	var shake_seen: float = 0.0
	for i: int in 60:
		_run(rig, DT, Vector2.ZERO, PuppetRig.Gait.WALK)
		peak_scale = maxf(peak_scale, rig.bubble_scale())
		peak_hop = maxf(peak_hop, rig.hop)
		peak_eyes = maxf(peak_eyes, rig.eye_size())
		shake_seen = maxf(shake_seen, absf(rig.bubble_shake()))
		if rig.hop > 0.0:
			air += DT
		elif air > 0.0:
			min_sq = minf(min_sq, rig.squash_y())
	is_true(peak_scale > 1.05, "easeOutBack aşması: %.2f" % peak_scale)
	is_true(shake_seen > 0.5, "'!' titrer")
	near(rig.bubble_shake(), 0.0, 1e-6, "titreme 0,4 sn'de söner")
	near(peak_hop, t.jump_speed * t.jump_speed / (2.0 * t.gravity), 1.0, "sıçrama yüksekliği")
	near(air, 0.35, 0.05, "~0,35 sn havada")
	is_true(peak_eyes > 1.08, "göz büyür: %.2f" % peak_eyes)
	is_true(min_sq < 0.97, "inişte ezilme: %.3f" % min_sq)
	rig.react(PuppetRig.Reaction.NONE)
	eq(rig.bubble_scale(), 0.0, "NONE balonu kaldırır")


# --- idle and anticipation/follow-through ---

func test_idle_breath_blink_and_look() -> void:
	var rig: PuppetRig = _rig(11)
	var lo: float = 2.0
	var hi: float = 0.0
	var blinked: bool = false
	var looks: Array[float] = []
	for i: int in roundi(8.0 / DT):
		_run(rig, DT, Vector2.ZERO, PuppetRig.Gait.WALK)
		if i > 60:
			lo = minf(lo, rig.squash_y())
			hi = maxf(hi, rig.squash_y())
		blinked = blinked or rig.is_blinking()
		looks.append(rig.eye_offset().x)
	is_true(hi - lo > 0.03 and hi - lo < 0.07, "nefes ±%%2,4: %.3f" % (hi - lo))
	is_true(blinked, "göz kırpar")
	looks.sort()
	is_true(looks[looks.size() - 1] - looks[0] > 1.0, "etrafa bakınır")
	# With a teammate present it looks at them too.
	var social: PuppetRig = _rig(5)
	social.friend_position = Vector2(-200.0, 0.0)
	social.has_friend = true
	var left_seen: bool = false
	for i: int in roundi(12.0 / DT):
		_run(social, DT, Vector2.ZERO, PuppetRig.Gait.WALK)
		left_seen = left_seen or social.eye_offset().x < -2.5
	is_true(left_seen, "arkadaşa (sola) bakar")


func test_start_dip_and_stop_overshoot() -> void:
	var rig: PuppetRig = _rig()
	_run(rig, 1.0, Vector2.ZERO, PuppetRig.Gait.WALK)
	var dip: float = 2.0
	for i: int in 12:
		_run(rig, DT, RIGHT * 140.0, PuppetRig.Gait.WALK)
		dip = minf(dip, rig.squash_y())
	is_true(dip < 0.985, "kalkışta minik çökme: %.3f" % dip)
	_run(rig, 1.0, RIGHT * 140.0, PuppetRig.Gait.WALK)
	var walking_lean: float = rig.lean.x
	var forward: float = -1.0
	for i: int in 30:
		_run(rig, DT, Vector2.ZERO, PuppetRig.Gait.WALK)
		forward = maxf(forward, rig.lean.x)
	is_true(forward > walking_lean + 0.01, "duruşta öne taşma: %.3f > %.3f" % [forward, walking_lean])
	_run(rig, 2.0, Vector2.ZERO, PuppetRig.Gait.WALK)
	near(rig.lean.x, 0.0, 0.01, "sonra yerine yaylanır")
	var pts: PackedVector2Array = rig.scarf_points()
	is_true(pts.size() == 6 and pts[5].y > pts[0].y, "atkı durunca aşağı sarkar")



# --- high frame rate, spring stability, hitch (t2) ---

## At 144/240 Hz the fixed step does not fall on some frames; the drawn scarf root is still at the body's draw-position
## anchor on every frame (<= 0.5 px).
func test_scarf_root_follows_body_at_high_frame_rates() -> void:
	for fps: float in [144.0, 240.0]:
		var rig: PuppetRig = _rig()
		var dt: float = 1.0 / fps
		var lagging: int = 0
		var worst: float = 0.0
		for i: int in roundi(2.0 * fps):
			var vel := Vector2(220.0, 0.0) if i < roundi(1.4 * fps) else Vector2(0.0, -140.0)
			var gait: PuppetRig.Gait = PuppetRig.Gait.SPRINT if vel.x > 0.0 else PuppetRig.Gait.WALK
			_run(rig, dt, vel, gait, dt)
			if rig.position != rig.target_position:
				lagging += 1
			worst = maxf(worst, rig.scarf_draw_points()[0].distance_to(rig.scarf_anchor()))
		is_true(lagging > 0, "%d Hz: adımsız kare oluşur (testin anlamlılığı): %d" % [fps, lagging])
		is_true(worst <= 0.5, "%d Hz: atkı kökü bağlantıda: %.3f px" % [fps, worst])


## The spring does not blow up with out-of-range settings either (substeps + clamping); with usual settings behaviour is the same (single step).
func test_spring_stable_at_extreme_settings() -> void:
	for setting: Vector2 in [Vector2(10.0, 2.0), Vector2(20.0, 2.0), Vector2(40.0, 0.05), Vector2(200.0, 5.0)]:
		var spring := PuppetSpring.new(0.0)
		for i: int in 600:
			spring.step(1.0, setting.x, setting.y, 1.0 / 120.0)
		is_true(is_finite(spring.x) and is_finite(spring.v), "%s sonlu" % setting)
		near(spring.x, 1.0, 0.01, "%s hedefe oturur" % setting)
	var a := PuppetSpring.new(0.0)
	a.step(1.0, 4.5, 0.32, 1.0 / 120.0)
	var w: float = TAU * 4.5
	var v: float = w * w / 120.0
	near(a.v, v, 1e-6, "olağan ayarda alt adım yok")
	near(a.x, v / 120.0, 1e-9)


## A hitched frame (e.g. 5 s) is processed at most MAX_FRAME_DELTA; the pose stays finite and then continues normally.
func test_frame_hitch_is_capped() -> void:
	var rig: PuppetRig = _rig()
	var pos: Vector2 = _run(rig, 0.5, RIGHT * 140.0, PuppetRig.Gait.WALK)
	var clock: float = rig.clock
	rig.update(5.0, pos + RIGHT * 20.0, RIGHT * 140.0, RIGHT, PuppetRig.Gait.WALK, false)
	is_true(rig.clock - clock <= PuppetRig.MAX_FRAME_DELTA + PuppetRig.STEP, "en çok 0,25 sn işlenir: %.3f" % (rig.clock - clock))
	is_true(rig.clock - clock >= PuppetRig.MAX_FRAME_DELTA - PuppetRig.STEP, "tavana kadar işlenir")
	is_true(is_finite(rig.squash_y()) and is_finite(rig.lean.x) and absf(rig.squash_y() - 1.0) < 0.3, "poz sonlu")
	eq(rig.position, pos + RIGHT * 20.0, "konum yetişir")
	var before: float = rig.clock
	_run(rig, 0.1, RIGHT * 140.0, PuppetRig.Gait.WALK)
	near(rig.clock - before, 0.1, PuppetRig.STEP, "sonra olağan ilerler (birikim taşmaz)")
