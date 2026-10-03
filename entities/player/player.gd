class_name Player
extends CharacterBody2D
## Player character (US-004; S2, S3, S5, S6). Spawned by Game's PlayerSpawner: node name str(peer_id), authority on that peer, initial
## position from spawn data (S3). Movement/network logic lives here, in PlayerMotion (node-free rules) and SnapshotBuffer (interpolation);
## the visual is the `Visual` child and only reads: velocity, facing, move_mode (PlayerMotion.Mode), is_interacting(), peer_id(), slot(),
## display_name() and identity_changed (KR-003, KR-017: replaced by the procedural puppet in Phase 2 without touching this).
## Local (authoritative) copy: each physics step reads PlayerInput, computes velocity with PlayerMotion, move_and_slide (collision:
## world only; players pass through each other and NPCs, GDD §9.2/KR-021, US-008) and writes net_* fields. No prediction or server
## confirmation: the client is authoritative over its own movement (S2). MultiplayerSynchronizer sends net_* every 0.05 s (20 Hz, unreliable).
## Remote copy: when the synchronizer writes net_* (`synchronized`) the snapshot goes into SnapshotBuffer; position, velocity, facing and
## mode are produced each frame from the buffer, `PlayerTuning.interpolation_delay` (~100 ms) behind. With an empty buffer position is
## untouched (Game's late-join position catch-up, S3, writes it meanwhile).
## Automation dump (S6, `--dump` only): the local player registers "player_states": {"<peer_id>": {"mode": int, "facing": [x, y],
## "wall_frames": int, "underruns": int}} for every player copy in the process; wall_frames = physics frames the copy (local or
## interpolated) was inside a wall, underruns = frames the remote buffer ran dry (SnapshotBuffer).
## Interaction (US-005, S7 player side): every copy joins `Interactable.ACTOR_GROUP` and exposes the host-validated position via
## `interaction_position()`. Only the local copy's `PlayerInteraction` child finds targets and sends request/cancel each physics step
## (after movement); the three signals below (HUD contract) fire on the local player only. Dump registers "interaction":
## PlayerInteraction.stats(). "Interacting" state (IS-014; same indicator on every peer): local from PlayerInteraction (starts at press,
## ends on decision; GDD §12); remote derived each frame from the host-replicated `Interactable.busy_by` (component held by this
## player), no extra network field. Instant actions like doors are not visible remotely.
## Noise (US-009, S8): local copy only, after movement, emits step sound: mode radius (NoiseProfile: sprint 120, walk/sneak 0) > 0 and
## real speed (`get_real_velocity`; pushing a wall does not count) >= `step_min_speed`, at most once per `step_interval`
## (NoiseRules.Cadence) via `NoiseBus.emit_noise`; on a client the host validates (S2). Remote copies make no sound.
## Bag (US-012): carry state lives in the bag (Bag, host-authoritative); the player only reads it (`is_carrying`, `interaction_tags` ->
## `free_hands` if empty-handed) and reports sprinting (`is_sprinting`); the drop rule is in the bag (host).
## Look (US-011b AC3; GDD §6.5, S2): `look_dir` is client-authoritative. The local copy turns each physics step via LookRules from
## PlayerInput's look input (mouse/right stick/bot `"look"`; otherwise smooth k = 9 turn toward movement), capped at
## `VisionTuning.max_turn_deg_per_sec` (240 deg/s); `net_look` is an 8-bit angle (LookRules.quantize, 1.4 deg step) sent at 20 Hz in the
## movement synchronizer. Remote copies interpolate the angle in SnapshotBuffer (100 ms) with the same cap. A held/caught player's look
## freezes. The host uses look in no game decision (NPC perception included).
## Held/caught (US-008, S3 addendum): the `Status` child (PlayerStatus, host-authoritative subtree) carries FREE/HELD/CAUGHT and hosts the
## PULL rescue Interactable. The local copy freezes while not FREE (input unread, movement/interaction cut, zero velocity). Host API
## (`host_hold/host_catch/host_release`) is called by NPC brains; `status_changed` fires on every peer, `rescued` on the host only.
## Dump: "player_states" + "status".

