extends TestCase
## US-010 shop interactions (store_a, fixed step, single process = host; GDD §9.3, KR-026): rules (CivilianRules: BUY cost, loiter
## threshold, distraction ledger, phone time), BUY (service hook, suspicion/loiter 0, cost, comes when no owner), SEND TO BACK ROOM
## (1 per job, register window >= 10 s), prompts hidden after a shout, LOITER (look lock, "what does this guy want", innocent),
## DISTRACT (knocking over a shelf: LISTEN <= 1 s from ClerkSpot, not from BackroomSpot/PhoneSpot; the phone rings after 3 s, is
## found, 1 per job; a second distraction +30), two prompt lines (E/Q channels), start_blocker with peers, loiter resets on
## leaving the shop, text presence.

const DT := 1.0 / 60.0
## Customer side of the counter: QueueSpot2 (counter front: BUY + SEND) and QueueSpot1 (register front, 64 px from the owner: LOITER + SEND).
const COUNTER_FRONT := Vector2(528, 336)
const REGISTER_FRONT := Vector2(528, 368)
const STREET := Vector2(880, 592)
## In the sales area 68 px from the owner (ClerkSpot), not exactly west (the look turning is measured).
const TALK_SPOT := Vector2(532, 404)
const TEXT_KEYS: Array[String] = ["INTERACT_COUNTER_BUY", "INTERACT_COUNTER_SEND", "INTERACT_OWNER_TALK",
	"INTERACT_SHELF_TOPPLE", "INTERACT_PHONE_DROP", "OWNER_SERVE", "OWNER_TALK", "OWNER_SENT", "OWNER_LISTEN",
	"OWNER_AGAIN", "OWNER_PHONE_FOUND", "OWNER_LOITER", "EVENT_PURCHASE", "EVENT_OWNER_SENT",
	"EVENT_OWNER_DISTRACTED", "EVENT_PHONE_FOUND"]


func _counter(stage: NpcStage) -> ShopCounter:
	return stage.level.props_root().get_node(^"Counter") as ShopCounter


func _shelf(stage: NpcStage, index: int) -> ShelfProp:
	var shelf: ShelfProp = stage.level.props_root().get_node(NodePath("ShelfProp%d" % index)) as ShelfProp
	shelf.set_physics_process(false)  # the clock is stepped by hand (probe) in the test
	return shelf


func _events(o: StoreOwner) -> Array:
	var out: Array = []
	for kind: StringName in StoreOwner.EVENT_KINDS:
		o.connect(kind, func(peer_id: int) -> void: out.append([kind, peer_id]))
	# Host hook (US-042 strategy tag "social"): [&"social", peer, kind].
	o.social_action.connect(func(peer_id: int, kind: StringName) -> void: out.append([&"social", peer_id, kind]))
	return out


## Keeps a hold going through the host path (Interactable host API; the requesting actor is in the scene).
func _hold(stage: NpcStage, item: Interactable, peer_id: int, seconds: float) -> void:
	item.host_start(peer_id, 1)
	stage.run(seconds)


# --- rules ---

func test_rules_purchase_loiter_distraction_log() -> void:
	eq(CivilianRules.purchase_cost(100, 10), 10)
	eq(CivilianRules.purchase_cost(10, 10), 10, "tam yeterse öder")
	eq(CivilianRules.purchase_cost(9, 10), 0, "yetmiyorsa bedava")
	eq(CivilianRules.purchase_cost(-50, 10), 0, "borçtayken bedava")
	is_true(CivilianRules.loiter_crossed(59.9, 60.0, 60.0))
	is_false(CivilianRules.loiter_crossed(60.0, 60.1, 60.0), "eşik bir kez")
	is_false(CivilianRules.loiter_crossed(10.0, 20.0, 60.0))
	var log := CivilianRules.DistractionLog.new()
	is_true(log.note("ShelfProp1:topple"))
	is_false(log.is_again(), "ilk dikkat dağıtma bedelsiz")
	is_false(log.note("ShelfProp1:topple"), "aynı kaynak bir kez")
	is_true(log.note("ShelfProp2:cellphone"))
	is_true(log.is_again(), "ikinci kaynak: yine mi?")
	is_false(log.note(""), "boş anahtar sayılmaz")
	eq(log.count, 2)


