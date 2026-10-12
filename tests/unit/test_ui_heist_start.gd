extends TestCase
## IS-114 (GB-13) "Start can't be found": start marker (ring + "START" tag in prep on every peer, host-only edge arrow when off-screen,
## gone once the job starts), the permanent HUD prep line (host / client / at the escape point), clearer locked prompt and reminder
## text, theme token, and Game's read-only `heist_start_position()` on a real host session (store_a, prep) where the host's prompt at
## the van (escape point, KR-045) is "Start"; every playable map puts it at its escape point. Layout: test_ui_layout.gd test_hud_prep_line_fits. Multi-process: tests/net/heist_start_spawn.json,
## heist_start_walk.json (the real E path, no automation hook).

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
const OTHER_MAPS: Array[String] = ["res://levels/store_b.tscn", "res://levels/store_a_rush.tscn"]
const SCREEN := Vector2(1280, 720)
const DT := 1.0 / 60.0
const NEW_KEYS: Array[String] = ["HUD_PREP_HOST", "HUD_PREP_CLIENT", "HUD_PREP_AT_ESCAPE", "HUD_PREP_AT_ESCAPE_HOST",
	"HUD_START_MARKER"]

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var hud: Hud
var marker: HeistStartMarker
var _previous_scene: PackedScene = null
var _previous_prep: bool = false


func _open(host: bool, before_ready: Callable = Callable()) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	net.hosting = host
	if before_ready.is_valid():
		before_ready.call()
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(SCREEN)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(_missing_key: String) -> void: pass
	viewport.add_child(hud)
	marker = hud.start_marker()
	marker.world_to_screen = func(world: Vector2) -> Vector2: return world
	for i: int in 3:
		await tree().process_frame


# --- AC1: world marker ---

func test_marker_needs_contract_members() -> void:
	is_false(HeistStartMarker.supports(null))
	is_false(HeistStartMarker.supports(autofree(Node.new()) as Node), "S3 eki yok: işaret yok")
	await _open(false)
	is_true(HeistStartMarker.supports(game))
	is_true(marker.visible)


func test_marker_ring_in_prep_on_host_and_client() -> void:
	for host: bool in [true, false]:
		await _open(host, func() -> void:
			game.prep_s = 5.0
			game.start_at = Vector2(400, 300))
		hud.advance(DT)
		var ring: Dictionary = marker.ring()
		var who: String = "host" if host else "istemci"
		is_false(ring.is_empty(), "%s: hazırlıkta halka var" % who)
		eq(ring.get("pos"), Vector2(400, 300), who + ": halka başlangıç noktasında")
		is_true(float(ring.get("radius", 0.0)) >= HeistStartMarker.RING_MIN_RADIUS, who + ": okunur yarıçap")
		is_true(marker.arrow().is_empty(), who + ": ekrandayken ok yok")
		eq(marker.tag_text(), tr(&"HUD_START_MARKER"))


func test_marker_gone_when_job_starts_or_no_point() -> void:
	await _open(true, func() -> void:
		game.prep_s = 5.0
		game.start_at = Vector2(400, 300))
	hud.advance(DT)
	is_false(marker.ring().is_empty())
	game.prep_s = -1.0  # job started (or no job)
	hud.advance(DT)
	is_true(marker.ring().is_empty(), "iş başladı: halka yok")
	is_true(marker.arrow().is_empty())
	game.prep_s = 5.0
	game.start_at = Vector2.INF
	hud.advance(DT)
	is_true(marker.ring().is_empty(), "başlangıç noktası yok: halka yok")


func test_marker_edge_arrow_host_only() -> void:
	await _open(true, func() -> void:
		game.prep_s = 5.0
		game.start_at = Vector2(-900, 360))
	hud.advance(DT)
	is_true(marker.ring().is_empty(), "ekran dışı: halka yok")
	var arrow: Dictionary = marker.arrow()
	if is_false(arrow.is_empty(), "host: ekran kenarında ok"):
		var pos: Vector2 = arrow["pos"]
		is_true(pos.x < SCREEN.x / 2.0, "ok solda: %s" % pos)
		is_true(Rect2(Vector2.ZERO, SCREEN).has_point(pos), "ok ekranda")
	game.start_at = Vector2(10, 360)  # ring cut by the screen edge
	hud.advance(DT)
	is_false(marker.ring().is_empty(), "kenarda: halka kısmen çizilir")
	is_false(marker.arrow().is_empty(), "kenarda: ok da var (yarım etiket tek ipucu kalmaz)")
	await _open(false, func() -> void:
		game.prep_s = 5.0
		game.start_at = Vector2(-900, 360))
	hud.advance(DT)
	is_true(marker.arrow().is_empty(), "istemci: ok yok (başlatan host)")


