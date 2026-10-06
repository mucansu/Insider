extends TestCase
## Sound catalog and players (IS-024): every event's file in the catalog exists and loads (loop off), event names unique,
## placeholder count reported; SfxEmitter minimum interval, repeat (register tick), silence on a missing event; sound on door and
## register state change; runs headless (dummy audio driver) without errors/warnings. Public API only (§6).

const DOOR_SCENE := "res://entities/props/door.tscn"
const REGISTER_SCENE := "res://entities/props/register.tscn"
const SFX_DIR := "res://assets/sfx/"
## Bound in this item + keys waiting to be bound (US-008: shop owner; US-009: run step).
const REQUIRED_EVENTS: Array[StringName] = [
	&"door_open", &"door_close", &"register_tick", &"register_done", &"ui_click", &"ui_focus",
	&"alert_step", &"alert_high", &"stinger_success", &"stinger_caught",
	&"clerk_question", &"clerk_interrogate", &"clerk_shout", &"run_step", &"walk_step",
]
## US-047: looping beds (ambience/music) in the catalog's `loops`.
const REQUIRED_LOOPS: Array[StringName] = [&"amb_street", &"amb_room", &"amb_murmur", &"music_calm"]
const LOOP_DIRS: Array[String] = ["res://assets/ambience/", "res://assets/music/"]
## US-047 AC1: bus layout (default_bus_layout.tres).
const BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"UI", &"VO"]
## US-047 AC8: game-information sounds that must stay the loudest one-shots (owner shout, high alert).
const INFO_EVENTS: Array[StringName] = [&"clerk_shout", &"alert_high"]


## Collects all engine/script logs including warnings (the runner ignores warnings; this test counts them).
class AllLogs extends Logger:
	var entries: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		entries.append("%s (%s:%d, %s)" % [code if rationale.is_empty() else rationale, file, line, function])
		_mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error:
			_mutex.lock()
			entries.append(message)
			_mutex.unlock()


## Manually advanced clock.
class FakeClock extends RefCounted:
	var t: float = 100.0

	func now() -> float:
		return t


func _catalog() -> SfxCatalog:
	return load(SfxCatalog.DEFAULT_PATH) as SfxCatalog


func _emitter(clock: FakeClock = null) -> SfxEmitter:
	var holder := Node2D.new()
	tree().root.add_child(holder)
	autofree(holder)
	var emitter: SfxEmitter = SfxEmitter.of(holder)
	if clock != null:
		emitter.clock = clock.now
	return emitter


# --- catalog ---

func test_every_catalog_event_has_loadable_file() -> void:
	var catalog: SfxCatalog = _catalog()
	if not is_true(catalog != null, "data/sfx_catalog.tres SfxCatalog olarak yüklenmeli"):
		return
	is_true(catalog.entries.size() >= REQUIRED_EVENTS.size(), "katalog boş ya da eksik")
	var seen: Dictionary = {}
	for entry: SfxEntry in catalog.entries:
		if not is_true(entry != null, "boş girdi"):
			continue
		var ev: StringName = entry.event
		is_false(String(ev).is_empty(), "olay adı boş")
		is_false(seen.has(ev), "olay iki kez: %s" % ev)
		seen[ev] = true
		if not is_true(entry.stream != null, "%s: stream yok" % ev):
			continue
		var streams: Array[AudioStream] = [entry.stream]
		streams.append_array(entry.variants)
		for one: AudioStream in streams:
			if not is_true(one != null, "%s: boş varyant" % ev):
				continue
			var path: String = one.resource_path
			is_true(path.begins_with(SFX_DIR) and path.ends_with(".ogg"), "%s: dosya assets/sfx/*.ogg olmalı (%s)" % [ev, path])
			is_true(FileAccess.file_exists(path), "%s: dosya yok: %s" % [ev, path])
			var loaded: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
			if is_true(loaded != null, "%s: Ogg Vorbis olarak yüklenmeli" % ev):
				is_false(loaded.loop, "%s: içe aktarmada döngü kapalı olmalı" % ev)
				is_true(loaded.get_length() > 0.0 and loaded.get_length() < 3.0, "%s: süre 0-3 sn (%s)" % [ev, loaded.get_length()])
		is_true(entry.pitch_min > 0.0 and entry.pitch_min <= entry.pitch_max, "%s: perde aralığı" % ev)
		is_true(entry.volume_db <= 6.0, "%s: ses düzeyi" % ev)
	for ev: StringName in REQUIRED_EVENTS:
		is_true(seen.has(ev), "katalogda olay yok: %s" % ev)


