class_name StoreOwner
extends CharacterBody2D
## Shop owner (US-008 AC1/AC10; GDD §9.3; S2, S11). Root CharacterBody2D (layer npcs, mask world: does not push players); components
## `Perception`, `Suspicion`, `Agenda`, `NpcMover`, `CivilianSenses`, `Brain` (OwnerBrain), optional `Hearing` (S8/S11, US-009; created if the
## generic class `Hearing` exists and the scene has none, duck typing: `heard(pos, radius, kind)` signal) and visual `Visual`. A static node
## under `NPCs` in the level (same path on every peer, authority host).
## Host: each physics step the brain gives velocity, `move_and_slide`, network fields are written. Replication (15 Hz): position/facing/meter
## unreliable continuous (ON-04: "?"/"!" derived from the threshold on the client), state/task/alarm/held reliable on change. Result events
## (`owner_question`, `owner_shrug`, `owner_shout`, `owner_held`, `owner_stagger`; AC10) become signals in the same order on every peer via
## reliable RPC. The client follows the position with smoothing. Dump (S6, `--dump`): "owner" = {state, task, alarmed, events, event_peers,
## bubbles} + on the host {detections, peak, agenda, states, rescues, discoveries, serves, register_opens}.
## US-016/US-039 additions: service hook and customer API (`serve_customer(id)`, `serve_state`, `door_bell`), discovery events
## `owner_discover_register` / `owner_discover_cash` (balloon; AC8) and host API `discover(source)`.
## US-010 additions (shop interactions): host API `serve_player(peer)` / `can_serve_player(peer)` (BUY), `send_to_backroom(peer)` /
## `can_send(peer)` (SEND), `is_active()`, `has_shouted()` (replicated `net_shouted`: counter prompts hidden); a `Talk` Interactable on the
## owner (STALL: E, hold, `talk_range`; innocent action; enabled from replicated state on every peer: in calm agenda, outside service/sent,
## before shouting); event channel extended (`owner_serve`, `owner_talk`, `owner_sent`, `owner_listen`, `owner_again`, `owner_phone_found`,
## `owner_loiter`; balloons in NpcVisual). Dump additions: on every peer `talk_peer`, `facing`, `shouted`, `talk_gaze`; on the host `loiter_s`
## (peer -> s), `player_serves`, `sent_windows`, `distractions`, `phones_found`; IS-100: `send_costs` ([{peer, amount}], SEND return cost)
## and `discoveries[].trigger` (return / serve / backroom / idle / direct). IS-081: `log` (OwnerLog ring buffer, last 200: t, state, task,
## facing, target, why, top_peer, top_value, ref -> discoveries/send_costs/sent_windows/detections index) and `log_dropped`.
## US-037 (KR-027): `Contact` component (NpcContact; created in `_ready` when active). The owner is an observer of shoves (range + line of
## sight -> `report_suspicion`); a calm shove adds suspicion and turns it to LOOK (`OwnerBrain.on_pushed`); while it staggers the brain is
## skipped (slide via physics, out of walls); while it HOLDs a player a teammate's shove is the PULL result (the held player's `Rescue`
## Interactable completes: free, `rescued`, owner STAGGER - the existing rescue path).
## IS-096: a `TaskGlyph` under `Visual` (created in `_ready` when active) draws the task badge from `net_state`/`net_task`.

