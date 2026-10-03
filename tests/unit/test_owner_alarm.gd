extends TestCase
## US-008 AC5 + AC8: after the shout (noise repeats every 5 s; if nobody is seen for 30 s alert 2 -> 1 and the agenda, calm 1 -> 0)
## and cone hysteresis (for a target being seen 50 deg/224 -> 53 deg/238 px; near/far band boundary unchanged). US-039 AC6 update:
## the fixed "shout again after 60 s" is gone; once calm the agenda's first task is the back room, and if cash was taken,
## discovery 1 s after arrival (DISCOVER -> shout, +1 neighbour; once per source). Single process = host.

const DT := 1.0 / 30.0
const STAFF_FRONT := Vector2(560, 400)
const HIDDEN := Vector2(656, 176)  # back room: behind a wall
const FAR := Vector2(880, 592)  # escape corner (outside): the owner cannot see while heading to the back room


## Back room cash placeholder (until the US-010/US-012 bag prop; duck-typed `taken`).
class FakeCash:
	extends Node2D
	var taken: bool = false


func _shout_then_hide(stage: NpcStage) -> Player:
	var p: Player = stage.player(2, STAFF_FRONT)
	stage.run(1.7, Callable(), DT)
	is_true(stage.owner().brain().is_alarmed(), "bağırdı")
	p.position = HIDDEN
	return p


func test_shout_repeats_then_calms_down_after_30s() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var a: StoreAlert = stage.alert()
	a.tuning = a.tuning.duplicate() as OwnerTuning
	a.tuning.max_neighbours = 0  # so a neighbour entering does not lock the alert at 3: only the owner's decay is measured
	var p: Player = _shout_then_hide(stage)
	var noises: int = o.brain().shout_noises
	eq(noises, 1, "ilk bağırış gürültüsü")
	stage.run(10.0, Callable(), DT)
	eq(o.brain().shout_noises, 3, "alarmdayken her 5 sn yinelenir")
	eq(Game.alert_level(), 2)
	p.position = FAR
	stage.run(21.0, Callable(), DT)
	eq(o.brain().state(), OwnerBrain.State.AGENDA, "30 sn kimse görünmedi: ajanda")
	eq(Game.alert_level(), 1, "uyarı 2 → 1")
	eq(o.suspicion().latch_level, Suspicion.Level.CALM, "tespit kilidi kalktı")
	eq(o.agenda().task_name(), &"backroom", "US-039 AC6: ilk görev arka oda kontrolü")
	stage.run(6.0, Callable(), DT)
	eq(Game.alert_level(), 0, "sakin kaldı: 1 → 0")
	eq(stage.alert().ladder.history, PackedInt32Array([0, 1, 2, 1, 0]), "I4")
	eq(o.brain().discoveries.size(), 0, "nakit yerinde: keşif yok")
	stage.leave()


func test_taken_backroom_cash_is_discovered_on_backroom_check() -> void:
	var stage := NpcStage.new(self)
	var cash := FakeCash.new()
	cash.name = "FakeCash"
	await stage.enter(NpcStage.STORE, func(level: Level) -> void:
		cash.position = level.marker(&"BackroomCash").position
		level.props_root().add_child(cash))
	var o: StoreOwner = stage.owner()
	var shouts: Array[bool] = []
	o.brain().shouted.connect(func(recheck: bool) -> void: shouts.append(recheck))
	var p: Player = _shout_then_hide(stage)
	cash.taken = true
	p.position = FAR
	stage.run(9.0, Callable(), DT)
	var first: Array[Chaser] = stage.alert().chasers()
	eq(first.size(), 1, "bağırış: 8 sn sonra komşu")
	for c: Chaser in first:
		c.free()  # the neighbour leaves the scene: the alert does not rise to 3, the owner's calming and walk to the back room is measured
	stage.run(21.5, Callable(), DT)
	eq(o.brain().state(), OwnerBrain.State.AGENDA)
	eq(o.agenda().task_name(), &"backroom", "sakinleşince ilk görev arka oda")
	eq(Game.alert_level(), 1, "uyarı 2 → 1")
	eq(shouts, [false] as Array[bool], "varmadan keşif yok")
	var found: Array[float] = []
	o.brain().discovered.connect(func(_s: int) -> void: found.append(o.agenda().arrived_for()))
	stage.run(15.0, Callable(), DT)
	eq(o.brain().discoveries.size(), 1, "arka oda varışında nakit keşfi")
	if found.size() == 1:
		near(found[0], 1.0, DT + 0.001, "AC2: varıştan 1 sn sonra")
	if o.brain().discoveries.size() == 1:
		eq(o.brain().discoveries[0]["source"], &"cash")
		is_true(bool(o.brain().discoveries[0]["full"]), "sakin sahip: DISCOVER → bağırış")
	eq(shouts, [false, true] as Array[bool], "keşif → bağırış (geç fark etme)")
	is_true(o.brain().is_alarmed())
	eq(Game.alert_level(), 2)
	stage.run(8.5, Callable(), DT)
	eq(stage.alert().chasers().size(), 1, "keşif bağırışı +1 komşu (toplam 2 = en fazla)")
	# One discovery per source: not repeated on the second calm + back room visit.
	stage.run(100.0, Callable(), DT)
	eq(shouts.count(true), 1, "keşif bir kez (%s)" % [shouts])
	stage.leave()


## AC8: hysteresis at the cone edge; the near/far band boundary stays the same.
func test_cone_hysteresis_keeps_seen_target() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	o.global_position = Vector2(500, 420)
	var per: Perception = o.perception()
	per.facing = Vector2.LEFT
	var p: Player = stage.player(2, Vector2.ZERO)
	await tree().physics_frame
	var at := func(angle_deg: float, dist: float) -> PerceptionRules.Band:
		p.position = Vector2(500, 420) + Vector2.LEFT.rotated(deg_to_rad(angle_deg)) * dist
		return per.observe_target(p).band
	eq(at.call(52.0, 150.0), PerceptionRules.Band.NONE, "görülmeyen hedef: 50° dışı")
	eq(at.call(48.0, 150.0), PerceptionRules.Band.FAR, "50° içi: görülür")
	eq(at.call(52.0, 150.0), PerceptionRules.Band.FAR, "görülürken 53°'ye kadar kalır")
	eq(at.call(54.0, 150.0), PerceptionRules.Band.NONE, "53° dışı: kaybolur")
	eq(at.call(0.0, 230.0), PerceptionRules.Band.NONE, "görülmeyen hedef: 224 px dışı")
	eq(at.call(0.0, 220.0), PerceptionRules.Band.FAR)
	eq(at.call(0.0, 235.0), PerceptionRules.Band.FAR, "görülürken 238 px'e kadar kalır")
	eq(at.call(0.0, 240.0), PerceptionRules.Band.NONE)
	eq(at.call(0.0, 100.0), PerceptionRules.Band.NEAR)
	eq(at.call(0.0, 116.0), PerceptionRules.Band.FAR, "yakın bant sınırı (112 px) histerezisle kaymaz")
	stage.leave()
