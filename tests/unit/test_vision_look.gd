extends TestCase
## US-011b AC3/AC4 (GDD §6.5, §2b; S2, S6): bakış yönü. LookRules (8 bit niceleme 1,4° adım, dönüş tavanı
## 240°/sn, klavye-yalnız yumuşak dönüş k = 9), bot `"look"` adımı, SnapshotBuffer'da açı ara değerlemesi (en kısa
## yol), oyuncunun yerel bakışı (girdi → tavanlı dönüş → 8 bit yayın; tutulunca donar) ve uzak kopyada aynı tavanla
## izleme, kukla baş/göz bakışı (gövde hareket yönünde), ekip bakış yayı yalnız yönlü kipte ve ekip arkadaşında.
## Ağ davranışı: tests/net/look_sync.json (0 ve 150 ms).

const SCENE := "res://entities/player/player.tscn"
const DT := 1.0 / 60.0
const MAX_TURN := deg_to_rad(240.0)
const STEP_DEG := 360.0 / 256.0


func _spawn(authority: int = 1, at: Vector2 = Vector2.ZERO) -> Player:
	var player: Player = (load(SCENE) as PackedScene).instantiate() as Player
	player.name = str(authority)
	player.set_multiplayer_authority(authority, true)
	player.position = at
	autofree(player)
	tree().root.add_child(player)
	return player


func _bot(steps: Array) -> BotTimeline:
	return BotTimeline.from_raw(steps)


# --- LookRules ---

func test_quantize_is_8_bit_and_round_trips_within_half_step() -> void:
	eq(LookRules.STEPS, 256)
	for deg: float in [0.0, 0.7, 1.4, 45.0, 90.0, 179.0, 180.0, -179.3, -90.0, -0.69, 359.0, 720.5]:
		var q: int = LookRules.quantize(deg_to_rad(deg))
		is_true(q >= 0 and q <= 255, "0..255: %d" % q)
		var back: float = rad_to_deg(LookRules.dequantize(q))
		near(absf(angle_difference(deg_to_rad(back), deg_to_rad(deg))), 0.0, deg_to_rad(STEP_DEG * 0.5) + 0.0001,
			"yarım adım içinde: %s → %s" % [deg, back])
	eq(LookRules.quantize(PI), LookRules.quantize(-PI), "±180° aynı adım")
	eq(LookRules.dequantize(LookRules.quantize(deg_to_rad(90.0))), LookRules.snap(deg_to_rad(90.0)))
	near(rad_to_deg(LookRules.dequantize(1)), STEP_DEG, 0.0001, "1 adım = 1,40625°")


func test_turn_is_capped_at_240_deg_per_sec() -> void:
	var a: float = LookRules.turn(0.0, deg_to_rad(90.0), 0.1, MAX_TURN)
	near(rad_to_deg(a), 24.0, 0.001, "0,1 sn'de en çok 24°")
	a = LookRules.turn(0.0, deg_to_rad(-90.0), 0.1, MAX_TURN)
	near(rad_to_deg(a), -24.0, 0.001, "ters yön de tavanlı")
	a = LookRules.turn(deg_to_rad(170.0), deg_to_rad(-170.0), 0.1, MAX_TURN)
	near(rad_to_deg(angle_difference(deg_to_rad(170.0), a)), 20.0, 0.001, "en kısa yoldan (±180 sarar)")
	near(LookRules.turn(0.0, deg_to_rad(10.0), 0.1, MAX_TURN), deg_to_rad(10.0), 0.0001, "yakın hedefe tam varır")
	# Tam tur 1,5 sn: 180° dönüş 0,75 sn'den önce bitmez.
	var t: float = 0.0
	var angle: float = 0.0
	while absf(angle_difference(angle, PI * 0.999)) > 0.001 and t < 2.0:
		angle = LookRules.turn(angle, PI * 0.999, DT, MAX_TURN)
		t += DT
	is_true(t >= 0.74 and t <= 0.78, "≈180° / 240°/sn = 0,75 sn, gelen %.3f" % t)


