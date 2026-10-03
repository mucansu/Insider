extends TestCase
## IS-096 AC2 (KR-031, GDD §9.3 "Sahip okunurluğu"): owner task glyph - state/task -> glyph mapping, follows a replicated task change
## within a frame, hidden unless the owner's visual is FULL, attached to the real owner scene from replicated fields only.


## Fake owner: only the replicated fields the glyph reads.
class FakeOwner:
	extends Node2D
	var net_state: int = OwnerBrain.State.AGENDA
	var net_task: StringName = &"counter"


## Fake NpcVisual: visibility gate only.
class FakeVisual:
	extends Node2D
	var full: bool = true

	func is_fully_visible() -> bool:
		return full


func _rig() -> Array:
	var o := FakeOwner.new()
	var v := FakeVisual.new()
	o.add_child(v)
	autofree(o)
	tree().root.add_child(o)
	var g: TaskGlyph = TaskGlyph.attach(v)
	return [o, v, g]


func test_glyph_mapping_covers_tasks_and_states() -> void:
	var agenda: int = OwnerBrain.State.AGENDA
	eq(TaskGlyph.glyph_for(agenda, &"counter"), TaskGlyph.Glyph.COUNTER, "tezgâh")
	eq(TaskGlyph.glyph_for(agenda, &"customer"), TaskGlyph.Glyph.COUNTER, "müşteriye servis tezgâhta")
	eq(TaskGlyph.glyph_for(agenda, &"restock"), TaskGlyph.Glyph.SHELF, "raf")
	eq(TaskGlyph.glyph_for(agenda, &"phone"), TaskGlyph.Glyph.PHONE, "telefon")
	eq(TaskGlyph.glyph_for(agenda, &"backroom"), TaskGlyph.Glyph.BACKROOM, "arka oda")
	eq(TaskGlyph.glyph_for(agenda, &"sent"), TaskGlyph.Glyph.BACKROOM, "GÖNDERİLDİ arka odaya")
	eq(TaskGlyph.glyph_for(agenda, &"listen"), TaskGlyph.Glyph.LISTEN, "DİNLE")
	eq(TaskGlyph.glyph_for(OwnerBrain.State.DISCOVER, &""), TaskGlyph.Glyph.DISCOVER, "keşif")
	for task: StringName in [&"bell", &"talk", &"", &"unknown"]:
		eq(TaskGlyph.glyph_for(agenda, task), TaskGlyph.Glyph.NONE, "glifsiz: %s" % task)
	for state: int in [OwnerBrain.State.LOOK, OwnerBrain.State.QUESTION, OwnerBrain.State.SHOUT, OwnerBrain.State.CHASE,
			OwnerBrain.State.HOLD, OwnerBrain.State.STAGGER, OwnerBrain.State.SEARCH]:
		eq(TaskGlyph.glyph_for(state, &"counter"), TaskGlyph.Glyph.NONE, "tepki durumunda görev glifi yok (?/! çizilir)")


func test_every_owner_agenda_task_has_a_glyph() -> void:
	var tuning: OwnerTuning = load(StoreOwner.OWNER_TUNING_PATH) as OwnerTuning
	for task: AgendaTask in tuning.tasks:
		if task != null:
			has(TaskGlyph.TASK_GLYPHS, task.name, "ajanda görevinin glifi var: %s" % task.name)


func test_follows_task_change_within_a_frame() -> void:
	var rig: Array = _rig()
	var o: FakeOwner = rig[0]
	var g: TaskGlyph = rig[2]
	await tree().process_frame
	eq(g.glyph(), TaskGlyph.Glyph.COUNTER)
	o.net_task = &"phone"
	await tree().process_frame
	eq(g.glyph(), TaskGlyph.Glyph.PHONE, "bir karede (< 100 ms) izler")
	eq(g.get(&"_drawn"), TaskGlyph.Glyph.PHONE, "çizim de güncel")
	o.net_task = &"restock"
	await tree().process_frame
	eq(g.get(&"_drawn"), TaskGlyph.Glyph.SHELF)
	o.net_state = OwnerBrain.State.DISCOVER
	o.net_task = &""
	await tree().process_frame
	eq(g.get(&"_drawn"), TaskGlyph.Glyph.DISCOVER)


func test_hidden_unless_fully_visible() -> void:
	var rig: Array = _rig()
	var v: FakeVisual = rig[1]
	var g: TaskGlyph = rig[2]
	v.full = false
	await tree().process_frame
	eq(g.glyph(), TaskGlyph.Glyph.NONE, "silüet/hayalet: glif yok")
	eq(g.get(&"_drawn"), TaskGlyph.Glyph.NONE)
	v.full = true
	await tree().process_frame
	eq(g.get(&"_drawn"), TaskGlyph.Glyph.COUNTER, "tam görünür: glif")


func test_attach_is_idempotent() -> void:
	var rig: Array = _rig()
	var v: FakeVisual = rig[1]
	is_true(TaskGlyph.attach(v) == rig[2], "ikinci bağlama aynı düğümü döner")
	eq(v.get_child_count(), 1)


func test_real_owner_has_glyph_from_replicated_fields() -> void:
	var stage := NpcStage.new(self)
	await stage.enter()
	var o: StoreOwner = stage.owner()
	var g: TaskGlyph = o.get_node_or_null(^"Visual/TaskGlyph") as TaskGlyph
	if is_true(g != null, "sahibin görselinde glif düğümü var"):
		o.net_state = OwnerBrain.State.AGENDA
		o.net_task = &"backroom"
		await tree().physics_frame
		await tree().process_frame
		eq(g.glyph(), TaskGlyph.Glyph.BACKROOM, "net_task'tan türetilir")
	stage.leave()
