extends TestCase
## Vision UI (US-011c; GDD §6.5): the HUD exposure badge (hidden / visible / seen), the teammate "seen" eye and off-screen edge
## arrow (scarf colour), the host's vision mode choice in the main menu. If Game does not carry the vision addition (S3 addition;
## mimari.md, US-011b/c) all stay hidden.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const MENU_SCENE := preload("res://ui/main_menu.tscn")
const BADGE_SCENE := preload("res://ui/exposure_badge.tscn")
const SCREEN := Vector2i(1280, 720)

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var journal: Fakes.CallLog
var viewport: SubViewport
var hud: Hud
var menu: MainMenu
## The HUD's missing-text warnings; the vision elements never produce a warning.
var warnings: Array[String] = []


func _viewport() -> SubViewport:
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = SCREEN
	tree().root.add_child(viewport)
	return viewport


func _fakes(vision: bool) -> void:
	var pair: Array = Fakes.make_pair(self, vision)
	net = pair[0]
	game = pair[1]
	journal = pair[2]


## Opens the HUD; `before_ready` prepares the fakes before they are added to the scene.
func _open_hud(vision: bool = true, before_ready: Callable = Callable()) -> void:
	_fakes(vision)
	if before_ready.is_valid():
		before_ready.call()
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(missing_key: String) -> void: warnings.append(missing_key)
	_viewport().add_child(hud)
	await tree().process_frame


func _open_menu(vision: bool = true, before_ready: Callable = Callable()) -> void:
	_fakes(vision)
	if before_ready.is_valid():
		before_ready.call()
	menu = MENU_SCENE.instantiate() as MainMenu
	menu.net = net
	menu.game = game
	_viewport().add_child(menu)
	await tree().process_frame


func _vgame() -> Fakes.FakeVisionGame:
	return game as Fakes.FakeVisionGame


func _badge() -> ExposureBadge:
	return hud.get_node("%ExposureBadge") as ExposureBadge


func _markers() -> TeamMarkers:
	return hud.get_node("%TeamMarkers") as TeamMarkers


func _badge_text() -> String:
	return (_badge().get_node("%ExposureLabel") as Label).text


func _menu_node(unique_name: String) -> Control:
	return menu.get_node("%" + unique_name) as Control


func _focused() -> String:
	var owner: Control = viewport.gui_get_focus_owner()
	return str(owner.name) if owner != null else "<yok>"


