extends TestCase
## IS-087: sahibin kapı davranışı (store_a; tohum 7: tezgâh ~31 sn, sonra ARKA ODA; nüfus kapalı; iç kapı D sahnedeki
## gibi kapalı). AC1 kendi kapı sesini duymaz (başkasınınkini duyar); AC2 iç kapıyı arkasından kapatır (NPC kapatma
## API'si `Door.host_close_by_npc`); AC3 arka kapı açıkken caddeden dolaşmaz (kısa yol: kapalı D'yi açar);
## AC4 DİNLE sırasında "?" (`is_listening`).

const FIXTURE := "res://tests/fixtures/store_a_backroom_first.tscn"
const DT := 1.0 / 60.0
## store_a iç kenarı: x ≤ 22 karo (doğu duvarı), y ≥ 4 karo (kuzey duvarı) — sahip binadan çıkmaz.
const INSIDE_MAX_X := 704.0
const INSIDE_MIN_Y := 128.0


func _door(stage: NpcStage, door_name: StringName) -> Door:
	return stage.level.props_root().get_node(NodePath(String(door_name))) as Door


func _hearing(o: StoreOwner) -> Hearing:
	return o.get_node_or_null(^"Hearing") as Hearing


## Sahibin arka oda görevine varmasını bekler (en çok `limit` sn); her adımda `probe`.
func _until_backroom(stage: NpcStage, limit: float, probe: Callable) -> bool:
	var o: StoreOwner = stage.owner()
	for i: int in roundi(limit / DT):
		stage.run(DT, probe)
		if o.agenda().task_name() == &"backroom" and o.agenda().has_arrived():
			return true
	return false


func test_owner_opens_backroom_door_closes_it_behind_and_ignores_own_door_noise() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(FIXTURE)
	var o: StoreOwner = stage.owner()
	var d: Door = _door(stage, &"BackroomDoor")
	is_false(d.is_open, "D kapalı başlar (geçici 'D açık' ayarı kaldırıldı)")
	var max_x: Array[float] = [0.0]
	var flips: Array[bool] = []
	var probe := func() -> void:
		max_x[0] = maxf(max_x[0], o.global_position.x)
		if flips.is_empty() or flips[-1] != d.is_open:
			flips.append(d.is_open)
	if not is_true(_until_backroom(stage, 60.0, probe), "sahip arka odaya vardı"):
		stage.leave()
		return
	stage.run(1.0, probe)
	var mover: NpcMover = o.brain().mover
	is_true(mover.doors_opened >= 1, "D'yi kendisi açtı")
	is_true(mover.doors_closed >= 1, "D'yi arkasından kapattı")
	is_false(d.is_open, "arka odadayken D kapalı (AC2)")
	eq(flips, [false, true, false], "D: kapalı → açık → kapalı")
	is_true(max_x[0] <= INSIDE_MAX_X, "binadan çıkmadı (en doğu x %.0f)" % max_x[0])
	eq(o.agenda().sequence.has(&"listen"), false, "kendi kapı sesine DİNLE yok (AC1)")
	var hearing: Hearing = _hearing(o)
	if is_true(hearing != null, "sahibin işitmesi var"):
		is_true(hearing.ignored_own_count() >= 2, "açma + kapama sesi kendi sesi sayıldı (%d)" % hearing.ignored_own_count())
	# Geri dönüş: görev bitince tezgâha D'den döner ve yine kapatır.
	for i: int in roundi(30.0 / DT):
		stage.run(DT, probe)
		if o.agenda().task_name() == &"counter" and o.agenda().has_arrived():
			break
	eq(o.agenda().task_name(), &"counter", "tezgâha döndü")
	stage.run(1.0, probe)
	is_false(d.is_open, "dönüşte de arkasından kapattı")
	is_true(mover.doors_closed >= 2, "iki geçiş, iki kapama")
	eq(o.agenda().sequence.has(&"listen"), false, "dönüşte de kendi sesine DİNLE yok")
	stage.leave()


