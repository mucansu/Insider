class_name ThemeTokens
extends RefCounted
## Tema token'ları ve ton altyapısı (S9 — docs/notes/mimari.md, KR-005, GDD §13).
##
## Düzen:
## - Sabitler (BG, FG, ...) **noir** tonunun değerleridir: derleme zamanında sabit gereken yerler
##   (ör. seviye yer tutucu renkleri) bunları okur. Noir tonunun tek kaynağı bu dosyadır.
## - Ton = `Tone` kaynağı (ui/theme/tone.gd): palet + yazı + biçim. Noir'i `noir_tone()` bu sabitlerden
##   kurar; ileride eklenecek tonlar `ui/theme/tones/<id>.tres` dosyalarıdır.
## - Her tonun Godot teması `ui/theme/<id>.tres` (noir için `noir.tres`); ThemeBuilder ile tondan
##   üretilir: `godot --headless --path . -s res://ui/theme/build_themes.gd`. Elle düzenlenmez;
##   tests/unit/test_ui_theme.gd üretilmiş dosyanın tonla aynı olduğunu doğrular.
## - Ekranlar temayı `ThemeTokens.apply(kök)` ile alır; tona duyarlı kod renkleri `ThemeTokens.tone()`dan okur.
## - GAMEPLAY_* ve PLAYER_COLORS oyun için anlamlıdır: tona bağlı değildir, her tonda aynı kalır
##   (Tone kaynağında karşılıkları yoktur; tema bunları doğrudan buradan alır).

# --- noir paleti ---
const BG := Color("#0f1114")
const FG := Color("#e6e2d8")
## AA kontrastı (≥ 4,5) kart ve giriş zeminlerinde de sağlansın diye stub değerinden (#7a7e86) açıldı.
const MUTED := Color("#868a92")
const ACCENT := Color("#c9a24b")
const WALL := Color("#2c2f36")
const FLOOR := Color("#1a1c21")
## Kart/panel zemini.
const SURFACE := Color("#161920")
## Giriş alanı ve buton zemini.
const SURFACE_RAISED := Color("#1f232b")
## Kenar ve ayraç çizgisi.
const LINE := Color("#2f343d")

# --- noir yazı ve biçim (yazı tipi: Godot varsayılanı) ---
const FONT_SIZE_SMALL := 15
const FONT_SIZE_BODY := 18
const FONT_SIZE_HEADING := 24
const FONT_SIZE_TITLE := 64
const TITLE_LETTER_SPACING := 10
const CAPTION_LETTER_SPACING := 2
const CORNER_RADIUS := 2
const BORDER_WIDTH := 1
const FOCUS_WIDTH := 2

# --- tondan bağımsız yerleşim ---
const SPACING := 10
const PADDING := 16
const SCREEN_MARGIN := 20

# --- oyun için anlamlı renkler (her tonda aynı) ---
const GAMEPLAY_ALERT := Color("#d8453a")
const GAMEPLAY_CASH := Color("#58b368")

## Oyuncu renkleri, katılım sırasıyla (en fazla 4 oyuncu).
const PLAYER_COLORS: Array[Color] = [
	Color("#4f9ddf"),
	Color("#e48a3a"),
	Color("#a77fd8"),
	Color("#45b8aa"),
]

const DEFAULT_TONE_ID := &"noir"
const THEME_DIR := "res://ui/theme"
const TONES_DIR := "res://ui/theme/tones"

static var _tone: Tone = null


## Noir tonu, yukarıdaki sabitlerden.
static func noir_tone() -> Tone:
	var t := Tone.new()
	t.id = DEFAULT_TONE_ID
	t.name_key = "TONE_NOIR"
	t.bg_color = BG
	t.surface_color = SURFACE
	t.raised_color = SURFACE_RAISED
	t.line_color = LINE
	t.fg_color = FG
	t.muted_color = MUTED
	t.accent_color = ACCENT
	t.wall_color = WALL
	t.floor_color = FLOOR
	t.font_size_small = FONT_SIZE_SMALL
	t.font_size_body = FONT_SIZE_BODY
	t.font_size_heading = FONT_SIZE_HEADING
	t.font_size_title = FONT_SIZE_TITLE
	t.title_letter_spacing = TITLE_LETTER_SPACING
	t.caption_letter_spacing = CAPTION_LETTER_SPACING
	t.corner_radius = CORNER_RADIUS
	t.border_width = BORDER_WIDTH
	t.focus_width = FOCUS_WIDTH
	return t


## Etkin ton (varsayılan noir). Online'da tonu host seçer (GDD §13); seçim akışı sonraki kalemlerde.
static func tone() -> Tone:
	if _tone == null:
		_tone = noir_tone()
	return _tone


## Etkin tonu değiştirir; null noir'e döner. Sonra açılan ekranlar yeni tonun temasını alır.
static func set_tone(value: Tone) -> void:
	_tone = value


## Noir + ui/theme/tones/*.tres (dosya adı sırasıyla, noir başta).
static func available_tones() -> Array[Tone]:
	var out: Array[Tone] = [noir_tone()]
	if not DirAccess.dir_exists_absolute(TONES_DIR):
		return out
	var files: PackedStringArray = DirAccess.get_files_at(TONES_DIR)
	files.sort()
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var t: Tone = load(TONES_DIR.path_join(f)) as Tone
		if t == null:
			push_warning("ThemeTokens: ton kaynağı okunamadı: " + f)
		elif t.id == DEFAULT_TONE_ID:
			push_warning("ThemeTokens: noir sabitlerden gelir, %s yok sayıldı" % f)
		else:
			out.append(t)
	return out


## Tonun üretilmiş Godot temasının yolu.
static func theme_path(tone_id: StringName) -> String:
	return THEME_DIR.path_join("%s.tres" % tone_id)


## Etkin tonun teması; dosyası yoksa noir temasına düşer.
static func theme() -> Theme:
	var path: String = theme_path(tone().id)
	if not ResourceLoader.exists(path):
		push_warning("ThemeTokens: tema yok (%s), noir kullanılıyor; build_themes.gd çalıştırılmalı" % path)
		path = theme_path(DEFAULT_TONE_ID)
	return load(path) as Theme


## Ekran kökü bu çağrıyla etkin tonun temasını alır.
static func apply(root: Control) -> void:
	root.theme = theme()
