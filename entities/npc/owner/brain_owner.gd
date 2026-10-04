class_name OwnerBrain
extends Node
## Shop owner brain, top layer (US-008 AC1/AC4/AC5/AC8; GDD §9.3; S2, S11). Host only; StoreOwner (root) calls `step(delta)` each physics step
## and applies the returned velocity. Rules live in core (`CivilianRules`, `Fsm`). HFSM-lite: this class runs the AGENDA layer (Agenda
## component: counter/shelf/backroom/phone + bell/customer/sent/listen interrupts) and layer selection; reaction states (LOOK -> QUESTION ->
## SHOUT -> CHASE -> HOLD -> STAGGER / SEARCH) are in `OwnerReaction`. Detection (100) moves any calm state to a shout (`owner_shout` +
## 320 px noise, detection latch); while alarmed the shout noise repeats every 5 s. Fairness (AC8, S2): decisions against the player (suspicion,
## contact) use the synchronizer's latest position; the 0.2 s grace and cone hysteresis in the player's favour live in perception. Dump
## `detections` (muhafiz-davranisi §4 fields + behaviour). Component fields (`body`, `perception` ...) are read only by the reaction layer and
## tests; not written outside the brain.
## Service (US-016 AC3): a customer in the queue calls `serve_customer(id)`; if the owner is on AGENDA and no other service runs, it interrupts
## the agenda (CUSTOMER interrupt), comes to ClerkSpot, faces west, serves for 6 s. At the service's `register_open_sec` (sec 2) the "register
## opens" hook `register_opened(customer_id)` fires (US-039 sale trigger; US-010 BUY uses the same hook). The customer reads the result via
## `serve_state(id)`.
## Discovery (US-039): if the owner did not catch the robbery in the act, it notices when the register opens (service hook), `backroom_check_sec`
## after arriving at the backroom task (if the bag is not in place), or `idle_discover_sec` (total) at the counter with no customer and an empty
## register -> DISCOVER (stands, balloon, `owner_discover` session event; `discover_sec`) -> shout flow (alert 2, noise, neighbour). One
## discovery per source; if the owner is already alarmed (or alert >= the shout tier) only balloon + neighbour +1. No discovery after the heist
## ends. After calming down (30 s search) the agenda's first task is forced to the backroom (natural discovery if cash was taken; no fixed
## "shout again after 60 s").
## Return check (IS-100, KR-032; comes before the service and idle triggers): once the owner has been away from ClerkSpot (any agenda task
## or interrupt: restock, backroom, phone, sent, listen, questioning ...) it looks at the register `return_check_sec` after standing back
## at ClerkSpot; an emptied register -> discovery (same flow, same one-per-source rule, none after the heist ends). SEND return cost (GDD
## §9.3 "suspicion +20 to the asking player on return"): back at the counter after SEND, the sender (if still free) gets
## `send_return_suspicion` wherever they are (an unseen meter drains as usual; an alarm in between cancels it; `send_costs`, dump).
## Back door bell (IS-104, KR-034): a player opening/closing or crossing the back door B rings its bell; the owner standing calm at ClerkSpot (home
## task, no interrupt) LISTENs at BackroomSpot and checks the bag on arrival (trigger "bell"); busy = not heard. The inner door D stays
## a plain door sound (hearing -> LISTEN toward D).
## Player tools (US-010; GDD §9.3, KR-026; oyun-yz round 2 #14-#15):
## - BUY `serve_player(peer)`: same as customer service (CUSTOMER interrupt, `register_opened` hook; service id -peer), suspicion 0 and loiter 0
##   for that player, `owner_serve`. SEND TO BACKROOM `send_to_backroom(peer)`: SENT interrupt, `owner_sent`; time from being sent until back at the
##   counter is `sent_windows` (register window). Both accepted in calm states (AGENDA, LOOK, QUESTION): from LOOK/QUESTION it shrugs first
##   (`owner_shrug`), returns to the agenda, then interrupts (interrupt API; round 2 #14).
## - STALL (talk): while a player holds the owner's `Talk` Interactable (`talk_item.busy_by`) the owner stops with a TALK interrupt and faces
##   the talker; gaze is locked on the talker during the talk (cone on them, register and D behind). `owner_talk` on start; once the talker's
##   loiter time passes `loiter_grace` it fires `owner_loiter` once ("what does this guy want"; suspicion fills via the civilian multiplier
##   table's loiter row). The talk is cut (`host_abort`) off agenda or on a high-priority interrupt.
## - DISTRACT: distraction sounds (StoreToolsTuning.DISTRACTION_KINDS) send it to LISTEN (`owner_listen`; session event `owner_distracted`);
##   counted once per source (prop + kind), the second and later add `again_suspicion` to the culprit ("again?", `owner_again`); distraction
##   listening is not split into LOOK unless suspicion reaches the QUESTION threshold (60). On reaching the phone's LISTEN point it finds the
##   phone (`owner_phone_found`, session event `phone_found`).

## Host only: shout (first, after discovery, or discovery while alarmed = neighbour +1); `late` = from discovery (alert manager spawns the
## neighbour).
signal shouted(late: bool)
## Host only: the service's "register opens" moment (US-016 AC3 hook; US-039, US-010).
signal register_opened(customer_id: int)
## Host only: discovery (US-039; Source).
signal discovered(source: int)
## Host only (US-010; US-042 strategy tag "social" hook): a player tool was applied successfully. `kind`: &"buy",
## &"talk", &"send", &"distract" (the culprit of a new distraction the owner heard and entered LISTEN for).
signal social_action(peer_id: int, kind: StringName)
## Host only (US-044): a player gazing through the window was questioned from the door (recognised).
signal recognized(peer_id: int)

enum State { AGENDA, LOOK, QUESTION, SHOUT, CHASE, HOLD, STAGGER, SEARCH, DISCOVER }
## Discovery source (US-039).
enum Source { REGISTER, CASH }
## Service state (customer reads).
enum Serve { NONE, PENDING, ACTIVE, DONE, ABORTED }

