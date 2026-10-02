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
## eder (çarpışma: world ve npcs katmanları; oyuncular birbirinin içinden geçer) ve ağ alanlarını (net_*) yazar.
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

signal identity_changed()
## Yakındaki etkileşilebilir hedef değişti (boş dize = hedef yok); yalnız yerel oyuncuda (S7).
signal interaction_target_changed(action_key: String)
signal interaction_started(action_key: String, duration: float)
signal interaction_finished(success: bool)

const DUMP_KEY := "player_states"
const INTERACTION_DUMP_KEY := "interaction"
const INTERACT_ACTION := &"interact"
const TUNING_PATH := "res://data/player_tuning.tres"
## Gövde şekli yoksa varsayılan yarıçap (S4: karakter çapı ~24 px).
const BODY_RADIUS := 12.0
## Duvar denetiminde gövde yarıçapından düşülen pay (px): kayarken temas "içinde" sayılmaz.
const WALL_CHECK_MARGIN := 2.0
## Fizik katmanı world (mimari.md §4).
const WORLD_MASK := 1

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

@onready var _input: PlayerInput = $PlayerInput
@onready var _sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _camera: Camera2D = $Camera2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _interaction: PlayerInteraction = $PlayerInteraction


func _ready() -> void:
	if tuning == null:
		push_error("Player: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PlayerTuning
	_local = is_multiplayer_authority()
	_buffer = SnapshotBuffer.new(tuning.interpolation_delay)
	add_to_group(Interactable.ACTOR_GROUP)
	_camera.enabled = _local
	if _local:
		_camera.zoom = Vector2.ONE * tuning.camera_zoom
		_camera.make_current()
		_camera.reset_smoothing()
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
	Game.players_changed.connect(_refresh_identity)
	_refresh_identity()


func _physics_process(delta: float) -> void:
	if _local:
		_input.poll(delta)
		var direction: Vector2 = _input.move_vector()
		move_mode = PlayerMotion.mode_for(_input.is_held(&"sneak"), _input.is_held(&"sprint"))
		velocity = PlayerMotion.step_velocity(velocity, direction, move_mode, tuning, delta)
		move_and_slide()
		facing = PlayerMotion.facing_for(facing, direction)
		_publish()
		_interaction.tick(delta, _input.is_held(INTERACT_ACTION), global_position, peer_id())
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


## Host'un etkileşim isteğini doğruladığı konum (S7, global): yerel kopyada şu anki konum; uzak kopyada
## eşitleyiciden gelen en güncel konum (ara değerlemeyle çizilen, ~100 ms geriden gelen konum değil; S2
## toleransı yalnız ağ gecikmesini karşılar). Henüz veri gelmediyse çizilen konum.
func interaction_position() -> Vector2:
	if _local or net_time <= 0.0:
		return global_position
	var parent: Node2D = get_parent() as Node2D
	return parent.to_global(net_position) if parent != null else net_position


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
	}


func _publish() -> void:
	net_position = position
	net_facing = facing
	net_mode = move_mode
	net_time = _now()


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
