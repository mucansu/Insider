class_name ThemeBuilder
extends RefCounted
## Bir `Tone`'dan Godot `Theme`'i kurar (S9). Çıktı deterministiktir; build_themes.gd bunu
## ui/theme/<id>.tres olarak kaydeder, test_ui_theme.gd kayıtlı dosyanın güncel olduğunu doğrular.
## Oyun için anlamlı renkler (CashLabel, AlertLabel, AlertPanel) tondan değil ThemeTokens.GAMEPLAY_*'dan gelir.
##
## Tür varyasyonları (sahnelerde `theme_type_variation`):
##   Label: TitleLabel, AlertTitleLabel, HeadingLabel, CaptionLabel, MutedLabel, AlertLabel, CashLabel
##   Button: PrimaryButton · HSeparator: AccentSeparator · MarginContainer: HudFrame
##   PanelContainer: CardPanel, HudPanel, HudChip, ToastPanel, AlertPanel, LadderStep, LadderStepActive
##   Panel: BackgroundPanel, DimPanel · VBoxContainer: LooseVBox · HBoxContainer: LooseHBox

const HUD_PANEL_ALPHA := 0.88
## HUD köşe ögeleri (nakit, ekip, uyarı merdiveni; US-013): haritayı az örten dar panel. Alfa, en açık dünya
## zemini (cam) üstünde bile MUTED ≥ 4,5 kalacak kadar yüksek (test_ui_theme: test_hud_chip_readable_over_world).
const HUD_CHIP_ALPHA := 0.94
const HUD_CHIP_PAD := Vector2i(10, 4)
const TOAST_PANEL_ALPHA := 0.94
const DIM_ALPHA := 0.78
const SELECTION_ALPHA := 0.35
const PRIMARY_HOVER_ALPHA := 0.14
const STRIPE_WIDTH := 3
const BUTTON_PAD := Vector2i(18, 10)
const FIELD_PAD := Vector2i(10, 8)
const CARD_PAD := Vector2i(22, 18)
const HUD_PAD := Vector2i(12, 8)
const TOAST_PAD := Vector2i(16, 10)
const PROGRESS_HEIGHT := 10


static func build(tone: Tone) -> Theme:
	var t := Theme.new()
	t.default_font = tone.font
	t.default_font_size = tone.font_size_body
	_labels(t, tone)
	_buttons(t, tone)
	_line_edit(t, tone)
	_panels(t, tone)
	_misc(t, tone)
	return t


static func _labels(t: Theme, tone: Tone) -> void:
	t.set_color(&"font_color", &"Label", tone.fg_color)
	var title_font := _spaced_font(tone, tone.title_letter_spacing, "title_font")
	var caption_font := _spaced_font(tone, tone.caption_letter_spacing, "caption_font")
	_variation(t, &"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", title_font)
	t.set_font_size(&"font_size", &"TitleLabel", tone.font_size_title)
	t.set_color(&"font_color", &"TitleLabel", tone.fg_color)
	# Kayıp sonucu başlığı (US-013 iş sonu ekranı): TitleLabel, uyarı renginde.
	_variation(t, &"AlertTitleLabel", &"TitleLabel")
	t.set_color(&"font_color", &"AlertTitleLabel", ThemeTokens.GAMEPLAY_ALERT)
	_variation(t, &"HeadingLabel", &"Label")
	t.set_font_size(&"font_size", &"HeadingLabel", tone.font_size_heading)
	t.set_color(&"font_color", &"HeadingLabel", tone.fg_color)
	_variation(t, &"CaptionLabel", &"Label")
	t.set_font(&"font", &"CaptionLabel", caption_font)
	t.set_font_size(&"font_size", &"CaptionLabel", tone.font_size_small)
	t.set_color(&"font_color", &"CaptionLabel", tone.muted_color)
	_variation(t, &"MutedLabel", &"Label")
	t.set_color(&"font_color", &"MutedLabel", tone.muted_color)
	_variation(t, &"AlertLabel", &"Label")
	t.set_color(&"font_color", &"AlertLabel", ThemeTokens.GAMEPLAY_ALERT)
	_variation(t, &"CashLabel", &"Label")
	t.set_font_size(&"font_size", &"CashLabel", tone.font_size_heading)
	t.set_color(&"font_color", &"CashLabel", ThemeTokens.GAMEPLAY_CASH)


