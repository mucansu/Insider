extends RefCounted
## Sözleşme yüzeyinin tek kaynağı (IS-039): docs/notes/mimari.md S1/S3/S4/S8 satırları birebir (yorumlar hariç).
## test_smoke.gd imzaları satır satır, test_ui_fakes.gd üye adlarını buradan okur.
## PENDING: sözleşmede olup gerçek koda henüz gelmemiş üyeler. Gerçek betikte yoksa denetim atlanır; üye gelince
## imza denetimi kendiliğinden açılır (yanlış imza düşer). Üye gerçek koda geldikten sonra listeden silinebilir.

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
		# S3 eki (Faz 2, KR-021; US-008/US-012/US-013).
		"signal alert_level_changed(level: int)",
		"func alert_level() -> int",
		"func alert_timer_left() -> float",
		"signal heist_finished(result: Dictionary)",
		"func heist_result() -> Dictionary",
		"func request_restart() -> void",
		"func venue_tier() -> int",
		# S3 görüş ekleri (US-011b/c, KR-023). set_vision_mode dönüşü belgede yazmıyor: void varsayıldı.
		"signal player_exposure_changed(peer: int, level: int)",
		"func player_exposure(peer: int) -> int",
		"func vision_mode() -> int",
		"func set_vision_mode(mode: int) -> void",
		"func player_world_position(peer: int) -> Vector2",
		# S3 eki adayı (US-038, kaçış okunurluğu; mimari.md'ye koordinatör işler): salt okunur, RPC yok.
		"func escape_point() -> Vector2",
		"func escape_status() -> Dictionary",
		# S3 eki (US-040, eli boş çekilme): HUD geri sayımı; salt okunur, RPC yok.
		"func abort_left() -> float",
	],
	"NoiseBus": [
		"func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void",
	],
	# S4 Level API (autoload değil; levels/level.gd, sınıf adı ve taban test_smoke'ta ayrıca denetlenir).
	"Level": [
		"func players_root() -> Node2D",
		"func props_root() -> Node2D",
		"func npcs_root() -> Node2D",
		"func spawn_count() -> int",
		"func spawn_position(index: int) -> Vector2",
		"func marker(marker_name: StringName) -> Node2D",
		# S4 eki (US-007) ve IS-027.
		"func marker_sequence(prefix: StringName) -> Array[Node2D]",
		"func zone(zone_name: StringName) -> Area2D",
		"func navigation_region() -> NavigationRegion2D",
		"func door_link(door_name: StringName) -> NavigationLink2D",
		"func map_rect() -> Rect2",
		# S3 eki (US-013): mekân kademesi.
		"func tier() -> int",
		# S3 görüş ekleri (sis; US-011a).
		"func attach_fog(observer: Node2D) -> FogLayer",
		"func fog_layer() -> FogLayer",
	],
}

const PENDING := {
	"Game": [
		"heist_finished", "heist_result",
		"request_restart", "venue_tier",
	],
	"Level": ["tier"],
}


## Sözleşme satırının üye adı ("signal x(...)", "func x(...)", "const X := ...", "var x: T").
static func member_name(line: String) -> String:
	var re := RegEx.create_from_string("^(?:static )?(?:signal|func|const|var) ([A-Za-z_][A-Za-z0-9_]*)")
	var m: RegExMatch = re.search(line)
	return m.get_string(1) if m != null else ""


## Sahibin (Net, Game, NoiseBus, Level) sözleşmeli üye adları.
static func names(owner: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in LINES.get(owner, []):
		out.append(member_name(line))
	return out


static func is_pending(owner: String, member: String) -> bool:
	return (PENDING.get(owner, []) as Array).has(member)
