extends TestCase
## IS-081: owner event log (core/owner_log.gd, OwnerBrain.event_log, dump `owner.log` / `owner.log_dropped`) and AC3 (a player raises
## `player_caught` at most once per node; after the job result no new hold/catch/window catch).
## - OwnerLog: entry only on (state, task, target) change or pending notes; notes in one step merge; `ref` points to a dump record;
##   ring buffer keeps the last `capacity` entries and counts the dropped ones; throttled notes; default reasons.
## - Brain (store_a, single process = host): the first step writes the agenda entry; a door sound writes "ses 'door' -> DİNLE";
##   a discovery writes the trigger reason with `ref` discoveries[0]; dump has `log` (host).

const DT := 1.0 / 30.0
const PLAYER_SCENE := "res://entities/player/player.tscn"


func _tick(book: OwnerLog, t: float, state: StringName, task: StringName = &"counter", target: int = 0) -> bool:
	return book.tick(t, state, task, Vector2.LEFT, target, 0, 0.0)


func test_entry_on_key_change_only() -> void:
	var book := OwnerLog.new()
	is_true(_tick(book, 0.0, &"agenda"), "ilk adım kayıt")
	is_false(_tick(book, 0.1, &"agenda"), "aynı anahtar: kayıt yok")
	is_true(_tick(book, 0.2, &"agenda", &"shelf"), "görev değişti")
	is_true(_tick(book, 0.3, &"look", &"shelf", 2), "durum + hedef")
	is_false(_tick(book, 0.4, &"look", &"shelf", 2))
	eq(book.entries.size(), 3)
	eq(book.entries[0]["why"], "görev: counter")
	eq(book.entries[1]["why"], "görev: shelf")
	eq(book.entries[2]["why"], "şüphe ? -> BAK p2")
	eq(book.entries[2]["state"], "look")
	eq(book.entries[2]["task"], "shelf")
	eq(book.entries[2]["target"], 2)
	eq(book.entries[2]["facing"], [-1.0, 0.0])
	for key: String in ["t", "state", "task", "facing", "target", "why", "top_peer", "top_value"]:
		has(book.entries[0], key)


func test_notes_merge_and_ref() -> void:
	var book := OwnerLog.new()
	_tick(book, 0.0, &"agenda")
	book.note("kasa boş, dönüş kontrolü (register)", "discoveries[0]")
	book.note_event(&"owner_discover_register", 0)
	book.note_event(&"owner_listen", 0)  # empty line: not noted
	is_true(_tick(book, 1.0, &"discover"), "not bekliyor: kayıt")
	eq(book.entries[1]["why"], "kasa boş, dönüş kontrolü (register); balon: kasa boş")
	eq(book.entries[1]["ref"], "discoveries[0]")
	is_false(book.entries[0].has("ref"), "ref yalnız notla")
	book.note("tespit p3")
	is_true(_tick(book, 1.1, &"discover"), "anahtar aynı ama not var")
	eq(book.entries[2]["why"], "tespit p3")
	is_false(book.entries[2].has("ref"), "ref bir sonraki kayda taşınmaz")
	book.note_event(&"owner_held", 2)
	_tick(book, 2.0, &"hold", &"", 2)
	eq(book.entries[3]["why"], "tuttu p2")


func test_ring_buffer_limit() -> void:
	eq(OwnerLog.DEFAULT_CAPACITY, 200)
	var book := OwnerLog.new(5)
	for i: int in 12:
		book.note("olay %d" % i)
		_tick(book, float(i), &"agenda")
	eq(book.entries.size(), 5, "son 5 kayıt")
	eq(book.dropped, 7)
	eq(book.entries[0]["why"], "olay 7")
	eq(book.entries[4]["why"], "olay 11")
	var rows: Array[Dictionary] = book.rows()
	rows[0]["why"] = "x"
	eq(book.entries[0]["why"], "olay 7", "rows() kopya")


func test_throttled_note() -> void:
	var book := OwnerLog.new()
	book.note_throttled("hear:run", "a", 0.0, 2.0)
	book.note_throttled("hear:run", "b", 1.0, 2.0)
	book.note_throttled("hear:door", "c", 1.0, 2.0)
	_tick(book, 1.0, &"chase")
	eq(book.entries[0]["why"], "a; c", "aynı anahtar 2 sn içinde tekrar yazılmaz")
	book.note_throttled("hear:run", "d", 2.5, 2.0)
	_tick(book, 2.5, &"chase")
	eq(book.entries[1]["why"], "d")


