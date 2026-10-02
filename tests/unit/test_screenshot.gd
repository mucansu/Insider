extends TestCase
## Ekran görüntüsü argümanları (Args, S6) ve main.gd zamanlaması (IS-022). Gerçek görüntü pencereli koşuda
## tools/screenshot.py ile alınır; burada headless'ta ayrıştırma, plan, dosya adı ve headless atlaması sınanır.

const ArgsScript := preload("res://autoload/args.gd")
const MainScript := preload("res://main.gd")


func _args() -> ArgsScript:
	return autofree(ArgsScript.new()) as ArgsScript


func _main() -> MainScript:
	return autofree((load("res://main.tscn") as PackedScene).instantiate()) as MainScript


func test_parses_screenshot_arguments() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray([
		"--host", "--screenshot-at=6,2.5,4", "--screenshot-dir=C:/tmp/shots", "--window-size=1280x720",
		"--quit-after=8",
	]))
	eq(a.screenshot_at, PackedFloat64Array([2.5, 4.0, 6.0]), "anlar artan sıraya dizilir")
	eq(a.screenshot_dir, "C:/tmp/shots")
	eq(a.window_size, Vector2i(1280, 720))
	is_true(a.wants_screenshots())
	eq(a.unknown.size(), 0)
	is_true(a.is_automated(), "--quit-after ile otomasyon; görüntü argümanları bunu değiştirmez")


func test_screenshot_defaults_and_reset() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray(["--screenshot-at=1", "--screenshot-dir=x", "--window-size=800X600"]))
	eq(a.window_size, Vector2i(800, 600), "büyük X de kabul")
	a.parse(PackedStringArray([]))
	eq(a.screenshot_at.size(), 0, "yeniden ayrıştırma sıfırlar")
	eq(a.screenshot_dir, "")
	eq(a.window_size, Vector2i.ZERO)
	is_false(a.wants_screenshots())
	is_false(a.is_automated(), "görüntü argümanı tek başına otomasyon sayılmaz")


func test_screenshot_needs_dir() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray(["--screenshot-at=1,2"]))
	eq(a.screenshot_at, PackedFloat64Array([1.0, 2.0]))
	is_false(a.wants_screenshots(), "dizin yoksa görüntü alınmaz (uyarı)")


func test_parse_moments() -> void:
	eq(ArgsScript.parse_moments("3"), PackedFloat64Array([3.0]))
	eq(ArgsScript.parse_moments(" 3 , 1.5,3,0 "), PackedFloat64Array([0.0, 1.5, 3.0]), "boşluk, tekrar, sıfır")
	eq(ArgsScript.parse_moments("1,abc").size(), 0, "sayı olmayan öğe tüm listeyi geçersiz kılar")
	eq(ArgsScript.parse_moments("1,-2").size(), 0, "negatif an geçersiz")
	eq(ArgsScript.parse_moments("1,,2").size(), 0, "boş öğe geçersiz")
	eq(ArgsScript.parse_moments("1,2,").size(), 0, "sondaki virgül geçersiz")
	eq(ArgsScript.parse_moments("1e400").size(), 0, "sonsuza taşan değer geçersiz")
	eq(ArgsScript.parse_moments("2,inf").size(), 0, "sonlu olmayan değer geçersiz")
	eq(ArgsScript.parse_moments("nan").size(), 0)
	eq(ArgsScript.parse_moments("").size(), 0)


func test_parse_window_size() -> void:
	eq(ArgsScript.parse_window_size("1280x720"), Vector2i(1280, 720))
	eq(ArgsScript.parse_window_size(" 1920x1080 "), Vector2i(1920, 1080))
	eq(ArgsScript.parse_window_size("1280"), Vector2i.ZERO)
	eq(ArgsScript.parse_window_size("1280x"), Vector2i.ZERO)
	eq(ArgsScript.parse_window_size("ax720"), Vector2i.ZERO)
	eq(ArgsScript.parse_window_size("1280x720x2"), Vector2i.ZERO)
	eq(ArgsScript.parse_window_size("10x10"), Vector2i.ZERO, "alt sınır")
	eq(ArgsScript.parse_window_size("99999x720"), Vector2i.ZERO, "üst sınır")


func test_invalid_screenshot_values_keep_defaults() -> void:
	var a: ArgsScript = _args()
	a.parse(PackedStringArray(["--screenshot-at=x", "--window-size=big", "--screenshot-dir"]))
	eq(a.screenshot_at.size(), 0)
	eq(a.window_size, Vector2i.ZERO)
	eq(a.screenshot_dir, "")
	eq(a.unknown.size(), 0, "tanınan anahtarlar bilinmeyen listesine girmez")


func test_screenshot_plan_drops_moments_after_quit() -> void:
	var moments := PackedFloat64Array([1.0, 3.0, 5.0, 7.5])
	eq(MainScript.screenshot_plan(moments, 0.0), moments, "--quit-after yoksa hepsi")
	eq(MainScript.screenshot_plan(moments, 5.0), PackedFloat64Array([1.0, 3.0, 5.0]), "eşit an alınır")
	eq(MainScript.screenshot_plan(moments, 0.5).size(), 0)
	eq(MainScript.screenshot_plan(PackedFloat64Array(), 4.0).size(), 0)


func test_screenshot_file_names() -> void:
	eq(MainScript.screenshot_file_name(0), "shot_00.png")
	eq(MainScript.screenshot_file_name(7), "shot_07.png")
	eq(MainScript.screenshot_file_name(12), "shot_12.png")


func test_skip_reason_before_level_load() -> void:
	eq(MainScript.screenshot_skip_reason(false, true), "headless")
	eq(MainScript.screenshot_skip_reason(false, false), "headless")
	eq(MainScript.screenshot_skip_reason(true, false), "level_not_loaded", "istemci seviyeyi yüklemeden: boş kare yok")
	eq(MainScript.screenshot_skip_reason(true, true), "")


func test_headless_capture_is_skipped() -> void:
	is_false(MainScript.capture_supported(), "birim testler headless koşar")
	var m: MainScript = _main()
	var path: String = OS.get_temp_dir().path_join("insiders_test_screenshot_%d.png" % Time.get_ticks_usec())
	m.take_screenshot(2.0, path)
	var records: Array[Dictionary] = m.screenshot_records()
	eq(records.size(), 1)
	eq(records[0]["at"], 2.0)
	eq(records[0]["file"], path)
	is_false(bool(records[0]["ok"]), "headless'ta görüntü yok")
	is_false(FileAccess.file_exists(path), "dosya yazılmaz")