const STATE_NAMES: Array[StringName] = [&"agenda", &"look", &"question", &"shout", &"chase", &"hold",
	&"stagger", &"search", &"discover"]
const SOURCE_NAMES: Array[StringName] = [&"register", &"cash"]
## Discovery balloon event (root emits; AC8) and session event (HUD text EVENT_OWNER_DISCOVERED).
const DISCOVER_EVENTS: Array[StringName] = [&"owner_discover_register", &"owner_discover_cash"]
const DISCOVER_SESSION_EVENT := &"owner_discover"
## Look-at point distance (px) if no service look is given.
const SERVE_LOOK_PX := 64.0
## The brain's allowed transitions (I3/I7 tests rely on this table).
const EDGES := {
	State.AGENDA: [State.LOOK, State.SHOUT, State.DISCOVER],
	State.LOOK: [State.AGENDA, State.QUESTION, State.SHOUT, State.DISCOVER],
	State.QUESTION: [State.AGENDA, State.SHOUT, State.DISCOVER],
	State.DISCOVER: [State.SHOUT],
	State.SHOUT: [State.CHASE],
	State.CHASE: [State.HOLD, State.SEARCH],
	State.HOLD: [State.CHASE, State.STAGGER],
	State.STAGGER: [State.CHASE, State.SEARCH],
	State.SEARCH: [State.CHASE, State.AGENDA],
}
const ALARM_STATES: Array[int] = [State.SHOUT, State.CHASE, State.HOLD, State.STAGGER, State.SEARCH]
const CALM_STATES: Array[int] = [State.AGENDA, State.LOOK, State.QUESTION]
## Agenda point arrival margin (px) and shout noise kind (S8).
const STAND_PX := 6.0
const SHOUT_KIND := &"shout"
const MAX_DETECTIONS := 64
## Sounds the owner makes itself: its hearing does not react to them (shout; US-011b agenda sounds).
const OWN_NOISE_KINDS: Array[StringName] = [SHOUT_KIND, NoiseProfile.KIND_PHONE, NoiseProfile.KIND_SHELF,
	NoiseProfile.KIND_BELL]
## Player service id is -peer (customer serial numbers are positive; US-010).
const DISTRACTED_SESSION_EVENT := &"owner_distracted"
const PHONE_FOUND_SESSION_EVENT := &"phone_found"
## Return check (IS-100): beyond RETURN_AWAY_PX from ClerkSpot the owner counts as away; within RETURN_AT_PX as back at the counter.
const RETURN_AWAY_PX := 32.0
const RETURN_AT_PX := 12.0
## Discovery trigger names (dump `discoveries[].trigger`; IS-100).
const TRIGGER_RETURN := &"return"
const TRIGGER_SERVE := &"serve"
const TRIGGER_BACKROOM := &"backroom"
const TRIGGER_IDLE := &"idle"
const TRIGGER_BELL := &"bell"
## Event log (IS-081): discovery reason per trigger and the throttle of repeated sound/bell notes (s).
const DISCOVER_LINES := {
	&"return": "kasa boş, dönüş kontrolü",
	&"serve": "kasa boş, servis",
	&"backroom": "çanta eksik, arka oda kontrolü",
	&"idle": "kasa boş, boş tezgâh",
	&"bell": "çanta eksik, arka kapı zili",
	&"direct": "keşif",
}
const LOG_REPEAT_SEC := 2.0

var owner_tuning: OwnerTuning
var civilian_tuning: CivilianTuning
## Agenda seed (given by StoreOwner.agenda_seed(); I6).
var agenda_seed: int = 0
var fsm := Fsm.new(State.AGENDA, EDGES)
## Ongoing target (peer; 0 = none).
var target: int = 0
## Records (dump, tests).
var detections: Array[Dictionary] = []
var rescues: Array[Dictionary] = []
## peer -> highest suspicion (dump "peak").
var peaks: Dictionary = {}
## Shout noises emitted (first + every 5 s repeat; dump/test).
var shout_noises: int = 0
## Agenda sounds emitted (US-011b; kind -> count): phone, shelf fix, door bell.
var agenda_noises: Dictionary = {}
## Discovery records (dump; US-039): {"source", "t", "full"}.
var discoveries: Array[Dictionary] = []
## Services completed and "register opens" count (dump; US-016).
var serves_done: int = 0
var register_opens: int = 0
## US-010: player tools tuning, talk component (StoreOwner connects it; no talk if missing) and records (dump).
var tools: StoreToolsTuning = null
var talk_item: Interactable = null
var player_serves: int = 0
var sent_windows: Array[float] = []
var phones_found: int = 0
var distractions := CivilianRules.DistractionLog.new()
## Whether the first shout happened (counter prompts are hidden; replicated).
var has_shouted: bool = false
## STALL soothes (dump/test): [{"peer", "amount"}].
var soothed: Array[Dictionary] = []
## Window queries (US-044; dump/test): questioned peers in order.
var window_questions: Array[int] = []
## SEND return costs applied (IS-100 AC3; dump/test): [{"peer", "amount"}].
var send_costs: Array[Dictionary] = []
## Event log (IS-081; dump `log`, host only): state/task changes and important events with a short reason.
var event_log := OwnerLog.new()

## Components (setup connects; read).
var body: CharacterBody2D = null
var perception: Perception = null
var suspicion: Suspicion = null
var agenda: Agenda = null
var mover: NpcMover = null
var senses: CivilianSenses = null

