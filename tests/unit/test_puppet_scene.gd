extends TestCase
## US-014 puppet scene: replaces the placeholder in the player scene (AC1), only reads state - locally from the Player's state, on
## a remote copy from the interpolated buffer state (AC3), collision radius unchanged, markers (name, balloon, badge) at a fixed
## anchor and >= 22 px (GDD §14.1 rule 2), no "pop" when a remote copy's position jumps (rule 6), reduced motion API (AC4),
## dependency direction (the puppet does not reference logic/network scripts). Maths tests: test_puppet.gd.

const SCENE := "res://entities/player/player.tscn"
const PUPPET_DIR := "res://entities/player/puppet"
const TUNING_SCRIPT := "res://data/puppet_tuning.gd"
const Deps := preload("res://tests/unit/test_deps.gd")
const Rules := preload("res://tests/unit/test_player_rules.gd")
## Forbidden references in puppet scripts: input, network, session, movement/player logic, NPC/interaction rules.
const FORBIDDEN: Array[String] = [
	"\\bInput\\.", "\\bPlayerInput\\b", "\\bmultiplayer\\b", "\\brpc", "\\bNet\\.", "\\bGame\\.", "\\bArgs\\.",
	"\\bNoiseBus\\b", "move_and_slide", "\\bPlayer\\b", "\\bPlayerMotion\\b", "\\bPlayerInteraction\\b",
	"\\bSnapshotBuffer\\b", "\\bInteractable\\b", "\\bPlayerVisual\\b", "\\bCharacterBody2D\\b",
	"res://(autoload|core|levels)/",
]
## Node scripts do not change their own position/transform; other puppet scripts are no-node maths/data.
const NODE_SCRIPTS: Array[String] = ["puppet.gd", "puppet_markers.gd"]
## (Writing to another object's field, e.g. `_mesh.transform = ...`, is allowed.)
const NODE_WRITES := "(^|[^.\\w]|self\\.)(global_)?(position|rotation|scale|transform)\\s*[-+*/]?=[^=]"
## No-node scripts (rig, body, eyes, scarf, spring, look) know no nodes or theme.
const RIG_FORBIDDEN: Array[String] = ["\\bNode2?D?\\b", "get_node", "\\bThemeTokens\\b", "get_tree", "\\$"]


func _spawn(authority: int, at: Vector2) -> Player:
	var player: Player = (load(SCENE) as PackedScene).instantiate() as Player
	player.name = str(authority)
	player.set_multiplayer_authority(authority, true)
	player.position = at
	tree().root.add_child(player)
	autofree(player)
	return player


func _puppet(player: Player) -> Puppet:
	return player.get_node("Visual/Puppet") as Puppet


func _frames(count: int) -> void:
	for i: int in count:
		await tree().process_frame


func _physics(count: int) -> void:
	for i: int in count:
		await tree().physics_frame


# --- AC1: scene ---

