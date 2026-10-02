extends TestCase
## Proje iskeleti duman testi (IS-003): proje ayarları, S5 girdi eylemleri, §4 fizik katmanları,
## autoload'lar ve S1/S3/S8 sözleşme imzaları, S4 Level API imzaları (IS-005), çeviri kaydı, tema token'ları, ana sahne ve
## projedeki tüm betiklerin derlenmesi (statik tipleme hataları içe aktarmada görünmediği için).

const ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"sprint", &"sneak", &"interact", &"intimidate", &"pause", &"toggle_debug",
]
const LAYERS: Array[String] = ["world", "players", "npcs", "interactables", "triggers", "vision_block"]
const PHYSICS_LAYERS_SCRIPT := "res://core/physics_layers.gd"
## Autoload adı -> betik yolu (sıra project.godot ile aynı). `NoiseBus`: `Noise` yerleşik sınıfla çakışır (S8).
const AUTOLOADS := {
	"Args": "res://autoload/args.gd",
	"Net": "res://autoload/net.gd",
	"Game": "res://autoload/game.gd",
	"NoiseBus": "res://autoload/noise.gd",
}

## Sözleşme satırları docs/notes/mimari.md S1/S3/S8'den birebir (yorumlar hariç).
## Uygulama fazlasını içerebilir; bu satırların her biri aynen bulunmalı.
const CONTRACTS := {
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
	],
	"NoiseBus": [
		"func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void",
	],
	# S4 Level API (autoload değil; betik yolu LEVEL_SCRIPT, sınıf adı ve taban ayrıca denetlenir).
	"Level": [
		"func players_root() -> Node2D",
		"func props_root() -> Node2D",
		"func npcs_root() -> Node2D",
		"func spawn_count() -> int",
		"func spawn_position(index: int) -> Vector2",
		"func marker(marker_name: StringName) -> Node2D",
	],
}
const LEVEL_SCRIPT := "res://levels/level.gd"


func test_project_settings() -> void:
	eq(ProjectSettings.get_setting("application/config/name"), "Insiders")
	eq(_res_path(ProjectSettings.get_setting("application/run/main_scene")), "res://main.tscn")
	eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)
	eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")
	eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60)
	eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2, "tipsiz bildirim hata olmalı")


## IS-019: renderer Compatibility (GL 3.3) — masaüstü ve mobil karşılığı; Forward+ özellik etiketi kalmaz.
func test_renderer_is_compatibility() -> void:
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
	eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	has(features, "GL Compatibility")
	is_false(features.has("Forward Plus"), "Forward+ etiketi kalmamalı")
	is_false(features.has("Mobile"), "Mobile etiketi olmamalı")


func test_physics_layer_names() -> void:
	for i: int in LAYERS.size():
		eq(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % (i + 1)), LAYERS[i])


## IS-037: core/physics_layers.gd katman sabitleri project.godot katman adlarıyla bit bit eşleşir: adlı her
## katman N için `PhysicsLayers.<AD>` = 1 << (N - 1); `_MASK` dışındaki her tamsayı sabiti adlı bir katmandır.
func test_physics_layer_constants_match_project() -> void:
	var consts: Dictionary = (load(PHYSICS_LAYERS_SCRIPT) as Script).get_script_constant_map()
	var named: Dictionary = {}
	for n: int in range(1, 33):
		var layer_name: String = str(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % n, ""))
		if layer_name.is_empty():
			continue
		var key: String = layer_name.to_upper()
		named[key] = n
		if is_true(consts.has(key), "PhysicsLayers.%s yok (katman %d `%s`)" % [key, n, layer_name]):
			eq(consts[key], 1 << (n - 1), "PhysicsLayers.%s = katman %d biti" % [key, n])
	eq(named.size(), LAYERS.size(), "adlı katman sayısı (§4)")
	for key: String in consts:
		if typeof(consts[key]) == TYPE_INT and not key.ends_with("_MASK"):
			is_true(named.has(key), "PhysicsLayers.%s adlı bir katmana karşılık gelmiyor" % key)
	eq(PhysicsLayers.SIGHT_MASK, PhysicsLayers.WORLD | PhysicsLayers.VISION_BLOCK, "görüş maskesi world + vision_block")


func test_input_actions_have_keyboard_and_gamepad() -> void:
	for action: StringName in ACTIONS:
		if not is_true(InputMap.has_action(action), "eylem yok: %s" % action):
			continue
		var keys: int = 0
		var pads: int = 0
		for e: InputEvent in InputMap.action_get_events(action):
			if e is InputEventKey:
				keys += 1
				ne((e as InputEventKey).physical_keycode, KEY_NONE, "%s: tuş fiziksel kodla tanımlı olmalı" % action)
			elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
				pads += 1
		is_true(keys >= 1, "%s: klavye olayı yok" % action)
		is_true(pads >= 1, "%s: gamepad olayı yok" % action)


