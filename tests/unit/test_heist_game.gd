extends TestCase
## US-012 Game bölümü (S3 eki) tek süreçli: host oturumu + store_a + gerçek oyuncu. Kazanma (kasa → kaçış
## bölgesi: temiz %90; çanta + uyarı 2: bağırışlı %85, ısı +5), kaybetme (police: içeride kalan yakalanır;
## caught_all), ekip nakdi = ödeme, request_restart (aynı seviye, nakit 0, sonuç sıfır), venue_tier, kaçış bölgesi
## olmayan seviyede iş izlenmez. US-008 olayları yokken sahte sahip olayları S3 session_event'leriyle verilir
## (&"alert_level", &"police_arrived", &"player_caught"). Çok süreçli: tests/net/heist_full.json.

const STORE := "res://levels/store_a.tscn"
const PLAIN_LEVEL := "res://tests/fixtures/empty_level.tscn"
const PLAYER := "res://entities/player/player.tscn"
const IN_ZONE := Vector2(860, 576)
const STAFF := Vector2(588, 368)
const NEAR_BAG := Vector2(496, 256)
const DT := 1.0 / 60.0

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
	eq(Game.team_cash(), 150, "kasa anında ekip nakdine (US-005)")
	await _frames()
	eq(_results.size(), 0, "kaçış bölgesine girmeden bitmez")
	me.position = IN_ZONE
	await _frames()
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
	eq(Game.team_cash(), 135, "ekip nakdi = ödeme (ham kasa nakdi ödemeyle değişti)")
	await _frames()
	eq(_results.size(), 1, "iş bitti: yeniden karar yok")
	# Bir daha (host): aynı seviye, nakit 0, sonuç sıfır, kasa yeniden dolu.
	var old_level: Level = _level()
	Game.request_restart()
	is_true(_level() != old_level and _level() != null, "seviye yeniden yüklendi")
	eq(Game.team_cash(), 0)
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
	eq(Game.team_cash(), 383)
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
	eq(Game.team_cash(), -100, "kasa nakdi kayboldu; kefalet 100 düştü (US-041, KR-029)")
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


## US-008 sinyal yolu: Game'de `player_caught(peer_id, by)` varsa seviye yüklenince bağlanır; by = chaser → Terlik
## yedi. (Sinyal US-008'de betikte olacak; burada çalışma anında eklenir — betik sinyali gibi get_signal_list'te.)
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


## İş bitince host yeni ganimet isteğini reddeder; bitmeden başlamış boşaltma sonradan biterse nakdi geri alınır.
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
	eq(Game.team_cash(), -100, "sonuçtan sonra nakit eklenmez (geri alındı); kefalet 100 (KR-029)")
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


## US-040: ganimetsiz kaçış bölgesinde 3 sn (data/heist_tuning.tres) kesintisiz → `aborted`; çıkınca sayaç sıfır.
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
		eq([r["cash_before"], r["cash_after"]], [0, 0], "kasa değişmez")
	eq(Game.abort_left(), -1.0, "iş bitti: sayaç yok")
	eq(Game.team_cash(), 0)
	await _stop()


## US-041 (KR-029): yakalanan başına kefalet 100 (T1); kasa eksiye düşer; sonraki işin ödemesi borcu kapatır
## (yeniden başlatma değil, aynı seviyenin düz yüklenmesi: kasa taşınır).
func test_bail_debt_closed_by_next_payout() -> void:
	var me: Player = _start()
	if not is_true(me != null, "yerel oyuncu"):
		await _stop()
		return
	Game.raise_session_event(&"police_arrived")
	await _frames()
	if eq(_results.size(), 1):
		var r: Dictionary = _results[0]
		eq(r["outcome"], &"police")
		eq(r["bail"], 100, "bir yakalanan: 100")
		eq(r["players"]["1"]["bail"], 100)
		eq([r["cash_before"], r["cash_after"]], [0, -100])
	eq(Game.team_cash(), -100, "borç")
	Game.start_level(STORE)
	me = Game.local_player() as Player
	eq(Game.team_cash(), -100, "borç sonraki işe taşınır")
	me.position = STAFF
	_complete(_level().props_root().get_node("Register/Interactable") as Interactable, 1, 3.05)
	eq(Game.team_cash(), 50, "kasa nakdi anında (-100 + 150)")
	me.position = IN_ZONE
	await _frames()
	if eq(_results.size(), 2):
		var r: Dictionary = _results[1]
		eq(r["outcome"], &"clean")
		eq(r["payout"], 135)
		eq(r["bail"], 0)
		eq([r["cash_before"], r["cash_after"]], [-100, 35], "iş öncesi + ödeme − kefalet")
	eq(Game.team_cash(), 35, "ödeme borcu kapattı")
	await _stop()


func test_request_restart_needs_level() -> void:
	Game.request_restart()  # çevrimdışı, seviye yok: uyarı, etkisiz
	is_true(Game.current_level() == null)
