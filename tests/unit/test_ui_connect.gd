extends TestCase
## Bağlantı kolaylığı (US-026): davet adresi seçimi, "adres[:port]" ayrıştırma, pano metninden adres,
## ayar dosyası okuma/yazma, davet paneli (Kopyala, açılır liste) ve duraklat menüsünde yalnız host'ta görünmesi.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const INVITE_SCENE := preload("res://ui/invite_panel.tscn")
const PAUSE_SCENE := preload("res://ui/pause_menu.tscn")
## Geçici ayar dosyası (oyuncunun user://connect.cfg'sine dokunulmaz).
const TEMP_PATH := "user://test_ui_connect_io.cfg"


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _viewport() -> SubViewport:
	var vp: SubViewport = autofree(SubViewport.new()) as SubViewport
	vp.size = Vector2i(1280, 720)
	tree().root.add_child(vp)
	return vp


# --- adres seçici (saf) ---

func test_invite_candidates_prefer_tailscale() -> void:
	var real_windows: PackedStringArray = ["0:0:0:0:0:0:0:1", "127.0.0.1", "fe80:0:0:0:8c39:898c:33dc:6daf",
		"169.254.197.225", "192.168.56.1", "217.10.126.174", "100.88.12.4", "192.168.1.20"]
	eq(ConnectInfo.invite_candidates(real_windows), PackedStringArray(["100.88.12.4", "192.168.1.20", "192.168.56.1"]),
		"Tailscale önce, sonra LAN, VirtualBox en sonda; IPv6, 169.254, loopback, genel adres atlanır")
	eq(ConnectInfo.invite_candidates(["172.17.0.1", "192.168.56.1", "10.0.0.5", "172.18.0.1"]),
		PackedStringArray(["10.0.0.5", "172.18.0.1", "172.17.0.1", "192.168.56.1"]), "Docker/VirtualBox LAN sonunda")
	is_true(ConnectInfo.is_virtual_lan("192.168.56.200") and ConnectInfo.is_virtual_lan("172.17.5.5"))
	is_false(ConnectInfo.is_virtual_lan("192.168.57.1") or ConnectInfo.is_virtual_lan("172.18.0.1"))
	eq(ConnectInfo.invite_candidates(["100.64.0.1", "100.127.255.254", "100.64.0.1"]),
		PackedStringArray(["100.64.0.1", "100.127.255.254"]), "birden çok Tailscale: sıra korunur, tekrar atılır")


func test_invite_candidates_lan_and_fallback() -> void:
	eq(ConnectInfo.invite_candidates(["10.1.2.3", "172.16.0.1", "172.31.255.1", "192.168.0.7"]),
		PackedStringArray(["10.1.2.3", "172.16.0.1", "172.31.255.1", "192.168.0.7"]))
	eq(ConnectInfo.invite_candidates(["172.15.0.1", "172.32.0.1", "100.63.255.255", "100.128.0.1", "8.8.8.8"]),
		PackedStringArray([ConnectInfo.LOOPBACK]), "aralık sınırları dışında aday yok → 127.0.0.1")
	eq(ConnectInfo.invite_candidates([]), PackedStringArray([ConnectInfo.LOOPBACK]))
	eq(ConnectInfo.invite_candidates(["::1", "169.254.1.1", "127.0.0.1", "fe80::1"]), PackedStringArray([ConnectInfo.LOOPBACK]))
	is_true(ConnectInfo.is_tailscale("100.64.0.0") and ConnectInfo.is_tailscale("100.127.255.255"))
	is_false(ConnectInfo.is_tailscale("100.64.0") or ConnectInfo.is_tailscale("100.64.0.256") or ConnectInfo.is_tailscale("x"))
	is_false(ConnectInfo.is_private_lan("192.169.0.1") or ConnectInfo.is_private_lan("11.0.0.1"))


