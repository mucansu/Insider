extends TestCase
## US-008 AC5 + AC8: bağırış sonrası (her 5 sn gürültü yinelenir; 30 sn kimse görünmezse uyarı 2 → 1 ve ajanda,
## sakin kalınca 1 → 0; arka oda nakdi alınmışsa 60 sn sonra yeniden bağırış ve +1 komşu) ve koni histerezisi
## (görülmekte olan hedef için 50°/224 → 53°/238 px; yakın/uzak bant sınırı değişmez). Tek süreç = host.

const DT := 1.0 / 30.0
const STAFF_FRONT := Vector2(560, 400)
const HIDDEN := Vector2(656, 176)  # arka oda: duvar arkası


## Arka oda nakdi yer tutucusu (US-010/US-012 çanta prop'u gelene kadar; duck typing `taken`).
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
	a.tuning.max_neighbours = 0  # komşu içeri girip uyarıyı 3'e kilitlemesin: yalnız sahibin sönümü ölçülür
	_shout_then_hide(stage)
	var noises: int = o.brain().shout_noises
	eq(noises, 1, "ilk bağırış gürültüsü")
	stage.run(10.0, Callable(), DT)
	eq(o.brain().shout_noises, 3, "alarmdayken her 5 sn yinelenir")
	eq(Game.alert_level(), 2)
	stage.run(21.0, Callable(), DT)
	eq(o.brain().state(), OwnerBrain.State.AGENDA, "30 sn kimse görünmedi: ajanda")
	eq(Game.alert_level(), 1, "uyarı 2 → 1")
	eq(o.suspicion().latch_level, Suspicion.Level.CALM, "tespit kilidi kalktı")
	stage.run(6.0, Callable(), DT)
	eq(Game.alert_level(), 0, "sakin kaldı: 1 → 0")
	eq(stage.alert().ladder.history, PackedInt32Array([0, 1, 2, 1, 0]), "I4")
	eq(o.agenda().sequence[-1], &"counter", "ajanda tezgâhtan sürer")
	stage.leave()


func test_taken_backroom_cash_triggers_late_shout_and_second_neighbour() -> void:
	var stage := NpcStage.new(self)
	var cash := FakeCash.new()
	cash.name = "FakeCash"
	await stage.enter(NpcStage.STORE, func(level: Level) -> void:
		cash.position = level.marker(&"BackroomCash").position
		level.props_root().add_child(cash))
	var o: StoreOwner = stage.owner()
	var shouts: Array[bool] = []
	o.brain().shouted.connect(func(recheck: bool) -> void: shouts.append(recheck))
	_shout_then_hide(stage)
	cash.taken = true
	stage.run(32.0, Callable(), DT)
	eq(o.brain().state(), OwnerBrain.State.AGENDA)
	stage.run(55.0, Callable(), DT)
	eq(shouts, [false] as Array[bool], "60 sn dolmadan yeniden bağırmaz")
	stage.run(6.0, Callable(), DT)
	eq(shouts, [false, true] as Array[bool], "nakit alınmış: ~60 sn sonra yeniden bağırış (geç fark etme)")
	is_true(o.brain().is_alarmed())
	stage.run(8.5, Callable(), DT)
	eq(stage.alert().chasers().size(), 2, "ikinci bağırış +1 komşu (en fazla 2)")
	# GDD §9.3: geç yeniden bağırış oturum başına bir kez (ikinci sakinleşmeden sonra yinelenmez).
	stage.run(100.0, Callable(), DT)
	eq(shouts.count(true), 1, "yeniden (geç) bağırış bir kez (%s)" % [shouts])
	stage.leave()


## AC8: koni kenarında histerezis; yakın/uzak bant sınırı aynı kalır.
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
