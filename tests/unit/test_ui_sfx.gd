extends TestCase
## Arayüz sesleri (IS-024): düğme odak/basma sesi, uyarı kademesi değişim sesi (bağlanınca değil, değişince;
## hareket azaltmadan bağımsız), iş sonu stinger'ı (kayıp/kaçış). Sahte Game (S3 eki) ile, yalnız genel API.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const PAUSE_SCENE := preload("res://ui/pause_menu.tscn")


class FakeClock extends RefCounted:
	var t: float = 100.0

	func now() -> float:
		return t


var game: Fakes.FakeGame
var hud: Hud
var clock := FakeClock.new()


func _open_hud() -> void:
	var pair: Array = Fakes.make_pair(self)
	game = pair[1]
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = pair[0]
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(_missing: String) -> void: pass
	viewport.add_child(hud)
	await tree().process_frame


func _listen(sfx: UiSfx) -> Array[StringName]:
	var heard: Array[StringName] = []
	sfx.clock = clock.now
	sfx.played.connect(func(ev: StringName) -> void: heard.append(ev))
	return heard


func test_alert_change_plays_step_then_high() -> void:
	await _open_hud()
	var ladder: AlertLadder = hud.get_node("%AlertLadder") as AlertLadder
	var heard: Array[StringName] = _listen(UiSfx.of(ladder))
	eq(heard.size(), 0, "bağlanınca ses yok")
	game.alert_level_changed.emit(1)
	clock.t += 1.0
	game.alert_level_changed.emit(1)
	clock.t += 1.0
	game.alert_level_changed.emit(3)
	eq(heard, [&"alert_step", &"alert_high"] as Array[StringName], "1: yumuşak tık, aynı kademe sessiz, 3: gerilim vuruşu")
	eq(AlertLadder.step_event(2), &"alert_step")
	eq(AlertLadder.step_event(5), &"alert_high")


func test_alert_sound_ignores_reduce_motion() -> void:
	await _open_hud()
	var ladder: AlertLadder = hud.get_node("%AlertLadder") as AlertLadder
	ladder.reduce_motion = true
	var heard: Array[StringName] = _listen(UiSfx.of(ladder))
	game.alert_level_changed.emit(2)
	eq(heard, [&"alert_step"] as Array[StringName], "hareket azaltma sesi kısmaz")
	is_false(ladder.is_popping())


func test_heist_end_stinger_by_outcome() -> void:
	await _open_hud()
	var end: HeistEnd = hud.get_node("%HeistEnd") as HeistEnd
	var heard: Array[StringName] = _listen(UiSfx.of(end))
	game.heist_finished.emit({"outcome": &"caught_all", "players": {}})
	eq(end.stinger_event(), &"stinger_caught")
	clock.t += 5.0
	game.heist_finished.emit({"outcome": &"clean", "players": {}})
	eq(end.stinger_event(), &"stinger_success")
	var stingers: Array[StringName] = heard.filter(func(ev: StringName) -> bool: return String(ev).begins_with("stinger"))
	eq(stingers, [&"stinger_caught", &"stinger_success"] as Array[StringName])
	eq(heard.back(), &"stinger_success", "stinger açılıştaki odak tikinden sonra çalar (kesilmez)")


func test_buttons_play_focus_and_click() -> void:
	var menu: PauseMenu = PAUSE_SCENE.instantiate() as PauseMenu
	tree().root.add_child(menu)
	autofree(menu)
	var heard: Array[StringName] = _listen(UiSfx.of(menu))
	menu.open()  # Devam düğmesi odak alır
	clock.t += 1.0
	(menu.get_node("%LeaveButton") as Button).pressed.emit()
	eq(heard, [UiSfx.FOCUS, UiSfx.CLICK] as Array[StringName], "odak tik, basma tık")
	_check_all_wired(menu)


## IS-078: davet listesi (host'ta) duraklat menüsü her açılışta yeniden kurulur; yeni düğmeler de ses alır.
func test_pause_invite_list_buttons_are_wired() -> void:
	var menu: PauseMenu = PAUSE_SCENE.instantiate() as PauseMenu
	var pair: Array = Fakes.make_pair(self)
	var net: Fakes.FakeNet = pair[0]
	net.hosting = true
	menu.net = net
	tree().root.add_child(menu)
	autofree(menu)
	var invite: InvitePanel = menu.get_node("%Invite") as InvitePanel
	invite.addresses_provider = func() -> PackedStringArray:
		return PackedStringArray(["192.168.1.5", "10.0.0.7", "100.101.2.3"])
	menu.open()
	is_true(invite.candidates().size() > 1, "birden çok aday: liste düğmeleri var")
	_check_all_wired(menu)
	var heard: Array[StringName] = _listen(UiSfx.of(menu))
	clock.t += 1.0
	(invite.get_node("%AddressList").get_child(0) as Button).pressed.emit()
	eq(heard.count(UiSfx.CLICK), 1, "liste düğmesi tek tık (çift bağ yok)")


## Her düğmenin basma sinyali ekranın arayüz çalarına (tam bir kez) bağlı.
func _check_all_wired(screen: Node) -> void:
	var player: UiSfx = UiSfx.of(screen)
	for node: Node in screen.find_children("*", "BaseButton", true, false):
		var count: int = 0
		for c: Dictionary in (node as BaseButton).pressed.get_connections():
			if (c["callable"] as Callable).get_object() == player:
				count += 1
		eq(count, 1, "%s basma sesine bağlı" % node.name)


func test_main_menu_buttons_are_wired() -> void:
	var menu: MainMenu = (load("res://ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	var pair: Array = Fakes.make_pair(self)
	menu.net = pair[0]
	menu.game = pair[1]
	menu.quit_override = func() -> void: pass
	tree().root.add_child(menu)
	autofree(menu)
	var sfx: UiSfx = menu.get_node_or_null(NodePath(UiSfx.NODE_NAME)) as UiSfx
	if not is_true(sfx != null, "ana menü arayüz çaları kurar"):
		return
	var heard: Array[StringName] = _listen(sfx)
	(menu.get_node("%QuitButton") as Button).pressed.emit()
	has(heard, UiSfx.CLICK, "Çıkış basma sesi")
