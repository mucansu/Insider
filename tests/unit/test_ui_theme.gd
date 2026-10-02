extends TestCase
## Tema ve ton altyapısı (US-003 AC4, S9, KR-005): üretilmiş temalar güncel, oyun renkleri tondan
## bağımsız, palet okunur (kontrast), odak görünür, ui/ altında sabit renk yok.

## Renk değerlerinin kaynağı (ThemeTokens) ve üreticisi; sabit renk taramasından muaf.
const TOKEN_SOURCE_DIR := "res://ui/theme"


func test_generated_themes_are_up_to_date() -> void:
	for tone: Tone in ThemeTokens.available_tones():
		var path: String = ThemeTokens.theme_path(tone.id)
		if not is_true(ResourceLoader.exists(path), "tema dosyası yok: %s (build_themes.gd çalıştır)" % path):
			continue
		var saved: Theme = load(path) as Theme
		var diff: String = _diff(_snapshot(ThemeBuilder.build(tone)), _snapshot(saved), "")
		is_true(diff.is_empty(), "%s tondan farklı (build_themes.gd çalıştır): %s" % [path, diff])


func test_builder_is_deterministic() -> void:
	var tone: Tone = ThemeTokens.noir_tone()
	eq(_diff(_snapshot(ThemeBuilder.build(tone)), _snapshot(ThemeBuilder.build(tone)), ""), "")


func test_gameplay_colors_independent_of_tone() -> void:
	var other: Tone = ThemeTokens.noir_tone()
	other.id = &"test_inverted"
	for prop: String in ["bg_color", "surface_color", "raised_color", "line_color", "fg_color", "muted_color", "accent_color"]:
		other.set(prop, (other.get(prop) as Color).inverted())
	var t: Theme = ThemeBuilder.build(other)
	eq(t.get_color(&"font_color", &"CashLabel"), ThemeTokens.GAMEPLAY_CASH)
	eq(t.get_color(&"font_color", &"AlertLabel"), ThemeTokens.GAMEPLAY_ALERT)
	eq((t.get_stylebox(&"panel", &"AlertPanel") as StyleBoxFlat).border_color, ThemeTokens.GAMEPLAY_ALERT)
	eq(t.get_color(&"font_color", &"Label"), other.fg_color, "tona bağlı renk tondan gelir")
	for p: Dictionary in (Tone as Script).get_script_property_list():
		var prop_name: String = str(p["name"]).to_lower()
		is_false(prop_name.contains("gameplay") or prop_name.contains("player"), "Tone oyun rengi taşımamalı: " + prop_name)


func test_tone_selection_api() -> void:
	ThemeTokens.set_tone(null)
	eq(ThemeTokens.tone().id, ThemeTokens.DEFAULT_TONE_ID, "varsayılan noir")
	eq(ThemeTokens.theme().resource_path, "res://ui/theme/noir.tres")
	eq(ThemeTokens.available_tones()[0].id, &"noir")
	var custom: Tone = ThemeTokens.noir_tone()
	custom.id = &"test_missing_theme"
	ThemeTokens.set_tone(custom)
	eq(ThemeTokens.tone(), custom)
	# Bu çağrı bilerek "tema yok" uyarısı verir; uyarı test çıktısına basılmaz (IS-009).
	var fallback: Theme = _quietly(func() -> Theme: return ThemeTokens.theme()) as Theme
	eq(fallback.resource_path, "res://ui/theme/noir.tres", "teması üretilmemiş ton noir'e düşer")
	ThemeTokens.set_tone(null)
	var noir: Tone = ThemeTokens.noir_tone()
	eq(noir.bg_color, ThemeTokens.BG)
	eq(noir.wall_color, ThemeTokens.WALL)
	eq(noir.floor_color, ThemeTokens.FLOOR)
	eq(noir.accent_color, ThemeTokens.ACCENT)


