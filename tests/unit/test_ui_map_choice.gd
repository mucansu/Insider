extends TestCase
## US-050 AC2/AC3/AC4 (UI side): the main menu host card map picker and the heist end "Another shop" with the fake Game's map
## addition (S3 addendum map_list / request_map_switch). Picker: registry maps, the pick decides the host's first level, `--level`
## wins (picker disabled), the last pick is remembered for the process. End screen: host-only drop-down of the other maps (next one
## first), the pick calls Game.request_map_switch; the session score table survives the level change and names each run's map.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const MENU_SCENE := preload("res://ui/main_menu.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")
const STORE_A := "res://levels/store_a.tscn"
const RUSH := "res://levels/store_a_rush.tscn"
const STORE_B := "res://levels/store_b.tscn"

var net: Fakes.FakeNet
var game: Fakes.FakeMapGame
var journal: Fakes.CallLog
var viewport: SubViewport
var menu: MainMenu
var hud: Hud
var screen: HeistEnd


func _pair(fresh_settings: bool = true) -> void:
	var pair: Array = Fakes.make_pair(self, false, fresh_settings, true)
	net = pair[0]
	game = pair[1] as Fakes.FakeMapGame
	journal = pair[2]
	if viewport == null:
		viewport = autofree(SubViewport.new()) as SubViewport
		viewport.size = Vector2i(1280, 720)
		tree().root.add_child(viewport)


func _open_menu(level_arg: String = "", remembered: String = "") -> void:
	MainMenu.remembered_map = remembered
	_pair()
	menu = MENU_SCENE.instantiate() as MainMenu
	menu.net = net
	menu.game = game
	menu.level_arg = level_arg
	viewport.add_child(menu)
	await _settle()


func _open_hud(level_path: String, hosting: bool = true) -> void:
	MainMenu.remembered_map = ""
	_pair()
	net.hosting = hosting
	_set_level(level_path)
	await _add_hud()


func _add_hud() -> void:
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_key: StringName) -> void: pass
	hud.warning_override = func(_missing_key: String) -> void: pass
	viewport.add_child(hud)
	screen = hud.get_node("%HeistEnd") as HeistEnd
	await _settle()


func _set_level(level_path: String) -> void:
	var level: Node = autofree(Node.new()) as Node
	level.scene_file_path = level_path
	game.level = level


func _settle() -> void:
	for i: int in 3:
		await tree().process_frame


func _focused() -> String:
	var owner: Control = viewport.gui_get_focus_owner()
	return "" if owner == null else str(owner.name)


func _push_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		viewport.push_input(e)


func _popup_texts() -> Array[String]:
	var popup: PopupMenu = (screen.get_node("%MapButton") as MenuButton).get_popup()
	var out: Array[String] = []
	for i: int in popup.item_count:
		out.append(popup.get_item_text(i))
	return out


static func _result() -> Dictionary:
	return {"outcome": &"clean", "loot_total": 200, "payout_ratio": 0.9, "payout": 180, "duration_s": 40.0,
		"players": {"1": {"name": "Ayşe", "slot": 0, "escaped": true, "caught": false, "loot": 200}}, "notes": []}


# --- AC2: main menu picker ---

func test_menu_picker_lists_registry_and_hosts_pick() -> void:
	await _open_menu()
	var option: OptionButton = menu.get_node("%MapOption") as OptionButton
	is_true(option.is_visible_in_tree(), "host kartında harita seçimi")
	is_false(option.disabled)
	eq(option.item_count, 3)
	eq(option.selected, 0, "varsayılan ilk harita")
	eq(menu.selected_map(), STORE_A)
	option.select(1)
	option.item_selected.emit(1)
	eq(MainMenu.remembered_map, RUSH, "seçim oturum boyunca hatırlanır")
	(menu.get_node("%NameEdit") as LineEdit).text = "Ayşe"
	(menu.get_node("%HostButton") as Button).pressed.emit()
	eq(journal.entries.back(), ["start_level", RUSH], "host olunca seçilen harita yüklenir")
	MainMenu.remembered_map = ""


func test_menu_remembers_last_pick_on_reopen() -> void:
	await _open_menu("", STORE_B)
	eq(menu.selected_map(), STORE_B, "son seçim yeniden açılışta seçili")
	eq(menu.host_level(), STORE_B)
	MainMenu.remembered_map = ""


func test_menu_level_arg_wins() -> void:
	await _open_menu(STORE_B, RUSH)
	var option: OptionButton = menu.get_node("%MapOption") as OptionButton
	is_true(option.disabled, "--level verilince seçim kilitli")
	eq(menu.selected_map(), STORE_B, "arg'ın haritası gösterilir")
	(menu.get_node("%NameEdit") as LineEdit).text = "Ayşe"
	(menu.get_node("%HostButton") as Button).pressed.emit()
	eq(journal.entries.back(), ["start_level", STORE_B], "--level önceliklidir")
	eq(MainMenu.remembered_map, RUSH, "arg hatırlanan seçimi ezmez")
	MainMenu.remembered_map = ""


func test_menu_unlisted_level_arg_shown_by_file_name() -> void:
	var fixture := "res://tests/fixtures/empty_level.tscn"
	await _open_menu(fixture)
	var option: OptionButton = menu.get_node("%MapOption") as OptionButton
	eq(option.item_count, 4, "kayıt dışı arg ayrı satır")
	eq(option.get_item_text(option.selected), "empty_level")
	eq(menu.host_level(), fixture, "otomasyon/test yolu arg ile serbest")


