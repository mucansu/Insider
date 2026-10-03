extends TestCase
## US-010 izi (Game soygun bölümü, host oturumu + store_a + gerçek oyuncu): SATIN AL sahibin `social_action`
## kancasıyla US-042 strateji etiketine "sosyal" sayılır; bedel iş sonu kasasından düşer (cash_after = iş öncesi +
## ödeme − kefalet − alışveriş; `cash_before` gerçek iş öncesi kasa).

const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
const COUNTER_FRONT := Vector2(528, 336)
const IN_ZONE := Vector2(860, 576)
const DT := 1.0 / 60.0

var _results: Array[Dictionary] = []
var _previous_scene: PackedScene = null


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _on_finished(result: Dictionary) -> void:
	_results.append(result)


func _start() -> Player:
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	Game.heist_finished.connect(_on_finished)
	if not eq(Net.host(free_udp_port()), OK):
		return null
	Game.start_level(STORE)
	return Game.local_player() as Player


func _stop() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.heist_finished.disconnect(_on_finished)
	Game.player_scene = _previous_scene


func _frames(n: int) -> void:
	for i: int in n:
		await tree().physics_frame


func test_purchase_is_social_strategy_and_cost_leaves_heist_cash() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.add_team_cash(100 - Game.team_cash())  # iş öncesi kasa 100
	me.position = COUNTER_FRONT
	await _frames(30)
	var buy: Interactable = (Game.current_level() as Level).props_root().get_node(^"Counter/Buy") as Interactable
	buy.host_start(1, 1)
	for i: int in roundi(2.1 / DT):
		buy.step(DT)
	eq(Game.team_cash(), 90, "bedel 10 anında düştü")
	me.position = IN_ZONE
	await _frames(200)
	if eq(_results.size(), 1, "eli boş çekilme (ganimet yok, 3 sn bölgede)"):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"aborted")
		eq((r["strategy"] as Dictionary)["class"], HeistRules.STRATEGY_SOCIAL, "SATIN AL → strateji sosyal")
		eq(r["purchases"], 10)
		eq(r["cash_before"], 100, "gerçek iş öncesi kasa")
		eq(r["cash_after"], 90, "100 + 0 − 0 − 10")
	eq(Game.team_cash(), 90)
	Game.add_team_cash(-Game.team_cash())
	await _stop()
