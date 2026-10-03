extends TestCase
## US-012 bag (entities/props/bag.*; single process, offline singular id 1 = host): data (bag.tres, S10), store_a
## placement (BackroomCash -> Props/Bag), 2 s pickup, cannot pick up with full hands, 0.3 s handover (a carrier cannot take
## their own bag back), while running a 25% drop roll every full second + 160 px noise (the test injects the dice and noise sink),
## no roll while walking, drops when the carrier leaves, `host_drop`, follows the carrier, the real player's
## `interaction_tags` / `is_carrying` / `is_sprinting` answers. Public API only: `Interactable.host_start/step`, `Bag.step/host_drop`.

const BAG_SCENE := "res://entities/props/bag.tscn"
const BAG_DEF := "res://data/props/bag.tres"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const STORE := "res://levels/store_a.tscn"
const DT := 1.0 / 60.0
const AT := Vector2(200, 200)


## Fake of the player's S7 + US-012 interface: group, position, `free_hands` when hands are empty, run flag.
class FakeActor:
	extends Node2D
	var sprinting: bool = false

	func interaction_position() -> Vector2:
		return global_position

	func interaction_tags() -> Dictionary:
		return {} if Bag.carried_by(get_tree(), get_multiplayer_authority()) != null \
			else {HeistRules.FREE_HANDS_TAG: 1}

	func is_sprinting() -> bool:
		return sprinting


var _noises: Array = []
var _taken: Array[int] = []
var _dropped: Array[int] = []
var _rolls: Array[float] = []


func _actor(peer_id: int, at: Vector2) -> FakeActor:
	var actor := FakeActor.new()
	actor.set_multiplayer_authority(peer_id)
	actor.position = at
	actor.add_to_group(Interactable.ACTOR_GROUP)
	tree().root.add_child(actor)
	autofree(actor)
	return actor


func _bag(at: Vector2 = AT) -> Bag:
	var bag: Bag = (load(BAG_SCENE) as PackedScene).instantiate() as Bag
	bag.position = at
	tree().root.add_child(bag)
	autofree(bag)
	bag.noise_sink = func(pos: Vector2, radius: float, kind: StringName, peer: int) -> void:
		_noises.append([pos, radius, kind, peer])
	bag.roll_source = func() -> float: return _rolls.pop_front() if not _rolls.is_empty() else 0.99
	bag.taken.connect(func(peer: int) -> void: _taken.append(peer))
	bag.dropped.connect(func(peer: int) -> void: _dropped.append(peer))
	return bag


