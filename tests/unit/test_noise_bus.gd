extends TestCase
## US-009 AC1, AC3, AC5, AC6 (tek süreç; çevrimdışı tekil kimlik 1 = host, ya da Net.host oturumu):
## NoiseBus host yayılımı (dinleyiciler + halka olayı), istemci isteğinin host doğrulaması (`host_request` = RPC
## gövdesi; hile: başka peer adına, uzak konumda, sonuç türünde ses yok, istemcinin yarıçapına güvenilmez),
## yayımcılar (oyuncu koşu adımı ≤ ~3 Hz, yürüme/sızma sessiz, uzak kopya yaymaz; kapı aç/kapa; kasa sürerken ve
## tamamlanınca), halka görseli (≥ 22 px, 0,4 sn, hareket azaltmada da görünür, seviye altında).
## Ağ: tests/net/noise_ring.json. Yalnız genel API (§6): `_` üyelere erişim yok.

const NOISE_BUS := "res://autoload/noise.gd"
const RING_SCENE := "res://entities/fx/noise_ring.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const DOOR_SCENE := "res://entities/props/door.tscn"
const REGISTER_SCENE := "res://entities/props/register.tscn"
const LEVEL := "res://tests/fixtures/empty_level.tscn"
const R := NoiseRules.Result
const DT := 1.0 / 60.0


## Dinleyici taklidi: `hear_noise` çağrılarını kaydeder.
class FakeListener:
	extends Node
	var calls: Array = []

	func _ready() -> void:
		add_to_group(&"noise_listener")

	func hear_noise(pos: Vector2, radius: float, kind: StringName) -> void:
		calls.append([pos, radius, kind])


## Etkileşim aktörü taklidi (S7: grup + interaction_position; host'un bildiği konum).
class FakeActor:
	extends Node2D

	func interaction_position() -> Vector2:
		return global_position


var _shown: Array = []


func _bus() -> Node:
	var bus: Node = autofree((load(NOISE_BUS) as GDScript).new()) as Node
	tree().root.add_child(bus)
	bus.connect(&"noise_shown", _on_shown)
	return bus


func _on_shown(pos: Vector2, radius: float, kind: StringName) -> void:
	_shown.append([pos, radius, kind])


func _listener() -> FakeListener:
	var listener := FakeListener.new()
	tree().root.add_child(listener)
	autofree(listener)
	return listener


func _actor(peer_id: int, at: Vector2) -> FakeActor:
	var actor := FakeActor.new()
	actor.set_multiplayer_authority(peer_id)
	actor.position = at
	actor.add_to_group(&"interaction_actors")
	tree().root.add_child(actor)
	autofree(actor)
	return actor


func _physics_frames(count: int) -> void:
	for i: int in count:
		await tree().physics_frame


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


# --- NoiseBus host yayılımı (AC1) ---

func test_host_emit_reaches_listeners_and_rings() -> void:
	var bus: Node = _bus()
	var a: FakeListener = _listener()
	var b: FakeListener = _listener()
	bus.call(&"emit_noise", Vector2(10, 20), 120.0, &"run", 1)
	eq(a.calls, [[Vector2(10, 20), 120.0, &"run"]], "host noise_listener grubunu çağırır")
	eq(b.calls.size(), 1)
	eq(_shown, [[Vector2(10, 20), 120.0, &"run"]], "halka olayı (host'ta yerel)")
	bus.call(&"emit_noise", Vector2(10, 20), 0.0, &"sneak", 1)
	eq(a.calls.size(), 1, "sıfır yarıçap yayılmaz (sızma/yürüme)")
	bus.call(&"emit_noise", Vector2(NAN, 0), 90.0, &"register", 0)
	eq(a.calls.size(), 1, "geçersiz konum yayılmaz")
	var stats: Dictionary = bus.call(&"stats")
	eq(stats["emitted"], 1)
	eq(stats["dispatched"], 1)
	eq(stats["delivered"], 2)
	eq(stats["rings"], 1)
	eq(stats["ring_kinds"], {"run": 1})
	eq(stats["accepted"], 0, "yerel host çağrısı istemci isteği değildir")


# --- istemci isteği: host doğrulaması (AC1, AC6 hile) ---