func test_tag_placement_avoids_name_tags_and_edges() -> void:
	var screen := Rect2(Vector2.ZERO, SCREEN)
	var text := Vector2(80, 30)
	var mid: Rect2 = HeistStartMarker.tag_rect(Vector2(640, 360), 70.0, text, screen)
	is_true(mid.position.y > 360.0 + 70.0, "ortada: halkanın altında (ad etiketleri başın üstünde)")
	var low: Rect2 = HeistStartMarker.tag_rect(Vector2(1136, 622), 74.0, text, screen)  # van near the bottom (host_6.2 frame)
	is_true(screen.encloses(low), "altta yer yoksa ekranda kalır: %s" % low)
	is_true(low.end.x <= 1136.0 - 74.0, "halkanın solunda")
	var corner: Rect2 = HeistStartMarker.tag_rect(Vector2(40, 700), 74.0, text, screen)
	is_true(screen.encloses(corner), "köşede: üstte")


func test_ring_radius_matches_start_range() -> void:
	eq(HeistStartMarker.RING_WORLD_RADIUS, Game.HEIST_START_RANGE, "halka = Başla menzili (ui autoload sabitine bağlanmaz)")


# --- AC2/AC7: prep line ---

func test_prep_line_rule() -> void:
	eq(Hud.prep_line_key(false, true, false), "", "hazırlık değil: satır yok")
	eq(Hud.prep_line_key(false, false, true), "")
	eq(Hud.prep_line_key(true, true, false), "HUD_PREP_HOST")
	eq(Hud.prep_line_key(true, true, true), "HUD_PREP_HOST", "host kaçışta ama Başla menzilinde değil: minibüse çağrı")
	eq(Hud.prep_line_key(true, true, true, true), "HUD_PREP_AT_ESCAPE_HOST", "host Başla isteminde: 'Herkes burada mı? [E] BAŞLA'")
	eq(Hud.prep_line_key(true, false, false), "HUD_PREP_CLIENT")
	eq(Hud.prep_line_key(true, false, true), "HUD_PREP_AT_ESCAPE", "istemci kaçışta: host BAŞLA'ya basınca")
	eq(Hud.prep_line_key(true, false, true, true), "HUD_PREP_AT_ESCAPE")
	eq(Hud.START_ACTION_KEY, Game.HEIST_START_KEY, "ui kopyası Game anahtarıyla aynı")


func test_prep_line_host_vs_client() -> void:
	await _open(true, func() -> void: game.prep_s = 5.0)
	hud.advance(DT)
	var label: Label = hud.prep_label()
	is_true(label.is_visible_in_tree(), "host: kalıcı satır görünür")
	eq(label.text, tr(&"HUD_PREP_HOST") % UiInput.action_hint(&"interact"))
	is_false(label.text.contains("%"), "biçim doldu")
	is_true(label.text.contains(UiInput.action_hint(&"interact")), "tuş adı: %s" % label.text)
	eq(label.theme_type_variation, &"StartLabel")
	hud.advance(5.0)
	is_true(label.is_visible_in_tree(), "toast değil: süre geçince de duruyor")
	game.escape = {"in_zone": 2, "free": 2}
	hud.advance(DT)
	eq(label.text, tr(&"HUD_PREP_HOST") % UiInput.action_hint(&"interact"), "host Başla menzili dışında: aynı çağrı")
	var player: Node = autofree(Fakes.FakePlayer.new()) as Node
	game.local_player_changed.emit(player)
	player.emit_signal(&"interaction_target_changed", Hud.START_ACTION_KEY)
	hud.advance(DT)
	eq(label.text, tr(&"HUD_PREP_AT_ESCAPE_HOST") % UiInput.action_hint(&"interact"), "host Başla isteminde: istemle aynı dil")
	is_true((hud.get_node("%PromptLabel") as Label).text.contains(UiInput.action_hint(&"interact")), "alt istem de [E] Başla")
	game.prep_s = -1.0
	hud.advance(DT)
	is_false(label.is_visible_in_tree(), "iş başladı: satır gider")
	await _open(false, func() -> void: game.prep_s = 5.0)
	hud.advance(DT)
	eq(hud.prep_label().text, tr(&"HUD_PREP_CLIENT"), "istemci metni")
	is_true(hud.prep_label().is_visible_in_tree())
	game.escape = {"in_zone": 1, "free": 2}
	hud.advance(DT)
	eq(hud.prep_label().text, tr(&"HUD_PREP_AT_ESCAPE"), "istemci: biri minibüste -> host BAŞLA'ya basınca")