func test_keyboard_only_smooth_turn_k9() -> void:
	# Tek adımda üstel yaklaşım: fark × (1 − e^(−9·dt)), tavanın altında.
	var one: float = LookRules.step_look(0.0, Vector2.ZERO, Vector2.from_angle(deg_to_rad(20.0)), DT, MAX_TURN)
	near(rad_to_deg(one), 20.0 * (1.0 - exp(-9.0 * DT)), 0.0001, "k = 9 yumuşatma")
	# ≈0,33 sn'de %95 (3/k).
	var angle: float = 0.0
	for i: int in roundi(0.333 / DT):
		angle = LookRules.step_look(angle, Vector2.ZERO, Vector2.from_angle(deg_to_rad(20.0)), DT, MAX_TURN)
	near(rad_to_deg(angle), 20.0 * 0.95, 0.4)
	# Büyük farkta tavan yine geçerli.
	var big: float = LookRules.step_look(0.0, Vector2.ZERO, Vector2.LEFT, 0.1, MAX_TURN)
	is_true(absf(rad_to_deg(big)) <= 24.0001, "klavyede de 240°/sn tavanı")
	# Açık bakış (fare/çubuk/bot) varsa hareket yönü yok sayılır.
	var look: float = LookRules.step_look(0.0, Vector2.DOWN, Vector2.LEFT, 0.05, MAX_TURN)
	near(rad_to_deg(look), 12.0, 0.001, "açık bakış: tavanla hedefe, yumuşatmasız")
	eq(LookRules.step_look(1.0, Vector2.ZERO, Vector2.ZERO, DT, MAX_TURN), 1.0, "girdi yok: açı korunur")


# --- bot "look" adımı (S6 eki) ---

func test_bot_look_step_parses_holds_and_releases() -> void:
	var bot: BotTimeline = _bot([{"t": 0.0, "look": [0, -2]}, {"t": 1.0, "look": [0, 0]}, {"t": 2.0, "look": [3]},
		{"t": 3.0, "look": [1, 1]}])
	bot.advance(0.1)
	eq(bot.look_vector(), Vector2.UP, "[0, -2] → birim yukarı")
	bot.advance(0.5)
	eq(bot.look_vector(), Vector2.UP, "bir sonraki look adımına kadar sürer")
	bot.advance(0.5)
	eq(bot.look_vector(), Vector2.ZERO, "[0, 0] bırakır")
	bot.advance(1.0)
	eq(bot.look_vector(), Vector2.ZERO, "bozuk look yok sayılır (uyarı)")
	bot.advance(1.0)
	near(bot.look_vector(), Vector2(1, 1).normalized(), 0.0001)
	eq(BotTimeline.parse_look("x"), Vector2.ZERO)


# --- SnapshotBuffer açı ara değerlemesi ---

func test_buffer_interpolates_look_along_shortest_arc() -> void:
	var buffer := SnapshotBuffer.new(0.1)
	buffer.push(1.0, 1.0, Vector2.ZERO, Vector2.DOWN, 0, deg_to_rad(170.0))
	buffer.push(1.1, 1.1, Vector2.ZERO, Vector2.DOWN, 0, deg_to_rad(-170.0))
	var frame: SnapshotBuffer.Frame = buffer.sample(1.15)  # çizim anı 1,15 − 0,1 = 1,05: ortada
	near(absf(rad_to_deg(frame.look)), 180.0, 0.5, "170° → −170° ortası 180° (350° değil)")
	is_false(buffer.push(1.2, 1.2, Vector2.ZERO, Vector2.DOWN, 0, NAN), "NaN bakış atılır")


# --- oyuncu: yerel bakış ve yayın ---

func test_local_player_turns_toward_bot_look_with_cap_and_publishes_8_bit() -> void:
	var player: Player = _spawn(1)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(_bot([{"t": 0.0, "look": [0, -1]}]))
	near(rad_to_deg(player.look_angle()), 90.0, 0.001, "başlangıç aşağı (90°)")
	var start: float = player.look_angle()
	for i: int in 16:
		await tree().physics_frame
	var turned: float = absf(angle_difference(start, player.look_angle()))
	is_true(rad_to_deg(turned) <= 240.0 * 16.0 / 60.0 + 0.5, "tavan: 16 karede ≤ 64°, gelen %.1f" %
		rad_to_deg(turned))
	is_true(rad_to_deg(turned) > 40.0, "döner")
	for i: int in 60:
		await tree().physics_frame
	near(rad_to_deg(player.look_angle()), -90.0, 0.01, "180° dönüş ~0,75 sn'de biter")
	near(player.look_dir, Vector2.UP, 0.0001)
	eq(player.net_look, LookRules.quantize(player.look_angle()), "8 bit yayın")
	eq(player.motion_state()["look_deg"], -90.0)


func test_held_player_look_freezes() -> void:
	var player: Player = _spawn(1)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(_bot([{"t": 0.0, "look": [1, 0]}]))
	player.host_hold(6.0)
	for i: int in 20:
		await tree().physics_frame
	near(rad_to_deg(player.look_angle()), 90.0, 0.001, "tutulan oyuncunun bakışı donar (girdi okunmaz)")


