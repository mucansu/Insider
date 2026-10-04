extends TestCase
## US-008 AC7 (+ ON-03, I3): owner HOLD (28 px + 0.5 s contact) -> player held (freezes, input cut, 6 s window) -> caught when the
## window ends; PULL (teammate within 32 px for 1 s, Interactable) -> both freed, owner STAGGERS exactly 2 s, rescuer gets suspicion 100;
## if the same player is held a second time the window is 3 s. ON-03: in the contact decision the player position is advanced along
## its velocity by min(RTT/2, 0.1 s) (in the fleeing player's favour); a variant that does not advance holds at the boundary (fails).
## Single process = host; NpcStage fixed step.

const DT := 1.0 / 60.0
const STAFF_FRONT := Vector2(560, 400)
const PLAYER_SCENE := "res://entities/player/player.tscn"


func _hold_target(stage: NpcStage) -> Player:
	var p: Player = stage.player(2, STAFF_FRONT)
	for i: int in roundi(6.0 / DT):
		stage.run(DT)
		if p.is_held():
			break
	return p


func test_hold_window_then_caught() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var p: Player = _hold_target(stage)
	if not is_true(p.is_held(), "sahip tuttu"):
		stage.leave()
		return
	eq(o.brain().state(), OwnerBrain.State.HOLD)
	eq(o.brain().held_peer(), 2)
	near(p.hold_left(), 6.0, DT + 0.001, "ilk tutma penceresi 6 sn")
	is_true((stage.level.players_root().get_node(^"2/Status/Rescue") as Interactable).enabled, "ÇEK yalnız tutulunca etkin")
	stage.run(5.9)
	is_true(p.is_held(), "pencere sürüyor")
	stage.run(0.2)
	is_true(p.is_caught(), "pencere dolunca yakalandı (kalıcı)")
	is_false((stage.level.players_root().get_node(^"2/Status/Rescue") as Interactable).enabled, "yakalanana ÇEK yok")
	stage.run(0.1)
	is_true(o.brain().state() in [OwnerBrain.State.CHASE, OwnerBrain.State.SEARCH], "sahip tutmayı bırakır")
	stage.leave()


func test_rescue_frees_staggers_and_second_hold_is_short() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var events: Array = []
	o.owner_stagger.connect(func(peer_id: int) -> void: events.append([&"owner_stagger", peer_id]))
	var p: Player = _hold_target(stage)
	if not is_true(p.is_held(), "sahip tuttu"):
		stage.leave()
		return
	var rescuer: Player = stage.player(3, p.position + Vector2(-24, 8))
	var rescue: Interactable = stage.level.players_root().get_node(^"2/Status/Rescue") as Interactable
	rescue.host_start(3, 1)
	eq(rescue.busy_by, 3, "ekip arkadaşı 32 px içinde ÇEK başlatır")
	stage.run(0.9)
	is_true(p.is_held(), "1 sn dolmadan serbest değil")
	stage.run(0.15)
	is_true(p.is_free(), "ÇEK: serbest")
	is_true(rescuer.is_free())
	eq(o.brain().state(), OwnerBrain.State.STAGGER)
	eq(events, [[&"owner_stagger", 3]])
	eq(o.suspicion().value_of(3), 100.0, "kurtarana şüphe 100")
	eq(o.brain().rescues.size(), 1)
	rescuer.position = Vector2(656, 176)
	var stagger: float = o.brain().fsm.time_in_state  # the rescue happened mid-step
	for i: int in roundi(3.0 / DT):
		stage.run(DT)
		if o.brain().state() != OwnerBrain.State.STAGGER:
			break
		stagger += DT
	near(stagger, 2.0, DT + 0.001, "I3: SENDELE tam 2 sn (±1 kare)")
	# The same player a second time: window 3 s.
	for i: int in roundi(4.0 / DT):
		stage.run(DT)
		if p.is_held() or rescuer.is_held():
			break
	if is_true(p.is_held(), "ikinci tutma (süren hedef önceliklidir)"):
		near(p.hold_left(), 3.0, DT + 0.001, "aynı oyuncu ikinci kez: 3 sn")
		eq(p.times_held(), 2)
	stage.leave()


## ON-03: a fleeing player (host-seen position at the contact boundary, velocity away from the owner) advanced by RTT/2 is not
## held; the non-advancing (faulty) variant holds in the same situation.
func test_lead_prediction_favours_fleeing_player() -> void:
	for case: Array in [[150, false], [0, true]]:
		var stage := NpcStage.new(self)
		await stage.enter()
		var o: StoreOwner = stage.owner()
		o.senses().rtt_override_ms = int(case[0])
		var p: Player = stage.player(2, STAFF_FRONT)
		for i: int in roundi(2.5 / DT):
			stage.run(DT)
			if o.brain().state() == OwnerBrain.State.CHASE:
				break
		if not is_true(o.brain().state() == OwnerBrain.State.CHASE, "kovalama başladı"):
			stage.leave()
			continue
		# Host-seen position: 24 px from the owner (inside contact), the player moves away at 140 px/s but sync lags.
		var away: Vector2 = (STAFF_FRONT - o.global_position).normalized()
		var held: bool = false
		for i: int in roundi(1.0 / DT):
			p.position = o.global_position + away * 24.0
			p.velocity = away * 140.0
			stage.run(DT)
			held = held or p.is_held()
		eq(held, bool(case[1]), "RTT %d ms: %s" % [case[0], "tutar (ileri alma yok)" if case[1] else "ileri alınan konum 28 px dışı"])
		stage.leave()


## A held local player freezes: movement and interaction input are cut; walks again once freed.
func test_held_local_player_freezes() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = "1"
	player.position = Vector2(100, 100)
	tree().root.add_child(player)
	autofree(player)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "interact", "dur": 5.0}]))
	var states: Array[int] = []
	player.status_changed.connect(func(s: int) -> void: states.append(s))
	for i: int in 10:
		await tree().physics_frame
	is_true(player.position.x > 101.0, "serbestken yürür")
	is_true(player.host_hold(6.0))
	var frozen_at: Vector2 = player.position
	for i: int in 10:
		await tree().physics_frame
	near(player.position, frozen_at, 0.01, "tutulunca donar")
	eq(player.velocity, Vector2.ZERO)
	is_true(player.host_release())
	for i: int in 10:
		await tree().physics_frame
	is_true(player.position.x > frozen_at.x + 1.0, "serbest kalınca yeniden yürür")
	eq(states, [PlayerStatus.State.HELD, PlayerStatus.State.FREE] as Array[int])
	eq(player.motion_state()["status"], PlayerStatus.State.FREE, "dökümde durum")
	is_true(player.host_catch())
	is_false(player.host_hold(3.0), "yakalanan yeniden tutulmaz")
	is_false(player.host_release(), "yakalama kalıcı")