func test_default_why() -> void:
	eq(OwnerLog.default_why(&"agenda", &"listen", 0), "ses -> DİNLE")
	eq(OwnerLog.default_why(&"agenda", &"customer", 0), "müşteri servisi")
	eq(OwnerLog.default_why(&"agenda", &"", 0), "görev yok")
	eq(OwnerLog.default_why(&"search", &"", 0), "hedef kayıp -> ARA")
	for state: StringName in OwnerBrain.STATE_NAMES:
		if state != &"agenda":
			is_true(OwnerLog.STATE_LINES.has(state), "durum satırı: %s" % state)


## Brain integration: agenda entry, door sound -> LISTEN reason, discovery with ref, dump key.
func test_brain_log_and_dump() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	stage.run(0.5, Callable(), DT)
	var book: OwnerLog = o.brain().event_log
	if not is_true(book.entries.size() >= 1, "ilk adım kaydı"):
		stage.leave()
		return
	eq(book.entries[0]["state"], "agenda")
	NoiseBus.emit_noise(stage.marker(&"BackroomDoor"), 160.0, NoiseProfile.KIND_DOOR)
	stage.run(0.1, Callable(), DT)
	var last: Dictionary = book.entries[-1]
	eq(last["task"], "listen", "kapı sesi -> DİNLE kaydı")
	eq(last["why"], "ses 'door' -> DİNLE")
	is_true(o.discover(OwnerBrain.Source.REGISTER), "keşif")
	stage.run(DT, Callable(), DT)
	last = book.entries[-1]
	eq(last["state"], "discover")
	eq(last["ref"], "discoveries[0]", "keşif kaydına referans (alan tekrarı yok)")
	is_true(str(last["why"]).begins_with("keşif (register)"), "neden: %s" % last["why"])
	var dump: Dictionary = o.dump_state()
	has(dump, "log")
	has(dump, "log_dropped")
	eq((dump["log"] as Array).size(), book.entries.size())
	eq(dump["log_dropped"], 0)
	is_true(Game.to_json_value(dump["log"]) is Array, "JSON'a yazılabilir")
	stage.leave()


func _player(peer_name: String) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = peer_name
	player.position = Vector2(100, 100)
	tree().root.add_child(player)
	autofree(player)
	return player


## AC3: hold -> rescue -> hold again -> window -> CAUGHT once; a second catch (chaser) is refused: one caught transition per player.
func test_caught_once_per_player() -> void:
	var player: Player = _player("1")
	var states: Array[int] = []
	player.status_changed.connect(func(s: int) -> void: states.append(s))
	await tree().physics_frame
	is_true(player.host_hold(6.0), "ilk tutma")
	is_true(player.host_release(), "kurtarıldı")
	is_true(player.host_hold(0.2), "ikinci tutma (meşru tekrar)")
	for i: int in 30:
		await tree().physics_frame
	is_true(player.is_caught(), "pencere doldu")
	eq(player.caught_by(), &"owner")
	is_false(player.host_catch(&"chaser"), "yakalanan yeniden yakalanmaz")
	is_false(player.host_hold(6.0), "yakalanan tutulamaz")
	eq(player.caught_by(), &"owner", "yakalayan değişmez")
	eq(states.count(PlayerStatus.State.CAUGHT), 1, "tek yakalanma geçişi")
	eq(states.count(PlayerStatus.State.HELD), 2, "iki tutma")
	eq(player.times_held(), 2)


## AC3 fix: after the job result no new hold/catch and an open window does not turn into CAUGHT (no late `player_caught`).
func test_no_catch_after_heist_result() -> void:
	var free_one: Player = _player("1")
	var held_one: Player = _player("2")
	await tree().physics_frame
	is_true(held_one.host_hold(0.2))
	Game._rpc_heist_finished({"outcome": &"caught"})
	is_false(free_one.host_hold(6.0), "iş bitti: tutma yok")
	is_false(free_one.host_catch(&"chaser"), "iş bitti: yakalama yok")
	for i: int in 30:
		await tree().physics_frame
	is_true(held_one.is_held(), "açık pencere yakalamaya dönmez")
	is_false(held_one.is_caught())
	Game._heist_on_level_exiting()
	is_true(Game.heist_result().is_empty())
	is_true(free_one.host_catch(&"chaser"), "yeni iş: yakalama yine çalışır")
