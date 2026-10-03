extends RefCounted
## Single source of the contract surface (IS-039): the S1/S3/S4/S8 lines of docs/notes/mimari.md, verbatim (comments excluded).
## test_smoke.gd reads signatures line by line; test_ui_fakes.gd reads member names from here.
## PENDING: contract members not in real code yet; the check is skipped while the script lacks them and
## turns on by itself once they land (a wrong signature then fails). Remove from the list afterwards.

const LINES := {
	"Net": [
		"signal peer_connected(peer_id: int)",
		"signal peer_disconnected(peer_id: int)",
		"signal connected_to_host()",
		"signal connection_failed()",
		"signal host_disconnected()",
		"func host(port: int = 7777, max_peers: int = 4) -> Error",
		"func join(address: String, port: int = 7777) -> Error",
		"func leave() -> void",
		"func is_host() -> bool",
		"func is_online() -> bool",
		"func local_peer_id() -> int",
		"func get_ping_ms(peer_id: int = 1) -> int",
		"func get_ping_info(peer_id: int = 1) -> Dictionary",
	],
	"Game": [
		"signal players_changed()",
		"signal local_player_changed(player: Node)",
		"signal team_cash_changed(value: int)",
		"signal level_loaded(level: Node)",
		"signal session_event(kind: StringName, data: Dictionary)",
		"const DEFAULT_LEVEL := \"res://levels/store_a.tscn\"",
		"const HUD_SCENE := \"res://ui/hud.tscn\"",
		"var player_scene: PackedScene",
		"func set_local_name(player_name: String) -> void",
		"func players() -> Dictionary",
		"func local_player() -> Node",
		"func start_level(level_path: String) -> void",
		"func current_level() -> Node",
		"func add_team_cash(amount: int) -> void",
		"func team_cash() -> int",
		"func raise_session_event(kind: StringName, data: Dictionary = {}) -> void",
		"func register_dump_provider(key: String, provider: Callable) -> void",
		"func collect_dump() -> Dictionary",
		# S3 addition (Phase 2, KR-021; US-008/US-012/US-013).
		"signal alert_level_changed(level: int)",
		"func alert_level() -> int",
		"func alert_timer_left() -> float",
		"signal heist_finished(result: Dictionary)",
		"func heist_result() -> Dictionary",
		"func request_restart() -> void",
		"func venue_tier() -> int",
		# S3 vision additions (US-011b/c, KR-023). The set_vision_mode return type is not in the doc: assumed void.
		"signal player_exposure_changed(peer: int, level: int)",
		"func player_exposure(peer: int) -> int",
		"func vision_mode() -> int",
		"func set_vision_mode(mode: int) -> void",
		"func player_world_position(peer: int) -> Vector2",
		# S3 addition candidate (US-038, escape legibility; coordinator carries it to mimari.md): read-only, no RPC.
		"func escape_point() -> Vector2",
		"func escape_status() -> Dictionary",
		# S3 addition (US-040, empty-handed retreat): HUD countdown; read-only, no RPC.
		"func abort_left() -> float",
		# S3 addition (US-042, cover): local player's cover (1 intact, 0 broken, -1 no job); read-only.
		"func cover_state() -> int",
		# S3 addition (IS-058b): session seed of the current job (host decides; a client reads 0).
		"func session_seed() -> int",
	],
	"NoiseBus": [
		"func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void",
	],
	# S4 Level API (not an autoload; levels/level.gd, class name and base are checked separately in test_smoke).
	"Level": [
		"func players_root() -> Node2D",
		"func props_root() -> Node2D",
		"func npcs_root() -> Node2D",
		"func spawn_count() -> int",
		"func spawn_position(index: int) -> Vector2",
		"func marker(marker_name: StringName) -> Node2D",
		# S4 addition (US-007) and IS-027.
		"func marker_sequence(prefix: StringName) -> Array[Node2D]",
		"func zone(zone_name: StringName) -> Area2D",
		"func navigation_region() -> NavigationRegion2D",
		"func door_link(door_name: StringName) -> NavigationLink2D",
		"func map_rect() -> Rect2",
		# S3 addition (US-013): venue tier.
		"func tier() -> int",
		# S3 vision additions (fog; US-011a).
		"func attach_fog(observer: Node2D) -> FogLayer",
		"func fog_layer() -> FogLayer",
	],
	# S6 addition (IS-015a): closed-loop bot brain arguments (autoload Args; checked by test_smoke like the other autoloads).
	"Args": [
		"var brain: String",
		"var run_seed: int",
		"var run_seed_given: bool",
		"var quit_on_heist_end: float",
		# IS-058b: brain loop.
		"var brain_loop: float",
	],
	# S6 addition (IS-015a): bot brain surface the statistics runner (IS-015b) relies on (entities/player/bot_brain.gd; checked in
	# tests/unit/test_bot_brain.gd). Dump section "brain": strategy, seed, role, phase, phase_log, stuck_s (+ counters).
	"BotBrain": [
		"const DUMP_KEY := \"brain\"",
		"func requested() -> bool",
		"func from_args() -> BotBrain",
		"func spec_from_file(path: String) -> Dictionary",
		"func tick(player: Player, frame: int, delta: float) -> void",
		"func dump_state() -> Dictionary",
		# IS-058b: fair sight / brain loop (dump additions omni, run, sight, runs).
		"func is_omni() -> bool",
		"func runs() -> Array[Dictionary]",
	],
}

const PENDING := {
	"Game": [
		"heist_finished", "heist_result",
		"request_restart", "venue_tier",
	],
	"Level": ["tier"],
}


## Member name of a contract line ("signal x(...)", "func x(...)", "const X := ...", "var x: T").
static func member_name(line: String) -> String:
	var re := RegEx.create_from_string("^(?:static )?(?:signal|func|const|var) ([A-Za-z_][A-Za-z0-9_]*)")
	var m: RegExMatch = re.search(line)
	return m.get_string(1) if m != null else ""


## Contract member names of the owner (Net, Game, NoiseBus, Level).
static func names(owner: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in LINES.get(owner, []):
		out.append(member_name(line))
	return out


static func is_pending(owner: String, member: String) -> bool:
	return (PENDING.get(owner, []) as Array).has(member)
