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

# --- noir seviye paleti (IS-008): seviye yer tutucu çizimi, levels/level_layout.gd ---
## Tonda karşılıkları `Tone.level_*_color`; seviye bunları `tone()`dan okur. Harita kenarı dolgusu BG,
## kenar taraması, kaldırım bordürü ve cam çerçevesi WALL'dır (tonda bg_color, wall_color).
## Değerler US-002'deki türetmelerin (yorumdaki oranlar) bugünkü paletle sonucudur; sabitlendikleri için
## arayüz ayarları (ör. MUTED kontrastı) seviye görünümünü kaydırmaz.
## Satış alanı zemini ve kapı boşluğu: FLOOR → ACCENT %12 (aydınlık iç mekân).
const LEVEL_FLOOR := Color("#2f2c26")
## Arka oda zemini: FLOOR → ACCENT %5.
const LEVEL_BACKROOM := Color("#232323")
## Kaldırım ve ara sokak: FLOOR → WALL %40.
const LEVEL_SIDEWALK := Color("#212429")
## Cadde: BG → FLOOR %50.
const LEVEL_STREET := Color("#15171b")
## Duvar dolgusu: WALL → MUTED %45.
const LEVEL_WALL := Color("#55585f")
## Duvarın yürünebilir tarafındaki kenar çizgisi (MUTED).
const LEVEL_WALL_EDGE := Color("#868a92")
## Vitrin camı şeridi: MUTED → FG %25.
const LEVEL_GLASS := Color("#9ea0a4")
## Raf dolgusu: WALL → MUTED %20.
const LEVEL_SHELF := Color("#3e4148")
## Raf dış çizgisi ve bölmeleri: MUTED %25 koyu.
const LEVEL_SHELF_EDGE := Color("#65686e")
## Tezgâh dolgusu: ACCENT %60 koyu.
const LEVEL_COUNTER := Color("#50411e")
## Tezgâh dış çizgisi: ACCENT %35 koyu.
const LEVEL_COUNTER_EDGE := Color("#836931")

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

# --- görüş sisi (US-011a; GDD §6.5): karo tonları, levels/fog/fog_layer ---
## Sis tonu = BG + alfa ile üstüne bindirme; doygunluk çarpanı alttaki görüntüye önce uygulanır.
## Bilinmeyen: opak düz ton (içerik sızmaz); yalnız kroki (duvar kenarı, kapı eşiği) sisin üstünde çizilir.
const GAMEPLAY_FOG_UNKNOWN := Color(BG.r, BG.g, BG.b, 1.0)
const GAMEPLAY_FOG_UNKNOWN_SATURATION := 1.0
## Hafıza: bu fazda görülmüş, şu an görülmeyen (yapı ve mobilya son görülen hâliyle, soluk).
const GAMEPLAY_FOG_MEMORY := Color(BG.r, BG.g, BG.b, 0.55)
const GAMEPLAY_FOG_MEMORY_SATURATION := 0.5
## Çevresel (yalnız yönlü kip): net koninin yanları.
const GAMEPLAY_FOG_PERIPHERAL := Color(BG.r, BG.g, BG.b, 0.30)
const GAMEPLAY_FOG_PERIPHERAL_SATURATION := 0.6
## Karanlık bölge taraması (45°; görüş hattında bile hafıza tonundaki karanlık karolar): MUTED, α 0,35.
const GAMEPLAY_FOG_DARK_HATCH := Color(MUTED.r, MUTED.g, MUTED.b, 0.35)

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
	t.level_floor_color = LEVEL_FLOOR
	t.level_backroom_color = LEVEL_BACKROOM
	t.level_sidewalk_color = LEVEL_SIDEWALK
	t.level_street_color = LEVEL_STREET
	t.level_wall_color = LEVEL_WALL
	t.level_wall_edge_color = LEVEL_WALL_EDGE
	t.level_glass_color = LEVEL_GLASS
	t.level_shelf_color = LEVEL_SHELF
	t.level_shelf_edge_color = LEVEL_SHELF_EDGE
	t.level_counter_color = LEVEL_COUNTER
	t.level_counter_edge_color = LEVEL_COUNTER_EDGE
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