signal identity_changed()
## Nearby interactable target changed (empty string = none); local player only (S7).
signal interaction_target_changed(action_key: String)
## Target of the Q (`intimidate`) prompt line changed (empty = none); local player only (S7 addendum, US-010).
signal interaction_alt_target_changed(action_key: String)
signal interaction_started(action_key: String, duration: float)
signal interaction_finished(success: bool)
## On every peer: held/caught state changed (PlayerStatus.State).
signal status_changed(state: int)
## Host only: held player was rescued by a teammate.
signal rescued(rescuer: int)

const DUMP_KEY := "player_states"
const INTERACTION_DUMP_KEY := "interaction"
const INTERACT_ACTION := &"interact"
## US-043: interaction tag of a player with intact cover, and the US-042 cover-broken session event.
const COVER_TAG := &"cover"
const COVER_EVENT := &"cover_broken"
const ALT_INTERACT_ACTION := &"intimidate"
const TUNING_PATH := "res://data/player_tuning.tres"
## Default radius if there is no body shape (S4: character diameter ~24 px).
const BODY_RADIUS := 12.0
## Margin subtracted from the body radius in the wall check (px): sliding contact does not count as "inside".
const WALL_CHECK_MARGIN := 2.0
## Physics layer world (architecture §4).
const WORLD_MASK := PhysicsLayers.WORLD
## Minimum speed (px/s) to count as sprinting (US-012): sprint key held while standing still is not sprinting.
const SPRINT_MOVING_SPEED := 20.0

@export var tuning: PlayerTuning

## Network fields: only the authoritative copy writes, the synchronizer sends (S2: position, facing, mode + sender time).
var net_position: Vector2 = Vector2.ZERO
var net_facing: Vector2 = Vector2.DOWN
var net_mode: int = PlayerMotion.Mode.WALK
## Look angle, 8-bit (LookRules.quantize; US-011b).
var net_look: int = LookRules.quantize(PI * 0.5)
## Moment net_position was written on the authority's own clock (s); interpolation draws against this clock.
var net_time: float = 0.0

## State the visual reads (on every copy; from the buffer on a remote copy).
var facing: Vector2 = Vector2.DOWN
var move_mode: int = PlayerMotion.Mode.WALK
## Look direction (unit; visual, fog and dump read it). Local: from input; remote: interpolated and capped.
var look_dir: Vector2 = Vector2.DOWN

var _local: bool = false
var _interacting: bool = false
var _buffer: SnapshotBuffer = null
var _slot: int = 0
var _display_name: String = ""
var _wall_query: PhysicsShapeQueryParameters2D = null
## In automation (S6) the wall check runs and is counted every physics frame.
var _track_walls: bool = false
var _wall_frames: int = 0
var _noise_profile: NoiseProfile = null
var _step_noise: NoiseRules.Cadence = null
var _look_angle: float = PI * 0.5
var _look_ready: bool = false
var _max_turn: float = 0.0
## US-043: whether this player's cover is broken (from the cover_broken session event).
var _cover_broken: bool = false

@onready var _input: PlayerInput = $PlayerInput
@onready var _sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _camera: Camera2D = $Camera2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _interaction: PlayerInteraction = $PlayerInteraction
@onready var _status: PlayerStatus = $Status


