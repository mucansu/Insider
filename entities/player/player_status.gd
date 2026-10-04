class_name PlayerStatus
extends Node2D
## Player's held/caught state (US-008 AC7; S2, S3 addendum, S7; GDD §9.3; KR-019 K3). The player's `Status` child. The player root is
## client-authoritative (own movement) but this subtree is **host-authoritative** (`_enter_tree` sets authority to 1; same on every peer):
## state changes only on the host and replicates via its own MultiplayerSynchronizer (on change, reliable). Visual and player only read it.
## - FREE -> HELD (`host_hold(window)`: owner held; CAUGHT when the window expires) -> FREE (`Rescue` done: teammate within 32 px holds
##   "pull" 1 s) or CAUGHT (permanent; `host_catch()`: neighbour caught, no rescue).
## - `Rescue` (Interactable, S7) is enabled only while HELD; on completion the host emits `rescued(rescuer)`.
## - Host events also reach everyone via `Game.raise_session_event` (US-012 result is built from them): `player_held {peer, window}`,
##   `player_caught {peer, by}` (by: &"owner" | &"chaser"), `player_rescued {peer, by}`.
## - PULL is validated on the host: the rescuer cannot be the held player and must be free (held/caught are rejected).
## - The window counter runs on the host; a client counts `hold_left()` locally from the moment it sees HELD (display only).
## - IS-081 AC3: once the job result is out (`Game.heist_result()` not empty) the status is final on the host: no new hold or catch and
##   an open hold window does not turn into CAUGHT. NPCs keep running on the end screen; without this a player the police already
##   caught (no event) could get a late `player_caught {by: chaser|owner}` that heist_end would take as the catcher. `player_caught` is
##   raised at most once per player node (CAUGHT is terminal); several in one session come from separate runs ("Bir daha").

## On every peer: state changed.
signal changed(state: int)
## Host only: held player was rescued (`rescuer` = pulling peer).
signal rescued(rescuer: int)

enum State { FREE, HELD, CAUGHT }

const SYNC_NAME := "StatusSync"
const HOST_PEER := 1
## PULL (GDD §9.3): teammate within 32 px holds for 1 s.
const RESCUE_KEY := "INTERACT_RESCUE"
const RESCUE_RANGE := 32.0
const RESCUE_HOLD_SEC := 1.0
## Catcher when the hold window expires (only the owner holds).
const HOLD_CATCHER := &"owner"

## Replicated state (host writes).
var state: int = State.FREE:
	set = _set_state
## Window of the last hold (s; replicated, the client counter starts from it).
var hold_window: float = 0.0

var _hold_left: float = 0.0
var _times_held: int = 0
var _caught_by: StringName = &""

@onready var _rescue: Interactable = $Rescue


func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER, true)


func _ready() -> void:
	_rescue.action_key = RESCUE_KEY
	_rescue.hold_time = RESCUE_HOLD_SEC
	_rescue.interact_range = RESCUE_RANGE
	_rescue.completed.connect(_on_rescue_completed)
	_rescue.actor_filter = _rescuer_allowed
	add_child(_make_sync())
	_apply()


func _physics_process(delta: float) -> void:
	step(delta)


## Window counter: on the host, CAUGHT at expiry; on a client a display counter only.
func step(delta: float) -> void:
	if state != State.HELD:
		return
	_hold_left = maxf(_hold_left - maxf(delta, 0.0), 0.0)
	if _hold_left <= 0.0 and _is_host() and not _heist_over():
		_caught_by = HOLD_CATCHER
		_become(State.CAUGHT)


func is_free() -> bool:
	return state == State.FREE


func is_held() -> bool:
	return state == State.HELD


func is_caught() -> bool:
	return state == State.CAUGHT


## Time left in the hold window (s; 0 if not HELD).
func hold_left() -> float:
	return _hold_left if state == State.HELD else 0.0


## Catcher (host; empty if not caught): &"owner" | &"chaser".
func caught_by() -> StringName:
	return _caught_by


## Times held this game (host).
func times_held() -> int:
	return _times_held


## Host only: holds a free player for `window` s. False if not accepted.
func host_hold(window: float) -> bool:
	if not _is_host() or state != State.FREE or _heist_over():
		return false
	_times_held += 1
	hold_window = maxf(window, 0.0)
	_become(State.HELD)
	return true


## Host only: permanent catch; `by` is the catcher (S3 addendum: &"chaser" neighbour, &"owner" hold window expired).
func host_catch(by: StringName = &"") -> bool:
	if not _is_host() or state == State.CAUGHT or _heist_over():
		return false
	_caught_by = by
	_become(State.CAUGHT)
	return true


## PULL filter (host): the rescuer cannot be the held player; freeness is checked in Interactable (`not_free`).
func _rescuer_allowed(peer_id: int, _actor: Node) -> bool:
	return peer_id != _peer()


## Host only: releases the held player (rescue).
func host_release() -> bool:
	if not _is_host() or state != State.HELD:
		return false
	_become(State.FREE)
	return true


func _on_rescue_completed(rescuer: int) -> void:
	if state != State.HELD:
		return
	_become(State.FREE)
	rescued.emit(rescuer)
	_raise(&"player_rescued", {"peer": _peer(), "by": rescuer})


func _become(value: int) -> void:
	state = value
	match value:
		State.HELD:
			_raise(&"player_held", {"peer": _peer(), "window": hold_window})
		State.CAUGHT:
			_raise(&"player_caught", {"peer": _peer(), "by": _caught_by})


func _set_state(value: int) -> void:
	if value == state:
		return
	state = value
	if value == State.HELD:
		_hold_left = hold_window
	if is_node_ready():
		_apply()
	changed.emit(value)


func _apply() -> void:
	if _rescue != null:
		_rescue.enabled = state == State.HELD


func _raise(kind: StringName, data: Dictionary) -> void:
	if _is_host() and Net.is_online():  # offline (solo/test): no session event
		Game.raise_session_event(kind, data)


## Peer that owns the player (authority of the player root).
func _peer() -> int:
	var parent: Node = get_parent()
	return parent.get_multiplayer_authority() if parent != null else 0


func _is_host() -> bool:
	return _host_side()


## The job result is out (IS-081 AC3): the status no longer changes toward held/caught.
static func _heist_over() -> bool:
	return not Game.heist_result().is_empty()


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:hold_window", ".:state"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.replication_config = config
	return sync


## Host or offline (S2). Read from Net flags: at disconnect (dump, last frames) asking `multiplayer.is_server()` on a closed transport
## must not print an error (same pattern as Game).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
