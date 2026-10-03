class_name Fsm
extends RefCounted
## Small state machine (US-008 AC1; mimari.md S11, KR-018). Node-free: states are ints (the brain's enum); allowed
## transitions come from an optional edge table. NPC brains and the venue alert ladder (I4: grocery {0→1, 1→2, 2→3, 3→5, 2→1, 1→0}) share it.
##
## - `go(to)`: switches if allowed, resets time in state, emits `changed`, logs history; an empty table allows all, same-state is a no-op (false).
## - `route(to)`: shortest state path over the edges (current excluded, `to` included); empty if unreachable (no ladder skipping).
## - `step(delta)`: advances time in state and the machine `clock` (brains call it every step).
## - History is timestamped: `history[i]` entered at `history_times[i]` (s, `clock`); dumps prove transition order and duration.

signal changed(from: int, to: int)

## Max transitions kept in history (dump/tests; oldest dropped).
const MAX_HISTORY := 256

var state: int = 0
## Time in the current state (s).
var time_in_state: float = 0.0
## Machine clock (s; sum of `step`).
var clock: float = 0.0
## Visited states (incl. initial; at most MAX_HISTORY) and entry times (`clock`).
var history: PackedInt32Array = PackedInt32Array()
var history_times: PackedFloat64Array = PackedFloat64Array()

## from -> PackedInt32Array (allowed targets); empty = free.
var _edges: Dictionary = {}


func _init(initial: int = 0, edges: Dictionary = {}) -> void:
	state = initial
	for from: Variant in edges:
		_edges[int(from)] = PackedInt32Array(edges[from])
	history.append(initial)
	history_times.append(0.0)


func can(to: int) -> bool:
	if to == state:
		return false
	if _edges.is_empty():
		return true
	var targets: PackedInt32Array = _edges.get(state, PackedInt32Array())
	return targets.has(to)


func go(to: int) -> bool:
	if not can(to):
		return false
	var from: int = state
	state = to
	time_in_state = 0.0
	history.append(to)
	history_times.append(clock)
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY)
		history_times = history_times.slice(history_times.size() - MAX_HISTORY)
	changed.emit(from, to)
	return true


func step(delta: float) -> void:
	time_in_state += maxf(delta, 0.0)
	clock += maxf(delta, 0.0)


## History as dump rows: [[state, entry time (s, 3 decimals)], ...]; state name if `names` given.
func history_rows(names: Array = []) -> Array:
	var out: Array = []
	for i: int in history.size():
		var s: int = history[i]
		out.append([names[s] if s >= 0 and s < names.size() else s, snappedf(history_times[i], 0.001)])
	return out


## Shortest allowed sequence from the current state to `to` (current excluded); empty if same state or unreachable.
func route(to: int) -> PackedInt32Array:
	return shortest_path(_edges, state, to)


## Shortest `from` -> `to` path in an edge table (from excluded); [to] directly if the table is empty.
static func shortest_path(edges: Dictionary, from: int, to: int) -> PackedInt32Array:
	if from == to:
		return PackedInt32Array()
	if edges.is_empty():
		return PackedInt32Array([to])
	var previous: Dictionary = {from: from}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == to:
			break
		for next: int in PackedInt32Array(edges.get(at, PackedInt32Array())):
			if not previous.has(next):
				previous[next] = at
				queue.append(next)
	if not previous.has(to):
		return PackedInt32Array()
	var out := PackedInt32Array()
	var walk: int = to
	while walk != from:
		out.insert(0, walk)
		walk = int(previous[walk])
	return out


## Whether the sequence (first element = start) uses only allowed transitions (repeated consecutive states are not transitions).
static func is_valid_sequence(edges: Dictionary, sequence: PackedInt32Array) -> bool:
	for i: int in range(1, sequence.size()):
		var from: int = sequence[i - 1]
		var to: int = sequence[i]
		if from == to:
			continue
		if not PackedInt32Array(edges.get(from, PackedInt32Array())).has(to):
			return false
	return true
