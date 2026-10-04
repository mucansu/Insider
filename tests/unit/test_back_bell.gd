extends TestCase
## IS-104 (KR-034) back door bell: a player opening/closing the back door B (Props/BackDoor Interactable `completed` on the host) rings
## the bell, so does crossing its threshold (in/out; open + step through within 1.5 s = one ring); store_a geometry, fixed step, single
## process = host, population off (NpcStage):
## - AC a: owner calm at ClerkSpot (home task, no interrupt) -> LISTEN toward BackroomSpot, leaves within 1 s, stands there within 4 s;
##   bag missing -> `backroom_check_sec` after arrival discover(CASH, "bell") -> DISCOVER; bag in place -> back to the counter.
## - AC b: owner busy (customer service, other agenda task, LOOK) -> no reaction, event log "zil duyulmadı (...)".
## - NPC completions (peer 0) do not ring; the bell sound rings at the door either way (heard owner or not).
## - AC c: tuning field `back_bell_door` in data/npc/owner_tuning.tres.

const DT := 1.0 / 30.0
const PEER := 2


func _stage() -> NpcStage:
	var stage := NpcStage.new(self)
	await stage.enter()
	var a: StoreAlert = stage.alert()
	a.tuning = a.tuning.duplicate() as OwnerTuning
	a.tuning.max_neighbours = 0
	return stage


func _ring(stage: NpcStage, peer_id: int = PEER) -> void:
	var item: Interactable = stage.level.props_root().get_node_or_null(^"BackDoor/Interactable") as Interactable
	if is_true(item != null, "store_a BackDoor/Interactable"):
		item.completed.emit(peer_id)


func _take_bag(stage: NpcStage) -> void:
	var bag: Node = stage.level.props_root().get_node_or_null(^"Bag")
	if is_true(bag != null, "store_a Bag"):
		bag.set(&"carrier", 5)


func _log_has(o: StoreOwner, text: String) -> bool:
	for entry: Dictionary in o.brain().event_log.entries:
		if String(entry["why"]).contains(text):
			return true
	return false


func test_tuning_field() -> void:
	var t: OwnerTuning = load("res://data/npc/owner_tuning.tres") as OwnerTuning
	eq(t.back_bell_door, &"BackDoor")
	eq(t.listen_sec, 6.0)
	eq(t.backroom_check_sec, 1.0)


## AC a: calm at the counter, B opens, bag gone -> leaves <= 1 s, BackroomSpot <= 4 s, discovery "bell" 1 s after arrival.
func test_calm_owner_walks_to_backroom_and_discovers() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	eq(o.agenda().task_name(), &"counter")
	is_true(o.agenda().has_arrived(), "tezgâhta")
	_take_bag(stage)
	var clerk: Vector2 = stage.marker(&"ClerkSpot")
	var spot: Vector2 = stage.marker(&"BackroomSpot")
	var seen: Dictionary = {"left": -1.0, "arrive": -1.0, "discover": -1.0}
	var t: Array[float] = [0.0]
	o.brain().discovered.connect(func(_source: int) -> void:
		if float(seen["discover"]) < 0.0:
			seen["discover"] = t[0])
	_ring(stage)
	eq(o.agenda().task_name(), &"listen", "zil -> DİNLE")
	has(o.events(), &"owner_listen")
	stage.run(8.0, func() -> void:
		t[0] += DT
		if float(seen["left"]) < 0.0 and o.global_position.distance_to(clerk) > 8.0:
			seen["left"] = t[0]
		if float(seen["arrive"]) < 0.0 and o.global_position.distance_to(spot) <= OwnerBrain.STAND_PX + 2.0:
			seen["arrive"] = t[0], DT)
	is_true(float(seen["left"]) >= 0.0 and float(seen["left"]) <= 1.0, "1 sn içinde yola çıkar %s" % seen)
	is_true(float(seen["arrive"]) >= 0.0 and float(seen["arrive"]) <= 4.0, "4 sn içinde BackroomSpot %s" % seen)
	if is_true(float(seen["discover"]) >= 0.0, "çanta eksik -> keşif"):
		near(float(seen["discover"]) - float(seen["arrive"]), o.brain().owner_tuning.backroom_check_sec, 0.25, "varıştan ~1 sn")
	if is_true(o.brain().discoveries.size() == 1, "tek keşif"):
		eq(o.brain().discoveries[0]["source"], &"cash")
		eq(o.brain().discoveries[0]["trigger"], OwnerBrain.TRIGGER_BELL)
	is_true(o.brain().state() == OwnerBrain.State.DISCOVER or o.brain().is_alarmed(), "DISCOVER -> bağırış")
	is_true(_log_has(o, "arka kapı zili -> DİNLE"), "olay günlüğü")
	stage.leave()