func test_player_scene_has_puppet() -> void:
	var player: Player = autofree((load(SCENE) as PackedScene).instantiate()) as Player
	var visual: Node = player.get_node("Visual")
	is_true(visual is PlayerVisual)
	var puppet: Node = visual.get_node_or_null("Puppet")
	if not is_true(puppet is Puppet, "Visual/Puppet kukla"):
		return
	is_true(puppet.get_node_or_null("Markers") is PuppetMarkers, "işaretler ayrı düğüm")
	is_true((puppet as Puppet).tuning != null, "tuning bağlı (data/puppet_tuning.tres)")
	eq((puppet as Puppet).tuning.resource_path, "res://data/puppet_tuning.tres")
	var label: Node = visual.get_node_or_null("NameLabel")
	is_true(label is Label, "ad etiketi korunur")
	is_true(label != null and label.get_index() > puppet.get_index(), "ad etiketi kuklanın üstünde çizilir")
	# No collision in the visual; body radius 12 (AC3).
	for node: Node in visual.find_children("*", "", true, false):
		is_false(node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D,
			"görselde çarpışma düğümü yok: %s" % node.name)
	var body: CircleShape2D = (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	near(body.radius, 12.0, 0.0001, "çarpışma yarıçapı 12")


func test_colors_and_looks_from_identity() -> void:
	var before: Dictionary = Game.players()
	Game._rpc_players({2: {"name": "Ayşe", "slot": 1}, 3: {"name": "Bora", "slot": 2}})
	var a: Player = _spawn(2, Vector2(100, 0))
	var b: Player = _spawn(3, Vector2(300, 0))
	await _frames(1)
	eq(_puppet(a).accent_color(), ThemeTokens.PLAYER_COLORS[1], "atkı oyuncu renginde")
	eq(_puppet(b).accent_color(), ThemeTokens.PLAYER_COLORS[2])
	var looks: Array[PuppetLook] = _puppet(a).tuning.player_looks
	is_true(_puppet(a).look == looks[1] and _puppet(b).look == looks[2], "görünüm yuvadan")
	is_true(_puppet(a).look.gear != _puppet(b).look.gear, "farklı yuva farklı başlık silueti")
	is_true(_puppet(a).rig().scarf_points().size() == 6, "atkı 6 parça")
	Game._rpc_players(before)


# --- AC3: only reads state ---

func test_local_puppet_follows_player_state() -> void:
	var player: Player = _spawn(1, Vector2.ZERO)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sneak"}]))
	await _physics(50)
	var rig: PuppetRig = _puppet(player).rig()
	eq(rig.gait, PuppetRig.Gait.SNEAK, "kip Player.move_mode'dan")
	near(rig.target_velocity, player.velocity, 0.001, "hız Player.velocity'den")
	near(rig.target_facing, Vector2.RIGHT, 0.001)
	near(rig.squash_y(), 0.84, 0.07, "sızma çömelik")
	is_true(rig.position.distance_to(player.global_position) < 8.0, "kukla oyuncuyla birlikte")
	eq(_puppet(player).position, Vector2.ZERO, "kukla kendi konumunu değiştirmez")


func test_remote_puppet_reads_interpolated_state() -> void:
	var player: Player = _spawn(2, Vector2(5, 5))
	await _frames(2)
	var sync: MultiplayerSynchronizer = player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer
	var start: float = Time.get_ticks_usec() / 1_000_000.0 - 1.0
	player.net_position = Vector2(40, 0)
	player.net_facing = Vector2.RIGHT
	player.net_mode = PlayerMotion.Mode.SPRINT
	player.net_time = start
	sync.synchronized.emit()
	player.net_position = Vector2(40.0 + 220.0 * 0.4, 0.0)
	player.net_time = start + 0.4
	sync.synchronized.emit()
	await tree().create_timer(0.3).timeout
	await _frames(2)
	var rig: PuppetRig = _puppet(player).rig()
	near(player.velocity, Vector2(220, 0), 0.01, "ön koşul: ara değerlenmiş hız")
	eq(rig.gait, PuppetRig.Gait.SPRINT, "uzak kopyada kip tampondan")
	near(rig.target_velocity, player.velocity, 0.001, "hız tampondan (girdiden değil)")
	is_true(rig.speed() > 100.0, "kukla koşar: %.1f" % rig.speed())
	is_true(rig.lean.x > 0.05, "gidilen yöne eğilir")
	eq((player.get_node("PlayerInput") as PlayerInput).source(), PlayerInput.Source.NONE, "uzakta girdi yok")


## A remote copy whose position is written from outside while the buffer is empty (Game catch-up) or whose buffer is reset: when the
## position jumps the puppet is silently rebuilt; the scarf is not flung, the scale does not jump.
func test_remote_teleport_has_no_pop() -> void:
	var player: Player = _spawn(4, Vector2(100, 100))
	await _frames(5)
	var rig: PuppetRig = _puppet(player).rig()
	var rebuilds: int = rig.rebuilds
	player.position = Vector2(600, 400)
	await _frames(1)
	eq(rig.rebuilds, rebuilds + 1, "ışınlanma yeniden kurar")
	var t: PuppetTuning = _puppet(player).tuning
	var chain: float = t.scarf_segment_length * t.puppet_scale * (t.scarf_segments - 1) * 1.3
	var sq: float = rig.squash_y()
	for i: int in 6:
		await _frames(1)
		var pts: PackedVector2Array = rig.scarf_points()
		is_true(pts[pts.size() - 1].distance_to(pts[0]) <= chain, "atkı bağlantıda")
		is_true(pts[0].distance_to(player.global_position) < 40.0, "atkı yeni konumda")
		near(rig.squash_y(), sq, 0.05, "ölçek sıçramaz")


# --- markers (rule 2) ---

func test_markers_fixed_anchor_and_size() -> void:
	var player: Player = _spawn(1, Vector2.ZERO)
	await _frames(2)
	var visual: PlayerVisual = player.get_node("Visual") as PlayerVisual
	var puppet: Puppet = _puppet(player)
	var markers: PuppetMarkers = puppet.get_node("Markers") as PuppetMarkers
	var label: Label = visual.get_node("NameLabel") as Label
	var label_pos: Vector2 = label.position
	var bubble: Vector2 = markers.bubble_center()
	var badge: Vector2 = markers.badge_center()
	is_true(label_pos.y + label.size.y < puppet.rig().head_top().y, "ad etiketi başın üstünde")
	visual.react(PuppetRig.Reaction.ALERT)
	eq(puppet.reaction(), PuppetRig.Reaction.ALERT, "tepki API'si oyuncu görselinden")
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sprint"}]))
	var hopped: bool = false
	for i: int in 30:
		await tree().physics_frame
		await tree().process_frame
		hopped = hopped or puppet.rig().hop > 1.0
		eq(label.position, label_pos, "ad etiketi animasyondan bağımsız")
		eq(markers.bubble_center(), bubble, "balon sabit bağlantıda")
		eq(markers.badge_center(), badge)
		eq(markers.position, Vector2.ZERO)
	is_true(hopped, "sıçrama oldu ama işaretler oynamadı")
	# >= 22 px at 1280x720 (camera zoom >= 1; canvas_items scale is 1 at the 1280x720 base).
	var zoom: float = player.tuning.camera_zoom
	is_true(PuppetMarkers.BUBBLE_SIZE * zoom >= 22.0, "balon ≥ 22 px")
	is_true(PuppetMarkers.BADGE_RADIUS * 2.0 * zoom >= 22.0, "rozet ≥ 22 px")
	eq(markers.interaction_marker_color(), ThemeTokens.tone().bg_color, "rozet dolgusu tondan (S9)")


# --- AC4: reduced motion ---

func test_reduced_motion_setting_api() -> void:
	is_false(Puppet.is_reduced_motion(), "varsayılan kapalı")
	Puppet.set_reduced_motion(true)
	var player: Player = _spawn(1, Vector2.ZERO)
	var input: PlayerInput = player.get_node("PlayerInput") as PlayerInput
	input.use_bot(BotTimeline.from_raw([{"t": 0.0, "move": [1, 0]}, {"t": 0.0, "hold": "sprint"}]))
	await _physics(40)
	var rig: PuppetRig = _puppet(player).rig()
	is_true(rig.reduced_motion, "ayar kuklaya geçer")
	eq(rig.bob(), 0.0)
	near(rig.lean.x, 0.0, 1e-6)
	is_true(rig.dust_particles().is_empty())
	Puppet.set_reduced_motion(false)
	await _frames(2)  # the process_frame signal comes before the nodes' _process
	is_false(rig.reduced_motion, "kapatma da geçer")


# --- dependency direction ---

func test_puppet_dependency_direction() -> void:
	var files: PackedStringArray = Rules.scripts_under(PUPPET_DIR)
	files.append(TUNING_SCRIPT)
	is_true(files.size() >= 9, "kukla betikleri: %s" % files)
	for path: String in files:
		var problems: PackedStringArray = violations(path, FileAccess.get_file_as_string(path))
		is_true(problems.is_empty(), "%s yasak başvuru:\n  %s" % [path, "\n  ".join(problems)])


func test_dependency_scanner_detects_mutations() -> void:
	var node_script := PUPPET_DIR.path_join("puppet.gd")
	var rig_script := PUPPET_DIR.path_join("puppet_rig.gd")
	var caught: Array[String] = [
		"var p: Player = get_parent()",
		"\tif Input.is_action_pressed(&\"sprint\"): pass",
		"var m := PlayerMotion.Mode.SNEAK",
		"\tglobal_position = Vector2.ZERO",
		"\tposition += Vector2.ONE",
		"\tself.scale = Vector2.ONE",
		"var g := Game.players()",
		"const X := preload(\"res://autoload/net.gd\")",
	]
	for line: String in caught:
		eq(violations(node_script, line).size(), 1, "yakalanmalı: " + line)
	eq(violations(rig_script, "var n: Node2D = null").size(), 1, "rig düğüm bilmez")
	eq(violations(rig_script, "var c := ThemeTokens.BG").size(), 1, "rig tema bilmez")
	var clean: Array[String] = [
		"var pos: Vector2 = global_position",
		"## Player bunu okur (yorum)",
		"var player_looks: Array = []",
		"if a.position == b: pass",
		"\t_mesh.transform = _rig.body_transform()",
	]
	for line: String in clean:
		eq(violations(node_script, line).size(), 0, "temiz sayılmalı: " + line)
	eq(violations(rig_script, "\tposition = pos").size(), 0, "rig kendi alanını yazar (düğüm değil)")


## Forbidden references in `source` (comments excluded).
static func violations(path: String, source: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var patterns: Array[String] = FORBIDDEN.duplicate()
	if path.begins_with(PUPPET_DIR):
		if NODE_SCRIPTS.has(path.get_file()):
			patterns.append(NODE_WRITES)
		else:
			patterns.append_array(RIG_FORBIDDEN)
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		var code: String = Deps.strip_comment(lines[i])
		for pattern: String in patterns:
			if RegEx.create_from_string(pattern).search(code) != null:
				out.append("%d: %s (%s)" % [i + 1, lines[i].strip_edges(), pattern])
				break
	return out


# --- draw cost and texture slot (t2) ---

func _bare_puppet(at: Vector2) -> Puppet:
	var puppet: Puppet = (load("res://entities/player/puppet/puppet.tscn") as PackedScene).instantiate() as Puppet
	puppet.position = at
	tree().root.add_child(puppet)
	autofree(puppet)
	return puppet


## Command count per puppet (venue population: 6 NPCs + 3 players): one command when drawn in code, one more if there is run dust;
## target <= 40.
func test_draw_cost_per_puppet() -> void:
	var tuning: PuppetTuning = load("res://data/puppet_tuning.tres") as PuppetTuning
	var puppets: Array[Puppet] = []
	for i: int in 3:
		var p: Puppet = _bare_puppet(Vector2(100 + i * 100, 100))
		p.configure(tuning.player_looks[i], ThemeTokens.PLAYER_COLORS[i])
		puppets.append(p)
	for frame: int in 40:
		for p: Puppet in puppets:
			p.position.x += 220.0 / 60.0
			p.set_state(Vector2(220, 0), Vector2.RIGHT, PuppetRig.Gait.SPRINT, false)
		await tree().process_frame
	await _frames(2)
	for p: Puppet in puppets:
		var stats: Dictionary = p.draw_stats()
		eq(int(stats["textures"]), 0)
		var dusty: int = 0 if p.rig().dust_particles().is_empty() else 1
		eq(int(stats["commands"]), 1 + dusty, "kodla çizim tek komut, toz ayrı (%s)" % p.look.gear)
		is_true(int(stats["triangles"]) > 100, "üçgenler toplandı: %s" % stats)
		is_true(int(stats["commands"]) <= 40)
	is_false(puppets[0].rig().dust_particles().is_empty(), "koşuda toz var (ölçüm anlamlı)")


## Texture slots: a filled part is drawn with its texture (each texture one command), an empty part in code; order kept, no error.
func test_texture_slots_draw() -> void:
	var tuning: PuppetTuning = load("res://data/puppet_tuning.tres") as PuppetTuning
	var look: PuppetLook = tuning.player_looks[0].duplicate() as PuppetLook
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	look.head_texture = texture
	look.body_texture = texture
	look.hand_texture = texture
	look.headgear_texture = texture
	var p: Puppet = _bare_puppet(Vector2(200, 200))
	p.configure(look, ThemeTokens.PLAYER_COLORS[0])
	await _frames(3)
	var stats: Dictionary = p.draw_stats()
	eq(int(stats["textures"]), 5, "baş, başlık, gövde, iki el dokuyla: %s" % stats)
	is_true(int(stats["commands"]) > int(stats["textures"]), "kodla kalan parçalar (gölge, ayak, göz, atkı) ayrıca")
	is_true(int(stats["commands"]) <= 40, "komut sınırı: %s" % stats)
	near(Puppet.part_rect(Puppet.Part.BODY, 1.16).size.x, PuppetBody.BODY_RADIUS.x * 2.0 * 1.16, 0.001, "gövde çerçevesi genişlikle")
	# Body texture only: a single split.
	var only_body: PuppetLook = tuning.player_looks[0].duplicate() as PuppetLook
	only_body.body_texture = texture
	p.configure(only_body, ThemeTokens.PLAYER_COLORS[0])
	await _frames(2)
	eq(int(p.draw_stats()["textures"]), 1)
	eq(int(p.draw_stats()["commands"]), 3, "öncesi + doku + sonrası")