func test_placeholder_count_is_reported() -> void:
	var catalog: SfxCatalog = _catalog()
	var placeholders: Array[StringName] = catalog.placeholder_events()
	# Today all sounds are placeholders (assetler.md "Yer tutucu sesler"); set to false when production sounds arrive.
	var total: int = catalog.entries.size() + catalog.loops.size()
	eq(placeholders.size(), total, "bütün girdiler (döngüler dahil) placeholder = true")
	print("       [bilgi] yer tutucu ses: %d/%d" % [placeholders.size(), total])
	var fresh := SfxEntry.new()
	is_true(fresh.placeholder, "yeni girdi varsayılan olarak yer tutucu")


func test_positional_events_heard_within_twice_noise_radius() -> void:
	# ses-ve-sfx §1 rule 3: audible distance = noise radius x 2 (S8 starting values).
	var expected := {&"door_open": 320.0, &"door_close": 320.0, &"register_tick": 180.0, &"register_done": 180.0,
		&"run_step": 240.0}
	var catalog: SfxCatalog = _catalog()
	for ev: StringName in expected:
		var entry: SfxEntry = catalog.find(ev)
		if is_true(entry != null, "katalogda yok: %s" % ev):
			eq(entry.max_distance, expected[ev], "%s duyulma mesafesi" % ev)


func test_every_entry_routes_to_an_existing_bus() -> void:
	# US-047 AC1: the bus layout is loaded (headless too) and every catalog entry/loop names one of its buses.
	for bus_name: StringName in BUSES:
		is_true(AudioServer.get_bus_index(bus_name) >= 0, "bus düzeninde yok: %s" % bus_name)
	var catalog: SfxCatalog = _catalog()
	for entry: SfxEntry in catalog.entries + catalog.loops:
		is_true(AudioServer.get_bus_index(entry.bus) > 0, "%s: bus Master dışı ve mevcut olmalı (%s)" % [entry.event, entry.bus])
	eq(catalog.find(&"door_open").bus, &"SFX")
	eq(catalog.find(&"ui_click").bus, &"UI")
	eq(catalog.find(&"clerk_shout").bus, &"VO")
	eq(catalog.find_loop(&"music_calm").bus, &"Music")
	eq(catalog.find_loop(&"amb_street").bus, &"Ambience")
	eq(SfxEntry.new().bus, &"SFX", "varsayılan bus SFX")


func test_emitters_apply_entry_bus() -> void:
	var emitter: SfxEmitter = _emitter()
	var ui: UiSfx = UiSfx.of(emitter.get_parent())
	is_true(emitter.play_event(&"door_open"))
	eq(emitter.bus, &"SFX")
	is_true(ui.play_event(&"ui_click"))
	eq(ui.bus, &"UI")
	is_true(emitter.play_event(&"clerk_shout"))
	eq(emitter.bus, &"VO")


func test_loops_are_seamless_ogg_on_their_buses() -> void:
	# US-047 AC3-AC5: ambience/music loops are looping Ogg Vorbis under assets/ambience|music.
	var catalog: SfxCatalog = _catalog()
	for id: StringName in REQUIRED_LOOPS:
		var entry: SfxEntry = catalog.find_loop(id)
		if not is_true(entry != null and entry.stream != null, "döngü yok: %s" % id):
			continue
		var path: String = entry.stream.resource_path
		is_true(path.begins_with(LOOP_DIRS[0]) or path.begins_with(LOOP_DIRS[1]), "%s: assets/ambience|music altında (%s)" % [id, path])
		var ogg: AudioStreamOggVorbis = entry.stream as AudioStreamOggVorbis
		if is_true(ogg != null, "%s: Ogg Vorbis" % id):
			is_true(ogg.loop, "%s: içe aktarmada döngü açık olmalı" % id)
			is_true(ogg.get_length() >= 8.0, "%s: döngü en az 8 sn (%s)" % [id, ogg.get_length()])
		is_true(entry.bus == &"Ambience" or entry.bus == &"Music", "%s: bus Ambience/Music" % id)
	is_true(catalog.find(&"amb_street") == null, "döngüler take() kataloğunda değil")


func test_mix_levels_keep_beds_under_events_and_info_on_top() -> void:
	# US-047 AC7/AC8: beds (music, ambience) sit under every one-shot except the quiet walk step; game-information sounds are the loudest.
	var catalog: SfxCatalog = _catalog()
	var quietest_event: float = 100.0
	var loudest_other: float = -100.0
	for entry: SfxEntry in catalog.entries:
		if entry.event != &"walk_step":
			quietest_event = minf(quietest_event, entry.volume_db)
		if not INFO_EVENTS.has(entry.event):
			loudest_other = maxf(loudest_other, entry.volume_db)
	for entry: SfxEntry in catalog.loops:
		is_true(entry.volume_db < quietest_event, "%s (%s dB) olaylardan kısık olmalı (%s)" % [entry.event, entry.volume_db, quietest_event])
	for ev: StringName in INFO_EVENTS:
		is_true(catalog.find(ev).volume_db >= loudest_other, "%s oyun bilgisi; en yüksek kalmalı" % ev)
	var walk: SfxEntry = catalog.find(&"walk_step")
	var run: SfxEntry = catalog.find(&"run_step")
	is_true(walk.volume_db <= run.volume_db - 8.0, "yürüme adımı koşudan belirgin kısık")
	is_true(walk.max_distance > 0.0 and walk.max_distance < run.max_distance, "yürüme adımı kısa menzilli")
	is_true(walk.variants.size() >= 2, "yürüme adımı 3 varyant")


