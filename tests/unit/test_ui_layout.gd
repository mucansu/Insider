extends TestCase
## Düzen (US-003 AC6): 1280×720 ve 1920×1080'de, her tonda ve her dilde, en uzun içerikle ekran
## öğeleri görünür alanın dışına taşmaz, sıkışmaz ve ana bloklar birbirinin üstüne binmez.
## Ekran görüntüsü headless alınamadığından kontrol boyut/konum üzerinden yapılır.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const LOCALES: Array[String] = ["tr", "en"]
## En geniş harflerle azami uzunlukta ad.
const LONG_NAME := "WWWWWWWWWWWWWWWW"
## Bir piksel altı yuvarlama payı.
const EPSILON := 0.5
## En kalabalık davet bölümü (US-026): Tailscale yok (not satırı) ve en çok adayla, en uzun adresler.
const WORST_ADDRESSES: Array[String] = ["192.168.100.100", "172.31.255.255", "10.100.100.100", "192.168.200.200",
	"10.200.200.200", "172.16.100.100"]
const SETTLE_FRAMES := 3


func test_main_menu_fits() -> void:
	await _each_variant(func(size: Vector2i, label: String) -> void:
		var ctx: Dictionary = await _open_menu(size)
		var menu: MainMenu = ctx["menu"]
		var net: Fakes.FakeNet = ctx["net"]
		# Form + en uzun hata.
		(menu.get_node("%NameEdit") as LineEdit).text = LONG_NAME
		(menu.get_node("%HostPortEdit") as LineEdit).text = "65535"
		net.host_result = ERR_CANT_CREATE
		(menu.get_node("%HostButton") as Button).pressed.emit()
		await _settle()
		is_true((menu.get_node("%ErrorPanel") as Control).visible, label + ": hata görünür")
		_check_fits(menu, size, label + " form+hata")
		_check_disjoint([menu.get_node("%NameEdit"), menu.get_node("Center/Column/Form/Cards/HostCard"),
			menu.get_node("Center/Column/Form/Cards/JoinCard"), menu.get_node("%QuitButton"),
			menu.get_node("%ErrorPanel")], label + " form")
		# US-026: "Gelişmiş" açık (port görünür), davet notu görünür, en uzun yapıştırma hatası.
		is_true((menu.get_node("%HostInvite").get_node("%NoteLabel") as Control).visible, label + ": davet notu")
		(menu.get_node("%AdvancedButton") as Button).button_pressed = true
		menu.clipboard_getter = func() -> String: return ""
		(menu.get_node("%PasteButton") as Button).pressed.emit()
		await _settle()
		_check_fits(menu, size, label + " form+gelişmiş+hata")
		_check_disjoint([menu.get_node("%NameEdit"), menu.get_node("Center/Column/Form/Cards/HostCard"),
			menu.get_node("Center/Column/Form/Cards/JoinCard"), menu.get_node("%QuitButton"),
			menu.get_node("%ErrorPanel")], label + " form+gelişmiş")
		# Bağlanıyor, en uzun adresle.
		(menu.get_node("%JoinAddressEdit") as LineEdit).text = "w".repeat(60) + ".example.ts.net"
		(menu.get_node("%JoinButton") as Button).pressed.emit()
		await _settle()
		eq(menu.state, MainMenu.State.CONNECTING, label)
		_check_fits(menu, size, label + " bağlanıyor")
		# Host açılıyor (Vazgeç görünür).
		(menu.get_node("%CancelButton") as Button).pressed.emit()
		net.host_result = OK
		(menu.get_node("%HostButton") as Button).pressed.emit()
		await _settle()
		eq(menu.state, MainMenu.State.STARTING, label)
		_check_fits(menu, size, label + " host açılıyor")
	)


func test_pause_invite_fits() -> void:
	# US-026: host'ta duraklat menüsü, davet listesi açık, en çok adayla (Tailscale yok → not satırı).
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
		game.team_cash_changed.emit(1999999999)
		net.ping_ms = 9999
		hud.refresh_ping()
		for i: int in Hud.MAX_TOASTS:
			game.session_event.emit(&"police_called", {})
		game.session_event.emit(&"an_unusually_long_unknown_event_kind_for_layout_checks", {})
		var player: Node = autofree(Fakes.FakePlayer.new()) as Node
		game.local_player_changed.emit(player)
		player.emit_signal(&"interaction_target_changed", "MENU_ERROR_CONNECTION_FAILED")
		await _settle()
		_check_fits(hud.get_node("%Root"), size, label + " HUD istem")
		near((hud.get_node("%Prompt") as Control).get_global_rect().get_center().x, size.x / 2.0, 2.0, label + ": istem ortada")
		player.emit_signal(&"interaction_started", "MENU_ERROR_CONNECTION_FAILED", 3.0)
		await _settle()
		_check_fits(hud.get_node("%Root"), size, label + " HUD")
		var top: String = "Root/Frame/Layout/Top/"
		_check_disjoint([hud.get_node(top + "CashPanel"), hud.get_node("%Toasts"), hud.get_node(top + "Right"),
			hud.get_node("%Interaction")], label + " HUD blokları")
		for block: String in ["%Toasts", "%Interaction"]:
			var first: Control = hud.get_node(block) as Control
			if block == "%Toasts":
				first = first.get_child(0) as Control
			near(first.get_global_rect().get_center().x, size.x / 2.0, 2.0, "%s: %s ekran ortasında" % [label, block])
		hud.toggle_pause()
		await _settle()
		_check_fits(hud.get_node("%PauseMenu"), size, label + " duraklat")
	)


# --- yardımcılar ---

## Her ton × dil × boyut için `body(size, label)` çalıştırır; sonra ton ve dili geri alır.
func _each_variant(body: Callable) -> void:
	var previous_locale: String = TranslationServer.get_locale()
	for tone: Tone in ThemeTokens.available_tones():
		ThemeTokens.set_tone(tone)
		for locale: String in LOCALES:
			TranslationServer.set_locale(locale)
			for size: Vector2i in SIZES:
				await body.call(size, "%s/%s/%dx%d" % [tone.id, locale, size.x, size.y])
	ThemeTokens.set_tone(null)
	TranslationServer.set_locale(previous_locale)


func _viewport(size: Vector2i) -> SubViewport:
	var vp: SubViewport = autofree(SubViewport.new()) as SubViewport
	vp.size = size
	tree().root.add_child(vp)
	return vp


func _open_menu(size: Vector2i) -> Dictionary:
	var pair: Array = Fakes.make_pair(self)
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.net = pair[0]
	menu.game = pair[1]
	(menu.get_node("%HostInvite") as InvitePanel).addresses_provider = func() -> PackedStringArray:
		return PackedStringArray(WORST_ADDRESSES)
	_viewport(size).add_child(menu)
	await _settle()
	return {"menu": menu, "net": pair[0], "game": pair[1]}


func _open_hud(size: Vector2i) -> Dictionary:
	var pair: Array = Fakes.make_pair(self)
	var hud: Hud = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	hud.net = pair[0]
	hud.game = pair[1]
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(_missing_key: String) -> void: pass  # bilinmeyen olay türü bilerek gönderilir
	_viewport(size).add_child(hud)
	await _settle()
	return {"hud": hud, "net": pair[0], "game": pair[1]}


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await tree().process_frame


## Görünen her Control alanın içinde; metin taşıyan öğeler en küçük boyutlarından dar değil.
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


## Görünen bloklar ikişer ikişer kesişmez.
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