func test_rules_phone_clock() -> void:
	var clock := CivilianRules.PhoneClock.new(3.0, 2.0, 3)
	is_false(clock.take(), "bırakılmamış telefon alınmaz")
	is_true(clock.plant(4))
	is_false(clock.plant(5), "tek telefon")
	eq(clock.peer, 4)
	var rings: Array[float] = []
	var t: float = 0.0
	for i: int in 600:
		t += 0.02
		if clock.step(0.02):
			rings.append(snappedf(t, 0.01))
	eq(rings.size(), 3, "en çok 3 kez çalar")
	near(rings[0], 3.0, 0.03, "3 sn sonra çalar")
	near(rings[1] - rings[0], 2.0, 0.03, "aralık 2 sn")
	eq(clock.state, CivilianRules.Phone.SILENT, "sonra susar")
	is_true(clock.take(), "susmuş telefon da bulunur")
	eq(clock.state, CivilianRules.Phone.FOUND)
	is_false(clock.step(5.0))


func test_peer_aware_start_blocker() -> void:
	var item: Interactable = autofree(Interactable.new()) as Interactable
	is_false(item.is_blocked_for(2), "engel yok")
	item.start_blocker = func(peer_id: int) -> bool: return peer_id == 2
	is_true(item.is_blocked_for(2), "peer'lı engel (US-010; oyun-yz tur 2 #14)")
	is_false(item.is_blocked_for(3))
	item.start_blocker = func() -> bool: return true
	is_true(item.is_blocked_for(3), "0 argümanlı eski biçim (IS-014 kapı) geçerli")


func test_texts_exist_in_both_languages() -> void:
	var file := FileAccess.open("res://i18n/texts.csv", FileAccess.READ)
	if not is_true(file != null, "texts.csv açıldı"):
		return
	var rows: Dictionary = {}
	while not file.eof_reached():
		var cols: PackedStringArray = file.get_csv_line()
		if cols.size() >= 3:
			rows[cols[0]] = cols
	for key: String in TEXT_KEYS:
		if is_true(rows.has(key), "metin anahtarı " + key):
			var cols: PackedStringArray = rows[key]
			is_true(not cols[1].strip_edges().is_empty() and not cols[2].strip_edges().is_empty(), key + " tr+en")
	for kind: StringName in [&"owner_serve", &"owner_talk", &"owner_sent", &"owner_listen", &"owner_again",
			&"owner_phone_found", &"owner_loiter"]:
		has(StoreOwner.EVENT_KINDS, kind, "olay kanalı " + kind)
		has(NpcVisual.BALLOON_KEYS, kind, "balon " + kind)


# --- BUY ---