func test_entry_pick_stream_uses_variants() -> void:
	var entry: SfxEntry = _catalog().find(&"walk_step")
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var seen: Dictionary = {}
	for i: int in 60:
		seen[entry.pick_stream(rng)] = true
	eq(seen.size(), 1 + entry.variants.size(), "her varyant seçilebilir")
	is_true(SfxEntry.new().pick_stream(rng) == null, "dosyasız girdi null")


# --- SfxEmitter ---

func test_emitter_min_interval_per_event() -> void:
	var clock := FakeClock.new()
	var emitter: SfxEmitter = _emitter(clock)
	var interval: float = _catalog().find(&"door_open").min_interval
	is_true(emitter.play_event(&"door_open"), "ilk çalış")
	clock.t += interval * 0.5
	is_false(emitter.play_event(&"door_open"), "en kısa aralık dolmadan tekrar çalmaz")
	is_true(emitter.play_event(&"door_close"), "başka olay aralığa takılmaz")
	clock.t += interval
	is_true(emitter.play_event(&"door_open"), "aralık dolunca yeniden çalar")
	eq(emitter.stream, _catalog().find(&"door_open").stream, "çalan dosya katalogdaki")


func test_emitter_unknown_event_is_silent() -> void:
	var emitter: SfxEmitter = _emitter()
	is_false(emitter.play_event(&"no_such_event_is024"), "katalogda olmayan olay çalmaz (yalnız uyarı)")
	is_false(emitter.playing)


func test_emitter_outside_tree_is_silent() -> void:
	var emitter: SfxEmitter = autofree(SfxEmitter.new()) as SfxEmitter
	is_false(emitter.play_event(&"door_open"), "ağaçta olmayan çalar çalmaz")


func test_emitter_repeat_while_condition() -> void:
	var clock := FakeClock.new()
	var emitter: SfxEmitter = _emitter(clock)
	var interval: float = _catalog().find(&"register_tick").min_interval
	var count: Array[int] = [0]
	emitter.played.connect(func(_ev: StringName) -> void: count[0] += 1)
	var active: Array[bool] = [true]
	emitter.repeat_while(&"register_tick", func() -> bool: return active[0])
	await tree().process_frame
	await tree().process_frame
	eq(count[0], 1, "koşul doğruyken ilk tik; aralık dolmadan ikinci yok")
	clock.t += interval
	await tree().process_frame
	eq(count[0], 2, "aralık dolunca yeni tik")
	active[0] = false
	clock.t += interval * 3.0
	await tree().process_frame
	eq(count[0], 2, "koşul yanlışken tik yok")


# --- bound props ---

func test_door_toggle_plays_open_and_close() -> void:
	var door: Door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	tree().root.add_child(door)
	autofree(door)
	var heard: Array[StringName] = []
	SfxEmitter.of(door).played.connect(func(ev: StringName) -> void: heard.append(ev))
	door.is_open = not door.is_open
	door.is_open = not door.is_open
	eq(heard.size(), 2)
	if heard.size() == 2:
		eq(heard[0], &"door_open" if not door.is_open else &"door_close", "ilk değişim")
		eq(heard[1], &"door_close" if not door.is_open else &"door_open", "ikinci değişim")


func test_register_ticks_while_emptying_and_chimes_when_done() -> void:
	var register: Register = (load(REGISTER_SCENE) as PackedScene).instantiate() as Register
	tree().root.add_child(register)
	autofree(register)
	var interactable: Interactable = register.get_node("Interactable") as Interactable
	interactable.set_physics_process(false)  # no actor: the host must not cancel the duration
	var heard: Array[StringName] = []
	SfxEmitter.of(register).played.connect(func(ev: StringName) -> void: heard.append(ev))
	await tree().process_frame
	is_false(heard.has(&"register_tick"), "boşaltma yokken tik yok")
	interactable.busy_by = 1
	interactable.progress = 0.5
	await tree().process_frame
	await tree().process_frame
	is_true(heard.has(&"register_tick"), "boşaltılırken tik")
	interactable.busy_by = 0
	interactable.progress = 0.0
	register.emptied = true
	eq(heard.back(), &"register_done", "boşalınca \"çın\"")


