class_name VisionRules
extends RefCounted
## Vision session rules (US-011b AC2/AC6/AC7; GDD §6.5; mimari.md S2, S3 addendum "Vision addenda", KR-022/KR-023). Node-free: Game and visuals only ask these rules.
## - Vision mode (`vision_mode`, VisionGrid.Mode: 0 peripheral 360 deg, 1 directional) is a host game rule: only the host picks it, before the level starts; replicated to clients; a client writing it has no effect.
## - Exposure (`exposure`, per player): 0 hidden, 1 visible (in an observer's cone and line of sight), 2 seen (any observer's suspicion of them >= SEEN_THRESHOLD). Only the host writes it (from the perception/suspicion summary); clients only apply the replicated value.
## - Sound ring draw condition: source tile visible (or peripheral) OR the local player is within the sound's effective radius (x wall_factor without line of sight; same rule as NoiseBus/Hearing, NoiseRules).
## - Memory latch (`Latch`): a prop visual freezes in its last seen state on an unseen tile.

enum Exposure { HIDDEN = 0, VISIBLE = 1, SEEN = 2 }

## "Seen" threshold (GDD §6.1: 30 "?").
const SEEN_THRESHOLD := 30.0
## Interval at which exposure is computed and broadcast on the host (s; 10 Hz).
const EXPOSURE_INTERVAL_SEC := 0.1
## z_index for things that must draw above the fog (FogLayer.Z_INDEX = 50): teammate, silhouette, ghost, heard sound ring (mimari.md S3 addendum: > 50).
const ABOVE_FOG_Z := 60
## Group of NPC visuals (the Game dump `visible_npcs` reads from this group; duck typing `is_fully_visible()`).
const NPC_VISUAL_GROUP := &"vision_npc_visuals"
## Max exposure transitions kept per peer in the dump.
const MAX_HISTORY := 32


## Exposure from one observer's view of a player: suspicion >= threshold -> 2; in cone and line of sight -> 1; else 0.
static func exposure_level(in_view: bool, suspicion: float) -> int:
	if suspicion >= SEEN_THRESHOLD:
		return Exposure.SEEN
	return Exposure.VISIBLE if in_view else Exposure.HIDDEN


## Highest across several observers.
static func combine(a: int, b: int) -> int:
	return maxi(a, b)


## Whether the sound ring is drawn on this peer: source tile seen OR the local player hears the sound (distance <= effective radius; radius x wall_factor without line of sight).
static func ring_shown(source_seen: bool, distance: float, radius: float, line_of_sight: bool,
		wall_factor: float) -> bool:
	if source_seen:
		return true
	return NoiseRules.can_hear(distance, NoiseRules.effective_radius(radius, line_of_sight, wall_factor))


## Memory latch: follows the live value while seen, holds the last seen one when unseen. If never seen `has_value()` is false
## (not drawn); without fog the caller always passes `seen = true`.
class Latch:
	extends RefCounted
	var _value: Variant = null
	var _has: bool = false

	## The value to show this step.
	func update(seen: bool, live: Variant) -> Variant:
		if seen:
			_value = live
			_has = true
		return _value

	func has_value() -> bool:
		return _has

	func value() -> Variant:
		return _value


## Session vision state (Game holds it): mode and player exposures. `authority` = this peer is the host (or offline);
## write methods have no effect without authority and return false.
class Session:
	extends RefCounted
	var _mode: int = 0
	## peer_id -> 0/1/2
	var _exposure: Dictionary = {}
	## peer_id -> Array[int] (transition history; first element is the first known level)
	var _history: Dictionary = {}

	func _init(default_mode: int = 0) -> void:
		_mode = clampi(default_mode, 0, VisionGrid.MODE_NAMES.size() - 1)

	func mode() -> int:
		return _mode

	## Host rule: only with authority and while no level is active; an invalid mode is rejected.
	func set_mode(mode: int, authority: bool, level_active: bool) -> bool:
		if not authority or level_active or mode < 0 or mode >= VisionGrid.MODE_NAMES.size():
			return false
		_mode = mode
		return true

	## Replicated mode (client; comes from the host). Ignored if invalid.
	func apply_mode(mode: int) -> bool:
		if mode < 0 or mode >= VisionGrid.MODE_NAMES.size() or mode == _mode:
			return false
		_mode = mode
		return true

	func exposure(peer_id: int) -> int:
		return int(_exposure.get(peer_id, Exposure.HIDDEN))

	func exposures() -> Dictionary:
		return _exposure.duplicate()

	func history() -> Dictionary:
		return _history.duplicate(true)

	## Host: writes exposures (no effect and returns empty without authority). Returns: changed peer -> new level.
	func write(levels: Dictionary, authority: bool) -> Dictionary:
		if not authority:
			return {}
		return apply(levels)

	## Replicated full table (client; on the host `write` uses the same path). A peer missing from the table counts as 0.
	## Returns: changed peer -> new level.
	func apply(levels: Dictionary) -> Dictionary:
		var changed: Dictionary = {}
		var peers: Array = _exposure.keys()
		for key: Variant in levels:
			if typeof(key) == TYPE_INT and not peers.has(key):
				peers.append(key)
		for peer: Variant in peers:
			var peer_id: int = int(peer)
			var raw: Variant = levels.get(peer_id, Exposure.HIDDEN)
			var level: int = clampi(int(raw) if typeof(raw) == TYPE_INT else 0, Exposure.HIDDEN, Exposure.SEEN)
			if not _history.has(peer_id):
				_history[peer_id] = [Exposure.HIDDEN]
			var was: int = exposure(peer_id)
			if levels.has(peer_id):
				_exposure[peer_id] = level
			else:
				_exposure.erase(peer_id)
			if level != was:
				changed[peer_id] = level
				var rows: Array = _history[peer_id]
				rows.append(level)
				if rows.size() > MAX_HISTORY:
					rows.pop_front()
		return changed

	## Session/level end: the table empties (history kept so dumps can see it). Returns: peers that dropped to 0.
	func clear_exposures() -> Dictionary:
		return apply({})

	## Peer left the session: its exposure and transition history are erased (dump and table do not carry the leaver).
	## Returns: peer dropped to 0 (if its exposure was not 0) -> 0.
	func forget(peer_id: int) -> Dictionary:
		var was: int = exposure(peer_id)
		_exposure.erase(peer_id)
		_history.erase(peer_id)
		return {peer_id: Exposure.HIDDEN} if was != Exposure.HIDDEN else {}
