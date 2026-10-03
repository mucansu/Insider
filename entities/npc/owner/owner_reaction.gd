class_name OwnerReaction
extends RefCounted
## Sahibin tepki alt katmanı (US-008 AC4/AC5/AC7; GDD §9.3; HFSM-lite: üst katman OwnerBrain ajanda ↔ tepki
## seçer, bu sınıf tepki durumlarını işletir). Durumlar (OwnerBrain.State): LOOK ("?" 30: durur, bakar ≥ look_min)
## → QUESTION (60: 110 px/sn yürür, 64 px'te durur, `owner_question`, bekler; < 30 ya da bekleme sonunda < 60 →
## `owner_shrug`, ajanda) → SHOUT (beyin bağırır) → CHASE (120 px/sn; 28 px + 0,5 sn temas, oyuncu konumu ON-03
## ile ileri alınır → HOLD) → HOLD (pencere 6 sn, ikinci kez 3 sn; dolunca yakalanır → CHASE) → kurtarılınca
## STAGGER (2 sn, kurtarana şüphe 100) → CHASE / SEARCH (son görülen konum; 30 sn kimse görünmezse ajanda, ilk
## görev arka oda kontrolü; US-039). Beynin yalnız genel API'sini kullanır (§6 kapsülleme).

## Bağırış süresi (sn): durur, bağırır, sonra kovalar.
const SHOUT_SEC := 0.5
## Arama noktasına varış payı (px).
const STAND_PX := 6.0

## Tutulan oyuncu (0 = yok).
var held_peer: int = 0

var _b: OwnerBrain = null
var _contact: float = 0.0
var _asked: bool = false
var _since_seen: float = 0.0
## BAK sırasında inceleme eşiği (60) geçildi mi (görülmeden verilen +60 da sayılır: US-016 tanık, US-010).
var _investigate: bool = false
var _rescue_cb: Callable = Callable()


func _init(brain: OwnerBrain) -> void:
	_b = brain


## Tepki katmanına girişte (LOOK ya da SHOUT) iç sayaçlar sıfırlanır.
func reset() -> void:
	_contact = 0.0
	_asked = false
	_investigate = false
	_since_seen = 0.0


## Bir adım: durumun istenen hızı (global px/sn). `level` en şüpheli serbest oyuncunun düzeyi.
func step(delta: float, level: int) -> Vector2:
	var fsm: Fsm = _b.fsm
	match fsm.state:
		OwnerBrain.State.LOOK:
			return _look(level)
		OwnerBrain.State.QUESTION:
			return _question(delta)
		OwnerBrain.State.SHOUT:
			if fsm.time_in_state >= SHOUT_SEC:
				fsm.go(OwnerBrain.State.CHASE)
			return _b.face(_b.seen_at(_b.target))
		OwnerBrain.State.CHASE:
			return _chase(delta)
		OwnerBrain.State.HOLD:
			return _hold_step()
		OwnerBrain.State.STAGGER:
			if fsm.time_in_state >= _b.owner_tuning.stagger_sec:
				fsm.go(OwnerBrain.State.CHASE if pick_chase_target() != 0 else OwnerBrain.State.SEARCH)
			return Vector2.ZERO
		OwnerBrain.State.SEARCH:
			return _search(delta)
	return Vector2.ZERO


func _look(level: int) -> Vector2:
	var t: OwnerTuning = _b.owner_tuning
	_b.restore_cone()
	_investigate = _investigate or level >= Suspicion.Level.INVESTIGATE
	if _investigate and level >= Suspicion.Level.NOTICE and _b.fsm.time_in_state >= t.look_min_sec:
		_b.target = _b.top_peer()
		_asked = false
		_b.fsm.go(OwnerBrain.State.QUESTION)
		return Vector2.ZERO
	if level < Suspicion.Level.NOTICE and _b.fsm.time_in_state >= t.look_max_sec:
		_b.back_to_agenda()
		return Vector2.ZERO
	if level >= Suspicion.Level.NOTICE:
		_b.target = _b.top_peer()
	return _b.face(_b.seen_at(_b.target))


func _question(delta: float) -> Vector2:
	var t: OwnerTuning = _b.owner_tuning
	var fsm: Fsm = _b.fsm
	var value: float = _b.suspicion.value_of(_b.target)
	var thresholds: PerceptionTuning = _b.perception.tuning
	if value < thresholds.notice_threshold - SuspicionMeter.EPSILON and fsm.time_in_state >= t.look_min_sec:
		_b.shrug()
		return Vector2.ZERO
	var spot: Vector2 = _b.seen_at(_b.target)
	var near: bool = spot.is_finite() and _b.body.global_position.distance_to(spot) <= t.question_stop
	if not _asked and near:
		_asked = true
		fsm.time_in_state = 0.0
		_b.event(&"owner_question", _b.target)
	if _asked:
		var calm: bool = value < thresholds.investigate_threshold - SuspicionMeter.EPSILON
		if (fsm.time_in_state >= t.question_wait_sec and calm) or fsm.time_in_state >= t.question_max_sec:
			_b.shrug()
			return Vector2.ZERO
		_b.mover.stop()
		return _b.face(spot)
	if fsm.time_in_state >= t.question_max_sec:
		_b.shrug()
		return Vector2.ZERO
	_b.mover.move_to(spot, t.question_speed, t.question_stop)
	return _b.walk(delta, spot)