func test_keyboard_only_look_follows_movement() -> void:
	var player: Player = _spawn(1, Vector2(2000, 2000))
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(_bot([{"t": 0.0, "move": [1, 0]}]))
	for i: int in 60:
		await tree().physics_frame
	near(rad_to_deg(player.look_angle()), 0.0, 1.0, "açık bakış yok: hareket yönüne yumuşak döner")


# --- uzak kopya: ara değerleme + aynı tavan ---

func test_remote_copy_follows_look_with_same_cap() -> void:
	var player: Player = _spawn(2)
	var sync: MultiplayerSynchronizer = player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
	var sender: float = Time.get_ticks_usec() / 1_000_000.0 - 1.0
	player.net_time = sender
	player.net_look = LookRules.quantize(0.0)
	sync.synchronized.emit()
	await tree().process_frame
	await tree().process_frame
	near(player.look_angle(), 0.0, 0.0001, "ilk veride döndürmeden oturur")
	# 180° sıçrayan veri: çizilen açı tavanla döner (ilk 0,1 sn'de ≤ 24° + kare payı).
	for k: int in range(1, 30):
		player.net_time = sender + 0.05 * k
		player.net_look = LookRules.quantize(PI * 0.99)
		sync.synchronized.emit()
	var before: float = player.look_angle()
	var started: int = Time.get_ticks_usec()
	await tree().create_timer(0.1).timeout
	var elapsed: float = (Time.get_ticks_usec() - started) / 1_000_000.0 + 1.0 / 30.0
	is_true(rad_to_deg(absf(angle_difference(before, player.look_angle()))) <= 240.0 * elapsed + 0.5,
		"uzak kopya da 240°/sn ile sınırlı")
	await tree().create_timer(0.9).timeout
	near(rad_to_deg(absf(angle_difference(player.look_angle(), LookRules.snap(PI * 0.99)))), 0.0, 0.01,
		"hedefe yakınsar")


# --- kukla ve ekip yayı (AC4) ---

func test_puppet_head_follows_look_body_follows_motion() -> void:
	var rig := PuppetRig.new(load(Puppet.TUNING_PATH) as PuppetTuning)
	rig.target_look = Vector2.UP
	rig.update(DT, Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT, PuppetRig.Gait.WALK, false)  # ilk kurulum
	near(rig.head_direction(), Vector2.UP, 0.0001, "kurulumda baş bakışta")
	near(rig.face_direction(), Vector2.RIGHT, 0.0001, "gövde hareket yönünde")
	is_true(rig.head_is_back() and not rig.is_back(), "baş arkaya, gövde yana")
	rig.target_look = Vector2.DOWN
	for i: int in 20:
		rig.update(DT, Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT, PuppetRig.Gait.WALK, false)
	is_true(rig.head_direction().y > 0.9, "baş k = 9 ile döner")
	near(rig.face_direction(), Vector2.RIGHT, 0.0001)
	rig.target_look = Vector2.ZERO
	rig.update(DT, Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT, PuppetRig.Gait.WALK, false)
	near(rig.head_direction(), rig.face_direction(), 0.0001, "bakış yoksa baş gövdeyle (NPC'ler)")


func test_look_arc_only_on_teammate_in_directional_mode() -> void:
	var was: int = Game.vision_mode()
	var local: Player = _spawn(1)
	var mate: Player = _spawn(2, Vector2(50, 0))
	await tree().process_frame
	var local_visual: PlayerVisual = local.get_node("Visual") as PlayerVisual
	var mate_visual: PlayerVisual = mate.get_node("Visual") as PlayerVisual
	Game.set_vision_mode(VisionGrid.Mode.DIRECTIONAL)
	is_true(mate_visual.shows_look_arc(), "yönlü kipte ekip arkadaşında yay")
	is_false(local_visual.shows_look_arc(), "yerel oyuncuda yay yok")
	Game.set_vision_mode(VisionGrid.Mode.PERIPHERAL)
	is_false(mate_visual.shows_look_arc(), "360° kipte yay yok")
	is_true(mate_visual.z_index > 50 and local_visual.z_index > 50, "oyuncular sisin (z 50) üstünde")
	eq(PlayerVisual.LOOK_ARC_RADIUS, 32.0)
	eq(PlayerVisual.LOOK_ARC_DEG, 90.0)
	eq(PlayerVisual.LOOK_ARC_ALPHA, 0.25)
	Game.set_vision_mode(was)
