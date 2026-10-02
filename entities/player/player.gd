class_name Player
extends CharacterBody2D
## Oyuncu karakteri (US-004; mimari.md S2, S3, S5, S6). Game'in PlayerSpawner'ı üretir: düğüm adı str(peer_id),
## yetki o peer'da, ilk konum spawn verisinden (S3). Hareket ve ağ mantığı burada, PlayerMotion'da (kurallar,
## düğümsüz) ve SnapshotBuffer'da (ara değerleme); görsel `Visual` alt düğümündedir ve yalnız şu durumu okur
## (KR-003, KR-017: Faz 2'de prosedürel kukla görseliyle değişir, buraya dokunulmaz):
##   velocity (hız), facing (birim bakış yönü), move_mode (PlayerMotion.Mode), is_interacting(),
##   peer_id(), slot(), display_name() ve identity_changed sinyali.
##
## Yerel (yetkili) kopya: her fizik adımında PlayerInput'u okur, hızı PlayerMotion ile hesaplar, move_and_slide
## eder (çarpışma: yalnız world; oyuncular birbirinin ve NPC'lerin içinden geçer — GDD §9.2/KR-021: NPC-oyuncu
## çarpışması yok, US-008) ve ağ alanlarını (net_*) yazar.
## Tahmin ya da sunucu onayı yok: istemci kendi hareketinde yetkilidir (S2), hareket anında görünür.
## MultiplayerSynchronizer net_* alanlarını 0,05 sn'de bir (20 Hz, güvenilmez) yayar.
## Uzak kopya: eşitleyici net_* alanlarını yazınca (`synchronized`) anlık görüntü SnapshotBuffer'a girer; konum,
## hız, yön ve kip her karede tampondan, `PlayerTuning.interpolation_delay` (~100 ms) geriden üretilir.
## Tampon boşken konuma dokunulmaz: Game'in geç katılana konum yetiştirmesi (S3) o arada konumu yazar.
##
## Otomasyon dökümü (S6, yalnız `--dump`): yerel oyuncu "player_states" anahtarını kaydeder:
## {"<peer_id>": {"mode": int, "facing": [x, y], "wall_frames": int, "underruns": int}} — süreçteki her oyuncu
## kopyası için; wall_frames kopyanın (yerel ya da ara değerlenmiş) duvar içinde olduğu fizik karesi sayısı,
## underruns uzak kopyada tamponun tükendiği kare sayısı (SnapshotBuffer).
##
## Etkileşim (US-005, S7 oyuncu tarafı): her kopya `Interactable.ACTOR_GROUP`'a girer ve host'un isteği
## doğruladığı konumu `interaction_position()` ile sunar. Yalnız yerel kopyada `PlayerInteraction` alt düğümü
## her fizik adımında (hareketten sonra) hedef bulur ve istek/iptal yollar; aşağıdaki üç sinyal (HUD sözleşmesi)
## yalnız yerel oyuncuda yayılır. Dökümde (yalnız `--dump`) yerel oyuncu "interaction" anahtarını kaydeder:
## PlayerInteraction.stats(). US-004 hareket/senkron davranışı bundan etkilenmez.
## "Etkileşimde" durumu (IS-014; görsel göstergesi her peer'da aynı): yerel kopyada PlayerInteraction'dan (basışta
## hemen, karar gelince biter; GDD §12); uzak kopyada host'un çoğalttığı `Interactable.busy_by`'dan (bu oyuncunun
## tuttuğu bileşen varsa) her karede türetilir — ek ağ alanı yok. Kapı gibi anlık eylemler uzakta görünmez.
##
## Gürültü (US-009, S8): yalnız yerel kopya, hareketten sonra adım sesi yayar: kipin yarıçapı (NoiseProfile: koşu
## 120, yürüme/sızma 0) > 0 ve gerçek hız (`get_real_velocity`; duvara itmek sayılmaz) ≥ `step_min_speed` iken
## en fazla `step_interval`'da bir (NoiseRules.Cadence) `NoiseBus.emit_noise`; istemcide host doğrular (S2).
## Uzak kopya ses üretmez.
##
## Çanta (US-012): taşıma durumu çantadadır (Bag, host yetkili); oyuncu yalnız okur (`is_carrying`,
## `interaction_tags` → eli boşsa `free_hands`) ve koşuyu bildirir (`is_sprinting`); düşürme kuralı çantada (host).
##
## Tutulma/yakalanma (US-008, S3 eki): `Status` alt düğümü (PlayerStatus, host yetkili alt ağaç) FREE/HELD/CAUGHT
## durumunu taşır ve ÇEK kurtarma Interactable'ını barındırır. Yerel kopya FREE değilken donar: girdi okunmaz
## (hareket ve etkileşim kesilir, hız sıfır). Host API'si (`host_hold/host_catch/host_release`) NPC beyinlerinden
## çağrılır; `status_changed` her peer'da, `rescued` yalnız host'ta yayılır. Dökümde "player_states" + "status".