signal owner_question(peer_id: int)
signal owner_shrug(peer_id: int)
signal owner_shout(peer_id: int)
signal owner_held(peer_id: int)
signal owner_stagger(peer_id: int)
## US-039 AC8: discovery balloon (peer always 0).
signal owner_discover_register(peer_id: int)
signal owner_discover_cash(peer_id: int)
## US-010 event channel (same order on every peer; balloon texts NpcVisual.BALLOON_KEYS).
signal owner_serve(peer_id: int)
signal owner_talk(peer_id: int)
signal owner_sent(peer_id: int)
signal owner_listen(peer_id: int)
signal owner_again(peer_id: int)
signal owner_phone_found(peer_id: int)
signal owner_loiter(peer_id: int)
## On every peer: task changed (replicated; task icon US-011).
signal task_changed(task_name: StringName)
## Host only (US-010): a player tool was applied successfully (OwnerBrain.social_action relay; kind buy|talk|send|distract).
## US-042 `Tracker.note_social` connects to this (coordinator merge).
signal social_action(peer_id: int, kind: StringName)
## US-010 trace / US-043 / US-044 event channel (every peer): STALL soothe exhausted ("does not work again"),
## REDIRECT ("they ran that way!"), window gazer questioned from the door ("Looking for something?").
signal owner_soothe_refused(peer_id: int)
signal owner_misdirect(peer_id: int)
signal owner_question_window(peer_id: int)
## Host only (US-044): the owner recognised the player (window questioning); Game counts `recognized` +1 at heist result.
signal recognized(peer_id: int)

const OWNER_TUNING_PATH := "res://data/npc/owner_tuning.tres"
const CIVILIAN_TUNING_PATH := "res://data/npc/civilian_tuning.tres"
const DUMP_KEY := "owner"
const EVENT_KINDS: Array[StringName] = [&"owner_question", &"owner_shrug", &"owner_shout", &"owner_held",
	&"owner_stagger", &"owner_discover_register", &"owner_discover_cash", &"owner_serve", &"owner_talk",
	&"owner_sent", &"owner_listen", &"owner_again", &"owner_phone_found", &"owner_loiter", &"owner_soothe_refused",
	&"owner_misdirect", &"owner_question_window"]
## Prompt key of the REDIRECT component, required tag (player's cover intact; Player.interaction_tags) and session
## event (HUD text EVENT_MISDIRECT).
const MISDIRECT_ACTION_KEY := "INTERACT_MISDIRECT"
const COVER_TAG := &"cover"
const MISDIRECT_SESSION_EVENT := &"misdirect"
## Owner states where STALL is open (US-010 trace: an owner in LOOK/QUESTION can also be talked to and soothed).
const TALK_STATES: Array[int] = [OwnerBrain.State.AGENDA, OwnerBrain.State.LOOK, OwnerBrain.State.QUESTION]
## Prompt key of the STALL component (i18n) and tasks where talking is closed (service, sent).
const TALK_ACTION_KEY := "INTERACT_OWNER_TALK"
const TALK_CLOSED_TASKS: Array[StringName] = [&"customer", &"sent"]
## Client smoothing (1/s) and jump threshold (px).
const SMOOTHING := 14.0
const SNAP_PX := 96.0
const HEARING_CLASS := &"Hearing"
## Replicated task name of the LISTEN interrupt (Agenda.INTERRUPT_NAMES).
const LISTEN_TASK := &"listen"
## Maximum events kept in the dump.
const MAX_EVENTS := 128
## US-037: held player's PULL component (PlayerStatus child; the shoulder rescue completes it).
const RESCUE_PATH := ^"Status/Rescue"

@export var owner_tuning: OwnerTuning
@export var civilian_tuning: CivilianTuning
## False: tests drive `step()` by hand.
@export var auto_step: bool = true
## False: the owner is ignored (hidden, no collision, does not run; fixture for interaction scenarios without NPCs).
@export var active: bool = true
## If >= 0, the agenda seed instead of the tuning file's (test fixture: e.g. first window task is the backroom; US-039).
@export var agenda_seed_override: int = -1

## Replicated state (host writes).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.LEFT
var net_meter: float = 0.0
var net_state: int = 0
var net_task: StringName = &"":
	set = _set_task
var net_alarmed: bool = false
var net_hold_peer: int = 0
## Whether the owner shouted this heist (US-010: counter prompts hidden).
var net_shouted: bool = false
## Whether REDIRECT was used this heist (US-043: 1 per heist; prompts hidden).
var net_misdirected: bool = false
## Host records (dump): REDIRECT [{"peer", "chasers", "point"}].
var misdirects: Array[Dictionary] = []

