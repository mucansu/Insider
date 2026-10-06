extends TestCase
## US-048 regression: Game connects every node under the level's NPCs that has a `recognized` / `social_action` signal. The owner's
## brain used the same names as StoreOwner's relay, so one recognition / social action was counted twice. The brain now emits
## `peer_recognized` / `peer_social_action`; StoreOwner relays them once (host session + store_a, real Game job).

const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"

var _previous_scene: PackedScene = null


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _start() -> StoreOwner:
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	if not eq(Net.host(free_udp_port()), OK):
		return null
	Game.start_level(STORE)
	var level: Level = Game.current_level() as Level
	if level == null:
		return null
	for child: Node in level.npcs_root().get_children():
		if child is StoreOwner:
			return child as StoreOwner
	return null


func _stop() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = _previous_scene


func test_owner_recognition_and_social_action_counted_once() -> void:
	var o: StoreOwner = _start()
	if not is_true(o != null and Game._heist != null, "host oturumu, iş, sahip"):
		await _stop()
		return
	await tree().physics_frame
	var brain: OwnerBrain = o.brain()
	is_false(brain.has_signal(&"recognized"), "beyin Game'in bağlandığı adı taşımaz")
	is_false(brain.has_signal(&"social_action"))
	var relayed: Array[int] = []
	o.recognized.connect(func(peer_id: int) -> void: relayed.append(peer_id))
	brain.peer_recognized.emit(1)
	eq(relayed, [1] as Array[int], "StoreOwner aktarır")
	eq(int(Game._heist.recognized_extra.get(1, 0)), 1, "tanınma bir kez sayılır")
	var before: int = Game._heist.social_actions
	brain.peer_social_action.emit(1, &"buy")
	eq(Game._heist.social_actions - before, 1, "sosyal eylem bir kez sayılır")
	await _stop()
