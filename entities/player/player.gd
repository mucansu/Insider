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

signal identity_changed()

const DUMP_KEY := "player_states"
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


func _ready() -> void:
	if tuning == null:
		push_error("Player: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PlayerTuning
	_local = is_multiplayer_authority()
	_buffer = SnapshotBuffer.new(tuning.interpolation_delay)
	_camera.enabled = _local
	if _local:
		_camera.zoom = Vector2.ONE * tuning.camera_zoom
		_camera.make_current()
		_camera.reset_smoothing()
		_publish()
		if not Args.dump_path.is_empty():
			Game.register_dump_provider(DUMP_KEY, _dump_states)
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
	if _track_walls and overlaps_world():
		_wall_frames += 1


func _process(_delta: float) -> void:
	if _local:
		return
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


## Etkileşim sürüyor mu (US-005 doldurur; görsel okur).
func is_interacting() -> bool:
	return _interacting


func set_interacting(value: bool) -> void:
	_interacting = value


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
