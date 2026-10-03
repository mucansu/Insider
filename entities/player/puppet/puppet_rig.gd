class_name PuppetRig
extends RefCounted
## Kukla animasyon hesabı (US-014; GDD §14.1, KR-017): düğümsüz, yalnız değerlerle çalışır (KR-003: 3D'ye
## geçişte aynı hesap toon gövdeyi sürebilir). Girdi = gözlenen durum (konum, hız, bakış yönü, kip, etkileşim);
## çıktı = poz (ezilme, eğilme, sekme, sıçrama, adım fazı, eller/ayaklar, gözler, atkı, toz, tepki balonu).
## Mantığa, girdiye, çarpışmaya ve ağa dokunmaz; Puppet her karede `update` çağırır ve pozu çizer.
##
## Sabit adım: `update(delta, …)` gelen süreyi biriktirip 1/120 sn'lik adımlarla ilerler; yaylar ve
## yumuşatmalar kare süresinden bağımsızdır. Konum adımlar arasında doğrusal dağıtılır (atkı düzgün izler).
## Işınlanma: tek güncellemede `teleport_distance`'tan uzun konum sıçraması (uzak kopyada tampon sıfırlanması,
## seviye değişimi) animasyonu sessizce yeniden kurar: atkı yeni konumda asılı, yaylar hedefte, toz silinir.
##
## Birimler: kukla geometrisi "birim" (× tuning.puppet_scale = px); hızlar ve adım boyları px/sn ve px.
## Sıçrama, toz ve atkı da birimdir (deneme sahnesi kukla ölçeği 2 ile çizildiği için oradaki px = 2 birim).
## "Görsel aşma" (GDD §14.1 kural 3): gövde merkezinin çarpışma merkezinden yatay sapması (`torso_offset`) ve
## gölge/ayak izinin yarıçapı (`footprint_radius`); tepki sıçraması (düşey, kısa) ve atkı (ikincil kumaş) hariç.

## Kip sırası tuning'deki Vector3 bileşenleriyle aynı: x sız, y yürü, z koş.
enum Gait { SNEAK, WALK, SPRINT }
enum Reaction { NONE, QUESTION, ALERT }

## Sabit simülasyon adımı (sn).
const STEP := 1.0 / 120.0
## Tek güncellemede işlenen en uzun süre (sn): takılan karede yaylar patlamasın.
const MAX_FRAME_DELTA := 0.25
const STEP_EPSILON := 1e-7
## Gözlenen hız bundan küçükse "duruyor" (duruş yumuşatması; px/sn).
const STOP_SPEED := 1.0
## moving oranı bunun altındayken bekleme pozu (nefes, bakınma).
const IDLE_MOVING := 0.2
## Gözlenen hızın görsel tavanı (px/sn): ara değerlemede kısa aralıkta büyük konum farkı (geç/kayıp paket)
## animasyonu patlatmasın.
const MAX_VISUAL_SPEED := 400.0
## Ezilme hedefinin güvenli aralığı (siluet ölçeği).
const SQUASH_LIMITS := Vector2(0.6, 1.3)

## Ezilmede genişleme: sqx = 1 + (1 - sqy) × oran.
const SQUASH_WIDTH_RATIO := 0.85
## Bakış y bileşeni bundan küçükse sırt dönük çizilir.
const BACK_FACING_Y := -0.35
## Baş tepesi: baş yarıçapının bu katı (başlık dahil).
const HEAD_TOP_RATIO := 1.15
## Sıçramada gölge küçülmesi: 1 - min(MAX, yükseklik / REF).
const SHADOW_HOP_REF := 45.0
const SHADOW_HOP_MAX := 0.45
## İnişte ezilme yalnız bu düşüş hızından sonra (birim/sn).
const LAND_MIN_SPEED := 60.0
## Atkı bağlantısı boyundan (birim): bakışın tersine ve aşağı.
const SCARF_BACK := 3.0
const SCARF_DEPTH := 1.5
const SCARF_DROP := 2.0


var tuning: PuppetTuning = null
## Hareket azaltma (GDD §14.1 kural 5): sekme, eğilme ve toz kapanır; balonlar ve halkalar kalır.
var reduced_motion: bool = false
## Görünümün atkısı var mı (yoksa atkı hesaplanmaz).
var has_scarf: bool = true
## Gövde genişlik çarpanı (PuppetLook.width): el/ayak açıklığı ve gölge.
var width: float = 1.0

