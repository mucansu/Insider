class_name NpcContact
extends Node
## NPC contact component (US-037; KR-027; GDD §9.2, §12; S2, S11). Child `Contact` of an NPC root (owner, civilian, chaser), created by
## the root in code (`attach`) on every peer with the same name; it carries no RPC and no synchronizer. Rules are in `ContactRules` (core),
## numbers in `data/npc/contact_tuning.tres`.
## - Every peer: joins `GROUP` so the local player can predict its own contact slowdown (S2: movement is client-authoritative) and the
##   visual can lean; watches a shoved NPC's slide for the dump.
## - Host only (S2): the root calls `step(delta)` at the top of its step. Detection uses each free player's latest synchronized position
##   (`interaction_position`), mode (`net_mode`) and heading (`net_facing`); the local copy uses its own values. A shove: the counter n
##   (the pusher's shoves over all NPCs in the last window, capped) -> calm cost to this NPC (`suspicion_sink`) and to observers with line
##   of sight (`observe_push`) -> role hook (`push_hook`; owner: LOOK or the shoulder rescue, chaser: catch window reset) -> slide and
##   stagger (`is_staggering`: the root skips its brain) -> session event `npc_pushed {peer, npc, calm}` (Game, reliable, every peer; HUD/SFX
##   can listen) and a journal row.
## - Dump (S6, `--dump`): key "contact" = {pushes: [{t, peer, npc, calm, n, suspicion, observers, rescue, chaser}], count, calm, hot,
##   hot_chaser, hot_cost, npcs, slides: [{npc, peer, moved}], slid: {npc: px}}; the journal is shared by the NPCs of one level (meta
##   on their parent). Rows are written on the host; slides on every peer.

const GROUP := &"npc_contact"
const NODE_NAME := "Contact"
## Session event (Game, S3) and its HUD text key EVENT_NPC_PUSHED.
const PUSH_EVENT := &"npc_pushed"
const DUMP_KEY := "contact"
const JOURNAL_META := &"npc_contact_journal"
## How long every peer watches a shoved NPC to measure its slide (dump only; s) and rows kept per list.
const SLIDE_WATCH_SEC := 1.0
const MAX_ROWS := 64


## Shove journal of one level (dump).
class Journal:
	extends RefCounted
	var pushes: Array[Dictionary] = []
	var slides: Array[Dictionary] = []

	func add_push(row: Dictionary) -> void:
		if pushes.size() < MAX_ROWS:
			pushes.append(row)

	func add_slide(row: Dictionary) -> void:
		if slides.size() < MAX_ROWS:
			slides.append(row)

	func dump() -> Dictionary:
		var calm: int = 0
		var hot: int = 0
		var hot_cost: float = 0.0
		var hot_chaser: int = 0
		var npcs: Array[String] = []
		for row: Dictionary in pushes:
			if bool(row["calm"]):
				calm += 1
			else:
				hot += 1
				hot_chaser += 1 if bool(row["chaser"]) else 0
				hot_cost += float(row["suspicion"])
				for amount: Variant in (row["observers"] as Dictionary).values():
					hot_cost += float(amount)
			npcs.append(str(row["npc"]))
		var slid: Dictionary = {}
		for row: Dictionary in slides:
			var npc: String = str(row["npc"])
			slid[npc] = maxf(float(slid.get(npc, 0.0)), float(row["moved"]))
		return {"pushes": pushes.duplicate(true), "count": pushes.size(), "calm": calm, "hot": hot, "hot_chaser": hot_chaser,
			"hot_cost": hot_cost, "npcs": npcs, "slides": slides.duplicate(true), "slid": slid}


## Chaser rules (back contact is not a shove, longer stagger, immunity).
var is_chaser: bool = false
## Observer perception (range + line of sight); null = not an observer.
var perception: Perception = null
## `func(peer_id: int, amount: float, where: Vector2) -> void` (host): adds suspicion; empty = this NPC has no suspicion.
var suspicion_sink: Callable = Callable()
## `func(peer_id: int, calm: bool) -> bool` (host): role reaction after the costs; true = the shove became a rescue (slide, no stagger).
var push_hook: Callable = Callable()

