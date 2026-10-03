extends TestCase
## Alert ladder HUD (US-013; S3 addition KR-021): level transitions via the fake Game's alert_level_changed / alert_level() /
## alert_timer_left() contract, box fill and number + name text, the police timer visible only at 3, change highlight (absent with
## reduced motion), hidden on a Game without the API, legibility.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var viewport: SubViewport
var hud: Hud
var ladder: AlertLadder
var warnings: Array[String] = []


func _open(before_ready: Callable = Callable(), game_override: Node = null) -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	if before_ready.is_valid():
		before_ready.call()
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game if game_override == null else game_override
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	viewport.add_child(hud)
	ladder = hud.get_node("%AlertLadder") as AlertLadder
	for i: int in 3:
		await tree().process_frame


func _level_text() -> String:
	return (ladder.get_node("%LevelLabel") as Label).text


func _timer() -> Label:
	return ladder.get_node("%TimerLabel") as Label


func _step(i: int) -> PanelContainer:
	return ladder.get_node("%Steps").get_child(i) as PanelContainer


func _filled() -> Array[int]:
	var out: Array[int] = []
	for i: int in AlertLadder.LEVEL_MAX + 1:
		if _step(i).theme_type_variation == &"LadderStepActive":
			out.append(i)
	return out


func test_initial_level_from_game() -> void:
	await _open(func() -> void: game.alert = 2)
	is_true(ladder.visible, "S3 eki olan Game ile merdiven görünür")
	eq(ladder.level(), 2)
	eq(_level_text(), tr("HUD_ALERT_LEVEL") % [2, tr("ALERT_T1_2")], "sayı + mekân adı")
	eq(_filled(), [0, 1, 2] as Array[int])
	is_false(ladder.is_popping(), "açılıştaki kademe vurgulanmaz")
	eq(warnings, [] as Array[String])


func test_level_transitions_follow_signal() -> void:
	await _open()
	var label: Label = ladder.get_node("%LevelLabel") as Label
	eq(_level_text(), tr("HUD_ALERT_LEVEL") % [0, tr("ALERT_T1_0")])
	eq(label.theme_type_variation, &"", "sakin: vurgu rengi yok")
	eq(_filled(), [0] as Array[int])
	for level: int in [1, 2, 3]:
		game.alert_level_changed.emit(level)
		eq(ladder.level(), level)
		eq(_level_text(), tr("HUD_ALERT_LEVEL") % [level, tr("ALERT_T1_%d" % level)])
		eq(label.theme_type_variation, &"AlertLabel", "kademe %d uyarı renginde" % level)
		eq(_filled().size(), level + 1)
	game.alert_level_changed.emit(5)
	eq(_level_text(), tr("HUD_ALERT_LEVEL") % [5, tr("ALERT_T1_5")])
	eq(_filled(), [0, 1, 2, 3, 5] as Array[int], "bakkalda 4 yok: polis kademesinde 4 dolmaz")
	near(_step(4).modulate.a, AlertLadder.LOCKED_ALPHA, 0.001, "mekânda olmayan kademe silik")
	near(_step(5).modulate.a, 1.0, 0.001)
	game.alert_level_changed.emit(0)
	eq(_filled(), [0] as Array[int], "geri iniş de izlenir")
	game.alert_level_changed.emit(99)
	eq(ladder.level(), AlertLadder.LEVEL_MAX, "aralık dışı değer sınırlanır")
	eq(warnings, [] as Array[String])


func test_police_timer_only_at_level_three() -> void:
	await _open(func() -> void: game.timer_left = 83.2)
	# US-038: the HUD timer is in the escape panel (test_ui_escape.gd); the ladder's own timer remains for a Game without the panel.
	is_false(ladder.show_timer, "HUD kaçış paneli varken merdiven sayacı kapalı")
	game.alert_level_changed.emit(3)
	is_false(_timer().visible, "kademe 3, show_timer kapalı: merdivende sayaç yok")
	game.alert_level_changed.emit(0)
	ladder.show_timer = true
	ladder.refresh_timer()
	is_false(_timer().visible, "kademe 0: sayaç yok")
	for level: int in [1, 2]:
		game.alert_level_changed.emit(level)
		is_false(_timer().visible, "kademe %d: sayaç yok (Invisible Inc. tuzağı)" % level)
	game.alert_level_changed.emit(3)
	is_true(_timer().visible, "kademe 3: sayaç görünür")
	eq(_timer().text, tr("HUD_ALERT_TIMER") % "1:24")
	game.timer_left = 9.0
	hud.advance(0.1)
	eq(_timer().text, tr("HUD_ALERT_TIMER") % "0:09", "HUD her karede sayacı yeniler")
	game.timer_left = -1.0
	hud.advance(0.1)
	is_false(_timer().visible, "Game sayaç vermiyorsa (−1) gizli")
	game.timer_left = 30.0
	game.alert_level_changed.emit(5)
	is_false(_timer().visible, "polis geldi: sayaç yok")
	game.alert_level_changed.emit(3)
	is_true(_timer().visible)