# --- son gözlenen durum ---
var target_position: Vector2 = Vector2.ZERO
var target_velocity: Vector2 = Vector2.ZERO
var target_facing: Vector2 = Vector2.DOWN
var gait: Gait = Gait.WALK
var interacting: bool = false
## Bakınmada bakılabilecek ekip arkadaşı (dünya px); yoksa has_friend false.
var friend_position: Vector2 = Vector2.ZERO
var has_friend: bool = false
## Baş ve gözlerin bakış yönü (US-011b, GDD §14.1: baş bakışı, gövde hareket yönünü izler); sıfır = baş gövdeyle.
var target_look: Vector2 = Vector2.ZERO

# --- poz durumu ---
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var accel: Vector2 = Vector2.ZERO
var face: float = PI * 0.5
## Baş açısı (rad): `target_look` varsa ona `turn_smoothing` ile döner, yoksa gövde açısı (`face`).
var head: float = PI * 0.5
var phase: float = 0.0
var clock: float = 0.0
var squash: PuppetSpring = PuppetSpring.new(1.0)
var lean: PuppetSpring = PuppetSpring.new(0.0)
var hop: float = 0.0
var hop_velocity: float = 0.0
var reaction: Reaction = Reaction.NONE
var reaction_age: float = 0.0
## Adım inişi ve ışınlanma sayaçları (teşhis/test).
var footfalls: int = 0
var rebuilds: int = 0

## Gözler (bakış, bakınma, kırpma) ve ikincil hareket (atkı, toz).
var eyes: PuppetEyes = null
var cloth: PuppetCloth = PuppetCloth.new()

var _accumulator: float = 0.0
var _built: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(values: PuppetTuning, rng_seed: int = 0) -> void:
	tuning = values
	_rng.seed = rng_seed
	eyes = PuppetEyes.new(values, _rng)


## Bir kare: gözlenen durumu alır, biriken süreyi sabit adımlarla işler.
func update(delta: float, pos: Vector2, vel: Vector2, facing: Vector2, which: Gait, working: bool) -> void:
	var from: Vector2 = position
	target_velocity = vel.limit_length(MAX_VISUAL_SPEED) if vel.is_finite() else Vector2.ZERO
	if facing.length_squared() > 0.0001:
		target_facing = facing.normalized()
	gait = which
	interacting = working
	target_position = pos
	if not _built or pos.distance_to(from) > tuning.teleport_distance:
		rebuild(pos)
		return
	_accumulator += clampf(delta, 0.0, MAX_FRAME_DELTA)
	var steps: int = int((_accumulator + STEP_EPSILON) / STEP)
	if steps <= 0:
		return
	_accumulator = maxf(0.0, _accumulator - steps * STEP)
	for i: int in steps:
		_step(STEP, from.lerp(pos, float(i + 1) / steps))


## Animasyonu verilen konumda ve son gözlenen durumda sessizce yeniden kurar (sıçrama/"pop" yok).
func rebuild(pos: Vector2) -> void:
	position = pos
	velocity = target_velocity
	accel = Vector2.ZERO
	face = target_facing.angle()
	head = _head_target()
	var moving: float = _moving()
	squash.settle(PuppetBody.target_squash(tuning, gait, moving, interacting, _exaggeration()))
	lean.settle(PuppetBody.target_lean(tuning, gait, velocity, accel, _exaggeration(), reduced_motion))
	eyes.settle(head)
	hop = 0.0
	hop_velocity = 0.0
	cloth.clear_dust()
	_accumulator = 0.0
	_reset_scarf()
	_built = true
	rebuilds += 1


## Tepki: "?" (şüphe) ya da "!" (fark edildi: sıçrama + göz büyümesi). NONE balonu kaldırır.
func react(kind: Reaction) -> void:
	if kind == reaction and kind != Reaction.ALERT:
		return
	reaction = kind
	reaction_age = 0.0
	if kind == Reaction.ALERT:
		jump()
		eyes.widen(tuning.alert_eye_impulse)


## Görünüm değişti: gövde genişliği ve atkı (atkı yeniden asılır).
func set_look(body_width: float, scarf: bool) -> void:
	width = body_width
	has_scarf = scarf
	if _built:
		_reset_scarf()


## Yerdeyse sıçrar.
func jump() -> void:
	if hop <= 0.01:
		hop_velocity = tuning.jump_speed
		hop = 0.01


# --- okuma (çizim ve testler) ---

func speed() -> float:
	return velocity.length()


## Hareket oranı 0..1 (tam harekette 1).
func moving() -> float:
	return _moving()


func face_direction() -> Vector2:
	return Vector2.from_angle(face)


## Başın (yüz, gözler, başlık) yönü.
func head_direction() -> Vector2:
	return Vector2.from_angle(head)


## Baş sırt dönük mü (yukarı bakıyor; yüz çizilmez).
func head_is_back() -> bool:
	return head_direction().y < BACK_FACING_Y


