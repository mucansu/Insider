extends TestCase
## US-008 AC5/AC6/AC7 (+ ON-08, kapı ekleri): mahalleli (chaser) ve bakkalın uyarı yöneticisi store_a'da.
## Koşan oyuncu açık alanda 10 karoda chaser'dan ≥ 1 karo açar (hız veride 190; 200 düşer). Bağırıştan 8 sn
## sonra NeighbourSpawn'da komşu (`chaser_spawn`), ilk mahalleli kapıya/içeri girince uyarı 3 + 60 sn polis
## sayacı, sayaç bitince 5 + `police_arrived` (I4: 0→1→2→3→5). Mahalleli yakalaması 28 px + 0,5 sn, kalıcı
## (kurtarma yok). Görüş yoksa son görülen konum 15 sn, sonra ön kapıda bekler. NPC kapalı kapıyı Interactable
## host API'siyle açar; kapı bağı kapı durumuna bağlı (kapalı kapıdan yol geçmez); kapı NPC gövdesine kapanmaz.

const DT := 1.0 / 60.0
const TILE := 32.0
const STAFF_FRONT := Vector2(560, 400)
const CHASER_SCENE := "res://entities/npc/chaser/chaser.tscn"
const PLAYER_TUNING := "res://data/player_tuning.tres"
const CHASER_TUNING := "res://data/npc/chaser_tuning.tres"


## Aynı anda duruştan koşmaya başlayan oyuncu (PlayerMotion, koşu kipi) ile chaser: oyuncu 10 karo koşunca aradaki
## mesafenin artışı (px).
static func gap_gain(chaser_speed: float, chaser_accel: float) -> float:
	var tuning: PlayerTuning = load(PLAYER_TUNING) as PlayerTuning
	var player_x: float = 0.0
	var player_v := Vector2.ZERO
	var chaser_x: float = 0.0
	var chaser_v: float = 0.0
	while player_x < 10.0 * TILE:
		player_v = PlayerMotion.step_velocity(player_v, Vector2.RIGHT, PlayerMotion.Mode.SPRINT, tuning, DT)
		player_x += player_v.x * DT
		chaser_v = move_toward(chaser_v, chaser_speed, chaser_accel * DT)
		chaser_x += chaser_v * DT
	return player_x - chaser_x


func test_runner_opens_a_tile_over_ten_tiles() -> void:
	var tuning: ChaserTuning = load(CHASER_TUNING) as ChaserTuning
	var gain: float = gap_gain(tuning.speed, tuning.acceleration)
	is_true(gain >= TILE, "ON-08: 10 karoda ≥ 1 karo açılır (hız %d: %.1f px)" % [tuning.speed, gain])
	is_true(tuning.speed < 220.0, "chaser koşudan yavaş (köşe/kapıda yakalanır)")
	var bad: float = gap_gain(200.0, tuning.acceleration)
	is_true(bad < TILE, "200 px/sn varyantı kabulü tutturamaz (%.1f px)" % bad)


func _chaser(stage: NpcStage, at: Vector2, goal: Vector2) -> Chaser:
	var c: Chaser = (load(CHASER_SCENE) as PackedScene).instantiate() as Chaser
	c.auto_step = false
	c.position = at
	c.goal = goal
	c.name = "TestChaser"
	stage.level.npcs_root().add_child(c)
	return c


func test_shout_spawns_neighbour_then_inside_and_police() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var a: StoreAlert = stage.alert()
	var spawned: Array[Node] = []
	var police: Array[int] = [0]
	a.chaser_spawn.connect(func(n: Node) -> void: spawned.append(n))
	a.police_arrived.connect(func() -> void: police[0] += 1)
	stage.player(2, STAFF_FRONT)
	stage.run(1.6)
	is_true(stage.owner().brain().is_alarmed(), "bağırdı")
	stage.run(7.8)
	eq(spawned.size(), 0, "8 sn dolmadan komşu yok")
	stage.run(0.3)
	eq(spawned.size(), 1, "bağırıştan 8 sn sonra komşu")
	eq(a.chasers().size(), 1)
	if not is_true(not spawned.is_empty()):
		stage.leave()
		return
	var c: Chaser = spawned[0] as Chaser
	near(c.global_position, stage.marker(&"NeighbourSpawn"), 40.0, "NeighbourSpawn'da doğar")
	var entered_at: float = -1.0
	for i: int in roundi(10.0 / DT):
		stage.run(DT)
		if Game.alert_level() == 3:
			entered_at = (i + 1) * DT
			break
	is_true(entered_at > 0.0 and entered_at <= 10.0, "mahalleli ön kapıya ≤ 10 sn (gelen %.2f)" % entered_at)
	near(Game.alert_timer_left(), 60.0, 0.5, "uyarı 3 → 60 sn polis sayacı")
	eq(stage.owner().brain().alarm_want(), 2)
	Game.set_alert_timer(0.0)  # sayaç doldu (Game sayacı kare saatiyle işler; burada beklemeden)
	stage.run(DT * 2)
	eq(Game.alert_level(), 5, "sayaç bitti: polis geldi")
	eq(police[0], 1, "police_arrived (session_event → her peer)")
	eq(a.ladder.history, PackedInt32Array([0, 1, 2, 3, 5]), "I4 bakkal merdiveni")
	stage.run(1.0)
	eq(Game.alert_level(), 5, "5'ten dönüş yok")
	stage.leave()