func test_buy_serves_player_resets_suspicion_and_pays() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	var events: Array = _events(o)
	var opened: Array[int] = []
	o.brain().register_opened.connect(func(id: int) -> void: opened.append(id))
	stage.player(2, COUNTER_FRONT)
	stage.run(1.0)
	var cash_before: int = Game.team_cash()
	Game.add_team_cash(100 - cash_before)  # team cash 100
	counter.buy_interactable().host_start(2, 1)
	stage.run(1.9)
	o.apply_suspicion(2, 45.0)  # owner is in LOOK: BUY interrupts that too (interrupt API, round 2 #14)
	stage.run(DT)
	eq(o.brain().state(), OwnerBrain.State.LOOK)
	stage.run(0.2)
	eq(counter.purchases, 1, "SATIN AL tamamlandı (2 sn tut)")
	eq(Game.team_cash(), 90, "bedel 10 ekip nakdinden")
	has(events, [&"owner_shrug", 2], "BAK'tan omuz silkip servise")
	has(events, [&"owner_serve", 2])
	has(events, [&"social", 2, &"buy"], "sosyal kanca: SATIN AL")
	eq(o.suspicion().value_of(2), 0.0, "satın alana şüphe 0")
	is_true(o.senses().loiter_time(2) < 0.25, "oyalanma sıfırlandı (%.2f)" % o.senses().loiter_time(2))
	eq(o.agenda().task_name(), &"customer", "MÜŞTERİ servisi (US-016 akışı)")
	stage.run(2.5)
	eq(opened, [-2], "servisin 2. sn'si: register_opened (oyuncu servis kimliği −peer)")
	is_true(counter.buy_interactable().is_blocked_for(2), "servis sürerken ikinci SATIN AL engelli")
	stage.run(4.0)
	eq(o.brain().player_serves, 1)
	eq(o.agenda().task_name(), &"counter", "servis bitti")
	Game.add_team_cash(-Game.team_cash())
	_hold(stage, counter.buy_interactable(), 2, 2.1)
	eq(counter.purchases, 2)
	eq(Game.team_cash(), 0, "nakit yoksa bedava")
	Game.add_team_cash(cash_before - Game.team_cash())
	stage.leave()


func test_buy_while_owner_away_brings_him_to_the_counter() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	stage.player(2, COUNTER_FRONT)
	o.agenda().begin_task(&"restock")
	stage.run(4.0)
	is_true(o.global_position.distance_to(stage.marker(&"ClerkSpot")) > 64.0, "sahip tezgâhtan uzakta")
	_hold(stage, _counter(stage).buy_interactable(), 2, 2.1)
	eq(o.brain().serve_state(-2), OwnerBrain.Serve.PENDING, "sahip tezgâha geliyor")
	var t: Array[float] = [0.0]
	var arrived: Array[float] = [-1.0]
	stage.run(20.0, func() -> void:
		t[0] += DT
		if arrived[0] < 0.0 and o.brain().serve_state(-2) == OwnerBrain.Serve.ACTIVE:
			arrived[0] = t[0])
	is_true(arrived[0] > 0.0 and arrived[0] <= 20.0, "≤ 20 sn içinde gelip servis etti (%.1f sn)" % arrived[0])
	stage.leave()


# --- SEND TO BACK ROOM ---

func test_send_to_backroom_once_per_heist_with_register_window() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	var events: Array = _events(o)
	stage.player(2, COUNTER_FRONT)
	stage.run(1.0)
	_hold(stage, counter.send_interactable(), 2, 2.1)
	is_true(counter.sent_used, "GÖNDER kullanıldı")
	has(events, [&"owner_sent", 2])
	has(events, [&"social", 2, &"send"], "sosyal kanca: GÖNDER")
	eq(o.agenda().task_name(), &"sent")
	await tree().physics_frame
	is_false(counter.send_interactable().enabled, "Q satırı gizli (iş başına 1)")
	is_true(counter.buy_interactable().enabled, "E satırı durur")
	for i: int in roundi(40.0 / DT):
		stage.run(DT)
		if not o.brain().sent_windows.is_empty():
			break
	if is_true(o.brain().sent_windows.size() == 1, "tezgâha döndü"):
		var sent_sec: float = o.brain().owner_tuning.sent_sec  # IS-100 (KR-032): 7 s search + walking
		is_true(o.brain().sent_windows[0] >= sent_sec, "kasa penceresi ≥ %.0f sn (%.1f)" % [sent_sec, o.brain().sent_windows[0]])
	is_false((stage.level.props_root().get_node(^"BackroomDoor") as Door).is_open, "D arkasından kapandı")
	var item: Interactable = counter.send_interactable()
	item.host_start(2, 2)
	stage.run(2.1)
	eq(o.agenda().sequence.count(&"sent"), 1, "ikinci GÖNDER işlemez")
	stage.leave()


