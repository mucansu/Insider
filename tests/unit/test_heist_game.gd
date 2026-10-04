extends TestCase
## US-012 Game part (S3 addition), single process: host session + store_a + real player. Win (register -> escape zone:
## clean 90%; bag + alert 2: shouted 85%, heat +5), lose (police: those still inside are caught; caught_all), team cash =
## payout, request_restart (same level, cash 0, result reset), venue_tier, no job tracking on a level without an escape
## zone. Without US-008 events, fake owner events are fed as S3 session_events (&"alert_level", &"police_arrived",
## &"player_caught"). Multi-process: tests/net/heist_full.json. US-045: team cash starts at HeistTuning.start_cash (allowance, KR-038);
## cover breaks only while an NPC sees the player (GB-08 A: unseen sprint keeps it, sprint in the owner's cone breaks it, `by` = observer).

const STORE := "res://levels/store_a.tscn"
const PLAIN_LEVEL := "res://tests/fixtures/empty_level.tscn"
const NOPOP := "res://tests/fixtures/store_a_nopop.tscn"
## Customer side of the counter, inside the owner's cone (US-045 AC4).
const COUNTER_FRONT := Vector2(536, 336)
const PLAYER := "res://entities/player/player.tscn"
const IN_ZONE := Vector2(860, 576)
const STAFF := Vector2(588, 368)
const NEAR_BAG := Vector2(496, 256)
const DT := 1.0 / 60.0
## IS-103: physics frames that cover the 3 s escape settle (data/heist_tuning.tres) with margin.
const SETTLE_FRAMES := 190
## US-045 (KR-038): session start cash (allowance).
var START: int = HeistTuning.load_default().start_cash

var _results: Array[Dictionary] = []
var _previous_scene: PackedScene = null


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


func _on_finished(result: Dictionary) -> void:
	_results.append(result)


func _start(level: String = STORE) -> Player:
	_previous_scene = Game.player_scene
	Game.player_scene = load(PLAYER) as PackedScene
	Game.heist_finished.connect(_on_finished)
	if not eq(Net.host(free_udp_port()), OK):
		return null
	Game.start_level(level)
	return Game.local_player() as Player


func _stop() -> void:
	Net.leave()
	await tree().process_frame
	await tree().process_frame
	Game.heist_finished.disconnect(_on_finished)
	Game.player_scene = _previous_scene


func _frames(n: int = 3) -> void:
	for i: int in n:
		await tree().physics_frame


func _complete(item: Interactable, peer_id: int, seconds: float) -> void:
	item.host_start(peer_id, 1)
	for i: int in roundi(seconds / DT):
		item.step(DT)


func _level() -> Level:
	return Game.current_level() as Level


func test_clean_win_pays_ninety_percent_of_register() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	eq(Game.venue_tier(), 1, "bakkal T1")
	eq(Game.heist_result(), {}, "iş sürerken sonuç yok")
	me.position = STAFF
	_complete(_level().props_root().get_node("Register/Interactable") as Interactable, 1, 3.05)
	eq(Game.team_cash(), START + 150, "kasa anında ekip nakdine (US-005)")
	await _frames()
	eq(_results.size(), 0, "kaçış bölgesine girmeden bitmez")
	eq(Game.escape_settle_left(), -1.0, "bölge dışında: kaçış geri sayımı yok")
	me.position = IN_ZONE
	await _frames()
	eq(_results.size(), 0, "IS-103: ganimetle bölgede, önce 3 sn geri sayım")
	var left: float = Game.escape_settle_left()
	is_true(left > 2.8 and left < 3.0, "geri sayım başladı: %s" % left)
	eq(Game.abort_left(), -1.0, "ganimet var: eli boş sayacı çalışmaz")
	await _frames(SETTLE_FRAMES)
	if eq(_results.size(), 1, "heist_finished bir kez"):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"clean")
		eq(r["loot_total"], 150)
		eq(r["payout_ratio"], 0.9, "%85 + kimse bağırmadı %5")
		eq(r["payout"], 135)
		eq(r["players"]["1"]["escaped"], true)
		eq(r["players"]["1"]["loot"], 150)
		has(r["notes"], {"kind": &"ghost_crew", "peer": 0}, "hiç uyarı yok: hayalet ekip")
		eq(Game.heist_result(), r, "geç katılan için de aynı sonuç")
	eq(Game.team_cash(), START + 135, "ekip nakdi = ödeme (ham kasa nakdi ödemeyle değişti)")
	await _frames()
	eq(_results.size(), 1, "iş bitti: yeniden karar yok")
	# Again (host): same level, register carried over (KR-029, US-042 package), result reset, register prop refilled.
	var old_level: Level = _level()
	Game.request_restart()
	is_true(_level() != old_level and _level() != null, "seviye yeniden yüklendi")
	eq(Game.team_cash(), START + 135, "ekip kasası yeniden başlatmada sıfırlanmaz")
	eq(Game.heist_result(), {}, "yeni iş: sonuç sıfır")
	is_false((_level().props_root().get_node("Register") as Register).emptied, "prop'lar sıfırlandı")
	await _stop()