var _reaction: OwnerReaction = null
var _shout_left: float = 0.0
var _notice_at: Dictionary = {}
## Ongoing service (US-016): customer id, whether the register opened; results id -> Serve.
var _serving: bool = false
var _serve_id: int = 0
var _serve_opened: bool = false
var _serve_results: Dictionary = {}
## Discovery (US-039): source -> true; whether the backroom check was done this visit; counter time with empty register and no customer.
var _discovered: Dictionary = {}
var _backroom_checked: bool = false
var _idle_empty: float = 0.0
## US-010: player being talked to (TALK interrupt), those already "what does this guy want"-ed, send time (< 0 if none), distraction
## listening (lock) and the listened phone's prop.
var _talking: int = 0
var _loiter_said: Dictionary = {}
var _sent_at: float = -1.0
## Player who sent the owner to the backroom (SEND return cost; 0 = none / already settled).
var _sent_by: int = 0
## Return check (IS-100): away from ClerkSpot since the last check; time standing back at ClerkSpot (counted on the agenda).
var _away_from_counter: bool = false
var _back_at_counter: float = 0.0
var _distraction_listen: bool = false
var _listen_phone: Node2D = null
## Back door bell (IS-104): the running LISTEN was started by the bell (back room + bag check); time standing at its point.
var _bell_listen: bool = false
var _bell_at_spot: float = 0.0
## STALL soothe: peer -> use count; whether this talk was evaluated (talker peer).
var _soothes: Dictionary = {}
var _soothed_talk: int = 0
## Whether the ongoing questioning is a window questioning (US-044; questioned peer, else 0).
var _door_question: int = 0


## Connects components (StoreOwner `_ready`, on the host).
func setup(owner_body: CharacterBody2D, owner_perception: Perception, owner_suspicion: Suspicion,
		owner_agenda: Agenda, owner_mover: NpcMover, owner_senses: CivilianSenses) -> void:
	body = owner_body
	perception = owner_perception
	suspicion = owner_suspicion
	agenda = owner_agenda
	mover = owner_mover
	senses = owner_senses
	_reaction = OwnerReaction.new(self)
	perception.set_cone(civilian_tuning.half_angle_deg, civilian_tuning.view_range)
	perception.set_hysteresis(civilian_tuning.hysteresis_angle_deg, civilian_tuning.hysteresis_range)
	perception.factor_query = _factor_for
	senses.track_window_stare = true  # US-044: window gazing only in the owner's context
	suspicion.innocent_decay_per_sec = civilian_tuning.innocent_decay_per_sec
	suspicion.threshold_reached.connect(_on_threshold)
	agenda.setup(owner_tuning.tasks, agenda_seed, senses.marker_positions)
	mover.door_shortcut = true  # IS-087 AC3: does not walk around via the street when the back door is open
	if tools == null:
		tools = StoreToolsTuning.load_default()
	mover.close_behind = owner_tuning.close_behind_doors.duplicate()
	mover.close_delay = owner_tuning.close_behind_sec
	agenda.interrupt_ended.connect(_on_interrupt_ended)
	senses.door_crossed.connect(_on_door_crossed)
	senses.back_door_rang.connect(_on_back_door_rang)
	# Props of discovery sources are remembered at the start (while in place): if the first query comes after the bag is carried away, no prop
	# would be found next to the marker and "taken" would never be seen (US-039).
	senses.prop_taken_near(owner_tuning.cash_marker)
	senses.prop_taken_near(owner_tuning.register_marker)


func state() -> int:
	return fsm.state


func state_name() -> StringName:
	return STATE_NAMES[fsm.state]


func is_alarmed() -> bool:
	return ALARM_STATES.has(fsm.state)


## To the alert manager: the owner's requested tier (0 calm, 1 suspicion/question, 2 shouted).
func alarm_want() -> int:
	if is_alarmed():
		return 2
	if fsm.state != State.AGENDA or suspicion.max_level >= Suspicion.Level.NOTICE:
		return 1
	return 0


func target_peer() -> int:
	return target


func held_peer() -> int:
	return _reaction.held_peer if _reaction != null else 0


## One step (host): senses -> suspicion -> layer selection -> desired velocity (global px/s); then the event log entry (IS-081).
func step(delta: float) -> Vector2:
	var velocity: Vector2 = _step_layers(delta)
	_log_tick()
	return velocity


func _step_layers(delta: float) -> Vector2:
	senses.step(delta)
	suspicion.tick(delta)
	mover.close_enabled = not is_alarmed()  # IS-087 AC2: closes the inner door behind it only when calm
	_record_peaks()
	_track_counter_distance()
	fsm.step(delta)
	_tick_shouts(delta)
	var level: int = _top_level()
	if CALM_STATES.has(fsm.state) and level >= Suspicion.Level.DETECT:
		shout(top_peer(), false)
	if fsm.state == State.DISCOVER:
		_end_talk()
		return _discover_step()
	if fsm.state == State.AGENDA:
		return _agenda_step(delta, level)
	if (fsm.state == State.LOOK or fsm.state == State.QUESTION) and _soothe_step():
		return Vector2.ZERO
	_end_talk()
	return _reaction.step(delta, level)


## --- Interrupt API (US-016 customer, US-010 send, US-009 sound; accepted on AGENDA only) ---

## Customer in the queue (US-016 AC3): if the owner is on AGENDA and no other service runs, comes to the counter (ClerkSpot), faces west,
## serves for `customer_sec`. True for the same customer's ongoing service; false while serving another.
func serve_customer(customer_id: int = 0) -> bool:
	if _serving and agenda.current_interrupt() == Agenda.Interrupt.CUSTOMER:
		return customer_id == _serve_id
	var clerk: Vector2 = senses.marker_position(owner_tuning.counter_marker)
	var look: Vector2 = senses.marker_position(owner_tuning.front_door_marker)
	if clerk.is_finite() and not owner_tuning.serve_facing.is_zero_approx():
		look = clerk + owner_tuning.serve_facing.normalized() * SERVE_LOOK_PX
	if not _interrupt(Agenda.Interrupt.CUSTOMER, owner_tuning.customer_sec, clerk, look, true):
		return false
	_serving = true
	_serve_id = customer_id
	_serve_opened = false
	_serve_results[customer_id] = Serve.PENDING
	if customer_id > 0:
		event_log.note("müşteri #%d sırada -> servis" % customer_id)
	return true


