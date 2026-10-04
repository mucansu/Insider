class_name ProductMark
extends Node2D
## Placeholder product on the map (US-045 v0; art US-046): draws `product_id` with ProductGlyph while visible. Visual only (KR-003): its
## owner (shelf item point, counter) sets `product_id` / `visible` from replicated state; no logic or network.

@export var product_id: StringName = &"":
	set = _set_product
## Shelf stock hint (half alpha) vs. a real object (the damacana on the counter).
@export var faded: bool = false


func _set_product(value: StringName) -> void:
	if value == product_id:
		return
	product_id = value
	queue_redraw()


func _draw() -> void:
	ProductGlyph.draw(self, Vector2.ZERO, product_id, faded)