func test_bag_and_shout_is_shouted_win() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.raise_session_event(&"alert_level", {"level": 2})
	var bag: Bag = _level().props_root().get_node("Bag") as Bag
	me.position = NEAR_BAG
	_complete(bag.get_node("Take") as Interactable, 1, 2.05)
	eq(bag.carrier, 1, "çanta alındı")
	me.position = IN_ZONE
	await _frames()
	if eq(_results.size(), 1):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"shouted")
		eq(r["loot_total"], 450)
		eq(r["payout_ratio"], 0.85)
		eq(r["payout"], 383)
		eq(r["heat"], 5)
		has(r["notes"], {"kind": &"porter", "peer": 1}, "Hamal")
	eq(Game.team_cash(), START + 383)
	await _stop()


## IS-103 (KR-034): escape settle — leaving the zone cancels the countdown, it restarts from 3 s; a shout (alert 2) during it ends the job
## at once as `shouted` (payout rules unchanged).
func test_escape_settle_cancel_and_shout() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	me.position = STAFF
	_complete(_level().props_root().get_node("Register/Interactable") as Interactable, 1, 3.05)
	me.position = IN_ZONE
	await _frames(90)
	var left: float = Game.escape_settle_left()
	is_true(left > 1.0 and left < 2.0, "1,5 sn sonra kalan ~1,5 sn: %s" % left)
	me.position = STAFF
	await _frames(3)
	eq(Game.escape_settle_left(), -1.0, "bölgeden çıktı: geri sayım iptal")
	eq(_results.size(), 0)
	me.position = IN_ZONE
	await _frames(60)
	left = Game.escape_settle_left()
	is_true(left > 1.8 and left < 2.1, "baştan sayıyor (~2 sn kaldı): %s" % left)
	eq(_results.size(), 0)
	Game.raise_session_event(&"alert_level", {"level": 2})
	await _frames(3)
	if eq(_results.size(), 1, "geri sayımda bağırış: iş hemen biter"):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"shouted")
		eq(r["payout_ratio"], 0.85)
		eq(r["payout"], 128)
		eq(r["heat"], 5)
	eq(Game.escape_settle_left(), -1.0, "iş bitti: geri sayım yok")
	await _stop()


func test_police_catches_player_inside() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	me.position = STAFF
	_complete(_level().props_root().get_node("Register/Interactable") as Interactable, 1, 3.05)
	Game.raise_session_event(&"police_arrived")
	await _frames()
	if eq(_results.size(), 1):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"police")
		eq(r["players"]["1"]["caught"], true, "içeride kalan yakalandı")
		eq(r["players"]["1"]["escaped"], false)
		eq(r["payout"], 0)
		has(r["notes"], {"kind": &"bail", "peer": 1})
	eq(Game.team_cash(), START - 100, "kasa nakdi kayboldu; kefalet 100 düştü (US-041, KR-029)")
	await _stop()


