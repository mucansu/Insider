extends TestCase
## US-004 oyuncu: ayar okuma (AC2, S10), kipe göre hız ve ivmelenme (PlayerMotion), sahne yapısı (AC1: katmanlar,
## görsel ayrı düğüm, kamera yalnız yerelde, yuvadan renk + ad etiketi), yerel hareket + duvar (AC2), uzak kopyanın
## tampondan çizilmesi (AC4).
## Ağ davranışı çok süreçli: tests/net/store_walk.json.

const SCENE := "res://entities/player/player.tscn"
const TUNING := "res://data/player_tuning.tres"
const PHYSICS_DT := 1.0 / 60.0
## Fizik katmanları (mimari.md §4).
const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_NPCS := 4


func _tuning() -> PlayerTuning:
	return load(TUNING) as PlayerTuning


## Ağaca eklenmiş oyuncu; `authority` 1 = yerel (çevrimdışı tekil kimlik 1), başka = uzak kopya.
func _spawn(authority: int = 1, at: Vector2 = Vector2.ZERO, parent: Node = null) -> Player:
	var player: Player = (load(SCENE) as PackedScene).instantiate() as Player
	player.name = str(authority)
	player.set_multiplayer_authority(authority, true)
	player.position = at
	if parent == null:
		parent = tree().root
		autofree(player)
	parent.add_child(player)
	return player


func _physics_frames(count: int) -> void:
	for i: int in count:
		await tree().physics_frame


func _process_frames(count: int) -> void:
	for i: int in count:
		await tree().process_frame


# --- ayarlar (AC2, S10) ---

func test_tuning_reads_data_file() -> void:
	var t: PlayerTuning = _tuning()
	if not is_true(t != null, "data/player_tuning.tres PlayerTuning olmalı"):
		return
	eq(t.walk_speed, 140.0)
	eq(t.sneak_speed, 70.0)
	eq(t.sprint_speed, 220.0)
	is_true(t.acceleration > 0.0 and t.deceleration > 0.0, "ivme ve fren pozitif")
	near(t.interpolation_delay, 0.1, 0.0001, "GDD §12: 100 ms tampon")
	# Değerlerin kaynağı dosya: betik varsayılanları nötr.
	var blank := PlayerTuning.new()
	eq(blank.walk_speed, 0.0)
	eq(blank.sprint_speed, 0.0)


func test_scene_uses_tuning_file() -> void:
	var player: Player = autofree((load(SCENE) as PackedScene).instantiate()) as Player
	is_true(player.tuning != null and player.tuning.resource_path == TUNING)


# --- PlayerMotion (AC2) ---

func test_mode_selection() -> void:
	eq(PlayerMotion.mode_for(false, false), PlayerMotion.Mode.WALK)
	eq(PlayerMotion.mode_for(false, true), PlayerMotion.Mode.SPRINT)
	eq(PlayerMotion.mode_for(true, false), PlayerMotion.Mode.SNEAK)
	eq(PlayerMotion.mode_for(true, true), PlayerMotion.Mode.SNEAK, "sızma koşmaya baskın")


func test_speed_by_mode() -> void:
	var t: PlayerTuning = _tuning()
	eq(PlayerMotion.speed_for(t, PlayerMotion.Mode.WALK), 140.0)
	eq(PlayerMotion.speed_for(t, PlayerMotion.Mode.SNEAK), 70.0)
	eq(PlayerMotion.speed_for(t, PlayerMotion.Mode.SPRINT), 220.0)
	eq(PlayerMotion.speed_for(t, 99), 140.0, "bilinmeyen kip yürüme")


func test_velocity_reaches_mode_speed_and_caps() -> void:
	var t: PlayerTuning = _tuning()
	for mode: int in [PlayerMotion.Mode.WALK, PlayerMotion.Mode.SNEAK, PlayerMotion.Mode.SPRINT]:
		var v := Vector2.ZERO
		v = PlayerMotion.step_velocity(v, Vector2.RIGHT, mode, t, PHYSICS_DT)
		near(v.x, minf(t.acceleration * PHYSICS_DT, PlayerMotion.speed_for(t, mode)), 0.001, "ilk adım ivmeyle")
		for i: int in 60:
			v = PlayerMotion.step_velocity(v, Vector2.RIGHT, mode, t, PHYSICS_DT)
		near(v, Vector2(PlayerMotion.speed_for(t, mode), 0.0), 0.001, "kip %d tam hız, aşmaz" % mode)


