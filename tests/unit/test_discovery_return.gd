extends TestCase
## IS-100 (KR-032) store balance: the owner's register check on returning to the counter + SEND return cost + shorter windows.
## store_a geometry, fixed step, single process = host, population off (NpcStage):
## - AC1: after being away from ClerkSpot (sent, listen, restock, backroom, phone; a customer interrupt that brings it back from an
##   away task) the owner discovers an emptied register `return_check_sec` (1 s) after standing back at ClerkSpot (trigger "return",
##   before the service hook); a full register -> nothing (and no later check while it stays at the counter); one discovery per source
##   (a later return after calming down does not discover again); none after the heist ends.
## - AC2: owner_tuning windows sent 7 s / listen 6 s.
## - AC3: back at the counter after SEND the (free) sender gets +20 suspicion once, wherever they are (an unseen meter drains); an
##   alarm in between cancels it.

const DT := 1.0 / 30.0
const COUNTER_FRONT := Vector2(528, 336)


func _stage() -> NpcStage:
	var stage := NpcStage.new(self)
	await stage.enter()
	var a: StoreAlert = stage.alert()
	a.tuning = a.tuning.duplicate() as OwnerTuning
	a.tuning.max_neighbours = 0
	return stage


func _register(stage: NpcStage) -> Node:
	return stage.level.props_root().get_node_or_null(^"Register")


## Runs `seconds`; empties the register once the owner is away (if `empty`); returns {"arrive": t back at ClerkSpot (last arrival),
## "discover": t of the first discovery, "away": whether it left}. Times in s from the call (-1 = never).
func _watch(stage: NpcStage, seconds: float, empty: bool) -> Dictionary:
	var o: StoreOwner = stage.owner()
	var clerk: Vector2 = stage.marker(&"ClerkSpot")
	var reg: Node = _register(stage)
	var out: Dictionary = {"arrive": -1.0, "discover": -1.0, "away": false}
	var t: Array[float] = [0.0]
	var on_discover: Callable = func(_source: int) -> void:
		if float(out["discover"]) < 0.0:
			out["discover"] = t[0]
	o.brain().discovered.connect(on_discover)
	stage.run(seconds, func() -> void:
		t[0] += DT
		var d: float = o.global_position.distance_to(clerk)
		if d > OwnerBrain.RETURN_AWAY_PX:
			out["away"] = true
			if empty and not bool(reg.get(&"emptied")):
				reg.set(&"emptied", true)
		if d > OwnerBrain.RETURN_AT_PX:
			if float(out["discover"]) < 0.0:
				out["arrive"] = -1.0
		elif bool(out["away"]) and float(out["arrive"]) < 0.0:
			out["arrive"] = t[0], DT)
	o.brain().discovered.disconnect(on_discover)
	return out


## Checks a "return" discovery `return_check_sec` after arriving back at ClerkSpot.
func _check_return(o: StoreOwner, seen: Dictionary, what: String) -> void:
	if not is_true(bool(seen["away"]), "%s: sahip tezgâhtan ayrıldı" % what):
		return
	if not is_true(float(seen["arrive"]) >= 0.0 and float(seen["discover"]) >= 0.0, "%s: döndü ve keşfetti %s" % [what, seen]):
		return
	var lag: float = float(seen["discover"]) - float(seen["arrive"])
	near(lag, o.brain().owner_tuning.return_check_sec, 2.0 * DT, "%s: varıştan 1 sn sonra" % what)
	if is_true(o.brain().discoveries.size() == 1, "%s: tek keşif" % what):
		eq(o.brain().discoveries[0]["source"], &"register", what)
		eq(o.brain().discoveries[0]["trigger"], OwnerBrain.TRIGGER_RETURN, what)
		eq(o.brain().discoveries[0]["full"], true, what)
	is_true(o.brain().state() == OwnerBrain.State.DISCOVER or o.brain().is_alarmed(), "%s: DISCOVER → bağırış" % what)


func test_return_after_sent() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	is_true(o.send_to_backroom())
	_check_return(o, _watch(stage, 40.0, true), "sent")
	stage.leave()


func test_return_after_listen() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	is_true(o.brain().hear(stage.marker(&"ShopSpot5"), 320.0, NoiseProfile.KIND_DOOR), "DİNLE")
	eq(o.agenda().task_name(), &"listen")
	_check_return(o, _watch(stage, 30.0, true), "listen")
	stage.leave()


func test_return_after_agenda_tasks() -> void:
	for task: StringName in [&"restock", &"backroom", &"phone"]:
		var stage: NpcStage = await _stage()
		var o: StoreOwner = stage.owner()
		stage.run(0.5, Callable(), DT)
		is_true(o.agenda().begin_task(task), String(task))
		_check_return(o, _watch(stage, 45.0, true), String(task))
		stage.leave()


## A customer brings the owner back from an away task: the return check (1 s) comes before the service's "register opens" (2 s).
func test_return_check_before_service_hook() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	is_true(o.agenda().begin_task(&"restock"))
	var first: Dictionary = _watch(stage, 9.0, true)
	is_true(bool(first["away"]), "rafa gitti")
	is_true(o.serve_customer(5), "müşteri kesmesi")
	_check_return(o, _watch(stage, 15.0, false), "customer")
	eq(o.brain().register_opens, 0, "kasa açılmadan dönüş kontrolü keşfetti")
	stage.leave()


