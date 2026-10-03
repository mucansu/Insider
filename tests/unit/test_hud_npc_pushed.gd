extends TestCase
## IS-096 AC3 (US-037 decision): the `npc_pushed` session event toasts only for a calm shove; heated shoves stay silent.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")

var hud: Hud
var game: Fakes.FakeGame


func _open() -> void:
	var pair: Array = Fakes.make_pair(self)
	game = pair[1]
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = pair[0]
	hud.game = game
	hud.menu_override = func(_error_key: StringName) -> void: pass
	hud.warning_override = func(_missing_key: String) -> void: pass
	viewport.add_child(hud)
	await tree().process_frame


func _toast_count() -> int:
	return hud.get_node("%Toasts").get_child_count()


func test_wants_toast_filter() -> void:
	is_true(Hud.wants_toast(&"npc_pushed", {"peer": 1, "npc": "Owner", "calm": true}), "sakin itme: bildirim")
	is_false(Hud.wants_toast(&"npc_pushed", {"peer": 1, "npc": "Owner", "calm": false}), "kızışmış itme: sessiz")
	is_false(Hud.wants_toast(&"npc_pushed", {"peer": 1}), "calm alanı yoksa sessiz")
	is_false(Hud.wants_toast(&"alert_level", {"level": 2}), "sessiz olay sessiz kalır")
	is_true(Hud.wants_toast(&"police_called", {}), "diğer olaylar değişmedi")


func test_calm_push_toasts_heated_does_not() -> void:
	await _open()
	for i: int in 3:
		game.session_event.emit(&"npc_pushed", {"peer": 1, "npc": "Owner", "calm": false})
	eq(_toast_count(), 0, "kovalamacada itme spam yapmaz")
	game.session_event.emit(&"npc_pushed", {"peer": 1, "npc": "Owner", "calm": true})
	eq(_toast_count(), 1, "sakin itme bir kez bildirilir")
	var label: Label = hud.get_node("%Toasts").get_child(0).get_child(0) as Label
	eq(label.text, hud.event_text(&"npc_pushed", {"peer": 1, "npc": "Owner", "calm": true}), "EVENT_NPC_PUSHED metni")
