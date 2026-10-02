extends Node2D
## Kapı yer tutucu görseli (US-005): kapalıyken boşluğu kapatan kanat, açıkken menteşe çevresinde 90° dönmüş
## ince kanat. Yalnız ebeveyn Door'un durumunu okur (KR-003). Renkler etkin tondan (S9: ahşap = tezgâh rengi).

## Kanat boyu (1 karo) ve kalınlığı; menteşe -x ucunda.
const LENGTH := 32.0
const THICKNESS := 6.0
const OPEN_THICKNESS := 3.0
const OUTLINE_WIDTH := 1.0

var _door: Door = null
var _drawn: Variant = null


func _ready() -> void:
	_door = get_parent() as Door
	if _door == null:
		push_error("DoorVisual: ebeveyn Door değil")
		set_process(false)


func _process(_delta: float) -> void:
	if _drawn != _door.is_open:
		_drawn = _door.is_open
		queue_redraw()


func _draw() -> void:
	if _door == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var half: float = LENGTH * 0.5
	var rect: Rect2
	if _door.is_open:
		# Menteşe -x ucunda; açık kanat duvar boşluğunun kenarına (kasaya) yaslanır.
		rect = Rect2(Vector2(-half, -half), Vector2(OPEN_THICKNESS, LENGTH))
	else:
		rect = Rect2(Vector2(-half, -THICKNESS * 0.5), Vector2(LENGTH, THICKNESS))
	draw_rect(rect, tone.level_counter_color)
	draw_rect(rect, tone.level_counter_edge_color, false, OUTLINE_WIDTH)
