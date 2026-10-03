extends TestCase
## US-039 (eksik ganimetin doğal keşfi) + US-016 AC3 (servis kesmesi ve "kasa açılır" kancası), store_a geometrisinde
## sabit adım, tek süreç = host, nüfus kapalı (müşteri yerine `serve_customer` doğrudan):
## - AC3 (US-016): servis → sahip ClerkSpot'a gelir, batıya döner, 6 sn; 2. sn'de `register_opened`; aynı anda tek
##   servis; sonuç `serve_state`.
## - AC1: kasa boşsa "kasa açılır" anında keşif (register). AC2: arka oda (gönderilmiş) varışından 1 sn sonra çanta
##   yerinde değilse keşif (cash). AC3: müşterisiz tezgâhta kasa boşken toplam 45 sn → keşif; müşteri varken sayılmaz.
## - AC4: DISCOVER 1,5 sn (durur) → bağırış akışı (uyarı 2); `owner_discover` oturum olayı {source}; balon olayı.
## - AC6: kaynak başına bir keşif; alarmdayken ikinci kaynak yalnız balon + komşu +1.
## - AC7: iş bittikten sonra keşif yok. AC8: HUD metin anahtarı. AC9: tezgâhtayken kapı sesi (160 px) → DİNLE,
##   şüphe bedeli yok; arka kapı (B) tezgâhtan duyulmaz (264 px > 160).

const DT := 1.0 / 30.0


var _session: Array[Array] = []


func _on_session(kind: StringName, data: Dictionary) -> void:
	_session.append([kind, data.duplicate()])


func _stage(neighbours: int = 0) -> NpcStage:
	var stage := NpcStage.new(self)
	await stage.enter()
	var a: StoreAlert = stage.alert()
	a.tuning = a.tuning.duplicate() as OwnerTuning
	a.tuning.max_neighbours = neighbours
	_session.clear()
	if not Game.session_event.is_connected(_on_session):
		Game.session_event.connect(_on_session)
	return stage


func _leave(stage: NpcStage) -> void:
	if Game.session_event.is_connected(_on_session):
		Game.session_event.disconnect(_on_session)
	stage.leave()


func _register(stage: NpcStage) -> Node:
	return stage.level.props_root().get_node_or_null(^"Register")


func _discover_events() -> Array:
	var out: Array = []
	for item: Array in _session:
		if item[0] == OwnerBrain.DISCOVER_SESSION_EVENT:
			out.append(item[1])
	return out


func test_serve_hook_and_register_discovery() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	var reg: Node = _register(stage)
	reg.set(&"emptied", true)
	var opened: Array = []
	o.brain().register_opened.connect(func(id: int) -> void:
		opened.append([id, o.agenda().interrupt_elapsed(), o.perception().facing]))
	is_true(o.serve_customer(7), "servis kabul")
	eq(o.serve_state(7), OwnerBrain.Serve.PENDING)
	is_false(o.serve_customer(8), "aynı anda tek servis")
	is_true(o.serve_customer(7), "aynı müşterinin süren servisi")
	var discover_at: Array[float] = []
	var shout_at: Array[float] = []
	var t: Array[float] = [0.0]
	stage.run(12.0, func() -> void:
		t[0] += DT
		if discover_at.is_empty() and o.brain().state() == OwnerBrain.State.DISCOVER:
			discover_at.append(t[0])
		if shout_at.is_empty() and o.brain().state() == OwnerBrain.State.SHOUT:
			shout_at.append(t[0]), DT)
	if is_true(opened.size() == 1, "kasa açılır kancası"):
		eq(opened[0][0], 7)
		near(float(opened[0][1]), 2.0, DT + 0.001, "servisin 2. saniyesi")
		is_true((opened[0][2] as Vector2).x < -0.9, "batıya döner (%s)" % opened[0][2])
	if is_true(discover_at.size() == 1 and shout_at.size() == 1, "DISCOVER → SHOUT"):
		near(shout_at[0] - discover_at[0], 1.5, DT + 0.001, "DISCOVER 1,5 sn")
	eq(o.serve_state(7), OwnerBrain.Serve.ABORTED, "servis yarıda kaldı")
	eq(o.brain().discoveries.size(), 1)
	eq(_discover_events(), [{"source": "register"}], "owner_discover oturum olayı")
	var ev: Array[StringName] = o.events()
	eq(ev.slice(0, 2), [&"owner_discover_register", &"owner_shout"] as Array[StringName], "balon sonra bağırış")
	eq(Game.alert_level(), 2, "uyarı 2")
	is_false(o.discover(OwnerBrain.Source.REGISTER), "kaynak başına bir keşif")
	_leave(stage)


func test_serve_completes_without_theft() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(1.0, Callable(), DT)
	is_true(o.serve_customer(3))
	stage.run(4.0, Callable(), DT)
	eq(o.serve_state(3), OwnerBrain.Serve.ACTIVE)
	eq(o.agenda().task_name(), &"customer")
	near(o.global_position.distance_to(stage.marker(&"ClerkSpot")), 0.0, 8.0, "ClerkSpot'ta")
	stage.run(6.0, Callable(), DT)
	eq(o.serve_state(3), OwnerBrain.Serve.DONE)
	eq(o.brain().serves_done, 1)
	eq(o.brain().register_opens, 1)
	eq(o.brain().discoveries.size(), 0, "kasa dolu: keşif yok")
	eq(o.agenda().task_name(), &"counter", "ajandaya döndü")
	_leave(stage)