# --- AC3: texts ---

func test_texts_exist_in_both_languages() -> void:
	var previous: String = TranslationServer.get_locale()
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in NEW_KEYS + ["HUD_PREP_GATHERING", "HUD_PREP_REMINDER"]:
			is_true(tr(key) != key and not tr(key).is_empty(), "%s/%s metni var" % [locale, key])
		is_true(tr(&"HUD_PREP_REMINDER").contains(tr(&"HUD_START_MARKER")), locale + ": hatırlatma işarete atıf yapar")
		is_true(tr(&"HUD_PREP_GATHERING").contains(tr(&"HUD_START_MARKER")), locale + ": kilitli istem nasıl başlanacağını söyler")
		for key: String in ["HUD_PREP_HOST", "HUD_PREP_CLIENT", "HUD_PREP_AT_ESCAPE", "HUD_PREP_AT_ESCAPE_HOST"]:
			is_true(tr(key).contains(tr(&"HUD_START_MARKER")), "%s/%s BAŞLA'yı anar" % [locale, key])
	TranslationServer.set_locale(previous)


func test_start_colour_token() -> void:
	eq(ThemeTokens.theme().get_color(&"font_color", &"StartLabel"), ThemeTokens.GAMEPLAY_START, "tema token rengi")
	for other: Color in [ThemeTokens.GAMEPLAY_ESCAPE, ThemeTokens.GAMEPLAY_ALERT, ThemeTokens.GAMEPLAY_CASH]:
		is_true(_distance(ThemeTokens.GAMEPLAY_START, other) > 0.3, "başla rengi diğer oynanış renklerinden ayrık")
	for player: Color in ThemeTokens.PLAYER_COLORS:
		is_true(_distance(ThemeTokens.GAMEPLAY_START, player) > 0.3, "oyuncu renginden ayrık")


static func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# --- Game read-only helper on a real host session ---

func test_game_start_position_real_session() -> void:
	eq(Game.heist_start_position(), Vector2.INF, "seviye yok: INF")
	_previous_scene = Game.player_scene
	_previous_prep = Args.heist_prep
	Args.heist_prep = true
	Game.player_scene = load(PLAYER) as PackedScene
	if eq(Net.host(_free_udp_port()), OK):
		Game.start_level(STORE)
		for i: int in 4:
			await tree().physics_frame
		var level: Level = Game.current_level() as Level
		is_true(Game.heist_in_prep(), "--heist-prep: hazırlık")
		is_true(level != null and Game.escape_point().is_finite(), "kaçış bölgesi")
		near(Game.heist_start_position().distance_to(Game.escape_point()), 0.0, 0.01, "KR-045: işaret minibüste (kaçış noktası)")
		var me: Player = Game.local_player() as Player
		var pi: PlayerInteraction = me.get_node(^"PlayerInteraction") as PlayerInteraction if me != null else null
		if is_true(pi != null, "yerel oyuncu etkileşimi"):
			is_true(pi.target_key() != "INTERACT_HEIST_START", "doğma yerinde Başla yok: %s" % pi.target_key())
			me.global_position = Game.heist_start_position()
			for i: int in 4:
				await tree().physics_frame
			eq(pi.target_key(), "INTERACT_HEIST_START", "minibüste en yakın hedef Başla (istem önceliği)")
		for path: String in OTHER_MAPS:  # KR-037: derived from each map's EscapeZone node, no per-map constant
			Game.start_level(path)
			for i: int in 4:
				await tree().physics_frame
			eq((Game.current_level() as Node).scene_file_path, path)
			is_true(Game.heist_in_prep(), path + ": hazırlık")
			near(Game.heist_start_position().distance_to(Game.escape_point()), 0.0, 0.01, path + ": işaret kaçış noktasında")
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = _previous_scene
	Args.heist_prep = _previous_prep


static func _free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port
