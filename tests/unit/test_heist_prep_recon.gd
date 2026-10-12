extends TestCase
## US-053 recon cost in prep (KR-046, GB-14): in the job's prep the owner's suspicion fills and drains as in the job; a detection there
## is a recognition, not an alarm (no shout/hold/question/chase, alert 0, `recognized` +1 once per prep, "?" balloon
## `owner_noticed_prep`, gaze held until the player leaves the shop); once the job starts the owner's first sight of that player starts
## at the prep head start (30, US-052 path). Shopping (shelf take, counter pay) stays open in prep; other job interactions stay locked.
## HUD: only that player's toast; the end screen's recognition line counts it. Rules + single-process host (store_a, --heist-prep).
## Multi-process: tests/net/heist_prep_recon.json.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
## Staff side next to the register, inside the owner's cone, near band (test_heist_phase.gd STAFF).
const STAFF := Vector2(588, 368)
## Customer side of the counter (test_shop.gd COUNTER_FRONT).
const COUNTER_FRONT := Vector2(528, 336)
## AC1: detection in the staff zone near band within this many seconds.
const DETECT_MAX_S := 2.0

var _previous_scene: PackedScene = null
var _previous_prep: bool = false


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _start() -> Player:
	_previous_scene = Game.player_scene
	_previous_prep = Args.heist_prep
	Args.heist_prep = true
	Game.player_scene = load(PLAYER) as PackedScene
	if not eq(Net.host(free_udp_port()), OK):
		return null
	Game.start_level(STORE)
	return Game.local_player() as Player


func _stop() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = _previous_scene
	Args.heist_prep = _previous_prep


func _frames(n: int = 3) -> void:
	for i: int in n:
		await tree().physics_frame


func _owner() -> StoreOwner:
	return Game.current_level().get_node_or_null(^"NPCs/Owner") as StoreOwner


func _van() -> Vector2:
	return (Game.current_level().get_node(^"HeistStart") as Node2D).global_position


