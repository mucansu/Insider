extends Node
## Command-line arguments (autoload `Args`, S6 — docs/notes/mimari.md).
## User args follow `--`: --host · --join=ADDR · --port=N · --name=NAME · --level=res://... · --bot=PATH.json · --dump=PATH.json
## · --quit-after=SEC · --player-scene=res://... (test only) · --screenshot-at=SEC[,SEC…] · --screenshot-dir=PATH · --window-size=WxH (IS-022)
## · --camera-zoom=X (dev; IS-027) · --perf · --perf-seconds=N (dev; IS-067: "render" section in the dump)
## · --brain=STRATEGY · --seed=N · --quit-on-heist-end=SEC (test/statistics; IS-015a, block at the end of the file) · --brain-loop=SEC (IS-058b).
## Parsed from `OS.get_cmdline_user_args()` at startup (tests may call `parse()` with their own list). Unknown args go to `unknown`
## without a warning (e.g. the test runner's --filter); a recognised key with a bad value warns and keeps the default.

const DEFAULT_PORT := 7777
## `--camera-zoom` accepted range (same as PlayerTuning.camera_zoom).
const CAMERA_ZOOM_MIN := 0.25
const CAMERA_ZOOM_MAX := 4.0

var want_host: bool = false
var join_address: String = ""
var port: int = DEFAULT_PORT
var player_name: String = ""
var level: String = ""
var bot_path: String = ""
var dump_path: String = ""
## Seconds; 0 = off.
var quit_after: float = 0.0
var player_scene: String = ""
## Screenshot times (seconds since start, same clock as --quit-after); ascending, unique. Empty = off.
var screenshot_at: PackedFloat64Array = []
## Directory the PNGs are written to (absolute, res:// or user://).
var screenshot_dir: String = ""
## Window size in pixels; (0, 0) = project setting.
var window_size: Vector2i = Vector2i.ZERO
## `--camera-zoom` override; 0 = not given, the tuning value is used.
var camera_zoom: float = 0.0
var unknown: PackedStringArray = []

const WINDOW_SIZE_MIN := 64
const WINDOW_SIZE_MAX := 16384


func _init() -> void:
	parse(OS.get_cmdline_user_args())


## Resets previous values and parses the given argument list.
func parse(args: PackedStringArray) -> void:
	want_host = false
	join_address = ""
	port = DEFAULT_PORT
	player_name = ""
	level = ""
	bot_path = ""
	dump_path = ""
	quit_after = 0.0
	player_scene = ""
	screenshot_at = []
	screenshot_dir = ""
	window_size = Vector2i.ZERO
	camera_zoom = 0.0
	unknown = []
	for raw: String in args:
		var arg: String = raw.strip_edges()
		var key: String = arg
		var value: String = ""
		var has_value: bool = false
		var eq: int = arg.find("=")
		if eq >= 0:
			key = arg.substr(0, eq)
			value = arg.substr(eq + 1).strip_edges()
			has_value = true
		match key:
			"--host":
				want_host = true
			"--join":
				if _need_value(key, value, has_value):
					join_address = value
			"--port":
				if _need_value(key, value, has_value):
					if value.is_valid_int() and value.to_int() >= 1 and value.to_int() <= 65535:
						port = value.to_int()
					else:
						push_warning("Args: geçersiz port '%s'; %d kullanılıyor" % [value, port])
			"--name":
				if _need_value(key, value, has_value):
					player_name = value
			"--level":
				if _need_value(key, value, has_value):
					level = value
			"--bot":
				if _need_value(key, value, has_value):
					bot_path = value
			"--dump":
				if _need_value(key, value, has_value):
					dump_path = value
			"--quit-after":
				if _need_value(key, value, has_value):
					if value.is_valid_float() and value.to_float() >= 0.0:
						quit_after = value.to_float()
					else:
						push_warning("Args: geçersiz --quit-after '%s'" % value)
			"--player-scene":
				if _need_value(key, value, has_value):
					player_scene = value
			"--screenshot-at":
				if _need_value(key, value, has_value):
					screenshot_at = parse_moments(value)
					if screenshot_at.is_empty():
						push_warning("Args: geçersiz --screenshot-at '%s' (SN[,SN…], SN >= 0)" % value)
			"--screenshot-dir":
				if _need_value(key, value, has_value):
					screenshot_dir = value
			"--window-size":
				if _need_value(key, value, has_value):
					window_size = parse_window_size(value)
					if window_size == Vector2i.ZERO:
						push_warning("Args: geçersiz --window-size '%s' (GxY, ör. 1280x720)" % value)
			"--camera-zoom":
				if _need_value(key, value, has_value):
					if value.is_valid_float() and value.to_float() >= CAMERA_ZOOM_MIN and value.to_float() <= CAMERA_ZOOM_MAX:
						camera_zoom = value.to_float()
					else:
						push_warning("Args: geçersiz --camera-zoom '%s' (%.2f..%.2f)" % [value, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX])
			_:
				unknown.append(raw)
	if want_host and not join_address.is_empty():
		push_warning("Args: --host ve --join birlikte verildi; --host kullanılıyor")
		join_address = ""
	if not screenshot_at.is_empty() and screenshot_dir.is_empty():
		push_warning("Args: --screenshot-at için --screenshot-dir gerekir; görüntü alınmayacak")
	_parse_vision_args()  # US-011d
	_parse_perf_args()  # IS-067
	_parse_brain_args()  # IS-015a


