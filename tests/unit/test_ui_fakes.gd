extends TestCase
## Fake Net / Game / player for US-003 UI tests and their conformance to the contract.
## Other test_ui_*.gd files use it via `preload("res://tests/unit/test_ui_fakes.gd")`.
## The tests here: the fakes carry the same signatures as the real autoload scripts; ui/ scripts use only the signals and functions
## of the S1/S3 contract on Net/Game (mimari.md §6).

## Public names in S1 and S3 and members not yet in a real autoload (PENDING) are in a single source: tests/contracts.gd
## (IS-039; test_smoke.gd reads the signatures from there too). If a PENDING member is absent from the real script the presence/
## signature check is skipped; once it arrives it must carry the same signature as the fake (the check turns on by itself).
const Contracts := preload("res://tests/contracts.gd")
const REAL_SCRIPTS := {"Net": "res://autoload/net.gd", "Game": "res://autoload/game.gd"}
## Dependency variable name in ui/ scripts -> autoload.
const UI_VARS := {"net": "Net", "game": "Game"}


## Writes calls to a shared log (so the order of Net and Game calls can be verified together).
class CallLog extends RefCounted:
	var entries: Array = []

	func add(entry: Array) -> void:
		entries.append(entry)

	func names() -> PackedStringArray:
		var out: PackedStringArray = []
		for e: Array in entries:
			out.append(str(e[0]))
		return out


class FakeNet extends Node:
	signal peer_connected(peer_id: int)
	signal peer_disconnected(peer_id: int)
	signal connected_to_host()
	signal connection_failed()
	signal host_disconnected()

	var journal: CallLog = CallLog.new()
	var host_result: Error = OK
	var join_result: Error = OK
	var hosting: bool = false
	var ping_ms: int = -1
	var ping_calls: int = 0
	var my_peer_id: int = 1

	func host(port: int = 7777, _max_peers: int = 4) -> Error:
		journal.add(["host", port])
		return host_result

	func join(address: String, port: int = 7777) -> Error:
		journal.add(["join", address, port])
		return join_result

	func leave() -> void:
		journal.add(["leave"])

	func is_host() -> bool:
		return hosting

	func is_online() -> bool:
		return true

	func local_peer_id() -> int:
		return my_peer_id

	func get_ping_ms(_peer_id: int = 1) -> int:
		ping_calls += 1
		return ping_ms


## S3 (Phase 1) surface; for a Game without the S3 addition (e.g. today's real Game).
class FakeGameBase extends Node:
	signal players_changed()
	signal local_player_changed(player: Node)
	signal team_cash_changed(value: int)
	signal level_loaded(level: Node)
	signal session_event(kind: StringName, data: Dictionary)

	var journal: CallLog = CallLog.new()
	var cash: int = 0
	## players() return in S3 form: peer_id -> {"name": String, "slot": int} (no colour; the HUD picks from the slot).
	var roster: Dictionary = {}
	var local: Node = null

	func set_local_name(player_name: String) -> void:
		journal.add(["set_local_name", player_name])

	func players() -> Dictionary:
		return roster

	func local_player() -> Node:
		return local

	func start_level(level_path: String) -> void:
		journal.add(["start_level", level_path])

	func team_cash() -> int:
		return cash


## S3 + S3 addition (alert ladder, job result). Signal emission in the test: `alert_level_changed.emit(2)` etc.
class FakeGame extends FakeGameBase:
	signal alert_level_changed(level: int)
	signal heist_finished(result: Dictionary)

	var alert: int = 0
	## Police timer (s); -1 if none.
	var timer_left: float = -1.0
	## heist_result() return; empty if the job has not ended.
	var result: Dictionary = {}
	## venue_tier() return (venue tier; shop 1).
	var tier: int = 1

	func alert_level() -> int:
		return alert

	func alert_timer_left() -> float:
		return timer_left

	func heist_result() -> Dictionary:
		return result

	func request_restart() -> void:
		journal.add(["request_restart"])

	func venue_tier() -> int:
		return tier

	## US-038 escape helpers: escape_point() (INF if none) and escape_status() {"in_zone", "free"}.
	var escape_at: Vector2 = Vector2.INF
	var escape: Dictionary = {"in_zone": 0, "free": 0}

	func escape_point() -> Vector2:
		return escape_at

	func escape_status() -> Dictionary:
		return escape

	## US-040 empty-handed retreat countdown (s); -1 if no counter.
	var abort: float = -1.0

	func abort_left() -> float:
		return abort

	## US-042 local cover: 1 intact, 0 broken, -1 no job.
	var cover: int = -1

	func cover_state() -> int:
		return cover


## S3 + S3 addition + vision addition (mimari.md, US-011b/c): exposure, player world position, the host's vision mode.
class FakeVisionGame extends FakeGame:
	signal player_exposure_changed(peer: int, level: int)

	## peer -> exposure (0 hidden, 1 visible, 2 seen); 0 if none.
	var exposure: Dictionary = {}
	## peer -> world position; Vector2.INF if none (no player).
	var positions: Dictionary = {}
	## vision_mode() return (0 peripheral 360 deg, 1 directional).
	var vision: int = 0

	func player_exposure(peer: int) -> int:
		return int(exposure.get(peer, 0))

	func player_world_position(peer: int) -> Vector2:
		return positions.get(peer, Vector2.INF)

	func vision_mode() -> int:
		return vision

	func set_vision_mode(mode: int) -> void:
		journal.add(["set_vision_mode", mode])
		vision = mode