func _events_of(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in Game.collect_dump()["events"] as Array:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


func _heist_dump() -> Dictionary:
	return Game.call(&"_heist_dump") as Dictionary


func _owner_kinds(o: StoreOwner) -> Array[StringName]:
	return o.events()


## Moves the local player to STAFF and waits until the owner's meter reaches DETECT (max 3 s); returns the seconds it took (-1 none).
func _detect_at_staff(me: Player, o: StoreOwner) -> float:
	me.position = STAFF
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < 3.0:
		await tree().physics_frame
		t += dt
		if o.suspicion().level_of(1) >= Suspicion.Level.DETECT:
			return t
	return -1.0


## Waits (max `seconds`) until the owner has no meter for the local player.
func _drain(o: StoreOwner, seconds: float = 12.0) -> void:
	var frames: int = roundi(seconds * float(Engine.physics_ticks_per_second))
	for i: int in frames:
		await tree().physics_frame
		if o.suspicion().value_of(1) <= 0.0:
			return


# --- rules ---

func test_rules_prep_shopping_items_open() -> void:
	is_false(HeistRules.prep_locks(&"Counter", &"HeistStart", &"Buy"), "tezgâh öde/al açık")
	is_true(HeistRules.prep_locks(&"Counter", &"HeistStart", &"Send"), "damacana iste kilitli")
	is_true(HeistRules.prep_locks(&"Counter", &"HeistStart", &"Pickup"), "damacana al kilitli")
	is_true(HeistRules.prep_locks(&"Counter", &"HeistStart"), "bileşen adı yok: tezgâh kilitli")
	is_false(HeistRules.prep_locks(&"ShopItem1", &"HeistStart", &"Take"), "raf ürünü al açık")
	is_false(HeistRules.prep_locks(&"ShopItem2", &"HeistStart", &"Take"))
	is_true(HeistRules.prep_locks(&"ShopItem1", &"HeistStart", &"Other"), "raf noktasının başka bileşeni kilitli")
	is_true(HeistRules.prep_locks(&"Register", &"HeistStart", &"Interactable"), "kasa kilitli")
	is_true(HeistRules.prep_locks(&"Bag", &"HeistStart", &"Take"), "çanta kilitli (raf öneki yok)")
	is_true(HeistRules.prep_locks(&"BackDoor", &"HeistStart", &"Interactable"), "arka kapı kilitli")
	is_false(HeistRules.prep_locks(&"FrontDoor", &"HeistStart", &"Interactable"), "müşteri kapısı açık")


func test_rules_tracker_prep_recognition_once_and_in_result() -> void:
	var tr_: HeistRules.Tracker = HeistRules.Tracker.new()
	is_true(tr_.note_prep_recognized(2, 5.123), "ilk tanınma")
	is_false(tr_.note_prep_recognized(2, 9.0), "hazırlıkta en çok 1 kez")
	is_false(tr_.note_prep_recognized(0, 1.0), "geçersiz peer")
	eq(tr_.prep_recognized.keys(), [2])
	near(float(tr_.prep_recognized[2]), 5.12, 0.001, "anı (seviye saati, 0,01)")
	tr_.note_recognized(2)  # US-044 window questioning in the job: separate source
	var roster: Dictionary = {1: {"name": "A", "slot": 0}, 2: {"name": "B", "slot": 1}}
	var result: Dictionary = tr_.build_result(HeistRules.DECISION_WIN, {}, roster)
	var players: Dictionary = result["players"] as Dictionary
	eq(int((players["2"] as Dictionary)["recognized"]), 2, "hazırlık + iş içi ayrı sayılır")
	eq(int((players["1"] as Dictionary)["recognized"]), 0)


func test_rules_prep_head_start_tuning() -> void:
	var t: HeatTuning = load(HeatTuning.PATH) as HeatTuning
	eq(t.prep_recognized_start, 30.0, "hazırlık tanınma başlangıcı (ayar) 30")
	var p: SessionHeat.Params = t.rules_params()
	eq(SessionHeat.prep_recognition_start(p), 30.0)
	eq(SessionHeat.prep_recognition_start(SessionHeat.Params.new()), 0.0, "varsayılan nötr")
	eq(SessionHeat.prep_recognition_start(null), 0.0)
	var r: OwnerRecognition = OwnerRecognition.from_state({"recognized": {}}, p)
	eq(r.prep_start, 30.0)
	r.add_prep(3)
	eq(r.start_of(3), 30.0, "hazırlıkta tanınan: işe 30'dan")
	r.starts[4] = 50.0
	r.add_prep(4)
	eq(r.start_of(4), 50.0, "daha büyük oturum başlangıcı düşmez")
	r.mark(5, 1.0, 10.0)
	r.add_prep(5)
	eq(r.start_of(5), 0.0, "bu işte selamlanmış oyuncuya eklenmez")
	var off: OwnerRecognition = OwnerRecognition.from_state({}, SessionHeat.Params.new())
	off.add_prep(3)
	is_true(off.starts.is_empty(), "ayar 0: başlangıç yok")


func test_rules_prep_indicator_stays_question() -> void:
	eq(HeistRules.prep_indicator_meter(100.0, 100.0, true), 99.0, "hazırlıkta '!' yok")
	eq(HeistRules.prep_indicator_meter(40.0, 100.0, true), 40.0)
	eq(HeistRules.prep_indicator_meter(100.0, 100.0, false), 100.0, "iş sürerken değişmez")
	var rules := CivilianRules.Params.new()
	rules.notice_at = 30.0
	rules.detect_at = 100.0
	eq(CivilianRules.bubble(rules, HeistRules.prep_indicator_meter(100.0, 100.0, true), false, CivilianRules.Bubble.NONE),
		CivilianRules.Bubble.NOTICE)


# --- Game (host, single process): AC1-AC3, AC5 ---

func test_prep_detection_is_recognition_not_alarm() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	var o: StoreOwner = _owner()
	if not is_true(Game.heist_in_prep() and o != null, "hazırlık + sahip"):
		await _stop()
		return
	# AC1: staff zone, near band: detection within 2 s (the prep gate is gone; same multipliers).
	var took: float = await _detect_at_staff(me, o)
	is_true(took > 0.0 and took <= DETECT_MAX_S, "personel bölgesinde <= 2 sn'de tespit (%.2f sn)" % took)
	await _frames(30)
	# AC2: recognition, no alarm.
	var brain: OwnerBrain = o.brain()
	is_false(brain.is_alarmed(), "sahip alarmda değil")
	is_false(brain.has_shouted, "bağırmadı")
	eq(brain.held_peer(), 0, "tutmadı")
	eq(brain.state(), OwnerBrain.State.LOOK, "bakıyor (soru/kovalama yok)")
	eq(brain.prep_watch_peer(), 1, "bakışı oyuncuda")
	eq(brain.suspicion.latch_level, Suspicion.Level.CALM, "tavanda kilit yok")
	var kinds: Array[StringName] = _owner_kinds(o)
	has(kinds, HeistRules.PREP_NOTICED_EVENT, "'?' balonu olayı")
	for bad: StringName in [&"owner_shout", &"owner_held"]:
		is_false(kinds.has(bad), "sahip olaylarında %s yok" % bad)
	# INVESTIGATE before the detection may question (costs nothing); after the detection no new question.
	var questions: int = kinds.count(&"owner_question")
	eq(o.bubble, CivilianRules.Bubble.NOTICE, "gösterge '?' (hazırlıkta '!' yok)")
	eq(Game.alert_level(), 0, "uyarı 0")
	var alert: StoreAlert = Game.current_level().get_node_or_null(^"NPCs/StoreAlert") as StoreAlert
	if alert != null:
		eq(alert.level(), 0, "dükkân uyarı merdiveni 0")
	var recorded: Dictionary = _heist_dump()["prep_recognized"] as Dictionary
	eq(recorded.keys(), ["1"], "tanınma kaydı (hazırlıkta, BAŞLA'dan önce)")
	is_true(float(recorded.get("1", -1.0)) > 0.0, "kayıt anı seviye saati")
	eq(_events_of("prep_recognized").size(), 1, "oyuncuya olay")
	eq(int(_events_of("prep_recognized")[0]["data"]["peer"]), 1)
	eq(brain.recognition.start_of(1), 30.0, "işe 30'dan başlayacak")
	eq(Game.cover_state(), 1, "hazırlıkta örtü izlenmez")
	# Still in the staff zone: no second recognition.
	await _frames(60)
	eq(_events_of("prep_recognized").size(), 1, "aynı oyuncu en çok 1 kez")
	eq(brain.prep_detections.size(), 1)
	# Leaves the shop: watch ends, the meter drains outside (no latch).
	me.global_position = _van()
	await _frames(10)
	eq(brain.prep_watch_peer(), 0, "dükkândan çıktı: bakış bırakıldı")
	is_false(brain.state() == OwnerBrain.State.QUESTION, "soruya yürümez")
	await _drain(o)
	eq(o.suspicion().value_of(1), 0.0, "dışarıda söner")
	# Back in the staff zone: detected again, watched again, still recognised once.
	took = await _detect_at_staff(me, o)
	is_true(took > 0.0, "yeniden tespit")
	await _frames(10)
	eq(brain.prep_watch_peer(), 1, "yeniden bakış")
	eq(_events_of("prep_recognized").size(), 1, "ikinci tanınma yok")
	eq((_heist_dump()["prep_recognized"] as Dictionary).size(), 1)
	is_false(brain.is_alarmed())
	eq(Game.alert_level(), 0)
	eq(_owner_kinds(o).count(&"owner_question"), questions, "tespitten sonra soru yok")
	is_false(_owner_kinds(o).has(&"owner_shout"))
	await _stop()


func test_prep_recognition_head_start_after_start() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	var o: StoreOwner = _owner()
	var took: float = await _detect_at_staff(me, o)
	if not is_true(took > 0.0, "hazırlıkta tespit"):
		await _stop()
		return
	me.global_position = _van()
	await _drain(o)
	eq(o.suspicion().value_of(1), 0.0, "başlamadan önce sönmüş")
	is_true(Game.request_heist_start(), "host BAŞLA")
	await _frames()
	is_false(Game.heist_in_prep())
	me.position = COUNTER_FRONT
	var greets: Array[Dictionary] = o.brain().recognition.greets
	for i: int in 600:
		await tree().physics_frame
		if not greets.is_empty():
			break
	if is_true(greets.size() == 1, "AC3: ilk görüşte tanıdı"):
		eq(int(greets[0]["peer"]), 1)
		is_true(float(greets[0]["value"]) >= 30.0, "şüphe >= 30 (%s)" % greets[0]["value"])
	has(_owner_kinds(o), OwnerRecognition.EVENT, "'Sen yine mi?' balonu (US-052 yolu)")
	await _stop()


func test_prep_shopping_open_job_interactions_locked() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	var counter: ShopCounter = (Game.current_level() as Level).props_root().get_node_or_null(^"Counter") as ShopCounter
	if not is_true(counter != null and counter.items().size() >= 1, "tezgâh + raf noktaları"):
		await _stop()
		return
	var bread: ShopItemPoint = counter.items()[0]
	is_false(Game.heist_prep_locks(bread.take_interactable()), "raf ürünü hazırlıkta açık")
	is_false(Game.heist_prep_locks(counter.buy_interactable()), "tezgâhta öde hazırlıkta açık")
	is_true(Game.heist_prep_locks(counter.send_interactable()), "damacana iste kilitli")
	for path: String in ["Props/Register/Interactable", "Props/BackDoor/Interactable", "Props/BackroomDoor/Interactable"]:
		var item: Interactable = Game.current_level().get_node_or_null(NodePath(path)) as Interactable
		if is_true(item != null, path):
			is_true(Game.heist_prep_locks(item), "%s kilitli" % path)
	for bag: Node in tree().get_nodes_in_group(HeistRules.BAG_GROUP):
		for child: Node in bag.get_children():
			if child is Interactable:
				is_true(Game.heist_prep_locks(child), "çanta kilitli")
	# Take bread (resets loiter, KR-038 rule unchanged), then pay at the counter.
	var cash_before: int = Game.team_cash()
	Game.add_team_cash(50 - cash_before)
	me.position = bread.global_position + Vector2(0, 4)
	await _frames(120)
	var senses: CivilianSenses = _owner().senses()
	is_true(senses.loiter_time(1) > 1.0, "oyalanma birikti (%.2f)" % senses.loiter_time(1))
	bread.take_interactable().host_start(1, 1)
	await _frames(40)
	eq(me.hand().item, &"bread", "hazırlıkta ekmek alındı")
	is_true(senses.loiter_time(1) < 0.8, "ekmek oyalanmayı sıfırladı (%.2f)" % senses.loiter_time(1))
	me.position = COUNTER_FRONT
	await _frames(12)
	counter.buy_interactable().host_start(1, 2)
	for i: int in 240:
		await tree().physics_frame
		if me.hand().paid:
			break
	is_true(me.hand().paid, "hazırlıkta tezgâhta ödendi")
	eq(Game.team_cash(), 45, "ekip nakdinden 5")
	Game.add_team_cash(cash_before - Game.team_cash())
	await _stop()


# --- HUD / end screen (fakes): AC4 ---

func _hud(local_peer: int) -> Array:
	var pair: Array = Fakes.make_pair(self)
	var net: Fakes.FakeNet = pair[0]
	var game: Fakes.FakeGame = pair[1]
	net.my_peer_id = local_peer
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.net = net
	hud.game = game
	hud.menu_override = func(_error_key: StringName) -> void: pass
	viewport.add_child(hud)
	await tree().process_frame
	return [hud, game, net]


func _toast_texts(hud: Hud) -> Array[String]:
	var out: Array[String] = []
	for panel: Node in hud.get_node("%Toasts").get_children():
		out.append((panel.get_child(0) as Label).text)
	return out


func test_hud_prep_recognition_only_on_own_screen() -> void:
	has(Hud.SELF_ONLY_EVENTS, HeistRules.PREP_RECOGNIZED_EVENT, "HUD sabiti çekirdekle aynı değer")
	var parts: Array = await _hud(1)
	var hud: Hud = parts[0]
	var game: Fakes.FakeGame = parts[1]
	game.session_event.emit(&"prep_recognized", {"peer": 2})
	eq(_toast_texts(hud), [] as Array[String], "başkasının tanınması: bildirim yok")
	game.session_event.emit(&"prep_recognized", {"peer": 1})
	eq(_toast_texts(hud), [tr("EVENT_PREP_RECOGNIZED")] as Array[String], "yalnız kendi ekranında")
	is_true(tr("EVENT_PREP_RECOGNIZED") != "EVENT_PREP_RECOGNIZED", "metin var")
	eq(Hud.TOAST_SECONDS, 4.0, "4 sn")
	hud.advance(4.1)
	eq(_toast_texts(hud), [] as Array[String], "4 sn sonra gider")


func test_end_screen_recognition_line_counts_prep() -> void:
	var parts: Array = await _hud(1)
	var hud: Hud = parts[0]
	var game: Fakes.FakeGame = parts[1]
	var result: Dictionary = {
		"outcome": &"clean", "loot_total": 0, "payout_ratio": 1.0, "payout": 0, "duration_s": 30.0,
		"players": {"1": {"name": "A", "slot": 0, "escaped": true, "caught": false, "loot": 0, "bail": 0,
			"witness_released": false, "recognized": 1, "left": false}},
		"notes": [],
	}
	game.heist_finished.emit(result)
	await tree().process_frame
	var screen: HeistEnd = hud.get_node("%HeistEnd") as HeistEnd
	eq(screen.local_recognized(), 1)
	var cause: Label = screen.get_node("%CauseNote") as Label
	is_true(cause.visible, "tanınma satırı")
	eq(cause.text, tr("END_RECOGNIZED"))
	eq(cause.theme_type_variation, &"MutedLabel")


func test_texts_present() -> void:
	for key: String in ["EVENT_PREP_RECOGNIZED", "OWNER_NOTICED_PREP", "END_RECOGNIZED"]:
		is_true(tr(key) != key, "%s metni" % key)
	eq(NpcVisual.BALLOON_KEYS.get(HeistRules.PREP_NOTICED_EVENT, ""), "OWNER_NOTICED_PREP", "balon anahtarı")
	has(StoreOwner.EVENT_KINDS, HeistRules.PREP_NOTICED_EVENT, "olay kanalı")
	eq(Game.HEIST_EVENT_PREP_RECOGNIZED, HeistRules.PREP_RECOGNIZED_EVENT, "Game olay adı kuralla aynı")