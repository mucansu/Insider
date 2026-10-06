extends TestCase
## IS-110 (GB-12): held vs caught readability. TeamStatus model (window counted locally from the status change, no network field),
## crew list badges ("Tutuldu 6..1" alert colour, "Yakalandı" muted, "Kaçtı"), held/caught event texts (own-screen variants,
## PULL key) and the local player's big countdown "TUTULDUN — n".

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const HELD := PlayerStatus.State.HELD
const CAUGHT := PlayerStatus.State.CAUGHT
const FREE := PlayerStatus.State.FREE
const NEW_KEYS: Array[String] = ["EVENT_PLAYER_HELD", "EVENT_PLAYER_HELD_SELF", "EVENT_PLAYER_CAUGHT", "EVENT_PLAYER_CAUGHT_SELF",
	"HUD_STATUS_HELD", "HUD_STATUS_HELD_NO_TIME", "HUD_STATUS_CAUGHT", "HUD_STATUS_ESCAPED", "HUD_HELD_COUNTDOWN",
	"HUD_HELD_COUNTDOWN_NO_TIME"]

var net: Fakes.FakeNet
var game: Fakes.FakeGame
var hud: Hud
var player: Fakes.FakePlayer


func _open() -> void:
	var pair: Array = Fakes.make_pair(self)
	net = pair[0]
	game = pair[1]
	game.roster = {1: {"name": "Ben", "slot": 0}, 2: {"name": "Ayla", "slot": 1}, 3: {"name": "Can", "slot": 2}}
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_k: StringName) -> void: pass
	hud.warning_override = func(_k: String) -> void: pass
	viewport.add_child(hud)
	player = autofree(Fakes.FakePlayer.new()) as Fakes.FakePlayer
	game.local_player_changed.emit(player)
	await tree().process_frame


func _row(peer: int) -> HBoxContainer:
	var ids: Array = game.roster.keys()
	ids.sort()
	return hud.get_node("%PlayerList").get_child(ids.find(peer)) as HBoxContainer


func _badge(peer: int) -> Label:
	return _row(peer).get_child(2) as Label


func _countdown() -> Control:
	return hud.get_node("%HeldCountdown") as Control


func _countdown_text() -> String:
	return (hud.get_node("%HeldCountdownLabel") as Label).text


func _toasts() -> Array[String]:
	var out: Array[String] = []
	for panel: Node in hud.get_node("%Toasts").get_children():
		out.append((panel.get_child(0) as Label).text)
	return out


# --- model ---

func test_status_values_mirror_player_status() -> void:
	eq(TeamStatus.STATUS_FREE, PlayerStatus.State.FREE)
	eq(TeamStatus.STATUS_HELD, PlayerStatus.State.HELD)
	eq(TeamStatus.STATUS_CAUGHT, PlayerStatus.State.CAUGHT)


func test_model_held_counts_down_then_caught() -> void:
	var s := TeamStatus.new()
	is_true(s.apply_event(&"player_held", {"peer": 2, "window": 6.0}))
	eq(s.badge(2), TeamStatus.Badge.HELD)
	eq(s.seconds_left(2), 6)
	is_false(s.advance(0.5), "6 -> 5.5 still shows 6")
	eq(s.seconds_left(2), 6)
	is_true(s.advance(0.6), "a whole second ticked")
	eq(s.seconds_left(2), 5)
	s.advance(4.5)
	eq(s.seconds_left(2), 1, "last second")
	is_true(s.apply_event(&"player_caught", {"peer": 2, "by": &"owner"}))
	eq(s.badge(2), TeamStatus.Badge.CAUGHT)
	eq(s.seconds_left(2), -1)
	is_false(s.apply_event(&"player_held", {"peer": 2, "window": 3.0}), "caught is permanent")
	eq(s.badge(2), TeamStatus.Badge.CAUGHT)


