class_name OwnerRecognition
extends RefCounted
## Owner's in-session recognition (US-052, KR-044): players recognised earlier in the session (Game `session_heat_state`) start at a
## head-start suspicion (`SessionHeat.recognition_start`, data/heat_tuning.tres `recognized_start` 30) the first time the owner sees
## them in a new job - "?" plus the "You again?" balloon (owner event `owner_recognize`). Only the starting value: cover is untouched and
## the meter drains as usual. Host only; built by StoreOwner when the level loads, stepped by OwnerBrain. Other civilians are unaffected.

## Owner result event / balloon (NpcVisual.BALLOON_KEYS -> OWNER_RECOGNIZE).
const EVENT := &"owner_recognize"

## peer -> head-start suspicion (> 0).
var starts: Dictionary = {}
## Peers already greeted this job.
var greeted: Dictionary = {}
## Dump rows {peer, t, value} (value = meter after the head start).
var greets: Array[Dictionary] = []


## From Game's session heat state ({"recognized": {peer: n}}) and the heat rule parameters.
static func from_state(state: Dictionary, p: SessionHeat.Params) -> OwnerRecognition:
	var r := OwnerRecognition.new()
	var table: Dictionary = state.get("recognized", {}) as Dictionary
	for key: Variant in table:
		var start: float = SessionHeat.recognition_start(p, int(table[key]))
		if start > 0.0:
			r.starts[int(str(key))] = start
	return r


## Peers due their head start in this step's observations: recognised, not greeted yet, actually seen (in the cone, clear line, lit).
func due(observations: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for key: Variant in starts:
		var peer: int = int(key)
		if greeted.has(peer):
			continue
		var obs: Perception.Observation = observations.get(peer) as Perception.Observation
		if obs != null and obs.line_clear and obs.band != PerceptionRules.Band.NONE and not obs.in_dark:
			out.append(peer)
	out.sort()
	return out


func start_of(peer: int) -> float:
	return float(starts.get(peer, 0.0))


## Records the greeting (once per job).
func mark(peer: int, t: float, value: float) -> void:
	greeted[peer] = true
	greets.append({"peer": peer, "t": snappedf(t, 0.01), "value": snappedf(value, 0.01)})
