extends TestCase
## Ambience + music (US-047 AC3-AC4): AmbienceRules picks inside/outside from the tile under the player on store_a AND store_b (KR-037),
## thresholds keep the previous place, the crossfade takes 0.5-1 s; Soundscape mixes street vs room/murmur and cuts music on a fake Game's
## alert/shout/heist end. Headless: streams never start, so nothing leaks.

const STEP := 1.0 / 60.0
const LEVELS: Array[String] = ["res://levels/store_a.tscn", "res://levels/store_b.tscn"]


## Minimal S3 stand-in: the signals/functions Soundscape reads.
class FakeGame extends Node:
	signal session_event(kind: StringName, data: Dictionary)
	signal heist_finished(result: Dictionary)
	var level: int = 0

	func alert_level() -> int:
		return level


func _layout_of(path: String) -> LevelLayout:
	var level: Level = (load(path) as PackedScene).instantiate() as Level
	autofree(level)
	return level.layout()


func _char_of(kind: LevelLayout.Kind) -> String:
	for ch: String in LevelLayout.LEGEND:
		if LevelLayout.LEGEND[ch] == kind:
			return ch
	return "?"


## A cell of `kind` whose 4 neighbours are not a threshold (so the cell itself decides).
func _cell_of_kind(layout: LevelLayout, kind: LevelLayout.Kind) -> Vector2i:
	var size: Vector2i = layout.size_in_tiles()
	for y: int in size.y:
		for x: int in size.x:
			if layout.kind_at(Vector2i(x, y)) == kind:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_place_from_tile_kind() -> void:
	var out := AmbienceRules.Place.OUTSIDE
	var inn := AmbienceRules.Place.INSIDE
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.STREET), inn), out)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.SIDEWALK), inn), out)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.FLOOR), out), inn)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.BACKROOM), out), inn)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.SHELF), out), inn)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.DOOR), out), out, "eşik önceki yeri korur")
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.DOOR), inn), inn)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.WINDOW), inn), inn)
	eq(AmbienceRules.place_for(_char_of(LevelLayout.Kind.CRATE), out), out, "sokaktaki kasa yığını da eşik")
	eq(AmbienceRules.place_at(PackedStringArray(), Vector2.ZERO, inn), inn, "seviye yoksa önceki yer")
	eq(AmbienceRules.place_at(PackedStringArray([",."]), Vector2(-5.0, 5.0), inn), inn, "ızgara dışı önceki yer")
	eq(AmbienceRules.place_at(PackedStringArray([",."]), Vector2(40.0, 5.0), out), inn)


func test_inside_outside_on_both_stores() -> void:
	for path: String in LEVELS:
		var layout: LevelLayout = _layout_of(path)
		if not is_true(layout != null, "%s: Tiles yok" % path):
			continue
		var spawn_side: Vector2i = _cell_of_kind(layout, LevelLayout.Kind.SIDEWALK)
		var floor_cell: Vector2i = _cell_of_kind(layout, LevelLayout.Kind.FLOOR)
		var back_cell: Vector2i = _cell_of_kind(layout, LevelLayout.Kind.BACKROOM)
		is_true(spawn_side.x >= 0 and floor_cell.x >= 0 and back_cell.x >= 0, "%s: kaldırım/zemin/arka oda var" % path)
		var c := func(cell: Vector2i) -> Vector2: return LevelLayout.cell_center(cell)
		var rows: PackedStringArray = layout.rows
		eq(AmbienceRules.place_at(rows, c.call(spawn_side), AmbienceRules.Place.INSIDE), AmbienceRules.Place.OUTSIDE, "%s kaldırım" % path)
		eq(AmbienceRules.place_at(rows, c.call(floor_cell), AmbienceRules.Place.OUTSIDE), AmbienceRules.Place.INSIDE, "%s satış alanı" % path)
		eq(AmbienceRules.place_at(rows, c.call(back_cell), AmbienceRules.Place.OUTSIDE), AmbienceRules.Place.INSIDE, "%s arka oda" % path)
		var level: Level = layout.get_parent() as Level
		for i: int in level.spawn_count():
			eq(AmbienceRules.place_at(rows, level.spawn_position(i), AmbienceRules.Place.INSIDE), AmbienceRules.Place.OUTSIDE,
				"%s doğuş noktası %d dışarıda" % [path, i])


func test_crossfade_time_and_equal_power() -> void:
	is_true(AmbienceRules.CROSSFADE_TIME >= 0.5 and AmbienceRules.CROSSFADE_TIME <= 1.0, "AC3 0,5-1 sn")
	var w: float = 0.0
	var t: float = 0.0
	while w < 1.0 and t < 5.0:
		w = AmbienceRules.step_mix(w, AmbienceRules.Place.INSIDE, STEP)
		t += STEP
	near(t, AmbienceRules.CROSSFADE_TIME, 0.05, "geçiş süresi")
	near(AmbienceRules.gain(0.5) ** 2 * 2.0, 1.0, 0.0001, "eşit güç: ortada toplam güç sabit")
	eq(AmbienceRules.to_db(-24.0, 0.0), -80.0)
	near(AmbienceRules.to_db(-24.0, 1.0), -24.0, 0.0001)


