extends TestCase
## IS-014 (2): kapı, kapı boşluğunda gövdesi olan bir oyuncu (players katmanı) varken kapanmaz: host `blocked`
## ile reddeder, istem görünür kalır, oyuncu tarafında HUD sinyalleri dengeli (started → finished(false));
## açma her zaman serbest. Tek süreç: çevrimdışı tekil kimlik 1 = host. Kural: test_interaction.gd
## (circle_overlaps_box, BLOCKED); ağ: tests/net/{door_sync,contention}.json.

const DOOR_SCENE := "res://entities/props/door.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const DOOR_POS := Vector2(368, 464)
## Kapatan oyuncu: kapının önünde, kanattan uzak (door_sync'teki bekleme yeri).
const CLOSER := Vector2(368, 498)
const DT := 1.0 / 60.0


## Etkileşim aktörü taklidi (S7: grup + interaction_position); fizik gövdesi yok → players katmanında değil.
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


## Gerçek oyuncu sahnesi; `peer_id` 1 değilse uzak kopya (host'ta çizilen ara değerlenmiş oyuncu).
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
	# Kanada yaslanmış (teğet) ve boşluktan çıkmış oyuncu engel değil.
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
	# Açılınca engel değerlendirilir: aynı oyuncu hâlâ kanat çizgisinde → kapanmaz.
	_wait_cooldown(item)
	item.request_start(2)
	is_true(door.is_open)
	eq(item.stats()["rejected"], {"blocked": 1})


func test_closer_in_gap_blocks_itself_and_latest_position_counts() -> void:
	var door: Door = _door(true)
	var item: Interactable = _interactable(door)
	# Kapatan oyuncunun kendisi boşlukta (menzil içinde): kanat ona kapanmaz.
	var closer: Player = _player(2, DOOR_POS + Vector2(4, 8))
	item.host_start(2, 1)
	is_true(door.is_open, "kendi üstüne kapanmaz")
	eq(item.stats()["rejected"], {"blocked": 1})
	# Host oyuncuyu boşluğun dışında çiziyor ama eşitleyiciden gelen en güncel konum boşlukta (S2, oyuncu lehine).
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
	_fake(3, DOOR_POS)  # players katmanında gövdesi yok
	is_false(door.is_closing_blocked())
	item.request_start(1)
	is_false(door.is_open)


## Oyuncu tarafı (S7 HUD sözleşmesi): engelli kapatma basışı started → finished(false) üretir, istem kalır.
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
