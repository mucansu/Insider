extends TestCase
## US-052 (KR-044) in-session heat and recognition. Rules (core/session_heat.gd): hot threshold, neighbour delay cut, passer-by cap,
## recognised head start; ledger: record / stamp / adopt / reset across jobs. Tuning: data/heat_tuning.tres values and the per-map
## override (VenueTuning id `heat`). OwnerRecognition (entities/npc/owner): who is due a head start. Game (host session + store_a):
## a police job (witness released: recognised 1, heat 17) carries over "Again" — the next job's neighbour delay is 2 s shorter, the
## passer-by cap +1, the owner starts the recognised player at 30 with "You again?"; a second job adds up; leaving the session resets.

const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
## Customer side of the counter, inside the owner's cone (test_heist_game COUNTER_FRONT).
const COUNTER_FRONT := Vector2(536, 336)

var _results: Array[Dictionary] = []
var _previous_scene: PackedScene = null


func _params(threshold: int = 10, cut: float = 2.0, bonus: int = 1, min_count: int = 1, start: float = 30.0) -> SessionHeat.Params:
	var p := SessionHeat.Params.new()
	p.threshold = threshold
	p.neighbour_delay_cut_s = cut
	p.passerby_bonus = bonus
	p.recognized_min = min_count
	p.recognized_start = start
	return p


func _result(heat: int, recognized: Dictionary) -> Dictionary:
	var players: Dictionary = {}
	for peer: Variant in recognized:
		players[str(peer)] = {"name": "p%d" % int(peer), "recognized": int(recognized[peer])}
	return {"outcome": &"police", "heat": heat, "players": players}


# --- rules ---

func test_hot_threshold() -> void:
	var p := _params()
	is_false(SessionHeat.is_hot(p, 9), "9 < 10: sakin")
	is_true(SessionHeat.is_hot(p, 10), "eşik dahil")
	is_true(SessionHeat.is_hot(p, 19))
	is_false(SessionHeat.is_hot(_params(0), 50), "eşik 0 = kapalı")
	is_false(SessionHeat.is_hot(null, 50), "parametre yok")


func test_neighbour_delay_and_passerby_cap() -> void:
	var p := _params()
	eq(SessionHeat.neighbour_delay(p, 5, 8.0), 8.0, "sakin oturum: değişmez")
	eq(SessionHeat.neighbour_delay(p, 15, 8.0), 6.0, "sıcak: −2 sn")
	eq(SessionHeat.neighbour_delay(p, 15, 1.5), 0.0, "sıfırın altına inmez")
	eq(SessionHeat.passerby_cap(p, 5, 2), 2, "sakin oturum: tavan aynı")
	eq(SessionHeat.passerby_cap(p, 10, 2), 3, "sıcak: tavan +1")
	eq(SessionHeat.passerby_cap(_params(10, 2.0, -3), 10, 2), 2, "eksi bonus yok sayılır")


func test_recognition_start() -> void:
	var p := _params()
	eq(SessionHeat.recognition_start(p, 0), 0.0, "tanınmamış: başlangıç yok")
	eq(SessionHeat.recognition_start(p, 1), 30.0, "1 tanınma: 30")
	eq(SessionHeat.recognition_start(p, 3), 30.0, "birikmez, yalnız başlangıç değeri")
	eq(SessionHeat.recognition_start(_params(10, 2.0, 1, 2), 1), 0.0, "eşik 2")
	eq(SessionHeat.recognition_start(_params(10, 2.0, 1, 0), 5), 0.0, "eşik 0 = kapalı")
	eq(SessionHeat.start_delta(10.0, 30.0), 20.0, "30'a tamamlar")
	eq(SessionHeat.start_delta(45.0, 30.0), 0.0, "zaten yüksekse düşürmez")


# --- ledger ---

func test_ledger_carries_and_resets() -> void:
	var l := SessionHeat.new()
	l.record(_result(17, {2: 1}))
	eq([l.heat, l.recognized], [17, {2: 1}], "1. iş")
	l.record(_result(5, {2: 1, 3: 0}))
	eq([l.heat, l.recognized], [22, {2: 2}], "2. iş: birikir; 0 tanınma yazılmaz")
	l.record({"heat": -4, "players": {}})
	eq(l.heat, 22, "eksi ısı yok sayılır")
	var r: Dictionary = _result(0, {})
	l.stamp(r)
	eq([r[SessionHeat.RESULT_HEAT], r[SessionHeat.RESULT_RECOGNIZED]], [22, {"2": 2}], "sonuca damga")
	var mirror := SessionHeat.new()
	mirror.adopt(r)
	eq([mirror.heat, mirror.recognized, mirror.recognized_of(2), mirror.recognized_of(9)], [22, {2: 2}, 2, 0], "istemci aynası")
	mirror.adopt({"heat": 99})
	eq(mirror.heat, 22, "damgasız sonuç aynayı değiştirmez")
	l.reset()
	eq([l.heat, l.recognized], [0, {}], "sıfırlama")


# --- tuning ---

func test_tuning_file_values_and_override() -> void:
	var t: HeatTuning = load(HeatTuning.PATH) as HeatTuning
	if not is_true(t != null, "data/heat_tuning.tres"):
		return
	eq([t.heat_threshold, t.neighbour_delay_cut_s, t.passerby_bonus, t.recognized_min, t.recognized_start], [10, 2.0, 1, 1, 30.0])
	eq(VenueTuning.PATHS[VenueTuning.HEAT], HeatTuning.PATH, "harita başına ezilebilir kimlik")
	var copy: HeatTuning = TuningOverrides.apply(t, {"neighbour_delay_cut_s": 3}) as HeatTuning
	eq([copy.neighbour_delay_cut_s, t.neighbour_delay_cut_s], [3.0, 2.0], "ezme kopyaya, küresel değişmez")
	eq(VenueTuning.errors({"heat": {"neighbour_delay_cut_s": 3.0, "passerby_bonus": 2}}), PackedStringArray(), "geçerli ezme")
	eq(VenueTuning.errors({"heat": {"nope": 1}}).size(), 1, "bilinmeyen alan hata")