func _scape(layout: LevelLayout, game: FakeGame, pos: Vector2) -> Array:
	var rows: PackedStringArray = layout.rows if layout != null else PackedStringArray()
	var holder := Node2D.new()
	holder.position = pos
	tree().root.add_child(holder)
	autofree(holder)
	tree().root.add_child(game)
	autofree(game)
	var scape := Soundscape.new()
	scape.game = game
	scape.rows_override = rows
	scape.force_active = true
	holder.add_child(scape)
	scape.start()
	return [holder, scape]


func test_soundscape_crossfades_street_and_room() -> void:
	var layout: LevelLayout = _layout_of(LEVELS[1])
	var outside_cell: Vector2i = _cell_of_kind(layout, LevelLayout.Kind.STREET)
	var inside_cell: Vector2i = _cell_of_kind(layout, LevelLayout.Kind.FLOOR)
	var pair: Array = _scape(layout, FakeGame.new(), LevelLayout.cell_center(outside_cell))
	var holder: Node2D = pair[0]
	var scape: Soundscape = pair[1]
	var catalog: SfxCatalog = SfxCatalog.load_default()
	scape.advance(STEP)
	eq(scape.place, AmbienceRules.Place.OUTSIDE)
	near(scape.volume_of(Soundscape.STREET), catalog.find_loop(&"amb_street").volume_db, 0.01, "dışarıda sokak tam")
	eq(scape.volume_of(Soundscape.ROOM), Soundscape.SILENT_DB, "dışarıda oda tonu yok (doğuşta geçiş yok)")
	holder.position = LevelLayout.cell_center(inside_cell)
	scape.advance(STEP)
	is_true(scape.volume_of(Soundscape.ROOM) > Soundscape.SILENT_DB, "içeri girince oda tonu yükselmeye başlar")
	is_true(scape.volume_of(Soundscape.STREET) > Soundscape.SILENT_DB, "çapraz geçişte sokak hemen kesilmez")
	for i: int in 60:
		scape.advance(STEP)
	near(scape.volume_of(Soundscape.ROOM), catalog.find_loop(&"amb_room").volume_db, 0.01, "içeride oda tonu tam")
	near(scape.volume_of(Soundscape.MURMUR), catalog.find_loop(&"amb_murmur").volume_db, 0.01, "içeride mırıltı")
	eq(scape.volume_of(Soundscape.STREET), Soundscape.SILENT_DB, "içeride sokak yok")
	eq(scape.player_of(Soundscape.STREET).bus, &"Ambience")
	eq(scape.player_of(Soundscape.MUSIC).bus, &"Music")
	is_false(scape.player_of(Soundscape.MUSIC).playing, "headless'ta akış başlamaz")


func test_soundscape_music_follows_game() -> void:
	var game := FakeGame.new()
	var pair: Array = _scape(null, game, Vector2.ZERO)
	var scape: Soundscape = pair[1]
	var full: float = SfxCatalog.load_default().find_loop(&"music_calm").volume_db
	for i: int in 240:
		scape.advance(STEP)
	near(scape.volume_of(Soundscape.MUSIC), full, 0.01, "sakin müzik çalar")
	game.session_event.emit(&"shout", {})
	for i: int in 18:
		scape.advance(STEP)
	eq(scape.volume_of(Soundscape.MUSIC), Soundscape.SILENT_DB, "bağırışta 0,3 sn içinde susar")
	for i: int in 420:
		scape.advance(STEP)
	near(scape.volume_of(Soundscape.MUSIC), full, 0.01, "sessizlikten sonra döner")
	game.level = 2
	for i: int in 18:
		scape.advance(STEP)
	eq(scape.volume_of(Soundscape.MUSIC), Soundscape.SILENT_DB, "kademe 2'de susar")
	game.level = 0
	game.heist_finished.emit({})
	for i: int in 900:
		scape.advance(STEP)
	eq(scape.volume_of(Soundscape.MUSIC), Soundscape.SILENT_DB, "iş sonunda müzik kapalı kalır")


func test_remote_copy_drops_soundscape() -> void:
	var holder := Node2D.new()
	tree().root.add_child(holder)
	autofree(holder)
	var scape := Soundscape.new()
	holder.add_child(scape)
	await tree().process_frame
	await tree().process_frame
	is_false(is_instance_valid(scape) and scape.is_inside_tree(), "yerel olmayan kopyada ambiyans/müzik yok")