func test_pause_and_ui_gamepad_events() -> void:
	# S5 (IS-009): pause = Esc + Start; ui_accept/ui_cancel Godot varsayılan tuşlarını korur, A/B eklenir.
	# InputMap çalışma anında değiştirilebildiğinden project.godot'taki kayıt okunur.
	var expected := {
		&"pause": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		&"ui_accept": [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		&"ui_cancel": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_B)],
	}
	for action: StringName in expected:
		var entry: Variant = ProjectSettings.get_setting("input/" + action)
		if not is_true(entry is Dictionary, "project.godot'ta eylem yok: %s" % action):
			continue
		var events: Array = (entry as Dictionary).get("events", [])
		for probe: InputEvent in expected[action]:
			var found: bool = false
			for e: InputEvent in events:
				found = found or e.is_match(probe)
			is_true(found, "%s: %s eşlemesi yok" % [action, probe.as_text()])
	var b := _joy(JOY_BUTTON_B)
	is_false(InputMap.event_is_action(b, &"pause"), "gamepad B oyunda duraklatma açmaz")
	is_false(InputMap.event_is_action(_joy(JOY_BUTTON_A), &"ui_cancel"), "A geri değil")


func test_modifiers_do_not_block_movement() -> void:
	# Sızarken (Ctrl) ve koşarken (Shift) yön tuşları eylemlerini korumalı.
	var e := InputEventKey.new()
	e.physical_keycode = KEY_W
	e.ctrl_pressed = true
	e.shift_pressed = true
	e.pressed = true
	is_true(InputMap.event_is_action(e, &"move_up"), "Ctrl+Shift+W move_up olmalı")


func test_autoloads_and_contracts() -> void:
	var root: Window = tree().root
	eq(_autoload_order(), AUTOLOADS.keys(), "autoload sırası")
	for autoload_name: String in AUTOLOADS:
		# Yerleşik sınıf adıyla çakışan autoload'a adıyla erişilemez (bkz. S8).
		is_false(ClassDB.class_exists(autoload_name), "autoload adı motor sınıfıyla çakışıyor: " + autoload_name)
		var node: Node = root.get_node_or_null(NodePath(autoload_name))
		if not is_true(node != null, "autoload yok: " + autoload_name):
			continue
		var script: Script = node.get_script() as Script
		eq(script.resource_path if script else "", AUTOLOADS[autoload_name])
		if not CONTRACTS.has(autoload_name) or script == null:
			continue
		var surface: PackedStringArray = _surface(script)
		for line: String in CONTRACTS[autoload_name]:
			is_true(surface.has(line), "%s sözleşmesinde eksik ya da farklı: %s" % [autoload_name, line])


func test_level_contract() -> void:
	# S4: kök `class_name Level extends Node2D`; çekirdek seviyeye yalnız bu API ile erişir.
	var script: Script = load(LEVEL_SCRIPT) as Script
	if not is_true(script != null, "yüklenemedi: " + LEVEL_SCRIPT):
		return
	eq(script.get_global_name(), &"Level", "S4 sınıf adı")
	eq(script.get_instance_base_type(), &"Node2D", "S4 taban sınıfı")
	var surface: PackedStringArray = _surface(script)
	for line: String in CONTRACTS["Level"]:
		is_true(surface.has(line), "Level sözleşmesinde eksik ya da farklı: " + line)
	# Denetimin kendisi: imza tipi değişirse yakalanır.
	var mutant := GDScript.new()
	mutant.source_code = "extends Node2D\nfunc spawn_position(index: float) -> Vector2:\n\treturn Vector2.ZERO\n"
	eq(mutant.reload(), OK)
	is_false(_surface(mutant).has("func spawn_position(index: int) -> Vector2"), "tip farkı yakalanmalı")


func test_autoloads_callable_by_name() -> void:
	# Autoload'lar başka betiklerden adıyla çağrılabilmeli; çağrılar yalnız derlenir, koşulmaz.
	var script := GDScript.new()
	script.source_code = "\n".join([
		"extends RefCounted",
		"func _calls() -> void:",
		"\tNoiseBus.emit_noise(Vector2.ZERO, 1.0, &\"run\")",
		"\tNet.is_host()",
		"\tGame.team_cash()",
		"\tArgs.get_name()",
	])
	eq(script.reload(), OK, "autoload çağrıları derlenmeli")


