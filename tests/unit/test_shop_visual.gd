extends TestCase
## Shop product marks (US-046 lite): every product has a distinct shape, letter and fill in the active tone; a shelf mark is
## full-strength and carries its product; a taken mark dims and restores; product names and take prompts exist in the CSV.

const PRODUCTS: Array[StringName] = [&"bread", &"cola", &"water"]


func test_letters_and_sizes_distinct() -> void:
	var letters: Array[String] = []
	var sizes: Array[Vector2] = []
	for id: StringName in PRODUCTS:
		letters.append(ProductGlyph.letter_of(id))
		sizes.append(ProductGlyph.size_of(id))
		is_false(ProductGlyph.letter_of(id).is_empty(), "%s harfi var" % id)
	eq(_unique_count(letters), PRODUCTS.size(), "harfler ayırt edilir")
	eq(_unique_count(sizes), PRODUCTS.size(), "boyutlar ayırt edilir")


func test_fill_colours_distinct_in_active_tone() -> void:
	var tone: Tone = ThemeTokens.tone()
	var fills: Array[Color] = []
	for id: StringName in PRODUCTS:
		fills.append(ProductGlyph.fill_of(id, tone))
	eq(_unique_count(fills), PRODUCTS.size(), "renkler ayırt edilir (ton içinde)")


func test_unknown_product_has_no_letter() -> void:
	eq(ProductGlyph.letter_of(&"unknown_thing"), "", "bilinmeyen ürün harfsiz")


func test_shelf_mark_is_full_strength_with_product() -> void:
	var point := autofree(ShopItemPoint.new()) as ShopItemPoint
	point.setup(1, &"bread", Vector2.ZERO)
	var mark := point.get_node("Mark") as ProductMark
	eq(mark.product_id, &"bread", "raf işareti ürünü taşır")
	is_false(mark.faded, "raf işareti soluk değil (görünür)")
	eq(mark.modulate.a, 1.0, "tam opaklık")


func test_taken_mark_dims_and_restores() -> void:
	var mark := autofree(ProductMark.new()) as ProductMark
	mark.product_id = &"cola"
	mark.set_taken(true)
	is_true(mark.taken, "alındı işareti")
	near(mark.modulate.a, ProductMark.TAKEN_ALPHA, 0.001, "soluklaşır")
	mark.set_taken(false)
	eq(mark.modulate.a, 1.0, "geri gelir")


func test_product_names_and_prompts_have_text() -> void:
	for id: StringName in PRODUCTS:
		var key: String = "PRODUCT_NAME_%s" % String(id).to_upper()
		is_true(tr(StringName(key)) != key, "%s adı CSV'de" % id)
		var def: ShopProduct = ShopProduct.of(id)
		is_true(def != null, "%s tanımı var" % id)
		is_true(tr(StringName(def.take_key)) != def.take_key, "%s alma metni CSV'de" % id)


func _unique_count(values: Array) -> int:
	var seen: Dictionary = {}
	for v: Variant in values:
		seen[v] = true
	return seen.size()