func test_shout_hides_counter_and_talk_prompts() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var counter: ShopCounter = _counter(stage)
	stage.player(2, COUNTER_FRONT)
	stage.run(0.5)
	await tree().physics_frame
	is_true(counter.buy_interactable().enabled and counter.send_interactable().enabled, "iki satır görünür")
	is_true(o.talk_interactable().enabled, "OYALA açık")
	o.brain().shout(2, false)
	stage.run(DT)
	await tree().physics_frame
	is_true(o.has_shouted(), "bağırdı (çoğaltılan)")
	is_false(counter.buy_interactable().enabled, "bağırınca SATIN AL gizli")
	is_false(counter.send_interactable().enabled, "bağırınca GÖNDER gizli")
	is_false(o.talk_interactable().enabled, "bağırınca OYALA kapalı")
	is_false(o.can_serve_player(2), "host da reddeder")
	stage.leave()


# --- LOITER ---

func test_talk_locks_gaze_on_talker_and_loiter_threshold() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	stage.player(2, TALK_SPOT)
	stage.run(1.0)
	var talk: Interactable = o.talk_interactable()
	is_true(talk.can_start(2, REGISTER_FRONT), "kasa önünde (sahibe 64 px) OYALA")
	is_true(talk.can_start(2, TALK_SPOT))
	var loiter: Array[float] = [10.0]
	o.senses().loiter_query = func(_peer_id: int) -> float: return loiter[0]
	talk.host_start(2, 1)
	stage.run(1.5)
	eq(o.agenda().task_name(), &"talk", "KONUŞ kesmesi")
	has(events, [&"owner_talk", 2])
	eq(events.count([&"social", 2, &"talk"]), 1, "sosyal kanca: OYALA (konuşma başına bir)")
	var to_player: Vector2 = (TALK_SPOT - o.global_position).normalized()
	is_true(o.perception().facing.dot(to_player) > 0.97, "bakış konuşana kilitli (%s)" % o.perception().facing)
	is_true(o.perception().facing.dot(Vector2.LEFT) < 0.95, "tezgâh yönünden (batı) döndü")
	var door: Vector2 = (stage.level.props_root().get_node(^"BackroomDoor") as Node2D).global_position
	is_true(o.perception().facing.dot((door - o.global_position).normalized()) < 0.0, "D arkada")
	eq(o.senses().interaction_of(2), CivilianRules.Interaction.NONE, "konuşma kurcalama sayılmaz (masum)")
	loiter[0] = 61.0
	stage.run(0.5)
	has(events, [&"owner_loiter", 2], "oyalanma eşiği: bu adam ne istiyor")
	eq(events.count([&"owner_loiter", 2]), 1, "bir kez")
	# On release the agenda continues.
	talk.host_abort()
	stage.run(0.5)
	eq(o.agenda().task_name(), &"counter", "konuşma bitti, tezgâh")
	# When the time runs out the conversation ends by itself.
	loiter[0] = 0.0
	talk.host_start(2, 2)
	stage.run(StoreToolsTuning.load_default().talk_max_sec + 0.5)
	eq(talk.busy_by, 0, "en uzun konuşma süresi")
	eq(o.agenda().task_name(), &"counter")
	stage.leave()


func test_talk_needs_calm_agenda_and_yields_to_service() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	stage.player(2, REGISTER_FRONT)
	stage.player(3, COUNTER_FRONT)
	stage.run(1.0)
	var talk: Interactable = o.talk_interactable()
	talk.host_start(2, 1)
	stage.run(0.5)
	eq(o.brain().talking_to(), 2)
	_hold(stage, _counter(stage).buy_interactable(), 3, 2.1)
	eq(o.agenda().task_name(), &"customer", "satın alma (MÜŞTERİ) konuşmayı keser")
	eq(talk.busy_by, 0, "konuşma bırakıldı")
	is_false(talk.enabled, "servis sırasında OYALA kapalı")
	stage.leave()


# --- DISTRACT ---