func test_model_rescue_and_repeat_hold_window() -> void:
	var s := TeamStatus.new()
	s.apply_event(&"player_held", {"peer": 3, "window": 6.0})
	s.advance(2.0)
	is_true(s.apply_event(&"player_rescued", {"peer": 3, "by": 2}))
	eq(s.badge(3), TeamStatus.Badge.NONE, "rescued -> free, no badge")
	s.apply_event(&"player_held", {"peer": 3, "window": 3.0})
	eq(s.seconds_left(3), 3, "second hold uses the event's (shorter) window")
	is_false(s.apply_event(&"other", {"peer": 3}))
	is_false(s.apply_event(&"player_held", {}), "no peer -> ignored")


func test_model_local_status_before_and_after_event() -> void:
	var s := TeamStatus.new()
	is_true(s.apply_status(1, HELD, -1.0), "status seen before the event")
	eq(s.seconds_left(1), -1, "window not known yet")
	is_true(s.apply_event(&"player_held", {"peer": 1, "window": 6.0}), "event fills the window")
	eq(s.seconds_left(1), 6)
	s.advance(2.0)
	is_false(s.apply_event(&"player_held", {"peer": 1, "window": 6.0}), "repeat notice does not restart the window")
	eq(s.seconds_left(1), 4)
	is_true(s.apply_status(1, FREE, 0.0))
	eq(s.badge(1), TeamStatus.Badge.NONE)
	s.apply_status(1, HELD, 2.5)
	eq(s.seconds_left(1), 3, "hold_left from the local player")
	s.apply_status(1, CAUGHT, 0.0)
	eq(s.badge(1), TeamStatus.Badge.CAUGHT)
	is_false(s.apply_status(1, FREE, 0.0), "FREE does not clear caught")


func test_model_result() -> void:
	var s := TeamStatus.new()
	s.apply_event(&"player_held", {"peer": 3, "window": 6.0})
	is_true(s.apply_result({"players": {"1": {"escaped": true, "caught": false}, "2": {"escaped": false, "caught": true},
		"3": {"escaped": false, "caught": false}}}))
	eq(s.badge(1), TeamStatus.Badge.ESCAPED)
	eq(s.badge(2), TeamStatus.Badge.CAUGHT)
	eq(s.badge(3), TeamStatus.Badge.NONE, "open window ends with the result")
	is_false(s.apply_result({}), "empty result -> nothing")


# --- HUD ---

func test_teammate_badge_counts_down_then_caught() -> void:
	await _open()
	is_false(_badge(2).visible, "no badge while free")
	game.session_event.emit(&"player_held", {"peer": 2, "window": 6.0})
	is_true(_badge(2).visible)
	eq(_badge(2).text, tr("HUD_STATUS_HELD") % 6)
	eq(_badge(2).theme_type_variation, &"AlertLabel", "warning colour")
	is_false(_countdown().visible, "big countdown only on the held player's own screen")
	hud.advance(1.2)
	eq(_badge(2).text, tr("HUD_STATUS_HELD") % 5)
	hud.advance(4.0)
	eq(_badge(2).text, tr("HUD_STATUS_HELD") % 1)
	game.session_event.emit(&"player_caught", {"peer": 2, "by": &"owner"})
	eq(_badge(2).text, tr("HUD_STATUS_CAUGHT"))
	eq(_badge(2).theme_type_variation, &"MutedLabel")
	eq((_row(2).get_child(1) as Label).theme_type_variation, &"MutedLabel", "caught row is muted")
	is_false(_badge(3).visible)
	game.players_changed.emit()
	eq(_badge(2).text, tr("HUD_STATUS_CAUGHT"), "badge survives a roster rebuild")


func test_teammate_rescued_clears_badge() -> void:
	await _open()
	game.session_event.emit(&"player_held", {"peer": 3, "window": 6.0})
	hud.advance(3.0)
	game.session_event.emit(&"player_rescued", {"peer": 3, "by": 2})
	is_false(_badge(3).visible, "rescued -> free")
	eq((_row(3).get_child(1) as Label).theme_type_variation, &"")


