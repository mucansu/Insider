extends TestCase
## US-011b store_a'da yerel görüş sisiyle (Level.attach_fog; gözlemci bir oyuncu kopyası) çizim kapıları:
## AC5 NPC görünürlük kapısı (tam / çevresel siluet / tutma → hayalet → gizli; işaretler yalnız tamken; siluet ve
## hayalet sis üstünde), kapı ve çanta görseli hafızada son görülen durumda donar ve görülünce güncellenir;
## AC6 ses halkası yalnız kaynak görülüyorsa ya da yerel oyuncu duyuyorsa (duvar ×0,5) çizilir; sahibin ajanda
## sesleri (telefon 160 / 3 sn, raf 96 / 2 sn, zil 160) NoiseBus'a girer, sahip kendi seslerine tepki vermez.
## Mantık etkilenmez (yalnız çizim). Ağ: tests/net/look_sync.json.

const STREET := Vector2(48, 528)
const STAFF_FRONT := Vector2(560, 400)
## Personel tarafı (19,13): sahibe 71 px, yakın halkanın (64) dışında, çevresel menzilde (192).
const STAFF_SIDE := Vector2(624, 432)
const BACKROOM := Vector2(496, 176)
## Arka kapının (20,3) hemen içi (20,5).
const BACK_DOOR_VIEW := Vector2(656, 176)
## Kaldırım (19,15): kuzeyinde düz duvar (19,14), içerisi (19,13) 64 px, (19,12) 96 px.
const SIDEWALK := Vector2(624, 496)
const RING := "res://entities/fx/noise_ring.tscn"


func _stage() -> NpcStage:
	return NpcStage.new(self)


func _frames(n: int) -> void:
	for i: int in n:
		await tree().physics_frame


func _owner_visual(stage: NpcStage) -> NpcVisual:
	return stage.owner().get_node("Visual") as NpcVisual


func _observe(stage: NpcStage, at: Vector2) -> FogLayer:
	var me: Player = stage.player(2, at)
	return stage.level.attach_fog(me)


func _move(fog: FogLayer, to: Vector2) -> void:
	(fog.observer() as Node2D).global_position = to
	fog.update_now()
	await _frames(2)


# --- AC5: NPC görünürlük kapısı ---

func test_owner_hidden_until_seen_then_holds_ghosts_and_hides() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var visual: NpcVisual = _owner_visual(stage)
	var fog: FogLayer = _observe(stage, STREET)
	await _frames(110)  # sis kurulmadan (sahipsiz) tam çizilmişti: tutma + hayalet süresi dolar
	eq(visual.sight_mode(), SightGate.Mode.HIDDEN, "duvar arkasındaki sahip çizilmez")
	is_false(visual.is_fully_visible())
	is_true(visual.is_in_group(VisionRules.NPC_VISUAL_GROUP))
	await _move(fog, STAFF_FRONT)
	eq(visual.sight_mode(), SightGate.Mode.FULL, "görünen karo ∧ görüş hattı → tam")
	is_true(visual.is_fully_visible())
	eq(visual.z_index, 0, "tam çizim seviyede (sis görünen karoda yok)")
	var seen_at: Vector2 = stage.owner().global_position
	await _move(fog, STREET)
	eq(visual.sight_mode(), SightGate.Mode.FULL, "0,2 sn tutma")
	await _frames(18)
	eq(visual.sight_mode(), SightGate.Mode.GHOST, "sonra hayalet")
	is_false(visual.is_fully_visible(), "hayalette işaret yok")
	near(visual.gate().ghost_position(), seen_at, 0.5, "son görülen konumda")
	is_true(visual.z_index > FogLayer.Z_INDEX, "hayalet sis üstünde")
	await _frames(100)
	eq(visual.sight_mode(), SightGate.Mode.HIDDEN, "1,5 sn sonra gizli")
	is_true(stage.owner().visible, "mantık/düğüm etkilenmez (yalnız çizim)")
	stage.leave()


func test_directional_peripheral_silhouette() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var visual: NpcVisual = _owner_visual(stage)
	var fog: FogLayer = _observe(stage, STAFF_SIDE)
	fog.set_mode(VisionGrid.Mode.DIRECTIONAL)
	var to_owner: Vector2 = stage.owner().global_position - STAFF_SIDE
	fog.set_look_dir(to_owner.rotated(deg_to_rad(70.0)))  # sahip 70°: net koninin (45°) dışı, çevresel (90°) içi
	await _move(fog, STAFF_SIDE)
	eq(fog.state_at_position(stage.owner().global_position), VisionGrid.State.PERIPHERAL, "fikstür: çevresel karo")
	eq(visual.sight_mode(), SightGate.Mode.SILHOUETTE, "çevresel bölgede soluk siluet")
	is_false(visual.is_fully_visible(), "balon/koni/yay yok")
	near(visual.gate().alpha(), 0.5, 0.0001)
	is_true(visual.z_index > FogLayer.Z_INDEX)
	fog.set_look_dir(to_owner)
	await _move(fog, STAFF_SIDE)
	eq(visual.sight_mode(), SightGate.Mode.FULL, "net konide tam")
	stage.leave()


