class_name Tone
extends Resource
## Cosmetic values of one tone (KR-005, GDD §13): palette, type, shape.
## Rules and gameplay-meaningful colours (ThemeTokens.GAMEPLAY_*, PLAYER_COLORS) are NOT here; they are identical in every tone.
## Noir: ThemeTokens.noir_tone(). New tone: ui/theme/tones/<id>.tres + build_themes.gd generates ui/theme/<id>.tres.

@export var id: StringName = &""
## Name shown on the tone picker (i18n key).
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

@export_subgroup("Level")
## Level placeholder drawing (levels/level_layout.gd, IS-008); noir values are ThemeTokens.LEVEL_*.
## Map edge uses bg_color; edge scan, kerb border and glass frame use wall_color.
@export var level_floor_color: Color
@export var level_backroom_color: Color
@export var level_sidewalk_color: Color
@export var level_street_color: Color
@export var level_wall_color: Color
@export var level_wall_edge_color: Color
@export var level_glass_color: Color
@export var level_shelf_color: Color
@export var level_shelf_edge_color: Color
@export var level_counter_color: Color
@export var level_counter_edge_color: Color

@export_group("Type")
## null: Godot default font.
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