func test_velocity_eight_directions_and_analog() -> void:
	var t: PlayerTuning = _tuning()
	var diagonal: Vector2 = _settle(Vector2(1, 1), PlayerMotion.Mode.WALK, t)
	near(diagonal.length(), 140.0, 0.01, "klavye çaprazı hızlandırmaz")
	near(diagonal.normalized(), Vector2(1, 1).normalized(), 0.001)
	var half: Vector2 = _settle(Vector2(0, -0.5), PlayerMotion.Mode.WALK, t)
	near(half, Vector2(0, -70), 0.01, "yarım çubuk = yarım hız")
	var too_long: Vector2 = _settle(Vector2(3, 0), PlayerMotion.Mode.SNEAK, t)
	near(too_long, Vector2(70, 0), 0.01, "yön uzunluğu 1'e kırpılır")


func test_velocity_brakes_to_stop_and_on_slower_mode() -> void:
	var t: PlayerTuning = _tuning()
	var v: Vector2 = _settle(Vector2.RIGHT, PlayerMotion.Mode.SPRINT, t)
	var slowed: Vector2 = PlayerMotion.step_velocity(v, Vector2.RIGHT, PlayerMotion.Mode.WALK, t, PHYSICS_DT)
	near(slowed.x, 220.0 - t.deceleration * PHYSICS_DT, 0.001, "yavaş kipe frenle geçilir")
	for i: int in 30:
		v = PlayerMotion.step_velocity(v, Vector2.ZERO, PlayerMotion.Mode.WALK, t, PHYSICS_DT)
	eq(v, Vector2.ZERO, "girdi yokken durur")


func test_facing_follows_input_and_keeps_when_idle() -> void:
	eq(PlayerMotion.facing_for(Vector2.DOWN, Vector2(0, -0.3)), Vector2.UP)
	near(PlayerMotion.facing_for(Vector2.DOWN, Vector2(1, 1)), Vector2(1, 1).normalized(), 0.0001)
	eq(PlayerMotion.facing_for(Vector2.LEFT, Vector2.ZERO), Vector2.LEFT)


func _settle(direction: Vector2, mode: int, t: PlayerTuning) -> Vector2:
	var v := Vector2.ZERO
	for i: int in 120:
		v = PlayerMotion.step_velocity(v, direction, mode, t, PHYSICS_DT)
	return v


# --- sahne (AC1) ---

func test_scene_structure() -> void:
	var player: Player = autofree((load(SCENE) as PackedScene).instantiate()) as Player
	if not is_true(player != null, "kök Player (CharacterBody2D) olmalı"):
		return
	eq(player.collision_layer, LAYER_PLAYERS, "katman players")
	# US-008: NPC-oyuncu çarpışması yok (GDD §9.2, KR-021; npcs katmanı oyuncu maskesinde değil).
	eq(player.collision_mask, LAYER_WORLD, "yalnız world ile çarpışır; oyuncular ve NPC'lerle değil")
	eq(player.collision_mask & LAYER_NPCS, 0)
	eq(player.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING)
	var body: CollisionShape2D = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	is_true(body != null and body.shape is CircleShape2D and is_equal_approx((body.shape as CircleShape2D).radius, 12.0),
		"çap ~24 px (S4)")
	is_true(player.get_node_or_null("PlayerInput") is PlayerInput)
	var visual: Node = player.get_node_or_null("Visual")
	is_true(visual is PlayerVisual, "görsel ayrı alt düğüm (KR-003/KR-017)")
	is_true(visual != null and visual.get_node_or_null("NameLabel") is Label, "ad etiketi")
	is_true(player.get_node_or_null("Camera2D") is Camera2D)
	var sync: MultiplayerSynchronizer = player.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if not is_true(sync != null and sync.replication_config != null):
		return
	near(sync.replication_interval, 0.05, 0.0001, "20 Hz")
	var props: Array[String] = []
	for path: NodePath in sync.replication_config.get_properties():
		props.append(str(path))
		eq(sync.replication_config.property_get_replication_mode(path), SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
			"%s her aralıkta (güvenilmez) yayılır" % path)
	props.sort()
	eq(props, [".:net_facing", ".:net_mode", ".:net_position", ".:net_time"], "konum/yön/kip + gönderen anı")