var _params: ContactRules.Params = null
var _state := ContactRules.NpcState.new()
var _history := ContactRules.PushHistory.new()
var _journal: Journal = null
var _watch_left: float = 0.0
var _watch_from: Vector2 = Vector2.ZERO
var _watch_peer: int = 0
var _watch_max: float = 0.0


## Creates the component under `body` (call from the root's `_ready`, on every peer).
static func attach(body: Node2D, chaser: bool, observer: Perception, sink: Callable, hook: Callable) -> NpcContact:
	var contact := NpcContact.new()
	contact.name = NODE_NAME
	contact.is_chaser = chaser
	contact.perception = observer
	contact.suspicion_sink = sink
	contact.push_hook = hook
	body.add_child(contact)
	return contact


## Journal shared by the NPCs under the same parent (S4 `NPCs`); created on first use.
static func journal_of(body: Node) -> Journal:
	var holder: Node = body.get_parent() if body.get_parent() != null else body
	if holder.has_meta(JOURNAL_META):
		var known: Journal = holder.get_meta(JOURNAL_META) as Journal
		if known != null:
			return known
	var journal := Journal.new()
	holder.set_meta(JOURNAL_META, journal)
	return journal


## Shove heading of a player copy (ContactRules.push_heading): the local copy from its own mode and velocity, a remote copy (host view)
## from the synchronizer's latest mode and facing (speed from the interpolated velocity).
static func heading_of(p: ContactRules.Params, player: Player) -> Vector2:
	var local: bool = player.is_local()
	var mode: int = player.move_mode if local else player.net_mode
	var direction: Vector2 = player.velocity if local else player.net_facing
	return ContactRules.push_heading(p, mode == PlayerMotion.Mode.SPRINT, player.velocity.length(), direction)


func _ready() -> void:
	add_to_group(GROUP)
	_params = ContactTuning.load_default().rules_params()
	_journal = journal_of(get_parent())
	Game.session_event.connect(_on_session_event)
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, _journal.dump)


## Called by the root at the top of its step on every peer. Host: shove detection and response timers; returns the slide velocity for
## this step (ZERO when not sliding). Client: ZERO (slide measurement only).
func step(delta: float) -> Vector2:
	_watch(delta)
	if not _host_side():
		return Vector2.ZERO
	_history.step(delta, _params.push_window_sec)
	_detect()
	return _state.step(delta)


## Host: whether the brain is stopped (stagger).
func is_staggering() -> bool:
	return _state.is_staggering()


func is_sliding() -> bool:
	return _state.is_sliding()


## Host response state (tests, dump).
func state() -> ContactRules.NpcState:
	return _state


func params() -> ContactRules.Params:
	return _params


func journal() -> Journal:
	return _journal


## NPC body position (global; a client's smoothed copy).
func body_position() -> Vector2:
	var body: Node2D = get_parent() as Node2D
	return body.global_position if body != null else Vector2.INF


## NPC facing (root's `facing`; ZERO if unknown).
func facing() -> Vector2:
	var body: Node = get_parent()
	var value: Variant = body.get(&"facing") if body != null else null
	return value as Vector2 if value is Vector2 else Vector2.ZERO


## Cooldown a client assumes after a shove of this NPC (prediction): immunity for a chaser, else the re-shove time.
func shove_cooldown() -> float:
	return maxf(_params.repush_sec, _params.chaser_immune_sec) if is_chaser else _params.repush_sec


## Host: shoves of `peer_id` recorded by this NPC within the window.
func history_count(peer_id: int) -> int:
	return _history.count(peer_id)


## Host: shoves of `peer_id` over every NPC in the window (counter n before the cap).
func recent_pushes(peer_id: int) -> int:
	var n: int = 0
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: NpcContact = node as NpcContact
		if other != null:
			n += other.history_count(peer_id)
	return n


