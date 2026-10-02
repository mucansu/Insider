extends TestCase
## US-008 t2 (denetim düzeltmeleri): ÇEK host doğrulaması (B1), tutulan/yakalanan oyuncunun etkileşimi reddedilir
## ve süreni iptal edilir (S1), sorgu yürüyüşü + `owner_shrug` + masumken boşalma 10/sn (S2), `player_caught`
## yakalayanı (S3), NPC kapıyı yalnız açar (kapatmaz, beklemeye uyar). Tek süreç = host; NpcStage sabit adım.

const DT := 1.0 / 60.0
const STAFF_FRONT := Vector2(560, 400)
const REGISTER_STAFF := Vector2(586, 366)
const PLAYER_SCENE := "res://entities/player/player.tscn"
const REGISTER_SCENE := "res://entities/props/register.tscn"
const DOOR_SCENE := "res://entities/props/door.tscn"


## Etkileşim aktörü taklidi (S7: grup + interaction_position; gövdesi yok).
class FakeActor:
	extends Node2D

	func interaction_position() -> Vector2:
		return global_position


static func _rescue_of(stage: NpcStage, peer_id: int) -> Interactable:
	return stage.level.players_root().get_node(NodePath("%d/Status/Rescue" % peer_id)) as Interactable


func test_rescue_is_validated_on_host() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var held: Player = stage.player(2, Vector2(400, 400))
	var caught: Player = stage.player(3, Vector2(410, 410))
	var free: Player = stage.player(4, Vector2(390, 410))
	is_true(held.host_hold(6.0))
	is_true(caught.host_catch(&"chaser"))
	var rescue: Interactable = _rescue_of(stage, 2)
	rescue.host_start(2, 1)
	eq(rescue.busy_by, 0, "tutulan kendi ÇEK'ini başlatamaz")
	rescue.host_start(3, 1)
	eq(rescue.busy_by, 0, "yakalanmış arkadaş çekemez")
	eq(rescue.stats()["rejected"], {"not_free": 2}, "ret host'ta")
	rescue.host_start(4, 1)
	eq(rescue.busy_by, 4, "serbest arkadaş çeker")
	stage.run(1.1)
	is_true(held.is_free(), "kurtarıldı")
	stage.leave()


func test_held_or_caught_player_cannot_interact_and_running_one_is_cancelled() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	stage.owner().active = false  # sahip etkisiz: yalnız etkileşim kuralı ölçülür
	var register: Interactable = stage.level.props_root().get_node(^"Register/Interactable") as Interactable
	var p: Player = stage.player(2, REGISTER_STAFF)
	is_true(p.host_hold(6.0))
	register.host_start(2, 1)
	eq(register.busy_by, 0, "tutulan oyuncunun (sahte) isteği reddedilir")
	is_true(p.host_catch(&"owner"))
	register.host_start(2, 2)
	eq(register.busy_by, 0, "yakalanan da")
	var q: Player = stage.player(3, REGISTER_STAFF + Vector2(0, 6))
	register.host_start(3, 1)
	eq(register.busy_by, 3, "serbest oyuncu başlar")
	is_true(q.host_hold(6.0))
	register.step(DT)
	eq(register.busy_by, 0, "tutulunca süren etkileşim iptal")
	eq(register.stats()["rejected"], {"not_free": 2})
	eq(register.stats()["cancelled"], 1)
	is_false(stage.level.props_root().get_node(^"Register").get(&"emptied"))
	stage.leave()


## Yerel oyuncu tarafı: kasayı tutarken tutulursa girdi kesilir → istemci iptali, busy_by 0, finished(false).
func test_local_hold_cuts_interaction_input() -> void:
	var reg: Node2D = (load(REGISTER_SCENE) as PackedScene).instantiate() as Node2D
	reg.position = Vector2(560, 368)
	tree().root.add_child(reg)
	autofree(reg)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.position = REGISTER_STAFF
	tree().root.add_child(player)
	autofree(player)
	var finished: Array[bool] = []
	player.interaction_finished.connect(func(ok: bool) -> void: finished.append(ok))
	(player.get_node("PlayerInput") as PlayerInput).use_bot(
		BotTimeline.from_raw([{"t": 0.05, "hold": "interact", "dur": 5.0}]))
	var item: Interactable = reg.get_node("Interactable") as Interactable
	for i: int in 20:
		await tree().physics_frame
		if item.busy_by == 1:
			break
	if not is_true(item.busy_by == 1, "kasa tutuluyor"):
		return
	is_true(player.host_hold(6.0))
	for i: int in 3:
		await tree().physics_frame
	eq(item.busy_by, 0, "tutulunca istemci iptal eder (girdi kesik)")
	eq(finished, [false] as Array[bool])
	is_false(player.is_interacting())
	is_false(reg.get(&"emptied"))