func test_event_texts() -> void:
	await _open()
	var key: String = UiInput.action_hint(&"interact")
	is_false(key.is_empty(), "interact has a key hint")
	game.session_event.emit(&"player_held", {"peer": 2, "window": 6.0})
	game.session_event.emit(&"player_caught", {"peer": 3, "by": &"owner"})
	eq(_toasts(), [tr("EVENT_PLAYER_HELD").format({"name": "Ayla", "seconds": 6, "key": key}),
		tr("EVENT_PLAYER_CAUGHT").format({"name": "Can"})] as Array[String])
	has(_toasts()[0], "6")
	has(_toasts()[0], "(" + key + ")")
	for t: String in _toasts():
		is_false(t.contains("{"), "no open placeholder: " + t)


func test_own_screen_countdown_and_texts() -> void:
	await _open()
	player.hold = 6.0
	player.status_changed.emit(HELD)
	is_true(_countdown().visible, "TUTULDUN countdown on own screen")
	eq(_countdown_text(), tr("HUD_HELD_COUNTDOWN") % 6)
	eq(_badge(1).text, tr("HUD_STATUS_HELD") % 6, "own row badge too")
	game.session_event.emit(&"player_held", {"peer": 1, "window": 6.0})
	eq(_toasts(), [tr("EVENT_PLAYER_HELD_SELF")] as Array[String], "own screen: you, not your name")
	hud.advance(2.0)
	eq(_countdown_text(), tr("HUD_HELD_COUNTDOWN") % 4)
	hud.advance(4.0)
	is_true(_countdown().visible, "waits for the host's decision")
	game.session_event.emit(&"player_caught", {"peer": 1, "by": &"owner"})
	is_false(_countdown().visible, "caught -> countdown gone")
	eq(_badge(1).text, tr("HUD_STATUS_CAUGHT"))
	eq(_toasts().back(), tr("EVENT_PLAYER_CAUGHT_SELF"))


func test_own_screen_rescued() -> void:
	await _open()
	game.session_event.emit(&"player_held", {"peer": 1, "window": 6.0})
	is_true(_countdown().visible, "event alone starts the countdown")
	eq(_countdown_text(), tr("HUD_HELD_COUNTDOWN") % 6)
	hud.advance(3.0)
	player.status_changed.emit(FREE)
	is_false(_countdown().visible, "pulled free -> countdown gone")
	is_false(_badge(1).visible)


func test_status_before_event_without_window() -> void:
	await _open()
	player.hold = 0.0
	player.status_changed.emit(HELD)
	eq(_countdown_text(), tr("HUD_HELD_COUNTDOWN_NO_TIME"), "window unknown -> no number")
	eq(_badge(1).text, tr("HUD_STATUS_HELD_NO_TIME"))
	game.session_event.emit(&"player_held", {"peer": 1, "window": 6.0})
	eq(_countdown_text(), tr("HUD_HELD_COUNTDOWN") % 6)


func test_result_marks_escaped() -> void:
	await _open()
	game.session_event.emit(&"player_held", {"peer": 3, "window": 6.0})
	game.heist_finished.emit({"players": {"1": {"escaped": true, "caught": false}, "2": {"escaped": true, "caught": false},
		"3": {"escaped": false, "caught": true}}})
	eq(_badge(1).text, tr("HUD_STATUS_ESCAPED"))
	eq(_badge(1).theme_type_variation, &"EscapeBadgeLabel")
	eq(_badge(3).text, tr("HUD_STATUS_CAUGHT"))


func test_texts_exist_in_both_languages() -> void:
	var before: String = TranslationServer.get_locale()
	for locale: String in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in NEW_KEYS:
			var text: String = tr(key)
			is_true(text != key and not text.is_empty(), "%s %s metni yok" % [locale, key])
		has(tr("EVENT_PLAYER_HELD"), "{seconds}")
		has(tr("EVENT_PLAYER_HELD"), "{key}")
		has(tr("HUD_HELD_COUNTDOWN"), "%d")
		has(tr("HUD_STATUS_HELD"), "%d")
	TranslationServer.set_locale(before)
