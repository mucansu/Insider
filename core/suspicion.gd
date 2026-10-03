class_name SuspicionMeter
extends RefCounted
## One observer's suspicion meter against one target (US-006 AC1; mimari.md S2, S11, GDD §6.1/§12, KR-019).
## Node-free; advances by fill rate (`PerceptionRules.rate_for`) and step time, independent of the fixed step.
##
## - Value 0..MAX_VALUE; thresholds (KR-019: "?" 30, inspect 60, detect 100) give the level: 0 calm, 1..N threshold order.
## - While seen (fill > 0) the value grows by `fill x s`; while unseen (line of sight cut, outside cone, dark) it decays at `decay_per_sec` and the level falls with the value.
## - Seen sequence: seen steps and gaps shorter than `gap_tolerance` between them form one sequence (`seen_for` = sequence length, gaps included). In a short gap the fill stops but the sequence continues and decay does not start:
##   fidgeting at the cone edge (11/1, 9/3 frames) or 20 Hz sync jitter does not reset the meter, and a one-frame loss after detection does not drop the level. Beyond the tolerance the sequence ends and decay runs for the time past it (real hiding).
## - Player-favouring slack (S2, GDD §12: the host sees the player at a ~100-175 ms old position): no fill in the first `grace` s of a sequence; on leaving line of sight the fill stops at once.
##   So a look shorter than `grace` leaves no trace, and the last ~0.2 s of a player hiding from the host's stale view never reaches detection. Continuously seen: detect = grace + MAX / fill
##   (sprinting, near band: 0.2 + 1.0 s; KR decision US-006 t2). During the slack the value neither fills nor decays.
## - `step()` returns the threshold levels crossed upward this step in order (the component turns them into signals).

## Meter cap (GDD §6.1: 0-100).
const MAX_VALUE := 100.0
## Float margin for threshold comparison (so a step sum does not stall at 99.9999).
const EPSILON := 0.0001


## Meter settings (value object; the component fills it from tuning).
class Params:
	extends RefCounted
	## Decay while unseen (units/s).
	var decay_per_sec: float = 0.0
	## Rising thresholds; level = number of thresholds crossed.
	var thresholds: PackedFloat32Array = PackedFloat32Array()
	## Player-favouring slack (s).
	var grace: float = 0.0
	## Gap length that does not break a seen sequence (s; 0 = every gap ends it).
	var gap_tolerance: float = 0.0


var value: float = 0.0
var level: int = 0
## Length of the ongoing seen sequence (s; tolerated gaps included; 0 if none).
var seen_for: float = 0.0
## Length of the ongoing gap (s; 0 while seen).
var gap_for: float = 0.0


## Advances one step. If `fill_rate` > 0 the target counts as seen this step. Returns the levels crossed upward (ascending); level drops are not returned.
func step(params: Params, fill_rate: float, delta: float) -> PackedInt32Array:
	var dt: float = maxf(delta, 0.0)
	if fill_rate > 0.0:
		gap_for = 0.0
		var before: float = seen_for
		seen_for += dt
		var credited: float = seen_for - maxf(before, params.grace)
		if credited > 0.0:
			value += fill_rate * minf(credited, dt)
	else:
		var decaying: float = dt
		if seen_for > 0.0:
			var tolerated: float = clampf(params.gap_tolerance - gap_for, 0.0, dt)
			gap_for += dt
			if gap_for < params.gap_tolerance:
				seen_for += dt
				decaying = 0.0
			else:
				seen_for = 0.0
				gap_for = 0.0
				decaying = dt - tolerated
		value -= maxf(params.decay_per_sec, 0.0) * decaying
	value = clampf(value, 0.0, MAX_VALUE)
	var new_level: int = level_for(params, value)
	var reached := PackedInt32Array()
	for l: int in range(level + 1, new_level + 1):
		reached.append(l)
	level = new_level
	return reached


## Level of a value: number of thresholds crossed (>=, with EPSILON margin).
static func level_for(params: Params, amount: float) -> int:
	var out: int = 0
	for t: float in params.thresholds:
		if amount >= t - EPSILON:
			out += 1
	return out


func reset() -> void:
	value = 0.0
	level = 0
	seen_for = 0.0
	gap_for = 0.0