## S2: sorgu yürüyüşü (110 px/sn, ~64 px'te durur, `owner_question`), masumken boşalma 10/sn, `owner_shrug`.
func test_question_walk_decay_and_shrug() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	o.global_position = Vector2(450, 300)
	o.perception().facing = Vector2.LEFT
	var p: Player = stage.player(2, Vector2(250, 300))
	var events: Array[StringName] = []
	for kind: StringName in StoreOwner.EVENT_KINDS:
		o.connect(kind, func(_peer: int) -> void: events.append(kind))
	await tree().physics_frame
	o.apply_suspicion(2, 65.0)
	var walk: Array[Vector2] = []
	var values: Array[float] = []
	var asked_at: Array[float] = [-1.0]
	var asked_dist: Array[float] = [-1.0]
	var t: Array[float] = [0.0]
	stage.run(6.0, func() -> void:
		t[0] += DT
		values.append(o.suspicion().value_of(2))
		if o.brain().state() == OwnerBrain.State.QUESTION and asked_at[0] < 0.0:
			walk.append(o.global_position)
		if events.has(&"owner_question") and asked_at[0] < 0.0:
			asked_at[0] = t[0]
			asked_dist[0] = o.global_position.distance_to(p.global_position))
	is_true(walk.size() > 30, "sorguya yürüdü")
	if walk.size() > 30:
		var speed: float = walk[20].distance_to(walk[29]) / (9.0 * DT)
		near(speed, 110.0, 3.0, "sorgu yürüyüşü 110 px/sn")
	near(asked_dist[0], 64.0, 8.0, "64 px'te durur ve sorar")
	eq(events.slice(0, 1), [&"owner_question"] as Array[StringName])
	# Masum (müşteri bölgesi, görünür): 0,2 sn kesinti payından sonra 10/sn.
	var a: float = values[60]
	var b: float = values[120]
	near(a - b, 10.0, 0.5, "görünüp masumken boşalma 10/sn (1 sn'de)")
	stage.run(3.0)
	has(events, &"owner_shrug", "3 sn içinde < 60 → söylenir")
	eq(o.brain().state(), OwnerBrain.State.AGENDA, "ajandaya döner")
	stage.leave()


func test_caught_by_records_catcher() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var p: Player = stage.player(2, STAFF_FRONT)
	for i: int in roundi(10.0 / DT):
		stage.run(DT)
		if p.is_caught():
			break
	is_true(p.is_caught(), "tutma penceresi doldu")
	eq(p.caught_by(), &"owner")
	var q: Player = stage.player(3, Vector2(300, 470))
	is_true(q.host_catch(&"chaser"))
	eq(q.caught_by(), &"chaser")
	stage.leave()


## Çürütme #1: NPC kapıyı yalnız açar; açık kapıya dokunmaz, oyuncunun hemen ardından beklemeye uyar.
func test_npc_only_opens_doors() -> void:
	var door: Door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	door.position = Vector2(368, 464)
	door.is_open = false
	tree().root.add_child(door)
	autofree(door)
	var item: Interactable = door.get_node("Interactable") as Interactable
	is_true(item.host_use_by_npc(Vector2(368, 496)), "kapalı kapıyı açar")
	is_true(door.is_open)
	for i: int in roundi(0.5 / DT):
		item.step(DT)
	item.host_use_by_npc(Vector2(368, 496))
	is_true(door.is_open, "açık kapıya dokunmaz (kapatmaz)")
	# Oyuncu kapatır; NPC hemen ardından (bekleme süresinde) açamaz, sonra açar.
	var closer := FakeActor.new()
	closer.position = Vector2(368, 500)
	closer.set_multiplayer_authority(5)
	closer.add_to_group(Interactable.ACTOR_GROUP)
	tree().root.add_child(closer)
	autofree(closer)
	for i: int in roundi(0.5 / DT):
		item.step(DT)
	item.host_start(5, 1)
	is_false(door.is_open, "oyuncu kapattı")
	is_false(item.host_use_by_npc(Vector2(368, 496)), "beklemede NPC açmaz")
	for i: int in roundi(0.5 / DT):
		item.step(DT)
	is_true(item.host_use_by_npc(Vector2(368, 496)))
	is_true(door.is_open)


## Taşıma (US-012 birleşimi): arka oda nakdi = BackroomCash'teki çanta; taşınınca "alındı" (geç yeniden bağırış).
func test_backroom_bag_taken_is_noticed() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var senses: CivilianSenses = stage.owner().senses()
	var bag: Node2D = stage.level.props_root().get_node_or_null(^"Bag") as Node2D
	if not is_true(bag != null, "store_a Props/Bag"):
		stage.leave()
		return
	is_false(senses.prop_taken_near(&"BackroomCash"), "çanta yerinde")
	bag.set(&"carrier", 2)
	is_true(senses.prop_taken_near(&"BackroomCash"), "çanta taşınıyor: nakit alındı")
	stage.leave()
