extends TestCase
## Layout (US-003 AC6): at 1280x720 and 1920x1080, in every tone and every language, with the longest content, screen elements do
## not overflow the visible area, are not squeezed and the main blocks do not overlap.
## Screenshots cannot be taken headless, so the check is done via size/position.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const LOCALES: Array[String] = ["tr", "en"]
## A name of maximum length in the widest letters.
const LONG_NAME := "WWWWWWWWWWWWWWWW"
## A sub-pixel rounding margin.
const EPSILON := 0.5
## The most crowded invite section (US-026): no Tailscale (note line) and with the most candidates, the longest addresses.
const WORST_ADDRESSES: Array[String] = ["192.168.100.100", "172.31.255.255", "10.100.100.100", "192.168.200.200",
	"10.200.200.200", "172.16.100.100"]
const SETTLE_FRAMES := 3
## The job-end screen is also checked at Steam Deck resolution (steam-yayin.md: 1280x800, text >= 12 px).
const END_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080)]
const DECK_MIN_FONT := 12
## The top HUD (cash, crew, alert ladder) with the longest content covers at most this fraction of the screen (US-013).
const MAX_TOP_COVERAGE := 0.075


func test_main_menu_fits() -> void:
	await _each_variant(func(size: Vector2i, label: String) -> void:
		var ctx: Dictionary = await _open_menu(size)
		var menu: MainMenu = ctx["menu"]
		var net: Fakes.FakeNet = ctx["net"]
		# Form + the longest error.
		(menu.get_node("%NameEdit") as LineEdit).text = LONG_NAME
		(menu.get_node("%HostPortEdit") as LineEdit).text = "65535"
		net.host_result = ERR_CANT_CREATE
		(menu.get_node("%HostButton") as Button).pressed.emit()
		await _settle()
		is_true((menu.get_node("%ErrorPanel") as Control).visible, label + ": hata görünür")
		_check_fits(menu, size, label + " form+hata")
		is_true((menu.get_node("%VisionOption") as Control).visible, label + ": görüş seçimi görünür")
		_check_disjoint([menu.get_node("%NameEdit"), menu.get_node("Center/Column/Form/Cards/HostCard"),
			menu.get_node("Center/Column/Form/Cards/JoinCard"), menu.get_node("%QuitButton"),
			menu.get_node("%ErrorPanel")], label + " form")
		# US-026: "Advanced" open (port visible), invite note visible, the longest paste error.
		is_true((menu.get_node("%HostInvite").get_node("%NoteLabel") as Control).visible, label + ": davet notu")
		(menu.get_node("%AdvancedButton") as Button).button_pressed = true
		menu.clipboard_getter = func() -> String: return ""
		(menu.get_node("%PasteButton") as Button).pressed.emit()
		await _settle()
		_check_fits(menu, size, label + " form+gelişmiş+hata")
		_check_disjoint([menu.get_node("%NameEdit"), menu.get_node("Center/Column/Form/Cards/HostCard"),
			menu.get_node("Center/Column/Form/Cards/JoinCard"), menu.get_node("%QuitButton"),
			menu.get_node("%ErrorPanel")], label + " form+gelişmiş")
		# Connecting, with the longest address.
		(menu.get_node("%JoinAddressEdit") as LineEdit).text = "w".repeat(60) + ".example.ts.net"
		(menu.get_node("%JoinButton") as Button).pressed.emit()
		await _settle()
		eq(menu.state, MainMenu.State.CONNECTING, label)
		_check_fits(menu, size, label + " bağlanıyor")
		# Host starting (Cancel visible).
		(menu.get_node("%CancelButton") as Button).pressed.emit()
		net.host_result = OK
		(menu.get_node("%HostButton") as Button).pressed.emit()
		await _settle()
		eq(menu.state, MainMenu.State.STARTING, label)
		_check_fits(menu, size, label + " host açılıyor")
	)


func test_pause_invite_fits() -> void:
	# US-026: pause menu on the host, invite list open, with the most candidates (no Tailscale -> note line).
	await _each_variant(func(size: Vector2i, label: String) -> void:
		var ctx: Dictionary = await _open_hud(size)
		var hud: Hud = ctx["hud"]
		var net: Fakes.FakeNet = ctx["net"]
		net.hosting = true
		var pause: PauseMenu = hud.get_node("%PauseMenu") as PauseMenu
		pause.net = net
		var invite: InvitePanel = pause.get_node("%Invite") as InvitePanel
		invite.addresses_provider = func() -> PackedStringArray: return PackedStringArray(WORST_ADDRESSES)
		ConnectInfo.hosted_port = ConnectInfo.MAX_PORT
		hud.toggle_pause()
		(invite.get_node("%AddressButton") as Button).button_pressed = true
		await _settle()
		is_true(invite.visible and invite.is_list_open(), label + ": davet listesi açık")
		_check_fits(pause, size, label + " duraklat+davet")
		ConnectInfo.hosted_port = 0
	)