## S7 player signals (HUD contract); emitted only on the local player.
class FakePlayer extends Node:
	signal interaction_target_changed(action_key: String)
	signal interaction_alt_target_changed(action_key: String)
	signal interaction_started(action_key: String, duration: float)
	signal interaction_finished(success: bool)


## Settings file for screen tests (US-026): the player's real user://connect.cfg is neither read nor written.
const TEST_SETTINGS_PATH := "user://test_ui_connect.cfg"


## Builds the Net and Game fakes with a shared log and registers them to be freed at test end.
## If `vision` the Game fake also carries the vision addition (FakeVisionGame). Redirects the settings file path to the test file;
## if `fresh_settings` the file is deleted (screens do not open with remembered values), otherwise values the test wrote earlier remain.
static func make_pair(test: TestCase, vision: bool = false, fresh_settings: bool = true) -> Array:
	if fresh_settings:
		reset_connect_settings()
	else:
		ConnectInfo.settings_path = TEST_SETTINGS_PATH
	var journal := CallLog.new()
	var net: FakeNet = test.autofree(FakeNet.new()) as FakeNet
	var game: FakeGame = test.autofree(FakeVisionGame.new() if vision else FakeGame.new()) as FakeGame
	net.journal = journal
	game.journal = journal
	return [net, game, journal]


func test_fakes_match_real_autoload_signatures() -> void:
	var pairs: Array = [["Net", FakeNet], ["Game", FakeGame], ["Game", FakeVisionGame]]
	for pair: Array in pairs:
		var autoload_name: String = pair[0]
		var real: Script = load(REAL_SCRIPTS[autoload_name]) as Script
		var fake: Script = pair[1]
		var real_surface: Dictionary = _surface(real)
		for entry: String in _surface(fake):
			var member: String = entry.get_slice("/", 0)
			if not is_true(Contracts.names(autoload_name).has(member), "%s sahtesinde sözleşme dışı üye: %s" % [autoload_name, member]):
				continue
			if _pending(autoload_name, member) and not _has_member(real_surface, member):
				continue  # in the contract but not yet in the real script
			is_true(real_surface.has(entry), "%s sahtesi gerçek imzadan farklı: %s" % [autoload_name, entry])


func test_ui_uses_only_contract_members() -> void:
	var used: Dictionary = {}
	for path: String in _files_under("res://ui", ".gd"):
		var source: String = FileAccess.get_file_as_string(path)
		var re := RegEx.create_from_string("\\b(net|game)\\.(call|connect|disconnect|is_connected)\\(&?\"([a-z_]+)\"")
		for m: RegExMatch in re.search_all(source):
			var autoload_name: String = UI_VARS[m.get_string(1)]
			used["%s.%s" % [autoload_name, m.get_string(3)]] = path
		# There must be no direct private member access on the contract object (net._x / Game._x).
		var private_re := RegEx.create_from_string("\\b(net|game|Net|Game)\\._[a-z]")
		is_true(private_re.search(source) == null, "özel üye erişimi: " + path)
	is_true(used.size() >= 10, "ui/ betiklerinde Net/Game kullanımı bulunamadı (desen değişti mi?)")
	for key: String in used:
		var autoload_name: String = key.get_slice(".", 0)
		var member: String = key.get_slice(".", 1)
		is_true(Contracts.names(autoload_name).has(member), "%s sözleşmede yok (%s)" % [key, used[key]])
		var real: Script = load(REAL_SCRIPTS[autoload_name]) as Script
		var names: Dictionary = {}
		for entry: String in _surface(real):
			names[entry.get_slice("/", 0)] = true
		is_true(names.has(member) or _pending(autoload_name, member), "%s gerçek betikte yok" % key)


# --- helpers ---

static func _pending(autoload_name: String, member: String) -> bool:
	return Contracts.is_pending(autoload_name, member)


static func _has_member(surface: Dictionary, member: String) -> bool:
	for entry: String in surface:
		if entry.get_slice("/", 0) == member:
			return true
	return false


## A list of signals and public methods as "name/arg count/(arg types)->return type"; type = Variant type number + class name
## (e.g. "player_exposure/1/(2)->2", "local_player/0/()->24:Node"). No return on a signal.
## The key starts with "name/" (member name `get_slice("/", 0)`).
static func _surface(script: Script) -> Dictionary:
	var type_of := func(info: Dictionary) -> String:
		var class_id: String = str(info.get("class_name", ""))
		return str(int(info.get("type", TYPE_NIL))) + (":" + class_id if not class_id.is_empty() else "")
	var args_of := func(args: Array) -> String:
		var parts: PackedStringArray = []
		for a: Dictionary in args:
			parts.append(type_of.call(a))
		return "%d/(%s)" % [args.size(), ",".join(parts)]
	var out: Dictionary = {}
	for s: Dictionary in script.get_script_signal_list():
		out["%s/%s" % [s["name"], args_of.call(s["args"])]] = true
	for m: Dictionary in script.get_script_method_list():
		var method: String = m["name"]
		if not method.begins_with("_"):
			out["%s/%s->%s" % [method, args_of.call(m["args"]), type_of.call(m.get("return", {}))]] = true
	return out


static func _files_under(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(dir.path_join(d), ext))
	return out


## Resets ConnectInfo to the test settings file and deletes the file; resets the host port from the menu.
static func reset_connect_settings() -> void:
	ConnectInfo.settings_path = TEST_SETTINGS_PATH
	ConnectInfo.hosted_port = 0
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
