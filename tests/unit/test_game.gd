extends TestCase
## Game (autoload/game.gd, S3) single-process unit tests (US-001 AC5/AC7): dump merging, JSON conversion, host session
## (player registry, cash, events, level + PlayerSpawner, local player), end-of-session cleanup.
## Client/late-join behaviour is multi-process: tests/net/*.json.

const LEVEL := "res://tests/fixtures/empty_level.tscn"
const LEVEL_B := "res://tests/fixtures/empty_level_b.tscn"
const PLAYER := "res://tests/fixtures/dummy_player.tscn"

var _cash_values: Array[int] = []
var _events: Array[StringName] = []
var _locals: Array[Node] = []
var _levels: int = 0


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _on_cash(v: int) -> void:
	_cash_values.append(v)


func _on_event(kind: StringName, _data: Dictionary) -> void:
	_events.append(kind)


func _on_local(p: Node) -> void:
	_locals.append(p)


func _on_level(_l: Node) -> void:
	_levels += 1


func test_to_json_value() -> void:
	var v: Variant = Game.to_json_value({
		1: Vector2(1.5, -2), &"k": [Vector2i(3, 4), Color(1, 0, 0, 1), &"x", null],
		"n": {"deep": Vector3(1, 2, 3)}, "f": 2.5, "b": true,
	})
	eq(v, {"1": [1.5, -2.0], "k": [[3, 4], "#ff0000ff", "x", null], "n": {"deep": [1.0, 2.0, 3.0]}, "f": 2.5, "b": true})
	is_true(JSON.stringify(v).begins_with("{"), "JSON'a yazılabilir")


func test_dump_merges_providers() -> void:
	Game.register_dump_provider("unit_custom", func() -> Dictionary: return {"pos": Vector2(1, 2), "tag": &"t"})
	Game.register_dump_provider("unit_list", func() -> Array: return [1, 2])
	Game.register_dump_provider("peers", func() -> int: return 99)  # base key: rejected
	Game.register_dump_provider("", func() -> int: return 1)  # invalid key
	var dump: Dictionary = Game.collect_dump()
	for key: String in Game.BASE_DUMP_KEYS:
		has(dump, key)
	eq(dump["unit_custom"], {"pos": [1.0, 2.0], "tag": "t"})
	eq(dump["unit_list"], [1, 2])
	eq(dump["peers"], [], "taban anahtar sağlayıcıyla ezilemez")
	is_false(dump.has(""))
	# Re-registering the same key keeps the last registration.
	Game.register_dump_provider("unit_list", func() -> String: return "yeni")
	eq(Game.collect_dump()["unit_list"], "yeni")
	Game._dump_providers.erase("unit_custom")
	Game._dump_providers.erase("unit_list")


func test_offline_dump_shape() -> void:
	var dump: Dictionary = Game.collect_dump()
	eq(dump["peer_id"], 0)
	eq(dump["is_host"], false)
	eq(dump["peers"], [])
	eq(dump["players"], {})
	eq(dump["team_cash"], 0)
	eq(dump["level"], "")
	eq(dump["player_nodes"], [])
	eq(dump["events"], [])
	eq(dump["host_lost"], false)
	is_true(JSON.stringify(dump).length() > 0)


func test_sanitize_name() -> void:
	eq(Game._sanitize_name("  Ali\n\t "), "Ali")
	eq(Game._sanitize_name("a\u0007b"), "ab")
	eq(Game._sanitize_name("x".repeat(40)).length(), Game.MAX_NAME_LENGTH)
	eq(Game._sanitize_name(42), "")
	eq(Game._sanitize_name(&"İsim"), "İsim")


func test_sanitize_long_name_is_bounded() -> void:
	# A giant name from the network (review t2-3: a 100k-char name froze the host for 642 ms) must be truncated in constant time.
	var huge: String = "ş".repeat(300000)
	var t0: int = Time.get_ticks_usec()
	var out: String = Game._sanitize_name(huge)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	eq(out.length(), Game.MAX_NAME_LENGTH)
	is_true(ms < 20.0, "300k karakterlik ad %.1f ms sürdü" % ms)
	eq(Game._sanitize_name(" ".repeat(200000) + "Ali"), "", "baştaki işlenebilir bölüm boşsa ad boş")


