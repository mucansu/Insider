class_name SessionScores
extends RefCounted
## Session score table (US-051; KR-044, K5 "a reason to go again"): every peer keeps the job results it saw this session locally
## (`Game.heist_finished` / `Game.heist_result()`; no new network field). A late joiner only sees jobs after it joined.
## The table has no single total score: "clean" (no cover broken, no shout) and "fast" (duration) are separate columns; the
## session bests are picked separately (fastest clean escape, fastest escape, biggest crew-cash gain).
## One shared store per process (`shared()`); HeistEnd resets it when the session ends (menu / lost connection). The HUD is
## re-created with each level, so the store must outlive it.

## Max alert at which the grocer has shouted (= HeistRules.ALERT_SHOUTED; ui may not depend on core/, test_session_scores checks equality).
const SHOUT_ALERT := 2
## Outcomes where the crew got away with loot (= HeistRules OUTCOME_CLEAN/SHOUTED/HOT); only these compete for "fastest".
const ESCAPE_OUTCOMES: Array[StringName] = [&"clean", &"shouted", &"hot"]
## Rows shown: the last this many runs (newest first), then best runs that fell outside them.
const RECENT_ROWS := 5
## Best-value kinds (`best()` keys).
const BEST_FASTEST_CLEAN := &"fastest_clean"
const BEST_FASTEST := &"fastest"
const BEST_TOP_CASH := &"top_cash"
const BEST_KINDS: Array[StringName] = [BEST_FASTEST_CLEAN, BEST_FASTEST, BEST_TOP_CASH]
## Strategy class (result `strategy.class`, = HeistRules.STRATEGY_* such as "arka_kapı") -> text key END_STRATEGY_<ASCII-folded, upper>
## (END_STRATEGY_ARKA_KAPI). Turkish letters are folded by code point so ui/ scripts carry no non-ASCII literal.
const STRATEGY_KEY_PREFIX := "END_STRATEGY_"
const FOLD: Dictionary = {0xE7: "c", 0xF6: "o", 0xFC: "u", 0x131: "i", 0x15F: "s", 0x11F: "g"}
const MAP_KEY_PREFIX := "MAP_"

static var _shared: SessionScores = null

## Runs oldest first: {no, level, outcome, duration_s, cash, clean, escaped, strategy}.
var _runs: Array[Dictionary] = []
var _last_hash: int = 0


## The process-wide store of the current session.
static func shared() -> SessionScores:
	if _shared == null:
		_shared = SessionScores.new()
	return _shared


## Session over (menu / connection lost): the next session starts with an empty table.
static func reset_shared() -> void:
	if _shared != null:
		_shared.reset()


func reset() -> void:
	_runs.clear()
	_last_hash = 0


func size() -> int:
	return _runs.size()


## Runs oldest first (copies).
func runs() -> Array[Dictionary]:
	return _runs.duplicate(true)


## The last recorded run ({} if none).
func latest() -> Dictionary:
	if _runs.is_empty():
		return {}
	var last: Dictionary = _runs[_runs.size() - 1]
	return last.duplicate()


## Records a job result seen on this peer. The same result arriving twice (heist_finished + heist_result on a re-created HUD) is
## counted once. Returns the run number, or 0 if nothing was recorded.
func record(result: Dictionary, level_path: String = "") -> int:
	if result.is_empty():
		return 0
	var key: int = hash(result)
	if key == _last_hash and not _runs.is_empty():
		return 0
	_last_hash = key
	var run: Dictionary = entry_from(result, level_path, _runs.size() + 1)
	_runs.append(run)
	return int(run["no"])


## Table row of a result.
static func entry_from(result: Dictionary, level_path: String, no: int) -> Dictionary:
	var outcome := StringName(str(result.get("outcome", "")))
	var strategy: Variant = result.get("strategy", {})
	var strategy_class: String = str((strategy as Dictionary).get("class", "")) if strategy is Dictionary else ""
	return {
		"no": no,
		"level": level_path,
		"outcome": outcome,
		"duration_s": float(result.get("duration_s", 0.0)),
		"cash": cash_change(result),
		"clean": is_clean(result),
		"escaped": ESCAPE_OUTCOMES.has(outcome),
		"strategy": strategy_class,
	}


