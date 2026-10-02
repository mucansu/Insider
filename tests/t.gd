class_name TestCase
extends RefCounted
## Birim test tabanı ve doğrulama yardımcıları (mimari.md §5). Eklentisiz.
##
## Kullanım: tests/unit/test_<modül>.gd dosyası `extends TestCase` olur; `test_` ile başlayan,
## argümansız her metot bir testtir (`await` kullanabilir). Koşucu her test için yeni örnek açar.
##   func test_toplam() -> void:
##       eq(1 + 1, 2)
##       near(Vector2(0, 0), Vector2(3, 4), 5.0)
## Doğrulamalar testi durdurmaz, başarısızlığı kaydeder ve bool döner (`if not is_true(x): return`).
## Test sırasında oluşan betik hatası (SCRIPT ERROR) testi her zaman düşürür; push_error / motor
## hatası da düşürür, test bunları bilerek tetikliyorsa önce `allow_errors()` çağırır.
## (`true`/`false` GDScript anahtar sözcüğü olduğundan yardımcı adları `is_true`/`is_false`.)

const _SELF_PATH := "res://tests/t.gd"

var _failures: PackedStringArray = []
var _errors_allowed: bool = false
var _autofree: Array[Object] = []


## İki değer eşit olmalı (int/float birbiriyle, String/StringName birbiriyle karşılaştırılabilir).
func eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if _same(actual, expected):
		return true
	return _record("eq: beklenen %s, gelen %s" % [_show(expected), _show(actual)], msg)


## İki değer farklı olmalı.
func ne(actual: Variant, unexpected: Variant, msg: String = "") -> bool:
	if not _same(actual, unexpected):
		return true
	return _record("ne: %s olmamalıydı" % _show(unexpected), msg)


func is_true(value: bool, msg: String = "") -> bool:
	if value:
		return true
	return _record("is_true: false geldi", msg)


func is_false(value: bool, msg: String = "") -> bool:
	if not value:
		return true
	return _record("is_false: true geldi", msg)


## Sayı ya da vektör (Vector2/3) farkı `tolerance` içinde olmalı.
func near(actual: Variant, expected: Variant, tolerance: float, msg: String = "") -> bool:
	var diff: float = INF
	var numeric: Array[int] = [TYPE_INT, TYPE_FLOAT]
	if typeof(actual) in numeric and typeof(expected) in numeric:
		diff = absf(float(actual) - float(expected))
	elif typeof(actual) == TYPE_VECTOR2 and typeof(expected) == TYPE_VECTOR2:
		diff = (actual as Vector2).distance_to(expected as Vector2)
	elif typeof(actual) == TYPE_VECTOR3 and typeof(expected) == TYPE_VECTOR3:
		diff = (actual as Vector3).distance_to(expected as Vector3)
	else:
		return _record("near: desteklenmeyen tipler %s / %s" % [type_string(typeof(actual)), type_string(typeof(expected))], msg)
	if diff <= tolerance:
		return true
	return _record("near: beklenen %s ± %s, gelen %s (fark %s)" % [_show(expected), tolerance, _show(actual), diff], msg)


## Kap öğeyi içermeli: Array/Packed*Array (öğe), Dictionary (anahtar), String/StringName (alt dize).
func has(container: Variant, item: Variant, msg: String = "") -> bool:
	var found: bool = false
	# Her kap kendi tipine çevrilip kendi has()'i çağrılır (unsafe_method_access = hata; davranış Variant
	# üzerinden dinamik çağrıyla aynı: öğe çalışma anında parametre tipine çevrilir).
	match typeof(container):
		TYPE_STRING, TYPE_STRING_NAME:
			found = str(container).contains(str(item))
		TYPE_ARRAY:
			found = (container as Array).has(item)
		TYPE_DICTIONARY:
			found = (container as Dictionary).has(item)
		TYPE_PACKED_BYTE_ARRAY:
			found = (container as PackedByteArray).has(item)
		TYPE_PACKED_INT32_ARRAY:
			found = (container as PackedInt32Array).has(item)
		TYPE_PACKED_INT64_ARRAY:
			found = (container as PackedInt64Array).has(item)
		TYPE_PACKED_FLOAT32_ARRAY:
			found = (container as PackedFloat32Array).has(item)
		TYPE_PACKED_FLOAT64_ARRAY:
			found = (container as PackedFloat64Array).has(item)
		TYPE_PACKED_STRING_ARRAY:
			found = (container as PackedStringArray).has(item)
		TYPE_PACKED_VECTOR2_ARRAY:
			found = (container as PackedVector2Array).has(item)
		TYPE_PACKED_VECTOR3_ARRAY:
			found = (container as PackedVector3Array).has(item)
		TYPE_PACKED_COLOR_ARRAY:
			found = (container as PackedColorArray).has(item)
		TYPE_PACKED_VECTOR4_ARRAY:
			found = (container as PackedVector4Array).has(item)
		_:
			return _record("has: desteklenmeyen kap tipi %s" % type_string(typeof(container)), msg)
	if found:
		return true
	return _record("has: %s içinde %s yok" % [_show(container), _show(item)], msg)


## Koşulsuz başarısızlık.
func fail(msg: String) -> bool:
	return _record("fail", msg)


## Testin push_error / motor hatası üretmesi bekleniyorsa çağrılır (betik hataları yine düşürür).
func allow_errors() -> void:
	_errors_allowed = true


## Nesneyi test bitince serbest bırakılmak üzere kaydeder ve geri döner (sahneye eklenen düğümler için).
func autofree(obj: Object) -> Object:
	_autofree.append(obj)
	return obj


func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


# --- koşucu (tests/run_tests.gd) için ---

func failures() -> PackedStringArray:
	return _failures


func errors_allowed() -> bool:
	return _errors_allowed


func free_tracked() -> void:
	for obj: Object in _autofree:
		if not is_instance_valid(obj) or obj is RefCounted:
			continue
		if obj is Node and (obj as Node).is_inside_tree():
			(obj as Node).queue_free()
		else:
			obj.free()
	_autofree.clear()


func _record(what: String, msg: String) -> bool:
	var line: String = what
	if not msg.is_empty():
		line += " — " + msg
	var where: String = _caller_location()
	if not where.is_empty():
		line += " (%s)" % where
	_failures.append(line)
	return false


## Doğrulamayı çağıran test satırını bulur (t.gd dışındaki ilk betik çerçevesi).
func _caller_location() -> String:
	for bt: ScriptBacktrace in Engine.capture_script_backtraces(false):
		for i: int in bt.get_frame_count():
			var file: String = bt.get_frame_file(i)
			if file != _SELF_PATH:
				return "%s:%d" % [file, bt.get_frame_line(i)]
	return ""


static func _same(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta != tb:
		var numeric: Array[int] = [TYPE_INT, TYPE_FLOAT]
		var text: Array[int] = [TYPE_STRING, TYPE_STRING_NAME]
		if not ((ta in numeric and tb in numeric) or (ta in text and tb in text)):
			return false
	return a == b


static func _show(v: Variant) -> String:
	if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
		return '"%s"' % v
	return str(v)