func test_topple_heard_from_clerk_spot_not_from_backroom_or_phone() -> void:
	for index: int in [1, 2, 3]:
		var stage := NpcStage.new(self)
		await stage.enter()
		var o: StoreOwner = stage.owner()
		var shelf: ShelfProp = _shelf(stage, index)
		stage.player(2, shelf.global_position + Vector2(32, 0))
		stage.run(1.0)
		eq(o.global_position.distance_to(stage.marker(&"ClerkSpot")) < 8.0, true, "sahip tezgâhta")
		var events: Array = _events(o)
		_hold(stage, shelf.get_node(^"Topple") as Interactable, 2, DT)
		is_true(shelf.toppled, "ShelfProp%d devrildi" % index)
		var listen_at: Array[float] = [-1.0]
		var t: Array[float] = [0.0]
		stage.run(1.0, func() -> void:
			t[0] += DT
			if listen_at[0] < 0.0 and o.agenda().task_name() == &"listen":
				listen_at[0] = t[0])
		is_true(listen_at[0] >= 0.0 and listen_at[0] <= 1.0, "ShelfProp%d: ClerkSpot'tan ≤ 1 sn DİNLE" % index)
		has(events, [&"owner_listen", 0])
		stage.run(2.0)
		var to_prop: Vector2 = (shelf.global_position - o.global_position).normalized()
		is_true(o.perception().facing.dot(to_prop) > 0.5 or o.global_position.distance_to(shelf.global_position) < 200.0,
			"ShelfProp%d: sese yöneldi" % index)
		is_false((shelf.get_node(^"Topple") as Interactable).enabled, "tek kullanımlık")
		stage.leave()
	for spot: StringName in [&"backroom", &"phone"]:
		var stage := NpcStage.new(self)
		await stage.enter()
		var o: StoreOwner = stage.owner()
		o.agenda().begin_task(spot)
		for i: int in roundi(15.0 / DT):
			stage.run(DT)
			if o.agenda().has_arrived():
				break
		is_true(o.agenda().has_arrived(), "%s noktasına vardı" % spot)
		var tools: StoreToolsTuning = StoreToolsTuning.load_default()
		for index: int in [1, 2, 3]:
			var at: Vector2 = _shelf(stage, index).global_position
			NoiseBus.emit_noise(at, tools.topple_radius, StoreToolsTuning.KIND_TOPPLE, 2)
		stage.run(DT)
		eq(o.agenda().task_name(), spot, "%s: raf devirme duyulmaz" % spot)
		stage.leave()


func test_phone_rings_lures_owner_and_second_distraction_costs_suspicion() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = _events(o)
	var tools: StoreToolsTuning = StoreToolsTuning.load_default()
	var s1: ShelfProp = _shelf(stage, 1)
	var s2: ShelfProp = _shelf(stage, 2)
	var s3: ShelfProp = _shelf(stage, 3)
	var shelves: Array[ShelfProp] = [s1, s2, s3]
	stage.player(2, s1.global_position + Vector2(32, 0))
	stage.player(3, s2.global_position + Vector2(32, 0))
	stage.run(1.0)
	var step_shelves := func() -> void:
		for s: ShelfProp in shelves:
			s.step(DT)
	# Drop the phone (Q, 0.5 s): one per job.
	_hold(stage, s2.get_node(^"Phone") as Interactable, 3, 0.6)
	eq(s2.phone_state, CivilianRules.Phone.PLANTED)
	stage.run(DT, step_shelves)
	is_false((s3.get_node(^"Phone") as Interactable).enabled, "ikinci telefon yok (iş başına 1)")
	# Knocking over a shelf (1st distraction): the owner walks to the sound.
	_hold(stage, s1.get_node(^"Topple") as Interactable, 2, DT)
	eq(o.agenda().task_name(), &"listen")
	eq(o.brain().distractions.count, 1)
	var peak3: Array[float] = [0.0]
	var rang: Array[float] = [-1.0]
	var t: Array[float] = [0.0]
	stage.run(4.0, func() -> void:
		step_shelves.call()
		t[0] += DT
		peak3[0] = maxf(peak3[0], o.suspicion().value_of(3))
		if rang[0] < 0.0 and s2.is_ringing():
			rang[0] = t[0])
	near(rang[0], tools.phone_delay_sec, 0.1, "bırakıldıktan 3 sn sonra çalar")
	eq(o.brain().distractions.count, 2, "telefon ikinci dikkat dağıtma")
	has(events, [&"owner_again", 3], "yine mi?")
	has(events, [&"social", 2, &"distract"], "sosyal kanca: raf devirme (c2)")
	has(events, [&"social", 3, &"distract"], "sosyal kanca: telefon (sorumlu)")
	is_true(peak3[0] >= tools.again_suspicion - 1.0, "telefonu bırakana +30 (en yüksek %.1f)" % peak3[0])
	eq(o.brain().state(), OwnerBrain.State.AGENDA, "\"yine mi?\" şüphesi dinlemeyi bölmez (< 60)")
	stage.run(10.0, step_shelves)
	eq(s2.phone_state, CivilianRules.Phone.FOUND, "sahip telefonu buldu")
	has(events, [&"owner_phone_found", 0])
	eq(o.brain().phones_found, 1)
	eq(o.brain().distractions.count, 2, "çalmayı sürdüren telefon tek dikkat dağıtma")
	stage.leave()