func test_palette_contrast() -> void:
	# WCAG oranları: gövde metni ≥ 4,5, büyük metin/grafik ≥ 3; ana metin ≥ 7.
	var surfaces: Dictionary = {"BG": ThemeTokens.BG, "SURFACE": ThemeTokens.SURFACE, "SURFACE_RAISED": ThemeTokens.SURFACE_RAISED}
	for s: String in surfaces:
		var bg: Color = surfaces[s]
		_contrast_at_least(ThemeTokens.FG, bg, 7.0, "FG / " + s)
		_contrast_at_least(ThemeTokens.MUTED, bg, 4.5, "MUTED / " + s)
		_contrast_at_least(ThemeTokens.ACCENT, bg, 4.5, "ACCENT / " + s)
		_contrast_at_least(ThemeTokens.GAMEPLAY_CASH, bg, 4.5, "GAMEPLAY_CASH / " + s)
		_contrast_at_least(ThemeTokens.GAMEPLAY_ALERT, bg, 3.0, "GAMEPLAY_ALERT / " + s)
	_contrast_at_least(ThemeTokens.BG, ThemeTokens.ACCENT, 4.5, "basılı birincil buton yazısı")


func test_hud_chip_readable_over_world() -> void:
	# US-013: yarı saydam HUD paneli (HudChip) haritanın üstünde; en kötü dünya zemini panelin alfasıyla
	# harmanlanmış arka plana karşı yazı FG/MUTED/CASH ≥ 4,5, ALERT (yazı ve merdiven kutusu) ≥ 3.
	for tone: Tone in ThemeTokens.available_tones():
		var t: Theme = ThemeBuilder.build(tone)
		var chip: Color = (t.get_stylebox(&"panel", &"HudChip") as StyleBoxFlat).bg_color
		var world: Dictionary = {"bg": tone.bg_color, "wall_color": tone.wall_color}
		for p: Dictionary in (Tone as Script).get_script_property_list():
			var prop: String = p["name"]
			if prop.begins_with("level_") and prop.ends_with("_color"):
				world[prop] = tone.get(prop)
		is_true(world.size() >= 12, "dünya renkleri bulunamadı")
		var texts: Dictionary = {
			"FG": [t.get_color(&"font_color", &"Label"), 4.5],
			"MUTED": [t.get_color(&"font_color", &"MutedLabel"), 4.5],
			"CAPTION": [t.get_color(&"font_color", &"CaptionLabel"), 4.5],
			"CASH": [t.get_color(&"font_color", &"CashLabel"), 4.5],
			"ALERT": [t.get_color(&"font_color", &"AlertLabel"), 3.0],
		}
		for w: String in world:
			var under: Color = world[w]
			var behind: Color = under.lerp(Color(chip, 1.0), chip.a)
			for key: String in texts:
				var spec: Array = texts[key]
				_contrast_at_least(spec[0], behind, spec[1], "%s: %s / HudChip üstü %s" % [tone.id, key, w])


func test_focus_is_always_visible() -> void:
	var t: Theme = ThemeTokens.theme()
	for type: StringName in [&"Button", &"LineEdit"]:
		var sb: StyleBoxFlat = t.get_stylebox(&"focus", type) as StyleBoxFlat
		if not is_true(sb != null, "%s odak stili yok" % type):
			continue
		eq(sb.border_color, ThemeTokens.ACCENT, "%s odak rengi" % type)
		is_true(sb.border_width_left >= ThemeTokens.FOCUS_WIDTH, "%s odak kenarı kalın" % type)
		is_false(sb.draw_center, "%s odak çerçevesi içeriği örtmez" % type)


func test_scenes_use_tokens_only() -> void:
	# Renk ve yazı tipi yalnız temadan (ajan kuralı 2): sahnelerde tema geçersiz kılma ve renk sabiti yok.
	var banned_tscn: RegEx = RegEx.create_from_string("theme_override_(colors|fonts|font_sizes|styles)|Color\\(")
	for path: String in _files_under("res://ui", ".tscn"):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			is_true(banned_tscn.search(lines[i]) == null, "%s:%d sabit renk/tema geçersiz kılma: %s" % [path, i + 1, lines[i]])
	var banned_gd: RegEx = RegEx.create_from_string("\\bColor(8)?\\s*\\(|\\bColor\\.[a-zA-Z_]|add_theme_(color|font|font_size|stylebox)_override")
	for path: String in _files_under("res://ui", ".gd"):
		if path.begins_with(TOKEN_SOURCE_DIR):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var code: String = lines[i].get_slice("#", 0)
			is_true(banned_gd.search(code) == null, "%s:%d sabit renk: %s" % [path, i + 1, lines[i].strip_edges()])


