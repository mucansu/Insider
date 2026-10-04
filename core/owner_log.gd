class_name OwnerLog
extends RefCounted
## Shop owner event log (IS-081; S6 dump `owner.log[]`, host only). Node-free ring buffer: diagnosis of "the owner did not react" reports
## (GB-04a, GB-05a/b). The brain calls `tick` at the end of every step; an entry is written when the (state, task, target) key changes or
## when notes are pending (important events queued with `note` between two ticks: sounds, discoveries, services, thresholds, result
## events). Several notes in the same step merge into one entry (`why` joined with "; ").
## Entry: {"t" (brain clock s), "state" (FSM), "task" (agenda task or interrupt name), "facing" [x, y], "target" (peer, 0 none),
## "why" (short human-readable reason), "top_peer", "top_value" (highest suspicion at that moment), "ref" (optional: index of a record
## already in the dump, e.g. "discoveries[0]", "send_costs[1]", "detections[2]" — those fields are not repeated here)}.
## Not player-visible (dump only): the lines are plain diagnostic strings, not tr() keys. The wire layout does not change.

## Ring buffer size (oldest dropped; `dropped` counts them).
const DEFAULT_CAPACITY := 200
const NOTE_SEPARATOR := "; "
## Default reason of a state entry (FSM state name -> line) when no note explains it.
const STATE_LINES := {
	&"look": "şüphe ? -> BAK",
	&"question": "şüphe -> SORGULA",
	&"shout": "BAĞIR",
	&"chase": "KOVALA",
	&"hold": "TUT",
	&"stagger": "SENDELE (ÇEK)",
	&"search": "hedef kayıp -> ARA",
	&"discover": "KEŞİF",
}
## Default reason of an agenda task / interrupt change (task name -> line); other tasks read "görev: <name>".
const TASK_LINES := {
	&"customer": "müşteri servisi",
	&"listen": "ses -> DİNLE",
	&"bell": "zil -> kapıya bakış",
	&"talk": "sohbet (OYALA)",
	&"sent": "GÖNDERİLDİ: arka oda",
}
## Result events (StoreOwner event channel) -> line; the peer is appended as " p<peer>" when non-zero. Empty line = not noted (the
## brain already notes the cause, e.g. LISTEN from `hear`).
const EVENT_LINES := {
	&"owner_question": "soru",
	&"owner_shrug": "omuz silkti",
	&"owner_shout": "bağırdı",
	&"owner_held": "tuttu",
	&"owner_stagger": "sendeledi, kurtaran",
	&"owner_discover_register": "balon: kasa boş",
	&"owner_discover_cash": "balon: para nerede",
	&"owner_serve": "SATIN AL servisi",
	&"owner_talk": "OYALA sohbeti",
	&"owner_sent": "GÖNDER isteği",
	&"owner_listen": "",
	&"owner_again": "yine mi? şüphe",
	&"owner_phone_found": "telefonu buldu",
	&"owner_loiter": "bu ne istiyor?",
	&"owner_soothe_refused": "OYALA tükendi",
	&"owner_question_window": "vitrin sorgusu",
}

var capacity: int = DEFAULT_CAPACITY
## Entries in order (at most `capacity`).
var entries: Array[Dictionary] = []
## Entries dropped from the front (ring overflow).
var dropped: int = 0

var _last_key: String = ""
var _pending: PackedStringArray = PackedStringArray()
var _pending_ref: String = ""
## Throttle key -> last note time (s).
var _throttle: Dictionary = {}


func _init(max_entries: int = DEFAULT_CAPACITY) -> void:
	capacity = maxi(max_entries, 1)


## Queues an important event for the next `tick` (`ref`: index of a record already in the dump; the last non-empty one wins).
func note(why: String, ref: String = "") -> void:
	if why.is_empty():
		return
	_pending.append(why)
	if not ref.is_empty():
		_pending_ref = ref


## Like `note` but at most once per `min_gap` s for the same `key` (repeated sounds while chasing etc. do not flood the buffer).
func note_throttled(key: String, why: String, t: float, min_gap: float) -> void:
	if _throttle.has(key) and t - float(_throttle[key]) < min_gap:
		return
	_throttle[key] = t
	note(why)


## Result event note (EVENT_LINES; unknown kinds are written raw).
func note_event(kind: StringName, peer: int) -> void:
	var line: String = str(EVENT_LINES.get(kind, String(kind)))
	if line.is_empty():
		return
	note(line + (" p%d" % peer if peer != 0 else ""))


## End of a brain step: writes an entry if the key changed or notes are pending. True if an entry was written.
func tick(t: float, state: StringName, task: StringName, facing: Vector2, target: int, top_peer: int, top_value: float) -> bool:
	var key: String = "%s|%s|%d" % [state, task, target]
	var changed: bool = key != _last_key
	if not changed and _pending.is_empty():
		return false
	var why: String = NOTE_SEPARATOR.join(_pending) if not _pending.is_empty() else default_why(state, task, target)
	var entry := {
		"t": snappedf(t, 0.01),
		"state": String(state),
		"task": String(task),
		"facing": [snappedf(facing.x, 0.01), snappedf(facing.y, 0.01)],
		"target": target,
		"why": why,
		"top_peer": top_peer,
		"top_value": snappedf(top_value, 0.1),
	}
	if not _pending_ref.is_empty():
		entry["ref"] = _pending_ref
	_append(entry)
	_last_key = key
	_pending = PackedStringArray()
	_pending_ref = ""
	return true


## Dump rows (copy).
func rows() -> Array[Dictionary]:
	return entries.duplicate(true)


## Default reason of a key change without notes: the state line, on AGENDA the task line.
static func default_why(state: StringName, task: StringName, target: int) -> String:
	var line: String
	if STATE_LINES.has(state):
		line = str(STATE_LINES[state])
	elif TASK_LINES.has(task):
		line = str(TASK_LINES[task])
	elif task.is_empty():
		line = "görev yok"
	else:
		line = "görev: %s" % task
	return line + (" p%d" % target if target != 0 else "")


func _append(entry: Dictionary) -> void:
	entries.append(entry)
	while entries.size() > capacity:
		entries.pop_front()
		dropped += 1