## Customer's service state (Serve): PENDING owner is coming to the counter, ACTIVE service running, DONE finished, ABORTED
## dropped (shout, questioning), NONE never accepted.
func serve_state(customer_id: int) -> int:
	if _serving and customer_id == _serve_id and agenda.current_interrupt() == Agenda.Interrupt.CUSTOMER:
		return Serve.ACTIVE if agenda.has_arrived() else Serve.PENDING
	return int(_serve_results.get(customer_id, Serve.NONE))


## Customer crossed the front door (US-016 AC2): bell rings, the owner looks at the door for 1 s (same flow as a player crossing).
func door_bell(door_pos: Vector2) -> void:
	_on_door_crossed(0, door_pos)


## "Is X in the back?": goes to the backroom and searches (US-010 SEND; `peer_id` the asking player, 0 = test/NPC). Accepted in calm
## states (shrugs first from LOOK/QUESTION).
func send_to_backroom(peer_id: int = 0) -> bool:
	if not can_send(peer_id):
		return false
	_settle_for_interrupt()
	var ok: bool = _interrupt(Agenda.Interrupt.SENT, owner_tuning.sent_sec,
		senses.marker_position(owner_tuning.backroom_marker), Vector2.INF, true)
	if ok:
		_sent_at = fsm.clock
		_sent_by = peer_id
		event_log.note("GÖNDER: arka odaya gidiyor (isteyen p%d)" % peer_id)
		if peer_id != 0:
			event(&"owner_sent", peer_id)
			social_action.emit(peer_id, &"send")
	return ok


## Whether SEND is accepted now (calm state, not already sent).
func can_send(_peer_id: int = 0) -> bool:
	return CALM_STATES.has(fsm.state) and agenda.current_interrupt() != Agenda.Interrupt.SENT


## BUY (US-010 AC2): serves the player like a customer (service id -peer; `register_opened` hook the same).
## Suspicion 0 and loiter 0 for that player (GDD §9.3). True and `owner_serve` if accepted.
func serve_player(peer_id: int) -> bool:
	if not can_serve_player(peer_id):
		return false
	_settle_for_interrupt()
	if not serve_customer(-peer_id):
		return false
	suspicion.forget(peer_id)
	senses.reset_loiter(peer_id)
	player_serves += 1
	event(&"owner_serve", peer_id)
	social_action.emit(peer_id, &"buy")
	return true


## Whether BUY is accepted now: calm state, no ongoing service, not sent.
func can_serve_player(peer_id: int) -> bool:
	if peer_id <= 0 or not CALM_STATES.has(fsm.state):
		return false
	var current: Agenda.Interrupt = agenda.current_interrupt()
	return not _serving and current != Agenda.Interrupt.SENT and current != Agenda.Interrupt.CUSTOMER


## Interrupt from LOOK/QUESTION: shrugs, returns to the agenda (the interrupt API also works in LOOK/QUESTION; round 2 #14).
func _settle_for_interrupt() -> void:
	if fsm.state == State.LOOK or fsm.state == State.QUESTION:
		shrug()


## Door bell: stops, looks at the door.
func ring_bell(door_pos: Vector2) -> bool:
	var ok: bool = _interrupt(Agenda.Interrupt.BELL, owner_tuning.bell_sec, Vector2.INF, door_pos, false)
	event_log.note_throttled("bell:%s" % ok, "zil -> kapıya bakış" if ok else "zil, tepki yok (%s/%s)" % [state_name(),
		agenda.task_name()], fsm.clock, LOG_REPEAT_SEC)
	return ok


## Back door bell (IS-104, KR-034): the bell rings at the door (sound for everyone); the owner hears it only standing calm at ClerkSpot
## (AGENDA, home task arrived, no interrupt) -> LISTEN at BackroomSpot (`listen_sec`, counted from the start) and the bag check
## `backroom_check_sec` after arriving (`discover(CASH, "bell")`). Busy -> not heard (event log note). True if the owner reacts.
func back_door_bell(door_pos: Vector2) -> bool:
	_agenda_noise(NoiseProfile.KIND_BELL, door_pos)
	var busy: String = _back_bell_busy()
	if busy.is_empty():
		var spot: Vector2 = senses.marker_position(owner_tuning.backroom_marker)
		if spot.is_finite() and _interrupt(Agenda.Interrupt.LISTEN, owner_tuning.listen_sec, spot, door_pos, false):
			_distraction_listen = false
			_listen_phone = null
			_bell_listen = true
			_bell_at_spot = 0.0
			_backroom_checked = false
			event_log.note("arka kapı zili -> DİNLE, arka odaya")
			event(&"owner_listen", 0)
			return true
		busy = "arka oda noktası yok"
	event_log.note_throttled("backbell", "zil duyulmadı (%s)" % busy, fsm.clock, LOG_REPEAT_SEC)
	return false


## Why the back bell is not heard now (empty = heard): reaction/alarm state, an interrupt (service, listen, sent, talk, bell), or not at
## the counter (other agenda task, still walking home).
func _back_bell_busy() -> String:
	if fsm.state != State.AGENDA:
		return String(state_name())
	if agenda.current_interrupt() != Agenda.Interrupt.NONE:
		return String(agenda.task_name())
	var task: AgendaTask = agenda.current_task()
	if task == null or not task.home:
		return String(agenda.task_name())
	if not agenda.has_arrived():
		return "tezgâha yürüyor"
	return ""


func _on_back_door_rang(_peer_id: int, door_pos: Vector2) -> void:
	back_door_bell(door_pos)