func test_start_level_rejects_bad_paths() -> void:
	allow_errors()
	Game.start_level("res://tests/fixtures/yok.tscn")
	Game.start_level("/etc/passwd")
	Game.start_level("res://../x.tscn")
	is_true(Game.current_level() == null)


func test_host_session_flow() -> void:
	var previous_scene: PackedScene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	Game.team_cash_changed.connect(_on_cash)
	Game.session_event.connect(_on_event)
	Game.local_player_changed.connect(_on_local)
	Game.level_loaded.connect(_on_level)

	eq(Net.host(free_udp_port()), OK)
	Game.set_local_name("  Birim ")
	var players: Dictionary = Game.players()
	eq(players.keys(), [1])
	eq(players[1], {"name": "Birim", "slot": 0}, "S3: ad ve katılım yuvası (renk yok)")
	# players() returns a copy.
	(players[1] as Dictionary)["name"] = "değişti"
	eq(Game.players()[1]["name"], "Birim")

	Game.add_team_cash(100)
	Game.add_team_cash(50)
	Game.add_team_cash(0)
	eq(Game.team_cash(), 150)
	eq(_cash_values, [100, 150])

	Game.raise_session_event(&"police_called", {"at": Vector2(3, 4)})
	Game.raise_session_event(&"alarm")
	eq(_events, [&"police_called", &"alarm"])

	Game.start_level(LEVEL)
	var level: Node = Game.current_level()
	if not is_true(level != null, "seviye yüklenmeli"):
		Net.leave()
		return
	eq(_levels, 1)
	eq(str(level.get_path()), "/root/Game/World/Level")
	is_true(level is Level, "seviye kökü Level (S4)")
	var spawner: MultiplayerSpawner = level.get_node_or_null("PlayerSpawner") as MultiplayerSpawner
	if is_true(spawner != null, "PlayerSpawner kurulmalı"):
		eq(spawner.spawn_path, NodePath("../Players"))
		is_true(spawner.get_node_or_null(spawner.spawn_path) == (level as Level).players_root())
	var me: Node2D = level.get_node_or_null("Players/1") as Node2D
	if is_true(me != null, "host oyuncusu Players/1"):
		eq(me.get_multiplayer_authority(), 1)
		eq(me.position, Vector2(160, 160), "Spawn1")
		is_true(Game.local_player() == me)
		eq(_locals.size(), 1)

	# Fake name change: a call outside an RPC has sender 0 -> unknown peer, ignored.
	Game._rpc_set_name("sahte")
	eq(Game.players()[1]["name"], "Birim")

	var dump: Dictionary = Game.collect_dump()
	eq(dump["peer_id"], 1)
	eq(dump["is_host"], true)
	eq(dump["peers"], [1])
	eq(dump["team_cash"], 150)
	eq(dump["level"], LEVEL)
	eq(dump["player_nodes"], [1])
	eq(dump["players"]["1"]["name"], "Birim")
	eq(dump["players"]["1"]["pos"], [160.0, 160.0])
	eq(dump["players"]["1"]["slot"], 0)
	is_false((dump["players"]["1"] as Dictionary).has("color"), "dökümde renk yok (KR-018)")
	eq(dump["events"], [
		{"kind": "police_called", "data": {"at": [3.0, 4.0]}},
		{"kind": "alarm", "data": {}},
		{"kind": "level_started", "data": {"run": 1, "level": LEVEL, "seed": Game.session_seed()}},
	], "IS-102: seviye başında host'a yerel koşu işareti")
	eq(_events, [&"police_called", &"alarm"], "koşu işareti session_event sinyali yaymaz")

	# Restarting the same level removes the old one and respawns the player.
	Game.start_level(LEVEL)
	eq(_levels, 2)
	is_true(Game.current_level() != level)
	is_true(Game.current_level().get_node_or_null("Players/1") != null)

	# Session end: on the next frame the level, players, cash and events are cleared.
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	is_true(Game.current_level() == null)
	eq(Game.players(), {})
	eq(Game.team_cash(), 0)
	eq(Game.collect_dump()["events"], [])
	is_true(Game.local_player() == null)
	is_true(_locals.back() == null, "yerel oyuncu kaldırılınca null yayılır")
	is_false(Game.collect_dump()["host_lost"], "host kendi ayrılınca host_lost değil")

	Game.team_cash_changed.disconnect(_on_cash)
	Game.session_event.disconnect(_on_event)
	Game.local_player_changed.disconnect(_on_local)
	Game.level_loaded.disconnect(_on_level)
	Game.player_scene = previous_scene