## Full register: no discovery on return, and no second look while it stays at the counter (emptied later -> only service/idle rules).
func test_full_register_no_discovery() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	is_true(o.agenda().begin_task(&"restock"))
	var seen: Dictionary = _watch(stage, 30.0, false)
	is_true(bool(seen["away"]) and float(seen["arrive"]) >= 0.0, "gitti ve döndü %s" % seen)
	eq(o.brain().discoveries.size(), 0, "kasa dolu: keşif yok")
	near(o.global_position.distance_to(stage.marker(&"ClerkSpot")), 0.0, OwnerBrain.RETURN_AT_PX, "tezgâhta")
	_register(stage).set(&"emptied", true)
	stage.run(5.0, Callable(), DT)
	eq(o.brain().discoveries.size(), 0, "tezgâhta dururken ikinci dönüş kontrolü yok")
	stage.leave()


## One discovery per source: after the alarm calms down the owner goes to the backroom and returns to the counter again; the emptied
## register is not discovered a second time.
func test_no_second_discovery() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	is_true(o.agenda().begin_task(&"restock"))
	_check_return(o, _watch(stage, 30.0, true), "ilk dönüş")
	var clerk: Vector2 = stage.marker(&"ClerkSpot")
	var calm_return: Array[bool] = [false, false]  # [away while calm, back at the counter while calm afterwards]
	stage.run(150.0, func() -> void:
		if o.brain().state() != OwnerBrain.State.AGENDA:
			return
		var d: float = o.global_position.distance_to(clerk)
		if d > OwnerBrain.RETURN_AWAY_PX:
			calm_return[0] = true
		elif calm_return[0] and d <= OwnerBrain.RETURN_AT_PX:
			calm_return[1] = true, DT)
	is_true(calm_return[1], "sakinleşince yeniden ayrılıp tezgâha döndü")
	eq(o.brain().discoveries.size(), 1, "kaynak başına tek keşif")
	stage.leave()


func test_no_return_discovery_after_heist_end() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	is_true(o.agenda().begin_task(&"restock"))
	var first: Dictionary = _watch(stage, 5.0, true)
	is_true(bool(first["away"]), "rafa gitti")
	Game._rpc_heist_finished({"outcome": &"clean"})
	var seen: Dictionary = _watch(stage, 30.0, false)
	Game._heist_on_level_exiting()
	is_true(float(seen["arrive"]) >= 0.0, "tezgâha döndü")
	eq(o.brain().discoveries.size(), 0, "iş bittikten sonra keşif yok")
	eq(o.brain().state(), OwnerBrain.State.AGENDA)
	stage.leave()


## AC3: sender at the counter front (in sight, ~71 px) -> +20 once on return.
func test_send_return_cost_near() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.player(2, COUNTER_FRONT)
	stage.run(0.5, Callable(), DT)
	is_true(o.send_to_backroom(2))
	var peak: Array[float] = [0.0]
	var cost_at: Array[float] = [-1.0]
	var t: Array[float] = [0.0]
	stage.run(40.0, func() -> void:
		t[0] += DT
		peak[0] = maxf(peak[0], o.suspicion().value_of(2))
		if cost_at[0] < 0.0 and not o.brain().send_costs.is_empty():
			cost_at[0] = t[0], DT)
	eq(o.brain().send_costs, [{"peer": 2, "amount": 20.0}] as Array[Dictionary], "GÖNDER dönüş bedeli")
	is_true(peak[0] >= 19.0, "şüphe +20 (tepe %.1f)" % peak[0])
	eq(o.brain().sent_windows.size(), 1, "tezgâha döndü")
	eq(o.brain().discoveries.size(), 0, "kasa dolu: keşif yok")
	is_true(o.brain().state() == OwnerBrain.State.AGENDA, "+20 tek başına bağırtmaz")
	stage.leave()


## AC3: sender far away (street, unseen) -> the cost is still applied once, the unseen meter drains to nothing, no alarm.
func test_send_return_cost_far() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.player(2, stage.marker(&"StreetRoute1"))
	stage.run(0.5, Callable(), DT)
	is_true(o.send_to_backroom(2))
	var applied: Array[bool] = [false]
	stage.run(40.0, func() -> void:
		if not applied[0] and not o.brain().send_costs.is_empty():
			applied[0] = true, DT)
	eq(o.brain().sent_windows.size(), 1, "tezgâha döndü")
	eq(o.brain().send_costs, [{"peer": 2, "amount": 20.0}] as Array[Dictionary], "uzaktaki gönderene de bedel")
	near(o.suspicion().value_of(2), 0.0, 0.01, "görülmeyen şüphe söndü")
	is_true(o.brain().state() == OwnerBrain.State.AGENDA, "bağırış yok")
	stage.leave()


## AC3: an alarm while sent (shout) ends the errand -> no return cost later.
func test_send_return_cost_cancelled_by_alarm() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.player(2, stage.marker(&"StreetRoute1"))
	stage.run(0.5, Callable(), DT)
	is_true(o.send_to_backroom(2))
	stage.run(2.0, Callable(), DT)
	o.brain().shout(2, false)
	stage.run(40.0, Callable(), DT)
	eq(o.brain().send_costs.size(), 0, "alarm GÖNDER bedelini iptal eder")
	stage.leave()


## AC2 + tuning: shorter windows and the new numbers live in the data file.
func test_tuning_values() -> void:
	var tuning: OwnerTuning = load("res://data/npc/owner_tuning.tres") as OwnerTuning
	eq(tuning.sent_sec, 7.0, "sent_sec")
	eq(tuning.listen_sec, 6.0, "listen_sec")
	eq(tuning.return_check_sec, 1.0, "return_check_sec")
	eq(tuning.send_return_suspicion, 20.0, "send_return_suspicion")