## Sound heard (Hearing `heard`, S8/S11): walks toward it (stops 64 px short) and looks. Excludes its own sounds
## (shout, agenda sounds, bell).
func hear(pos: Vector2, _radius: float, kind: StringName) -> bool:
	if OWN_NOISE_KINDS.has(kind) or not pos.is_finite():
		return false
	var distraction: bool = StoreToolsTuning.DISTRACTION_KINDS.has(kind)
	var source: Node2D = senses.distraction_source(pos) if distraction else null
	var fresh: bool = distraction and distractions.note(_distraction_key(source, pos, kind))
	if fresh and distractions.is_again():
		var culprit: int = int(source.call(&"distraction_peer", kind)) if source != null else 0
		if culprit != 0 and CALM_STATES.has(fsm.state):
			suspicion.apply_delta(culprit, tools.again_suspicion)  # "again?" (US-010 AC5)
			event(&"owner_again", culprit)
	var here: Vector2 = body.global_position
	var spot: Vector2 = Vector2.INF
	if here.distance_to(pos) > owner_tuning.question_stop:
		spot = pos + (here - pos).normalized() * owner_tuning.question_stop
	var was_listening: bool = agenda.current_interrupt() == Agenda.Interrupt.LISTEN
	if not _interrupt(Agenda.Interrupt.LISTEN, owner_tuning.listen_sec, spot, pos, false):
		event_log.note_throttled("hear-no:%s" % kind, "ses '%s' duyuldu, tepki yok (%s/%s)" % [kind, state_name(),
			agenda.task_name()], fsm.clock, LOG_REPEAT_SEC)
		return false
	event_log.note_throttled("hear:%s" % kind, "ses '%s' -> DİNLE%s" % [kind, " (dikkat dağıtma)" if distraction else ""],
		fsm.clock, 0.0 if not was_listening else LOG_REPEAT_SEC)
	_distraction_listen = distraction
	_bell_listen = false  # a newer sound replaces the bell's back-room walk (latest sound wins)
	_listen_phone = source if kind == StoreToolsTuning.KIND_CELLPHONE else null
	if not was_listening:
		event(&"owner_listen", 0)
	if fresh:
		Game.raise_session_event(DISTRACTED_SESSION_EVENT, {"kind": String(kind)})
		var by: int = int(source.call(&"distraction_peer", kind)) if source != null else 0
		if by != 0:
			social_action.emit(by, &"distract")
	return true


static func _distraction_key(source: Node2D, pos: Vector2, kind: StringName) -> String:
	var where: String = String(source.name) if source != null else str(pos.round())
	return "%s:%s" % [where, kind]


func _interrupt(kind: Agenda.Interrupt, duration: float, spot: Vector2, look: Vector2, on_arrival: bool) -> bool:
	if fsm.state != State.AGENDA:
		return false
	return agenda.interrupt(kind, duration, spot, look, on_arrival)


func _on_door_crossed(_peer_id: int, door_pos: Vector2) -> void:
	_agenda_noise(NoiseProfile.KIND_BELL, door_pos)  # bell rings at the door (US-011b; wherever the owner is)
	ring_bell(door_pos)


func _on_interrupt_ended(kind: Agenda.Interrupt, completed: bool) -> void:
	if kind != Agenda.Interrupt.CUSTOMER or not _serving:
		return
	_serving = false
	_serve_results[_serve_id] = Serve.DONE if completed else Serve.ABORTED
	if completed:
		serves_done += 1


## --- Discovery (US-039) ---

## Notice the robbery: once per source, while the heist runs. If calm DISCOVER -> shout; if already alarmed (or alert at the shout tier) only
## balloon + neighbour +1. True if accepted.
func discover(source: int, trigger: StringName = &"direct") -> bool:
	if source < 0 or source >= SOURCE_NAMES.size() or _discovered.has(source) or not _heist_running():
		return false
	_discovered[source] = true
	var full: bool = not is_alarmed() and fsm.state != State.DISCOVER \
		and Game.alert_level() < maxi(civilian_tuning.alarm_level, 1)
	discoveries.append({"source": SOURCE_NAMES[source], "t": snappedf(fsm.clock, 0.01), "full": full, "trigger": trigger})
	event_log.note("%s (%s)%s" % [str(DISCOVER_LINES.get(trigger, "keşif")), SOURCE_NAMES[source],
		"" if full else ", zaten alarmda: yalnız balon"], "discoveries[%d]" % (discoveries.size() - 1))
	discovered.emit(source)
	event(DISCOVER_EVENTS[source], 0)
	if not full:
		shouted.emit(true)  # second source while alarmed: only balloon + neighbour +1 (max_neighbours preserved)
		return true
	Game.raise_session_event(DISCOVER_SESSION_EVENT, {"source": String(SOURCE_NAMES[source])})
	target = 0
	mover.stop()
	agenda.cancel_interrupt()
	_reaction.reset()
	fsm.go(State.DISCOVER)
	return true


## DISCOVER: stands (balloon in the visual); when time is up the shout flow (targetless; alert >= 2 row applies to everyone).
func _discover_step() -> Vector2:
	mover.stop()
	if fsm.time_in_state >= owner_tuning.discover_sec:
		shout(0, true)
	return Vector2.ZERO