func test_hud_fits() -> void:
	await _each_variant(func(size: Vector2i, label: String) -> void:
		var ctx: Dictionary = await _open_hud(size)
		var hud: Hud = ctx["hud"]
		var game: Fakes.FakeGame = ctx["game"]
		var net: Fakes.FakeNet = ctx["net"]
		var roster: Dictionary = {}
		for i: int in 4:
			roster[i + 1] = {"name": LONG_NAME, "slot": i}
		game.roster = roster
		net.my_peer_id = 3
		game.players_changed.emit()
		(game as Fakes.FakeVisionGame).player_exposure_changed.emit(3, 2)  # longest badge text
		for i: int in 4:  # IS-110: every crew row has a held badge, the local player's big countdown is up
			game.session_event.emit(&"player_held", {"peer": i + 1, "window": 6.0})
		game.team_cash_changed.emit(1999999999)
		net.ping_ms = 9999
		hud.refresh_ping()
		game.timer_left = 5999.0
		game.alert_level_changed.emit(3)
		for i: int in Hud.MAX_TOASTS:
			game.session_event.emit(&"police_called", {})
		game.session_event.emit(&"an_unusually_long_unknown_event_kind_for_layout_checks", {})
		var player: Node = autofree(Fakes.FakePlayer.new()) as Node
		game.local_player_changed.emit(player)
		player.emit_signal(&"interaction_target_changed", "MENU_ERROR_CONNECTION_FAILED")
		player.emit_signal(&"interaction_alt_target_changed", "MENU_ERROR_CONNECTION_FAILED")  # IS-091 Q line
		await _settle()
		_check_fits(hud.get_node("%Root"), size, label + " HUD istem")
		near((hud.get_node("%Prompt") as Control).get_global_rect().get_center().x, size.x / 2.0, 2.0, label + ": istem ortada")
		player.emit_signal(&"interaction_started", "MENU_ERROR_CONNECTION_FAILED", 3.0)
		await _settle()
		_check_fits(hud.get_node("%Root"), size, label + " HUD")
		_check_fonts(hud.get_node("%Root"), label + " HUD")
		var top: String = "Root/Frame/Layout/Top/"
		_check_disjoint([hud.get_node(top + "CashPanel"), hud.get_node("%Toasts"), hud.get_node(top + "Right"),
			hud.get_node("%Interaction"), hud.get_node("%AlertLadder"), hud.get_node("%ExposureBadge"),
			hud.get_node("%HeldCountdown")], label + " HUD blokları")
		is_true((hud.get_node("%HeldCountdown") as Control).visible, label + ": tutuldun geri sayımı görünür")
		is_true((hud.get_node("%ExposureBadge") as Control).visible, label + ": maruziyet rozeti görünür")
		# US-013: corner elements and the ladder cover little of the map (even with the longest content).
		var covered: float = 0.0
		for block: Node in [hud.get_node(top + "CashPanel"), hud.get_node(top + "Right/PlayersPanel"), hud.get_node("%AlertLadder")]:
			covered += (block as Control).get_global_rect().get_area()
		is_true(covered <= MAX_TOP_COVERAGE * size.x * size.y, "%s: üst HUD ekranın %%%.1f'ini örtüyor" % [label, 100.0 * covered / (size.x * size.y)])
		for block: String in ["%Toasts", "%Interaction", "%AlertLadder"]:
			var first: Control = hud.get_node(block) as Control
			if block == "%Toasts":
				first = first.get_child(0) as Control
			near(first.get_global_rect().get_center().x, size.x / 2.0, 2.0, "%s: %s ekran ortasında" % [label, block])
		hud.toggle_pause()
		await _settle()
		_check_fits(hud.get_node("%PauseMenu"), size, label + " duraklat")
	)


func test_heist_end_fits() -> void:
	# Longest content: 4 players with maximum names, the largest amounts, 3 notes with the longest descriptions; win and loss.
	var longest_notes: Array = [{"kind": &"pulled_free", "peer": 1}, {"kind": &"window_star", "peer": 2},
		{"kind": &"owner_favourite", "peer": 4}]
	await _each_variant(func(size: Vector2i, label: String) -> void:
		var ctx: Dictionary = await _open_hud(size)
		var hud: Hud = ctx["hud"]
		var game: Fakes.FakeGame = ctx["game"]
		(ctx["net"] as Fakes.FakeNet).my_peer_id = 4
		var players: Dictionary = {}
		for i: int in 4:
			players[str(i + 1)] = {"name": "W".repeat(MainMenu.MAX_NAME_LENGTH), "slot": i, "escaped": i < 2,
				"caught": i >= 2, "loot": 1999999999}
		for outcome: StringName in [&"shouted", &"caught_all"]:
			game.heist_finished.emit({"outcome": outcome, "loot_total": 1999999999, "payout_ratio": 0.85,
				"payout": 1999999999, "duration_s": 5999.0, "players": players, "notes": longest_notes})
			await _settle()
			var screen: Control = hud.get_node("%HeistEnd") as Control
			is_true(screen.visible, label)
			var what: String = "%s iş sonu %s" % [label, outcome]
			_check_fits(screen, size, what)
			var box: String = "Center/Card/Box/"
			_check_disjoint([screen.get_node(box + "Header"), screen.get_node(box + "Body"), screen.get_node("%NotesBox"),
				screen.get_node(box + "Buttons")], what)
			_check_fonts(screen, what)
	, END_SIZES)