## Sırt dönük mü (yukarı bakıyor).
func is_back() -> bool:
	return face_direction().y < BACK_FACING_Y


## Siluet yüksekliği ölçeği (ezilme-esneme yayı).
func squash_y() -> float:
	return squash.x


func squash_x() -> float:
	return 1.0 + (1.0 - squash.x) * SQUASH_WIDTH_RATIO


## Adım sekmesi (birim, yukarı); hareket azaltmada 0.
func bob() -> float:
	if reduced_motion:
		return 0.0
	return absf(sin(phase)) * PuppetBody.per_gait(tuning.bob_amplitude, gait) * _moving() * tuning.bounce


## Gövde dönüşümü: birim koordinatlı gövde/baş parçalarını düğüm yereline (px) taşır.
## Sırayla: sıçrama → eğilme (ayak noktası etrafında) → ezilme × ölçek → sekme.
func body_transform(include_hop: bool = true) -> Transform2D:
	var s: float = tuning.puppet_scale
	var lift: float = hop * s if include_hop else 0.0
	return Transform2D(lean.x, Vector2(0.0, -lift)) \
		.scaled_local(Vector2(squash_x() * s, squash_y() * s)) \
		.translated_local(Vector2(0.0, -bob()))


## Yer dönüşümü (gölge ve ayaklar; eğilme ve ezilme yok).
func ground_transform() -> Transform2D:
	var s: float = tuning.puppet_scale
	return Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)


## Sıçramada gölge ölçeği.
func shadow_scale() -> float:
	return 1.0 - minf(SHADOW_HOP_MAX, hop / SHADOW_HOP_REF)


## İki ayağın merkezi (birim, yer dönüşümünde): sol, sağ.
func foot_offsets() -> PackedVector2Array:
	return PuppetBody.feet(face_direction(), phase, _moving(), PuppetBody.per_gait(tuning.foot_swing, gait), width, hop)


## İki elin merkezi (birim, gövde dönüşümünde).
func hand_offsets() -> PackedVector2Array:
	var m: float = _moving()
	return PuppetBody.hands(face_direction(), phase, m, width, gait == Gait.SNEAK and m > IDLE_MOVING,
		interacting, clock)


## Göz bebeği sapması (birim) ve ölçeği; kırpmada kapalı.
func eye_offset() -> Vector2:
	return eyes.offset()


func eye_size() -> float:
	return eyes.size.x


func is_blinking() -> bool:
	return eyes.is_blinking()


## Atkı noktaları (dünya px; ilk nokta boyundaki bağlantı). Atkı yoksa boş.
func scarf_points() -> PackedVector2Array:
	return cloth.scarf_points()


## Çizilecek atkı noktaları (dünya px). Yüksek kare hızında (144/240 Hz) bazı karelerde sabit adım düşmez:
## simülasyon konumu gözlenen konumun gerisinde kalır, gövde ise gözlenen konumda çizilir. Atkı aynı farkla
## kaydırılır; kökü her karede gövdedeki bağlantı noktasındadır.
func scarf_draw_points() -> PackedVector2Array:
	var pts: PackedVector2Array = cloth.scarf_points()
	var lag: Vector2 = target_position - position
	if lag == Vector2.ZERO or pts.is_empty():
		return pts
	var out: PackedVector2Array = pts.duplicate()
	for i: int in out.size():
		out[i] += lag
	return out


## Atkının gövdedeki bağlantı noktası, gözlenen (çizilen) konumda (dünya px).
func scarf_anchor() -> Vector2:
	return _anchor_at(target_position)


func dust_particles() -> Array[PuppetCloth.Dust]:
	return cloth.dust_particles()


## Balon pop ölçeği (easeOutBack) ve "!" titremesi (px).
func bubble_scale() -> float:
	return PuppetBody.bubble_scale(tuning, reaction, reaction_age)


func bubble_shake() -> float:
	return PuppetBody.bubble_shake(tuning, reaction, reaction_age)


## Gövde merkezinin çarpışma merkezinden yatay sapması (px; sıçrama hariç).
func torso_offset() -> float:
	return absf((body_transform(false) * PuppetBody.TORSO_CENTER).x)


## Gölge ve ayak izinin merkezden en uzak yatay noktası (px).
func footprint_radius() -> float:
	var s: float = tuning.puppet_scale
	var r: float = PuppetBody.SHADOW_RADIUS.x * width * shadow_scale()
	for foot: Vector2 in foot_offsets():
		r = maxf(r, absf(foot.x) + PuppetBody.FOOT_RADIUS.x)
	return r * s


