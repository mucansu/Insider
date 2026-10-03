extends Node2D
## Çanta yer tutucu görseli (US-012): nakit renginde küçük çuval (taşınırken biraz küçük), altında alma/devir
## ilerleme çizgisi. Yalnız ebeveyn Bag'in durumunu okur (KR-003). Renkler ThemeTokens'tan (S9; nakit rengi her
## tonda aynı: GAMEPLAY_CASH).
## Hafıza (US-011b AC5; GDD §6.5 madde 7): seviyede yerel oyuncunun sisi varsa çanta durumu (yerde nerede / alındı)
## yalnız çanta ya da son görüldüğü yer görülürken (görünen/çevresel karo) güncellenir; görülmezken son görülen
## durumda donar (VisionRules.Latch): yerde görülen çanta, gözden uzakta alınsa da o yer yeniden görülene dek yerde
## çizilir. Taşınırken görülen çanta taşıyanla (ekip arkadaşı, sis üstünde) çizilir. Hiç görülmeyen çanta çizilmez.
## Mantık etkilenmez. Sis yoksa canlı durum.

const SIZE := Vector2(14.0, 12.0)
const CARRIED_SCALE := 0.8
const NECK := Vector2(6.0, 3.0)
const OUTLINE_WIDTH := 1.5
const BAR_GAP := 4.0
const BAR_HEIGHT := 3.0

var _bag: Bag = null
var _drawn: Array = []
var _memory := VisionRules.Latch.new()


func _ready() -> void:
	_bag = get_parent() as Bag
	if _bag == null:
		push_error("BagVisual: ebeveyn Bag değil")
		set_process(false)


func _process(_delta: float) -> void:
	var live: Array = [_bag.global_position, _bag.is_carried()]
	var seen: bool = FogView.is_seen(self, _bag.global_position)
	if not seen and _memory.has_value() and not bool((_memory.value() as Array)[1]):
		seen = FogView.is_seen(self, (_memory.value() as Array)[0] as Vector2)  # son görülen yer görülüyor
	_memory.update(seen, live)
	var at: Vector2 = shown_position()
	z_index = VisionRules.ABOVE_FOG_Z if shown_carried() else 0
	var state: Array = [shown_carried(), snappedf(_bag.progress_ratio(), 0.01), to_local(at) if at.is_finite() else at]
	if state != _drawn:
		_drawn = state
		queue_redraw()


## Çizilen konum (global): yerde son görülen yer, taşınıyorsa canlı konum; çizilmiyorsa INF.
func shown_position() -> Vector2:
	if not _memory.has_value():
		return Vector2.INF
	var memory: Array = _memory.value()
	if bool(memory[1]):
		return _bag.global_position if _bag.is_carried() else Vector2.INF
	return memory[0] as Vector2


## Çizilen durum taşınıyor mu.
func shown_carried() -> bool:
	return _memory.has_value() and bool((_memory.value() as Array)[1]) and _bag.is_carried()


func _draw() -> void:
	if _bag == null:
		return
	var at: Vector2 = shown_position()
	if not at.is_finite():
		return
	var tone: Tone = ThemeTokens.tone()
	var size: Vector2 = SIZE * (CARRIED_SCALE if shown_carried() else 1.0)
	var rect := Rect2(to_local(at) - size * 0.5, size)
	var neck := Rect2(Vector2(-NECK.x * 0.5, rect.position.y - NECK.y), NECK)
	draw_rect(rect, ThemeTokens.GAMEPLAY_CASH)
	draw_rect(neck, ThemeTokens.GAMEPLAY_CASH)
	draw_rect(rect, tone.bg_color, false, OUTLINE_WIDTH)
	var ratio: float = _bag.progress_ratio()
	if ratio > 0.0:
		var bar := Rect2(rect.position + Vector2(0.0, rect.size.y + BAR_GAP), Vector2(rect.size.x * ratio, BAR_HEIGHT))
		draw_rect(bar, tone.fg_color)
