extends Node2D
## Kapı yer tutucu görseli (US-005): kapalıyken boşluğu kapatan kanat, açıkken menteşe çevresinde 90° dönmüş
## ince kanat. Yalnız ebeveyn Door'un durumunu okur (KR-003). Renkler etkin tondan (S9: ahşap = tezgâh rengi).
## Hafıza (US-011b AC5; GDD §6.5 madde 7): seviyede yerel oyuncunun sisi varsa kapı yalnız karosu görülürken
## (görünen ya da çevresel) güncellenir; görülmezken son görülen durumda (açık/kapalı) donar (VisionRules.Latch).
## Mantık ve çarpışma etkilenmez. Sis yoksa canlı durum.

## Kanat boyu (1 karo) ve kalınlığı; menteşe -x ucunda.
const LENGTH := 32.0
const THICKNESS := 6.0
const OPEN_THICKNESS := 3.0
const OUTLINE_WIDTH := 1.0

var _door: Door = null
var _drawn: Variant = null
var _memory := VisionRules.Latch.new()


func _ready() -> void:
	_door = get_parent() as Door
	if _door == null:
		push_error("DoorVisual: ebeveyn Door değil")
		set_process(false)


func _process(_delta: float) -> void:
	_memory.update(FogView.is_seen(self, _door.global_position), _door.is_open)
	if _drawn != shown_open():
		_drawn = shown_open()
		queue_redraw()


## Çizilen durum: görülürken canlı, görülmezken son görülen (hiç görülmediyse canlı).
func shown_open() -> bool:
	return bool(_memory.value()) if _memory.has_value() else _door.is_open


func _draw() -> void:
	if _door == null:
		return
	var tone: Tone = ThemeTokens.tone()
	var half: float = LENGTH * 0.5
	var rect: Rect2
	if shown_open():
		# Menteşe -x ucunda; açık kanat duvar boşluğunun kenarına (kasaya) yaslanır.
		rect = Rect2(Vector2(-half, -half), Vector2(OPEN_THICKNESS, LENGTH))
	else:
		rect = Rect2(Vector2(-half, -THICKNESS * 0.5), Vector2(LENGTH, THICKNESS))
	draw_rect(rect, tone.level_counter_color)
	draw_rect(rect, tone.level_counter_edge_color, false, OUTLINE_WIDTH)