## AC3: müşterisiz tezgâhta kasa boşken toplam 45 sn → keşif; içeride müşteri varken sayılmaz.
func test_idle_counter_discovery() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	_register(stage).set(&"emptied", true)
	var customers: Array[int] = [1]
	o.senses().customers_query = func() -> int: return customers[0]
	stage.run(150.0, Callable(), DT)
	eq(o.brain().discoveries.size(), 0, "müşteri varken boşta sayacı işlemez")
	customers[0] = 0
	var counter: Array[float] = [0.0]
	var at: Array[float] = []
	stage.run(200.0, func() -> void:
		if not at.is_empty():
			return
		var a: Agenda = o.agenda()
		if o.brain().state() == OwnerBrain.State.AGENDA and a.current_interrupt() == Agenda.Interrupt.NONE \
				and a.current_task() != null and a.current_task().home and a.has_arrived():
			counter[0] += DT
		if o.brain().discoveries.size() > 0:
			at.append(counter[0]), DT)
	if is_true(at.size() == 1, "boşta keşif"):
		near(at[0], 45.0, 2.0 * DT, "tezgâhta toplam 45 sn")
		eq(o.brain().discoveries[0]["source"], &"register")
	_leave(stage)


## AC2: gönderilmiş (ya da arka oda görevi) varıştan 1 sn sonra çanta yerinde değilse keşif.
func test_sent_backroom_discovers_taken_cash() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	var bag: Node = stage.level.props_root().get_node_or_null(^"Bag")
	if not is_true(bag != null, "store_a Bag"):
		_leave(stage)
		return
	bag.set(&"carrier", 2)
	stage.run(0.5, Callable(), DT)
	is_true(o.send_to_backroom())
	var at: Array[float] = []
	o.brain().discovered.connect(func(_source: int) -> void: at.append(o.agenda().arrived_for()))
	stage.run(20.0, Callable(), DT)
	is_true(o.brain().state() != OwnerBrain.State.AGENDA, "keşif → DISCOVER/bağırış")
	if is_true(at.size() == 1, "arka odada keşif"):
		near(at[0], 1.0, DT + 0.001, "varıştan 1 sn sonra")
	eq(_discover_events(), [{"source": "cash"}])
	has(o.events(), &"owner_discover_cash")
	_leave(stage)


## AC6: alarmdayken ikinci kaynak: yalnız balon + komşu +1 (en fazla 2); aynı kaynak ikinci kez yok.
func test_second_source_while_alarmed() -> void:
	var stage: NpcStage = await _stage(2)
	var o: StoreOwner = stage.owner()
	var shouts: Array[bool] = []
	o.brain().shouted.connect(func(late: bool) -> void: shouts.append(late))
	is_true(o.discover(OwnerBrain.Source.REGISTER))
	stage.run(2.0, Callable(), DT)
	is_true(o.brain().is_alarmed())
	is_true(o.discover(OwnerBrain.Source.CASH))
	is_false(o.discover(OwnerBrain.Source.CASH))
	eq(o.brain().state() != OwnerBrain.State.DISCOVER, true, "alarmdayken DISCOVER yok")
	eq(shouts, [true, true] as Array[bool], "keşif bağırışı + komşu çağrısı")
	eq(_discover_events(), [{"source": "register"}], "ikinci keşif yalnız balon (HUD olayı yok)")
	has(o.events(), &"owner_discover_cash")
	stage.run(9.0, Callable(), DT)
	eq(stage.alert().chasers().size(), 2, "komşu +1 (en fazla 2)")
	_leave(stage)


## AC7: iş bittikten sonra keşif üretilmez.
func test_no_discovery_after_heist_finished() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	Game._rpc_heist_finished({"outcome": &"clean"})
	is_false(o.discover(OwnerBrain.Source.REGISTER), "iş bitti")
	Game._heist_on_level_exiting()
	is_true(Game.heist_result().is_empty())
	is_true(o.discover(OwnerBrain.Source.REGISTER), "iş sürüyor")
	_leave(stage)


## AC9: tezgâhtayken kapı sesi (160 px) → DİNLE (döner, bakar), şüphe bedeli yok; arka kapı (B) tezgâhtan duyulmaz.
func test_door_noise_listen_at_counter() -> void:
	var stage: NpcStage = await _stage()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	eq(o.agenda().task_name(), &"counter")
	NoiseBus.emit_noise(stage.marker(&"BackDoor"), 160.0, NoiseProfile.KIND_DOOR)
	stage.run(0.1, Callable(), DT)
	eq(o.agenda().task_name(), &"counter", "arka kapı (B) tezgâhtan 160 px dışında")
	NoiseBus.emit_noise(stage.marker(&"BackroomDoor"), 160.0, NoiseProfile.KIND_DOOR)
	stage.run(0.1, Callable(), DT)
	eq(o.agenda().task_name(), &"listen", "arka oda kapısı sesi → DİNLE")
	stage.run(2.0, Callable(), DT)
	var to_door: Vector2 = (stage.marker(&"BackroomDoor") - o.global_position).normalized()
	is_true(o.perception().facing.dot(to_door) > 0.7, "sese döner")
	eq(o.suspicion().peers().size(), 0, "görülmeden girişe şüphe bedeli yok")
	_leave(stage)


## AC8: HUD olay metni anahtarı (IS-080 kalıbı dışı ad: override).
func test_hud_event_key() -> void:
	eq(Hud.event_key(OwnerBrain.DISCOVER_SESSION_EVENT), "EVENT_OWNER_DISCOVERED")
	eq(Hud.event_key(&"player_held"), "EVENT_PLAYER_HELD", "kalıp değişmedi")
	ne(tr("EVENT_OWNER_DISCOVERED"), "EVENT_OWNER_DISCOVERED")
	ne(tr("OWNER_DISCOVER_REGISTER"), "OWNER_DISCOVER_REGISTER")
	ne(tr("OWNER_DISCOVER_CASH"), "OWNER_DISCOVER_CASH")
