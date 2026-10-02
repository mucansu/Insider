class_name PlayerVisual
extends Node2D
## Oyuncunun yer tutucu görseli (US-004 AC1): oyuncu renginde daire, bakış yönü göstergesi, ad etiketi.
## Yalnız ebeveyn Player'ın durumunu okur (hız, yön, kip, etkileşim, yuva, ad); mantığa, girdiye ve ağa
## dokunmaz (KR-003). Faz 2'de prosedürel kukla (KR-017) bu düğümün yerini alır.
## Kip gösterimi: sızarken soluk dolgu, koşarken dış halka; etkileşimde gövde üstünde nokta (her peer'da, yerel
## ve uzak oyuncu için aynı: Player.is_interacting()).
## Renkler: oyuncu rengi ThemeTokens.PLAYER_COLORS[slot] (her tonda aynı), kenar/etiket etkin tondan
## (mimari.md §6 görsel istisnası, S9). Ad etiketi oyuncunun adıdır: dinamik metin, otomatik çeviri kapalı
## (ad bir çeviri anahtarına denk gelse de aynen görünür); ad boşsa HUD ile aynı yedek, tr("HUD_PLAYER_UNNAMED").

const RADIUS := 12.0
const OUTLINE_WIDTH := 1.5
## Yön göstergesi: gövde kenarından dışarı taşan üçgen.
const INDICATOR_LENGTH := 7.0
const INDICATOR_HALF_WIDTH := 5.0
const SNEAK_FILL_ALPHA := 0.45
const SPRINT_RING_GAP := 3.0
const SPRINT_RING_WIDTH := 1.5
const INTERACT_DOT_RADIUS := 3.0
## Bu hızın (px/sn) altı "duruyor" sayılır (koşu halkası yalnız hareket ederken).
const MOVING_SPEED := 5.0
const LABEL_WIDTH := 160.0
const LABEL_GAP := 2.0
const LABEL_OUTLINE := 4

var _player: Player = null
var _color: Color = Color.WHITE
## Son çizilen durum: değişmedikçe yeniden çizilmez.
var _drawn: Array = []

@onready var _label: Label = $NameLabel


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerVisual: ebeveyn Player değil")
		set_process(false)
		return
	var tone: Tone = ThemeTokens.tone()
	if tone.font != null:
		_label.add_theme_font_override(&"font", tone.font)
	_label.add_theme_font_size_override(&"font_size", tone.font_size_small)
	_label.add_theme_color_override(&"font_color", tone.fg_color)
	_label.add_theme_color_override(&"font_outline_color", tone.bg_color)
	_label.add_theme_constant_override(&"outline_size", LABEL_OUTLINE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(LABEL_WIDTH, _label.get_minimum_size().y)
	_label.position = Vector2(-LABEL_WIDTH * 0.5, -RADIUS - INDICATOR_LENGTH - LABEL_GAP - _label.size.y)
	_player.identity_changed.connect(_refresh_identity)
	_refresh_identity()


func _process(_delta: float) -> void:
	var moving: bool = _player.velocity.length() > MOVING_SPEED
	var state: Array = [_player.facing, _player.move_mode, moving, _player.is_interacting(), _color]
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var edge: Color = ThemeTokens.tone().bg_color
	var fill: Color = _color
	if _player.move_mode == PlayerMotion.Mode.SNEAK:
		fill.a = SNEAK_FILL_ALPHA
	draw_circle(Vector2.ZERO, RADIUS, fill)
	draw_circle(Vector2.ZERO, RADIUS, edge, false, OUTLINE_WIDTH, true)
	if _player.move_mode == PlayerMotion.Mode.SPRINT and _player.velocity.length() > MOVING_SPEED:
		draw_circle(Vector2.ZERO, RADIUS + SPRINT_RING_GAP, _color, false, SPRINT_RING_WIDTH, true)
	var dir: Vector2 = _player.facing.normalized() if _player.facing != Vector2.ZERO else Vector2.DOWN
	var side: Vector2 = dir.orthogonal() * INDICATOR_HALF_WIDTH
	var base: Vector2 = dir * (RADIUS - OUTLINE_WIDTH)
	var tip: Vector2 = dir * (RADIUS + INDICATOR_LENGTH)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), _color)
	if _player.is_interacting():
		draw_circle(Vector2.ZERO, INTERACT_DOT_RADIUS, interaction_marker_color())


## Etkileşim göstergesi (gövde üstünde nokta) son çizim isteğinde var mı; yerel ve uzak oyuncuda aynı yol
## (Player.is_interacting()).
func shows_interaction() -> bool:
	return _drawn.size() > 3 and bool(_drawn[3])


## Etkileşim noktasının rengi (etkin tondan; S9).
func interaction_marker_color() -> Color:
	return ThemeTokens.tone().bg_color


## Renk ve ad Player'ın yuva/ad bilgisinden (Game.players(), S3).
func _refresh_identity() -> void:
	var colors: Array[Color] = ThemeTokens.PLAYER_COLORS
	_color = colors[posmod(_player.slot(), colors.size())]
	var player_name: String = _player.display_name()
	if player_name.is_empty():
		player_name = tr(&"HUD_PLAYER_UNNAMED") % _player.peer_id()
	_label.text = player_name
	queue_redraw()


## Çizimde kullanılan oyuncu rengi.
func body_color() -> Color:
	return _color


## Ad etiketindeki metin.
func label_text() -> String:
	return _label.text