func test_chaser_catch_is_permanent_and_held_counts() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var p: Player = stage.player(2, Vector2(400, 400))
	var q: Player = stage.player(3, Vector2(240, 400))
	is_true(q.host_hold(6.0))
	var c: Chaser = _chaser(stage, Vector2(460, 400), Vector2(400, 400))
	for i: int in roundi(2.0 / DT):
		stage.run(DT)
		if p.is_caught():
			break
	is_true(p.is_caught(), "28 px + 0,5 sn: yakalandı")
	is_false((stage.level.players_root().get_node(^"2/Status/Rescue") as Interactable).enabled, "kurtarma yok")
	stage.run(3.0)
	is_true(q.is_caught(), "tutulan oyuncuyu da yakalar")
	eq(c.brain().catches, [2, 3] as Array[int])
	stage.leave()


func test_lost_sight_search_then_wait_at_front_door() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var c: Chaser = _chaser(stage, stage.marker(&"NeighbourSpawn"), Vector2(400, 400))
	stage.run(6.0)
	eq(c.brain().state_name(), &"search", "koşu hedefine vardı, kimse yok: arar")
	stage.run(15.5)
	eq(c.brain().state_name(), &"wait", "15 sn sonra ön kapıda bekler")
	stage.run(6.0)
	near(c.global_position, stage.marker(&"FrontDoor"), 16.0)
	stage.leave()


func test_npc_opens_closed_door_and_door_link_follows_state() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var front: Door = stage.level.props_root().get_node(^"FrontDoor") as Door
	var back: Door = stage.level.props_root().get_node(^"BackDoor") as Door
	is_false(stage.level.door_link(&"BackDoor").enabled, "kapalı arka kapının bağı kapalı (başlangıç)")
	is_true(stage.level.door_link(&"FrontDoor").enabled, "açık ön kapının bağı açık")
	front.is_open = false
	is_false(stage.level.door_link(&"FrontDoor").enabled, "kapı kapanınca bağ kapanır")
	await stage.sync()
	var c: Chaser = _chaser(stage, stage.marker(&"NeighbourSpawn"), Vector2(400, 400))
	var opened: bool = false
	for i: int in roundi(12.0 / DT):
		stage.run(DT)
		if not opened and (front.is_open or back.is_open):
			opened = true
			await stage.sync()  # bağ açıldı: harita yinelemesi
		if c.global_position.distance_to(Vector2(400, 400)) < 16.0:
			break
	is_true(opened, "chaser kapalı kapıyı açtı")
	var uses: int = int(front.dump_state()["interact"]["npc_uses"]) + int(back.dump_state()["interact"]["npc_uses"])
	eq(uses, 1, "Interactable host API'si (host_use_by_npc), oyuncu sayaçları dışında")
	eq(int(front.dump_state()["interact"]["requests"]), 0)
	is_true(c.global_position.distance_to(Vector2(400, 400)) < 16.0, "içeri girdi (%s)" % c.global_position)
	# Kapı NPC gövdesine kapanmaz.
	var door: Door = front if front.is_open else back
	c.global_position = door.global_position
	await tree().physics_frame
	is_true(door.is_closing_blocked(), "kanatta NPC gövdesi: kapanmaz")
	c.global_position = door.global_position + Vector2(0, 80)
	await tree().physics_frame
	is_false(door.is_closing_blocked())
	stage.leave()
