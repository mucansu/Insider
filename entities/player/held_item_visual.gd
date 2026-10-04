extends Node2D
## Product in the player's hand (US-045 v0 placeholder; KR-017 puppet holds it, art US-046): a small product glyph beside the body on the
## facing side (heavy damacana in front, held with both hands). Only reads the player's replicated hand (`Status/Hand`) and facing
## (KR-003); no logic or network. Missing hand (test dummy) = draws nothing.

const SIDE_PX := 11.0
const DROP_PX := 4.0
const FRONT_PX := 9.0

var _player: Node2D = null
var _hand: PlayerHand = null
var _drawn: Array = []


func _ready() -> void:
	_player = get_parent().get_parent() as Node2D if get_parent() != null else null
	_hand = _player.get_node_or_null(^"Status/Hand") as PlayerHand if _player != null else null
	if _hand == null:
		set_process(false)


func _process(_delta: float) -> void:
	var face: Variant = _player.get(&"facing")
	var side: float = signf((face as Vector2).x) if face is Vector2 and absf((face as Vector2).x) > 0.35 else 1.0
	var state: Array = [_hand.item, side]
	if state != _drawn:
		_drawn = state
		queue_redraw()


func _draw() -> void:
	if _hand == null or not _hand.is_holding():
		return
	var side: float = float(_drawn[1]) if _drawn.size() > 1 else 1.0
	var at := Vector2(side * SIDE_PX, DROP_PX)
	if _hand.is_heavy():
		at = Vector2(side * FRONT_PX * 0.5, FRONT_PX)
	ProductGlyph.draw(self, at, _hand.item)
