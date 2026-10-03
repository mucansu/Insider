extends TestCase
## US-038 kaçış okunurluğu: HUD kaçış paneli (hedef satırı uyarı ≥ 2, polis sayacı, "Kaçış noktasında n/m"),
## kaçış kenar oku (uyarı ≥ 2 ve kaçış noktası ekran dışı), iş sonu yakalanma nedeni (polis / mahalleli / sahip),
## yeni metin anahtarları (TR + EN), dünya işareti (bölge dikdörtgeni, sisin üstünde kroki, nabız ve hareket
## azaltma) ve Game salt okunur yardımcıları (escape_point / escape_status; host oturumu + store_a + gerçek oyuncu).

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
const IN_ZONE := Vector2(860, 576)
const ESCAPE_CENTER := Vector2(864, 576)
const NEW_KEYS: Array[String] = [
	"HUD_ESCAPE_OBJECTIVE", "HUD_ESCAPE_RULE", "HUD_ESCAPE_POLICE", "HUD_ESCAPE_COUNT",
	"END_STATUS_CAUGHT_POLICE", "END_STATUS_CAUGHT_CHASER", "END_STATUS_CAUGHT_OWNER",
	"END_CAUSE_POLICE", "END_CAUSE_CHASER", "END_CAUSE_OWNER",
]

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var hud: Hud
var panel: EscapePanel
var arrow: EscapeArrow
var warnings: Array[String] = []
var _previous_scene: PackedScene = null


func _open(before_ready: Callable = Callable()) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	if before_ready.is_valid():
		before_ready.call()
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	viewport.add_child(hud)
	panel = hud.get_node("%EscapePanel") as EscapePanel
	arrow = hud.get_node("%EscapeArrow") as EscapeArrow
	arrow.world_to_screen = func(world: Vector2) -> Vector2: return world
	for i: int in 3:
		await tree().process_frame


# --- AC2/AC3/AC4: panel satırları ---

func test_lines_rule() -> void:
	eq(EscapePanel.lines(0, -1.0, 0, 3), {"objective": false, "police": false, "count": false}, "sakin, sayaç yok")
	eq(EscapePanel.lines(1, -1.0, 0, 3)["objective"], false, "şüphe: hedef yok")
	eq(EscapePanel.lines(2, -1.0, 0, 3)["objective"], true, "bağırdı: hedef")
	eq(EscapePanel.lines(3, 59.0, 0, 3)["police"], true, "sayaç varken polis satırı")
	eq(EscapePanel.lines(3, 0.0, 0, 3)["police"], true, "0 sn de gösterilir")
	eq(EscapePanel.lines(0, -1.0, 1, 3)["count"], true, "bölgede biri varken sayım (uyarıdan bağımsız)")
	eq(EscapePanel.lines(0, -1.0, 0, 0)["count"], false, "kimse yok")


func test_panel_follows_game_state() -> void:
	await _open()
	is_false(panel.visible, "sakin ve bölge boş: panel gizli")
	is_false(arrow.visible and not arrow.marker().is_empty(), "ok yok")
	game.alert = 2
	hud.advance(0.1)
	is_true(panel.visible and panel.objective_label().visible, "uyarı 2: hedef satırı")
	eq(panel.objective_label().text, tr("HUD_ESCAPE_OBJECTIVE"))
	eq(panel.objective_label().theme_type_variation, &"EscapeLabel", "kaçış renginde")
	is_false(panel.police_label().visible, "sayaç yokken polis satırı yok")
	game.alert = 3
	game.timer_left = 42.3
	hud.advance(0.1)
	is_true(panel.police_label().visible, "AC3: polis sayacı görünür")
	eq(panel.police_label().text, tr("HUD_ESCAPE_POLICE") % "0:43")
	game.timer_left = 9.0
	hud.advance(0.1)
	eq(panel.police_label().text, tr("HUD_ESCAPE_POLICE") % "0:09", "her karede yenilenir")
	is_false((hud.get_node("%AlertLadder").get_node("%TimerLabel") as Label).visible, "sayaç tek yerde (panel)")
	is_false(panel.count_label().visible, "bölge boş: sayım yok")
	game.escape = {"in_zone": 1, "free": 3}
	hud.advance(0.1)
	is_true(panel.count_label().visible, "AC4: bölgede biri var")
	eq(panel.count_label().text, tr("HUD_ESCAPE_COUNT") % [1, 3])
	eq(panel.count_label().theme_type_variation, &"", "eksik: nötr")
	game.escape = {"in_zone": 2, "free": 2}
	hud.advance(0.1)
	eq(panel.count_label().text, tr("HUD_ESCAPE_COUNT") % [2, 2], "m = yakalanmamış oyuncu")
	eq(panel.count_label().theme_type_variation, &"EscapeLabel", "herkes orada: kaçış renginde")
	game.alert = 0
	game.timer_left = -1.0
	game.escape = {"in_zone": 0, "free": 2}
	hud.advance(0.1)
	is_false(panel.visible, "her şey sönünce panel gizli")
	eq(warnings, [] as Array[String])


