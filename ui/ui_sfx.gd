class_name UiSfx
extends AudioStreamPlayer
## UI sound (IS-024): non-positional player on the screen's child node (`UiSfx`). Events play by name from `data/sfx_catalog.tres` (SfxCatalog); the same event is rate-limited.
## `wire_buttons(screen)` binds buttons: focus -> ui_focus, press -> ui_click. Sound only accompanies; no information is sound-only (ses-ve-sfx §1 rule 7).

## Event played (only when actually played; tests read it).
signal played(event: StringName)

const NODE_NAME := &"UiSfx"
const CLICK := &"ui_click"
const FOCUS := &"ui_focus"

## If empty, `SfxCatalog.load_default()` on first use.
var catalog: SfxCatalog = null
## Clock (s); tests override. Falls back to `SfxCatalog.now_sec()` if invalid.
var clock: Callable

var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## UI player of `owner_node`; created if missing.
static func of(owner_node: Node) -> UiSfx:
	var existing: UiSfx = owner_node.get_node_or_null(NodePath(NODE_NAME)) as UiSfx
	if existing != null:
		return existing
	var player := UiSfx.new()
	player.name = NODE_NAME
	owner_node.add_child(player)
	return player


## Binds focus and press sounds to every button under `root`; returns the player.
static func wire_buttons(root: Node) -> UiSfx:
	var player: UiSfx = of(root)
	for node: Node in root.find_children("*", "BaseButton", true, false):
		wire_button(node as BaseButton, player)
	return player


## Binds focus and press sounds to one button; skips it if already bound to a UI player (no double sound).
## Use for buttons created after the screen is built (e.g. the invite address list).
static func wire_button(button: BaseButton, player: UiSfx) -> void:
	if is_wired(button):
		return
	button.focus_entered.connect(player.play_event.bind(FOCUS))
	button.pressed.connect(player.play_event.bind(CLICK))


## Whether the button's pressed signal is bound to a UI player.
static func is_wired(button: BaseButton) -> bool:
	for c: Dictionary in button.pressed.get_connections():
		if (c["callable"] as Callable).get_object() is UiSfx:
			return true
	return false


## UI player of `node`'s nearest ancestor (if the screen set it up via `wire_buttons`); null otherwise.
static func find_for(node: Node) -> UiSfx:
	var current: Node = node.get_parent()
	while current != null:
		var player: UiSfx = current.get_node_or_null(NodePath(NODE_NAME)) as UiSfx
		if player != null:
			return player
		current = current.get_parent()
	return null


## Plays the event; false (silent) if it is not in the catalogue, the player is not in the tree, or the minimum interval has not elapsed.
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
	if SfxCatalog.playback_enabled():
		play()
	played.emit(event)
	return true


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else SfxCatalog.now_sec()