func test_client_request_accepted_with_host_radius() -> void:
	var bus: Node = _bus()
	var listener: FakeListener = _listener()
	_actor(5, Vector2(300, 300))
	eq(bus.call(&"host_request", 5, Vector2(310, 300), &"run", 5, 10.0), R.OK)
	eq(listener.calls, [[Vector2(310, 300), 120.0, &"run"]], "yarıçap host'un tanımından (istemci yollamaz)")
	eq(_shown.size(), 1)
	eq(bus.call(&"host_request", 5, Vector2(300, 320), &"run", 0, 10.35), R.OK, "kaynak 0 = gönderen")
	eq((bus.call(&"stats") as Dictionary)["accepted"], 2)


func test_client_cannot_cheat() -> void:
	var bus: Node = _bus()
	var listener: FakeListener = _listener()
	_actor(5, Vector2(300, 300))
	_actor(7, Vector2(800, 300))
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"run", 7), R.FOREIGN_PEER, "başka peer adına ses yok")
	eq(bus.call(&"host_request", 5, Vector2(800, 300), &"run", 5), R.TOO_FAR, "başkasının yanında ses yok")
	eq(bus.call(&"host_request", 5, Vector2(300 + NoiseRules.POSITION_TOLERANCE + 1.0, 300), &"run", 5), R.TOO_FAR)
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"door", 5), R.KIND_NOT_ALLOWED, "istemci kapı sesi üretemez")
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"register", 0), R.KIND_NOT_ALLOWED)
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"sneak", 5), R.SILENT, "sızma sessiz")
	eq(bus.call(&"host_request", 9, Vector2(300, 300), &"run", 9), R.NO_ACTOR, "aktörü olmayan peer")
	eq(bus.call(&"host_request", 0, Vector2(300, 300), &"run", 0), R.FOREIGN_PEER)
	eq(listener.calls.size(), 0, "reddedilen ses dinleyiciye ulaşmaz")
	eq(_shown.size(), 0, "reddedilen ses halka göstermez")
	var stats: Dictionary = bus.call(&"stats")
	eq(stats["accepted"], 0)
	eq(stats["rejected_total"], 8)
	eq((stats["rejected"] as Dictionary).get("too_far"), 2)


func test_client_rate_limit() -> void:
	var bus: Node = _bus()
	var listener: FakeListener = _listener()
	_actor(5, Vector2(300, 300))
	_actor(6, Vector2(500, 300))
	var interval: float = NoiseProfile.load_default().step_interval
	var gap: float = interval * NoiseRules.CLIENT_RATE_FACTOR
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"run", 5, 20.0), R.OK)
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"run", 5, 20.0 + gap - 0.02), R.RATE, "çok sık: red")
	eq(bus.call(&"host_request", 6, Vector2(500, 300), &"run", 6, 20.0 + 0.01), R.OK, "sınır gönderen başına")
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"run", 5, 20.0 + gap + 0.01), R.OK,
		"son kabulden yarım aralık sonra kabul (reddedilen istek süreyi sıfırlamaz)")
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"run", 5, 20.0 + gap + 0.01 + interval), R.OK, "dürüst tempo")
	# Hileli istek (uzak konum) tempo sayacını ilerletmez; tempo reddi dinleyiciye ulaşmaz.
	eq(bus.call(&"host_request", 5, Vector2(900, 900), &"run", 5, 30.0), R.TOO_FAR)
	eq(bus.call(&"host_request", 5, Vector2(300, 300), &"run", 5, 30.01), R.OK)
	eq(listener.calls.size(), 5)
	eq((bus.call(&"stats") as Dictionary)["rejected"], {"rate": 1, "too_far": 1})


# --- yayımcılar (AC3) ---