func test_panel_hidden_without_api() -> void:
	var legacy: Object = autofree(Fakes.FakeGameBase.new())
	is_false(EscapePanel.supports(legacy), "S3 eki yok")
	is_false(EscapeArrow.supports(legacy), "S3 eki yok")
	await _open()
	is_true(EscapePanel.supports(game) and EscapeArrow.supports(game))


func test_panel_fits_and_is_legible() -> void:
	await _open(func() -> void:
		game.alert = 3
		game.timer_left = 60.0
		game.escape = {"in_zone": 2, "free": 3})
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	is_true(screen.encloses(panel.get_global_rect()), "1280×720 taşma yok (%s)" % panel.get_global_rect())
	for label: Label in [panel.objective_label(), panel.police_label(), panel.count_label()]:
		is_true(label.visible, "%s görünür" % label.name)
		is_true(label.get_theme_font_size(&"font_size") >= ThemeTokens.FONT_SIZE_BODY, "%s ≥ 18 px" % label.name)
	var ladder: Control = hud.get_node("%AlertLadder") as Control
	is_true(panel.get_global_rect().position.y >= ladder.get_global_rect().end.y, "panel merdivenin altında")
	eq(ThemeTokens.theme().get_color(&"font_color", &"EscapeLabel"), ThemeTokens.GAMEPLAY_ESCAPE, "tema token rengi")


# --- AC2: kenar oku ---

func test_arrow_only_when_alert_and_offscreen() -> void:
	await _open(func() -> void: game.escape_at = Vector2(2000, 360))
	arrow.refresh()
	is_true(arrow.marker().is_empty(), "uyarı 0: ok yok")
	game.alert = 2
	arrow.refresh()
	var m: Dictionary = arrow.marker()
	if is_true(not m.is_empty(), "uyarı 2 + ekran dışı: ok"):
		near(float(m["pos"].x), 1280.0 - TeamMarkers.EDGE_MARGIN, 0.5, "sağ kenarda")
		near(float(m["angle"]), 0.0, 0.05, "sağa bakar")
	game.escape_at = Vector2(640, 500)
	arrow.refresh()
	is_true(arrow.marker().is_empty(), "ekrandaysa ok yok (dünya işareti görünür)")
	game.escape_at = Vector2.INF
	arrow.refresh()
	is_true(arrow.marker().is_empty(), "kaçış noktası yoksa ok yok")
	game.escape_at = Vector2(640, -900)
	game.alert = 1
	arrow.refresh()
	is_true(arrow.marker().is_empty(), "uyarı 1: ok yok")


func test_arrow_avoids_escape_panel() -> void:
	await _open(func() -> void:
		game.alert = 3
		game.timer_left = 30.0
		game.escape = {"in_zone": 1, "free": 2}
		game.escape_at = Vector2(640, -900))
	arrow.refresh()
	var m: Dictionary = arrow.marker()
	if is_true(not m.is_empty(), "üst kenarda ok"):
		var block: Rect2 = panel.get_global_rect().grow(EscapeArrow.ARROW_SIZE / 2.0)
		is_false(block.has_point(m["pos"]), "ok kaçış panelinin üstüne düşmez (%s, %s)" % [m["pos"], block])


# --- AC5: iş sonu nedeni ---

