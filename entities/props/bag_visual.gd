extends Node2D
## Çanta yer tutucu görseli (US-012): nakit renginde küçük çuval (taşınırken biraz küçük), altında alma/devir
## ilerleme çizgisi. Yalnız ebeveyn Bag'in durumunu okur (KR-003). Renkler ThemeTokens'tan (S9; nakit rengi her
## tonda aynı: GAMEPLAY_CASH).

const SIZE := Vector2(14.0, 12.0)
const CARRIED_SCALE := 0.8
const NECK := Vector2(6.0, 3.0)
const OUTLINE_WIDTH := 1.5
const BAR_GAP := 4.0
const BAR_HEIGHT := 3.0

var _bag: Bag = null
var _drawn: Array = []


func _ready() -> void:
	_bag = get_parent() as Bag
	if _bag == null:
		push_error("BagVisual: ebeveyn Bag değil")
		set_process(false)


func _process(_delta: float) -> void:
	var state: Array = [_bag.is_carried(), snappedf(_bag.progress_ratio(), 0.01)]
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	if _bag == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var size: Vector2 = SIZE * (CARRIED_SCALE if _bag.is_carried() else 1.0)
	var rect := Rect2(-size * 0.5, size)
	var neck := Rect2(Vector2(-NECK.x * 0.5, rect.position.y - NECK.y), NECK)
	draw_rect(rect, ThemeTokens.GAMEPLAY_CASH)
	draw_rect(neck, ThemeTokens.GAMEPLAY_CASH)
	draw_rect(rect, tone.bg_color, false, OUTLINE_WIDTH)
	var ratio: float = _bag.progress_ratio()
	if ratio > 0.0:
		var bar := Rect2(rect.position + Vector2(0.0, rect.size.y + BAR_GAP), Vector2(rect.size.x * ratio, BAR_HEIGHT))
		draw_rect(bar, tone.fg_color)
