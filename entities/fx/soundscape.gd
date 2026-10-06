class_name Soundscape
extends Node
## Local ambience + music (US-047 AC3-AC4): child `Soundscape` of the player scene; only the LOCAL copy keeps it (remote copies free it on
## their first frame). Four non-positional looping players, levels and files from `data/sfx_catalog.tres` `loops`:
## - `amb_street` (Ambience bus): outside bed, crossfades with
## - `amb_room` + `amb_murmur` (Ambience bus): shop room tone + quiet customer murmur, inside (AmbienceRules: tile under the player, any map);
## - `music_calm` (Music bus): MusicRules.Mixer — cut on threat (alert >= 2 rise, shout/caught/police event), 4 s silence, fade back while the
##   heist runs; off after `heist_finished` (end screen stingers play alone).
## Reads game state only through S3/S4 (Game `alert_level()`, `session_event`, `heist_finished`, `current_level()` -> Level `layout()` ->
## `rows`, duck typed: entities/ does not reference levels/, §6).
## Headless: volumes are computed but streams are not started (SfxCatalog.playback_enabled; IS-029 leak gate).

const NODE_NAME := &"Soundscape"
const STREET := &"amb_street"
const ROOM := &"amb_room"
const MURMUR := &"amb_murmur"
const MUSIC := &"music_calm"
const LOOP_IDS: Array[StringName] = [STREET, ROOM, MURMUR, MUSIC]
## Silent floor (dB).
const SILENT_DB := -80.0

## Game source (S3, duck typed); the Game autoload if left empty. Tests inject a fake.
var game: Object = null
## If empty, `SfxCatalog.load_default()`.
var catalog: SfxCatalog = null
## Tests: layout rows to read instead of `game.current_level().layout().rows` (owner position is then level-local).
var rows_override: PackedStringArray = PackedStringArray()
## Tests: run even if the owner is not the local player.
var force_active: bool = false
## Current place and inside weight (0 = outside, 1 = inside).
var place: AmbienceRules.Place = AmbienceRules.Place.OUTSIDE
var inside: float = 0.0
var music := MusicRules.Mixer.new()

var _players: Dictionary = {}
var _started: bool = false
var _snapped: bool = false


func _process(delta: float) -> void:
	if not _started:
		if not (force_active or _owner_is_local()):
			queue_free()  # remote copy: ambience/music belong to the local player only
			return
		start()
	advance(delta)


## Binds to Game and creates the loop players (idempotent).
func start() -> void:
	if _started:
		return
	_started = true
	if catalog == null:
		catalog = SfxCatalog.load_default()
	if game == null:
		game = get_node_or_null(^"/root/Game")
	if game != null:
		if game.has_signal(&"session_event"):
			game.connect(&"session_event", _on_session_event)
		if game.has_signal(&"heist_finished"):
			game.connect(&"heist_finished", _on_heist_finished)
	for id: StringName in LOOP_IDS:
		var entry: SfxEntry = catalog.find_loop(id)
		var player := AudioStreamPlayer.new()
		player.name = String(id)
		player.volume_db = SILENT_DB
		if entry != null:
			player.stream = entry.stream
			player.bus = entry.bus
		add_child(player)
		_players[id] = player
		if entry != null and entry.stream != null and SfxCatalog.playback_enabled():
			player.play()


## One mix step: place from the owner's tile, crossfade, music gain; applies volumes.
func advance(delta: float) -> void:
	var tiles: Node2D = _layout()
	var rows: PackedStringArray = rows_override
	if rows.is_empty() and tiles != null:
		var value: Variant = tiles.get(&"rows")
		rows = value as PackedStringArray if typeof(value) == TYPE_PACKED_STRING_ARRAY else PackedStringArray()
	place = AmbienceRules.place_at(rows, _owner_level_position(tiles), place)
	if not _snapped:
		_snapped = true
		inside = 1.0 if place == AmbienceRules.Place.INSIDE else 0.0  # spawn: no fade from the wrong bed
	else:
		inside = AmbienceRules.step_mix(inside, place, delta)
	var level: int = int(game.call(&"alert_level")) if game != null and game.has_method(&"alert_level") else 0
	var music_gain: float = music.step(delta, level)
	_apply(STREET, AmbienceRules.gain(1.0 - inside))
	_apply(ROOM, AmbienceRules.gain(inside))
	_apply(MURMUR, AmbienceRules.gain(inside))
	_apply(MUSIC, music_gain)


## Current volume of a loop player (dB; SILENT_DB if absent). Tests and diagnostics.
func volume_of(id: StringName) -> float:
	var player: AudioStreamPlayer = _players.get(id) as AudioStreamPlayer
	return player.volume_db if player != null else SILENT_DB


func player_of(id: StringName) -> AudioStreamPlayer:
	return _players.get(id) as AudioStreamPlayer


func _apply(id: StringName, linear: float) -> void:
	var player: AudioStreamPlayer = _players.get(id) as AudioStreamPlayer
	var entry: SfxEntry = catalog.find_loop(id) if catalog != null else null
	if player == null or entry == null:
		return
	player.volume_db = AmbienceRules.to_db(entry.volume_db, linear)


## The level's tile layout node (Level `layout()`, S4); null without a level.
func _layout() -> Node2D:
	if game == null or not game.has_method(&"current_level"):
		return null
	var level: Node = game.call(&"current_level") as Node
	if level == null or not level.has_method(&"layout"):
		return null
	return level.call(&"layout") as Node2D


## Owner position in the layout's local space (tile grid); the owner's own position without a layout in the tree.
func _owner_level_position(tiles: Node2D) -> Vector2:
	var holder: Node2D = get_parent() as Node2D
	if holder == null:
		return Vector2.ZERO
	return tiles.to_local(holder.global_position) if tiles != null and tiles.is_inside_tree() else holder.position


func _owner_is_local() -> bool:
	var holder: Node = get_parent()
	return holder != null and holder.has_method(&"is_local") and bool(holder.call(&"is_local"))


func _on_session_event(kind: StringName, _data: Dictionary) -> void:
	if MusicRules.is_threat_event(kind):
		music.trigger()


func _on_heist_finished(_result: Dictionary) -> void:
	music.finish()