func test_caught_cause_rule() -> void:
	eq(HeistEnd.caught_cause(false, &"chaser", &"police", true), &"", "yakalanmadı")
	eq(HeistEnd.caught_cause(true, &"chaser", &"police", true), &"chaser", "olaydaki yakalayan önce")
	eq(HeistEnd.caught_cause(true, &"owner", &"hot", false), &"owner")
	eq(HeistEnd.caught_cause(true, &"", &"police", false), &"police", "olaysız + sonuç polis")
	eq(HeistEnd.caught_cause(true, &"", &"hot", true), &"police", "polis geldi, bölge dışında kaldı")
	eq(HeistEnd.caught_cause(true, &"", &"caught_all", false), &"", "bilinmiyor: genel metin")
	eq(HeistEnd.caught_status_key(&""), &"END_STATUS_CAUGHT")
	eq(HeistEnd.caught_status_key(&"police"), &"END_STATUS_CAUGHT_POLICE")


func test_end_screen_shows_cause() -> void:
	await _open()
	var screen: HeistEnd = hud.get_node("%HeistEnd") as HeistEnd
	game.session_event.emit(&"player_caught", {"peer": 2, "by": &"chaser"})
	game.session_event.emit(&"police_arrived", {})
	game.heist_finished.emit({
		"outcome": &"police", "loot_total": 0, "payout_ratio": 0.0, "payout": 0, "duration_s": 75.0,
		"players": {
			"1": {"name": "Ayşe", "slot": 0, "escaped": false, "caught": true, "loot": 0},
			"2": {"name": "Cem", "slot": 1, "escaped": false, "caught": true, "loot": 0},
		},
		"notes": [],
	})
	await tree().process_frame
	var cause: Label = screen.get_node("%CauseNote") as Label
	is_true(screen.is_open() and cause.visible, "yerel oyuncunun nedeni görünür")
	eq(cause.text, tr("END_CAUSE_POLICE"), "polis geldiğinde kaçış noktasında değildin")
	var statuses: Array[String] = []
	for child: Node in screen.get_node("%PlayerGrid").get_children():
		if child is Label:
			statuses.append((child as Label).text)
	has(statuses, tr("END_STATUS_CAUGHT_POLICE"), "yerel: polis")
	has(statuses, tr("END_STATUS_CAUGHT_CHASER"), "Cem: mahalleli (olaydan)")
	eq(tr("END_OUTCOME_POLICE_NOTE").is_empty(), false)
	eq(warnings, [] as Array[String])


func test_end_screen_no_cause_when_escaped() -> void:
	await _open()
	var screen: HeistEnd = hud.get_node("%HeistEnd") as HeistEnd
	game.heist_finished.emit({
		"outcome": &"clean", "loot_total": 100, "payout_ratio": 0.9, "payout": 90, "duration_s": 30.0,
		"players": {"1": {"name": "Ayşe", "slot": 0, "escaped": true, "caught": false, "loot": 100}},
		"notes": [],
	})
	await tree().process_frame
	is_false((screen.get_node("%CauseNote") as Label).visible, "kaçan için neden satırı yok")


# --- AC6: metinler ---

func test_new_keys_have_tr_and_en() -> void:
	var previous: String = TranslationServer.get_locale()
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in NEW_KEYS:
			ne(TranslationServer.translate(key), key, "%s [%s]" % [key, locale])
		eq(TranslationServer.translate("HUD_ESCAPE_COUNT").count("%d"), 2, "n/m iki yer tutucu [%s]" % locale)
	TranslationServer.set_locale(previous)
	for cause: StringName in [HeistEnd.CAUSE_POLICE, HeistEnd.CAUSE_CHASER, HeistEnd.CAUSE_OWNER]:
		has(NEW_KEYS, String(HeistEnd.caught_status_key(cause)), "nedenin durum anahtarı listede")
		has(NEW_KEYS, HeistEnd.CAUSE_KEY_PREFIX + String(cause).to_upper(), "nedenin açıklama anahtarı listede")


# --- AC1: dünya işareti ---