func _run(item: Interactable, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		item.step(DT)


func _step(bag: Bag, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		bag.step(DT)


func _take(bag: Bag) -> Interactable:
	return bag.get_node("Take") as Interactable


func _handoff(bag: Bag) -> Interactable:
	return bag.get_node("Handoff") as Interactable


## `peer_id` picks up the bag (the retry cooldown passes first, then 2 s hold).
func _pick(bag: Bag, peer_id: int) -> void:
	_run(_take(bag), InteractionRules.REPEAT_COOLDOWN + 0.05)
	_take(bag).host_start(peer_id, 1)
	_run(_take(bag), 2.05)


func test_bag_def() -> void:
	var def: PropDef = load(BAG_DEF) as PropDef
	if not is_true(def != null, "bag.tres PropDef olmalı"):
		return
	eq(def.id(), &"bag")
	eq(def.hold_time, 2.0, "2 sn alma")
	eq(def.action_key, "INTERACT_BAG_TAKE")
	eq(def.alt_action_key, "INTERACT_BAG_HANDOFF")
	is_true(def.cash_value >= 300 and def.cash_value <= 600, "arka oda nakdi 300-600 (GDD §9.3)")
	is_true(def.requirement != null and def.requirement.required_tag == HeistRules.FREE_HANDS_TAG, "eli boş etiketi")


func test_store_has_bag_at_backroom_cash() -> void:
	var level: Level = (load(STORE) as PackedScene).instantiate() as Level
	autofree(level)
	var bag: Node2D = level.props_root().get_node_or_null("Bag") as Node2D
	if not is_true(bag != null and bag.scene_file_path == BAG_SCENE, "Props/Bag alt sahne örneği"):
		return
	eq(bag.position, level.marker(&"BackroomCash").position, "BackroomCash konumunda")


func test_take_needs_two_seconds_and_free_hands() -> void:
	var bag: Bag = _bag()
	_actor(2, AT + Vector2(20, 0))
	_take(bag).host_start(2, 1)
	_run(_take(bag), 1.9)
	eq(bag.carrier, 0, "2 sn dolmadan alınmaz")
	_run(_take(bag), 0.15)
	eq(bag.carrier, 2, "2 sn sonra taşıyan")
	eq(_taken, [2])
	is_false(_take(bag).enabled, "taşınırken yerden alınmaz")
	is_true(_handoff(bag).enabled, "taşınırken devir açık")
	is_true(bag.is_carried())
	eq(Bag.carried_by(tree(), 2), bag)
	var other: Bag = _bag(AT + Vector2(0, 30))
	_take(other).host_start(2, 2)
	eq(_take(other).stats()["rejected"], {"missing_tag": 1}, "eli dolu oyuncu ikinci çantayı alamaz")


func test_handoff_in_point_three_seconds() -> void:
	var bag: Bag = _bag()
	var carrier: FakeActor = _actor(2, AT)
	_actor(3, AT + Vector2(16, 0))
	_pick(bag, 2)
	_step(bag, DT)
	near(bag.global_position, carrier.global_position + Bag.CARRY_OFFSET, 0.01, "taşıyanı izler")
	_handoff(bag).host_start(2, 5)
	eq(_handoff(bag).stats()["rejected"], {"missing_tag": 1}, "taşıyan kendi çantasını devralamaz")
	_handoff(bag).host_start(3, 1)
	_run(_handoff(bag), 0.2)
	eq(bag.carrier, 2, "0,3 sn dolmadan devir yok")
	_run(_handoff(bag), 0.15)
	eq(bag.carrier, 3, "0,3 sn sonra devredildi")
	eq(_taken, [2, 3], "alma ve devralma sayılır (Hamal notu)")


func test_sprinting_drops_each_second_with_quarter_chance() -> void:
	var bag: Bag = _bag()
	var actor: FakeActor = _actor(2, AT)
	_pick(bag, 2)
	_rolls = [0.0]
	_step(bag, 3.0)
	eq(_rolls.size(), 1, "yürürken zar atılmaz")
	eq(bag.carrier, 2, "yürürken düşmez")
	actor.sprinting = true
	_rolls = [0.9, 0.3, 0.1]
	_step(bag, 0.98)
	eq(_rolls.size(), 3, "tam saniye dolmadan zar yok")
	_step(bag, 0.05)
	eq(_rolls.size(), 2, "1. saniye: zar 0,9 → tutar")
	_step(bag, 1.0)
	eq(bag.carrier, 2, "2. saniye: zar 0,3 ≥ 0,25 → tutar")
	actor.position = Vector2(260, 210)
	_step(bag, 1.0)
	eq(bag.carrier, 0, "3. saniye: zar 0,1 < 0,25 → düşer")
	eq(bag.drops, 1)
	eq(_dropped, [2])
	eq(bag.floor_position, Vector2(260, 210), "taşıyanın konumunda yere iner")
	eq(_noises, [[Vector2(260, 210), 160.0, &"bag_drop", 2]], "160 px gürültü (S8)")
	is_true(_take(bag).enabled, "düşen çanta yeniden alınabilir")
	_step(bag, DT)
	eq(bag.position, Vector2(260, 210))


func test_drops_when_carrier_leaves_and_on_host_drop() -> void:
	var bag: Bag = _bag()
	var actor: FakeActor = _actor(2, AT + Vector2(10, 0))
	_pick(bag, 2)
	bag.host_drop()
	eq(bag.carrier, 0, "host_drop (ör. yakalanma) düşürür")
	eq(_noises.size(), 1)
	_step(bag, HeistRules.BAG_RETAKE_DELAY + 0.05)
	_pick(bag, 2)
	actor.position = Vector2(300, 300)
	_step(bag, DT)
	tree().root.remove_child(actor)
	_step(bag, DT)
	eq(bag.carrier, 0, "taşıyan ayrılınca düşer")
	tree().root.add_child(actor)


func test_dropped_bag_retakable_after_point_three_seconds() -> void:
	var bag: Bag = _bag()
	_actor(2, AT + Vector2(10, 0))
	_pick(bag, 2)
	bag.host_drop()
	_run(_take(bag), InteractionRules.REPEAT_COOLDOWN + 0.05)  # the component's retry cooldown is separate
	_step(bag, 0.2)
	_take(bag).host_start(2, 7)
	eq(_take(bag).stats()["rejected"], {"blocked": 1}, "düştükten 0,2 sn sonra alınamaz (KR-026)")
	_step(bag, 0.15)
	_take(bag).host_start(2, 8)
	eq(_take(bag).stats()["busy_by"], 2, "0,3 sn sonra yeniden alınabilir")
	_run(_take(bag), 2.05)
	eq(bag.carrier, 2)
	eq(bag.dump_state()["seen_carriers"], [2], "görülen taşıyan dökümde")


func test_host_lock_rejects_take_and_handoff() -> void:
	var bag: Bag = _bag()
	_actor(2, AT + Vector2(10, 0))
	_actor(3, AT + Vector2(20, 0))
	_pick(bag, 2)
	bag.host_lock()
	_handoff(bag).host_start(3, 1)
	eq(_handoff(bag).stats()["rejected"], {"blocked": 1}, "iş bitti: devir reddedilir")
	bag.host_drop()
	_step(bag, 1.0)
	_run(_take(bag), 1.0)
	_take(bag).host_start(3, 2)
	eq(_take(bag).stats()["rejected"], {"blocked": 1}, "iş bitti: yerden alma reddedilir")
	eq(bag.carrier, 0)


func test_player_tags_and_sprint() -> void:
	var bag: Bag = _bag(Vector2(400, 400))
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.set_multiplayer_authority(1, true)
	player.position = Vector2(400, 420)
	tree().root.add_child(player)
	autofree(player)
	eq(player.interaction_tags(), {HeistRules.FREE_HANDS_TAG: 1, Player.COVER_TAG: 1}, "eli boş (+ US-043 örtü etiketi)")
	is_false(player.is_carrying())
	_pick(bag, 1)
	eq(bag.carrier, 1)
	is_true(player.is_carrying())
	eq(player.interaction_tags(), {Player.COVER_TAG: 1},
		"taşırken free_hands yok: başka çanta/devir istemi yok (örtü etiketi ayrı, US-043)")
	is_false(player.is_sprinting(), "duran oyuncu koşmuyor")
	player.move_mode = PlayerMotion.Mode.SPRINT
	player.velocity = Vector2(220, 0)
	is_true(player.is_sprinting())
	player.velocity = Vector2.ZERO
	is_false(player.is_sprinting(), "koşu tuşu basılı ama duruyor")
