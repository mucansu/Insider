extends TestCase
## Project skeleton smoke test (IS-003): project settings, S5 input actions, §4 physics layers, autoloads and S1/S3/S8 contract
## signatures, S4 Level API signatures (IS-005; additions and the PENDING pattern IS-039), translation registry, theme tokens, main
## scene and compilation of all scripts in the project (static typing errors do not show up at import).

const ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"sprint", &"sneak", &"interact", &"intimidate", &"pause", &"toggle_debug",
]
const LAYERS: Array[String] = ["world", "players", "npcs", "interactables", "triggers", "vision_block"]
const PHYSICS_LAYERS_SCRIPT := "res://core/physics_layers.gd"
## Autoload name -> script path (order same as project.godot). `NoiseBus`: `Noise` collides with a built-in class (S8).
const AUTOLOADS := {
	"Args": "res://autoload/args.gd",
	"Net": "res://autoload/net.gd",
	"Game": "res://autoload/game.gd",
	"NoiseBus": "res://autoload/noise.gd",
}

## Contract lines and not-yet-arrived (PENDING) members in a single source: tests/contracts.gd (IS-039).
## May include the implementation phase; every non-PENDING line must be found verbatim.
const Contracts := preload("res://tests/contracts.gd")
const CONTRACTS := Contracts.LINES
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


## IS-019: renderer Compatibility (GL 3.3) - the desktop and mobile counterpart; no Forward+ feature tag remains.
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


## IS-037: core/physics_layers.gd layer constants match project.godot layer names bit by bit: for every named layer N
## `PhysicsLayers.<NAME>` = 1 << (N - 1); every integer constant other than `_MASK` is a named layer.
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
	# S5 (IS-009): pause = Esc + Start; ui_accept/ui_cancel keep Godot's default keys, A/B are added.
	# The InputMap can be changed at runtime, so the entry in project.godot is read.
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