func _ready() -> void:
	if tuning == null:
		push_error("Player: tuning atanmamış; %s yükleniyor" % TUNING_PATH)
		tuning = load(TUNING_PATH) as PlayerTuning
	_local = is_multiplayer_authority()
	_buffer = SnapshotBuffer.new(tuning.interpolation_delay)
	_noise_profile = NoiseProfile.load_default()
	_step_noise = NoiseRules.Cadence.new(_noise_profile.step_interval)
	var vision: VisionTuning = load(VisionTuning.PATH) as VisionTuning
	_max_turn = deg_to_rad(vision.max_turn_deg_per_sec) if vision != null else 0.0
	add_to_group(Interactable.ACTOR_GROUP)
	_camera.enabled = _local
	if _local:
		_setup_camera()
		_publish()
		_interaction.target_changed.connect(interaction_target_changed.emit)
		_interaction.alt_target_changed.connect(interaction_alt_target_changed.emit)
		_interaction.started.connect(_on_interaction_started)
		_interaction.finished.connect(_on_interaction_finished)
		if not Args.dump_path.is_empty():
			Game.register_dump_provider(DUMP_KEY, _dump_states)
			Game.register_dump_provider(INTERACTION_DUMP_KEY, _interaction.stats)
	else:
		_sync.synchronized.connect(_on_synchronized)
	_track_walls = Args.is_automated()
	_status.changed.connect(status_changed.emit)
	_status.rescued.connect(rescued.emit)
	Game.players_changed.connect(_refresh_identity)
	Game.session_event.connect(_on_session_event)
	_refresh_identity()


func _physics_process(delta: float) -> void:
	if _local:
		_input.poll(delta)
		var free: bool = _status.is_free()
		var direction: Vector2 = _input.move_vector() if free else Vector2.ZERO
		if free:
			move_mode = PlayerMotion.mode_for(_input.is_held(&"sneak"), _input.is_held(&"sprint"))
			velocity = PlayerMotion.step_velocity(velocity, direction, move_mode, tuning, delta)
		else:
			move_mode = PlayerMotion.Mode.WALK
			velocity = Vector2.ZERO  # held/caught: freezes
		move_and_slide()
		facing = PlayerMotion.facing_for(facing, direction)
		if free:
			_look_angle = LookRules.step_look(_look_angle, _input.look_vector(global_position), facing, delta,
				_max_turn)
		look_dir = Vector2.from_angle(_look_angle)
		_publish()
		_emit_step_noise(delta)
		_interaction.tick(delta, free and _input.is_held(INTERACT_ACTION), global_position, peer_id(),
			interaction_tags(), free and _input.is_held(ALT_INTERACT_ACTION))
	if _track_walls and overlaps_world():
		_wall_frames += 1


func _process(delta: float) -> void:
	if _local:
		return
	_interacting = Interactable.held_by(get_tree(), peer_id()) != null
	var frame: SnapshotBuffer.Frame = _buffer.sample(_now())
	if frame == null:
		return
	position = frame.position
	velocity = frame.velocity
	facing = frame.facing
	move_mode = frame.mode
	if _look_ready:
		_look_angle = LookRules.turn(_look_angle, frame.look, delta, _max_turn)
	else:
		_look_angle = frame.look  # first data: sit without a turn animation
		_look_ready = true
	look_dir = Vector2.from_angle(_look_angle)


## Peer that owns this copy (S3: authority = peer_id).
func peer_id() -> int:
	return get_multiplayer_authority()


func is_local() -> bool:
	return _local


## Whether the session vision mode is directional (host rule, Game.vision_mode(); the visual reads it for the team look arc).
func is_directional_view() -> bool:
	return Game.vision_mode() == VisionGrid.Mode.DIRECTIONAL


## Drawn look angle (rad; angle of `look_dir`).
func look_angle() -> float:
	return _look_angle


## Player's join slot (Game.players(); colour in the visual from ThemeTokens.PLAYER_COLORS[slot]).
func slot() -> int:
	return _slot


func display_name() -> String:
	return _display_name


## Whether an interaction is running (visual reads): local from PlayerInteraction, remote from replicated busy_by (every frame).
func is_interacting() -> bool:
	return _interacting


func set_interacting(value: bool) -> void:
	_interacting = value


## Held/caught state (PlayerStatus.State; replicated on every peer).
func status() -> int:
	return _status.state