func test_menu_focus_passes_map_row() -> void:
	await _open_menu()
	(menu.get_node("%HostPortEdit") as Control).grab_focus()
	_push_key(KEY_DOWN)
	eq(_focused(), "HostButton", "dikey zincir değişmez: port → Host ol")
	_push_key(KEY_LEFT)
	eq(_focused(), "MapOption", "harita Host satırında, solda")
	_push_key(KEY_LEFT)
	eq(_focused(), "MapOption", "sol kenar")
	_push_key(KEY_UP)
	eq(_focused(), "HostPortEdit", "harita → port")
	(menu.get_node("%MapOption") as Control).grab_focus()
	_push_key(KEY_RIGHT)
	eq(_focused(), "HostButton")
	_push_key(KEY_RIGHT)
	eq(_focused(), "JoinButton")
	(menu.get_node("%MapOption") as Control).grab_focus()
	_push_key(KEY_DOWN)
	eq(_focused(), "QuitButton")
	(menu.get_node("%HostPortEdit") as Control).grab_focus()
	var tabs: Array[String] = []
	for i: int in 3:
		_push_key(KEY_TAB)
		tabs.append(_focused())
	eq(tabs, ["VisionOption", "MapOption", "HostButton"] as Array[String], "Tab halkası")


# --- AC3/AC4: heist end "Another shop" ---

func test_host_sees_other_maps_next_first() -> void:
	await _open_hud(STORE_A)
	_finish_now()
	await _settle()
	var button: MenuButton = screen.get_node("%MapButton") as MenuButton
	is_true(button.visible, "host 'Başka bakkal' görür")
	eq(_popup_texts(), [tr("MAP_STORE_A_RUSH"), tr("MAP_STORE_B")] as Array[String], "mevcut hariç, sıradaki önce")
	eq(_focused(), "RetryButton")
	_push_key(KEY_RIGHT)
	eq(_focused(), "MapButton", "Bir daha → Başka bakkal")
	_push_key(KEY_RIGHT)
	eq(_focused(), "ScoresButton")
	var picked: Array[String] = []
	screen.map_switch_requested.connect(func(p: String) -> void: picked.append(p))
	button.get_popup().id_pressed.emit(0)
	eq(journal.entries.back(), ["request_map_switch", RUSH], "seçim Game.request_map_switch'e gider")
	eq(picked, [RUSH] as Array[String])
	eq(MainMenu.remembered_map, RUSH, "menü de son haritayı hatırlar")
	MainMenu.remembered_map = ""


func test_choices_wrap_from_last_map() -> void:
	await _open_hud(STORE_B)
	_finish_now()
	await _settle()
	eq(_popup_texts(), [tr("MAP_STORE_A"), tr("MAP_STORE_A_RUSH")] as Array[String], "listenin sonundan başa sarar")
	_set_level("res://tests/fixtures/empty_level.tscn")
	eq(screen.map_choices().size(), 3, "kayıt dışı seviyede tüm haritalar")


func test_client_has_no_map_switch() -> void:
	await _open_hud(STORE_A, false)
	_finish_now()
	await _settle()
	is_false((screen.get_node("%MapButton") as Control).visible, "istemcide Başka bakkal yok")
	(screen.get_node("%MapButton") as MenuButton).get_popup().id_pressed.emit(0)
	eq(journal.names(), PackedStringArray(), "istemci harita değiştirme isteyemez")


func test_refused_switch_emits_nothing() -> void:
	await _open_hud(STORE_A)
	game.switch_ok = false
	_finish_now()
	await _settle()
	var picked: Array[String] = []
	screen.map_switch_requested.connect(func(p: String) -> void: picked.append(p))
	(screen.get_node("%MapButton") as MenuButton).get_popup().id_pressed.emit(1)
	eq(journal.entries.back(), ["request_map_switch", STORE_B])
	eq(picked, [] as Array[String], "Game reddederse sinyal yok")
	eq(MainMenu.remembered_map, "")
	(screen.get_node("%MapButton") as MenuButton).get_popup().id_pressed.emit(7)
	eq(journal.entries.size(), 1, "geçersiz kimlik yok sayılır")


func test_without_map_api_no_button() -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	net.hosting = true
	viewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = pair[1]
	hud.menu_override = func(_key: StringName) -> void: pass
	viewport.add_child(hud)
	screen = hud.get_node("%HeistEnd") as HeistEnd
	await _settle()
	screen.show_result(_result())
	await _settle()
	is_false(screen.can_switch_map())
	is_false((screen.get_node("%MapButton") as Control).visible, "Game harita eki taşımıyorsa düğme yok")


func test_scores_survive_switch_and_name_maps() -> void:
	await _open_hud(STORE_A)
	_finish_now()
	await _settle()
	(screen.get_node("%MapButton") as MenuButton).get_popup().id_pressed.emit(0)
	# The level change re-creates the HUD while the session stays online (Net online): the table survives.
	viewport.remove_child(hud)
	hud.free()
	_set_level(RUSH)
	await _add_hud()
	var second: Dictionary = _result()
	second["duration_s"] = 52.0  # a different job (the store drops a repeated identical result as a re-show)
	game.heist_finished.emit(second)
	await _settle()
	eq(screen.scores.size(), 2, "skor tablosu harita değişiminde korunur")
	var runs: Array[Dictionary] = screen.scores.runs()
	eq(screen.map_name(str(runs[0]["level"])), tr("MAP_STORE_A"))
	eq(screen.map_name(str(runs[1]["level"])), tr("MAP_STORE_A_RUSH"), "yeni haritanın adı (Kalabalık saat)")
	MainMenu.remembered_map = ""


func _finish_now() -> void:
	game.heist_finished.emit(_result())