# --- prompt lines and loitering ---

func test_two_prompt_lines_pick_targets_per_input_action() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	stage.run(1.0)
	var pi: PlayerInteraction = autofree(PlayerInteraction.new()) as PlayerInteraction
	stage.level.add_child(pi)
	var lines: Array = []
	pi.target_changed.connect(func(key: String) -> void: lines.append(["E", key]))
	pi.alt_target_changed.connect(func(key: String) -> void: lines.append(["Q", key]))
	pi.tick(DT, false, COUNTER_FRONT, 2)
	eq(pi.target_key(), "INTERACT_COUNTER_BUY", "tezgâh önü: E = SATIN AL")
	eq(pi.alt_target_key(), "INTERACT_COUNTER_SEND", "tezgâh önü: Q = GÖNDER")
	pi.tick(DT, false, REGISTER_FRONT, 2)
	eq(pi.target_key(), "INTERACT_OWNER_TALK", "kasa önü: E = OYALA")
	eq(pi.alt_target_key(), "INTERACT_COUNTER_SEND")
	var send: Interactable = _counter(stage).send_interactable()
	var talk: Interactable = stage.owner().talk_interactable()
	var before: int = int(send.stats()["requests"])
	var talk_before: int = int(talk.stats()["requests"])
	pi.tick(DT, false, REGISTER_FRONT, 2, {}, true)
	eq(int(send.stats()["requests"]), before + 1, "Q isteği GÖNDER'e gitti")
	eq(int(talk.stats()["requests"]), talk_before, "E hedefine (OYALA) istek yok")
	pi.tick(DT, false, REGISTER_FRONT, 2, {}, false)
	pi.tick(DT, true, REGISTER_FRONT, 2, {}, false)
	eq(int(talk.stats()["requests"]), talk_before + 1, "E isteği OYALA'ya gitti")
	eq(int(send.stats()["requests"]), before + 1)
	pi.tick(DT, false, REGISTER_FRONT, 2, {}, false)
	pi.tick(DT, false, STREET, 2)
	eq(pi.target_key(), "")
	eq(pi.alt_target_key(), "")
	has(lines, ["Q", ""])
	stage.level.remove_child(pi)
	stage.leave()


func test_loiter_resets_on_leaving_the_shop_and_is_dumped() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var p: Player = stage.player(2, Vector2(400, 400))
	stage.run(3.0)
	near(o.senses().loiter_time(2), 3.0, 0.05, "dükkân içinde birikir")
	var dumped: Dictionary = o.dump_state()["loiter_s"]
	near(float(dumped.get("2", -1.0)), 3.0, 0.11, "döküm loiter_s")
	p.global_position = STREET
	stage.run(DT)
	eq(o.senses().loiter_time(2), 0.0, "dükkândan çıkınca sıfır")
	stage.leave()
