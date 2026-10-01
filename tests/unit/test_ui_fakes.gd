extends TestCase
## US-003 arayüz testleri için sahte Net / Game / oyuncu ve bunların sözleşmeye uyumu.
## Diğer test_ui_*.gd dosyaları `preload("res://tests/unit/test_ui_fakes.gd")` ile kullanır.
## Buradaki testler: sahteler gerçek autoload betikleriyle aynı imzayı taşır; ui/ betikleri Net/Game'de
## yalnız S1/S3 sözleşmesindeki sinyal ve fonksiyonları kullanır (mimari.md §6).

## S1 ve S3'teki genel adlar (docs/notes/mimari.md).
const CONTRACT := {
	"Net": [
		"peer_connected", "peer_disconnected", "connected_to_host", "connection_failed", "host_disconnected",
		"host", "join", "leave", "is_host", "is_online", "local_peer_id", "get_ping_ms",
	],
	"Game": [
		"players_changed", "local_player_changed", "team_cash_changed", "level_loaded", "session_event",
		"set_local_name", "players", "local_player", "start_level", "current_level", "add_team_cash",
		"team_cash", "raise_session_event", "register_dump_provider", "collect_dump",
	],
}
const REAL_SCRIPTS := {"Net": "res://autoload/net.gd", "Game": "res://autoload/game.gd"}
## ui/ betiklerinde bağımlılık değişkeni adı -> autoload.
const UI_VARS := {"net": "Net", "game": "Game"}


## Çağrıları ortak bir günlüğe yazar (Net ve Game çağrılarının sırası birlikte doğrulanabilsin).
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


class FakeGame extends Node:
	signal players_changed()
	signal local_player_changed(player: Node)
	signal team_cash_changed(value: int)
	signal level_loaded(level: Node)
	signal session_event(kind: StringName, data: Dictionary)

	var journal: CallLog = CallLog.new()
	var cash: int = 0
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


## S7 oyuncu sinyalleri (HUD sözleşmesi); yalnız yerel oyuncuda yayılır.
class FakePlayer extends Node:
	signal interaction_target_changed(action_key: String)
	signal interaction_started(action_key: String, duration: float)
	signal interaction_finished(success: bool)


## Net ve Game sahtelerini ortak günlükle kurar ve test sonunda serbest bırakılmak üzere kaydeder.
static func make_pair(test: TestCase) -> Array:
	var journal := CallLog.new()
	var net: FakeNet = test.autofree(FakeNet.new()) as FakeNet
	var game: FakeGame = test.autofree(FakeGame.new()) as FakeGame
	net.journal = journal
	game.journal = journal
	return [net, game, journal]


func test_fakes_match_real_autoload_signatures() -> void:
	var pairs := {"Net": FakeNet, "Game": FakeGame}
	for autoload_name: String in pairs:
		var real: Script = load(REAL_SCRIPTS[autoload_name]) as Script
		var fake: Script = pairs[autoload_name]
		var real_surface: Dictionary = _surface(real)
		for entry: String in _surface(fake):
			var member: String = entry.get_slice("/", 0)
			if not is_true(CONTRACT[autoload_name].has(member), "%s sahtesinde sözleşme dışı üye: %s" % [autoload_name, member]):
				continue
			is_true(real_surface.has(entry), "%s sahtesi gerçek imzadan farklı: %s" % [autoload_name, entry])


func test_ui_uses_only_contract_members() -> void:
	var used: Dictionary = {}
	for path: String in _files_under("res://ui", ".gd"):
		var source: String = FileAccess.get_file_as_string(path)
		var re := RegEx.create_from_string("\\b(net|game)\\.(call|connect|disconnect|is_connected)\\(&?\"([a-z_]+)\"")
		for m: RegExMatch in re.search_all(source):
			var autoload_name: String = UI_VARS[m.get_string(1)]
			used["%s.%s" % [autoload_name, m.get_string(3)]] = path
		# Sözleşmeli nesneye doğrudan özel üye erişimi (net._x / Game._x) olmamalı.
		var private_re := RegEx.create_from_string("\\b(net|game|Net|Game)\\._[a-z]")
		is_true(private_re.search(source) == null, "özel üye erişimi: " + path)
	is_true(used.size() >= 10, "ui/ betiklerinde Net/Game kullanımı bulunamadı (desen değişti mi?)")
	for key: String in used:
		var autoload_name: String = key.get_slice(".", 0)
		var member: String = key.get_slice(".", 1)
		is_true(CONTRACT[autoload_name].has(member), "%s sözleşmede yok (%s)" % [key, used[key]])
		var real: Script = load(REAL_SCRIPTS[autoload_name]) as Script
		var names: Dictionary = {}
		for entry: String in _surface(real):
			names[entry.get_slice("/", 0)] = true
		is_true(names.has(member), "%s gerçek betikte yok" % key)


# --- yardımcılar ---

## "ad/argüman sayısı" biçiminde sinyal ve genel metot listesi.
static func _surface(script: Script) -> Dictionary:
	var out: Dictionary = {}
	for s: Dictionary in script.get_script_signal_list():
		out["%s/%d" % [s["name"], (s["args"] as Array).size()]] = true
	for m: Dictionary in script.get_script_method_list():
		var method: String = m["name"]
		if not method.begins_with("_"):
			out["%s/%d" % [method, (m["args"] as Array).size()]] = true
	return out


static func _files_under(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(dir.path_join(d), ext))
	return out