func test_invite_text_and_session_port() -> void:
	eq(ConnectInfo.invite_text("100.64.0.2", 7777), "100.64.0.2:7777")
	eq(ConnectInfo.format_address("100.64.0.2", 7777), "100.64.0.2", "varsayılan port yazılmaz")
	eq(ConnectInfo.format_address("100.64.0.2", 7780), "100.64.0.2:7780")
	var previous: int = ConnectInfo.hosted_port
	ConnectInfo.hosted_port = 0
	eq(ConnectInfo.session_port(7801), 7801, "menüden host olunmadıysa komut satırı portu")
	ConnectInfo.hosted_port = 7790
	eq(ConnectInfo.session_port(7801), 7790)
	ConnectInfo.hosted_port = previous
	eq(ConnectInfo.DEFAULT_PORT, MainMenu.DEFAULT_PORT)
	eq(ConnectInfo.MIN_PORT, MainMenu.MIN_PORT)
	eq(ConnectInfo.MAX_NAME_LENGTH, MainMenu.MAX_NAME_LENGTH)


# --- host:port ayrıştırma ---

func test_parse_host_port() -> void:
	eq(ConnectInfo.parse_host_port("100.64.0.2"), {"ok": true, "address": "100.64.0.2", "port": 7777})
	eq(ConnectInfo.parse_host_port("  100.64.0.2:7780 \t\n"), {"ok": true, "address": "100.64.0.2", "port": 7780}, "boşluklar")
	eq(ConnectInfo.parse_host_port("100.64.0.2 : 7780"), {"ok": true, "address": "100.64.0.2", "port": 7780}, "iki nokta çevresi")
	eq(ConnectInfo.parse_host_port("kasa-pc.tail1234.ts.net:9000"), {"ok": true, "address": "kasa-pc.tail1234.ts.net", "port": 9000})
	eq(ConnectInfo.parse_host_port("10.0.0.9", 8000)["port"], 8000, "port yoksa varsayılan")
	eq(ConnectInfo.parse_host_port("1.2.3.4:1024")["ok"], true, "alt sınır")
	eq(ConnectInfo.parse_host_port("1.2.3.4:65535")["ok"], true, "üst sınır")
	for bad: String in ["", "   ", "1.2.3.4:1023", "1.2.3.4:65536", "1.2.3.4:", "1.2.3.4:77x", "1.2.3.4:-7777",
			"256.1.1.1", "1.2.3", "1.2.3.4.5", "kasa pc", "-kasa", "kasa_pc", "::1", "fe80::1:7777", "1.2.3.4:7777:1",
			"100.64.0.2/24"]:
		is_false(ConnectInfo.parse_host_port(bad)["ok"], "geçersiz: '%s'" % bad)
	eq(ConnectInfo.parse_port(" 7777 "), 7777)
	eq(ConnectInfo.parse_port("+7777"), -1)
	eq(ConnectInfo.parse_port("077777"), -1)


func test_find_invite_in_clipboard_text() -> void:
	eq(ConnectInfo.find_invite("100.64.0.2:7777"), {"ok": true, "address": "100.64.0.2", "port": 7777})
	eq(ConnectInfo.find_invite("Davet adresi: 100.70.1.2:9000, hadi"), {"ok": true, "address": "100.70.1.2", "port": 9000})
	eq(ConnectInfo.find_invite("adres 10.0.0.9 bekliyorum"), {"ok": true, "address": "10.0.0.9", "port": 7777})
	eq(ConnectInfo.find_invite("999.1.1.1 ve sonra 192.168.1.4:7780")["address"], "192.168.1.4", "ilk geçerli")
	is_false(ConnectInfo.find_invite("sürüm 1.2.3.4.5 yüklendi")["ok"], "beş parçalı sürüm adres değil")
	is_false(ConnectInfo.find_invite("100.64.0.2:80")["ok"], "port aralık dışı")
	is_false(ConnectInfo.find_invite("merhaba dünya")["ok"])
	for word: String in ["merhaba", "kasa-pc", "  tamam\n"]:
		is_false(ConnectInfo.find_invite(word)["ok"], "noktasız, rakamsız tek sözcük adres değil: '%s'" % word)
	is_true(ConnectInfo.find_invite("pc1")["ok"], "rakamlı tek sözcük makine adı olabilir")
	eq(ConnectInfo.find_invite("Adres: 100.64.0.2:7777.")["port"], 7777, "cümle sonu noktası")