signal identity_changed()
## Yakındaki etkileşilebilir hedef değişti (boş dize = hedef yok); yalnız yerel oyuncuda (S7).
signal interaction_target_changed(action_key: String)
signal interaction_started(action_key: String, duration: float)
signal interaction_finished(success: bool)
## Her peer'da: tutulma/yakalanma durumu değişti (PlayerStatus.State).
signal status_changed(state: int)
## Yalnız host'ta: tutulan oyuncu ekip arkadaşınca kurtarıldı.
signal rescued(rescuer: int)

const DUMP_KEY := "player_states"
const INTERACTION_DUMP_KEY := "interaction"
const INTERACT_ACTION := &"interact"
const TUNING_PATH := "res://data/player_tuning.tres"
## Gövde şekli yoksa varsayılan yarıçap (S4: karakter çapı ~24 px).
const BODY_RADIUS := 12.0
## Duvar denetiminde gövde yarıçapından düşülen pay (px): kayarken temas "içinde" sayılmaz.
const WALL_CHECK_MARGIN := 2.0
## Fizik katmanı world (mimari.md §4).
const WORLD_MASK := PhysicsLayers.WORLD
## Koşu sayılması için en düşük hız (px/sn; US-012): koşu tuşu basılı ama duran oyuncu koşmuyor.
const SPRINT_MOVING_SPEED := 20.0

@export var tuning: PlayerTuning

## Ağ alanları: yalnız yetkili kopya yazar, eşitleyici yayar (S2: konum, yön, kip + gönderen anı).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.DOWN
var net_mode: int = PlayerMotion.Mode.WALK
## Yetkili kopyanın kendi saatinde net_position'ın yazıldığı an (sn); ara değerleme bu saate göre çizer.
var net_time: float = 0.0

## Görselin okuduğu durum (her kopyada; uzak kopyada tampondan).
var facing: Vector2 = Vector2.DOWN
var move_mode: int = PlayerMotion.Mode.WALK

var _local: bool = false
var _interacting: bool = false
var _buffer: SnapshotBuffer = null
var _slot: int = 0
var _display_name: String = ""
var _wall_query: PhysicsShapeQueryParameters2D = null
## Otomasyonda (S6) her fizik karesinde duvar denetimi yapılır ve sayılır.
var _track_walls: bool = false
var _wall_frames: int = 0
var _noise_profile: NoiseProfile = null
var _step_noise: NoiseRules.Cadence = null

@onready var _input: PlayerInput = $PlayerInput
@onready var _sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _camera: Camera2D = $Camera2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _interaction: PlayerInteraction = $PlayerInteraction
@onready var _status: PlayerStatus = $Status