func test_register_client_order_done_not_cut_by_late_progress() -> void:
	# On the client `emptied` (on change, every frame) can arrive before `busy_by/progress` (0.1 s apart): after the "ding" the old
	# progress may show one more frame yet no tick must play (on a single-channel player it would cut the "ding").
	var clock := FakeClock.new()
	var register: Register = (load(REGISTER_SCENE) as PackedScene).instantiate() as Register
	tree().root.add_child(register)
	autofree(register)
	var interactable: Interactable = register.get_node("Interactable") as Interactable
	interactable.set_physics_process(false)
	var emitter: SfxEmitter = SfxEmitter.of(register)
	emitter.clock = clock.now
	var heard: Array[StringName] = []
	emitter.played.connect(func(ev: StringName) -> void: heard.append(ev))
	interactable.busy_by = 1
	interactable.progress = 2.9
	await tree().process_frame
	await tree().process_frame
	register.emptied = true  # state arrives first
	clock.t += 5.0  # the tick interval has long elapsed
	await tree().process_frame
	await tree().process_frame
	interactable.busy_by = 0  # then the progress zero arrives
	interactable.progress = 0.0
	await tree().process_frame
	eq(heard.front(), &"register_tick")
	eq(heard.back(), &"register_done", "son çalan \"çın\": %s" % [heard])


func test_first_sync_is_silent_baseline_then_changes_play() -> void:
	# A late-joining/reconnecting client: the first sync packet is the base state (the event did not happen in front of that peer),
	# applied silently; the next change plays. The synchroniser signal is emitted by hand (client simulation).
	var door: Door = (load(DOOR_SCENE) as PackedScene).instantiate() as Door
	tree().root.add_child(door)
	autofree(door)
	var emitter: SfxEmitter = SfxEmitter.of(door)
	is_false(emitter.baseline_pending, "host/çevrimdışı taban beklemez")
	emitter.baseline_pending = true  # client: set up in _ready once the synchroniser is found
	var heard: Array[StringName] = []
	emitter.played.connect(func(ev: StringName) -> void: heard.append(ev))
	door.is_open = not door.is_open  # first sync packet (base)
	(door.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer).delta_synchronized.emit()
	eq(heard.size(), 0, "ilk eşitleme değeri ses çalmaz")
	eq(door.dump_state()["sfx"], {"played": 0, "silent": 1})
	door.is_open = not door.is_open  # next sync: a real change
	eq(heard.size(), 1, "ikinci değişim çalar")
	eq(door.dump_state()["sfx"], {"played": 1, "silent": 1})


func test_max_distance_reset_per_play() -> void:
	var emitter: SfxEmitter = _emitter()
	emitter.play_event(&"door_open")
	eq(emitter.max_distance, _catalog().find(&"door_open").max_distance)
	emitter.play_event(&"ui_click")  # no distance on input (0)
	eq(emitter.max_distance, SfxEmitter.DEFAULT_MAX_DISTANCE, "önceki olayın mesafesi kalmaz")


# --- headless ---

func test_headless_skips_stream_start() -> void:
	# In headless playback is not started (no dangling playback object at shutdown; IS-029 gate); the event is still processed.
	is_false(SfxCatalog.force_playback)
	var emitter: SfxEmitter = _emitter()
	is_true(emitter.play_event(&"door_open"), "olay işlenir (played, sayaç)")
	is_false(emitter.playing, "headless'ta akış başlamaz")
	eq(emitter.stats()["played"], 1)


func test_headless_playback_has_no_errors_or_warnings() -> void:
	# Real playback (force_playback): no errors/warnings on the dummy driver. When done the streams are stopped and the audio server is
	# expected to delete its playback objects (no object left dangling at process end).
	var logs := AllLogs.new()
	OS.add_logger(logs)
	SfxCatalog.force_playback = true
	var emitter: SfxEmitter = _emitter()
	var ui: UiSfx = UiSfx.of(emitter.get_parent())
	var played: int = 0
	var started: int = 0
	for ev: StringName in _catalog().events():
		if emitter.play_event(ev):
			played += 1
			started += int(emitter.playing)
		if ui.play_event(ev):
			played += 1
			started += int(ui.playing)
		for i: int in 2:
			await tree().process_frame
	SfxCatalog.force_playback = false
	emitter.stop()
	ui.stop()
	await tree().create_timer(0.3).timeout
	OS.remove_logger(logs)
	eq(played, _catalog().events().size() * 2, "her olay iki çalarda da çaldı")
	eq(started, played, "force_playback ile akış gerçekten başladı")
	eq(logs.entries.size(), 0, "ses çalışı hata/uyarı vermemeli: %s" % "; ".join(logs.entries))