## Whether the args start a session directly (host or join).
func wants_session() -> bool:
	return want_host or not join_address.is_empty()


## Whether this is an automation/test run (dump or timed quit requested).
func is_automated() -> bool:
	return not dump_path.is_empty() or quit_after > 0.0


## Whether screenshots were requested (times and directory both given).
func wants_screenshots() -> bool:
	return not screenshot_at.is_empty() and not screenshot_dir.is_empty()


## "3,1.5,3" → [1.5, 3.0] (ascending, unique). Empty list on an empty item (incl. trailing comma), a non-number,
## a non-finite value ("1e400", "inf") or a negative value.
static func parse_moments(value: String) -> PackedFloat64Array:
	var out: PackedFloat64Array = []
	for part: String in value.split(","):
		var s: String = part.strip_edges()
		if not s.is_valid_float():
			return PackedFloat64Array()
		var t: float = s.to_float()
		if not is_finite(t) or t < 0.0:
			return PackedFloat64Array()
		if not out.has(t):
			out.append(t)
	out.sort()
	return out


## "1280x720" (x or X) → Vector2i(1280, 720); (0, 0) if malformed or outside [WINDOW_SIZE_MIN, WINDOW_SIZE_MAX].
static func parse_window_size(value: String) -> Vector2i:
	var parts: PackedStringArray = value.strip_edges().to_lower().split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO
	var w: int = parts[0].to_int()
	var h: int = parts[1].to_int()
	if w < WINDOW_SIZE_MIN or h < WINDOW_SIZE_MIN or w > WINDOW_SIZE_MAX or h > WINDOW_SIZE_MAX:
		return Vector2i.ZERO
	return Vector2i(w, h)


## Steps of the `--bot` file (see `load_bot`); empty if no file was given.
func bot_steps() -> Array[Dictionary]:
	if bot_path.is_empty():
		return []
	return load_bot(bot_path)