func test_screens_reference_noir_theme() -> void:
	for scene: String in ["res://ui/main_menu.tscn", "res://ui/pause_menu.tscn", "res://ui/hud.tscn", "res://ui/heist_end.tscn"]:
		has(FileAccess.get_file_as_string(scene), "path=\"res://ui/theme/noir.tres\"", "%s editörde noir temasıyla açılır" % scene)


# --- yardımcılar ---

## `fn`'i motorun hata/uyarı yazımı kapalıyken çağırıp sonucunu döner: beklenen push_warning birim test
## çıktısına WARNING satırı basmasın (koşucunun allow_errors'u yalnız sayımı etkiler, yazımı değil).
## Bu sürede koşucu da hata yakalamaz; yalnız sonucu ayrıca doğrulanan tek çağrı için kullanılır.
## Çağrı `_invoke`ta: çağrı noktasındaki hata (geçersiz Callable, imza uyuşmazlığı) yalnız onu durdurur,
## yazım yine geri açılır; sonuç null döner ve test kendi doğrulamasında düşer.
static func _quietly(fn: Callable) -> Variant:
	var previous: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var result: Variant = _invoke(fn)
	Engine.print_error_messages = previous
	return result


static func _invoke(fn: Callable) -> Variant:
	return fn.call()


func _contrast_at_least(fg: Color, bg: Color, minimum: float, what: String) -> void:
	var ratio: float = _contrast(fg, bg)
	is_true(ratio >= minimum, "%s kontrastı %.2f < %.1f" % [what, ratio, minimum])


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _relative_luminance(a)
	var lb: float = _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## WCAG göreli parlaklığı (sRGB → doğrusal).
static func _relative_luminance(c: Color) -> float:
	var lin: Color = c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b


static func _snapshot(t: Theme) -> Dictionary:
	var out: Dictionary = {
		"default_font_size": t.default_font_size,
		"default_font": _resource_snapshot(t.default_font),
	}
	var types: PackedStringArray = t.get_type_list()
	types.sort()
	for type: String in types:
		var entry: Dictionary = {"base": str(t.get_type_variation_base(type))}
		for item: String in t.get_color_list(type):
			entry["color/" + item] = t.get_color(item, type).to_html()
		for item: String in t.get_constant_list(type):
			entry["constant/" + item] = t.get_constant(item, type)
		for item: String in t.get_font_size_list(type):
			entry["font_size/" + item] = t.get_font_size(item, type)
		for item: String in t.get_font_list(type):
			entry["font/" + item] = _resource_snapshot(t.get_font(item, type))
		for item: String in t.get_stylebox_list(type):
			entry["style/" + item] = _resource_snapshot(t.get_stylebox(item, type))
		out[type] = entry
	return out


static func _resource_snapshot(r: Resource) -> Variant:
	if r == null:
		return null
	if not r.resource_path.is_empty() and not r.resource_path.contains("::"):
		return r.resource_path  # dış kaynak (ör. yazı tipi dosyası): yoluyla karşılaştır
	var out: Dictionary = {"class": r.get_class()}
	for p: Dictionary in r.get_property_list():
		var prop: String = p["name"]
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE) or prop.begins_with("resource_") or prop == "script":
			continue
		var v: Variant = r.get(prop)
		if v is Color:
			v = (v as Color).to_html()
		elif v is float:
			v = snappedf(v as float, 0.001)
		elif v is Resource:
			v = _resource_snapshot(v as Resource)
		out[prop] = v
	return out


## İlk farkı "yol: beklenen ≠ gelen" biçiminde döner; fark yoksa boş.
static func _diff(expected: Variant, actual: Variant, where: String) -> String:
	if expected is Dictionary and actual is Dictionary:
		var e: Dictionary = expected
		var a: Dictionary = actual
		var keys: Array = e.keys()
		for k: Variant in a.keys():
			if not e.has(k):
				keys.append(k)
		for k: Variant in keys:
			var sub: String = "%s/%s" % [where, k]
			if not e.has(k):
				return "%s: fazladan" % sub
			if not a.has(k):
				return "%s: eksik" % sub
			var d: String = _diff(e[k], a[k], sub)
			if not d.is_empty():
				return d
		return ""
	if typeof(expected) != typeof(actual) or expected != actual:
		return "%s: beklenen %s ≠ gelen %s" % [where, var_to_str(expected), var_to_str(actual)]
	return ""


static func _files_under(dir: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(dir.path_join(d), ext))
	return out