func test_players_broadcast_coalesces_per_frame() -> void:
	eq(Net.host(free_udp_port()), OK)
	await tree().process_frame
	var count: Array[int] = [0]
	var counter: Callable = func() -> void: count[0] += 1
	Game.players_changed.connect(counter)
	for i: int in 5:
		Game._queue_players_broadcast()
	eq(count[0], 0, "yayın kare sonuna ertelenir")
	await tree().process_frame
	eq(count[0], 1, "aynı karedeki istekler tek yayına iner")
	Game.players_changed.disconnect(counter)
	Net.leave()
	await tree().process_frame


func test_session_event_keeps_own_copy() -> void:
	eq(Net.host(free_udp_port()), OK)
	var data: Dictionary = {"zone": "back", "list": [1]}
	Game.raise_session_event(&"alarm", data)
	data["zone"] = "front"
	(data["list"] as Array).append(2)
	eq(Game.collect_dump()["events"], [{"kind": "alarm", "data": {"zone": "back", "list": [1]}}])
	Net.leave()
	await tree().process_frame


func test_leave_during_handshake_cleans_up() -> void:
	# Review t2-2: if the peer leaves after the hello is received and the level is loaded but before acceptance, no level must
	# remain and the next join handshake must not hit the timeout (10 s). The fake host runs in a separate SceneMultiplayer
	# (/root/FakeHost branch): sends hello; does not finish the handshake while `accept` is false.
	var fake_root: Node = Node.new()
	fake_root.name = "FakeHost"
	tree().root.add_child(fake_root)
	var api: SceneMultiplayer = SceneMultiplayer.new()
	tree().set_multiplayer(api, fake_root.get_path())
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var port: int = free_udp_port()
	eq(server.create_server(port, 4), OK)
	var accept: Array[bool] = [false]
	api.auth_callback = func(peer_id: int, _data: PackedByteArray) -> void:
		if accept[0]:
			api.complete_auth(peer_id)
	var on_authenticating: Callable = func(peer_id: int) -> void:
		api.send_auth(peer_id, var_to_bytes({"v": Game.PROTOCOL_VERSION, "level": LEVEL}))
	api.peer_authenticating.connect(on_authenticating)
	api.multiplayer_peer = server
	var connected: Array[bool] = [false]
	var on_connected: Callable = func() -> void: connected[0] = true
	Net.connected_to_host.connect(on_connected)

	eq(Net.join("127.0.0.1", port), OK)
	var deadline: int = Time.get_ticks_msec() + 3000
	while Game.current_level() == null and Time.get_ticks_msec() < deadline:
		await tree().process_frame
	is_true(Game.current_level() != null, "seviye el sıkışmasında yüklenmeli")
	is_false(Net.is_online(), "kabul edilmeden çevrimiçi değil")
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	is_true(Game.current_level() == null, "kabulden önce ayrılınca seviye kalkmalı")
	eq(Game.collect_dump()["level"], "")

	accept[0] = true
	var t0: int = Time.get_ticks_msec()
	eq(Net.join("127.0.0.1", port), OK)
	deadline = t0 + 4000
	while not connected[0] and Time.get_ticks_msec() < deadline:
		await tree().process_frame
	is_true(connected[0], "ikinci katılma kabul edilmeli")
	is_true(Time.get_ticks_msec() - t0 < 3000, "el sıkışması zaman aşımı beklenmemeli")
	is_true(Game.current_level() != null)

	Net.connected_to_host.disconnect(on_connected)
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	is_true(Game.current_level() == null)
	server.close()
	api.multiplayer_peer = OfflineMultiplayerPeer.new()
	# IS-029: both lambdas capture `api` and are stored on `api` (a cycle); if it is not broken
	# SceneMultiplayer, the test instance and scripts leak at exit ("leaked"/"still in use").
	api.auth_callback = Callable()
	api.peer_authenticating.disconnect(on_authenticating)
	tree().set_multiplayer(null, fake_root.get_path())
	fake_root.queue_free()
	await tree().process_frame


