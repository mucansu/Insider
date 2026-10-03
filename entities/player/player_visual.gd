class_name PlayerVisual
extends Node2D
## Oyuncunun görseli (US-004 AC1, US-014): prosedürel kukla (`Puppet`, KR-017) + ad etiketi + etkileşim rozeti.
## Yalnız ebeveyn Player'ın durumunu okur (hız, yön, kip, etkileşim, yuva, ad) ve kuklaya aktarır; mantığa,
## girdiye ve ağa dokunmaz (KR-003). Uzak kopyada Player bu durumu ara değerlenmiş tampondan üretir; kukla aynı
## yoldan canlanır (girdiden değil).
## Kip → kukla yürüyüşü eşlemesi burada (PlayerMotion.Mode → PuppetRig.Gait); kukla oyuncu betiklerini bilmez.
## Renkler: atkı oyuncu rengi ThemeTokens.PLAYER_COLORS[slot] (her tonda aynı), görünüm (başlık) yuvaya göre
## PuppetTuning.player_looks'tan (rol/loadout gelene kadar), etiket etkin tondan (mimari.md §6 görsel istisnası,
## S9). Ad etiketi ve işaretler kuklanın üstünde sabit bağlantı noktasında, animasyondan bağımsız (GDD §14.1
## kural 2). Ad etiketi oyuncunun adıdır: dinamik metin, otomatik çeviri kapalı; ad boşsa HUD ile aynı yedek,
## tr("HUD_PLAYER_UNNAMED").
## Görüş (US-011b AC4; GDD §6.5, §14.1): kukla baş ve gözleri `Player.look_dir`'i izler (gövde hareket yönünü);
## ekip arkadaşı her zaman tam çizilir, sisin üstünde (`z_index` = VisionRules.ABOVE_FOG_Z > FogLayer 50); yönlü
## kipte (`Player.is_directional_view()`) ekip arkadaşının çevresinde atkı renginde 32 px / 90° ince bakış yayı (α 0,25);
## yerel oyuncuda ve 360° kipte yay yok.

const LABEL_WIDTH := 160.0
const LABEL_GAP := 2.0
const LABEL_OUTLINE := 4
## Bu uzaklıktaki (px) en yakın ekip arkadaşına beklerken bakılabilir.
const FRIEND_RANGE := 260.0
## Ekip arkadaşının bakış yayı (GDD §6.5): yarıçap, açı, opaklık, kalınlık.
const LOOK_ARC_RADIUS := 32.0
const LOOK_ARC_DEG := 90.0
const LOOK_ARC_ALPHA := 0.25
const LOOK_ARC_WIDTH := 2.0
const LOOK_ARC_SEGMENTS := 12

var _player: Player = null
var _color: Color = Color.WHITE
var _arc_angle: float = INF

@onready var _puppet: Puppet = $Puppet
@onready var _label: Label = $NameLabel


## Oyuncunun hareket kipinin kukla karşılığı.
static func gait_for(mode: int) -> PuppetRig.Gait:
	match mode:
		PlayerMotion.Mode.SNEAK:
			return PuppetRig.Gait.SNEAK
		PlayerMotion.Mode.SPRINT:
			return PuppetRig.Gait.SPRINT
	return PuppetRig.Gait.WALK


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerVisual: ebeveyn Player değil")
		set_process(false)
		return
	z_index = VisionRules.ABOVE_FOG_Z
	var tone: Tone = ThemeTokens.tone()
	if tone.font != null:
		_label.add_theme_font_override(&"font", tone.font)
	_label.add_theme_font_size_override(&"font_size", tone.font_size_small)
	_label.add_theme_color_override(&"font_color", tone.fg_color)
	_label.add_theme_color_override(&"font_outline_color", tone.bg_color)
	_label.add_theme_constant_override(&"outline_size", LABEL_OUTLINE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(LABEL_WIDTH, _label.get_minimum_size().y)
	_label.position = Vector2(-LABEL_WIDTH * 0.5, _puppet.marker_anchor().y - LABEL_GAP - _label.size.y)
	_player.identity_changed.connect(_refresh_identity)
	_refresh_identity()


func _process(_delta: float) -> void:
	_puppet.set_state(_player.velocity, _player.facing, gait_for(_player.move_mode), _player.is_interacting())
	_puppet.set_look(_player.look_dir)
	var arc: float = _player.look_angle() if shows_look_arc() else INF
	if arc != _arc_angle:
		_arc_angle = arc
		queue_redraw()
	var friend: Node2D = _nearest_friend()
	_puppet.set_friend(friend.global_position if friend != null else Vector2.ZERO, friend != null)


## Tepki balonu ve tepkisi (ör. oyuncu fark edilince "!": sıçrama + göz büyümesi); NPC'ler de aynı API'yi
## kullanır (Puppet.react).
func react(kind: PuppetRig.Reaction) -> void:
	_puppet.react(kind)


func puppet() -> Puppet:
	return _puppet


## Bakış yayı çiziliyor mu: ekip arkadaşı (yerel değil) ve yönlü görüş kipi.
func shows_look_arc() -> bool:
	return _player != null and not _player.is_local() and _player.is_directional_view()


func _draw() -> void:
	if not is_finite(_arc_angle):
		return
	var half: float = deg_to_rad(LOOK_ARC_DEG) * 0.5
	draw_arc(Vector2.ZERO, LOOK_ARC_RADIUS, _arc_angle - half, _arc_angle + half, LOOK_ARC_SEGMENTS,
		Color(_color, LOOK_ARC_ALPHA), LOOK_ARC_WIDTH, true)


## Etkileşim göstergesi (kuklanın üstünde rozet) son çizim durumunda var mı; yerel ve uzak oyuncuda aynı yol
## (Player.is_interacting()).
func shows_interaction() -> bool:
	return _puppet.shows_interaction()


## Etkileşim rozetinin dolgu rengi (etkin tondan; S9).
func interaction_marker_color() -> Color:
	return _puppet.interaction_marker_color()


## Çizimde kullanılan oyuncu rengi (atkı ve rozet halkası).
func body_color() -> Color:
	return _color


## Ad etiketindeki metin.
func label_text() -> String:
	return _label.text


## Renk, görünüm ve ad Player'ın yuva/ad bilgisinden (Game.players(), S3).
func _refresh_identity() -> void:
	var colors: Array[Color] = ThemeTokens.PLAYER_COLORS
	_color = colors[posmod(_player.slot(), colors.size())]
	var looks: Array[PuppetLook] = _puppet.tuning.player_looks
	var look: PuppetLook = looks[posmod(_player.slot(), looks.size())] if not looks.is_empty() else null
	_puppet.configure(look, _color)
	var player_name: String = _player.display_name()
	if player_name.is_empty():
		player_name = tr(&"HUD_PLAYER_UNNAMED") % _player.peer_id()
	_label.text = player_name
	queue_redraw()


## Kardeş oyuncu kopyalarından en yakını (FRIEND_RANGE içinde); yalnız konum okunur.
func _nearest_friend() -> Node2D:
	var root: Node = _player.get_parent()
	if root == null:
		return null
	var best: Node2D = null
	var best_d: float = FRIEND_RANGE * FRIEND_RANGE
	for child: Node in root.get_children():
		var other: Player = child as Player
		if other == null or other == _player:
			continue
		var d: float = other.global_position.distance_squared_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best