func _marker_level() -> Array:
	var level := Level.new()
	var zones := Node2D.new()
	zones.name = "Zones"
	level.add_child(zones)
	var zone := Area2D.new()
	zone.name = "EscapeZone"
	zone.position = Vector2(864, 576)
	zones.add_child(zone)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(128, 64)
	shape.shape = rect
	zone.add_child(shape)
	var marker := EscapeMarker.new()
	level.add_child(marker)
	autofree(level)
	tree().root.add_child(level)
	return [level, marker]


func test_world_marker_reads_zone_and_draws_above_fog() -> void:
	var parts: Array = _marker_level()
	var marker: EscapeMarker = parts[1]
	await tree().process_frame
	eq(marker.rect, Rect2(Vector2(800, 544), Vector2(128, 64)), "bölge dikdörtgeni (düzen değişmeden okunur)")
	is_true(marker.kroki() != null, "kroki katmanı")
	if marker.kroki() != null:
		is_true(marker.kroki().z_index > FogLayer.Z_INDEX and marker.kroki().z_index < VisionRules.ABOVE_FOG_Z,
			"kroki sisin üstünde, oyuncuların altında (z %d)" % marker.kroki().z_index)
		is_false(marker.kroki().z_as_relative, "mutlak z")
	eq(marker.z_index, 0, "zemin katmanı sisin altında (bilinmeyende gizli, hafızada soluk)")


func test_world_marker_pulse_and_reduce_motion() -> void:
	near(EscapeMarker.fill_alpha(0.0, false), EscapeMarker.FILL_ALPHA, 0.001)
	is_true(EscapeMarker.fill_alpha(EscapeMarker.PULSE_PERIOD / 4.0, false) > EscapeMarker.FILL_ALPHA + 0.05, "nabız")
	eq(EscapeMarker.fill_alpha(EscapeMarker.PULSE_PERIOD / 4.0, true), EscapeMarker.FILL_ALPHA, "hareket azaltma: sabit")
	var parts: Array = _marker_level()
	var marker: EscapeMarker = parts[1]
	marker.reduce_motion = true
	await tree().process_frame
	await tree().process_frame
	eq(marker.current_fill_alpha(), EscapeMarker.FILL_ALPHA, "reduce_motion: nabız yok")
	marker.reduce_motion = false
	Puppet.set_reduced_motion(true)
	is_true(marker.is_motion_reduced(), "genel hareket azaltma ayarı da kapatır")
	Puppet.set_reduced_motion(false)


func test_store_has_escape_marker() -> void:
	var scene: PackedScene = load(STORE) as PackedScene
	var level: Node = scene.instantiate()
	var marker: EscapeMarker = level.get_node_or_null("EscapeMarker") as EscapeMarker
	is_true(marker != null, "store_a: EscapeMarker ayrı görsel düğüm (seviye kökünde)")
	if marker != null:
		eq(marker.zone_name, &"EscapeZone")
		eq(marker.read_zone_rect().get_center(), ESCAPE_CENTER, "ağaç dışında da bölge merkezi")
	level.free()


# --- AC7: Game salt okunur yardımcıları (host; istemci aynı hesabı yerel kopyadan yapar) ---

func _start() -> Node2D:
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	if not eq(Net.host(_free_udp_port()), OK):
		return null
	Game.start_level(STORE)
	return Game.local_player() as Node2D


func _stop() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = _previous_scene


static func _free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func test_game_escape_helpers() -> void:
	eq(Game.escape_point(), Vector2.INF, "seviye yokken INF")
	eq(Game.escape_status(), {"in_zone": 0, "free": 0}, "seviye yokken boş")
	var me: Node2D = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	eq(Game.escape_point(), ESCAPE_CENTER, "EscapeZone merkezi")
	eq(Game.escape_status(), {"in_zone": 0, "free": 1}, "doğma noktasında: 0/1")
	me.position = IN_ZONE
	await tree().physics_frame
	eq(Game.escape_status(), {"in_zone": 1, "free": 1}, "bölgede: 1/1 (ganimet yok: iş sürer)")
	eq(Game.heist_result(), {}, "ganimetsiz bölgede olmak işi bitirmez")
	Game.raise_session_event(&"player_caught", {"peer": 1, "by": &"chaser"})
	await tree().physics_frame
	eq(int(Game.escape_status()["free"]), 0, "yakalanan sayılmaz (m)")
	await _stop()