func test_player_slots_reuse_freed_slot() -> void:
	# KR-018: players() carries only {"name", "slot"}; the host assigns the smallest free slot.
	eq(Net.host(free_udp_port()), OK)
	await tree().process_frame  # session opens on Game's frame (host = slot 0)
	Game._add_player(5, "b")
	Game._add_player(6, "c")
	var players: Dictionary = Game.players()
	eq(players.keys(), [1, 5, 6])
	eq([players[1]["slot"], players[5]["slot"], players[6]["slot"]], [0, 1, 2])
	eq(players[5], {"name": "b", "slot": 1})
	Game._players.erase(5)
	Game._add_player(7, "d")
	eq(Game.players()[7], {"name": "d", "slot": 1}, "ayrılanın yuvası yeniden kullanılır")
	Net.leave()
	await tree().process_frame
	eq(Game.players(), {})


func test_players_rpc_sanitizes_slot() -> void:
	# Client side: the list from the host is stored only as name + non-negative int slot.
	Game._rpc_players({
		1: {"name": " A ", "slot": 2}, 2: {"name": "B", "slot": "x"}, 3: {"name": "C", "color": Color.RED},
		4: {"name": "D", "slot": -3}, "bozuk": {"name": "E", "slot": 1}, 5: "bozuk",
	})
	eq(Game.players(), {
		1: {"name": "A", "slot": 2}, 2: {"name": "B", "slot": 0}, 3: {"name": "C", "slot": 0},
		4: {"name": "D", "slot": 0},
	})
	Game._rpc_players({})
	eq(Game.players(), {})


func test_spawn_uses_level_api() -> void:
	# Spawn point from Level.spawn_position (SpawnPoints-shifted fixture: Spawn1 = (200, 120) + (400, 0)).
	var previous_scene: PackedScene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	eq(Net.host(free_udp_port()), OK)
	Game.start_level(LEVEL_B)
	var level: Level = Game.current_level() as Level
	if is_true(level != null, "seviye Level olarak yüklenmeli"):
		var me: Node2D = level.players_root().get_node_or_null("1") as Node2D
		if is_true(me != null, "host oyuncusu üretilmeli"):
			eq(me.position, Vector2(600, 120))
			eq(me.position, level.spawn_position(0))
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = previous_scene


func test_rejects_level_without_level_root() -> void:
	# S4: if the root is not a Level or Players is missing, the level is not loaded; Game does not create Players by node name.
	allow_errors()
	var bare := Node2D.new()  # Players present, root not a Level
	var players := Node2D.new()
	players.name = "Players"
	bare.add_child(players)
	players.owner = bare
	var no_players: Level = Level.new()  # root Level, no Players
	var roots: Array[Node2D] = [bare, no_players]
	for i: int in roots.size():
		var path: String = "user://test_game_bad_level_%d.tscn" % i  # separate path: do not mix the load cache
		var packed := PackedScene.new()
		eq(packed.pack(roots[i]), OK)
		eq(ResourceSaver.save(packed, path), OK)
		is_false(Game._load_level_local(path), "%d. sahne reddedilmeli" % i)
		is_true(Game.current_level() == null)
		roots[i].free()
		DirAccess.remove_absolute(path)


func test_offline_start_level_has_no_players() -> void:
	Game.start_level(LEVEL)
	var level: Level = Game.current_level() as Level
	if is_true(level != null):
		eq(level.players_root().get_child_count(), 0, "oturum yokken oyuncu üretilmez")
	Game._unload_level()
	is_true(Game.current_level() == null)


func test_default_player_scene() -> void:
	eq(Game.DEFAULT_PLAYER_SCENE, "res://entities/player/player.tscn")
	if ResourceLoader.exists(Game.DEFAULT_PLAYER_SCENE):
		is_true(Game.player_scene != null and Game.player_scene.resource_path == Game.DEFAULT_PLAYER_SCENE)
	else:
		# Before US-004: no default scene -> safely null (tests override with --player-scene).
		is_true(Game.player_scene == null, "varsayılan oyuncu sahnesi yokken null")