func test_player_sprint_steps_emit_at_most_3hz() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.set_multiplayer_authority(1, true)
	player.position = Vector2(4000, 4000)
	tree().root.add_child(player)
	autofree(player)
	NoiseBus.noise_shown.connect(_on_shown)
	(player.get_node("PlayerInput") as PlayerInput).use_bot(BotTimeline.from_raw([
		{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sprint", "dur": 1.2},
		{"t": 1.2, "hold": "sneak"}, {"t": 2.4, "move": [0, 0]},
	]))
	await _physics_frames(72)
	var run: Array = _shown.duplicate()
	await _physics_frames(84)
	NoiseBus.noise_shown.disconnect(_on_shown)
	if not is_true(run.size() >= 3 and run.size() <= 5, "1,2 sn koşu: ~3 Hz adım sesi, gelen %d" % run.size()):
		return
	for item: Array in run:
		eq([item[1], item[2]], [120.0, &"run"], "koşu: 120 px")
	near(run[0][0], Vector2(4000, 4000), 30.0, "ses oyuncunun konumunda")
	eq(_shown.size(), run.size(), "sızma (hareket ederken) sessiz")
	eq(player.move_mode, PlayerMotion.Mode.SNEAK)


func test_walking_and_remote_copies_are_silent() -> void:
	var local: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	local.name = "1"
	local.set_multiplayer_authority(1, true)
	local.position = Vector2(5000, 4000)
	tree().root.add_child(local)
	autofree(local)
	var remote: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	remote.name = "2"
	remote.set_multiplayer_authority(2, true)
	remote.position = Vector2(5000, 4200)
	tree().root.add_child(remote)
	autofree(remote)
	NoiseBus.noise_shown.connect(_on_shown)
	(local.get_node("PlayerInput") as PlayerInput).use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [1, 0]}]))
	(remote.get_node("PlayerInput") as PlayerInput).use_bot(BotTimeline.from_raw([
		{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sprint"}]))
	await _physics_frames(45)
	NoiseBus.noise_shown.disconnect(_on_shown)
	is_true(local.velocity.length() > 100.0, "yerel oyuncu yürüdü")
	eq(_shown.size(), 0, "yürüme sessiz; uzak kopya ses üretmez")


func test_sprint_into_wall_is_silent() -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(6000 + 13 + 16, 4000)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 128)
	shape.shape = rect
	wall.add_child(shape)
	tree().root.add_child(wall)
	autofree(wall)
	await _physics_frames(2)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.set_multiplayer_authority(1, true)
	player.position = Vector2(6000, 4000)
	tree().root.add_child(player)
	autofree(player)
	(player.get_node("PlayerInput") as PlayerInput).use_bot(BotTimeline.from_raw([
		{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sprint"}]))
	await _physics_frames(10)
	NoiseBus.noise_shown.connect(_on_shown)
	await _physics_frames(40)
	NoiseBus.noise_shown.disconnect(_on_shown)
	eq(player.move_mode, PlayerMotion.Mode.SPRINT)
	near(player.position.x, 6000.0, 2.0, "duvara dayalı")
	eq(_shown.size(), 0, "koşu tuşu basılı ama hız eşiğin altında: sessiz")


func test_door_emits_on_open_and_close() -> void:
	var door: Door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	door.position = Vector2(7000, 4000)
	tree().root.add_child(door)
	autofree(door)
	_actor(1, Vector2(7000, 4020))
	NoiseBus.noise_shown.connect(_on_shown)
	var item: Interactable = door.get_node("Interactable") as Interactable
	var was_open: bool = door.is_open
	item.request_start(1)
	eq(door.is_open, not was_open)
	await _physics_frames(20)  # tekrar beklemesi (REPEAT_COOLDOWN) dolsun
	item.request_start(2)
	NoiseBus.noise_shown.disconnect(_on_shown)
	eq(door.is_open, was_open)
	eq(_shown, [[Vector2(7000, 4000), 160.0, &"door"], [Vector2(7000, 4000), 160.0, &"door"]], "aç ve kapa: 160 px")


func test_register_emits_while_emptying_and_on_complete() -> void:
	# Doğal fizik yolu (gerçek fizik kareleri; item.step yok): 3 sn tam boşaltma = 1. ve 2. sn tempo sesi + bitiş
	# sesi; bitişe denk gelen 3. tempo sesi bastırılır (aynı noktada art arda iki ses yok).
	eq(Net.host(free_udp_port()), OK)
	var reg: Register = (load(REGISTER_SCENE) as PackedScene).instantiate() as Register
	reg.position = Vector2(8000, 4000)
	tree().root.add_child(reg)
	autofree(reg)
	_actor(1, Vector2(8028, 4000))
	var frames: Array[int] = []
	var counter: Array[int] = [0]
	var on_frame := func() -> void: counter[0] += 1
	tree().physics_frame.connect(on_frame)
	var on_noise := func(_pos: Vector2, _radius: float, _kind: StringName) -> void: frames.append(counter[0])
	NoiseBus.noise_shown.connect(on_noise)
	NoiseBus.noise_shown.connect(_on_shown)
	var item: Interactable = reg.get_node("Interactable") as Interactable
	item.request_start(1)
	await _physics_frames(45)
	eq(_shown.size(), 0, "ilk ses register_interval (1 sn) sonra")
	await _physics_frames(30)
	eq(_shown, [[Vector2(8000, 4000), 90.0, &"register"]], "boşaltma sürerken (~1 sn)")
	await _physics_frames(130)  # toplam ~3,4 sn: tam süre dolar (3 sn)
	is_true(reg.emptied, "3 sn tutunca boşaldı")
	await _physics_frames(70)
	NoiseBus.noise_shown.disconnect(on_noise)
	NoiseBus.noise_shown.disconnect(_on_shown)
	tree().physics_frame.disconnect(on_frame)
	eq(_shown.size(), 3, "1 sn + 2 sn + bitiş = 3 ses (çift bitiş sesi yok); kareler %s" % [frames])
	for item_shown: Array in _shown:
		eq([item_shown[1], item_shown[2]], [90.0, &"register"])
	for i: int in range(1, frames.size()):
		is_true(frames[i] - frames[i - 1] >= 30, "sesler arası ≥ 0,5 sn: %s" % [frames])
	Net.leave()
	await tree().process_frame
	await tree().process_frame


# --- halka görseli (AC5) ---

func test_ring_geometry() -> void:
	eq(NoiseRing.DURATION, 0.4, "0,4 sn")
	is_true(NoiseRing.MIN_RADIUS * 2.0 >= 22.0, "≥ 22 px okunurluk (GDD §14.1 kural 2)")
	eq(NoiseRing.ring_radius(0.0, 120.0, false), NoiseRing.MIN_RADIUS, "küçükten başlar")
	near(NoiseRing.ring_radius(0.4, 120.0, false), 120.0, 0.001, "sesin yarıçapına genişler")
	var mid: float = NoiseRing.ring_radius(0.2, 120.0, false)
	is_true(mid > NoiseRing.MIN_RADIUS and mid < 120.0)
	eq(NoiseRing.ring_radius(0.0, 4.0, false), NoiseRing.MIN_RADIUS, "küçük ses de ≥ 22 px")
	eq(NoiseRing.ring_radius(0.4, 4.0, false), NoiseRing.MIN_RADIUS)
	# Hareket azaltma: genişleme yok, baştan tam yarıçapta görünür.
	eq(NoiseRing.ring_radius(0.0, 120.0, true), 120.0)
	eq(NoiseRing.ring_radius(0.3, 120.0, true), 120.0)
	eq(NoiseRing.ring_radius(0.0, 4.0, true), NoiseRing.MIN_RADIUS)
	eq(NoiseRing.ring_alpha(0.0), 1.0)
	is_true(NoiseRing.ring_alpha(0.39) >= NoiseRing.END_ALPHA and NoiseRing.END_ALPHA > 0.0, "sona dek okunur")


func test_ring_lifetime_and_reduced_motion() -> void:
	for reduced: bool in [false, true]:
		NoiseRing.reduced_motion = reduced
		var ring: NoiseRing = (load(RING_SCENE) as PackedScene).instantiate() as NoiseRing
		tree().root.add_child(ring)
		autofree(ring)
		ring.setup(90.0)
		eq(ring.current_radius(), 90.0 if reduced else NoiseRing.MIN_RADIUS, "başta (azaltma %s)" % reduced)
		await tree().process_frame
		is_true(is_instance_valid(ring) and ring.is_inside_tree(), "görünür (azaltma %s)" % reduced)
		var deadline: int = Time.get_ticks_msec() + 2000
		while is_instance_valid(ring) and not ring.is_queued_for_deletion() and Time.get_ticks_msec() < deadline:
			await tree().process_frame
		is_true(not is_instance_valid(ring) or ring.is_queued_for_deletion(), "0,4 sn sonra kalkar")
	NoiseRing.reduced_motion = false


func test_ring_spawns_under_current_level() -> void:
	eq(Net.host(free_udp_port()), OK)
	Game.start_level(LEVEL)
	var level: Node = Game.current_level()
	if not is_true(level != null, "seviye yüklendi"):
		Net.leave()
		return
	NoiseBus.emit_noise(Vector2(300, 200), 120.0, &"run", 1)
	var rings: Array[Node] = []
	for child: Node in level.get_children():
		if child is NoiseRing:
			rings.append(child)
	eq(rings.size(), 1, "halka seviyenin altında (her peer kendi seviyesine ekler)")
	if rings.size() == 1:
		var ring: NoiseRing = rings[0] as NoiseRing
		eq(ring.global_position, Vector2(300, 200))
		eq(ring.radius, 120.0)
	Net.leave()
	await tree().process_frame
	await tree().process_frame