# --- helpers ---

## Every visible text is readable on Steam Deck (>= 12 px); other than the secondary title (CaptionLabel) all are >= body (18 px).
func _check_fonts(root: Node, label: String) -> void:
	var problems: PackedStringArray = []
	for c: Control in _visible_controls(root):
		if not (c is Label or c is Button):
			continue
		var font_size: int = c.get_theme_font_size(&"font_size")
		var floor_size: int = DECK_MIN_FONT if c.theme_type_variation == &"CaptionLabel" else ThemeTokens.FONT_SIZE_BODY
		if font_size < floor_size:
			problems.append("%s %d px" % [root.get_path_to(c), font_size])
	is_true(problems.is_empty(), "%s: küçük yazı: %s" % [label, "; ".join(problems.slice(0, 4))])


## Runs `body(size, label)` for every tone x language x size; then restores tone and language.
func _each_variant(body: Callable, sizes: Array[Vector2i] = SIZES) -> void:
	var previous_locale: String = TranslationServer.get_locale()
	for tone: Tone in ThemeTokens.available_tones():
		ThemeTokens.set_tone(tone)
		for locale: String in LOCALES:
			TranslationServer.set_locale(locale)
			for size: Vector2i in sizes:
				await body.call(size, "%s/%s/%dx%d" % [tone.id, locale, size.x, size.y])
	ThemeTokens.set_tone(null)
	TranslationServer.set_locale(previous_locale)


func _viewport(size: Vector2i) -> SubViewport:
	var vp: SubViewport = autofree(SubViewport.new()) as SubViewport
	vp.size = size
	tree().root.add_child(vp)
	return vp


## The fake Game carries the vision addition (US-011c): the vision choice in the menu and the exposure badge in the HUD enter the layout.
func _open_menu(size: Vector2i) -> Dictionary:
	var pair: Array = Fakes.make_pair(self, true)
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.net = pair[0]
	menu.game = pair[1]
	(menu.get_node("%HostInvite") as InvitePanel).addresses_provider = func() -> PackedStringArray:
		return PackedStringArray(WORST_ADDRESSES)
	_viewport(size).add_child(menu)
	await _settle()
	return {"menu": menu, "net": pair[0], "game": pair[1]}


func _open_hud(size: Vector2i) -> Dictionary:
	var pair: Array = Fakes.make_pair(self, true)
	var hud: Hud = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	hud.net = pair[0]
	hud.game = pair[1]
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(_missing_key: String) -> void: pass  # an unknown event kind is sent on purpose
	_viewport(size).add_child(hud)
	await _settle()
	return {"hud": hud, "net": pair[0], "game": pair[1]}


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await tree().process_frame


## Every visible Control is inside the area; text-bearing elements are not narrower than their minimum size.
func _check_fits(root: Node, size: Vector2i, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(size)).grow(EPSILON)
	var problems: PackedStringArray = []
	var checked: int = 0
	for c: Control in _visible_controls(root):
		checked += 1
		var r: Rect2 = c.get_global_rect()
		if not bounds.encloses(r):
			problems.append("taşma %s %s" % [root.get_path_to(c), r])
		if c is Label or c is Button or c is LineEdit or c is Container:
			var min_size: Vector2 = c.get_combined_minimum_size()
			if c.size.x + EPSILON < min_size.x or c.size.y + EPSILON < min_size.y:
				problems.append("sıkışma %s boyut %s < en küçük %s" % [root.get_path_to(c), c.size, min_size])
	is_true(checked > 5, "%s: denetlenecek öğe yok" % label)
	is_true(problems.is_empty(), "%s: %s" % [label, "; ".join(problems.slice(0, 4))])


## Visible blocks do not intersect pairwise.
func _check_disjoint(nodes: Array, label: String) -> void:
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for n: Variant in nodes:
		var c: Control = n as Control
		if c != null and c.is_visible_in_tree():
			rects.append(c.get_global_rect())
			names.append(str(c.name))
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			var overlap: Rect2 = rects[i].intersection(rects[j])
			is_true(overlap.get_area() < 1.0, "%s: %s ile %s üst üste (%s)" % [label, names[i], names[j], overlap])


static func _visible_controls(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	if root is Control and (root as Control).is_visible_in_tree():
		out.append(root as Control)
	for child: Node in root.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		out.append_array(_visible_controls(child))
	return out