func _ready() -> void:
	if tuning == null:
		push_error("Player: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PlayerTuning
	_local = is_multiplayer_authority()
	_buffer = SnapshotBuffer.new(tuning.interpolation_delay)
	_noise_profile = NoiseProfile.load_default()
	_step_noise = NoiseRules.Cadence.new(_noise_profile.step_interval)
	add_to_group(Interactable.ACTOR_GROUP)
	_camera.enabled = _local
	if _local:
		_setup_camera()
		_publish()
		_interaction.target_changed.connect(interaction_target_changed.emit)
		_interaction.started.connect(_on_interaction_started)
		_interaction.finished.connect(_on_interaction_finished)
		if not Args.dump_path.is_empty():
			Game.register_dump_provider(DUMP_KEY, _dump_states)
			Game.register_dump_provider(INTERACTION_DUMP_KEY, _interaction.stats)
	else:
		_sync.synchronized.connect(_on_synchronized)
	_track_walls = Args.is_automated()
	_status.changed.connect(status_changed.emit)
	_status.rescued.connect(rescued.emit)
	Game.players_changed.connect(_refresh_identity)
	_refresh_identity()


func _physics_process(delta: float) -> void:
	if _local:
		_input.poll(delta)
		var free: bool = _status.is_free()
		var direction: Vector2 = _input.move_vector() if free else Vector2.ZERO
		if free:
			move_mode = PlayerMotion.mode_for(_input.is_held(&"sneak"), _input.is_held(&"sprint"))
			velocity = PlayerMotion.step_velocity(velocity, direction, move_mode, tuning, delta)
		else:
			move_mode = PlayerMotion.Mode.WALK
			velocity = Vector2.ZERO  # tutuldu/yakalandı: donar
		move_and_slide()
		facing = PlayerMotion.facing_for(facing, direction)
		_publish()
		_emit_step_noise(delta)
		_interaction.tick(delta, free and _input.is_held(INTERACT_ACTION), global_position, peer_id(),
			interaction_tags())
	if _track_walls and overlaps_world():
		_wall_frames += 1


func _process(_delta: float) -> void:
	if _local:
		return
	_interacting = Interactable.held_by(get_tree(), peer_id()) != null
	var frame: SnapshotBuffer.Frame = _buffer.sample(_now())
	if frame == null:
		return
	position = frame.position
	velocity = frame.velocity
	facing = frame.facing
	move_mode = frame.mode


## Bu kopyanın sahibi olan peer (S3: yetki = peer_id).
func peer_id() -> int:
	return get_multiplayer_authority()


func is_local() -> bool:
	return _local


## Oyuncunun katılım yuvası (Game.players(); renk görselde ThemeTokens.PLAYER_COLORS[slot]).
func slot() -> int:
	return _slot


func display_name() -> String:
	return _display_name


## Etkileşim sürüyor mu (görsel okur): yerelde PlayerInteraction'dan, uzakta çoğaltılan busy_by'dan (her karede).
func is_interacting() -> bool:
	return _interacting


func set_interacting(value: bool) -> void:
	_interacting = value


## Tutulma/yakalanma durumu (PlayerStatus.State; her peer'da çoğaltılan).
func status() -> int:
	return _status.state


func is_free() -> bool:
	return _status.is_free()


func is_held() -> bool:
	return _status.is_held()


func is_caught() -> bool:
	return _status.is_caught()


## Tutma penceresinden kalan (sn; tutulmuyorsa 0).
func hold_left() -> float:
	return _status.hold_left()


## Yakalayan (host; S3 eki `player_caught {peer, by}`).
func caught_by() -> StringName:
	return _status.caught_by()


func times_held() -> int:
	return _status.times_held()


## Yalnız host: tutar (`window` sn sonra yakalanır; ÇEK ile kurtarılabilir).
func host_hold(window: float) -> bool:
	return _status.host_hold(window)


## Yalnız host: kalıcı yakalama; `by` yakalayan (&"chaser", &"owner"; S3 eki `player_caught {peer, by}`).
func host_catch(by: StringName = &"") -> bool:
	return _status.host_catch(by)


## Yalnız host: tutmayı bırakır.
func host_release() -> bool:
	return _status.host_release()


## Host'un etkileşim isteğini doğruladığı konum (S7, global): yerel kopyada şu anki konum; uzak kopyada
## eşitleyiciden gelen en güncel konum (ara değerlemeyle çizilen, ~100 ms geriden gelen konum değil; S2
## toleransı yalnız ağ gecikmesini karşılar). Henüz veri gelmediyse çizilen konum.
func interaction_position() -> Vector2:
	if _local or net_time <= 0.0:
		return global_position
	var parent: Node2D = get_parent() as Node2D
	return parent.to_global(net_position) if parent != null else net_position


## Etkileşim etiketleri (S7 `InteractionRequirement.required_tag`; host da aynı yöntemi okur). US-012: eli boşsa
## `free_hands` (çanta yalnız eli boşken alınır/devralınır).
func interaction_tags() -> Dictionary:
	return {} if is_carrying() else {HeistRules.FREE_HANDS_TAG: 1}


## Çanta taşıyor mu (US-012; durum çantada, host yetkili ve çoğaltılır).
func is_carrying() -> bool:
	return is_inside_tree() and Bag.carried_by(get_tree(), peer_id()) != null


## Koşuyor mu (US-012 çanta düşürme ve "Maratoncu" notu): koşu kipi ve gerçekten hareket ediyor. Uzak kopyada
## ara değerlenen kip ve hızdan.
func is_sprinting() -> bool:
	return move_mode == PlayerMotion.Mode.SPRINT and velocity.length() > SPRINT_MOVING_SPEED


## Gövde (kenar payı WALL_CHECK_MARGIN düşülmüş) world katmanıyla örtüşüyor mu.
func overlaps_world() -> bool:
	if _wall_query == null:
		_wall_query = _make_wall_query()
	_wall_query.transform = global_transform
	return not get_world_2d().direct_space_state.intersect_shape(_wall_query, 1).is_empty()


## Döküm/teşhis durumu.
func motion_state() -> Dictionary:
	return {
		"mode": move_mode,
		"facing": facing,
		"wall_frames": _wall_frames,
		"underruns": _buffer.underrun_count() if _buffer != null else 0,
		"status": _status.state if _status != null else PlayerStatus.State.FREE,
	}


## Yerel kameranın yakınlaştırması (IS-027): `--camera-zoom` verildiyse o, yoksa `tuning.camera_zoom`.
func camera_zoom() -> float:
	return Args.camera_zoom if Args.camera_zoom > 0.0 else tuning.camera_zoom


## Kamera sınırı (IS-027, global): harita dikdörtgeni `map`, kameranın gördüğü alan `view_size`'tan (viewport /
## zoom) dar olan eksende harita ortada kalacak biçimde görüş boyuna genişletilir (Camera2D dar sınırda sağ/alt
## kenara yaslanır; böylece kamera o eksende sabit, harita ortalı durur). Düğümsüz; birim testte doğrudan.
static func camera_limits(map: Rect2, view_size: Vector2) -> Rect2i:
	var out: Rect2 = map
	for axis: int in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		if map.size[axis] < view_size[axis]:
			out.position[axis] = map.get_center()[axis] - view_size[axis] * 0.5
			out.size[axis] = view_size[axis]
	var start := Vector2i(floori(out.position.x), floori(out.position.y))
	var end := Vector2i(ceili(out.end.x), ceili(out.end.y))
	return Rect2i(start, end - start)


func _setup_camera() -> void:
	_camera.zoom = Vector2.ONE * camera_zoom()
	_apply_camera_limits()
	get_viewport().size_changed.connect(_apply_camera_limits)
	_camera.make_current()
	_camera.reset_smoothing()


## Seviyenin harita dikdörtgenine (S4 `map_rect()`; ata düğümde ördek tipleme) kenetler; seviye yoksa sınırsız.
func _apply_camera_limits() -> void:
	var map: Rect2 = _level_map_rect()
	if not map.has_area():
		return
	var limits: Rect2i = camera_limits(map, get_viewport_rect().size / _camera.zoom)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y


func _level_map_rect() -> Rect2:
	var node: Node = get_parent()
	while node != null:
		if node.has_method(&"map_rect"):
			var rect: Rect2 = node.call(&"map_rect")
			var level: Node2D = node as Node2D
			return level.global_transform * rect if level != null else rect
		node = node.get_parent()
	return Rect2()


func _publish() -> void:
	net_position = position
	net_facing = facing
	net_mode = move_mode
	net_time = _now()


## Yerel kopya: koşu adımı sesi (S8). Tür ve yarıçap kipten; tempo ve hız eşiği NoiseProfile'dan.
func _emit_step_noise(delta: float) -> void:
	var kind: StringName = NoiseProfile.KIND_WALK
	match move_mode:
		PlayerMotion.Mode.SNEAK:
			kind = NoiseProfile.KIND_SNEAK
		PlayerMotion.Mode.SPRINT:
			kind = NoiseProfile.KIND_RUN
	var radius: float = _noise_profile.radius_for(kind)
	var stepping: bool = radius > 0.0 and get_real_velocity().length() >= _noise_profile.step_min_speed
	if _step_noise.tick(delta, stepping):
		NoiseBus.emit_noise(global_position, radius, kind, peer_id())


func _on_interaction_started(action_key: String, duration: float) -> void:
	_interacting = true
	interaction_started.emit(action_key, duration)


func _on_interaction_finished(success: bool) -> void:
	_interacting = false
	interaction_finished.emit(success)


func _on_synchronized() -> void:
	_buffer.push(net_time, _now(), net_position, net_facing, net_mode)


func _refresh_identity() -> void:
	var entry: Dictionary = Game.players().get(peer_id(), {})
	var new_slot: int = maxi(0, int(entry.get("slot", 0)))
	var new_name: String = str(entry.get("name", ""))
	if new_slot == _slot and new_name == _display_name:
		return
	_slot = new_slot
	_display_name = new_name
	identity_changed.emit()


func _make_wall_query() -> PhysicsShapeQueryParameters2D:
	var radius: float = BODY_RADIUS
	var circle: CircleShape2D = _body_shape.shape as CircleShape2D
	if circle != null:
		radius = circle.radius
	var shape := CircleShape2D.new()
	shape.radius = maxf(1.0, radius - WALL_CHECK_MARGIN)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = WORLD_MASK
	query.exclude = [get_rid()]
	return query


## Süreçteki bütün oyuncu kopyalarının durumu (S6 dökümü).
func _dump_states() -> Dictionary:
	var out: Dictionary = {}
	var root: Node = get_parent()
	if root == null:
		return out
	for child: Node in root.get_children():
		var player: Player = child as Player
		if player != null:
			out[str(player.peer_id())] = player.motion_state()
	return out


static func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