func test_change_pops_unless_reduced_motion() -> void:
	await _open()
	ladder.reduce_motion = true
	game.alert_level_changed.emit(1)
	is_false(ladder.is_popping(), "hareket azaltma: vurgu yok")
	eq(_step(1).scale, Vector2.ONE)
	eq(_filled(), [0, 1] as Array[int], "durum yine anında görünür")
	ladder.reduce_motion = false
	game.alert_level_changed.emit(2)
	is_true(ladder.is_popping(), "kademe değişimi kısa vurgu")
	await tree().create_timer(AlertLadder.POP_SEC + 0.1).timeout
	is_false(ladder.is_popping(), "vurgu %.1f sn içinde biter" % AlertLadder.POP_SEC)
	near(_step(2).scale.x, 1.0, 0.001, "ölçek geri döner")
	game.alert_level_changed.emit(2)
	is_false(ladder.is_popping(), "aynı kademe tekrar gelince vurgu yok")


func test_hidden_when_game_lacks_alert_api() -> void:
	var legacy: Node = autofree(Fakes.FakeGameBase.new()) as Node
	await _open(Callable(), legacy)
	is_false(ladder.visible, "S3 eki yoksa merdiven gizli")
	hud.advance(0.1)
	eq(warnings, [] as Array[String])


func test_tier_from_game_venue_tier() -> void:
	await _open(func() -> void:
		game.tier = 9
		game.alert = 1)
	eq(ladder.tier, 9, "mekân kademesi Game.venue_tier()'den")
	eq(_level_text(), tr("HUD_ALERT_LEVEL") % [1, tr("ALERT_GENERIC")], "o mekânın anahtarı yoksa genel metin")
	eq(warnings, ["ALERT_T9_1"] as Array[String])
	warnings.clear()
	var legacy: Node = autofree(Fakes.FakeGameBase.new()) as Node
	await _open(Callable(), legacy)
	eq(ladder.tier, AlertLadder.DEFAULT_TIER, "venue_tier yoksa varsayılan (bakkal T1)")


func test_level_names_per_venue_and_missing_key() -> void:
	await _open()
	eq(ladder.tier, 1, "sahte Game bakkal döner")
	for level: int in AlertLadder.LEVEL_MAX + 1:
		ne(tr("ALERT_T1_%d" % level), "ALERT_T1_%d" % level, "bakkal kademe %d anahtarı var" % level)
	eq(ladder.venue_levels(), [0, 1, 2, 3, 5])
	ladder.tier = 9
	eq(ladder.venue_levels(), range(AlertLadder.LEVEL_MAX + 1), "tanımsız mekânda tüm kademeler")
	eq(ladder.level_name(1), tr("ALERT_GENERIC"), "anahtar yoksa genel metin")
	eq(warnings, ["ALERT_T9_1"] as Array[String], "eksik anahtar geliştiriciye bildirilir")


func test_legibility() -> void:
	await _open(func() -> void:
		game.alert = 3
		game.timer_left = 60.0)
	for i: int in AlertLadder.LEVEL_MAX + 1:
		var step: PanelContainer = _step(i)
		is_true(step.size.x >= 22.0 and step.size.y >= 22.0, "kutu %d ≥ 22 px (%s)" % [i, step.size])
	var police: Label = (hud.get_node("%EscapePanel") as EscapePanel).police_label()
	for label: Label in [ladder.get_node("%LevelLabel"), police]:
		is_true(label.visible, "%s görünür" % label.name)
		is_true(label.get_theme_font_size(&"font_size") >= ThemeTokens.FONT_SIZE_BODY, "%s ≥ 18 px" % label.name)
	# Non-text element >= 3:1: empty box outline on its own background, filled box on the panel background.
	var t: Theme = ThemeTokens.theme()
	var empty: StyleBoxFlat = t.get_stylebox(&"panel", &"LadderStep") as StyleBoxFlat
	is_true(_contrast(empty.border_color, empty.bg_color) >= 3.0, "boş kutu çerçevesi")
	var active: StyleBoxFlat = t.get_stylebox(&"panel", &"LadderStepActive") as StyleBoxFlat
	eq(active.bg_color, ThemeTokens.GAMEPLAY_ALERT, "dolu kutu oyun rengi")
	is_true(_contrast(active.bg_color, ThemeTokens.tone().surface_color) >= 3.0, "dolu kutu panel zemininde")
	eq(ladder.theme_type_variation, &"HudChip", "yarı saydam dar panel")
	is_true(ladder.size.y <= 60.0, "merdiven tek satır (%.0f px)" % ladder.size.y)


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(lin.call(c.r)) + 0.7152 * float(lin.call(c.g)) + 0.0722 * float(lin.call(c.b))
