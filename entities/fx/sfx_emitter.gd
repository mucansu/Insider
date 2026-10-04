class_name SfxEmitter
extends AudioStreamPlayer2D
## Positional sound player (IS-024): child node (`Sfx`) of its owner; plays events by name from `data/sfx_catalog.tres`
## (SfxCatalog). Not an autoload (§6); props set it up in `_ready` via `SfxEmitter.of(self)`.
## Listener: the view's Camera2D (local avatar); attenuation by AudioStreamPlayer2D, audible range from the entry's `max_distance`
## (noise radius x 2), or DEFAULT_MAX_DISTANCE if 0. Same event is rate-limited by `SfxEntry.min_interval`. Repeating sound:
## `repeat_while(event, condition)`. Replicated state sound (`play_on_change`): on a client the FIRST sync packet is baseline
## (late join/reconnect) and applied silently; later changes play. Host and offline always play. Sound is local only.

## Event played (only when actually played; for tests and future subtitles/visual pairs).
signal played(event: StringName)

const NODE_NAME := &"Sfx"
## When the entry gives no distance (AudioStreamPlayer2D default).
const DEFAULT_MAX_DISTANCE := 2000.0

## If empty, `SfxCatalog.load_default()` on first use.
var catalog: SfxCatalog = null
## Clock (s); tests override. Falls back to `SfxCatalog.now_sec()` if invalid.
var clock: Callable
## Client has not yet received the first sync packet: `play_on_change` is silent (baseline). Set in `_ready`;
## cleared when the owner's synchronizer emits `delta_synchronized`/`synchronized` (`mark_synced`).
var baseline_pending: bool = false

var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _repeat_event: StringName = &""
var _repeat_while: Callable
var _played: int = 0
var _silent: int = 0


func _ready() -> void:
	_rng.randomize()
	set_process(_repeat_while.is_valid())
	var holder: Node = get_parent()
	if holder == null:
		return
	for node: Node in holder.find_children("*", "MultiplayerSynchronizer", false, false):
		var sync: MultiplayerSynchronizer = node as MultiplayerSynchronizer
		baseline_pending = not multiplayer.is_server()
		sync.delta_synchronized.connect(mark_synced)
		sync.synchronized.connect(mark_synced)


## `owner_node`'s player; created if missing.
static func of(owner_node: Node) -> SfxEmitter:
	var existing: SfxEmitter = owner_node.get_node_or_null(NodePath(NODE_NAME)) as SfxEmitter
	if existing != null:
		return existing
	var emitter := SfxEmitter.new()
	emitter.name = NODE_NAME
	owner_node.add_child(emitter)
	return emitter


## One-line call: plays the event on `owner_node`'s player.
static func play_on(owner_node: Node, event: StringName) -> bool:
	return of(owner_node).play_event(event)


## Replicated state change sound: the first sync packet (baseline) is silent on clients.
static func play_on_change(owner_node: Node, event: StringName) -> bool:
	var emitter: SfxEmitter = of(owner_node)
	if emitter.baseline_pending:
		emitter.count_silent()
		return false
	return emitter.play_event(event)


## First sync packet applied: later changes play.
func mark_synced() -> void:
	baseline_pending = false


func count_silent() -> void:
	_silent += 1


## For the dump (S6 "props"): count of played and baseline-silenced sounds.
func stats() -> Dictionary:
	return {"played": _played, "silent": _silent}


## Plays the event; false (silent) if missing from catalog, file missing, player not in tree, or min interval not elapsed.
func play_event(event: StringName) -> bool:
	if not is_inside_tree():
		return false
	if catalog == null:
		catalog = SfxCatalog.load_default()
	var entry: SfxEntry = catalog.take(event, _last_played, _now())
	if entry == null:
		return false
	stream = entry.stream
	volume_db = entry.volume_db
	pitch_scale = entry.pick_pitch(_rng)
	max_distance = entry.max_distance if entry.max_distance > 0.0 else DEFAULT_MAX_DISTANCE
	if SfxCatalog.playback_enabled():
		play()
	_played += 1
	played.emit(event)
	return true


## While `condition` returns true, tries to play `event` every frame (rhythm = entry's min interval).
func repeat_while(event: StringName, condition: Callable) -> void:
	_repeat_event = event
	_repeat_while = condition
	set_process(condition.is_valid())


func _process(_delta: float) -> void:
	if _repeat_while.is_valid() and bool(_repeat_while.call()):
		play_event(_repeat_event)


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else SfxCatalog.now_sec()
