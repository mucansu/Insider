extends TestCase
## IS-014 (3): the remote player's "interacting" indicator is also drawn on other peers. The remote copy derives the state from
## the host-replicated `Interactable.busy_by` (no extra network field); the visual draws the same point in the active tone's
## colour (ThemeTokens) via the same path (Player.is_interacting()) for local and remote players. Single process: offline
## singular id 1 = host. Also (4): test_interaction*.gd files do not access `_`-prefixed members (§6, KR-018).

const REGISTER_SCENE := "res://entities/props/register.tscn"
const PLAYER_SCENE := "res://entities/player/player.tscn"
const REG_POS := Vector2(560, 368)
const STAFF := Vector2(588, 368)
const TEST_DIR := "res://tests/unit"
const Deps := preload("res://tests/unit/test_deps.gd")


func _register() -> Interactable:
	var reg: Node2D = (load(REGISTER_SCENE) as PackedScene).instantiate() as Node2D
	reg.position = REG_POS
	tree().root.add_child(reg)
	autofree(reg)
	return reg.get_node("Interactable") as Interactable


func _player(peer_id: int, at: Vector2) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id, true)
	player.position = at
	tree().root.add_child(player)
	autofree(player)
	return player


func _visual(player: Player) -> PlayerVisual:
	return player.get_node("Visual") as PlayerVisual


func _frames(count: int) -> void:
	for i: int in count:
		await tree().process_frame


func test_remote_player_shows_indicator_from_host_state() -> void:
	var item: Interactable = _register()
	var remote: Player = _player(7, STAFF)
	var bystander: Player = _player(8, STAFF + Vector2(0, 20))
	await _frames(2)
	is_false(remote.is_interacting())
	is_false(_visual(remote).shows_interaction(), "boşta gösterge yok")
	# The host accepts the remote peer's request (RPC body): busy_by = 7.
	item.host_start(7, 1)
	eq(item.busy_by, 7)
	await _frames(2)
	is_true(remote.is_interacting(), "uzak kopya host durumundan etkileşimde")
	is_true(_visual(remote).shows_interaction(), "gösterge diğer peer'da çizilir")
	is_false(bystander.is_interacting(), "başka peer'ın etkileşimi yanmaz")
	eq(_visual(remote).interaction_marker_color(), ThemeTokens.tone().bg_color, "renk etkin tondan (S9)")
	item.host_cancel(7, 1)
	await _frames(2)
	is_false(remote.is_interacting(), "iptalde söner")
	is_false(_visual(remote).shows_interaction())


## On the client: once the replicated busy_by is written from the synchroniser (directly here), the same indicator.
func test_replicated_busy_by_drives_remote_indicator() -> void:
	var item: Interactable = _register()
	var remote: Player = _player(5, STAFF)
	item.busy_by = 5
	await _frames(2)
	is_true(_visual(remote).shows_interaction())
	item.busy_by = 0
	await _frames(2)
	is_false(_visual(remote).shows_interaction())


## The local player shows it immediately on press (GDD §12); the look matches the remote copy (same point, same colour).
func test_local_indicator_same_look() -> void:
	var item: Interactable = _register()
	var local: Player = _player(1, STAFF)
	var remote: Player = _player(6, STAFF + Vector2(0, 16))
	var input: PlayerInput = local.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.05, "hold": "interact", "dur": 1.0}]))
	for i: int in 10:
		await tree().physics_frame
	await _frames(1)
	is_true(local.is_interacting(), "yerel: basılı tutarken")
	eq(item.busy_by, 1)
	is_true(_visual(local).shows_interaction())
	is_false(_visual(remote).shows_interaction())
	eq(_visual(local).interaction_marker_color(), _visual(remote).interaction_marker_color(), "aynı renk")


## KR-018 §6: interaction tests do not reach `_`-prefixed class members from outside (public API or hook).
func test_interaction_tests_use_public_api() -> void:
	var pattern := RegEx.create_from_string("\\._[a-z]\\w*")
	var checked: int = 0
	for f: String in DirAccess.get_files_at(TEST_DIR):
		if not (f.begins_with("test_interaction") and f.ends_with(".gd")):
			continue
		checked += 1
		var path: String = TEST_DIR.path_join(f)
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var found: RegExMatch = pattern.search(Deps.strip_comment(line))
			is_true(found == null, "%s özel üye erişimi: %s" % [f, line.strip_edges()])
	is_true(checked >= 4, "test_interaction*.gd dosyaları tarandı")
