extends TestCase
## US-049 in-job "Start" (KR-044): a heist level opens in prep (interactions except the customer door locked with the "prep" reject and
## the crew-gathering prompt; no Tracker observation, no suspicion, no alert step), the host's E on the start point (the van, KR-045) starts the
## job (phase active + `heist_started`), "Again" opens in prep again; automation starts at once unless `--heist-prep` (Args.heist_prep).
## HUD: crew-gathering prompt text and the host's 30 s reminder (fakes). Multi-process: tests/net/heist_start.json, heist_prep_owner.json.

const Fakes := preload("res://tests/unit/test_ui_fakes.gd")
const HUD_SCENE := preload("res://ui/hud.tscn")
const STORE := "res://levels/store_a.tscn"
const PLAYER := "res://entities/player/player.tscn"
## Staff side next to the register, inside the owner's cone (test_heist_game.gd STAFF).
const STAFF := Vector2(588, 368)
const DT := 1.0 / 60.0

var _previous_scene: PackedScene = null
var _previous_prep: bool = false


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _start(prep: bool) -> Player:
	_previous_scene = Game.player_scene
	_previous_prep = Args.heist_prep
	Args.heist_prep = prep
	Game.player_scene = load(PLAYER) as PackedScene
	if not eq(Net.host(free_udp_port()), OK):
		return null
	Game.start_level(STORE)
	return Game.local_player() as Player


func _stop() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.player_scene = _previous_scene
	Args.heist_prep = _previous_prep


func _frames(n: int = 3) -> void:
	for i: int in n:
		await tree().physics_frame


func _item(prop_path: String) -> Interactable:
	var level: Node = Game.current_level()
	return level.get_node_or_null(NodePath(prop_path)) as Interactable if level != null else null


func _heist_dump() -> Dictionary:
	return Game.call(&"_heist_dump") as Dictionary


