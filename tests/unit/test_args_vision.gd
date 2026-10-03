extends TestCase
## Args `--vision-mode=peripheral|directional` (US-011d; S6 addition, GDD §6.5, KR-023).

const ArgsScript := preload("res://autoload/args.gd")


func _make() -> ArgsScript:
	return autofree(ArgsScript.new()) as ArgsScript


func test_default_is_peripheral() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray([]))
	eq(ArgsScript.DEFAULT_VISION_MODE, "peripheral")
	eq(a.vision_mode, "peripheral")
	is_false(a.vision_mode_given)
	eq(ArgsScript.VISION_MODES, ["peripheral", "directional"] as Array[String])


func test_valid_modes() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--vision-mode=directional"]))
	eq(a.vision_mode, "directional")
	is_true(a.vision_mode_given)
	eq(a.unknown.size(), 0, "tanınan argüman unknown'a girmez")
	a.parse(PackedStringArray(["--host", " --vision-mode= Peripheral ", "--port=9000"]))
	eq(a.vision_mode, "peripheral", "boşluk ve büyük harf tolere edilir")
	is_true(a.vision_mode_given)
	is_true(a.want_host)
	eq(a.port, 9000)


func test_invalid_falls_back_to_peripheral() -> void:
	var a: ArgsScript = _make()
	for bad: String in ["--vision-mode=omni", "--vision-mode=", "--vision-mode", "--vision-mode=directional2"]:
		a.parse(PackedStringArray([bad]))
		eq(a.vision_mode, "peripheral", "geçersiz: " + bad)
		is_false(a.vision_mode_given, "geçersiz: " + bad)
		eq(a.unknown.size(), 0, "geçersiz değer de tanınan anahtardır: " + bad)


func test_reparse_resets_mode() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--vision-mode=directional"]))
	a.parse(PackedStringArray(["--join=10.0.0.2"]))
	eq(a.vision_mode, "peripheral")
	is_false(a.vision_mode_given)


func test_unknown_order_kept() -> void:
	var a: ArgsScript = _make()
	a.parse(PackedStringArray(["--filter=x", "--vision-mode=directional", "--timeout=5", "--vision-moder=1"]))
	eq(a.unknown, PackedStringArray(["--filter=x", "--timeout=5", "--vision-moder=1"]))
	eq(a.vision_mode, "directional")


func test_autoload_default_in_test_run() -> void:
	# The test runner passes no --vision-mode; the autoload must be at its default.
	eq(Args.vision_mode, "peripheral")