# --- owner recognition ---

func test_owner_recognition_due() -> void:
	var r := OwnerRecognition.from_state({"recognized": {2: 1, 3: 0, 4: 2}}, _params())
	eq(r.starts, {2: 30.0, 4: 30.0}, "yalnız tanınanlar")
	var seen := Perception.Observation.new()
	seen.peer_id = 2
	seen.band = PerceptionRules.Band.FAR
	seen.line_clear = true
	var blocked := Perception.Observation.new()
	blocked.peer_id = 4
	blocked.band = PerceptionRules.Band.NEAR
	blocked.line_clear = false
	var stranger := Perception.Observation.new()
	stranger.peer_id = 3
	stranger.band = PerceptionRules.Band.NEAR
	stranger.line_clear = true
	eq(r.due({2: seen, 3: stranger, 4: blocked}), [2] as Array[int], "görülen tanınan; görüş hattı kapalı ve tanınmayan yok")
	r.mark(2, 1.5, 30.0)
	eq(r.due({2: seen}), [] as Array[int], "iş başına bir kez")
	eq(r.greets, [{"peer": 2, "t": 1.5, "value": 30.0}] as Array[Dictionary])
	var dark := Perception.Observation.new()
	dark.peer_id = 4
	dark.band = PerceptionRules.Band.NEAR
	dark.line_clear = true
	dark.in_dark = true
	eq(r.due({4: dark}), [] as Array[int], "karanlıkta tanınmaz")


# --- Game (host session) ---

static func _free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _on_finished(result: Dictionary) -> void:
	_results.append(result)


func _frames(n: int = 3) -> void:
	for i: int in n:
		await tree().physics_frame


func _level() -> Level:
	return Game.current_level() as Level


func _alert() -> StoreAlert:
	return _level().npcs_root().get_node("StoreAlert") as StoreAlert


func test_game_carries_heat_over_again_and_resets_on_leave() -> void:
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	Game.heist_finished.connect(_on_finished)
	if eq(Net.host(_free_udp_port()), OK):
		Game.start_level(STORE)
		await _game_flow()
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	eq(Game.session_heat_state()["heat"], 0, "oturum bitti: sıfır")
	eq(Game.session_heat_state()["recognized"], {}, "tanınma sıfır")
	Game.heist_finished.disconnect(_on_finished)
	Game.player_scene = _previous_scene


func _game_flow() -> void:
	var me: Player = Game.local_player() as Player
	if not is_true(me != null, "yerel oyuncu"):
		return
	eq(Game.session_heat_state(), {"heat": 0, "active": false, "recognized": {}, "known": [] as Array[int]}, "yeni oturum: sakin")
	eq(_alert().neighbour_delay(), 8.0, "1. iş: komşu gecikmesi ayardaki gibi")
	var pop: Population = _level().npcs_root().get_node("Population") as Population
	eq(pop.schedule.params.passerby_max, 2, "1. iş: yoldan geçen tavanı 2")
	await _frames()
	Game.raise_session_event(&"police_arrived")  # outside, untouched: witness released (recognised 1), heat 15 + 2
	await _frames()
	if not eq(_results.size(), 1, "1. iş bitti"):
		return
	eq([_results[0]["heat"], _results[0]["session_heat"], _results[0]["recognized_session"]], [17, 17, {"1": 1}], "sonuçta oturum toplamı")
	var state: Dictionary = Game.session_heat_state()
	eq([state["heat"], state["active"], state["recognized"], state["known"]], [17, true, {1: 1}, [1] as Array[int]])
	var dump: Dictionary = Game.collect_dump().get("heist", {}) as Dictionary
	if not dump.is_empty():
		eq([dump["session_heat"], dump["recognized_session"]], [17, {"1": 1}], "döküm")
	Game.request_restart()  # "Again": the session carries over
	await _frames()
	eq(Game.session_heat_state()["heat"], 17, "Bir daha: ısı taşındı")
	eq(_alert().neighbour_delay(), 6.0, "2. iş: komşu 2 sn erken")
	pop = _level().npcs_root().get_node("Population") as Population
	eq(pop.schedule.params.passerby_max, 3, "2. iş: yoldan geçen tavanı +1")
	var owner: StoreOwner = _level().npcs_root().get_node("Owner") as StoreOwner
	eq(owner.brain().recognition.starts, {1: 30.0}, "sahip tanınanı biliyor")
	me = Game.local_player() as Player
	me.position = COUNTER_FRONT
	await _frames(20)
	var greets: Array[Dictionary] = owner.brain().recognition.greets
	if eq(greets.size(), 1, "ilk görüşte bir kez"):
		eq([greets[0]["peer"], greets[0]["value"]], [1, 30.0], "şüphe 30'dan başlar")
	has(owner.events(), &"owner_recognize", "balon: Sen yine mi?")
	eq(Game.cover_state(), 1, "örtü bozulmaz")
	await _frames(20)
	eq(owner.brain().recognition.greets.size(), 1, "tekrar selamlamaz")
	Game.raise_session_event(&"police_arrived")
	await _frames()
	if eq(_results.size(), 2, "2. iş bitti"):
		eq([_results[1]["session_heat"], _results[1]["recognized_session"]], [34, {"1": 2}], "2. iş: birikir")