func test_find_invite_ranking_and_ts_names() -> void:
	eq(ConnectInfo.find_invite("bağlan: kasa-pc.tail1234.ts.net:7780, olmazsa 100.70.1.2"),
		{"ok": true, "address": "kasa-pc.tail1234.ts.net", "port": 7780}, "metindeki ts.net adı, portlu önce")
	eq(ConnectInfo.find_invite("ad: kasa-pc.tail1234.ts.net."), {"ok": true, "address": "kasa-pc.tail1234.ts.net", "port": 7777})
	eq(ConnectInfo.find_invite("192.168.1.4 ya da 100.70.1.2")["address"], "100.70.1.2", "portsuzlarda Tailscale önce")
	eq(ConnectInfo.find_invite("8.8.8.8 ya da 192.168.1.4")["address"], "192.168.1.4", "sonra özel ağ")
	eq(ConnectInfo.find_invite("100.70.1.2 ama 192.168.1.4:7790")["address"], "192.168.1.4", "portlu aday her şeyden önce")
	eq(ConnectInfo.find_invite("100.70.1.2:7790 ve 100.70.1.3:7791")["address"], "100.70.1.2", "eşitlikte metindeki sıra")
	is_false(ConnectInfo.find_invite("bkz. x.ts.net.ornek.com sayfası")["ok"], "ts.net ile bitmeyen ad")
	is_false(ConnectInfo.find_invite("kasa.ts.net:123456")["ok"], "uzun port")
	is_false(ConnectInfo.find_invite("")["ok"])


# --- ayar dosyası ---

func test_settings_round_trip_and_merge() -> void:
	_remove(TEMP_PATH)
	eq(ConnectInfo.load_settings(TEMP_PATH), ConnectInfo.default_settings(), "dosya yok → varsayılan")
	eq(ConnectInfo.save_settings({ConnectInfo.KEY_NAME: " Ayşe "}, TEMP_PATH), OK)
	eq(ConnectInfo.load_settings(TEMP_PATH), {ConnectInfo.KEY_NAME: "Ayşe", ConnectInfo.KEY_ADDRESS: ""})
	ConnectInfo.save_settings({ConnectInfo.KEY_ADDRESS: "100.64.0.2:7780"}, TEMP_PATH)
	eq(ConnectInfo.load_settings(TEMP_PATH), {ConnectInfo.KEY_NAME: "Ayşe", ConnectInfo.KEY_ADDRESS: "100.64.0.2:7780"},
		"yazılmayan anahtar korunur")
	_remove(TEMP_PATH)


func test_settings_corrupt_or_wrong_types_fall_back() -> void:
	for content: String in ["[connect\nname=\"yarım", "\u0001\u0002ikili çöp", "name = \"bölümsüz\"",
			"[connect]\nname = 42\naddress = [1, 2]\n"]:
		var f: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
		f.store_string(content)
		f.close()
		eq(ConnectInfo.load_settings(TEMP_PATH), ConnectInfo.default_settings(), "bozuk içerik: %s" % content.c_escape())
	var long: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	long.store_string("[connect]\nname = \"%s\"\naddress = \"  10.0.0.9  \"\n" % "W".repeat(40))
	long.close()
	eq(ConnectInfo.load_settings(TEMP_PATH), {ConnectInfo.KEY_NAME: "W".repeat(ConnectInfo.MAX_NAME_LENGTH),
		ConnectInfo.KEY_ADDRESS: "10.0.0.9"}, "ad kesilir, boşluk atılır")
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: "A\ty\u0001ş\u007fe\u0085\n", ConnectInfo.KEY_ADDRESS: "10.0.0.9\r"}, TEMP_PATH)
	eq(ConnectInfo.load_settings(TEMP_PATH), {ConnectInfo.KEY_NAME: "Ayşe", ConnectInfo.KEY_ADDRESS: "10.0.0.9"},
		"addaki ve adresteki kontrol karakterleri temizlenir")
	eq(ConnectInfo.strip_control("Bo\u0007b"), "Bob")
	eq(ConnectInfo.save_settings({ConnectInfo.KEY_NAME: "Bo"}, TEMP_PATH), OK, "bozuk dosyanın üstüne yazılabilir")
	eq(ConnectInfo.load_settings(TEMP_PATH)[ConnectInfo.KEY_NAME], "Bo")
	_remove(TEMP_PATH)


