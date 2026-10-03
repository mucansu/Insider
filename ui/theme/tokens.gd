class_name ThemeTokens
extends RefCounted
## Theme tokens and tone infrastructure (S9 — docs/notes/mimari.md, KR-005, GDD §13).
##
## Layout:
## - Constants (BG, FG, ...) are the **noir** tone's values: used where compile-time constants are needed (e.g. level placeholder colours). This file is noir's single source.
## - A tone is a `Tone` resource (ui/theme/tone.gd): palette + type + shape. `noir_tone()` builds noir from these constants; future tones are `ui/theme/tones/<id>.tres`.
## - Each tone's Godot theme is `ui/theme/<id>.tres` (`noir.tres` for noir), generated from the tone by ThemeBuilder: `godot --headless --path . -s res://ui/theme/build_themes.gd`.
##   Never hand-edited; tests/unit/test_ui_theme.gd checks the generated file matches the tone.
## - Screens get the theme via `ThemeTokens.apply(root)`; tone-aware code reads colours from `ThemeTokens.tone()`.
## - GAMEPLAY_* and PLAYER_COLORS are gameplay-meaningful: not tone-dependent, identical in every tone (no counterpart in `Tone`; the theme takes them straight from here).

# --- noir palette ---
const BG := Color("#0f1114")
const FG := Color("#e6e2d8")
## Lightened from the stub value (#7a7e86) so AA contrast (>= 4.5) also holds on card and input backgrounds.
const MUTED := Color("#868a92")
const ACCENT := Color("#c9a24b")
const WALL := Color("#2c2f36")
const FLOOR := Color("#1a1c21")
## Card/panel background.
const SURFACE := Color("#161920")
## Input field and button background.
const SURFACE_RAISED := Color("#1f232b")
## Edge and divider line.
const LINE := Color("#2f343d")

# --- noir level palette (IS-008): level placeholder drawing, levels/level_layout.gd ---
## Tone counterparts are `Tone.level_*_color`; the level reads them from `tone()`. Map edge fill is BG; edge scan, kerb border and glass frame are WALL (bg_color, wall_color in the tone).
## Values are today's results of the US-002 derivations (ratios in the comments); fixed so UI tweaks (e.g. MUTED contrast) do not shift the level look.
## Sales floor and door gap: FLOOR -> ACCENT 12% (lit interior).
const LEVEL_FLOOR := Color("#2f2c26")
## Back room floor: FLOOR -> ACCENT 5%.
const LEVEL_BACKROOM := Color("#232323")
## Pavement and alley: FLOOR -> WALL 40%.
const LEVEL_SIDEWALK := Color("#212429")
## Street: BG -> FLOOR 50%.
const LEVEL_STREET := Color("#15171b")
## Wall fill: WALL -> MUTED 45%.
const LEVEL_WALL := Color("#55585f")
## Edge line on the walkable side of a wall (MUTED).
const LEVEL_WALL_EDGE := Color("#868a92")
## Shop-window glass strip: MUTED -> FG 25%.
const LEVEL_GLASS := Color("#9ea0a4")
## Shelf fill: WALL -> MUTED 20%.
const LEVEL_SHELF := Color("#3e4148")
## Shelf outline and dividers: MUTED darkened 25%.
const LEVEL_SHELF_EDGE := Color("#65686e")
## Counter fill: ACCENT darkened 60%.
const LEVEL_COUNTER := Color("#50411e")
## Counter outline: ACCENT darkened 35%.
const LEVEL_COUNTER_EDGE := Color("#836931")

# --- noir type and shape (font: Godot default) ---
const FONT_SIZE_SMALL := 15
const FONT_SIZE_BODY := 18
const FONT_SIZE_HEADING := 24
const FONT_SIZE_TITLE := 64
const TITLE_LETTER_SPACING := 10
const CAPTION_LETTER_SPACING := 2
const CORNER_RADIUS := 2
const BORDER_WIDTH := 1
const FOCUS_WIDTH := 2

# --- tone-independent layout ---
const SPACING := 10
const PADDING := 16
const SCREEN_MARGIN := 20

# --- gameplay-meaningful colours (identical in every tone) ---
const GAMEPLAY_ALERT := Color("#d8453a")
const GAMEPLAY_CASH := Color("#58b368")
## Escape point (US-038): world marker, HUD edge arrow and escape rows. Yellow: distinct from cash green, alert red and player colours; high contrast on the noir ground (BG).
const GAMEPLAY_ESCAPE := Color("#e9dd4f")

# --- vision fog (US-011a; GDD §6.5): tile tones, levels/fog/fog_layer ---
## Fog tone = BG overlaid with alpha; the saturation multiplier applies to the image below first.
## Unknown: opaque flat tone (no content leaks); only the sketch (wall edges, door thresholds) draws above the fog.
const GAMEPLAY_FOG_UNKNOWN := Color(BG.r, BG.g, BG.b, 1.0)
const GAMEPLAY_FOG_UNKNOWN_SATURATION := 1.0
## Memory: seen earlier this phase, not currently seen (structures and furniture as last seen, faded).
const GAMEPLAY_FOG_MEMORY := Color(BG.r, BG.g, BG.b, 0.55)
const GAMEPLAY_FOG_MEMORY_SATURATION := 0.5
## Ambient (directional mode only): the sides of the sharp cone.
const GAMEPLAY_FOG_PERIPHERAL := Color(BG.r, BG.g, BG.b, 0.30)
const GAMEPLAY_FOG_PERIPHERAL_SATURATION := 0.6
## Dark-zone scan (45 deg; dark tiles in memory tone even inside the line of sight): MUTED, alpha 0.35.
const GAMEPLAY_FOG_DARK_HATCH := Color(MUTED.r, MUTED.g, MUTED.b, 0.35)

# --- NPC attention readability (IS-096; GDD §9.3 "Sahip okunurluğu"): NpcVisual cone, drawn in the tone's FG ---
## Cone fill opacity when calm (the local player is not inside it).
const GAMEPLAY_CONE_ALPHA := 0.15
## Cone fill opacity while the local player stands inside the cone, plus an edge line of this opacity and width (px).
const GAMEPLAY_CONE_WATCHED_ALPHA := 0.25
const GAMEPLAY_CONE_EDGE_ALPHA := 0.35
const GAMEPLAY_CONE_EDGE_WIDTH := 1.0

## Player colours, in join order (max 4 players).
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


## Noir tone, from the constants above.
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


## Active tone (default noir). Online the host picks the tone (GDD §13); the picker flow comes in later items.
static func tone() -> Tone:
	if _tone == null:
		_tone = noir_tone()
	return _tone


## Sets the active tone; null returns to noir. Screens opened afterwards get the new tone's theme.
static func set_tone(value: Tone) -> void:
	_tone = value


## Noir + ui/theme/tones/*.tres (by file name, noir first).
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


## Path of the tone's generated Godot theme.
static func theme_path(tone_id: StringName) -> String:
	return THEME_DIR.path_join("%s.tres" % tone_id)


## Theme of the active tone; falls back to the noir theme if its file is missing.
static func theme() -> Theme:
	var path: String = theme_path(tone().id)
	if not ResourceLoader.exists(path):
		push_warning("ThemeTokens: tema yok (%s), noir kullanılıyor; build_themes.gd çalıştırılmalı" % path)
		path = theme_path(DEFAULT_TONE_ID)
	return load(path) as Theme


## The screen root gets the active tone's theme through this call.
static func apply(root: Control) -> void:
	root.theme = theme()