## Discovery triggers on the agenda: back at ClerkSpot after being away + `return_check_sec` (IS-100, first), the service's "register
## opens" moment, backroom arrival + 1 s, empty register at the counter without a customer. True if the state changed (step ends).
func _agenda_triggers(delta: float) -> bool:
	if _return_check(delta):
		return fsm.state != State.AGENDA
	if _serving and not _serve_opened and agenda.current_interrupt() == Agenda.Interrupt.CUSTOMER \
			and agenda.has_arrived() and agenda.interrupt_elapsed() >= owner_tuning.register_open_sec:
		_serve_opened = true
		register_opens += 1
		event_log.note("servis: kasa açıldı")
		register_opened.emit(_serve_id)
		if senses.prop_taken_near(owner_tuning.register_marker) and discover(Source.REGISTER, TRIGGER_SERVE):
			return fsm.state != State.AGENDA
	var interrupt: Agenda.Interrupt = agenda.current_interrupt()
	var task: AgendaTask = agenda.current_task()
	var bell: bool = _bell_listen and interrupt == Agenda.Interrupt.LISTEN
	var backroom: bool = bell or interrupt == Agenda.Interrupt.SENT or (interrupt == Agenda.Interrupt.NONE \
		and task != null and task.name == owner_tuning.backroom_task)
	# LISTEN counts its time from the start, so the bell's "since arrival" is kept here (IS-104).
	if bell and agenda.has_arrived():
		_bell_at_spot += maxf(delta, 0.0)
	var arrived_for: float = _bell_at_spot if bell else agenda.arrived_for()
	if not backroom:
		_backroom_checked = false
	elif not _backroom_checked and agenda.has_arrived() and arrived_for >= owner_tuning.backroom_check_sec:
		_backroom_checked = true
		var cash_taken: bool = senses.prop_taken_near(owner_tuning.cash_marker)
		if not cash_taken:
			event_log.note("arka oda kontrolü: çanta yerinde")
		if cash_taken and discover(Source.CASH, TRIGGER_BELL if bell else TRIGGER_BACKROOM):
			return fsm.state != State.AGENDA
	var at_counter: bool = interrupt == Agenda.Interrupt.NONE and task != null and task.home and agenda.has_arrived()
	if owner_tuning.idle_discover_sec > 0.0 and at_counter and senses.customers_inside() == 0 \
			and not _discovered.has(Source.REGISTER) and senses.prop_taken_near(owner_tuning.register_marker):
		_idle_empty += maxf(delta, 0.0)
		if _idle_empty >= owner_tuning.idle_discover_sec and discover(Source.REGISTER, TRIGGER_IDLE):
			return fsm.state != State.AGENDA
	return false


## Return check (IS-100): standing back at ClerkSpot after being away; at `return_check_sec` the register is looked at once per return.
## True if a discovery was accepted.
func _return_check(delta: float) -> bool:
	if owner_tuning.return_check_sec <= 0.0 or not _away_from_counter or not _near_counter(RETURN_AT_PX):
		return false
	_back_at_counter += maxf(delta, 0.0)
	if _back_at_counter < owner_tuning.return_check_sec:
		return false
	_away_from_counter = false
	_back_at_counter = 0.0
	var taken: bool = senses.prop_taken_near(owner_tuning.register_marker)
	if not taken:
		event_log.note("dönüş kontrolü: kasa dolu")
	return taken and discover(Source.REGISTER, TRIGGER_RETURN)


## Every step (any state): leaving ClerkSpot arms the return check; stepping off the spot restarts the "back at the counter" time.
func _track_counter_distance() -> void:
	if not _near_counter(RETURN_AWAY_PX):
		_away_from_counter = true
	if not _near_counter(RETURN_AT_PX):
		_back_at_counter = 0.0


## Whether the owner stands within `px` of ClerkSpot (false if the marker is missing).
func _near_counter(px: float) -> bool:
	var clerk: Vector2 = senses.marker_position(owner_tuning.counter_marker)
	return clerk.is_finite() and body.global_position.distance_to(clerk) <= px


## Whether the heist is running (if the result was not broadcast; US-039 AC7: no discovery after the heist ends).
func _heist_running() -> bool:
	return Game.heist_result().is_empty()


## --- AGENDA layer ---

func _agenda_step(delta: float, level: int) -> Vector2:
	var listening: bool = agenda.current_interrupt() == Agenda.Interrupt.LISTEN
	if not listening:
		_distraction_listen = false
		_listen_phone = null
		_bell_listen = false
	# Distraction listening is not split into LOOK by "again?" suspicion; it is split at the QUESTION threshold (60) (US-010).
	var held_by_listen: bool = listening and _distraction_listen and level < Suspicion.Level.INVESTIGATE
	if level >= Suspicion.Level.NOTICE and not held_by_listen:
		target = top_peer()
		_reaction.reset()
		_end_talk()
		fsm.go(State.LOOK)
		mover.stop()
		return Vector2.ZERO
	_talk_step()
	_sent_window_step()
	if listening and _listen_phone != null and agenda.has_arrived():
		_find_phone()
	var goal: Vector2 = agenda.goal_position()
	if goal.is_finite():
		mover.move_to(goal, owner_tuning.walk_speed, STAND_PX)
	else:
		mover.stop()
	agenda.step(delta, mover.arrived() or mover.failed())
	if _agenda_triggers(delta):
		return Vector2.ZERO
	var sound: StringName = agenda.take_noise(delta)
	if not sound.is_empty():
		_agenda_noise(sound, body.global_position)
	var narrowed: float = agenda.half_angle_deg()
	perception.set_cone(narrowed if narrowed > 0.0 else civilian_tuning.half_angle_deg, civilian_tuning.view_range)
	var velocity: Vector2 = mover.desired_velocity(delta)
	if velocity.length() > 1.0:
		turn(velocity, delta)
	else:
		var look: Vector2 = agenda.goal_facing(body.global_position)
		if not look.is_zero_approx():
			turn(look, delta)
	return velocity


## --- player tools (US-010) ---