func test_settings_default_path_is_user_connect_cfg() -> void:
	eq(ConnectInfo.SETTINGS_PATH, "user://connect.cfg")
	Fakes.reset_connect_settings()
	eq(ConnectInfo.settings_path, Fakes.TEST_SETTINGS_PATH, "ekran testleri gerçek dosyaya dokunmaz")
	ConnectInfo.save_settings({ConnectInfo.KEY_NAME: "Bo"})
	is_true(FileAccess.file_exists(Fakes.TEST_SETTINGS_PATH))
	Fakes.reset_connect_settings()


# --- davet paneli ---

func _invite(addresses: PackedStringArray, copied: Array[String]) -> InvitePanel:
	var panel: InvitePanel = INVITE_SCENE.instantiate() as InvitePanel
	panel.addresses_provider = func() -> PackedStringArray: return addresses
	panel.clipboard_setter = func(text: String) -> void: copied.append(text)
	_viewport().add_child(panel)
	return panel


func test_invite_panel_single_address_copy() -> void:
	var copied: Array[String] = []
	var panel: InvitePanel = _invite(["fe80::1", "100.64.0.2"], copied)
	panel.port = 7790
	eq((panel.get_node("%AddressLabel") as Label).text, "100.64.0.2:7790")
	is_true(panel.get_node("%AddressLabel").visible)
	is_false(panel.get_node("%AddressButton").visible, "tek adayda liste yok")
	is_false(panel.get_node("%NoteLabel").visible, "Tailscale varken not yok")
	var copy: Button = panel.get_node("%CopyButton") as Button
	copy.pressed.emit()
	eq(copied, ["100.64.0.2:7790"] as Array[String])
	eq(copy.text, "MENU_INVITE_COPIED")
	panel.advance(InvitePanel.COPIED_SEC - 0.1)
	eq(copy.text, "MENU_INVITE_COPIED")
	panel.advance(0.2)
	eq(copy.text, "MENU_INVITE_COPY", "kısa süre sonra eski yazı")
	eq(panel.focus_controls(), [copy] as Array[Control])


func test_invite_panel_lan_only_shows_note() -> void:
	var copied: Array[String] = []
	var panel: InvitePanel = _invite(["127.0.0.1", "192.168.1.20"], copied)
	eq(panel.invite_text(), "192.168.1.20:7777")
	is_true(panel.get_node("%NoteLabel").visible, "Tailscale yok notu")
	panel.addresses_provider = func() -> PackedStringArray: return PackedStringArray()
	panel.refresh()
	eq(panel.invite_text(), "127.0.0.1:7777", "hiç arabirim yoksa loopback")


func test_invite_panel_list_selects_and_copies() -> void:
	var copied: Array[String] = []
	var panel: InvitePanel = _invite(["192.168.56.1", "100.100.1.1", "10.0.0.4"], copied)
	var focus_changes: Array[int] = [0]
	panel.focus_layout_changed.connect(func() -> void: focus_changes[0] += 1)
	var choice: Button = panel.get_node("%AddressButton") as Button
	is_true(choice.visible)
	is_false(panel.get_node("%AddressLabel").visible)
	eq(choice.text, tr("MENU_INVITE_CHOICE") % ["100.100.1.1:7777", 2])
	is_false(panel.is_list_open())
	choice.button_pressed = true
	is_true(panel.is_list_open(), "adres düğmesi listeyi açar")
	eq(focus_changes[0], 1, "odak sırası yenilenir")
	var names: Array[String] = []
	for c: Control in panel.focus_controls():
		names.append(str(c.name))
	eq(names, ["AddressButton", "Address0", "Address1", "Address2", "CopyButton"] as Array[String])
	eq((panel.get_node("%AddressList").get_child(2) as Button).text, "192.168.56.1:7777", "liste hepsini gösterir (VirtualBox en sonda)")
	(panel.get_node("%AddressList").get_child(1) as Button).pressed.emit()
	eq(panel.selected_address(), "10.0.0.4")
	eq(copied, ["10.0.0.4:7777"] as Array[String], "seçilen adres kopyalanır")
	is_false(panel.is_list_open(), "seçince liste kapanır")
	is_true(panel.get_node("%NoteLabel").visible, "seçilen Tailscale değil → not")
	panel.refresh()
	eq(panel.selected_address(), "100.100.1.1", "yenileyince ilk aday")


