extends Node2D
## Kasa yer tutucu görseli (US-005): tezgâh üstünde çekmece; doluyken nakit rengi, boşken soluk; boşaltılırken
## altında ilerleme çizgisi (her peer'da çoğaltılan ilerlemeden). Yalnız ebeveyn Register'ın durumunu okur
## (KR-003). Renkler ThemeTokens'tan (S9; nakit rengi her tonda aynı: GAMEPLAY_CASH).

const SIZE := Vector2(18.0, 12.0)
const OUTLINE_WIDTH := 1.5
const BAR_GAP := 4.0
const BAR_HEIGHT := 3.0

var _register: Register = null
var _drawn: Array = []


func _ready() -> void:
	_register = get_parent() as Register
	if _register == null:
		push_error("RegisterVisual: ebeveyn Register değil")
		set_process(false)


func _process(_delta: float) -> void:
	var state: Array = [_register.emptied, snappedf(_register.progress_ratio(), 0.01)]
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	if _register == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(rect, tone.muted_color if _register.emptied else ThemeTokens.GAMEPLAY_CASH)
	draw_rect(rect, tone.bg_color, false, OUTLINE_WIDTH)
	var ratio: float = _register.progress_ratio()
	if ratio > 0.0:
		var bar := Rect2(rect.position + Vector2(0.0, rect.size.y + BAR_GAP), Vector2(rect.size.x * ratio, BAR_HEIGHT))
		draw_rect(bar, tone.fg_color)