## State the visual reads (on every peer).
var facing: Vector2 = Vector2.LEFT
var bubble: int = CivilianRules.Bubble.NONE
## Last event and time since it (balloon text).
var last_event: StringName = &""
var last_event_age: float = INF

var _rules: CivilianRules.Params = null
var _events: Array[StringName] = []
var _event_peers: Array[int] = []
var _bubbles: Array[int] = []
var _contact: NpcContact = null

@onready var _perception: Perception = $Perception
@onready var _suspicion: Suspicion = $Suspicion
@onready var _agenda: Agenda = $Agenda
@onready var _mover: NpcMover = $Mover
@onready var _senses: CivilianSenses = $Senses
@onready var _brain: OwnerBrain = $Brain
@onready var _talk: Interactable = $Talk
@onready var _misdirect: Interactable = $Misdirect


func _ready() -> void:
	_suspicion.set_physics_process(false)  # the brain runs it in order (never runs if not active)
	_setup_talk()
	_setup_misdirect()
	if not active:
		hide()
		collision_layer = 0
		set_physics_process(false)
		return
	# IS-106: per-map overrides of the level (VenueTuning) over the scene's / global tuning.
	owner_tuning = VenueTuning.of(self, VenueTuning.OWNER, owner_tuning) as OwnerTuning
	civilian_tuning = VenueTuning.of(self, VenueTuning.CIVILIAN, civilian_tuning) as CivilianTuning
	_rules = civilian_tuning.rules_params(_perception.tuning)
	_contact = NpcContact.attach(self, false, _perception, report_suspicion, _on_pushed)
	var visual: Node2D = get_node_or_null(^"Visual") as Node2D
	if visual != null:
		TaskGlyph.attach(visual, self)  # IS-096: task glyph from replicated state (visual only)
	net_position = position
	facing = _perception.facing
	net_facing = facing
	if _is_host():
		_senses.bell_marker = owner_tuning.front_door_marker
		_senses.bell_radius = owner_tuning.bell_radius
		_senses.back_bell_door = owner_tuning.back_bell_door
		_senses.setup(_level(), civilian_tuning, _perception.tuning)
		_perception.set_arm_reach(owner_tuning.arm_reach_px)  # IS-098: 360 deg near band within arm reach
		_brain.owner_tuning = owner_tuning
		_brain.civilian_tuning = civilian_tuning
		_brain.agenda_seed = agenda_seed()
		_brain.talk_item = _talk
		_brain.social_action.connect(social_action.emit)
		_brain.recognized.connect(recognized.emit)
		_brain.setup(self, _perception, _suspicion, _agenda, _mover, _senses)
		_bind_hearing()
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, dump_state)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


## One step: brain + movement + replication on the host; smoothing on a client. Indicator from replicated state on every peer.
func step(delta: float) -> void:
	if not active:
		return
	var slide: Vector2 = _contact.step(delta)
	if _is_host():
		velocity = Vector2.ZERO if _contact.is_staggering() else _brain.step(delta)  # US-037: stagger stops the brain
		if not slide.is_zero_approx():
			velocity = slide
		move_and_slide()
		_publish()
	else:
		_follow(delta)
	last_event_age += delta
	_refresh_talk()
	_refresh_misdirect()
	var next: int = CivilianRules.bubble(_rules, net_meter, net_alarmed, bubble)
	if next != bubble:
		bubble = next
		_bubbles.append(next)


func brain() -> OwnerBrain:
	return _brain


func agenda() -> Agenda:
	return _agenda


func perception() -> Perception:
	return _perception


## On every peer: whether the owner is listening to a sound (LISTEN interrupt; from the replicated task name). The visual draws "?" (IS-087 AC4).
func is_listening() -> bool:
	return net_task == LISTEN_TASK


func suspicion() -> Suspicion:
	return _suspicion


func senses() -> CivilianSenses:
	return _senses