## TALK: while a player holds `talk_item` the owner stops and turns to them (gaze locked); on release the agenda continues.
func _talk_step() -> void:
	var talker: int = talk_item.busy_by if talk_item != null else 0
	var current: Agenda.Interrupt = agenda.current_interrupt()
	if talker == 0:
		_talking = 0
		if current == Agenda.Interrupt.TALK:
			agenda.cancel_interrupt()
		return
	var player: Node2D = senses.player(talker)
	var at: Vector2 = CivilianSenses.position_of(player) if player != null else Vector2.INF
	if current == Agenda.Interrupt.TALK and _talking == talker:
		agenda.retarget_look(at)
	elif agenda.interrupt(Agenda.Interrupt.TALK, tools.talk_max_sec + 1.0, Vector2.INF, at, false):
		_talking = talker
		mover.stop()
		event(&"owner_talk", talker)
		social_action.emit(talker, &"talk")
	else:
		_end_talk()  # a high-priority interrupt (customer, sent) is running: no talk
		return
	var grace: float = senses.rules.loiter_grace if senses.rules != null else 0.0
	if grace > 0.0 and not _loiter_said.has(talker) and senses.loiter_time(talker) >= grace:
		_loiter_said[talker] = true
		event(&"owner_loiter", talker)  # "what does this guy want" (suspicion fills via the loiter row)


## Cuts the talk (host): the component is released, the TALK interrupt ends.
func _end_talk() -> void:
	if talk_item != null and talk_item.busy_by != 0:
		talk_item.host_abort()
	if _talking != 0 and agenda.current_interrupt() == Agenda.Interrupt.TALK:
		agenda.cancel_interrupt()
	_talking = 0


## Perception's multiplier query: civilian table; the window-gazing row (US-044) stops suspicion at `outside_stare_cap`
## (does not shout, only asks).
func _factor_for(target: Node) -> float:
	var f: float = senses.factor_for(target)
	if f <= 0.0 or senses.behaviour_for(target) != CivilianRules.Behaviour.WINDOW_STARE:
		return f
	var cap: float = civilian_tuning.outside_stare_cap
	return 0.0 if suspicion.value_of(target.get_multiplayer_authority()) >= cap else f


## Questioning point: for a player gazing through the window (outside) the owner walks to the front door (US-044); for others the last seen position.
## The decision holds for a whole questioning (the owner does not walk out even if the gazer turns away for a moment).
func question_spot(peer_id: int) -> Vector2:
	if _door_question == peer_id or is_window_starer(peer_id):
		var door: Vector2 = senses.marker_position(owner_tuning.front_door_marker)
		if door.is_finite():
			_door_question = peer_id
			return door
	return seen_at(peer_id)


## Whether the player is outside gazing through the window (US-044; context window time > 0).
func is_window_starer(peer_id: int) -> bool:
	var player: Node2D = senses.player(peer_id)
	if player == null or senses.window_stare_of(peer_id) <= 0.0:
		return false
	return senses.zone_of(CivilianSenses.position_of(player)) == CivilianRules.Zone.OUTSIDE


## Questioning moment (OwnerReaction): to a window gazer "Looking for something?" (recognised), to others "What are you doing?".
func ask(peer_id: int) -> void:
	if _door_question == peer_id:
		window_questions.append(peer_id)
		event(&"owner_question_window", peer_id)
		recognized.emit(peer_id)
	else:
		event(&"owner_question", peer_id)


## STALL soothe (GDD §9.3, US-010 trace): when a talk starts with the owner in LOOK/QUESTION, that player's suspicion drops by their counter
## (40 / 20 / 0), the owner shrugs and moves to talk on the agenda (true). If the counter is exhausted ("does not work again")
## `owner_soothe_refused` and the talk is cut (false). A talk is evaluated once.
func _soothe_step() -> bool:
	var talker: int = talk_item.busy_by if talk_item != null else 0
	if talker == 0:
		_soothed_talk = 0
		return false
	if _soothed_talk == talker:
		return false
	_soothed_talk = talker
	var uses: int = int(_soothes.get(talker, 0))
	_soothes[talker] = uses + 1
	var amount: float = CivilianRules.soothe_amount(uses, tools.talk_soothe_steps)
	if amount <= 0.0:
		event(&"owner_soothe_refused", talker)
		return false
	suspicion.apply_delta(talker, -amount)
	soothed.append({"peer": talker, "amount": amount})
	shrug()
	return true


## Player currently talked to (0 = none).
func talking_to() -> int:
	return _talking


## Register window measurement: time from being sent until back at the counter (home task).
func _sent_window_step() -> void:
	if _sent_at < 0.0 or agenda.current_interrupt() != Agenda.Interrupt.NONE:
		return
	var task: AgendaTask = agenda.current_task()
	if task != null and task.home and agenda.has_arrived():
		sent_windows.append(snappedf(fsm.clock - _sent_at, 0.01))
		event_log.note("GÖNDER dönüşü: tezgâhta", "sent_windows[%d]" % (sent_windows.size() - 1))
		_sent_at = -1.0
		_send_return_cost()


## SEND return cost (IS-100 AC3, GDD §9.3 "suspicion +20 to the asking player on return"): back at the counter, the sender gets
## `send_return_suspicion` once if still free (not held / caught). Applied wherever the sender is: an unseen meter drains at the usual
## rate (suspicion given unseen leaks no position), so leaving before the return mostly avoids it.
func _send_return_cost() -> void:
	var peer_id: int = _sent_by
	_sent_by = 0
	var amount: float = owner_tuning.send_return_suspicion
	if peer_id == 0 or amount <= 0.0:
		return
	var player: Node2D = senses.player(peer_id)
	if player == null or not bool(player.call(&"is_free")):
		return
	suspicion.apply_delta(peer_id, amount)
	send_costs.append({"peer": peer_id, "amount": amount})
	event_log.note("GÖNDER dönüş bedeli p%d" % peer_id, "send_costs[%d]" % (send_costs.size() - 1))


## Reached the phone's LISTEN point: finds the phone.
func _find_phone() -> void:
	var phone: Node2D = _listen_phone
	_listen_phone = null
	if phone == null or not is_instance_valid(phone) or not phone.has_method(&"host_take_phone"):
		return
	if body.global_position.distance_to(phone.global_position) > maxf(tools.phone_find_px, owner_tuning.question_stop):
		return
	if bool(phone.call(&"host_take_phone")):
		phones_found += 1
		event(&"owner_phone_found", 0)
		Game.raise_session_event(PHONE_FOUND_SESSION_EVENT, {})


