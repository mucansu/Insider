class_name ProductMark
extends Node2D
## Placeholder product on the map (US-045 v0; art US-046): draws `product_id` with ProductGlyph while visible. Visual only (KR-003): its
## owner (shelf item point, counter) sets `product_id` / `visible` / `set_taken` from replicated state; no logic or network.

## Alpha of a taken shelf product (the mark dims; the glyph stays readable as "was here").
const TAKEN_ALPHA := 0.3

@export var product_id: StringName = &"":
	set = _set_product
## Shelf stock hint (half alpha) vs. a real object (the damacana on the counter).
@export var faded: bool = false
var taken: bool = false


func _set_product(value: StringName) -> void:
	if value == product_id:
		return
	product_id = value
	queue_redraw()


## Dims the mark once its product is gone from the owner's hand/shelf; the owner decides (no network here).
func set_taken(value: bool) -> void:
	taken = value
	modulate.a = TAKEN_ALPHA if taken else 1.0


func _draw() -> void:
	ProductGlyph.draw(self, Vector2.ZERO, product_id, faded)
