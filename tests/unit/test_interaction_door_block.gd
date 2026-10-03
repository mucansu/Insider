extends TestCase
## IS-014 (2): a door does not close while a player with a body in the doorway (players layer) is there: host rejects with
## `blocked`, the prompt stays visible, HUD signals balanced on the player side (started -> finished(false)); opening is always
## free. Single process: offline singular id 1 = host. Rule: test_interaction.gd (circle_overlaps_box, BLOCKED); network:
## tests/net/{door_sync,contention}.json.

const DOOR_SCENE := "res://entities/props/door.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const DOOR_POS := Vector2(368, 464)
## The closing player: in front of the door, away from the wing (the waiting spot in door_sync).
const CLOSER := Vector2(368, 498)
const DT := 1.0 / 60.0


## Fake interaction actor (S7: group + interaction_position); no physics body -> not on the players layer.
class FakeActor:
	extends Node2D

	func interaction_position() -> Vector2:
		return global_position


var _results: Array = []


func _door(open: bool) -> Door:
	var door: Door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	door.position = DOOR_POS
	door.is_open = open
	tree().root.add_child(door)
	autofree(door)
	_interactable(door).request_finished.connect(func(seq: int, ok: bool) -> void: _results.append([seq, ok]))
	return door


func _interactable(door: Door) -> Interactable:
	return door.get_node("Interactable") as Interactable


func _fake(peer_id: int, at: Vector2) -> FakeActor:
	var actor := FakeActor.new()
	actor.set_multiplayer_authority(peer_id)
	actor.position = at
	actor.add_to_group(Interactable.ACTOR_GROUP)
	tree().root.add_child(actor)
	autofree(actor)
	return actor


## Real player scene; if `peer_id` is not 1 it is a remote copy (the interpolated player drawn on the host).
func _player(peer_id: int, at: Vector2) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id, true)
	player.position = at
	tree().root.add_child(player)
	autofree(player)
	return player


func _wait_cooldown(item: Interactable) -> void:
	for i: int in roundi(InteractionRules.REPEAT_COOLDOWN / DT) + 1:
		item.step(DT)


func test_open_door_does_not_close_on_player_in_gap() -> void:
	var door: Door = _door(true)
	var item: Interactable = _interactable(door)
	_fake(1, CLOSER)
	var other: Player = _player(2, DOOR_POS + Vector2(0, 6))
	is_true(door.is_closing_blocked(), "boşlukta oyuncu gövdesi")
	is_true(item.can_start(1, CLOSER), "istem görünür (istemci süzgeci engeli bilmez)")
	item.request_start(1)
	is_true(door.is_open, "kapanmadı")
	eq(_results, [[1, false]], "host reddi")
	eq(item.stats()["rejected"], {"blocked": 1})
	eq(item.action_key, "INTERACT_DOOR_CLOSE", "istem aynı: kapat")
	is_true(item.can_start(1, CLOSER), "red sonrası istem yine görünür")
	# A player leaning on the wing (tangent) or out of the doorway is not an obstruction.
	other.position = DOOR_POS + Vector2(0, 16)
	is_false(door.is_closing_blocked(), "teğet temas engel değil")
	other.position = DOOR_POS - Vector2(0, 40)
	item.request_start(2)
	is_false(door.is_open, "boşluk boşalınca kapanır")
	eq(_results.back(), [2, true])
	var stats: Dictionary = item.stats()
	eq([stats["requests"], stats["accepted"], stats["rejected_total"]], [2, 1, 1], "requests = accepted + rejected")


func test_opening_is_always_free() -> void:
	var door: Door = _door(false)
	var item: Interactable = _interactable(door)
	_fake(1, CLOSER)
	_player(2, DOOR_POS + Vector2(0, 14))
	is_false(door.is_closing_blocked(), "kapalı kapının kapanma engeli yok")
	item.request_start(1)
	is_true(door.is_open, "boşlukta (kanada dayalı) oyuncu varken de açılır")
	eq(_results, [[1, true]])
	# On opening the obstruction is evaluated: the same player still on the wing line -> does not close.
	_wait_cooldown(item)
	item.request_start(2)
	is_true(door.is_open)
	eq(item.stats()["rejected"], {"blocked": 1})


func test_closer_in_gap_blocks_itself_and_latest_position_counts() -> void:
	var door: Door = _door(true)
	var item: Interactable = _interactable(door)
	# The closing player themselves in the doorway (within range): the wing does not close on them.
	var closer: Player = _player(2, DOOR_POS + Vector2(4, 8))
	item.host_start(2, 1)
	is_true(door.is_open, "kendi üstüne kapanmaz")
	eq(item.stats()["rejected"], {"blocked": 1})
	# The host draws the player outside the doorway but the latest position from the synchroniser is in it (S2, in the player's favour).
	closer.position = DOOR_POS + Vector2(0, 34)
	closer.net_position = DOOR_POS + Vector2(0, 10)
	closer.net_time = 1.0
	is_true(door.is_closing_blocked(), "en güncel konum boşlukta")
	item.host_start(2, 2)
	is_true(door.is_open)
	closer.net_position = closer.position
	is_false(door.is_closing_blocked())
	item.host_start(2, 3)
	is_false(door.is_open, "iki konum da dışarıda: kapanır")


func test_non_player_actor_does_not_block() -> void:
	var door: Door = _door(true)
	var item: Interactable = _interactable(door)
	_fake(1, CLOSER)
	_fake(3, DOOR_POS)  # no body on the players layer
	is_false(door.is_closing_blocked())
	item.request_start(1)
	is_false(door.is_open)


## Player side (S7 HUD contract): a blocked close press yields started -> finished(false), the prompt remains.
func test_player_signals_balanced_when_blocked() -> void:
	var door: Door = _door(true)
	var player: Player = _player(1, CLOSER)
	_player(2, DOOR_POS + Vector2(-6, 2))
	var keys: Array[String] = []
	var started: Array = []
	var finished: Array[bool] = []
	player.interaction_target_changed.connect(func(k: String) -> void: keys.append(k))
	player.interaction_started.connect(func(k: String, d: float) -> void: started.append([k, d]))
	player.interaction_finished.connect(func(ok: bool) -> void: finished.append(ok))
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.05, "press": "interact"}]))
	for i: int in 8:
		await tree().physics_frame
	eq(keys, ["INTERACT_DOOR_CLOSE"] as Array[String], "istem: kapat (red sonrası değişmez)")
	eq(started, [["INTERACT_DOOR_CLOSE", 0.0]])
	eq(finished, [false] as Array[bool], "host reddi: başarısız, ceza yok")
	is_false(player.is_interacting())
	is_true(door.is_open)
	eq(_interactable(door).stats()["rejected"], {"blocked": 1})
