class_name SessionHeat
extends RefCounted
## In-session heat and recognition (US-052, KR-044; GDD heat/recognition, "smallest in-session effect"). Node-free.
## - Ledger (instance): heat summed over the session's finished jobs and per-player recognitions (peer -> count). Single source is
##   Game's ledger: the host records every job result (`record`) and stamps the totals into the result (`stamp`: "session_heat",
##   "recognized_session" {"<peer>": n}); every peer adopts them from the broadcast result (`adopt`), so a client mirrors the host
##   without a new RPC. It carries over "Again" and level changes; Game resets it when the session begins/ends (menu, leave).
## - Effects (static, `Params` from data/heat_tuning.tres via HeatTuning.rules_params, per-map overridable): heat >= `threshold`
##   (> 0) makes later jobs "hot": the neighbour comes `neighbour_delay_cut_s` sooner (never below 0) and the passer-by cap is
##   `passerby_bonus` higher. A player recognised >= `recognized_min` (> 0) times this session starts at `recognized_start`
##   suspicion when the owner first sees them in a new job (only the start value; cover is untouched).

## Result fields written by `stamp` (S3 result addendum).
const RESULT_HEAT := "session_heat"
const RESULT_RECOGNIZED := "recognized_session"


class Params:
	extends RefCounted
	## Session heat at/above which later jobs are hot (<= 0 = never).
	var threshold: int = 0
	## Hot: seconds taken off the neighbour delay (shout -> neighbour out).
	var neighbour_delay_cut_s: float = 0.0
	## Hot: extra passers-by allowed on the street at once.
	var passerby_bonus: int = 0
	## Recognitions needed for the owner's head start (<= 0 = off).
	var recognized_min: int = 0
	## Suspicion the owner starts a recognised player at (0-100).
	var recognized_start: float = 0.0


## Session heat total.
var heat: int = 0
## peer (int) -> recognitions this session.
var recognized: Dictionary = {}


func reset() -> void:
	heat = 0
	recognized.clear()


## Host: adds a finished job's result (S3 result dict: "heat", players {"<peer>": {"recognized"}}).
func record(result: Dictionary) -> void:
	heat += maxi(int(result.get("heat", 0)), 0)
	var players: Dictionary = result.get("players", {}) as Dictionary
	for key: Variant in players:
		var entry: Dictionary = players[key] as Dictionary
		var n: int = int(entry.get("recognized", 0)) if entry != null else 0
		if n > 0:
			var peer: int = int(str(key))
			recognized[peer] = int(recognized.get(peer, 0)) + n


## Host: writes the session totals into `result` (after `record`).
func stamp(result: Dictionary) -> void:
	result[RESULT_HEAT] = heat
	result[RESULT_RECOGNIZED] = recognized_dump()


## Every peer: takes the totals from a broadcast result (no-op if the result has none, e.g. an older host).
func adopt(result: Dictionary) -> void:
	if not result.has(RESULT_HEAT):
		return
	heat = maxi(int(result[RESULT_HEAT]), 0)
	recognized.clear()
	var table: Dictionary = result.get(RESULT_RECOGNIZED, {}) as Dictionary
	for key: Variant in table:
		var n: int = int(table[key])
		if n > 0:
			recognized[int(str(key))] = n


func recognized_of(peer: int) -> int:
	return int(recognized.get(peer, 0))


## {"<peer>": n} (JSON-friendly; dump and result).
func recognized_dump() -> Dictionary:
	var out: Dictionary = {}
	for peer: Variant in recognized:
		out[str(int(peer))] = int(recognized[peer])
	return out


## Whether later jobs are hot at this session heat.
static func is_hot(p: Params, session_heat: int) -> bool:
	return p != null and p.threshold > 0 and session_heat >= p.threshold


## Neighbour delay (s) for a job started at this session heat.
static func neighbour_delay(p: Params, session_heat: int, base_s: float) -> float:
	if not is_hot(p, session_heat):
		return base_s
	return maxf(base_s - maxf(p.neighbour_delay_cut_s, 0.0), 0.0)


## Passer-by cap for a job started at this session heat.
static func passerby_cap(p: Params, session_heat: int, base: int) -> int:
	if not is_hot(p, session_heat):
		return base
	return base + maxi(p.passerby_bonus, 0)


## Owner's starting suspicion for a player with `count` recognitions this session (0 = none).
static func recognition_start(p: Params, count: int) -> float:
	if p == null or p.recognized_min <= 0 or count < p.recognized_min:
		return 0.0
	return clampf(p.recognized_start, 0.0, 100.0)


## Raise needed to bring a meter at `current` up to `start` (never lowers it).
static func start_delta(current: float, start: float) -> float:
	return maxf(start - current, 0.0)
