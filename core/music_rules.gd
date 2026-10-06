class_name MusicRules
extends RefCounted
## Calm music rule v0 (US-047 AC4; ses-ve-sfx §5 minimum, GDD §14). Node-free. One calm loop on the Music bus. A threat — the alert ladder
## rising to THREAT_LEVEL or above, or a shout/catch/police event — cuts the music within CUT_TIME, then SILENCE_TIME of silence ("silence is a
## tool"); after that it fades back in over FADE_IN_TIME if the heist is still running. Heist over (end screen) = music off for good and the
## existing stingers play alone. `Mixer.step` returns the music gain (linear 0..1); the player only applies it.

## Alert level that counts as a threat (S3 alert ladder, 0-5).
const THREAT_LEVEL := 2
## Fall from full to silent (s; AC4 <= 0.3 s).
const CUT_TIME := 0.25
## Silence after a threat (s).
const SILENCE_TIME := 4.0
## Return fade (s).
const FADE_IN_TIME := 2.5
## Session events (S3 `session_event` kinds) that cut the music like a ladder rise.
const THREAT_EVENTS: Array[StringName] = [&"shout", &"player_caught", &"police_arrived"]


static func is_threat_level(level: int) -> bool:
	return level >= THREAT_LEVEL


static func is_threat_event(kind: StringName) -> bool:
	return THREAT_EVENTS.has(kind)


class Mixer:
	extends RefCounted

	## Current gain (linear 0..1). Starts silent and fades in.
	var gain: float = 0.0
	## Silence left after the last threat (s).
	var silence_left: float = 0.0
	## Heist finished: music stays off.
	var finished: bool = false
	var _last_level: int = 0

	## A one-shot threat (shout, catch, police): cut + silence.
	func trigger() -> void:
		silence_left = MusicRules.CUT_TIME + MusicRules.SILENCE_TIME  # the cut, then a full 4 s of silence

	## Heist end: off for good (until a new Mixer, i.e. the next level).
	func finish() -> void:
		finished = true

	## Advances `delta` s with the current alert level; returns the gain. A rise of the ladder into or within the threat range re-triggers.
	func step(delta: float, alert_level: int) -> float:
		if alert_level > _last_level and MusicRules.is_threat_level(alert_level):
			trigger()
		_last_level = alert_level
		var silent: bool = finished or silence_left > 0.0
		if silence_left > 0.0:
			silence_left = maxf(silence_left - delta, 0.0)
		if silent:
			gain = move_toward(gain, 0.0, delta / MusicRules.CUT_TIME)
		else:
			gain = move_toward(gain, 1.0, delta / MusicRules.FADE_IN_TIME)
		return gain