## Host API (AC4; US-010 STALL): changes suspicion of that player.
func apply_suspicion(peer_id: int, delta: float) -> void:
	_suspicion.apply_delta(peer_id, delta)


## Host API (US-016 AC5): a witness civilian told - suspicion `delta` to that player; `where` (the spot the witness saw, if finite)
## becomes the owner's last seen position (the questioning walks there).
func report_suspicion(peer_id: int, delta: float, where: Vector2 = Vector2.INF) -> void:
	if not _is_host() or not active or peer_id == 0:
		return
	_suspicion.apply_delta(peer_id, delta)
	if where.is_finite():
		_suspicion.hint_position(peer_id, where)


## Host API (US-016): customer in the queue (true if accepted; also true for the same customer's ongoing service).
func serve_customer(customer_id: int = 0) -> bool:
	return _brain.serve_customer(customer_id) if _is_host() and active else false


## Host API (US-016): customer's service state (OwnerBrain.Serve).
func serve_state(customer_id: int) -> int:
	return _brain.serve_state(customer_id) if _is_host() and active else OwnerBrain.Serve.NONE


## Host API (US-016): customer crossed the front door (bell).
func door_bell(door_pos: Vector2) -> void:
	if _is_host() and active:
		_brain.door_bell(door_pos)


## Host API (US-039): notice the robbery (OwnerBrain.Source).
func discover(source: int) -> bool:
	return _brain.discover(source) if _is_host() and active else false


## Host API (US-010 SEND): "is X in the back?" (`peer_id` the asking player; 0 = test).
func send_to_backroom(peer_id: int = 0) -> bool:
	return _brain.send_to_backroom(peer_id) if _is_host() and active else false


## Host API (US-010): whether SEND is accepted now (the counter's host blocker).
func can_send(peer_id: int = 0) -> bool:
	return _brain.can_send(peer_id) if _is_host() and active else false


## Host API (US-010 BUY): serves the player (register hook included). True if accepted.
func serve_player(peer_id: int) -> bool:
	return _brain.serve_player(peer_id) if _is_host() and active else false


## Host API (US-010): whether BUY is accepted now (the counter's host blocker).
func can_serve_player(peer_id: int) -> bool:
	return _brain.can_serve_player(peer_id) if _is_host() and active else false


## On every peer: whether the owner is active (may be off in a fixture; counter prompts check this).
func is_active() -> bool:
	return active


## On every peer: whether the owner shouted this heist (replicated).
func has_shouted() -> bool:
	return net_shouted


## On every peer: how much the gaze points at the talking player (gaze . direction; 0 if no talk). Measure of the STALL gaze lock.
func talk_gaze() -> float:
	var talker: int = _talk.busy_by
	if talker == 0:
		return 0.0
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == talker and node is Node2D:
			var to: Vector2 = (node as Node2D).global_position - global_position
			return facing.normalized().dot(to.normalized()) if not to.is_zero_approx() else 1.0
	return 0.0


## REDIRECT component (tests).
func misdirect_interactable() -> Interactable:
	return _misdirect


## On every peer: whether REDIRECT is open now (owner and neighbour prompts; alert >= threshold, 1 per heist). The cover condition is in
## the Interactable requirement (tag `cover`).
func misdirect_open() -> bool:
	return active and not net_misdirected \
		and Game.alert_level() >= _tools().misdirect_min_alert