func test_camera_and_input_only_on_local_player() -> void:
	var local: Player = _spawn(1)
	var remote: Player = _spawn(2, Vector2(100, 0))
	is_true(local.is_local() and not remote.is_local())
	is_true((local.get_node("Camera2D") as Camera2D).enabled, "yerel kamera etkin")
	is_false((remote.get_node("Camera2D") as Camera2D).enabled, "uzak kopyada kamera kapalı")
	eq((local.get_node("PlayerInput") as PlayerInput).source(), PlayerInput.Source.DEVICE)
	eq((remote.get_node("PlayerInput") as PlayerInput).source(), PlayerInput.Source.NONE, "uzakta girdi okunmaz")
	eq(local.peer_id(), 1)
	eq(remote.peer_id(), 2)


func test_visual_color_and_name_from_identity() -> void:
	# Renk yuvadan, ad Game.players()'tan (S3); iki farklı yuva, boş olmayan adlar.
	var before: Dictionary = Game.players()
	Game._rpc_players({2: {"name": "Ayşe", "slot": 1}, 3: {"name": "Bora", "slot": 2}})
	var a: Player = _spawn(2, Vector2(100, 0))
	var b: Player = _spawn(3, Vector2(200, 0))
	var va: PlayerVisual = a.get_node("Visual") as PlayerVisual
	var vb: PlayerVisual = b.get_node("Visual") as PlayerVisual
	eq(a.slot(), 1)
	eq(b.slot(), 2)
	eq(va.body_color(), ThemeTokens.PLAYER_COLORS[1])
	eq(vb.body_color(), ThemeTokens.PLAYER_COLORS[2])
	is_true(va.body_color() != vb.body_color(), "farklı yuva farklı renk")
	eq(va.label_text(), "Ayşe")
	eq(vb.label_text(), "Bora")
	# Kimlik sonradan değişince görsel izler (identity_changed).
	Game._rpc_players({2: {"name": "Cem", "slot": 0}, 3: {"name": "Bora", "slot": 2}})
	eq(va.body_color(), ThemeTokens.PLAYER_COLORS[0])
	eq(va.label_text(), "Cem")
	Game._rpc_players(before)


func test_name_label_is_not_auto_translated_and_has_fallback() -> void:
	var before: Dictionary = Game.players()
	is_true(tr("PAUSE_TITLE") != "PAUSE_TITLE", "ön koşul: anahtar çevrilir")
	Game._rpc_players({2: {"name": "PAUSE_TITLE", "slot": 0}, 3: {"name": "", "slot": 1}})
	var keyed: Player = _spawn(2, Vector2(100, 0))
	var unnamed: Player = _spawn(3, Vector2(200, 0))
	var label: Label = keyed.get_node("Visual/NameLabel") as Label
	is_false(label.can_auto_translate(), "ad etiketi otomatik çevrilmez")
	eq((keyed.get_node("Visual") as PlayerVisual).label_text(), "PAUSE_TITLE")
	eq(label.atr(label.text), "PAUSE_TITLE", "çeviri anahtarına denk gelen ad aynen görünür")
	var fallback: String = (unnamed.get_node("Visual") as PlayerVisual).label_text()
	eq(fallback, tr("HUD_PLAYER_UNNAMED") % 3, "boş ad: HUD ile aynı yedek")
	is_true(fallback != "HUD_PLAYER_UNNAMED" and fallback.contains("3"), "yedek çevrilmiş ve peer kimlikli: %s" % fallback)
	Game._rpc_players(before)


# --- hareket (AC2) ---

func test_local_player_walks_and_stops_at_wall() -> void:
	var world: Node2D = autofree(Node2D.new()) as Node2D
	tree().root.add_child(world)
	var wall := StaticBody2D.new()
	wall.collision_layer = LAYER_WORLD
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 256)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	wall.position = Vector2(116, 0)  # sol kenar x = 100
	world.add_child(wall)
	await _physics_frames(1)
	var player: Player = _spawn(1, Vector2.ZERO, world)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sneak", "dur": 0.4}]))
	await _physics_frames(24)  # 0,4 sn sızma: ~70 px/sn
	is_true(player.position.x > 20.0 and player.position.x < 30.0, "0,4 sn sızma ~26 px, gelen %s" % player.position.x)
	await _physics_frames(60)
	eq(player.move_mode, PlayerMotion.Mode.WALK, "sızma süresi bitti")
	near(player.position, Vector2(100.0 - 12.0, 0.0), 0.5, "duvardan geçmez, kenarında durur")
	is_false(player.overlaps_world(), "duvar içinde değil")
	eq(player.facing, Vector2.RIGHT)
	near(player.net_position, player.position, 0.001, "ağ alanı yerel konumu yansıtır")


