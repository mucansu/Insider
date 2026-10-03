extends TestCase
## IS-027 local player camera and view polish: zoom 1.5 from `data/player_tuning.tres` camera_zoom (the `--camera-zoom` developer
## argument overrides), the camera is clamped to the level's map rectangle (S4 `Level.map_rect()`), centred if the map is narrower
## than the view; the viewport clear colour is the tone's BG.

const SCENE := "res://entities/player/player.tscn"
const TUNING := "res://data/player_tuning.tres"
const STORE := "res://levels/store_a.tscn"
const ArgsScript := preload("res://autoload/args.gd")
const MainScript := preload("res://main.gd")


func _spawn_local(parent: Node) -> Player:
	var player: Player = (load(SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.set_multiplayer_authority(1, true)
	parent.add_child(player)
	return player


func _camera(player: Player) -> Camera2D:
	return player.get_node("Camera2D") as Camera2D


func test_tuning_zoom_is_one_and_a_half() -> void:
	var t: PlayerTuning = load(TUNING) as PlayerTuning
	near(t.camera_zoom, 1.5, 0.0001, "ON-01: yakınlaştırma 1,5")


func test_args_camera_zoom_parsing() -> void:
	var a: ArgsScript = autofree(ArgsScript.new()) as ArgsScript
	eq(a.camera_zoom, 0.0, "verilmedi = 0")
	a.parse(PackedStringArray(["--camera-zoom=1.0"]))
	near(a.camera_zoom, 1.0, 0.0001)
	eq(a.unknown.size(), 0, "tanınan argüman")
	a.parse(PackedStringArray(["--camera-zoom=2.25", "--host"]))
	near(a.camera_zoom, 2.25, 0.0001)
	a.parse(PackedStringArray([]))
	eq(a.camera_zoom, 0.0, "yeniden ayrıştırma sıfırlar")
	for bad: String in ["--camera-zoom=abc", "--camera-zoom=0", "--camera-zoom=-1", "--camera-zoom=9", "--camera-zoom"]:
		a.parse(PackedStringArray([bad]))
		eq(a.camera_zoom, 0.0, "geçersiz değer yok sayılır: " + bad)


func test_local_camera_uses_tuning_zoom_or_argument() -> void:
	var saved: float = Args.camera_zoom
	Args.camera_zoom = 0.0
	var player: Player = _spawn_local(autofree(Node2D.new()) as Node2D)
	tree().root.add_child(player.get_parent())
	near(player.camera_zoom(), 1.5, 0.0001)
	eq(_camera(player).zoom, Vector2(1.5, 1.5))
	is_true(_camera(player).limit_smoothed, "sınır yumuşak")
	tree().root.remove_child(player.get_parent())
	Args.camera_zoom = 1.0
	var other: Player = _spawn_local(autofree(Node2D.new()) as Node2D)
	tree().root.add_child(other.get_parent())
	near(other.camera_zoom(), 1.0, 0.0001, "--camera-zoom tuning'i geçersiz kılar")
	eq(_camera(other).zoom, Vector2.ONE)
	tree().root.remove_child(other.get_parent())
	Args.camera_zoom = saved


func test_camera_limits_math() -> void:
	var map := Rect2(0, 0, 960, 640)
	# Zoom 1.5: view 853x480 is smaller than the map -> limit is the map.
	eq(Player.camera_limits(map, Vector2(1280, 720) / 1.5), Rect2i(0, 0, 960, 640))
	# Zoom 1.0: view 1280x720 is larger than the map -> map centred, limit is the view size.
	eq(Player.camera_limits(map, Vector2(1280, 720)), Rect2i(-160, -40, 1280, 720))
	# Mixed: only the narrow axis widens; a positioned map.
	eq(Player.camera_limits(Rect2(100, 50, 2000, 300), Vector2(1280, 720)), Rect2i(100, -160, 2000, 720))
	# Fractional widening is rounded down/up, never narrower than the view.
	var odd: Rect2i = Player.camera_limits(map, Vector2(1281, 721))
	is_true(odd.size.x >= 1281 and odd.size.y >= 721, "yuvarlama görüşü kapsar: %s" % odd)
	near(Vector2(odd.get_center()), map.get_center(), 1.0, "ortalı")


func test_camera_clamps_to_level_map() -> void:
	var saved: float = Args.camera_zoom
	Args.camera_zoom = 0.0
	var level: Level = autofree((load(STORE) as PackedScene).instantiate()) as Level
	level.position = Vector2(100, 200)  # the root's transform is reflected in the global limit
	tree().root.add_child(level)
	var player: Player = _spawn_local(level.players_root())
	var cam: Camera2D = _camera(player)
	var map := Rect2(Vector2(100, 200), Vector2(960, 640))
	var expected: Rect2i = Player.camera_limits(map, player.get_viewport_rect().size / cam.zoom)
	eq(Rect2i(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top),
		expected, "Camera2D limit_* = harita (görüşe göre)")
	# If the view is larger than the map the limit covers the view and centres the map (no grey gap, surroundings are BG).
	cam.zoom = Vector2.ONE
	player.get_viewport().size_changed.emit()
	var view: Vector2 = player.get_viewport_rect().size
	expected = Player.camera_limits(map, view)
	eq(Rect2i(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top),
		expected, "görüş değişince sınır yeniden hesaplanır")
	near(Vector2((cam.limit_left + cam.limit_right) * 0.5, (cam.limit_top + cam.limit_bottom) * 0.5),
		map.get_center(), 1.0, "harita ortada")
	tree().root.remove_child(level)
	Args.camera_zoom = saved


func test_camera_without_level_is_unbounded() -> void:
	var holder: Node2D = autofree(Node2D.new()) as Node2D
	tree().root.add_child(holder)
	var player: Player = _spawn_local(holder)
	var fresh := Camera2D.new()
	eq(_camera(player).limit_left, fresh.limit_left, "seviye yoksa varsayılan sınır")
	eq(_camera(player).limit_right, fresh.limit_right)
	fresh.free()
	tree().root.remove_child(holder)


func test_clear_color_is_tone_background() -> void:
	var saved: Color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3))
	MainScript.apply_clear_color()
	eq(RenderingServer.get_default_clear_color(), ThemeTokens.tone().bg_color, "ON-07: temizleme rengi BG")
	eq(ThemeTokens.noir_tone().bg_color, ThemeTokens.BG)
	RenderingServer.set_default_clear_color(saved)