func test_caught_all_by_chaser() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.raise_session_event(&"player_caught", {"peer": 1, "by": &"chaser"})
	await _frames()
	if eq(_results.size(), 1):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"caught_all")
		eq(r["notes"], [{"kind": &"slipper", "peer": 1}, {"kind": &"bail", "peer": 1}])
	await _stop()


## US-008 signal path: if Game has `player_caught(peer_id, by)` it is connected on level load; by = chaser -> Terlik
## is eaten. (The signal will be in the script with US-008; here it is added at runtime, like a script signal in get_signal_list.)
func test_player_caught_signal_with_cause() -> void:
	if not Game.has_signal(&"player_caught"):
		Game.add_user_signal("player_caught", [
			{"name": "peer_id", "type": TYPE_INT}, {"name": "by", "type": TYPE_STRING_NAME},
		])
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.emit_signal(&"player_caught", 1, &"chaser")
	await _frames()
	if eq(_results.size(), 1, "sinyalden yakalanma"):
		eq(_results[0]["outcome"], &"caught_all")
		eq(_results[0]["notes"][0], {"kind": &"slipper", "peer": 1}, "by=chaser sinyalden geçti")
	await _stop()


## After the job ends the host rejects new loot requests; if an unloading started earlier finishes later the cash is refunded.
func test_loot_locked_after_finish() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	me.position = STAFF
	var reg: Interactable = _level().props_root().get_node("Register/Interactable") as Interactable
	reg.host_start(1, 1)
	for i: int in roundi(1.0 / DT):
		reg.step(DT)
	Game.raise_session_event(&"police_arrived")
	await _frames()
	eq(_results.size(), 1, "iş bitti (polis)")
	for i: int in roundi(2.2 / DT):
		reg.step(DT)
	is_true((_level().props_root().get_node("Register") as Register).emptied, "süren boşaltma bitti")
	eq(Game.team_cash(), START - 100, "sonuçtan sonra nakit eklenmez (geri alındı); kefalet 100 (KR-029)")
	var bag: Bag = _level().props_root().get_node("Bag") as Bag
	me.position = NEAR_BAG
	(bag.get_node("Take") as Interactable).host_start(1, 2)
	eq((bag.get_node("Take") as Interactable).stats()["rejected"], {"blocked": 1}, "çanta yeni istek reddedilir")
	await _stop()


func test_fresh_register_rejected_after_finish() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.raise_session_event(&"police_arrived")
	await _frames()
	me.position = STAFF
	var reg: Interactable = _level().props_root().get_node("Register/Interactable") as Interactable
	reg.host_start(1, 1)
	eq(reg.stats()["rejected"], {"blocked": 1}, "iş bitti: kasa isteği reddedilir")
	await _stop()


func test_caught_carrier_drops_bag() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	var bag: Bag = _level().props_root().get_node("Bag") as Bag
	me.position = NEAR_BAG
	_complete(bag.get_node("Take") as Interactable, 1, 2.05)
	eq(bag.carrier, 1)
	Game.raise_session_event(&"player_caught", {"peer": 1})
	await _frames()
	eq(bag.carrier, 0, "yakalanan taşıyanın çantası düşer")
	eq(bag.drops, 1)
	if eq(_results.size(), 1):
		eq(_results[0]["outcome"], &"caught_all")
		eq(_results[0]["loot_total"], 0)
	await _stop()


func test_level_without_escape_zone_is_not_a_heist() -> void:
	var me: Player = _start(PLAIN_LEVEL)
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.raise_session_event(&"player_caught", {"peer": 1})
	Game.raise_session_event(&"police_arrived")
	await _frames()
	eq(_results.size(), 0, "EscapeZone yok: iş izlenmez")
	eq(Game.heist_result(), {})
	await _stop()