## Host API (US-043 REDIRECT "they ran that way!"): a player with intact cover `peer_id` points -> neighbours within `misdirect_radius` of the
## speaker run for `misdirect_run_sec` opposite the escape point (`CivilianRules.misdirect_point`); the speaker gets +`misdirect_suspicion`
## at the owner; 1 per heist (`net_misdirected`). The owner's and the neighbour's component connect here. True if accepted.
func misdirect(peer_id: int) -> bool:
	if not _is_host() or not misdirect_open() or peer_id <= 0 or not _senses.cover_intact(peer_id):
		return false
	var player: Node2D = _senses.player(peer_id)
	if player == null:
		return false
	var tools: StoreToolsTuning = _tools()
	var at: Vector2 = CivilianSenses.position_of(player)
	var level: Node = _level()
	var point: Vector2 = CivilianRules.misdirect_point(at, _escape_point(level), tools.misdirect_run_px)
	var misled: int = 0
	var npcs: Node = level.call(&"npcs_root") as Node if level != null and level.has_method(&"npcs_root") else null
	if npcs != null:
		for node: Node in npcs.get_children():
			var npc: Node2D = node as Node2D
			if npc == null or not npc.has_method(&"mislead") or npc.global_position.distance_to(at) > tools.misdirect_radius:
				continue
			if bool(npc.call(&"mislead", point, tools.misdirect_run_sec)):
				misled += 1
	net_misdirected = true
	_suspicion.apply_delta(peer_id, tools.misdirect_suspicion)
	misdirects.append({"peer": peer_id, "chasers": misled, "point": [roundf(point.x), roundf(point.y)]})
	host_event(&"owner_misdirect", peer_id)
	Game.raise_session_event(MISDIRECT_SESSION_EVENT, {"peer": peer_id})
	social_action.emit(peer_id, &"misdirect")
	_refresh_misdirect()
	return true


## Escape point: Game's (S3 addendum), else the center of the first shape of the level's `EscapeZone` zone (S4 addendum); INF if none.
static func _escape_point(level: Node) -> Vector2:
	var p: Vector2 = Game.escape_point()
	if p.is_finite() or level == null or not level.has_method(&"zone"):
		return p
	var zone: Area2D = level.call(&"zone", &"EscapeZone") as Area2D
	if zone == null:
		return Vector2.INF
	for node: Node in zone.find_children("*", "CollisionShape2D", false, false):
		return (node as CollisionShape2D).global_position
	return zone.global_position


## Contact component (US-037; tests).
func contact() -> NpcContact:
	return _contact


## US-037 shove hook (host; NpcContact calls it after the calm cost). A teammate's shove while the owner holds someone completes the held
## player's PULL (existing rescue path) and returns true (no stagger: the brain goes to its own STAGGER); otherwise the brain reacts.
func _on_pushed(peer_id: int, calm: bool) -> bool:
	if not _is_host() or not active:
		return false
	if _shoulder_rescue(peer_id):
		return true
	_brain.on_pushed(peer_id, calm)
	return false


func _shoulder_rescue(peer_id: int) -> bool:
	var held: int = _brain.held_peer()
	if _brain.state() != OwnerBrain.State.HOLD or held == 0 or held == peer_id:
		return false
	var player: Node = _senses.player(held)
	var rescue: Interactable = player.get_node_or_null(RESCUE_PATH) as Interactable if player != null else null
	if rescue == null or not rescue.enabled:
		return false
	if rescue.busy_by != 0:
		rescue.host_abort()
	rescue.completed.emit(peer_id)  # same signal a finished PULL emits on the host (PlayerStatus frees and emits `rescued`)
	return true


## STALL component (tests, visual).
func talk_interactable() -> Interactable:
	return _talk


## Host API (US-010 BUY): loiter counter reset.
func reset_loiter(peer_id: int) -> void:
	_senses.reset_loiter(peer_id)


## Agenda seed (host; single point). `agenda_seed_override` >= 0 wins as is (test fixture); else owner_tuning.agenda_seed mixed with
## the session seed (IS-058b: `Game.session_seed()`; 0 = the data seed unchanged; SessionSeed.derive).
func agenda_seed() -> int:
	if agenda_seed_override >= 0:
		return agenda_seed_override
	return SessionSeed.derive(Game.session_seed(), owner_tuning.agenda_seed, SessionSeed.SALT_OWNER_AGENDA)


