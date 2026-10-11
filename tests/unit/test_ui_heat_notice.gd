extends TestCase
## US-052 AC4: in-session heat notice (ui/heat_notice.gd) — "neighbourhood on edge (heat n)" only when later jobs are hot, "the
## shopkeeper knows you: <name>" per recognised player in the roster; the HUD shows them as toasts when it opens (job prep); a cool
## session or a game without the API shows nothing.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")


func _game() -> Fakes.FakeGame:
	return Fakes.make_pair(self)[1] as Fakes.FakeGame


func test_lines_follow_state() -> void:
	var game: Fakes.FakeGame = _game()
	var me: Node = autofree(Node.new()) as Node
	eq(HeatNotice.lines(game, me), PackedStringArray(), "sakin oturum: satır yok")
	game.roster = {1: {"name": "Mustafa", "slot": 0}, 2: {"name": "Ayla", "slot": 1}}
	game.heat_state = {"heat": 19, "active": true, "recognized": {2: 1, 7: 1}, "known": [2, 7]}
	eq(HeatNotice.lines(game, me), PackedStringArray([tr(&"HUD_HEAT_HOT") % 19, tr(&"HUD_HEAT_KNOWN") % "Ayla"]),
		"sıcak + tanınan (oturumdan çıkan 7 yazılmaz)")
	game.heat_state = {"heat": 5, "active": false, "recognized": {1: 1}, "known": [1]}
	eq(HeatNotice.lines(game, me), PackedStringArray([tr(&"HUD_HEAT_KNOWN") % "Mustafa"]), "ısı eşik altı: yalnız tanınma")
	eq(HeatNotice.lines(autofree(Node.new()) as Node, me), PackedStringArray(), "API yok: satır yok")
	is_true((tr(&"HUD_HEAT_HOT") % 19).contains("19"))


func test_hud_shows_notice_on_open() -> void:
	var pair: Array = Fakes.make_pair(self)
	var net: Fakes.FakeNet = pair[0]
	var game: Fakes.FakeGame = pair[1]
	game.roster = {1: {"name": "Mustafa", "slot": 0}}
	game.heat_state = {"heat": 15, "active": true, "recognized": {1: 1}, "known": [1]}
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	viewport.add_child(hud)
	await tree().process_frame
	var texts: Array[String] = []
	for panel: Node in hud.get_node("%Toasts").get_children():
		texts.append((panel.get_child(0) as Label).text)
	eq(texts, [tr(&"HUD_HEAT_HOT") % 15, tr(&"HUD_HEAT_KNOWN") % "Mustafa"] as Array[String], "iki bildirim")