func test_open_back_door_does_not_send_owner_around_the_street() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(FIXTURE, func(level: Level) -> void:
		(level.props_root().get_node(^"BackDoor") as Door).is_open = true)
	var o: StoreOwner = stage.owner()
	var min_y: Array[float] = [INF]
	var max_x: Array[float] = [0.0]
	var probe := func() -> void:
		min_y[0] = minf(min_y[0], o.global_position.y)
		max_x[0] = maxf(max_x[0], o.global_position.x)
	if not is_true(_until_backroom(stage, 60.0, probe), "sahip arka odaya vardı"):
		stage.leave()
		return
	is_true(o.brain().mover.shortcuts >= 1, "kapalı D'yi açan kısa yol seçildi (AC3)")
	is_true(max_x[0] <= INSIDE_MAX_X and min_y[0] >= INSIDE_MIN_Y,
		"caddeden/ara sokaktan dolaşmadı (x ≤ %.0f, y ≥ %.0f)" % [max_x[0], min_y[0]])
	stage.leave()


func test_shortcut_rule_needs_a_clear_saving() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(FIXTURE)
	var mover: NpcMover = stage.owner().brain().mover
	near(NpcMover.path_length(PackedVector2Array([Vector2.ZERO, Vector2(30, 40), Vector2(30, 140)])), 150.0, 0.001)
	# Tezgâhtan satış alanına açık yol kısa: kapalı kapı kısa yol olmaz.
	stage.run(0.5)
	mover.move_to(stage.marker(&"RestockSpot3"), 100.0)
	stage.run(1.0)
	eq(mover.shortcuts, 0, "satış alanına giderken kapı açılmaz")
	eq(mover.doors_opened, 0)
	stage.leave()


func test_foreign_door_noise_is_heard_and_listening_shows_question() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(FIXTURE)
	var o: StoreOwner = stage.owner()
	stage.run(1.0)
	var d: Door = _door(stage, &"BackroomDoor")
	var radius: float = NoiseProfile.load_default().radius_for(NoiseProfile.KIND_DOOR)
	var hearing: Hearing = _hearing(o)
	if not is_true(hearing != null, "sahibin işitmesi var"):
		stage.leave()
		return
	# Kendi eylemi sırasında aynı noktadaki kapı sesi duyulmaz.
	hearing.ignore_own(d.global_position, NoiseProfile.KIND_DOOR, func() -> bool:
		NoiseBus.emit_noise(d.global_position, radius, NoiseProfile.KIND_DOOR, 0)
		return true)
	stage.run(DT)
	eq(o.agenda().task_name(), &"counter", "kendi sesi: DİNLE yok")
	is_false(o.is_listening())
	eq(hearing.ignored_own_count(), 1)
	# Başkasının (oyuncu) kapı sesi aynen işler.
	NoiseBus.emit_noise(d.global_position, radius, NoiseProfile.KIND_DOOR, 2)
	stage.run(DT)
	eq(o.agenda().task_name(), &"listen", "oyuncunun kapı sesi: DİNLE")
	is_true(o.is_listening(), "DİNLE sırasında \"?\" (AC4)")
	eq(o.bubble, CivilianRules.Bubble.NONE, "ölçer göstergesi değişmez (\"?\" dinlemeden)")
	stage.leave()


func test_door_npc_close_api() -> void:
	var stage := NpcStage.new(self)
	await stage.enter(FIXTURE)
	var d: Door = _door(stage, &"BackroomDoor")
	var at: Vector2 = d.global_position
	is_false(d.host_close_by_npc(at + Vector2(0, 40)), "kapalı kapı: kapatılacak bir şey yok")
	d.is_open = true
	is_false(d.host_close_by_npc(at + Vector2(0, 200)), "menzil dışı (40 + 24 px) kapatamaz")
	is_true(d.is_open)
	is_true(d.host_close_by_npc(at + Vector2(0, 50)), "menzilde kapatır")
	is_false(d.is_open)
	# NPC'nin anlık kullanımı (host_use_by_npc) açık kapıyı yine kapatmaz (yalnız açar; US-008 t2).
	d.is_open = true
	var item: Interactable = d.get_node(^"Interactable") as Interactable
	stage.run(0.5)
	is_true(item.host_use_by_npc(at + Vector2(0, 30)))
	is_true(d.is_open, "host_use_by_npc açık kapıya dokunmaz")
	stage.leave()