# --- uzak kopya (AC4) ---

func test_remote_copy_draws_from_buffer_not_raw() -> void:
	# Ham uygulamayı (gelen net_position'ı doğrudan konuma yazmak) ayırt eder: ikinci görüntü gelince konum
	# hemen sıçramaz (tampon gecikmesi), arada iki görüntü arasında kalır ve hız iki görüntüden türer.
	var player: Player = _spawn(2, Vector2(5, 5))
	await _physics_frames(2)
	near(player.position, Vector2(5, 5), 0.001, "veri yokken konuma dokunulmaz (Game yetiştirmesi yazar)")
	var sync: MultiplayerSynchronizer = player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
	var sender_start: float = Time.get_ticks_usec() / 1_000_000.0 - 1.0  # gönderen saati: fark yalnız saat kayması
	player.net_position = Vector2(40, 0)
	player.net_facing = Vector2.LEFT
	player.net_mode = PlayerMotion.Mode.SNEAK
	player.net_time = sender_start
	sync.synchronized.emit()
	await _process_frames(2)  # process_frame sinyali düğümlerin _process'inden önce gelir
	near(player.position, Vector2(40, 0), 0.001, "ilk görüntüde beklenir")
	eq(player.facing, Vector2.LEFT)
	eq(player.move_mode, PlayerMotion.Mode.SNEAK)
	eq(player.velocity, Vector2.ZERO)
	# İkinci görüntü gönderen saatinde SPAN sn sonra (yürüme hızında 40 -> 96). SPAN, saat farkı sıfırlama eşiğinin
	# (0,5 sn) altında; hemen gelmesi saat farkını ~SPAN × 0,05 kadar kaydırır, çizim ~(delay - 0,02) sn geride kalır.
	const SPAN := 0.4
	var target := Vector2(40.0 + 140.0 * SPAN, 0.0)
	player.net_position = target
	player.net_facing = Vector2.UP
	player.net_mode = PlayerMotion.Mode.WALK
	player.net_time = sender_start + SPAN
	sync.synchronized.emit()
	await _process_frames(2)
	near(player.position, Vector2(40, 0), 0.001, "tampon gecikmesi: yeni görüntüye hemen sıçramaz")
	eq(player.facing, Vector2.LEFT, "yön de tampondan")
	eq(player.move_mode, PlayerMotion.Mode.SNEAK, "kip de tampondan")
	# Çizim anı iki görüntü arasına girince ara değerlenir (pencere ~0,08..0,48 sn).
	await tree().create_timer(0.25).timeout
	await _process_frames(2)
	is_true(player.position.x > 40.5 and player.position.x < target.x - 0.5,
		"iki görüntü arasında ara değer, gelen %s" % player.position)
	near(player.position.y, 0.0, 0.001)
	near(player.velocity, Vector2(140.0, 0.0), 0.01, "hız iki görüntü arasından (ham kopyada 0 kalır)")
	is_true(not player.facing.is_equal_approx(Vector2.LEFT) and not player.facing.is_equal_approx(Vector2.UP),
		"yön ara değerlenir, gelen %s" % player.facing)
	near(player.facing.length(), 1.0, 0.001)
	eq(player.move_mode, PlayerMotion.Mode.SNEAK, "kip önceki görüntüden")
	# Tampon geçince son görüntüde beklenir; ileri tahmin yok.
	await tree().create_timer(0.45).timeout
	await _process_frames(2)
	near(player.position, target, 0.001, "tampon geçince son görüntü")
	eq(player.velocity, Vector2.ZERO, "son görüntüden öteye tahmin yok")
	eq(player.facing, Vector2.UP)
	eq(player.move_mode, PlayerMotion.Mode.WALK)