## US-037 (KR-027): shoved by `peer_id` (host; NpcContact already applied the calm cost). Calm on the agenda -> LOOK at the pusher; while
## chasing the hold contact window restarts.
func on_pushed(peer_id: int, calm: bool) -> void:
	if calm and fsm.state == State.AGENDA:
		target = peer_id
		_reaction.reset()
		_end_talk()
		fsm.go(State.LOOK)
		mover.stop()
	elif fsm.state == State.CHASE:
		_reaction.reset()


## --- general helpers used by the reaction layer ---

## Shout: detection latch, noise, event; `late` = from discovery (US-039).
func shout(peer_id: int, late: bool) -> void:
	if peer_id != 0:
		target = peer_id
	_sent_by = 0  # alarm: the SEND errand is over, no return cost later
	suspicion.latch_level = Suspicion.Level.DETECT
	has_shouted = true
	mover.stop()
	agenda.cancel_interrupt()
	_shout_left = owner_tuning.shout_repeat_sec
	_reaction.reset()
	if fsm.state != State.SHOUT:
		fsm.go(State.SHOUT)
	event(&"owner_shout", target)
	_noise()
	shouted.emit(late)


## Calming down: latch released, agenda restarts from the counter; `check_backroom` (after alarm, US-039 AC6) forces the first task to the
## backroom (natural discovery on arrival if cash was taken).
func back_to_agenda(check_backroom: bool = false) -> void:
	suspicion.latch_level = Suspicion.Level.CALM
	target = 0
	_door_question = 0
	_reaction.reset()
	fsm.go(State.AGENDA)
	agenda.restart_home()
	if check_backroom:
		agenda.begin_task(owner_tuning.backroom_task)
		event_log.note("sakinleşti -> ilk görev arka oda")
	restore_cone()


func shrug() -> void:
	event(&"owner_shrug", target)
	back_to_agenda()


func restore_cone() -> void:
	perception.set_cone(civilian_tuning.half_angle_deg, civilian_tuning.view_range)


func walk(delta: float, look_at: Vector2) -> Vector2:
	var velocity: Vector2 = mover.desired_velocity(delta)
	if velocity.length() > 1.0:
		turn(velocity, delta)
	elif look_at.is_finite():
		turn(look_at - body.global_position, delta)
	return velocity


func face(point: Vector2) -> Vector2:
	if point.is_finite():
		turn(point - body.global_position, get_physics_process_delta_time())
	return Vector2.ZERO


func turn(direction: Vector2, delta: float) -> void:
	perception.turn_toward(direction, delta)


func seen_at(peer_id: int) -> Vector2:
	return suspicion.last_seen_position(peer_id) if peer_id != 0 else Vector2.INF


## Most suspicious free player (0 if none).
func top_peer() -> int:
	var best: int = 0
	var best_value: float = 0.0
	for peer_id: int in suspicion.peers():
		var player: Node = senses.player(peer_id)
		if player != null and not bool(player.call(&"is_free")):
			continue
		var value: float = suspicion.value_of(peer_id)
		if value > best_value:
			best_value = value
			best = peer_id
	return best


## Result event (AC10): the root broadcasts to everyone via reliable RPC.
func event(kind: StringName, peer: int) -> void:
	event_log.note_event(kind, peer)
	if body.has_method(&"host_event"):
		body.call(&"host_event", kind, peer)


func _top_level() -> int:
	var peer: int = top_peer()
	return suspicion.level_of(peer) if peer != 0 else Suspicion.Level.CALM


func _tick_shouts(delta: float) -> void:
	if not is_alarmed():
		return
	_shout_left -= delta
	if _shout_left <= 0.0:
		_shout_left = owner_tuning.shout_repeat_sec
		_noise()


func _noise() -> void:
	shout_noises += 1
	NoiseBus.emit_noise(body.global_position, owner_tuning.shout_radius, SHOUT_KIND)


## Agenda sound (US-011b, S8): radius from NoiseProfile; NoiseBus emits to listeners and the ring event on the host.
func _agenda_noise(kind: StringName, at: Vector2) -> void:
	agenda_noises[kind] = int(agenda_noises.get(kind, 0)) + 1
	NoiseBus.emit_noise(at, NoiseProfile.load_default().radius_for(kind), kind)


func _record_peaks() -> void:
	for peer_id: int in suspicion.peers():
		peaks[peer_id] = maxf(float(peaks.get(peer_id, 0.0)), suspicion.value_of(peer_id))


## Threshold crossings: the "?" moment and detection record (AC8 dump; time = brain clock, Fsm.clock).
func _on_threshold(peer_id: int, level: int) -> void:
	if level == Suspicion.Level.NOTICE:
		_notice_at[peer_id] = fsm.clock
		event_log.note("şüphe eşiği ? p%d" % peer_id)
	elif level == Suspicion.Level.DETECT and detections.size() < MAX_DETECTIONS:
		var obs: Perception.Observation = suspicion.last_observations().get(peer_id) as Perception.Observation
		detections.append(senses.detection_record(peer_id, obs, perception.global_position,
			float(_notice_at.get(peer_id, -1.0)), fsm.clock))
		event_log.note("tespit p%d" % peer_id, "detections[%d]" % (detections.size() - 1))


## Event log entry at the end of a step (IS-081): state, task/interrupt, facing, target (held player in HOLD), highest suspicion.
func _log_tick() -> void:
	var top: int = 0
	var top_value: float = 0.0
	for peer_id: int in suspicion.peers():
		var value: float = suspicion.value_of(peer_id)
		if value > top_value:
			top_value = value
			top = peer_id
	var who: int = target if target != 0 else held_peer()
	event_log.tick(fsm.clock, state_name(), agenda.task_name(), perception.facing, who, top, top_value)