## Visual's cone: half angle (degrees; the task's if it narrows) and range (px).
func cone_half_angle() -> float:
	for task: AgendaTask in owner_tuning.tasks:
		if task != null and task.name == net_task and task.half_angle_deg > 0.0:
			return task.half_angle_deg
	return civilian_tuning.half_angle_deg


func cone_range() -> float:
	return civilian_tuning.view_range


## Drawn position of the held player (visual; INF if none).
func held_position() -> Vector2:
	if net_hold_peer == 0:
		return Vector2.INF
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == net_hold_peer and node is Node2D:
			return (node as Node2D).global_position
	return Vector2.INF


## Host: broadcasts the result event to everyone (signal in the same order on every peer).
func host_event(kind: StringName, peer_id: int) -> void:
	if not _is_host() or not EVENT_KINDS.has(kind):
		return
	if Net.is_online():
		_rpc_event.rpc(kind, peer_id)
	else:
		_rpc_event(kind, peer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_event(kind: StringName, peer_id: int) -> void:
	if not EVENT_KINDS.has(kind):
		return
	if _events.size() < MAX_EVENTS:
		_events.append(kind)
		_event_peers.append(peer_id)
	last_event = kind
	last_event_age = 0.0
	emit_signal(kind, peer_id)


## Result events seen on this peer (in order; at most MAX_EVENTS).
func events() -> Array[StringName]:
	return _events.duplicate()


func dump_state() -> Dictionary:
	var out := {
		"state": OwnerBrain.STATE_NAMES[clampi(net_state, 0, OwnerBrain.STATE_NAMES.size() - 1)],
		"task": net_task,
		"alarmed": net_alarmed,
		"events": _events.duplicate(),
		"event_peers": _event_peers.duplicate(),
		"bubbles": _bubbles.duplicate(),
		"talk_peer": _talk.busy_by,
		"talk_gaze": snappedf(talk_gaze(), 0.01),
		"facing": [snappedf(facing.x, 0.01), snappedf(facing.y, 0.01)],
		"shouted": net_shouted,
		"misdirected": net_misdirected,
	}
	if _is_host():
		var states: Array = _brain.fsm.history_rows(OwnerBrain.STATE_NAMES)
		var peaks: Dictionary = {}
		for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
			peaks[str(node.get_multiplayer_authority())] = 0.0  # a player with no meter at all also shows as 0
		for peer_id: int in _brain.peaks:
			peaks[str(peer_id)] = snappedf(float(_brain.peaks[peer_id]), 0.01)
		out["detections"] = _brain.detections.duplicate(true)
		out["peak"] = peaks
		out["agenda"] = _agenda.sequence.duplicate()
		out["states"] = states
		out["rescues"] = _brain.rescues.duplicate(true)
		out["shout_noises"] = _brain.shout_noises
		out["agenda_noises"] = _brain.agenda_noises.duplicate()
		out["discoveries"] = _brain.discoveries.duplicate(true)
		out["serves"] = _brain.serves_done
		out["register_opens"] = _brain.register_opens
		out["loiter_s"] = _senses.loiter_dump()
		out["player_serves"] = _brain.player_serves
		out["sent_windows"] = _brain.sent_windows.duplicate()
		out["send_costs"] = _brain.send_costs.duplicate(true)
		out["distractions"] = _brain.distractions.count
		out["phones_found"] = _brain.phones_found
		out["soothed"] = _brain.soothed.duplicate(true)
		out["misdirects"] = misdirects.duplicate(true)
		out["window_questions"] = _brain.window_questions.duplicate()
		out["log"] = _brain.event_log.rows()  # IS-081: event log (OwnerLog; refers to the records above by index)
		out["log_dropped"] = _brain.event_log.dropped
	return out


func _publish() -> void:
	net_position = position
	facing = _perception.facing
	net_facing = facing
	net_state = _brain.state()
	net_task = _agenda.task_name() if _brain.state() == OwnerBrain.State.AGENDA else &""
	net_alarmed = _brain.is_alarmed()
	net_hold_peer = _brain.held_peer()
	net_shouted = net_shouted or _brain.has_shouted
	var top: float = 0.0
	for peer_id: int in _suspicion.peers():
		top = maxf(top, _suspicion.value_of(peer_id))
	net_meter = SuspicionMeter.MAX_VALUE if net_alarmed else top


func _follow(delta: float) -> void:
	if position.distance_to(net_position) > SNAP_PX:
		position = net_position
	else:
		position = position.lerp(net_position, 1.0 - exp(-SMOOTHING * delta))
	if not net_facing.is_zero_approx():
		facing = facing.slerp(net_facing.normalized(), 1.0 - exp(-SMOOTHING * delta)).normalized()


func _set_task(value: StringName) -> void:
	if value == net_task:
		return
	net_task = value
	task_changed.emit(value)


## Store tools tuning of this level (IS-106: global default with the level's per-map overrides; VenueTuning caches the copy).
func _tools() -> StoreToolsTuning:
	return VenueTuning.of(self, VenueTuning.STORE_TOOLS, StoreToolsTuning.load_default()) as StoreToolsTuning


## STALL component (US-010): values from StoreToolsTuning; never enabled if the owner is not active.
func _setup_talk() -> void:
	var tools: StoreToolsTuning = _tools()
	_talk.action_key = TALK_ACTION_KEY
	_talk.hold_time = tools.talk_max_sec
	_talk.interact_range = tools.talk_range
	_talk.innocent = true
	_refresh_talk()


## From replicated state: talking is possible in calm states (agenda, LOOK, QUESTION; outside service and sent), before
## shouting.
func _refresh_talk() -> void:
	_talk.enabled = active and not net_shouted and TALK_STATES.has(net_state) \
		and not TALK_CLOSED_TASKS.has(net_task) and not misdirect_open()


## REDIRECT component (US-043): E, hold, range; innocent action; only a player with intact cover (tag `cover`).
func _setup_misdirect() -> void:
	var tools: StoreToolsTuning = _tools()
	setup_misdirect_item(_misdirect, tools)
	_misdirect.completed.connect(func(peer_id: int) -> void: misdirect(peer_id))
	_refresh_misdirect()


## The owner's and the neighbour's REDIRECT components are built with the same tuning.
static func setup_misdirect_item(item: Interactable, tools: StoreToolsTuning) -> void:
	item.action_key = MISDIRECT_ACTION_KEY
	item.hold_time = tools.misdirect_hold_sec
	item.interact_range = tools.misdirect_range
	item.innocent = true
	var need := InteractionRequirement.new()
	need.required_tag = COVER_TAG
	item.requirement = need


func _refresh_misdirect() -> void:
	_misdirect.enabled = misdirect_open()


## Hearing component: created if the scene has no `Hearing` and the generic class exists (code unchanged once US-009 lands).
func _bind_hearing() -> void:
	var hearing: Node = get_node_or_null(NodePath(String(HEARING_CLASS)))
	if hearing == null:
		var script: GDScript = _global_script(HEARING_CLASS) as GDScript
		if script != null and script.can_instantiate():
			hearing = script.new() as Node
			if hearing != null:
				hearing.name = String(HEARING_CLASS)
				add_child(hearing)
	if hearing != null and &"corner_spread_px" in hearing:
		hearing.set(&"corner_spread_px", owner_tuning.hearing_corner_px)  # US-010: shelf-end sound around the corner
	if hearing != null and hearing.has_signal(&"heard"):
		hearing.connect(&"heard", _brain.hear)


static func _global_script(cls: StringName) -> Script:
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(info.get("class", "")) == cls:
			return load(str(info["path"])) as Script
	return null


## Nearest ancestor with the Level API (S4; duck typing).
func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"marker"):
		node = node.get_parent()
	return node


func _is_host() -> bool:
	return _host_side()


## Host or offline (S2). Read from Net flags: at disconnect (dump, last frames) asking `multiplayer.is_server()` on a closed transport
## must not print an error (same pattern as Game).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
