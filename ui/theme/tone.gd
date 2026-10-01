class_name Tone
extends Resource
## Bir tonun kozmetik değerleri (KR-005, GDD §13): palet, yazı, biçim.
## Kurallar ve oyun için anlamlı renkler (ThemeTokens.GAMEPLAY_*, PLAYER_COLORS) burada YOKTUR; her tonda aynıdır.
## Noir: ThemeTokens.noir_tone(). Yeni ton: ui/theme/tones/<id>.tres + build_themes.gd ile ui/theme/<id>.tres teması.

@export var id: StringName = &""
## Ton seçim ekranında görünecek ad (i18n anahtarı).
@export var name_key: String = ""

@export_group("Palette")
@export var bg_color: Color
@export var surface_color: Color
@export var raised_color: Color
@export var line_color: Color
@export var fg_color: Color
@export var muted_color: Color
@export var accent_color: Color
@export var wall_color: Color
@export var floor_color: Color

@export_group("Type")
## null: Godot varsayılan yazı tipi.
@export var font: Font
@export var font_size_small: int = 15
@export var font_size_body: int = 18
@export var font_size_heading: int = 24
@export var font_size_title: int = 64
@export var title_letter_spacing: int = 0
@export var caption_letter_spacing: int = 0

@export_group("Shape")
@export var corner_radius: int = 0
@export var border_width: int = 1
@export var focus_width: int = 2