func test_invite_panel_list_is_capped_and_can_be_disabled() -> void:
	var copied: Array[String] = []
	var many: PackedStringArray = []
	for i: int in 9:
		many.append("10.0.0.%d" % (i + 1))
	var panel: InvitePanel = _invite(many, copied)
	eq(panel.candidates().size(), InvitePanel.MAX_LISTED)
	eq(panel.get_node("%AddressList").get_child_count(), InvitePanel.MAX_LISTED)
	panel.allow_list = false
	panel.refresh()
	is_false(panel.get_node("%AddressButton").visible, "liste kapalı: yalnız ilk aday")
	eq((panel.get_node("%AddressLabel") as Label).text, "10.0.0.1:7777")


# --- duraklat menüsü ---

func _pause(hosting: bool, addresses: PackedStringArray) -> PauseMenu:
	var pair: Array = Fakes.make_pair(self)
	var net: Fakes.FakeNet = pair[0]
	net.hosting = hosting
	var menu: PauseMenu = PAUSE_SCENE.instantiate() as PauseMenu
	menu.net = net
	var invite: InvitePanel = menu.get_node("%Invite") as InvitePanel
	invite.addresses_provider = func() -> PackedStringArray: return addresses
	_viewport().add_child(menu)
	return menu


func test_pause_menu_shows_invite_only_to_host() -> void:
	var client: PauseMenu = _pause(false, ["100.64.0.2"])
	client.open()
	is_false(client.get_node("%Invite").visible, "istemcide davet yok")
	eq(str(client.get_viewport().gui_get_focus_owner().name), "ResumeButton")
	var host: PauseMenu = _pause(true, ["192.168.1.2", "100.64.0.2"])
	ConnectInfo.hosted_port = 7790
	host.open()
	var invite: InvitePanel = host.get_node("%Invite") as InvitePanel
	is_true(invite.visible, "host'ta davet görünür")
	eq(invite.invite_text(), "100.64.0.2:7790", "menüden host olunan port")
	eq(str(host.get_viewport().gui_get_focus_owner().name), "ResumeButton", "odak yine Devam'da")
	ConnectInfo.hosted_port = 0
	host.close()
	host.open()
	eq(invite.invite_text(), "100.64.0.2:%d" % Args.port, "komut satırıyla (--host) açılışta Args.port")


func test_pause_menu_invite_gamepad_focus() -> void:
	var host: PauseMenu = _pause(true, ["192.168.1.2", "100.64.0.2"])
	host.open()
	var vp: Viewport = host.get_viewport()
	var order: Array[String] = []
	for i: int in 4:
		var down := InputEventJoypadButton.new()
		down.button_index = JOY_BUTTON_DPAD_DOWN
		down.pressed = true
		vp.push_input(down)
		order.append(str(vp.gui_get_focus_owner().name))
	eq(order, ["LeaveButton", "AddressButton", "CopyButton", "ResumeButton"] as Array[String], "Devam → Ayrıl → davet → Devam")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	(host.get_node("%Invite").get_node("%AddressButton") as Control).grab_focus()
	vp.push_input(accept)
	accept = accept.duplicate() as InputEventJoypadButton
	accept.pressed = false
	vp.push_input(accept)
	is_true((host.get_node("%Invite") as InvitePanel).is_list_open(), "A listeyi açar")
	eq(str(vp.gui_get_focus_owner().name), "Address0", "odak listedeki seçili adreste")