static func _key(keycode: Key, pressed: bool = true, shift: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	e.shift_pressed = shift
	return e


static func _joy(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


## A three-person crew: local 1 (slot 0), friends 2 (slot 1) and 3 (slot 2).
func _crew() -> void:
	net.my_peer_id = 1
	game.roster = {1: {"name": "Ada", "slot": 0}, 2: {"name": "Bo", "slot": 1}, 3: {"name": "Cem", "slot": 2}}


func _markers_of(peer: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in _markers().markers():
		if int(m["peer"]) == peer:
			out.append(m)
	return out


# --- badge ---

func test_badge_hidden_without_exposure_api() -> void:
	await _open_hud(false)
	is_false(_badge().visible, "Game maruziyet vermiyorsa rozet gizli")
	is_false(_markers().visible, "Game konum vermiyorsa ekip işaretleri gizli")
	hud.advance(0.1)
	eq(warnings, [] as Array[String], "uyarı yok")


func test_hidden_with_real_game_until_contract_lands() -> void:
	var badge: ExposureBadge = BADGE_SCENE.instantiate() as ExposureBadge
	_viewport().add_child(badge)
	var fake_net: Fakes.FakeNet = autofree(Fakes.FakeNet.new()) as Fakes.FakeNet
	badge.bind(Game, fake_net)
	eq(badge.visible, ExposureBadge.supports(Game), "gerçek Game: API yoksa gizli, gelince görünür")
	var markers := TeamMarkers.new()
	viewport.add_child(markers)
	markers.bind(Game, fake_net)
	eq(markers.visible, TeamMarkers.supports(Game))
	if not TeamMarkers.supports(Game):
		markers.advance(0.1)  # while hidden the position is not queried (no error)
		eq(markers.markers().size(), 0)


func test_badge_initial_state_and_local_signal() -> void:
	await _open_hud(true, func() -> void:
		_crew()
		_vgame().exposure = {1: 1, 2: 2})
	var badge: ExposureBadge = _badge()
	is_true(badge.visible)
	eq(badge.level(), EyeIcon.VISIBLE, "ilk durum player_exposure(yerel)'den")
	eq(_badge_text(), tr("HUD_EXPOSURE_VISIBLE"))
	_vgame().player_exposure_changed.emit(2, 0)
	eq(badge.level(), EyeIcon.VISIBLE, "başka peer'ın değişimi rozeti etkilemez")
	_vgame().player_exposure_changed.emit(1, 2)
	eq(badge.level(), EyeIcon.SEEN)
	eq(_badge_text(), tr("HUD_EXPOSURE_SEEN"))
	eq((badge.get_node("%ExposureLabel") as Label).theme_type_variation, &"AlertLabel", "görüldü uyarı renginde")
	eq((badge.get_node("%EyeIcon") as EyeIcon).level, EyeIcon.SEEN, "göz şekli de değişir")
	_vgame().player_exposure_changed.emit(1, 0)
	eq(_badge_text(), tr("HUD_EXPOSURE_HIDDEN"))
	eq((badge.get_node("%ExposureLabel") as Label).theme_type_variation, &"MutedLabel")
	_vgame().player_exposure_changed.emit(1, 7)
	eq(badge.level(), EyeIcon.SEEN, "aralık dışı değer kırpılır")


func test_badge_pop_and_reduce_motion() -> void:
	await _open_hud()
	var badge: ExposureBadge = _badge()
	is_false(badge.is_popping(), "ilk durum pop'suz")
	badge.set_level(EyeIcon.SEEN)
	is_true(badge.is_popping(), "yükselişte pop")
	await tree().create_timer(ExposureBadge.POP_SEC + 0.1).timeout
	badge.set_level(EyeIcon.HIDDEN)
	is_false(badge.is_popping(), "düşüşte pop yok")
	badge.reduce_motion = true
	badge.set_level(EyeIcon.SEEN)
	is_false(badge.is_popping(), "hareket azaltmada pop yok")
	eq(badge.level(), EyeIcon.SEEN, "durum yine anında")


func test_eye_colors_and_sizes() -> void:
	eq(EyeIcon.color_for(EyeIcon.SEEN), ThemeTokens.GAMEPLAY_ALERT, "görüldü oyun uyarı rengi")
	is_true(EyeIcon.color_for(EyeIcon.HIDDEN) != EyeIcon.color_for(EyeIcon.VISIBLE), "gizli ve görünür ayrışır")
	# GDD §14.1: game-info markers >= 22 px at 1280x720.
	is_true(TeamMarkers.ARROW_SIZE >= 22.0 and TeamMarkers.SEEN_ICON_SIZE >= 22.0, "işaretler ≥ 22 px")
	await _open_hud()
	var icon: Control = _badge().get_node("%EyeIcon") as Control
	is_true(icon.size.x >= 22.0 and icon.size.y >= 22.0, "rozet gözü ≥ 22 px: %s" % icon.size)
	near(_badge().get_global_rect().position.x, ThemeTokens.SCREEN_MARGIN, 1.0, "rozet sol kenarda")
	is_true(_badge().get_global_rect().end.y > SCREEN.y * 0.85, "rozet altta")


# --- crew markers ---

func test_edge_point() -> void:
	var rect := Rect2(0, 0, 100, 100)
	eq(TeamMarkers.edge_point(Vector2(200, 50), rect), Vector2(100, 50))
	eq(TeamMarkers.edge_point(Vector2(50, -150), rect), Vector2(50, 0))
	eq(TeamMarkers.edge_point(Vector2(300, 150), rect), Vector2(100, 70))
	eq(TeamMarkers.edge_point(Vector2(30, 40), rect), Vector2(30, 40), "içerideki nokta değişmez")


func test_push_clear() -> void:
	var inner := Rect2(10, 10, 80, 80)
	var blocks: Array[Rect2] = [Rect2(0, 0, 40, 20)]
	eq(TeamMarkers.push_clear(Vector2(20, 10), inner, blocks, 5.0), Vector2(20, 25), "üst kenar: bloğun altına")
	eq(TeamMarkers.push_clear(Vector2(10, 10), inner, blocks, 5.0), Vector2(10, 25), "köşe: önce üst kenar kuralı")
	eq(TeamMarkers.push_clear(Vector2(10, 15), inner, blocks, 5.0), Vector2(45, 15), "sol kenar: bloğun sağına")
	eq(TeamMarkers.push_clear(Vector2(60, 10), inner, blocks, 5.0), Vector2(60, 10), "blok dışında değişmez")
	eq(TeamMarkers.push_clear(Vector2(90, 50), inner, [Rect2(80, 40, 30, 20)] as Array[Rect2], 5.0), Vector2(75, 50), "sağ kenar: sola")


func test_arrows_avoid_hud_blocks() -> void:
	# A friend off-screen at top left: the arrow falls below the cash panel, not above it.
	await _open_hud(true, func() -> void:
		_crew()
		_vgame().exposure = {2: 2}
		_vgame().positions = {2: Vector2(-300, -200), 3: Vector2(1600, -300)})
	var layer: TeamMarkers = _markers()
	layer.world_to_screen = func(p: Vector2) -> Vector2: return p
	await tree().process_frame
	layer.refresh()
	eq(layer.markers().size(), 2)
	var half: float = TeamMarkers.ARROW_SIZE / 2.0
	for m: Dictionary in layer.markers():
		var arrow := Rect2(m["pos"] - Vector2(half, half), Vector2(half, half) * 2.0)
		for block: Control in layer.avoid:
			if block.is_visible_in_tree():
				is_true(arrow.intersection(block.get_global_rect()).get_area() < 1.0,
					"peer %d oku %s ile çakışıyor" % [m["peer"], block.name])


func test_markers_arrow_and_seen_icon() -> void:
	await _open_hud(true, func() -> void:
		_crew()
		_vgame().exposure = {1: 2}
		_vgame().positions = {1: Vector2(640, 360), 2: Vector2(700, 300), 3: Vector2(2000, 360)})
	var layer: TeamMarkers = _markers()
	is_true(layer.visible)
	layer.world_to_screen = func(p: Vector2) -> Vector2: return p
	layer.refresh()
	eq(_markers_of(1).size(), 0, "yerel oyuncu için dünya işareti yok (rozet var)")
	eq(_markers_of(2).size(), 0, "ekrandaki, görülmeyen arkadaşa işaret yok")
	var arrows: Array[Dictionary] = _markers_of(3)
	if eq(arrows.size(), 1, "ekran dışı arkadaşa ok"):
		var arrow: Dictionary = arrows[0]
		eq(arrow["kind"], &"arrow")
		eq(arrow["pos"], Vector2(SCREEN.x - TeamMarkers.EDGE_MARGIN, SCREEN.y / 2.0), "sağ kenarda, aynı hizada")
		near(float(arrow["angle"]), 0.0, 0.001, "sağa bakar")
		eq(arrow["color"], ThemeTokens.PLAYER_COLORS[2], "atkı rengi (slot)")
		is_false(arrow["seen"])
	_vgame().player_exposure_changed.emit(2, 2)
	_vgame().player_exposure_changed.emit(3, 2)
	layer.advance(0.016)
	var seen: Array[Dictionary] = _markers_of(2)
	if eq(seen.size(), 1, "görülen arkadaşın üstünde göz"):
		eq(seen[0]["kind"], &"seen")
		eq(seen[0]["pos"], Vector2(700, 300) + TeamMarkers.SEEN_ANCHOR, "sabit bağlantı noktası")
	is_true(bool(_markers_of(3)[0]["seen"]), "ekran dışındaki görülen arkadaşın okunda göz")
	_vgame().player_exposure_changed.emit(2, 1)
	layer.refresh()
	eq(_markers_of(2).size(), 0, "görünür (1) arkadaşa göz çizilmez")
	await tree().process_frame  # draws without error


func test_markers_use_canvas_transform_and_skip_unknown() -> void:
	await _open_hud(true, func() -> void:
		_crew()
		game.roster[4] = {"name": "Dee", "slot": 3}
		_vgame().exposure = {2: 2}
		_vgame().positions = {1: Vector2(0, 0), 2: Vector2(100, 100), 3: Vector2(-400, 100)})
	# Camera zoom 1.5; world (0,0) at screen (640,360).
	viewport.canvas_transform = Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2(640, 360))
	var layer: TeamMarkers = _markers()
	layer.refresh()
	eq(_markers_of(4).size(), 0, "konumu olmayan oyuncu atlanır")
	var seen: Array[Dictionary] = _markers_of(2)
	if eq(seen.size(), 1):
		eq(seen[0]["pos"], Vector2(640, 360) + (Vector2(100, 100) + TeamMarkers.SEEN_ANCHOR) * 1.5, "dünya → ekran")
	# -400 x 1.5 + 640 = 40: on screen (even in the edge margin) -> no marker if not seen.
	var arrows: Array[Dictionary] = _markers_of(3)
	eq(arrows.size(), 0, "ekrandaki arkadaşa ok yok")
	_vgame().positions[3] = Vector2(-500, 100)
	layer.refresh()
	arrows = _markers_of(3)
	if eq(arrows.size(), 1, "ekran dışı (x = -110)"):
		near(float((arrows[0]["pos"] as Vector2).x), TeamMarkers.EDGE_MARGIN, 0.01, "sol kenarda")
		eq(arrows[0]["color"], ThemeTokens.PLAYER_COLORS[2])


func test_players_changed_rereads_exposure() -> void:
	await _open_hud(true, func() -> void:
		_crew()
		_vgame().positions = {2: Vector2(100, 100)})
	var layer: TeamMarkers = _markers()
	layer.world_to_screen = func(p: Vector2) -> Vector2: return p
	layer.refresh()
	eq(_markers_of(2).size(), 0)
	_vgame().exposure = {2: 2}
	game.players_changed.emit()
	layer.refresh()
	eq(_markers_of(2).size(), 1, "oyuncu listesi değişince maruziyet yeniden okunur")


# --- main menu: the host's vision mode ---

func test_menu_vision_hidden_without_api() -> void:
	await _open_menu(false)
	is_false(_menu_node("VisionOption").visible)
	is_false(_menu_node("VisionLabel").visible)
	is_false(_menu_node("VisionHint").visible)
	(_menu_node("NameEdit") as LineEdit).text = "Ada"
	(_menu_node("HostButton") as Button).pressed.emit()
	eq(journal.names(), PackedStringArray(["set_local_name", "host", "start_level"]), "görüş çağrısı yok")


func test_menu_vision_default_from_game_and_host_order() -> void:
	await _open_menu(true, func() -> void: _vgame().vision = MainMenu.VISION_DIRECTIONAL)
	var option: OptionButton = _menu_node("VisionOption") as OptionButton
	is_true(option.visible and _menu_node("VisionLabel").visible and _menu_node("VisionHint").visible)
	eq(option.item_count, 2)
	eq(option.get_item_text(option.get_item_index(MainMenu.VISION_OMNI)), "MENU_VISION_OMNI")
	eq(option.get_item_text(option.get_item_index(MainMenu.VISION_DIRECTIONAL)), "MENU_VISION_DIRECTIONAL")
	eq(menu.vision_mode(), MainMenu.VISION_DIRECTIONAL, "varsayılan Game'den")
	option.select(option.get_item_index(MainMenu.VISION_OMNI))
	(_menu_node("NameEdit") as LineEdit).text = "Ada"
	(_menu_node("HostButton") as Button).pressed.emit()
	eq(journal.entries, [["set_local_name", "Ada"], ["host", MainMenu.DEFAULT_PORT],
		["set_vision_mode", MainMenu.VISION_OMNI], ["start_level", Game.DEFAULT_LEVEL]], "seviye başlamadan kip iletilir")


func test_menu_vision_not_sent_on_join_or_host_failure() -> void:
	await _open_menu()
	(_menu_node("NameEdit") as LineEdit).text = "Ada"
	net.host_result = ERR_CANT_CREATE
	(_menu_node("HostButton") as Button).pressed.emit()
	eq(journal.names(), PackedStringArray(["set_local_name", "host"]), "host açılamazsa kip gönderilmez")
	(_menu_node("JoinAddressEdit") as LineEdit).text = "10.0.0.9"
	(_menu_node("JoinButton") as Button).pressed.emit()
	is_false(journal.names().has("set_vision_mode"), "katılan istemci kip seçmez")


func test_menu_vision_focus_order() -> void:
	# IS-078: the vision choice is on the same row as the host port (so it fits 720p with the invite panel);
	# reached with left/right and Tab, not in the vertical chain.
	await _open_menu()
	_menu_node("NameEdit").grab_focus()
	var down: Array[String] = []
	for i: int in 5:
		viewport.push_input(_key(KEY_DOWN))
		down.append(_focused())
	eq(down, ["CopyButton", "HostPortEdit", "HostButton", "QuitButton", "NameEdit"] as Array[String], "aşağı ok")
	var tabs: Array[String] = []
	for i: int in 10:
		viewport.push_input(_key(KEY_TAB))
		tabs.append(_focused())
	eq(tabs, ["CopyButton", "HostPortEdit", "VisionOption", "HostButton", "JoinAddressEdit", "PasteButton",
		"AdvancedButton", "JoinButton", "QuitButton", "NameEdit"] as Array[String], "Tab halkası")
	# Gamepad row: host port <-> vision <-> Advanced.
	_menu_node("HostPortEdit").grab_focus()
	var row: Array[String] = []
	for b: JoyButton in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_LEFT]:
		viewport.push_input(_joy(b))
		row.append(_focused())
	eq(row, ["VisionOption", "AdvancedButton", "VisionOption", "HostPortEdit"] as Array[String], "gamepad sağ/sol satırı")
	_menu_node("VisionOption").grab_focus()
	viewport.push_input(_joy(JOY_BUTTON_DPAD_UP))
	eq(_focused(), "CopyButton", "gamepad yukarı: görüş → davet")
	_menu_node("VisionOption").grab_focus()
	viewport.push_input(_joy(JOY_BUTTON_DPAD_DOWN))
	eq(_focused(), "HostButton", "gamepad aşağı: görüş → Host ol")
	# Advanced open: from the Join port left to vision; in the Tab ring the port comes after Advanced.
	(_menu_node("AdvancedButton") as Button).button_pressed = true
	_menu_node("JoinPortEdit").grab_focus()
	viewport.push_input(_joy(JOY_BUTTON_DPAD_LEFT))
	eq(_focused(), "VisionOption", "gamepad sol: Katıl portu → görüş")
	_menu_node("AdvancedButton").grab_focus()
	viewport.push_input(_key(KEY_TAB))
	eq(_focused(), "JoinPortEdit", "Tab: Gelişmiş → Katıl portu")


func test_menu_focus_row_without_vision() -> void:
	# When vision is hidden the host port row links directly to Advanced (focus never goes to a hidden element).
	await _open_menu(false)
	_menu_node("HostPortEdit").grab_focus()
	viewport.push_input(_joy(JOY_BUTTON_DPAD_RIGHT))
	eq(_focused(), "AdvancedButton", "gamepad sağ: port → Gelişmiş")
	viewport.push_input(_joy(JOY_BUTTON_DPAD_LEFT))
	eq(_focused(), "HostPortEdit", "gamepad sol: Gelişmiş → port")
	(_menu_node("AdvancedButton") as Button).button_pressed = true
	_menu_node("JoinPortEdit").grab_focus()
	viewport.push_input(_joy(JOY_BUTTON_DPAD_LEFT))
	eq(_focused(), "HostPortEdit", "gamepad sol: Katıl portu → host portu")
	_menu_node("HostPortEdit").grab_focus()
	viewport.push_input(_key(KEY_TAB))
	eq(_focused(), "HostButton", "Tab: görüş yokken port → Host ol")