func is_free() -> bool:
	return _status.is_free()


func is_held() -> bool:
	return _status.is_held()


func is_caught() -> bool:
	return _status.is_caught()


## Time left in the hold window (s); 0 if not held.
func hold_left() -> float:
	return _status.hold_left()


## Catcher (host; S3 addendum `player_caught {peer, by}`).
func caught_by() -> StringName:
	return _status.caught_by()


func times_held() -> int:
	return _status.times_held()


## Host only: holds (caught after `window` s; can be rescued with PULL).
func host_hold(window: float) -> bool:
	return _status.host_hold(window)


## Host only: permanent catch; `by` is the catcher (&"chaser", &"owner"; S3 addendum `player_caught {peer, by}`).
func host_catch(by: StringName = &"") -> bool:
	return _status.host_catch(by)


## Host only: releases the hold.
func host_release() -> bool:
	return _status.host_release()


## Position at which the host validates interaction requests (S7, global): current position on the local copy; on a remote copy the latest
## position from the synchronizer (not the ~100 ms delayed interpolated drawn position; the S2 tolerance covers network latency only).
## Drawn position if no data has arrived yet.
func interaction_position() -> Vector2:
	if _local or net_time <= 0.0:
		return global_position
	var parent: Node2D = get_parent() as Node2D
	return parent.to_global(net_position) if parent != null else net_position


## Interaction tags (S7 `InteractionRequirement.required_tag`; the host reads the same method). US-012: `free_hands` if empty-handed
## (a bag can only be taken/received empty-handed).
func interaction_tags() -> Dictionary:
	var tags: Dictionary = {} if is_carrying() else {HeistRules.FREE_HANDS_TAG: 1}
	if not _cover_broken:
		tags[COVER_TAG] = 1  # US-043: cover intact ("like a customer"; REDIRECT requires this; the host also checks)
	return tags


## US-042 cover event (every peer): this player's cover broke (resets with the level: new node).
func _on_session_event(kind: StringName, data: Dictionary) -> void:
	if kind == COVER_EVENT and typeof(data.get("peer")) == TYPE_INT and int(data["peer"]) == peer_id():
		_cover_broken = true


## Whether carrying a bag (US-012; state is in the bag, host-authoritative and replicated).
func is_carrying() -> bool:
	return is_inside_tree() and Bag.carried_by(get_tree(), peer_id()) != null


## Whether sprinting (US-012 bag drop and the "Maratoncu" note): sprint mode and actually moving. On a remote copy from
## the interpolated mode and speed.
func is_sprinting() -> bool:
	return move_mode == PlayerMotion.Mode.SPRINT and velocity.length() > SPRINT_MOVING_SPEED


## Whether the body (edge margin WALL_CHECK_MARGIN subtracted) overlaps the world layer.
func overlaps_world() -> bool:
	if _wall_query == null:
		_wall_query = _make_wall_query()
	_wall_query.transform = global_transform
	return not get_world_2d().direct_space_state.intersect_shape(_wall_query, 1).is_empty()


## Dump/diagnostic state.
func motion_state() -> Dictionary:
	return {
		"mode": move_mode,
		"facing": facing,
		"look_deg": snappedf(rad_to_deg(_look_angle), 0.1),
		"wall_frames": _wall_frames,
		"underruns": _buffer.underrun_count() if _buffer != null else 0,
		"status": _status.state if _status != null else PlayerStatus.State.FREE,
	}


## Local camera zoom (IS-027): `--camera-zoom` if given, else `tuning.camera_zoom`.
func camera_zoom() -> float:
	return Args.camera_zoom if Args.camera_zoom > 0.0 else tuning.camera_zoom