func test_no_fog_everything_visible() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	await _frames(3)
	eq(_owner_visual(stage).sight_mode(), SightGate.Mode.FULL, "sis yokken (sahipsiz test) her şey görünür")
	stage.leave()


# --- AC5: prop hafızası ---

func test_door_visual_freezes_in_memory() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var door: Door = stage.level.props_root().get_node("BackDoor") as Door
	var visual: Node = door.get_node("Visual")
	var fog: FogLayer = _observe(stage, BACK_DOOR_VIEW)
	await _move(fog, BACK_DOOR_VIEW)
	is_true(FogView.is_seen(visual, door.global_position), "fikstür: arka kapı arka odadan görünür")
	is_false(bool(visual.call(&"shown_open")))
	await _move(fog, STREET)
	is_false(FogView.is_seen(visual, door.global_position))
	door.is_open = true
	await tree().process_frame
	is_false(bool(visual.call(&"shown_open")), "görülmezken son görülen (kapalı) durumda donar")
	await _move(fog, BACK_DOOR_VIEW)
	await tree().process_frame
	is_true(bool(visual.call(&"shown_open")), "görülünce güncellenir")
	stage.leave()


func test_bag_visual_keeps_last_seen_floor_spot() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var bag: Bag = stage.level.props_root().get_node("Bag") as Bag
	var visual: Node = bag.get_node("Visual")
	var spot: Vector2 = bag.global_position
	var fog: FogLayer = _observe(stage, BACKROOM)
	await _move(fog, BACKROOM)
	await tree().process_frame
	eq(visual.call(&"shown_position"), spot, "görülen çanta yerinde")
	await _move(fog, STREET)
	stage.player(3, Vector2(300, 300))
	bag.carrier = 3
	await tree().process_frame
	is_true(bag.is_carried())
	eq(visual.call(&"shown_position"), spot, "gözden uzakta alınan çanta hafızada yerde")
	is_false(bool(visual.call(&"shown_carried")))
	await _move(fog, BACKROOM)
	await tree().process_frame
	is_true(bool(visual.call(&"shown_carried")), "eski yer görülünce güncellenir: alındı")
	is_true((visual as CanvasItem).z_index > FogLayer.Z_INDEX, "taşınan çanta taşıyanla sis üstünde")
	stage.leave()


# --- AC6: ses halkası ---

func _ring(stage: NpcStage, at: Vector2, radius: float) -> NoiseRing:
	var ring: NoiseRing = (load(RING) as PackedScene).instantiate() as NoiseRing
	autofree(ring)
	stage.level.add_child(ring)
	ring.global_position = at
	ring.setup(radius)
	return ring


func test_noise_ring_only_when_seen_or_heard() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var fog: FogLayer = _observe(stage, SIDEWALK)
	await _move(fog, SIDEWALK)
	var seen: NoiseRing = _ring(stage, SIDEWALK + Vector2(96, 0), 120.0)
	is_true(seen.is_shown() and seen.visible, "kaynak görünen karoda")
	var heard: NoiseRing = _ring(stage, Vector2(624, 432), 160.0)
	is_false(FogView.is_tile_seen(fog, Vector2(624, 432)), "fikstür: duvar arkası görünmez")
	is_true(heard.is_shown(), "duvar arkası 64 px ≤ 160 × 0,5: duyulur")
	is_true(heard.z_index > FogLayer.Z_INDEX, "duyulan halka sis üstünde")
	var muffled: NoiseRing = _ring(stage, Vector2(624, 400), 160.0)
	is_false(muffled.is_shown() or muffled.visible, "duvar arkası 96 px > 80: çizilmez")
	var far: NoiseRing = _ring(stage, Vector2(592, 176), 160.0)
	is_false(far.is_shown(), "uzak arka oda: çizilmez")
	stage.leave()


func test_noise_ring_without_fog_always_shown() -> void:
	var stage: NpcStage = _stage()
	await stage.enter()
	var ring: NoiseRing = _ring(stage, Vector2(592, 176), 10.0)
	is_true(ring.is_shown() and ring.visible)
	eq(ring.z_index, NoiseRing.Z_INDEX)
	stage.leave()


# --- AC6: sahibin ajanda sesleri ---