func _events_of(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in Game.collect_dump()["events"] as Array:
		if str(e.get("kind", "")) == kind:
			out.append(e)
	return out


# --- rules ---

func test_rules_prep_lock_and_names() -> void:
	is_true(HeistRules.prep_locks(&"Register", &"HeistStart"), "kasa kilitli")
	is_true(HeistRules.prep_locks(&"BackDoor", &"HeistStart"), "arka kapı kilitli")
	is_true(HeistRules.prep_locks(&"BackroomDoor", &"HeistStart"), "iç kapı kilitli")
	is_true(HeistRules.prep_locks(&"", &"HeistStart"), "sahipsiz bileşen kilitli")
	is_false(HeistRules.prep_locks(&"FrontDoor", &"HeistStart"), "müşteri kapısı açık")
	is_false(HeistRules.prep_locks(&"HeistStart", &"HeistStart"), "başlangıç noktası açık")
	is_true(HeistRules.is_phase(HeistRules.PHASE_PREP))
	is_true(HeistRules.is_phase(HeistRules.PHASE_ACTIVE))
	is_false(HeistRules.is_phase(7), "bilinmeyen evre")
	is_false(HeistRules.is_phase("1"), "tür denetimi")
	eq(HeistRules.phase_name(false, HeistRules.PHASE_ACTIVE, false), "none")
	eq(HeistRules.phase_name(true, HeistRules.PHASE_PREP, false), "prep")
	eq(HeistRules.phase_name(true, HeistRules.PHASE_ACTIVE, false), "active")
	eq(HeistRules.phase_name(true, HeistRules.PHASE_ACTIVE, true), "finished")


func test_rules_reminder_period() -> void:
	is_false(HeistRules.prep_reminder_due(29.9, 0, 30.0))
	is_true(HeistRules.prep_reminder_due(30.0, 0, 30.0), "ilk hatırlatma 30 sn")
	is_false(HeistRules.prep_reminder_due(45.0, 1, 30.0), "biri gösterildi: sonraki 60 sn")
	is_true(HeistRules.prep_reminder_due(60.0, 1, 30.0))
	is_false(HeistRules.prep_reminder_due(100.0, 0, 0.0), "periyot 0: kapalı")


func test_hud_constants_match_rules() -> void:
	eq(Hud.PREP_PROMPT_KEY, HeistRules.PREP_PROMPT_KEY, "ui core'a bağlanmaz (§6): aynı değer")
	eq(Hud.PREP_REMINDER_S, HeistRules.PREP_REMINDER_S)


func test_args_heist_prep_flag() -> void:
	var saved: PackedStringArray = OS.get_cmdline_user_args()
	Args.parse(PackedStringArray(["--heist-prep", "--host"]))
	is_true(Args.heist_prep)
	is_false(Args.unknown.has("--heist-prep"), "tanınan bayrak unknown'a düşmez")
	Args.parse(PackedStringArray(["--host"]))
	is_false(Args.heist_prep, "varsayılan kapalı")
	Args.parse(saved)


# --- Game (host, single process) ---

func test_automation_starts_at_once() -> void:
	var me: Player = _start(false)
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	is_false(Game.heist_in_prep(), "otomasyon (betik ana döngüsü): iş doğrudan başlar")
	eq(Game.heist_prep_s(), -1.0)
	eq(_heist_dump()["phase"], "active")
	eq(_heist_dump()["started_at_s"], 0.0, "seviye yüklenirken başladı")
	eq(_events_of("heist_started").size(), 0, "sessiz otomatik başlangıç: olay geçmişi değişmez")
	var start: Interactable = _item("HeistStart/Trigger")
	if is_true(start != null, "başlangıç noktası her heist seviyesinde var"):
		is_false(start.offered_to(1), "iş başladı: Başla istemi yok")
	is_false(Game.request_heist_start(), "başlamış iş yeniden başlamaz")
	await _stop()


func test_prep_locks_job_interactions() -> void:
	var me: Player = _start(true)
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	is_true(Game.heist_in_prep(), "--heist-prep: hazırlık")
	var dump: Dictionary = _heist_dump()
	eq(dump["phase"], "prep")
	eq(dump["active"], false, "hazırlıkta iş koşmuyor")
	eq(dump["started_at_s"], -1.0)
	var register: Interactable = _item("Props/Register/Interactable")
	var front: Interactable = _item("Props/FrontDoor/Interactable")
	var back: Interactable = _item("Props/BackDoor/Interactable")
	if not is_true(register != null and front != null and back != null, "seviye bileşenleri"):
		await _stop()
		return
	is_true(Game.heist_prep_locks(register), "kasa kilitli")
	is_true(Game.heist_prep_locks(back), "arka kapı kilitli")
	is_false(Game.heist_prep_locks(front), "ön kapı açık (müşteri gibi gezilir)")
	eq(register.prompt_key(), HeistRules.PREP_PROMPT_KEY, "istem: ekip toplanıyor")
	eq(front.prompt_key(), front.action_key, "ön kapı istemi değişmez")
	me.position = STAFF
	await _frames()
	register.host_start(1, 1)
	eq(register.busy_by, 0, "host hazırlıkta kasayı reddeder")
	eq(int((register.stats()["rejected"] as Dictionary).get("prep", 0)), 1, "red nedeni prep")
	eq(Game.abort_left(), -1.0, "hazırlıkta çekilme sayacı yok")
	await _stop()


func test_no_penalty_in_prep_then_start() -> void:
	var me: Player = _start(true)
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	var owner_node: Node = Game.current_level().get_node_or_null(^"NPCs/Owner")
	var meter: Suspicion = owner_node.call(&"suspicion") as Suspicion if owner_node != null else null
	if not is_true(meter != null, "sahip şüphe bileşeni"):
		await _stop()
		return
	me.position = STAFF
	await _frames(90)
	eq(meter.value_of(1), 0.0, "hazırlıkta şüphe dolmaz (sahibin önünde personel tarafı)")
	eq(Game.alert_level(), 0, "uyarı merdiveni adım atmaz")
	eq(Game.cover_state(), 1, "hazırlıkta örtü izlenmez")
	eq(_heist_dump()["elapsed"], 0.0, "iş süresi hazırlıkta saymaz")
	# Start: host E on the start point (the van, KR-045).
	var start: Interactable = _item("HeistStart/Trigger")
	if not is_true(start != null, "başlangıç noktası"):
		await _stop()
		return
	is_true(start.offered_to(1), "Başla host'a sunulur")
	is_false(start.offered_to(2), "istemciye sunulmaz")
	eq(start.prompt_key(), "INTERACT_HEIST_START")
	me.global_position = (Game.current_level().get_node(^"HeistStart") as Node2D).global_position
	await _frames()
	start.host_start(2, 1)
	is_true(Game.heist_in_prep(), "istemci (2) başlatamaz")
	start.host_start(1, 1)
	await _frames()
	is_false(Game.heist_in_prep(), "host E: iş başladı")
	var dump: Dictionary = _heist_dump()
	eq(dump["phase"], "active")
	is_true(float(dump["started_at_s"]) > 1.0, "başlama anı hazırlıktan sonra: %s" % dump["started_at_s"])
	eq(float(dump["prep_s"]), float(dump["started_at_s"]), "hazırlık süresi = başlama anı")
	eq(_events_of("heist_started").size(), 1, "heist_started olayı")
	is_false(start.offered_to(1), "başladıktan sonra Başla yok")
	# Rules live now: the owner sees the player behind the counter.
	me.position = STAFF
	await _frames(30)
	is_true(meter.value_of(1) > 0.0, "iş başladı: şüphe dolar")
	eq(Game.cover_state(), 0, "iş başladı: örtü bozulur")
	is_true(float(_heist_dump()["elapsed"]) > 0.0, "iş süresi başlamadan sonra sayar")
	var register: Interactable = _item("Props/Register/Interactable")
	is_false(Game.heist_prep_locks(register), "kasa artık açık")
	eq(register.prompt_key(), register.action_key)
	await _stop()


func test_restart_opens_in_prep_again() -> void:
	var me: Player = _start(true)
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	is_true(Game.request_heist_start())
	is_false(Game.heist_in_prep())
	Game.request_restart()
	await _frames()
	is_true(Game.heist_in_prep(), "Bir daha: yine hazırlık")
	eq(_heist_dump()["started_at_s"], -1.0)
	is_true(_item("HeistStart/Trigger") != null, "yeni seviyede başlangıç noktası")
	await _stop()


# --- HUD ---

func _open_hud() -> Array:
	var pair: Array = Fakes.make_pair(self)
	var viewport: SubViewport = autofree(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1280, 720)
	tree().root.add_child(viewport)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	hud.net = pair[0]
	hud.game = pair[1]
	hud.menu_override = func(_error_key: StringName) -> void: pass
	hud.warning_override = func(_missing_key: String) -> void: pass
	viewport.add_child(hud)
	await tree().process_frame
	return [hud, pair[0], pair[1]]


func test_hud_prep_prompt_text() -> void:
	var opened: Array = await _open_hud()
	var hud: Hud = opened[0]
	var game: Fakes.FakeGame = opened[2]
	game.roster = {1: {"name": "A", "slot": 0}, 2: {"name": "B", "slot": 1}}
	eq(hud.prep_prompt_text(), tr(&"HUD_PREP_GATHERING") % 2, "ekip sayısı")
	is_true(hud.prep_prompt_text().contains("2"))
	is_false(hud.prep_prompt_text().contains("%"), "biçim doldu")


func test_hud_reminder_for_host_only() -> void:
	var opened: Array = await _open_hud()
	var hud: Hud = opened[0]
	var net: Fakes.FakeNet = opened[1]
	var game: Fakes.FakeGame = opened[2]
	var toasts: Node = hud.get_node("%Toasts")
	game.prep_s = 31.0
	hud.advance(DT)
	eq(toasts.get_child_count(), 0, "istemciye hatırlatma yok")
	net.hosting = true
	hud.advance(DT)
	eq(toasts.get_child_count(), 1, "host: 30 sn sonra hatırlatma")
	var label: Label = toasts.get_child(0).get_child(0) as Label
	is_true(label.text.contains(tr(&"INTERACT_HEIST_START")), "metinde Başla: %s" % label.text)
	hud.advance(DT)
	eq(toasts.get_child_count(), 1, "aynı periyotta tekrar yok")
	game.prep_s = 61.0
	hud.advance(DT)
	eq(toasts.get_child_count(), 2, "60 sn: ikinci hatırlatma")
	game.prep_s = -1.0
	hud.advance(DT)
	eq(toasts.get_child_count(), 2, "iş başladı: hatırlatma yok")