func _chase(delta: float) -> Vector2:
	var c: CivilianTuning = _b.civilian_tuning
	var peer: int = pick_chase_target()
	if peer == 0:
		_b.fsm.go(OwnerBrain.State.SEARCH)
		return Vector2.ZERO
	_b.target = peer
	_since_seen = 0.0
	var player: Node2D = _b.senses.player(peer)
	var spot: Vector2 = _b.senses.predicted(player, c.lead_cap_sec)
	_contact = CivilianRules.contact_step(_contact, _b.body.global_position.distance_to(spot), c.contact_reach, delta)
	if _contact >= c.contact_time - 0.0001:
		_contact = 0.0
		_hold(peer, player)
		return Vector2.ZERO
	_b.mover.move_to(CivilianSenses.position_of(player), _b.owner_tuning.hold_speed, c.contact_reach * 0.5)
	return _b.walk(delta, spot)


func _hold(peer: int, player: Node) -> void:
	var t: OwnerTuning = _b.owner_tuning
	var window: float = CivilianRules.hold_window(int(player.call(&"times_held")), t.hold_window_sec,
		t.hold_window_repeat_sec)
	if not bool(player.call(&"host_hold", window)):
		return
	held_peer = peer
	_rescue_cb = _on_rescued.bind(peer)
	player.connect(&"rescued", _rescue_cb, CONNECT_ONE_SHOT)
	_b.fsm.go(OwnerBrain.State.HOLD)
	_b.mover.stop()
	_b.event(&"owner_held", peer)


func _hold_step() -> Vector2:
	var player: Node2D = _b.senses.player(held_peer)
	if player == null or not bool(player.call(&"is_held")):
		_release()
		_b.suspicion.forget(held_peer)
		held_peer = 0
		_b.fsm.go(OwnerBrain.State.CHASE)
		return Vector2.ZERO
	return _b.face(CivilianSenses.position_of(player))


func _on_rescued(rescuer: int, peer: int) -> void:
	if _b.fsm.state != OwnerBrain.State.HOLD or peer != held_peer:
		return
	_b.rescues.append({"peer": peer, "by": rescuer, "t": _b.fsm.clock})
	_rescue_cb = Callable()
	held_peer = 0
	_b.fsm.go(OwnerBrain.State.STAGGER)
	_b.suspicion.apply_delta(rescuer, _b.owner_tuning.rescuer_suspicion)
	_b.event(&"owner_stagger", rescuer)


func _release() -> void:
	var player: Node = _b.senses.player(held_peer)
	if player != null and _rescue_cb.is_valid() and player.is_connected(&"rescued", _rescue_cb):
		player.disconnect(&"rescued", _rescue_cb)
	_rescue_cb = Callable()


func _search(delta: float) -> Vector2:
	var t: OwnerTuning = _b.owner_tuning
	_since_seen += delta
	if pick_chase_target() != 0:
		_b.fsm.go(OwnerBrain.State.CHASE)
		return Vector2.ZERO
	if _since_seen >= t.calm_after_sec:
		_b.back_to_agenda(true)  # US-039 AC6: ilk görev arka oda (nakit alınmışsa varışta keşif)
		return Vector2.ZERO
	var spot: Vector2 = _b.seen_at(_b.target)
	if not spot.is_finite():
		return Vector2.ZERO
	_b.mover.move_to(spot, t.hold_speed, STAND_PX)
	if _b.mover.arrived() or _b.mover.failed():
		_b.turn(_b.perception.facing.rotated(PI * 0.5), delta)  # bakınır
		return Vector2.ZERO
	return _b.walk(delta, spot)


## Kovalanacak serbest oyuncu: tespit düzeyinde (100) ve şu an görülen, en yakını; süren hedef önceliklidir.
func pick_chase_target() -> int:
	var best: int = 0
	var best_dist: float = INF
	var seen: Dictionary = _b.suspicion.last_observations()
	for peer_id: int in seen:
		var obs: Perception.Observation = seen[peer_id]
		if obs.band == PerceptionRules.Band.NONE or not obs.line_clear:
			continue
		if _b.suspicion.level_of(peer_id) < Suspicion.Level.DETECT:
			continue
		var player: Node2D = _b.senses.player(peer_id)
		if player == null or not bool(player.call(&"is_free")):
			continue
		var dist: float = _b.body.global_position.distance_to(obs.position)
		if peer_id == _b.target:
			dist -= _b.civilian_tuning.view_range
		if dist < best_dist:
			best_dist = dist
			best = peer_id
	return best