## Baş tepesinin düğüm yerelindeki konumu (px); işaretler buna DEĞİL sabit bağlantıya bağlıdır.
func head_top() -> Vector2:
	return body_transform() * (PuppetBody.HEAD_CENTER - Vector2(0.0, PuppetBody.HEAD_RADIUS * HEAD_TOP_RATIO))


# --- adım ---

func _step(h: float, pos: Vector2) -> void:
	position = pos
	var k: float = tuning.speed_smoothing_start if target_velocity.length() > STOP_SPEED \
		else tuning.speed_smoothing_stop
	var prev: Vector2 = velocity
	velocity += (target_velocity - velocity) * (1.0 - exp(-k * h))
	accel += ((velocity - prev) / h - accel) * (1.0 - exp(-tuning.accel_smoothing * h))
	var spd: float = velocity.length()
	face += angle_difference(face, target_facing.angle()) * (1.0 - exp(-tuning.turn_smoothing * h))
	if target_look.length_squared() > 0.0001:
		head += angle_difference(head, target_look.angle()) * (1.0 - exp(-tuning.turn_smoothing * h))
	else:
		head = face

	var half: float = floorf(phase / PI)
	phase += spd * h / maxf(1.0, PuppetBody.per_gait(tuning.stride, gait)) * PI
	if floorf(phase / PI) != half and spd > tuning.footfall_min_speed:
		_footfall()
	clock += h

	var m: float = _moving()
	var ex: float = _exaggeration()
	var sq_target: float = PuppetBody.target_squash(tuning, gait, m, interacting, ex)
	if m < IDLE_MOVING and tuning.breath_period > 0.0:
		sq_target += tuning.breath_amount * sin(clock * TAU / tuning.breath_period) * (1.0 - m / IDLE_MOVING)
	sq_target -= maxf(0.0, accel.dot(face_direction())) * tuning.squash_accel_gain * ex  # kalkış çökmesi
	sq_target = clampf(sq_target, SQUASH_LIMITS.x, SQUASH_LIMITS.y)
	squash.step(sq_target, tuning.spring_frequency, tuning.squash_damping, h)
	lean.step(PuppetBody.target_lean(tuning, gait, velocity, accel, ex, reduced_motion),
		tuning.spring_frequency * tuning.lean_frequency_ratio, tuning.lean_damping, h)

	if hop > 0.0 or hop_velocity > 0.0:
		hop_velocity -= tuning.gravity * h
		hop += hop_velocity * h
		if hop <= 0.0:
			hop = 0.0
			if hop_velocity < -LAND_MIN_SPEED:
				squash.v -= tuning.land_impulse * tuning.bounce
			hop_velocity = 0.0

	eyes.step(h, head, m < IDLE_MOVING, gait == Gait.SNEAK and m > IDLE_MOVING, position, friend_position,
		has_friend)
	if reaction != Reaction.NONE:
		reaction_age += h
	if has_scarf:
		cloth.step_scarf(_anchor_at(position), tuning.scarf_segments, _scarf_segment(), tuning.scarf_damping,
			tuning.scarf_gravity * tuning.puppet_scale * h * h)
	cloth.step_dust(h)


func _footfall() -> void:
	footfalls += 1
	if reduced_motion:
		return
	squash.v -= tuning.footfall_impulse * tuning.bounce * PuppetBody.per_gait(tuning.footfall_factor, gait)
	if gait != Gait.SPRINT:
		return
	cloth.emit_dust(position, face_direction(), tuning.dust_per_step, tuning.dust_life, tuning.puppet_scale, _rng)


## Gövdenin `base` konumunda (dünya px) çizildiği pozda atkının boyundaki bağlantısı.
func _anchor_at(base: Vector2) -> Vector2:
	var s: float = tuning.puppet_scale
	var f: Vector2 = face_direction()
	var neck: Vector2 = base + Vector2(sin(lean.x), -cos(lean.x)) * PuppetBody.NECK_HEIGHT * s * squash.x \
		- Vector2(0.0, hop * s)
	return neck + Vector2(-f.x * SCARF_BACK, -f.y * SCARF_DEPTH + SCARF_DROP) * s


func _scarf_segment() -> float:
	return tuning.scarf_segment_length * tuning.puppet_scale


func _reset_scarf() -> void:
	cloth.reset_scarf(_anchor_at(position), tuning.scarf_segments if has_scarf else 0, _scarf_segment())


func _head_target() -> float:
	return target_look.angle() if target_look.length_squared() > 0.0001 else face


func _moving() -> float:
	return minf(1.0, velocity.length() / maxf(1.0, tuning.moving_reference_speed))


func _exaggeration() -> float:
	return tuning.exaggeration