static func _buttons(t: Theme, tone: Tone) -> void:
	var hover_bg: Color = tone.raised_color.lerp(tone.line_color, 0.5)
	t.set_stylebox(&"normal", &"Button", _box("button_normal", tone.raised_color, tone.line_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"hover", &"Button", _box("button_hover", hover_bg, tone.line_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"pressed", &"Button", _box("button_pressed", tone.bg_color, tone.accent_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"hover_pressed", &"Button", _box("button_hover_pressed", tone.bg_color, tone.accent_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"disabled", &"Button", _box("button_disabled", tone.surface_color, tone.line_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"focus", &"Button", _focus_box("button_focus", tone))
	t.set_color(&"font_color", &"Button", tone.fg_color)
	t.set_color(&"font_hover_color", &"Button", tone.fg_color)
	t.set_color(&"font_focus_color", &"Button", tone.fg_color)
	t.set_color(&"font_pressed_color", &"Button", tone.accent_color)
	t.set_color(&"font_hover_pressed_color", &"Button", tone.accent_color)
	t.set_color(&"font_disabled_color", &"Button", tone.muted_color)
	t.set_constant(&"h_separation", &"Button", ThemeTokens.SPACING)

	_variation(t, &"PrimaryButton", &"Button")
	var primary_hover: Color = tone.accent_color
	primary_hover.a = PRIMARY_HOVER_ALPHA
	t.set_stylebox(&"normal", &"PrimaryButton", _box("primary_normal", tone.raised_color, tone.accent_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"hover", &"PrimaryButton", _box("primary_hover", primary_hover, tone.accent_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"pressed", &"PrimaryButton", _box("primary_pressed", tone.accent_color, tone.accent_color, tone.border_width, tone, BUTTON_PAD))
	t.set_stylebox(&"hover_pressed", &"PrimaryButton", _box("primary_hover_pressed", tone.accent_color, tone.accent_color, tone.border_width, tone, BUTTON_PAD))
	t.set_color(&"font_color", &"PrimaryButton", tone.accent_color)
	t.set_color(&"font_hover_color", &"PrimaryButton", tone.accent_color)
	t.set_color(&"font_focus_color", &"PrimaryButton", tone.accent_color)
	t.set_color(&"font_pressed_color", &"PrimaryButton", tone.bg_color)
	t.set_color(&"font_hover_pressed_color", &"PrimaryButton", tone.bg_color)


static func _line_edit(t: Theme, tone: Tone) -> void:
	var selection: Color = tone.accent_color
	selection.a = SELECTION_ALPHA
	t.set_stylebox(&"normal", &"LineEdit", _box("field_normal", tone.bg_color, tone.line_color, tone.border_width, tone, FIELD_PAD))
	t.set_stylebox(&"read_only", &"LineEdit", _box("field_read_only", tone.surface_color, tone.line_color, tone.border_width, tone, FIELD_PAD))
	t.set_stylebox(&"focus", &"LineEdit", _focus_box("field_focus", tone))
	t.set_color(&"font_color", &"LineEdit", tone.fg_color)
	t.set_color(&"font_selected_color", &"LineEdit", tone.fg_color)
	t.set_color(&"font_uneditable_color", &"LineEdit", tone.muted_color)
	t.set_color(&"font_placeholder_color", &"LineEdit", tone.muted_color)
	t.set_color(&"caret_color", &"LineEdit", tone.accent_color)
	t.set_color(&"selection_color", &"LineEdit", selection)


static func _panels(t: Theme, tone: Tone) -> void:
	var pad := Vector2i(ThemeTokens.PADDING, ThemeTokens.PADDING)
	t.set_stylebox(&"panel", &"Panel", _box("panel", tone.surface_color, tone.line_color, tone.border_width, tone, Vector2i.ZERO))
	t.set_stylebox(&"panel", &"PanelContainer", _box("panel_container", tone.surface_color, tone.line_color, tone.border_width, tone, pad))

	_variation(t, &"CardPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"CardPanel", _box("card", tone.surface_color, tone.line_color, tone.border_width, tone, CARD_PAD))
	_variation(t, &"HudPanel", &"PanelContainer")
	var hud_bg: Color = tone.surface_color
	hud_bg.a = HUD_PANEL_ALPHA
	t.set_stylebox(&"panel", &"HudPanel", _box("hud", hud_bg, tone.line_color, tone.border_width, tone, HUD_PAD))
	_variation(t, &"ToastPanel", &"PanelContainer")
	var toast_bg: Color = tone.surface_color
	toast_bg.a = TOAST_PANEL_ALPHA
	t.set_stylebox(&"panel", &"ToastPanel", _stripe_box("toast", toast_bg, tone.accent_color, tone, TOAST_PAD))
	_variation(t, &"AlertPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"AlertPanel", _stripe_box("alert", tone.surface_color, ThemeTokens.GAMEPLAY_ALERT, tone, HUD_PAD))

	_variation(t, &"HudChip", &"PanelContainer")
	var chip_bg: Color = tone.surface_color
	chip_bg.a = HUD_CHIP_ALPHA
	var chip_line: Color = tone.line_color
	chip_line.a = HUD_CHIP_ALPHA
	t.set_stylebox(&"panel", &"HudChip", _box("hud_chip", chip_bg, chip_line, tone.border_width, tone, HUD_CHIP_PAD))
	# Uyarı merdiveni kutuları (US-013): boş kutu MUTED çerçeve (metin dışı öge ≥ 3:1; LINE zeminde
	# seçilmez), dolu kutu GAMEPLAY_ALERT dolgu. Boyut sahnede (≥ 22 px), iç boşluk yok.
	_variation(t, &"LadderStep", &"PanelContainer")
	t.set_stylebox(&"panel", &"LadderStep", _box("ladder_step", tone.bg_color, tone.muted_color, tone.focus_width, tone, Vector2i.ZERO))
	_variation(t, &"LadderStepActive", &"PanelContainer")
	t.set_stylebox(&"panel", &"LadderStepActive", _box("ladder_step_active", ThemeTokens.GAMEPLAY_ALERT, ThemeTokens.GAMEPLAY_ALERT, tone.focus_width, tone, Vector2i.ZERO))

	_variation(t, &"BackgroundPanel", &"Panel")
	t.set_stylebox(&"panel", &"BackgroundPanel", _box("background", tone.bg_color, tone.bg_color, 0, tone, Vector2i.ZERO))
	_variation(t, &"DimPanel", &"Panel")
	var dim: Color = tone.bg_color
	dim.a = DIM_ALPHA
	t.set_stylebox(&"panel", &"DimPanel", _box("dim", dim, dim, 0, tone, Vector2i.ZERO))


static func _misc(t: Theme, tone: Tone) -> void:
	t.set_constant(&"separation", &"VBoxContainer", ThemeTokens.SPACING)
	t.set_constant(&"separation", &"HBoxContainer", ThemeTokens.SPACING)
	_variation(t, &"LooseVBox", &"VBoxContainer")
	t.set_constant(&"separation", &"LooseVBox", ThemeTokens.SPACING * 2)
	_variation(t, &"LooseHBox", &"HBoxContainer")
	t.set_constant(&"separation", &"LooseHBox", ThemeTokens.SPACING * 2)
	t.set_constant(&"h_separation", &"GridContainer", ThemeTokens.SPACING + 4)
	t.set_constant(&"v_separation", &"GridContainer", ThemeTokens.SPACING)

	t.set_stylebox(&"background", &"ProgressBar", _box("progress_bg", tone.bg_color, tone.line_color, tone.border_width, tone, Vector2i.ZERO))
	var fill := _box("progress_fill", tone.accent_color, tone.accent_color, 0, tone, Vector2i.ZERO)
	fill.content_margin_top = PROGRESS_HEIGHT / 2.0
	fill.content_margin_bottom = PROGRESS_HEIGHT / 2.0
	t.set_stylebox(&"fill", &"ProgressBar", fill)
	t.set_color(&"font_color", &"ProgressBar", tone.fg_color)

	t.set_stylebox(&"separator", &"HSeparator", _line("separator", tone.line_color, tone.border_width))
	t.set_constant(&"separation", &"HSeparator", ThemeTokens.SPACING)
	_variation(t, &"AccentSeparator", &"HSeparator")
	t.set_stylebox(&"separator", &"AccentSeparator", _line("accent_separator", tone.accent_color, tone.focus_width))

	_variation(t, &"HudFrame", &"MarginContainer")
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		t.set_constant(side, &"HudFrame", ThemeTokens.SCREEN_MARGIN)


# --- yardımcılar (alt kaynak kimlikleri sabit: üretilen .tres farkı yalnız gerçek değişikliği gösterir) ---

static func _variation(t: Theme, variation: StringName, base: StringName) -> void:
	t.set_type_variation(variation, base)


static func _box(id: String, bg: Color, border: Color, border_width: int, tone: Tone, pad: Vector2i) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.resource_scene_unique_id = id
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(tone.corner_radius)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb


## Odak çerçevesi: dolgusuz, vurgu renginde kalın kenar (klavye/gamepad odağı her zaman görünür).
static func _focus_box(id: String, tone: Tone) -> StyleBoxFlat:
	var sb := _box(id, tone.accent_color, tone.accent_color, tone.focus_width, tone, Vector2i.ZERO)
	sb.draw_center = false
	sb.set_expand_margin_all(tone.focus_width)
	return sb


## Solunda renk şeridi olan panel (bildirim, hata).
static func _stripe_box(id: String, bg: Color, stripe: Color, tone: Tone, pad: Vector2i) -> StyleBoxFlat:
	var sb := _box(id, bg, stripe, 0, tone, pad)
	sb.border_width_left = STRIPE_WIDTH
	sb.content_margin_left = pad.x + STRIPE_WIDTH
	return sb


static func _line(id: String, color: Color, thickness: int) -> StyleBoxLine:
	var sb := StyleBoxLine.new()
	sb.resource_scene_unique_id = id
	sb.color = color
	sb.thickness = thickness
	return sb


static func _spaced_font(tone: Tone, spacing: int, id: String) -> FontVariation:
	var f := FontVariation.new()
	f.resource_scene_unique_id = id
	f.base_font = tone.font
	f.spacing_glyph = spacing
	return f