## US-040: 3 s (data/heist_tuning.tres) continuously in the escape zone without loot -> `aborted`; leaving resets the counter.
func test_empty_handed_abort() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	eq(Game.abort_left(), -1.0, "bölge dışında: sayaç yok")
	me.position = IN_ZONE
	await _frames(90)
	var left: float = Game.abort_left()
	is_true(left > 1.0 and left < 2.0, "1,5 sn sonra kalan ~1,5 sn: %s" % left)
	me.position = STAFF
	await _frames(3)
	eq(Game.abort_left(), -1.0, "bölgeden çıktı: sayaç sıfırlandı")
	me.position = IN_ZONE
	await _frames(150)
	eq(_results.size(), 0, "yeniden sayıyor: 2,5 sn'de bitmez")
	await _frames(40)
	if eq(_results.size(), 1, "3 sn kesintisiz: iş bitti"):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"aborted")
		eq(r["payout"], 0)
		eq(r["heat"], 0)
		eq(r["bail"], 0)
		eq(r["players"]["1"]["escaped"], true, "yakalanmadı, kaçtı sayılır")
		eq(r["players"]["1"]["caught"], false)
		eq([r["cash_before"], r["cash_after"]], [START, START], "kasa değişmez")
	eq(Game.abort_left(), -1.0, "iş bitti: sayaç yok")
	eq(Game.team_cash(), START)
	await _stop()


## US-041 (KR-029): bail 100 per caught player (T1); cash may go negative; the next job's payout clears the debt
## (not a restart, a plain load of the same level: cash carries over).
func test_bail_debt_closed_by_next_payout() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	me.position = STAFF  # staff side next to the owner: cover breaks (US-042; seen, US-045), police catch
	await _frames()
	Game.raise_session_event(&"police_arrived")
	await _frames()
	if eq(_results.size(), 1):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"police")
		eq(r["bail"], 100, "bir yakalanan: 100")
		eq(r["players"]["1"]["bail"], 100)
		eq([r["cash_before"], r["cash_after"]], [START, START - 100])
	eq(Game.team_cash(), START - 100, "borç")
	Game.start_level(STORE)
	me = Game.local_player() as Player
	eq(Game.team_cash(), START - 100, "borç sonraki işe taşınır")
	me.position = STAFF
	_complete(_level().props_root().get_node("Register/Interactable") as Interactable, 1, 3.05)
	eq(Game.team_cash(), START + 50, "kasa nakdi anında (-100 + 150)")
	me.position = IN_ZONE
	await _frames(SETTLE_FRAMES)
	if eq(_results.size(), 2):
		var r: Dictionary = _results[1]
		eq(r["outcome"], &"clean")
		eq(r["payout"], 135)
		eq(r["bail"], 0)
		eq([r["cash_before"], r["cash_after"]], [START - 100, START + 35], "iş öncesi + ödeme − kefalet")
	eq(Game.team_cash(), START + 35, "ödeme borcu kapattı")
	await _stop()


## US-042 AC1/AC3: source of the local cover indicator; breaks on crossing to the staff side, the event reaches everyone, no return.
func test_cover_state_breaks_on_staff_side() -> void:
	eq(Game.cover_state(), -1, "iş yok")
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	eq(Game.cover_state(), 1, "doğma noktası (dışarı): müşteri gibi")
	me.position = STAFF
	await _frames()
	eq(Game.cover_state(), 0, "personel tarafı: örtü bozuldu")
	var events: Array = Game.collect_dump()["events"]
	has(events, {"kind": "cover_broken", "data": {"peer": 1, "reason": "staff", "by": "Owner"}},
		"olay herkese gider; gören sahip (GB-08 A)")
	me.position = IN_ZONE + Vector2(-300, 0)
	await _frames()
	eq(Game.cover_state(), 0, "geri gelmez")
	await _stop()