## Camera limit (IS-027, global): map rect `map`, widened to the view size `view_size` (viewport / zoom) on any axis where the map is
## narrower, so the map stays centred (Camera2D would otherwise hug the right/bottom edge on a narrow limit). Node-free; unit-tested
## directly.
static func camera_limits(map: Rect2, view_size: Vector2) -> Rect2i:
	var out: Rect2 = map
	for axis: int in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		if map.size[axis] < view_size[axis]:
			out.position[axis] = map.get_center()[axis] - view_size[axis] * 0.5
			out.size[axis] = view_size[axis]
	var start := Vector2i(floori(out.position.x), floori(out.position.y))
	var end := Vector2i(ceili(out.end.x), ceili(out.end.y))
	return Rect2i(start, end - start)


func _setup_camera() -> void:
	_camera.zoom = Vector2.ONE * camera_zoom()
	_apply_camera_limits()
	get_viewport().size_changed.connect(_apply_camera_limits)
	_camera.make_current()
	_camera.reset_smoothing()


## Clamps to the level's map rect (S4 `map_rect()`; duck typed on an ancestor); unbounded if no level.
func _apply_camera_limits() -> void:
	var map: Rect2 = _level_map_rect()
	if not map.has_area():
		return
	var limits: Rect2i = camera_limits(map, get_viewport_rect().size / _camera.zoom)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y


func _level_map_rect() -> Rect2:
	var node: Node = get_parent()
	while node != null:
		if node.has_method(&"map_rect"):
			var rect: Rect2 = node.call(&"map_rect")
			var level: Node2D = node as Node2D
			return level.global_transform * rect if level != null else rect
		node = node.get_parent()
	return Rect2()


func _publish() -> void:
	net_position = position
	net_facing = facing
	net_mode = move_mode
	net_look = LookRules.quantize(_look_angle)
	net_time = _now()


## Local copy: sprint step sound (S8). Kind and radius from the mode; cadence and speed threshold from NoiseProfile.
func _emit_step_noise(delta: float) -> void:
	var kind: StringName = NoiseProfile.KIND_WALK
	match move_mode:
		PlayerMotion.Mode.SNEAK:
			kind = NoiseProfile.KIND_SNEAK
		PlayerMotion.Mode.SPRINT:
			kind = NoiseProfile.KIND_RUN
	var radius: float = _noise_profile.radius_for(kind)
	var stepping: bool = radius > 0.0 and get_real_velocity().length() >= _noise_profile.step_min_speed
	if _step_noise.tick(delta, stepping):
		NoiseBus.emit_noise(global_position, radius, kind, peer_id())


func _on_interaction_started(action_key: String, duration: float) -> void:
	_interacting = true
	interaction_started.emit(action_key, duration)


func _on_interaction_finished(success: bool) -> void:
	_interacting = false
	interaction_finished.emit(success)


func _on_synchronized() -> void:
	_buffer.push(net_time, _now(), net_position, net_facing, net_mode, LookRules.dequantize(net_look))


func _refresh_identity() -> void:
	var entry: Dictionary = Game.players().get(peer_id(), {})
	var new_slot: int = maxi(0, int(entry.get("slot", 0)))
	var new_name: String = str(entry.get("name", ""))
	if new_slot == _slot and new_name == _display_name:
		return
	_slot = new_slot
	_display_name = new_name
	identity_changed.emit()


func _make_wall_query() -> PhysicsShapeQueryParameters2D:
	var radius: float = BODY_RADIUS
	var circle: CircleShape2D = _body_shape.shape as CircleShape2D
	if circle != null:
		radius = circle.radius
	var shape := CircleShape2D.new()
	shape.radius = maxf(1.0, radius - WALL_CHECK_MARGIN)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = WORLD_MASK
	query.exclude = [get_rid()]
	return query


## State of all player copies in the process (S6 dump).
func _dump_states() -> Dictionary:
	var out: Dictionary = {}
	var root: Node = get_parent()
	if root == null:
		return out
	for child: Node in root.get_children():
		var player: Player = child as Player
		if player != null:
			out[str(player.peer_id())] = player.motion_state()
	return out


static func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