func test_agenda_task_noise_cadence() -> void:
	var phone := AgendaTask.new()
	phone.name = &"phone"
	phone.marker = &"P"
	phone.min_sec = 20.0
	phone.max_sec = 20.0
	phone.home = true
	phone.noise_kind = NoiseProfile.KIND_PHONE
	phone.noise_interval_sec = 3.0
	var agenda: Agenda = autofree(Agenda.new()) as Agenda
	var tasks: Array[AgendaTask] = [phone]
	agenda.setup(tasks, 1, func(_m: StringName) -> Array[Vector2]: return [Vector2.ZERO])
	var times: Array[float] = []
	var t: float = 0.0
	for i: int in 540:
		var at_goal: bool = t >= 1.0  # 1 sn yürür, sonra varır
		agenda.step(1.0 / 60.0, at_goal)
		var kind: StringName = agenda.take_noise(1.0 / 60.0)
		t += 1.0 / 60.0
		if not kind.is_empty():
			eq(kind, &"phone")
			times.append(t)
	eq(times.size(), 2, "varıştan 3 ve 6 sn sonra (9 sn içinde)")
	if times.size() == 2:
		near(times[0], 4.0, 0.05, "ilk ses varıştan bir aralık sonra")
		near(times[1] - times[0], 3.0, 0.05, "3 sn'de bir")
	agenda.interrupt(Agenda.Interrupt.BELL, 5.0)
	for i: int in 300:
		agenda.step(1.0 / 60.0, true)
		eq(agenda.take_noise(1.0 / 60.0), &"", "kesmede ses yok")


func test_owner_tuning_and_profile_agenda_sounds() -> void:
	var tuning: OwnerTuning = load("res://data/npc/owner_tuning.tres") as OwnerTuning
	var kinds: Dictionary = {}
	for task: AgendaTask in tuning.tasks:
		kinds[task.name] = [task.noise_kind, task.noise_interval_sec]
	eq(kinds[&"phone"], [&"phone", 3.0], "telefon 3 sn'de bir")
	eq(kinds[&"restock"], [&"shelf", 2.0], "raf düzeltme 2 sn'de bir")
	eq(kinds[&"counter"], [&"", 0.0])
	var profile: NoiseProfile = NoiseProfile.load_default()
	eq(profile.radius_for(NoiseProfile.KIND_PHONE), 160.0)
	eq(profile.radius_for(NoiseProfile.KIND_SHELF), 96.0)
	eq(profile.radius_for(NoiseProfile.KIND_BELL), 160.0)
	eq(profile.radius_for(NoiseProfile.KIND_DOOR), 160.0, "kapılar 160 (US-009)")
	is_false(NoiseProfile.is_movement_kind(NoiseProfile.KIND_PHONE), "istemci ajanda sesi üretemez")


var _shown: Array = []


func _on_noise_shown(pos: Vector2, radius: float, kind: StringName) -> void:
	_shown.append([kind, radius, pos])


func test_owner_phone_and_bell_noises_reach_noise_bus() -> void:
	var stage: NpcStage = _stage()
	await stage.enter(NpcStage.STORE, func(level: Level) -> void:
		for child: Node in level.npcs_root().get_children():
			if child is StoreOwner:
				var o: StoreOwner = child as StoreOwner
				var tuning: OwnerTuning = (load(StoreOwner.OWNER_TUNING_PATH) as OwnerTuning).duplicate(true) as OwnerTuning
				for task: AgendaTask in tuning.tasks:
					task.home = task.name == &"phone"
				o.owner_tuning = tuning)
	_shown.clear()
	NoiseBus.noise_shown.connect(_on_noise_shown)
	var o: StoreOwner = stage.owner()
	stage.run(9.0)
	var phones: Array = _shown.filter(func(row: Array) -> bool: return row[0] == &"phone")
	is_true(phones.size() >= 2, "telefonda 3 sn'de bir ses, gelen %d" % phones.size())
	if not phones.is_empty():
		eq(phones[0][1], 160.0)
		near(phones[0][2] as Vector2, o.global_position, 8.0, "sahibin konumunda")
	eq(o.agenda().task_name(), &"phone", "sahip kendi telefon sesine tepki vermez (dinle kesmesi yok)")
	eq(int(o.brain().agenda_noises.get(&"phone", 0)), phones.size())
	# Kapı zili: oyuncu ön kapıdan içeri girer → zil sesi kapıda (160).
	_shown.clear()
	var p: Player = stage.player(2, Vector2(368, 496))
	stage.run(0.1)
	p.position = Vector2(368, 432)
	stage.run(0.1)
	var bells: Array = _shown.filter(func(row: Array) -> bool: return row[0] == &"bell")
	eq(bells.size(), 1, "ön kapı geçişinde bir zil sesi")
	if bells.size() == 1:
		eq(bells[0][1], 160.0)
		near(bells[0][2] as Vector2, stage.marker(&"FrontDoor"), 48.0, "zil kapıda")
	NoiseBus.noise_shown.disconnect(_on_noise_shown)
	stage.leave()