## US-045 AC4 (GB-08 option A, KR-038): sprinting on the street with nobody looking keeps the cover; sprinting inside the owner's cone
## breaks it and the event / dump name the observer (`by`, `seen_by`).
func test_cover_breaks_only_when_seen() -> void:
	var me: Player = _start(NOPOP)
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	(me.get_node(^"PlayerInput") as PlayerInput).use_bot(BotTimeline.from_raw([
		{"t": 0.05, "move": [1, 0]}, {"t": 0.05, "hold": "sprint", "dur": 30.0}, {"t": 1.5, "move": [-1, 0]}]))
	var sprinted: Array[bool] = [false]
	for i: int in 80:
		await tree().physics_frame
		sprinted[0] = sprinted[0] or me.is_sprinting()
	is_true(sprinted[0], "sokakta koştu")
	eq(Game.cover_state(), 1, "kimse görmedi: örtü sağlam")
	me.position = COUNTER_FRONT
	await _frames(30)
	eq(Game.cover_state(), 0, "sahip konisinde koştu: bozuk")
	var events: Array = Game.collect_dump()["events"]
	has(events, {"kind": "cover_broken", "data": {"peer": 1, "reason": "run", "by": "Owner"}}, "gören: sahip")
	await _stop()


## US-042 AC2: when police arrive, a player with intact cover (waiting outside) is released by the witness check.
func test_police_releases_witness() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	Game.raise_session_event(&"police_arrived")
	await _frames()
	if eq(_results.size(), 1):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"police", "kimse kaçmadı")
		var p: Dictionary = r["players"]["1"]
		eq([p["caught"], p["escaped"], p["witness_released"], p["recognized"], p["bail"]], [false, false, true, 1, 0])
		eq(r["heat"], HeistRules.HEAT_POLICE + 2, "tanık: ekip ısısı +2 (data/heist_tuning.tres)")
		eq(r["strategy"]["cover_intact"], {"1": true})
		eq(r["strategy"]["class"], &"zaman")
	eq(Game.team_cash(), START, "kefalet yok")
	await _stop()


## US-042 AC1: close interaction with a marked friend (owner held) inside the owner's cone and line of sight -> cover breaks,
## owner's suspicion of that player +60 (report_suspicion: customer-witness path). Unseen / unmarked interaction does not break it.
func test_association_seen_by_owner() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	await _frames()
	var owner: Node2D = _level().npcs_root().get_node("Owner") as Node2D
	var eye: Perception = owner.get_node("Perception") as Perception
	var meter: Suspicion = owner.get_node("Suspicion") as Suspicion
	# A point inside the cone and line of sight (the counter blocks some rays): the first candidate.
	var seen_at: Vector2 = Vector2.INF
	for d: Vector2 in [Vector2(-60, 60), Vector2(-60, -60), Vector2(-100, 60), Vector2(-40, 30)]:
		var at: Vector2 = eye.global_position + d
		if PerceptionRules.band(eye.params(), eye.global_position, eye.facing, at) != PerceptionRules.Band.NONE 				and eye.has_line_of_sight(eye.global_position, at):
			seen_at = at
			break
	if not is_true(seen_at.is_finite(), "sahibin gördüğü nokta"):
		await _stop()
		return
	# Behind the owner, outside the 360 deg arm reach (IS-098: within it the owner sees in every direction).
	var behind: Vector2 = eye.global_position - eye.facing.normalized() * (eye.arm_reach() + 16.0)
	var other: int = 77
	eq(Game._heist_associate_at(1, other, seen_at, seen_at + Vector2(20, 0)), 0, "arkadaş işaretsiz")
	Game.raise_session_event(&"player_held", {"peer": other})
	await _frames(1)
	eq(Game._heist_associate_at(1, other, behind, behind + Vector2(20, 0)), 0, "sahibin arkasında: görülmedi")
	eq(Game._heist_associate_at(1, other, seen_at, seen_at + Vector2(60, 0)), 0, "48 px dışında")
	eq(Game.cover_state(), 1, "bozulmadı")
	var before: float = meter.value_of(1)
	eq(Game._heist_associate_at(1, other, seen_at, seen_at + Vector2(20, 0)), 1, "sahip gördü")
	near(meter.value_of(1) - before, 60.0, 0.5, "sahibin şüphesi +60")
	await _frames()
	eq(Game.cover_state(), 0, "ilişkilendirme örtüyü bozdu")
	await _stop()


func test_request_restart_needs_level() -> void:
	Game.request_restart()  # offline, no level: warning, no effect
	is_true(Game.current_level() == null)