## Bag in place: the owner checks, finds it and goes back to the counter (return check: register still full).
func test_bell_with_bag_in_place() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	_ring(stage)
	eq(o.agenda().task_name(), &"listen")
	stage.run(12.0, Callable(), DT)
	eq(o.brain().discoveries.size(), 0, "çanta yerinde: keşif yok")
	eq(o.brain().state(), OwnerBrain.State.AGENDA)
	is_true(_log_has(o, "arka oda kontrolü: çanta yerinde"), "kontrol yapıldı")
	is_true(o.global_position.distance_to(stage.marker(&"ClerkSpot")) <= 12.0, "tezgâha döndü")
	stage.leave()


## AC b: during a customer service (BUY uses the same flow) the bell is not heard.
func test_not_heard_while_serving() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	_take_bag(stage)
	is_true(o.serve_customer(5), "servis")
	stage.run(0.5, Callable(), DT)
	eq(o.agenda().task_name(), &"customer")
	var bells: int = int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0))
	_ring(stage)
	eq(o.agenda().task_name(), &"customer", "zil servisi kesmez")
	eq(int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0)), bells + 1, "zil sesi kapıda yine çalar")
	stage.run(0.1, Callable(), DT)
	is_true(_log_has(o, "zil duyulmadı (customer)"), "olay günlüğü notu")
	stage.run(5.0, Callable(), DT)
	eq(o.brain().discoveries.size(), 0, "tepki yok")
	stage.leave()


## AC b: other agenda task (restock, still walking) and a reaction state (LOOK) -> not heard.
func test_not_heard_away_or_reacting() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	is_true(o.agenda().begin_task(&"restock"))
	stage.run(0.2, Callable(), DT)
	is_false(o.brain().back_door_bell(stage.marker(&"BackDoor")), "rafta: duyulmaz")
	eq(o.agenda().task_name(), &"restock")
	stage.run(0.1, Callable(), DT)
	is_true(_log_has(o, "zil duyulmadı (restock)"))
	stage.leave()
	stage = await _stage()
	o = stage.owner()
	stage.run(1.0, Callable(), DT)
	o.brain().fsm.go(OwnerBrain.State.LOOK)
	is_false(o.brain().back_door_bell(stage.marker(&"BackDoor")), "BAK: duyulmaz")
	stage.run(0.1, Callable(), DT)
	is_true(_log_has(o, "zil duyulmadı (look)"))
	stage.leave()


## Crossing the threshold (alley -> back room and back) rings too; opening + stepping through within 1.5 s is one ring.
func test_crossing_rings() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	var p: Player = stage.player(PEER, Vector2(656, 80))
	stage.run(0.1, Callable(), DT)
	eq(o.agenda().task_name(), &"counter", "sokakta: zil yok")
	var bells: int = int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0))
	_ring(stage)
	p.position = Vector2(656, 144)
	stage.run(0.1, Callable(), DT)
	eq(o.agenda().task_name(), &"listen", "açılış + giriş -> DİNLE")
	eq(int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0)), bells + 1, "açıp geçmek tek zil")
	p.position = Vector2(900, 560)  # leaves far from the door (no ring), out of the owner's sight
	stage.run(14.0, Callable(), DT)
	eq(o.agenda().task_name(), &"counter", "kontrol bitti, tezgâhta")
	is_true(o.agenda().has_arrived(), "tezgâha vardı")
	p.position = Vector2(528, 176)  # back room, away from the door: no ring
	stage.run(0.1, Callable(), DT)
	eq(o.agenda().task_name(), &"counter")
	p.position = Vector2(656, 144)
	stage.run(0.1, Callable(), DT)
	p.position = Vector2(656, 80)
	stage.run(0.1, Callable(), DT)
	eq(o.agenda().task_name(), &"listen", "çıkış geçişi de zil")
	eq(int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0)), bells + 2)
	stage.leave()


## An NPC closing the door (peer 0) does not ring; the inner door D stays a plain door sound (LISTEN toward D, no back-room walk).
func test_npc_completion_and_inner_door() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	var bells: int = int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0))
	_ring(stage, 0)
	eq(o.agenda().task_name(), &"counter", "NPC kapatması zil sayılmaz")
	eq(int(o.brain().agenda_noises.get(NoiseProfile.KIND_BELL, 0)), bells)
	NoiseBus.emit_noise(stage.marker(&"BackroomDoor"), 160.0, NoiseProfile.KIND_DOOR)
	stage.run(2.0, Callable(), DT)
	eq(o.agenda().task_name(), &"listen", "D sesi -> DİNLE")
	var to_door: Vector2 = (stage.marker(&"BackroomDoor") - o.global_position).normalized()
	is_true(o.perception().facing.dot(to_door) > 0.7, "D'ye döner")
	is_false(_log_has(o, "arka kapı zili"), "D zil değil")
	stage.leave()
