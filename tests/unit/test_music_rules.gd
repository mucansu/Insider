extends TestCase
## Music rule v0 (US-047 AC4; ses-ve-sfx §5): calm loop fades in; alert rise to >= 2 or a shout/caught/police event cuts it within 0.3 s,
## 4 s of silence follow, then it returns while the heist runs; heist end silences it for good.

const STEP := 1.0 / 60.0


func _advance(mixer: MusicRules.Mixer, seconds: float, level: int) -> float:
	var t: float = 0.0
	while t < seconds - 0.00001:
		mixer.step(STEP, level)
		t += STEP
	return mixer.gain


## Seconds until the gain reaches ~0 (or `limit`).
func _time_to_silence(mixer: MusicRules.Mixer, level: int, limit: float = 2.0) -> float:
	var t: float = 0.0
	while mixer.gain > 0.001 and t < limit:
		mixer.step(STEP, level)
		t += STEP
	return t


func test_fades_in_when_calm() -> void:
	var mixer := MusicRules.Mixer.new()
	eq(mixer.gain, 0.0, "başta sessiz")
	_advance(mixer, MusicRules.FADE_IN_TIME * 0.5, 0)
	is_true(mixer.gain > 0.3 and mixer.gain < 0.7, "yavaş girer (%s)" % mixer.gain)
	near(_advance(mixer, MusicRules.FADE_IN_TIME, 1), 1.0, 0.001, "kademe 1 müziği kesmez")


func test_alert_two_cuts_fast_then_four_seconds_silence_then_returns() -> void:
	var mixer := MusicRules.Mixer.new()
	_advance(mixer, 5.0, 0)
	near(mixer.gain, 1.0, 0.001)
	var cut: float = _time_to_silence(mixer, 2)
	is_true(cut <= 0.3, "kademe 2'de <= 0,3 sn'de kesilir (%s)" % cut)
	_advance(mixer, MusicRules.SILENCE_TIME - 0.1, 2)
	eq(mixer.gain, 0.0, "4 sn sessizlik")
	_advance(mixer, 0.2 + MusicRules.FADE_IN_TIME, 2)
	near(mixer.gain, 1.0, 0.001, "iş sürüyorsa geri döner")
	_advance(mixer, 1.0, 3)
	is_true(mixer.gain < 0.01, "kademe yeniden yükselirse yine kesilir")


func test_threat_events_cut() -> void:
	for kind: StringName in [&"shout", &"player_caught", &"police_arrived"]:
		is_true(MusicRules.is_threat_event(kind), "%s tehdit" % kind)
	is_false(MusicRules.is_threat_event(&"purchase"))
	var mixer := MusicRules.Mixer.new()
	_advance(mixer, 5.0, 0)
	mixer.trigger()
	is_true(_time_to_silence(mixer, 0) <= 0.3, "bağırış müziği <= 0,3 sn'de keser")
	_advance(mixer, MusicRules.SILENCE_TIME - 0.2, 0)
	eq(mixer.gain, 0.0)


func test_level_staying_high_does_not_retrigger() -> void:
	var mixer := MusicRules.Mixer.new()
	_advance(mixer, 1.0, 2)
	_advance(mixer, MusicRules.CUT_TIME + MusicRules.SILENCE_TIME + MusicRules.FADE_IN_TIME + 0.2, 2)
	near(mixer.gain, 1.0, 0.001, "aynı kademede kalmak yeniden kesmez")


func test_heist_end_silences_for_good() -> void:
	var mixer := MusicRules.Mixer.new()
	_advance(mixer, 5.0, 0)
	mixer.finish()
	is_true(_time_to_silence(mixer, 0) <= 0.3, "iş sonunda müzik susar")
	_advance(mixer, 20.0, 0)
	eq(mixer.gain, 0.0, "iş sonu ekranında geri gelmez")