func test_translations_registered() -> void:
	var files: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations")
	has(files, "res://i18n/texts.tr.translation")
	has(files, "res://i18n/texts.en.translation")
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	eq(TranslationServer.translate(&"COMMON_LOADING"), "Yükleniyor…")
	TranslationServer.set_locale("en")
	eq(TranslationServer.translate(&"COMMON_LOADING"), "Loading…")
	eq(TranslationServer.translate(&"GAME_TITLE"), "Insiders")
	TranslationServer.set_locale(previous)


func test_theme_tokens() -> void:
	var consts: Dictionary = (load("res://ui/theme/tokens.gd") as Script).get_script_constant_map()
	for key: String in ["BG", "FG", "MUTED", "ACCENT", "WALL", "FLOOR", "GAMEPLAY_ALERT", "GAMEPLAY_CASH"]:
		eq(type_string(typeof(consts.get(key))), "Color", "ThemeTokens.%s" % key)
	is_true(ThemeTokens.PLAYER_COLORS.size() >= 4, "oyuncu başına bir renk (en fazla 4 oyuncu)")


func test_main_scene_instantiates() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	if not is_true(scene != null, "res://main.tscn yüklenemedi"):
		return
	var main: Node = autofree(scene.instantiate()) as Node
	var script: Script = main.get_script() as Script
	eq(script.resource_path if script else "", "res://main.gd")


func test_all_scripts_compile() -> void:
	var paths: PackedStringArray = _scripts_under("res://")
	is_true(paths.size() > 0, "betik bulunamadı")
	for path: String in paths:
		# Ayrıştırılamayan betik (tipsiz bildirim dahil) geçersiz kalır; ilk yüklemede koşucu hatayı da yakalar.
		var script: Script = load(path) as Script
		is_true(script != null and (script.can_instantiate() or script.is_abstract()), "derlenemedi: " + path)


# --- yardımcılar ---

static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


static func _autoload_order() -> Array:
	var names: Array = []
	for p: Dictionary in ProjectSettings.get_property_list():
		var key: String = p["name"]
		if key.begins_with("autoload/"):
			names.append(key.trim_prefix("autoload/"))
	return names


static func _res_path(path: String) -> String:
	return ResourceUID.uid_to_path(path) if path.begins_with("uid://") else path


static func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if FileAccess.file_exists(dir.path_join(".gdignore")):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts_under(dir.path_join(d)))
	return out


## Betiğin genel yüzeyini sözleşme satırı biçiminde çıkarır.
static func _surface(script: Script) -> PackedStringArray:
	var out: PackedStringArray = []
	for s: Dictionary in script.get_script_signal_list():
		out.append("signal %s(%s)" % [s["name"], _render_args(s)])
	for m: Dictionary in script.get_script_method_list():
		out.append("func %s(%s) -> %s" % [m["name"], _render_args(m), _type_name(m["return"], true)])
	var consts: Dictionary = script.get_script_constant_map()
	for key: Variant in consts:
		out.append("const %s := %s" % [key, var_to_str(consts[key])])
	for p: Dictionary in script.get_script_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append("var %s: %s" % [p["name"], _type_name(p, false)])
	return out


static func _render_args(info: Dictionary) -> String:
	var args: Array = info["args"]
	var defaults: Array = info["default_args"]
	var first_default: int = args.size() - defaults.size()
	var parts: PackedStringArray = []
	for i: int in args.size():
		var arg: Dictionary = args[i]
		var part: String = "%s: %s" % [arg["name"], _type_name(arg, false)]
		if i >= first_default:
			part += " = " + _render_default(defaults[i - first_default], arg)
		parts.append(part)
	return ", ".join(parts)


static func _render_default(value: Variant, arg: Dictionary) -> String:
	# Kap literalleri ({} ve []) yansımada null görünür.
	if value == null and int(arg["type"]) == TYPE_DICTIONARY:
		return "{}"
	if value == null and int(arg["type"]) == TYPE_ARRAY:
		return "[]"
	return var_to_str(value)


static func _type_name(info: Dictionary, is_return: bool) -> String:
	var type: int = info["type"]
	var cls: String = str(info["class_name"])
	if type == TYPE_NIL:
		return "void" if is_return and not (int(info["usage"]) & PROPERTY_USAGE_NIL_IS_VARIANT) else "Variant"
	if not cls.is_empty():
		return cls  # nesne sınıfı ya da enum (ör. Error)
	return type_string(type)