func test_look_actions_right_stick() -> void:
	# US-011d (S5 addition, GDD §6.5): look actions only on the gamepad right stick; mouse look is read from the cursor position
	# (not an action), a keyboard-only player turns to the walking direction (no key). Dead zone same as move_*.
	var expected := {
		&"look_left": [JOY_AXIS_RIGHT_X, -1.0], &"look_right": [JOY_AXIS_RIGHT_X, 1.0],
		&"look_up": [JOY_AXIS_RIGHT_Y, -1.0], &"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	var move_deadzone: float = float((ProjectSettings.get_setting("input/move_up") as Dictionary)["deadzone"])
	for action: StringName in expected:
		var entry: Variant = ProjectSettings.get_setting("input/" + action)
		if not is_true(entry is Dictionary, "project.godot'ta eylem yok: %s" % action):
			continue
		var deadzone: float = float((entry as Dictionary).get("deadzone", -1.0))
		near(deadzone, move_deadzone, 0.0001, "%s ölü bölgesi move_* ile aynı" % action)
		var events: Array = (entry as Dictionary).get("events", [])
		eq(events.size(), 1, "%s: tek olay (sağ çubuk)" % action)
		for e: InputEvent in events:
			if not is_true(e is InputEventJoypadMotion, "%s: yalnız eksen olayı" % action):
				continue
			var m := e as InputEventJoypadMotion
			eq(m.axis, expected[action][0], "%s ekseni" % action)
			eq(m.axis_value, expected[action][1], "%s yönü" % action)
	is_false(InputMap.has_action(&"look_toggle_mode"), "kip host kuralı; oyuncu eylemi yok")
	# The right stick does not mix with movement or UI actions.
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	for other: StringName in [&"move_right", &"move_left", &"ui_right", &"ui_left"]:
		is_false(InputMap.event_is_action(stick, other), "sağ çubuk %s tetiklememeli" % other)


func test_modifiers_do_not_block_movement() -> void:
	# While sneaking (Ctrl) and running (Shift) the arrow-key actions must be preserved.
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
		# An autoload that collides with a built-in class name cannot be reached by name (see S8).
		is_false(ClassDB.class_exists(autoload_name), "autoload adı motor sınıfıyla çakışıyor: " + autoload_name)
		var node: Node = root.get_node_or_null(NodePath(autoload_name))
		if not is_true(node != null, "autoload yok: " + autoload_name):
			continue
		var script: Script = node.get_script() as Script
		eq(script.resource_path if script else "", AUTOLOADS[autoload_name])
		if not CONTRACTS.has(autoload_name) or script == null:
			continue
		var problems: PackedStringArray = contract_problems(autoload_name, script)
		is_true(problems.is_empty(), "%s sözleşmesinde eksik ya da farklı:
  %s" % [autoload_name, "
  ".join(problems)])


func test_level_contract() -> void:
	# S4: root `class_name Level extends Node2D`; the core reaches the level only through this API.
	var script: Script = load(LEVEL_SCRIPT) as Script
	if not is_true(script != null, "yüklenemedi: " + LEVEL_SCRIPT):
		return
	eq(script.get_global_name(), &"Level", "S4 sınıf adı")
	eq(script.get_instance_base_type(), &"Node2D", "S4 taban sınıfı")
	var problems: PackedStringArray = contract_problems("Level", script)
	is_true(problems.is_empty(), "Level sözleşmesinde eksik ya da farklı:
  " + "
  ".join(problems))
	# The check itself: caught if a signature type changes.
	var mutant := GDScript.new()
	mutant.source_code = "extends Node2D\nfunc spawn_position(index: float) -> Vector2:\n\treturn Vector2.ZERO\n"
	eq(mutant.reload(), OK)
	is_false(_surface(mutant).has("func spawn_position(index: int) -> Vector2"), "tip farkı yakalanmalı")


## IS-039: a PENDING member is skipped if absent from the real script; checked once it arrives. A missing non-PENDING member fails.
func test_pending_contract_members() -> void:
	for owner: String in Contracts.PENDING:
		var names: PackedStringArray = Contracts.names(owner)
		for member: String in Contracts.PENDING[owner]:
			has(names, member, "%s PENDING üyesi sözleşme satırlarında yok: %s" % [owner, member])
	# A Game without any S3 additions: only missing non-PENDING (Phase 1) members are reported.
	var bare: GDScript = _mutant("extends Node
func players() -> Dictionary:
	return {}
")
	var problems: PackedStringArray = contract_problems("Game", bare)
	# (US-008: alert members reached real code and left PENDING; the example is still a PENDING member.)
	is_false(_mentions(problems, "heist_result"), "gelmemiş PENDING üye atlanmalı: %s" % problems)
	is_true(_mentions(problems, "alert_level"), "PENDING'den çıkan (gerçek) üye eksikse düşer")
	is_true(_mentions(problems, "team_cash"), "PENDING dışı eksik üye düşmeli")
	is_false(_mentions(problems, "players()"), "doğru imzalı üye geçer")
	# When a PENDING member arrives its signature is checked: the right signature passes, a wrong one fails.
	var good: GDScript = _mutant("extends Node
signal alert_level_changed(level: int)
func alert_level() -> int:
	return 0
"
		+ "func player_world_position(peer: int) -> Vector2:
	return Vector2.INF
")
	problems = contract_problems("Game", good)
	is_false(_mentions(problems, "alert_level") or _mentions(problems, "player_world_position"), "doğru imza geçer: %s" % problems)
	var wrong: GDScript = _mutant("extends Node
signal alert_level_changed(level: float)
func alert_level() -> float:
	return 0.0
"
		+ "func set_vision_mode(mode: StringName) -> void:
	pass
")
	problems = contract_problems("Game", wrong)
	for line: String in ["signal alert_level_changed(level: int)", "func alert_level() -> int", "func set_vision_mode(mode: int) -> void"]:
		has(problems, line, "PENDING üyenin yanlış imzası düşmeli")
	# Level: typed array return (marker_sequence) and PENDING fog members with the same pattern.
	var level: GDScript = _mutant("extends Node2D
func marker_sequence(prefix: StringName) -> Array[Node2D]:
	return []
"
		+ "func tier() -> float:
	return 1.0
")
	problems = contract_problems("Level", level)
	is_false(problems.has("func marker_sequence(prefix: StringName) -> Array[Node2D]"), "tipli dizi dönüşü okunmalı")
	has(problems, "func tier() -> int", "PENDING tier yanlış tipte düşmeli")
	has(problems, "func attach_fog(observer: Node2D) -> FogLayer", "gerçek (PENDING olmayan) üye eksikse düşer")
	var untyped: GDScript = _mutant("extends Node2D
func marker_sequence(prefix: StringName) -> Array:
	return []
")
	has(contract_problems("Level", untyped), "func marker_sequence(prefix: StringName) -> Array[Node2D]", "tipsiz dizi farkı yakalanmalı")


func test_autoloads_callable_by_name() -> void:
	# Autoloads must be callable by name from other scripts; the calls are only compiled, not run.
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
		# A script that cannot be parsed (including an untyped declaration) stays invalid; on first load the runner catches the error too.
		var script: Script = load(path) as Script
		is_true(script != null and (script.can_instantiate() or script.is_abstract()), "derlenemedi: " + path)


# --- helpers ---

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


## Lines missing or different in the script from the `owner` contract. A PENDING member entirely absent from the script is skipped.
static func contract_problems(owner: String, script: Script) -> PackedStringArray:
	var surface: PackedStringArray = _surface(script)
	var present: Dictionary = {}
	for entry: String in surface:
		present[Contracts.member_name(entry)] = true
	var out: PackedStringArray = []
	for line: String in Contracts.LINES[owner]:
		var member: String = Contracts.member_name(line)
		if Contracts.is_pending(owner, member) and not present.has(member):
			continue  # in the contract but not yet in the real script
		if not surface.has(line):
			out.append(line)
	return out


static func _mutant(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script


static func _mentions(lines: PackedStringArray, text: String) -> bool:
	for line: String in lines:
		if line.contains(text):
			return true
	return false


## Extracts the script's public surface as contract-line form.
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
	# Container literals ({} and []) appear as null in reflection.
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
		return cls  # object class or enum (e.g. Error)
	if type == TYPE_ARRAY and int(info.get("hint", 0)) == PROPERTY_HINT_ARRAY_TYPE:
		return "Array[%s]" % info["hint_string"]  # typed array (e.g. Array[Node2D])
	return type_string(type)