## Crew cash change of a job: cash_after - cash_before; if the result lacks them (older host), payout - bail.
static func cash_change(result: Dictionary) -> int:
	if result.has("cash_before") and result.has("cash_after"):
		return int(result["cash_after"]) - int(result["cash_before"])
	return int(result.get("payout", 0)) - int(result.get("bail", 0))


## "Clean": nobody's cover broke and nobody shouted (max alert below SHOUT_ALERT). A result without cover data counts on the shout alone.
static func is_clean(result: Dictionary) -> bool:
	var strategy: Variant = result.get("strategy", {})
	var info: Dictionary = strategy if strategy is Dictionary else {}
	var max_alert: int = int(result.get("max_alert", info.get("max_alert", 0)))
	if max_alert >= SHOUT_ALERT:
		return false
	var cover: Variant = info.get("cover_intact", {})
	if cover is Dictionary:
		for peer: Variant in cover:
			if not bool((cover as Dictionary)[peer]):
				return false
	return true


## Session bests: kind -> run number (0 if none). Fastest = shortest escape; fastest clean = shortest clean escape;
## top cash = biggest positive crew-cash gain. Ties keep the earlier run.
func best() -> Dictionary:
	var out: Dictionary = {BEST_FASTEST_CLEAN: 0, BEST_FASTEST: 0, BEST_TOP_CASH: 0}
	var fastest: float = INF
	var fastest_clean: float = INF
	var top_cash: int = 0
	for run: Dictionary in _runs:
		var duration: float = float(run["duration_s"])
		if bool(run["escaped"]):
			if duration < fastest:
				fastest = duration
				out[BEST_FASTEST] = run["no"]
			if bool(run["clean"]) and duration < fastest_clean:
				fastest_clean = duration
				out[BEST_FASTEST_CLEAN] = run["no"]
		if int(run["cash"]) > top_cash:
			top_cash = int(run["cash"])
			out[BEST_TOP_CASH] = run["no"]
	return out


## Run by number ({} if unknown).
func run_by_no(no: int) -> Dictionary:
	return _runs[no - 1].duplicate() if no >= 1 and no <= _runs.size() else {}


## Rows to show: the last RECENT_ROWS runs newest first, then best runs older than those (newest first). Bounded at
## RECENT_ROWS + BEST_KINDS.size() rows however long the session gets.
func visible_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shown: Dictionary = {}
	for i: int in range(_runs.size() - 1, maxi(_runs.size() - RECENT_ROWS, 0) - 1, -1):
		out.append(_runs[i].duplicate())
		shown[int(_runs[i]["no"])] = true
	var older: Array[int] = []
	var bests: Dictionary = best()
	for kind: StringName in BEST_KINDS:
		var no: int = int(bests[kind])
		if no > 0 and not shown.has(no) and not older.has(no):
			older.append(no)
	older.sort()
	older.reverse()
	for no: int in older:
		out.append(run_by_no(no))
	return out


## Text key of a map name from the level path ("res://levels/store_a.tscn" -> MAP_STORE_A); "" without a path.
static func map_key(level_path: String) -> String:
	var base: String = level_path.get_file().get_basename()
	return "" if base.is_empty() else MAP_KEY_PREFIX + base.to_upper()


## Text key of a strategy class ("" without a class; the caller checks the key exists).
static func strategy_key(strategy_class: String) -> String:
	if strategy_class.is_empty():
		return ""
	var folded: String = ""
	for i: int in strategy_class.length():
		var code: int = strategy_class.unicode_at(i)
		folded += String.chr(code) if code < 0x80 else str(FOLD.get(code, "_"))
	return STRATEGY_KEY_PREFIX + folded.to_upper()
