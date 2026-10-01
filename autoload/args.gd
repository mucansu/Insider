extends Node
## Komut satırı argümanları (autoload `Args`, S6 — docs/notes/mimari.md).
## Kullanıcı argümanları `--` sonrasında: --host · --join=ADDR · --port=N · --name=AD · --level=res://...
## · --bot=PATH.json · --dump=PATH.json · --quit-after=SN · --player-scene=res://... (yalnız test)
## Açılışta `OS.get_cmdline_user_args()` ayrıştırılır; testler `parse()` ile kendi listesini verebilir.
## Tanınmayan argümanlar `unknown` listesine girer (test koşucusunun --filter gibi argümanları için uyarı
## basılmaz); tanınan anahtarın değeri bozuksa uyarı basılır ve varsayılan korunur.

const DEFAULT_PORT := 7777

var want_host: bool = false
var join_address: String = ""
var port: int = DEFAULT_PORT
var player_name: String = ""
var level: String = ""
var bot_path: String = ""
var dump_path: String = ""
## Saniye; 0 = kapalı.
var quit_after: float = 0.0
var player_scene: String = ""
var unknown: PackedStringArray = []


func _init() -> void:
	parse(OS.get_cmdline_user_args())


## Önceki değerleri sıfırlar ve verilen argüman listesini ayrıştırır.
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
			_:
				unknown.append(raw)
	if want_host and not join_address.is_empty():
		push_warning("Args: --host ve --join birlikte verildi; --host kullanılıyor")
		join_address = ""


## Argümanlar doğrudan bir oturum başlatıyor mu (host ya da katıl).
func wants_session() -> bool:
	return want_host or not join_address.is_empty()


## Otomasyon/test koşusu mu (döküm ya da süreli çıkış istendi).
func is_automated() -> bool:
	return not dump_path.is_empty() or quit_after > 0.0


## `--bot` dosyasının adımları (bkz. `load_bot`); dosya verilmediyse boş.
func bot_steps() -> Array[Dictionary]:
	if bot_path.is_empty():
		return []
	return load_bot(bot_path)


## Bot dosyasını (S6) okur: {"steps":[{"t":0.0,"move":[1,0]}, {"t":2.0,"hold":"interact","dur":4.5}, ...]}.
## Dönen adımlar `t`'ye göre sıralıdır; `t` ve `dur` float'a, `move` Vector2'ye çevrilir; diğer alanlar
## olduğu gibi kalır. Bozuk adım uyarıyla atlanır; dosya okunamazsa boş liste.
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


## Tek bot adımını doğrular ve tiplerini düzeltir; geçersizse boş sözlük döner.
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