## Host: applies a shove by `peer_id` standing at `at` with unit `heading` (detection calls it; tests too).
func host_push(peer_id: int, at: Vector2, heading: Vector2, calm: bool) -> void:
	if not _host_side():
		return
	_history.add(peer_id)
	var n: int = ContactRules.push_count(_params, recent_pushes(peer_id))
	var cost: float = ContactRules.pushed_cost(_params, n, calm)
	var applied: float = 0.0
	if cost > 0.0 and suspicion_sink.is_valid():
		suspicion_sink.call(peer_id, cost, at)
		applied = cost
	var observers: Dictionary = _notify_observers(peer_id, at, ContactRules.observer_cost(_params, n, calm))
	var rescue: bool = push_hook.is_valid() and bool(push_hook.call(peer_id, calm))
	var stagger: float = 0.0 if rescue else (_params.chaser_stagger_sec if is_chaser else _params.stagger_sec)
	_state.start(_params, heading, stagger, _params.chaser_immune_sec if is_chaser else 0.0)
	var npc: String = String(get_parent().name)
	_journal.add_push({"t": snappedf(Time.get_ticks_msec() / 1000.0, 0.01), "peer": peer_id, "npc": npc, "calm": calm,
		"n": n, "suspicion": applied, "observers": observers, "rescue": rescue, "chaser": is_chaser})
	_start_watch(peer_id)
	if Net.is_online():  # offline (solo/test): no session event
		Game.raise_session_event(PUSH_EVENT, {"peer": peer_id, "npc": npc, "calm": calm})


## Host: an observer reacts to a shove by `peer_id` at `at`: within its view range and line of sight -> +`amount` suspicion (true).
func observe_push(peer_id: int, at: Vector2, amount: float) -> bool:
	if amount <= 0.0 or perception == null or not suspicion_sink.is_valid() or not perception.is_inside_tree():
		return false
	var from: Vector2 = perception.global_position
	if from.distance_to(at) > perception.params().view_range or not perception.has_line_of_sight(from, at):
		return false
	suspicion_sink.call(peer_id, amount, at)
	return true


func _detect() -> void:
	var body: Node2D = get_parent() as Node2D
	if body == null or not is_inside_tree() or not _state.can_be_pushed():
		return
	var calm: bool = ContactRules.is_calm(_params, Game.alert_level())
	var slack: float = 0.0 if calm else _params.hot_slack_px
	var here: Vector2 = body.global_position
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		var player: Player = node as Player
		if player == null or not player.is_free():
			continue
		var at: Vector2 = player.interaction_position()
		if not ContactRules.overlaps(_params, here, at, slack):
			continue
		var heading: Vector2 = heading_of(_params, player)
		if not ContactRules.in_front(_params, at, heading, here):
			continue
		if is_chaser and ContactRules.from_behind(_params, here, facing(), at):
			continue  # contact from a chaser's back is not a shove
		host_push(player.peer_id(), at, heading, calm)
		return


func _notify_observers(peer_id: int, at: Vector2, amount: float) -> Dictionary:
	var out: Dictionary = {}
	if amount <= 0.0:
		return out
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other: NpcContact = node as NpcContact
		if other != null and other != self and other.observe_push(peer_id, at, amount):
			out[String(other.get_parent().name)] = amount
	return out


## Every peer: a shove of this NPC seen through the session event starts the slide measurement (the host starts it in `host_push`).
func _on_session_event(kind: StringName, data: Dictionary) -> void:
	if kind != PUSH_EVENT or _host_side() or get_parent() == null:
		return
	if str(data.get("npc", "")) == String(get_parent().name):
		_start_watch(int(data.get("peer", 0)))


func _start_watch(peer_id: int) -> void:
	_watch_left = SLIDE_WATCH_SEC
	_watch_from = body_position()
	_watch_peer = peer_id
	_watch_max = 0.0


func _watch(delta: float) -> void:
	if _watch_left <= 0.0:
		return
	_watch_max = maxf(_watch_max, body_position().distance_to(_watch_from))
	_watch_left -= maxf(delta, 0.0)
	if _watch_left <= 0.0:
		_journal.add_slide({"npc": String(get_parent().name), "peer": _watch_peer, "moved": snappedf(_watch_max, 0.1)})


## Host or offline (S2; same pattern as the NPC roots).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