## Reads the bot file (S6): {"steps":[{"t":0.0,"move":[1,0]}, {"t":2.0,"hold":"interact","dur":4.5}, ...]}.
## Steps are sorted by `t`; `t`/`dur` become float, `move` a Vector2, other fields are kept as is.
## Bad steps are skipped with a warning; an unreadable file yields an empty list.
static func load_bot(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_warning("Args: bot dosyası yok: " + path)
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or typeof((parsed as Dictionary).get("steps")) != TYPE_ARRAY:
		push_warning("Args: bot dosyası {\"steps\": [...]} biçiminde değil: " + path)
		return out
	for item: Variant in (parsed as Dictionary)["steps"]:
		var step: Dictionary = parse_bot_step(item)
		if step.is_empty():
			push_warning("Args: bozuk bot adımı atlandı: %s" % str(item))
			continue
		out.append(step)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


## Validates one bot step and fixes its types; returns an empty dictionary if invalid.
static func parse_bot_step(item: Variant) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY:
		return {}
	var step: Dictionary = (item as Dictionary).duplicate(true)
	if not _is_number(step.get("t")) or float(step["t"]) < 0.0:
		return {}
	step["t"] = float(step["t"])
	if step.has("move"):
		var m: Variant = step["move"]
		if typeof(m) != TYPE_ARRAY or (m as Array).size() != 2:
			return {}
		var arr: Array = m
		if not (_is_number(arr[0]) and _is_number(arr[1])):
			return {}
		step["move"] = Vector2(float(arr[0]), float(arr[1]))
	if step.has("dur"):
		if not _is_number(step["dur"]) or float(step["dur"]) < 0.0:
			return {}
		step["dur"] = float(step["dur"])
	return step


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _need_value(key: String, value: String, has_value: bool) -> bool:
	if has_value and not value.is_empty():
		return true
	push_warning("Args: %s bir değer ister (%s=...)" % [key, key])
	return false


# --- US-011d: vision mode (--vision-mode=peripheral|directional; GDD §6.5, KR-023) -------------------
# Separate block: the main loop leaves unrecognised args in `unknown`; this block pulls `--vision-mode` out of it at the end of `parse()`.
# The mode is a host game rule; Game/lobby read it on the host only.

const VISION_MODES: Array[String] = ["peripheral", "directional"]
const DEFAULT_VISION_MODE := "peripheral"

## One of `VISION_MODES`; `DEFAULT_VISION_MODE` if the arg is missing or invalid.
var vision_mode: String = DEFAULT_VISION_MODE
## Whether `--vision-mode` was given with a valid value (otherwise data/lobby defaults decide the mode).
var vision_mode_given: bool = false


func _parse_vision_args() -> void:
	vision_mode = DEFAULT_VISION_MODE
	vision_mode_given = false
	var rest: PackedStringArray = []
	for raw: String in unknown:
		var arg: String = raw.strip_edges()
		var eq: int = arg.find("=")
		var key: String = arg.substr(0, eq) if eq >= 0 else arg
		if key != "--vision-mode":
			rest.append(raw)
			continue
		var value: String = arg.substr(eq + 1).strip_edges().to_lower() if eq >= 0 else ""
		if not _need_value(key, value, eq >= 0):
			continue
		if VISION_MODES.has(value):
			vision_mode = value
			vision_mode_given = true
		else:
			push_warning("Args: geçersiz --vision-mode '%s' (%s); %s kullanılıyor"
				% [value, "|".join(PackedStringArray(VISION_MODES)), vision_mode])
	unknown = rest


# --- IS-067: render/perf measurement (--perf, --perf-seconds=N; S6 dev arg) ----------------
# Separate block (US-011d pattern), pulled from `unknown` at the end of `parse()`. With `--perf` main.gd samples frame time and
# Performance/RenderingServer monitors and adds a "render" section to the dump; when off nothing is hooked (zero cost).

const DEFAULT_PERF_SECONDS := 10.0
const PERF_SECONDS_MIN := 1.0
const PERF_SECONDS_MAX := 600.0

## Whether `--perf` was given.
var perf: bool = false
## Measurement window (seconds); the dump summarises the last N seconds.
var perf_seconds: float = DEFAULT_PERF_SECONDS


func _parse_perf_args() -> void:
	perf = false
	perf_seconds = DEFAULT_PERF_SECONDS
	var rest: PackedStringArray = []
	for raw: String in unknown:
		var arg: String = raw.strip_edges()
		var eq: int = arg.find("=")
		var key: String = arg.substr(0, eq) if eq >= 0 else arg
		var value: String = arg.substr(eq + 1).strip_edges() if eq >= 0 else ""
		match key:
			"--perf":
				if eq >= 0:
					push_warning("Args: --perf değer almaz (bayrak); '%s' yok sayıldı" % arg)
				perf = true
			"--perf-seconds":
				if not _need_value(key, value, eq >= 0):
					continue
				var secs: float = parse_perf_seconds(value)
				if secs > 0.0:
					perf_seconds = secs
				else:
					push_warning("Args: geçersiz --perf-seconds '%s' (%.0f..%.0f); %.0f kullanılıyor"
						% [value, PERF_SECONDS_MIN, PERF_SECONDS_MAX, perf_seconds])
			_:
				rest.append(raw)
	unknown = rest


## "15" / "2.5" → seconds; 0 if not a number, not finite or outside [PERF_SECONDS_MIN, PERF_SECONDS_MAX].
static func parse_perf_seconds(value: String) -> float:
	var s: String = value.strip_edges()
	if not s.is_valid_float():
		return 0.0
	var t: float = s.to_float()
	if not is_finite(t) or t < PERF_SECONDS_MIN or t > PERF_SECONDS_MAX:
		return 0.0
	return t


# --- IS-015a: closed-loop bot brain (--brain=STRATEGY, --seed=N, --quit-on-heist-end=SEC; S6 test args) -------------------------
# Separate block (US-011d pattern), pulled from `unknown` at the end of `parse()`.
# `--brain`: strategy of the local player's brain (BotRules.STRATEGIES, optional "+bag" suffix; entities/player/bot_brain.gd). Given
# together with `--bot` it is an error: the brain replaces the timeline (`--bot` is dropped). A bot file may select a brain too
# ({"brain": ..., "seed": ...}; BotBrain.spec_from_file).
# `--seed`: run seed. Today only the brain's randomness uses it (reaction delay, wait times, path jitter); the game's NPC randomness has
# no session seed yet (IS-058) and may bind to the same argument later.
# `--quit-on-heist-end`: SEC seconds after the job ends (Game.heist_finished) the process writes the dump (exit_reason "heist_end") and
# exits 0 (statistics runner); independent of `--quit-after`, whichever comes first.
# `--seed` also fixes the NPC session seed (IS-058b, Game.session_seed()).
# `--brain-loop` (IS-058b): SEC seconds after the job ends the host's brain asks "Again" (Game.request_restart) and every brain starts
# a new run (dump brain.runs[]); endurance runs. Do not combine with `--quit-on-heist-end` (that quits on the first job end).

## Brain strategy (lower case); empty = no brain.
var brain: String = ""
## Run seed (`--seed`); 0 if not given.
var run_seed: int = 0
## Whether `--seed` was given with a valid value.
var run_seed_given: bool = false
## Seconds after the job ends to dump and quit; < 0 = off.
var quit_on_heist_end: float = -1.0
## Seconds after the job ends until the host's brain restarts the job; < 0 = off (IS-058b).
var brain_loop: float = -1.0


func _parse_brain_args() -> void:
	brain = ""
	run_seed = 0
	run_seed_given = false
	quit_on_heist_end = -1.0
	brain_loop = -1.0
	var rest: PackedStringArray = []
	for raw: String in unknown:
		var arg: String = raw.strip_edges()
		var eq: int = arg.find("=")
		var key: String = arg.substr(0, eq) if eq >= 0 else arg
		var value: String = arg.substr(eq + 1).strip_edges() if eq >= 0 else ""
		match key:
			"--brain":
				if not _need_value(key, value, eq >= 0):
					continue
				if BotRules.is_valid_strategy(value):
					brain = value.to_lower()
				else:
					push_warning("Args: geçersiz --brain '%s' (%s, isteğe bağlı %s / %s / %s ekleri)"
						% [value, "|".join(PackedStringArray(BotRules.STRATEGIES)), BotRules.BAG_SUFFIX, BotRules.OMNI_SUFFIX,
						BotRules.HUMAN_SUFFIX])
			"--seed":
				if not _need_value(key, value, eq >= 0):
					continue
				if value.is_valid_int():
					run_seed = value.to_int()
					run_seed_given = true
				else:
					push_warning("Args: geçersiz --seed '%s' (tam sayı)" % value)
			"--quit-on-heist-end":
				if not _need_value(key, value, eq >= 0):
					continue
				if value.is_valid_float() and is_finite(value.to_float()) and value.to_float() >= 0.0:
					quit_on_heist_end = value.to_float()
				else:
					push_warning("Args: geçersiz --quit-on-heist-end '%s' (SN >= 0)" % value)
			"--brain-loop":
				if not _need_value(key, value, eq >= 0):
					continue
				if value.is_valid_float() and is_finite(value.to_float()) and value.to_float() >= 0.0:
					brain_loop = value.to_float()
				else:
					push_warning("Args: geçersiz --brain-loop '%s' (SN >= 0)" % value)
			_:
				rest.append(raw)
	unknown = rest
	if not brain.is_empty() and not bot_path.is_empty():
		push_error("Args: --brain ve --bot birlikte verilemez (beyin zaman çizelgesinin yerini alır); --bot yok sayılıyor")
		bot_path = ""
