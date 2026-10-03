class_name HeistRules
extends RefCounted
## Soygun sonucu kuralları (US-012; GDD §9.3 "Ganimet ve sonuç", §3 K3; mimari.md S3 eki). Düğümsüz: yalnız
## değerlerle çalışır, sahne ağacını bilmez (KR-003). Game (host) her fizik adımında oyuncuların görünümünü
## (`view`: kaçış bölgesinde mi, yakalandı mı, tutuluyor mu, taşıdığı çanta değeri, koşuyor mu) `Tracker`'a
## verir; karar (`decide`) ve sonuç sözlüğü (`Tracker.build_result`, S3 eki alanları) buradan çıkar.
##
## Kurallar:
## - Kazanma: yakalanmamış herkes kaçış bölgesinde ve bunların ganimeti > 0 (taşıdığı çanta ya da kendi
##   boşalttığı kasa nakdi). Sonuç en yüksek uyarı kademesinden: ≤ 1 temiz, 2 bağırışlı, ≥ 3 sıcak.
## - Kaybetme: herkes yakalandı (`caught_all`) ya da polis geldi (`police_arrived`): kaçış bölgesi dışındaki
##   herkes yakalanır; kalanlar (bölgedekiler) ganimetliyse iş sıcak kazanılır, değilse `police`.
## - held ≠ caught: tutulan oyuncu yakalanmış sayılmaz (kurtarılabilir; süresi dolunca US-008 caught yapar).
## - Ödeme = ganimet × aracı oranı (tamsayı yüzde, yarım yukarı yuvarlanır); yakalananın payı (ganimeti) 0.
## - Eli boş çekilme (US-040): yakalanmamış herkes kaçış bölgesinde ve ganimet 0 iken `abort_hold_s` (data/
##   heist_tuning.tres, 3 sn) kesintisiz kalınırsa iş `aborted` biter: pay 0, bölgedekiler kaçmış sayılır, ısı
##   uyarı ≥ 2 ise +5. Biri çıkar/yakalanırsa sayaç sıfırlanır; ganimet > 0 ise kazanma kuralı anında; polis
##   geldiyse polis kuralı.
## - Kefalet (US-041, KR-029): iş sonunda yakalanan her oyuncu için ekip kasasından mekân kademesinin tutarı
##   (data/heist_tuning.tres) düşer; kasa eksiye düşebilir (borç), sonraki ödeme doğal olarak kapatır.
##   Ekip kasası = iş öncesi + ödeme − kefalet.
## - Çanta: koşulan her tam saniyede %25 düşer (gürültü 160); devir 0,3 sn; alma süresi data/props/bag.tres.

const OUTCOME_CLEAN := &"clean"
const OUTCOME_SHOUTED := &"shouted"
const OUTCOME_HOT := &"hot"
const OUTCOME_CAUGHT_ALL := &"caught_all"
const OUTCOME_POLICE := &"police"
## Eli boş çekilme (US-040): kayıp değil, kazanma da değil; pay 0.
const OUTCOME_ABORTED := &"aborted"
const LOSS_OUTCOMES: Array[StringName] = [OUTCOME_CAUGHT_ALL, OUTCOME_POLICE]
## `decide` dönüşü: iş sürüyor / kazanıldı (sonuç türü kademeden) / kaybedildi (OUTCOME_POLICE, OUTCOME_CAUGHT_ALL).
const DECISION_NONE := &""
const DECISION_WIN := &"win"

## Uyarı kademeleri (S3 eki, bakkal eşlemesi): 2 bağırdı, 3 mahalle geldi (5 polis).
const ALERT_SHOUTED := 2
const ALERT_HOT := 3
## Aracı oranı (yüzde). Temiz işte "kimse bağırmadı" bonusu eklenir.
const RATIO_PCT_CLEAN := 85
const RATIO_PCT_NO_SHOUT_BONUS := 5
const RATIO_PCT_SHOUTED := 85
const RATIO_PCT_HOT := 70
## Isı değişimi, sonuç türüne göre (KR-026; Faz 4 ekonomisine kadar yalnız sonuçta raporlanır). Tek sabit bloğu.
const HEAT_CLEAN := 0
const HEAT_SHOUTED := 5
const HEAT_HOT := 10
const HEAT_POLICE := 15
const HEAT_CAUGHT_ALL := 15
## Eli boş çekilme: bağırış olduysa (uyarı ≥ ALERT_SHOUTED) +5, değilse 0 (US-040).
const HEAT_ABORTED_SHOUTED := 5
## Eli boş çekilme sayacının yedek süresi (sn): asıl değer data/heist_tuning.tres `abort_hold_s` (Game verir).
const ABORT_HOLD_S := 3.0
## Kayan nokta birikimi için tolerans (60 Hz adımların toplamı 3,0'ı 1e-9 ıskalamasın).
const ABORT_EPS := 1e-6

## Çanta (GDD §9.3; kart US-012).
const BAG_GROUP := &"loot_bags"
## Koşulan her tam saniyede düşürme olasılığı.
const BAG_DROP_CHANCE := 0.25
const BAG_DROP_NOISE_RADIUS := 160.0
const BAG_DROP_NOISE_KIND := &"bag_drop"
const HANDOFF_HOLD_TIME := 0.3
## Düşen çanta bu süre dolmadan yeniden alınamaz (KR-026; sn).
const BAG_RETAKE_DELAY := 0.3
## Eli boş oyuncunun etiketi (S7 InteractionRequirement.required_tag): çanta yalnız eli boşken alınır/devralınır.
const FREE_HANDS_TAG := &"free_hands"

## Yakalanma nedeni (not seçimi için): polis (içeride kalan), mahalleli (US-008 chaser), bilinmiyor.
const CAUGHT_BY_POLICE := &"police"
const CAUGHT_BY_CHASER := &"chaser"
## Oyuncu durumunu okuyan yöntem adları (US-008 oyuncu API'si; yoksa false).
const CAUGHT_METHODS: Array[StringName] = [&"is_caught"]
const HELD_METHODS: Array[StringName] = [&"is_held"]
const SPRINT_METHODS: Array[StringName] = [&"is_sprinting"]

## Notlar (S3 eki not türleri; bu kalemin üretebildikleri). Öncelik sırası `NOTE_ORDER`.
const NOTE_GHOST_CREW := &"ghost_crew"
const NOTE_SLIPPER := &"slipper"
const NOTE_BAIL := &"bail"
const NOTE_PORTER := &"porter"
const NOTE_MARATHON := &"marathon"
const NOTE_ORDER: Array[StringName] = [NOTE_GHOST_CREW, NOTE_SLIPPER, NOTE_BAIL, NOTE_PORTER, NOTE_MARATHON]
const MAX_NOTES := 3
const MAX_NOTES_PER_PEER := 2
## "Maratoncu" için en az koşu süresi (sn).
const MARATHON_MIN_S := 5.0


## Kazanılan işin türü (en yüksek uyarı kademesinden).
static func win_outcome(max_alert: int) -> StringName:
	if max_alert >= ALERT_HOT:
		return OUTCOME_HOT
	if max_alert >= ALERT_SHOUTED:
		return OUTCOME_SHOUTED
	return OUTCOME_CLEAN


static func is_loss(outcome: StringName) -> bool:
	return LOSS_OUTCOMES.has(outcome)


## Aracı oranı (yüzde); kayıpta 0.
static func ratio_pct(outcome: StringName, shouted: bool) -> int:
	match outcome:
		OUTCOME_CLEAN:
			return RATIO_PCT_CLEAN + (0 if shouted else RATIO_PCT_NO_SHOUT_BONUS)
		OUTCOME_SHOUTED:
			return RATIO_PCT_SHOUTED
		OUTCOME_HOT:
			return RATIO_PCT_HOT
	return 0


## Isı değişimi; `max_alert` yalnız eli boş çekilmede (bağırış olduysa +5) kullanılır.
static func heat_for(outcome: StringName, max_alert: int = 0) -> int:
	match outcome:
		OUTCOME_ABORTED:
			return HEAT_ABORTED_SHOUTED if max_alert >= ALERT_SHOUTED else 0
		OUTCOME_CLEAN:
			return HEAT_CLEAN
		OUTCOME_SHOUTED:
			return HEAT_SHOUTED
		OUTCOME_HOT:
			return HEAT_HOT
		OUTCOME_POLICE:
			return HEAT_POLICE
		OUTCOME_CAUGHT_ALL:
			return HEAT_CAUGHT_ALL
	return 0


## Ödeme = ganimet × yüzde / 100, yarım yukarı (tamsayı: her peer'da aynı).
static func payout(loot: int, pct: int) -> int:
	return (maxi(loot, 0) * maxi(pct, 0) + 50) / 100


## Kefalet tutarı: `table` (kademe -> tutar) içinde kademenin kendisi, yoksa en yakın alt kademesi; hiçbiri yoksa 0.
static func bail_for_tier(table: Dictionary, tier: int) -> int:
	var best_tier: int = -1
	var amount: int = 0
	for key: Variant in table:
		var t: int = int(key)
		if t <= tier and t > best_tier:
			best_tier = t
			amount = maxi(int(table[key]), 0)
	return amount


## İş sonu ekip kasası = iş öncesi + ödeme − kefalet (eksi olabilir: borç; sonraki ödeme kapatır, KR-029).
static func cash_after(before: int, payout_value: int, bail: int) -> int:
	return before + maxi(payout_value, 0) - maxi(bail, 0)


## Eli boş çekilme koşulu (anlık): en az bir yakalanmamış oyuncu var, hepsi kaçış bölgesinde ve ganimet 0.
## `players` biçimi `decide` ile aynı.
static func abort_ready(players: Dictionary) -> bool:
	var free: int = 0
	for peer: Variant in players:
		var p: Dictionary = players[peer]
		if bool(p.get("caught", false)):
			continue
		free += 1
		if not bool(p.get("in_zone", false)) or int(p.get("loot", 0)) > 0:
			return false
	return free > 0


## İşin durumu. `players`: peer -> {"caught": bool, "in_zone": bool, "loot": int} (loot: yakalanmamışın kaçırdığı
## ganimet). `police`: polis geldi (bölge dışındakiler çağıran tarafından zaten yakalanmış işaretlenir).
## `abort_due`: eli boş çekilme sayacı doldu (AbortClock.done); yalnız koşul hâlâ sağlanıyorsa `aborted`.
static func decide(players: Dictionary, police: bool, abort_due: bool = false) -> StringName:
	if players.is_empty():
		return DECISION_NONE
	var free: int = 0
	var all_in_zone: bool = true
	var loot: int = 0
	for peer: Variant in players:
		var p: Dictionary = players[peer]
		if bool(p.get("caught", false)):
			continue
		free += 1
		all_in_zone = all_in_zone and bool(p.get("in_zone", false))
		loot += int(p.get("loot", 0))
	if free == 0:
		return OUTCOME_POLICE if police else OUTCOME_CAUGHT_ALL
	if all_in_zone and loot > 0:
		return DECISION_WIN
	if police:
		return OUTCOME_POLICE
	if abort_due and all_in_zone and loot == 0:
		return OUTCOME_ABORTED
	return DECISION_NONE


## Çanta: koşu süresi `prev_s`'ten `new_s`'e çıkınca atılacak zar sayısı (geçilen tam saniyeler).
static func rolls_due(prev_s: float, new_s: float) -> int:
	return maxi(floori(new_s) - floori(maxf(prev_s, 0.0)), 0)


## Çanta: zar (0..1) düşürüyor mu.
static func drops(roll: float) -> bool:
	return roll < BAG_DROP_CHANCE


## `node` verilen yöntemlerden birini taşıyor ve true dönüyorsa true (US-008 API'si yokken false).
static func node_flag(node: Object, methods: Array[StringName]) -> bool:
	if node == null:
		return false
	for method: StringName in methods:
		if node.has_method(method):
			return bool(node.call(method))
	return false


## İsteğe bağlı (başka kalemin) sinyalini hedefe uydurur. Hedef `max_args` parametre alır; `min_args`'tan
## sonrakiler varsayılanlıdır. Sinyal `min_args`'tan az argüman taşıyorsa geçersiz Callable (bağlanmaz);
## `max_args`'tan fazlaysa fazlası atılır.
static func adapt_callable(target: Callable, signal_args: int, min_args: int, max_args: int) -> Callable:
	if signal_args < min_args:
		return Callable()
	if signal_args > max_args:
		return target.unbind(signal_args - max_args)
	return target


## Not adayları (öncelik sırasıyla, her tür en fazla bir kez): `stats` =
## {"max_alert": int, "caught": {peer: cause}, "bags": {peer: int}, "sprint_s": {peer: float}, "slots": {peer: int}}.
## Eşitlikte küçük yuva kazanır. Hayalet ekip (peer 0 = ekip): hiç uyarı yok.
static func note_candidates(stats: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slots: Dictionary = stats.get("slots", {})
	var caught: Dictionary = stats.get("caught", {})
	if int(stats.get("max_alert", 0)) <= 0 and caught.is_empty():
		out.append({"kind": NOTE_GHOST_CREW, "peer": 0})
	var by_chaser: Dictionary = {}
	var any_caught: Dictionary = {}
	for peer: Variant in caught:
		any_caught[peer] = 1.0
		if StringName(str(caught[peer])) == CAUGHT_BY_CHASER:
			by_chaser[peer] = 1.0
	_append_top(out, NOTE_SLIPPER, by_chaser, slots, 1.0)
	_append_top(out, NOTE_BAIL, any_caught, slots, 1.0)
	_append_top(out, NOTE_PORTER, stats.get("bags", {}), slots, 1.0)
	_append_top(out, NOTE_MARATHON, stats.get("sprint_s", {}), slots, MARATHON_MIN_S)
	return out


## Adaylardan en fazla `max_notes` not: aynı tür bir kez, aynı oyuncuya en fazla `max_per_peer` (ekip notu sınırsız).
static func pick_notes(candidates: Array[Dictionary], max_notes: int = MAX_NOTES,
		max_per_peer: int = MAX_NOTES_PER_PEER) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var per_peer: Dictionary = {}
	var kinds: Dictionary = {}
	for c: Dictionary in candidates:
		if out.size() >= max_notes:
			break
		var kind: StringName = StringName(str(c.get("kind", "")))
		var peer: int = int(c.get("peer", 0))
		if kind == &"" or kinds.has(kind):
			continue
		if peer != 0 and int(per_peer.get(peer, 0)) >= max_per_peer:
			continue
		kinds[kind] = true
		if peer != 0:
			per_peer[peer] = int(per_peer.get(peer, 0)) + 1
		out.append({"kind": kind, "peer": peer})
	return out


## `values` (peer -> sayı) içinde en büyüğü `min_value`'dan küçük değilse notu ekler; eşitlikte küçük yuva, sonra
## küçük peer.
static func _append_top(out: Array[Dictionary], kind: StringName, values: Dictionary, slots: Dictionary,
		min_value: float) -> void:
	var best_peer: int = 0
	var best: float = -INF
	for key: Variant in values:
		var peer: int = int(key)
		var value: float = float(values[key])
		if value < min_value or peer == 0:
			continue
		if best_peer == 0 or value > best or (is_equal_approx(value, best) and _before(peer, best_peer, slots)):
			best_peer = peer
			best = value
	if best_peer != 0:
		out.append({"kind": kind, "peer": best_peer})


static func _before(a: int, b: int, slots: Dictionary) -> bool:
	var sa: int = int(slots.get(a, 1 << 20))
	var sb: int = int(slots.get(b, 1 << 20))
	return sa < sb if sa != sb else a < b


## Eli boş çekilme sayacı (US-040): koşul (`abort_ready`) her adımda verilir; kesintisiz `hold_s` sağlanınca dolar,
## koşul bozulunca ya da `epoch` değişince (yakalanan sayısı: biri yakalandı) sıfırlanır. Host'ta Tracker'ın içinde
## karar verir; istemcide Game aynı sınıfla yerel kopyadan yalnız HUD geri sayımını türetir (karar host'ta).
class AbortClock:
	extends RefCounted

	var hold_s: float = HeistRules.ABORT_HOLD_S
	## Koşulun kesintisiz sağlandığı süre (sn); 0 = sayaç yok.
	var held_s: float = 0.0
	## Bu sayaçta görülen en uzun süre (yalnız döküm/teşhis).
	var peak_s: float = 0.0
	var _epoch: int = 0

	func _init(hold: float = HeistRules.ABORT_HOLD_S) -> void:
		hold_s = maxf(hold, 0.0)

	## `epoch`: değişirse sayaç baştan başlar (ör. yakalanan sayısı; koşul sürse bile kesinti sayılır).
	func step(holding: bool, delta: float, epoch: int = 0) -> void:
		if epoch != _epoch:
			_epoch = epoch
			held_s = 0.0
		held_s = held_s + maxf(delta, 0.0) if holding else 0.0
		peak_s = maxf(peak_s, held_s)

	func running() -> bool:
		return held_s > 0.0

	func done() -> bool:
		return running() and held_s >= hold_s - HeistRules.ABORT_EPS

	## Kalan süre (sn); sayaç yoksa −1.
	func left() -> float:
		return maxf(hold_s - held_s, 0.0) if running() else -1.0


## Bir işin host'taki sayaçları ve kararı. Game her fizik adımında `observe` + `evaluate` çağırır; olaylar
## (uyarı, polis, yakalanma, kasa nakdi, çanta alma) ilgili yöntemlerle girer. Görünüm (`views`):
## peer -> {"in_zone": bool, "caught": bool, "held": bool, "bag_value": int, "sprinting": bool}.
class Tracker:
	extends RefCounted

	var elapsed: float = 0.0
	var max_alert: int = 0
	var shouts: int = 0
	var police: bool = false
	var finished: bool = false
	## peer -> yakalanma nedeni (StringName; &"" bilinmiyor).
	var caught: Dictionary = {}
	## peer -> boşalttığı nakit (kasa; anında ekip nakdine girmiştir, kaçarsa ganimet sayılır).
	var cash: Dictionary = {}
	## peer -> aldığı/devraldığı çanta sayısı.
	var bags: Dictionary = {}
	## peer -> koşu süresi (sn).
	var sprint_s: Dictionary = {}
	## Eli boş çekilme sayacı (US-040); Game `abort.hold_s`'i data/heist_tuning.tres'ten verir.
	var abort: HeistRules.AbortClock = HeistRules.AbortClock.new()

	func set_alert(level: int) -> void:
		max_alert = maxi(max_alert, level)

	func note_shout() -> void:
		shouts += 1

	## Bağırış oldu mu ("kimse bağırmadı" bonusu yoksa).
	func shouted() -> bool:
		return shouts > 0 or max_alert >= HeistRules.ALERT_SHOUTED

	func mark_caught(peer: int, cause: StringName = &"") -> void:
		if peer <= 0:
			return
		if not caught.has(peer) or str(caught[peer]).is_empty():
			caught[peer] = cause

	func is_caught(peer: int) -> bool:
		return caught.has(peer)

	func add_cash(peer: int, amount: int) -> void:
		if peer > 0 and amount > 0:
			cash[peer] = int(cash.get(peer, 0)) + amount

	## Ekip nakdine iş sırasında giren toplam ganimet nakdi (bitişte ödemeyle değiştirilir).
	func cash_grabbed() -> int:
		var total: int = 0
		for peer: Variant in cash:
			total += int(cash[peer])
		return total

	func note_bag(peer: int) -> void:
		if peer > 0:
			bags[peer] = int(bags.get(peer, 0)) + 1

	## Polis geldi: kaçış bölgesi dışındaki yakalanmamış herkes yakalanır (tutulanlar dahil).
	func arrive_police(views: Dictionary) -> void:
		police = true
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			if not bool(v.get("in_zone", false)):
				mark_caught(int(peer), HeistRules.CAUGHT_BY_POLICE)

	## Bir zaman adımı: süre, koşu süreleri; oyuncu API'sinin bildirdiği yakalanmalar kalıcı kaydedilir
	## (held kaydedilmez: tutulan oyuncu yakalanmış değildir).
	func observe(views: Dictionary, delta: float) -> void:
		elapsed += maxf(delta, 0.0)
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			if bool(v.get("caught", false)):
				mark_caught(int(peer))
			if bool(v.get("sprinting", false)):
				sprint_s[int(peer)] = float(sprint_s.get(int(peer), 0.0)) + maxf(delta, 0.0)
		abort.step(not police and HeistRules.abort_ready(players_state(views)), delta, caught.size())

	## Kural girdisi: peer -> {"caught", "in_zone", "loot"}.
	func players_state(views: Dictionary) -> Dictionary:
		var out: Dictionary = {}
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			var id: int = int(peer)
			var is_caught_now: bool = is_caught(id) or bool(v.get("caught", false))
			out[id] = {
				"caught": is_caught_now,
				"in_zone": bool(v.get("in_zone", false)),
				"loot": 0 if is_caught_now else int(cash.get(id, 0)) + int(v.get("bag_value", 0)),
			}
		return out

	func evaluate(views: Dictionary) -> StringName:
		if finished:
			return HeistRules.DECISION_NONE
		return HeistRules.decide(players_state(views), police, abort.done())

	## Sonuç sözlüğü (S3 eki): `roster` = Game.players() (peer -> {"name", "slot"}). `bail_each`: yakalanan başına
	## kefalet (KR-029); `cash_before`: iş öncesi ekip kasası (kasadan anında giren ham nakit hariç).
	func build_result(decision: StringName, views: Dictionary, roster: Dictionary, bail_each: int = 0,
			cash_before: int = 0) -> Dictionary:
		var win: bool = decision == HeistRules.DECISION_WIN
		var outcome: StringName = HeistRules.win_outcome(max_alert) if win else decision
		var got_away: bool = win or outcome == HeistRules.OUTCOME_ABORTED
		var state: Dictionary = players_state(views)
		var players: Dictionary = {}
		var slots: Dictionary = {}
		var loot_total: int = 0
		var bail_total: int = 0
		for key: Variant in roster:
			var id: int = int(key)
			var entry: Dictionary = roster[key]
			var s: Dictionary = state.get(id, {"caught": is_caught(id), "in_zone": false, "loot": 0})
			var escaped: bool = got_away and not bool(s["caught"]) and bool(s["in_zone"])
			var loot: int = int(s["loot"]) if escaped and win else 0
			var bail: int = maxi(bail_each, 0) if bool(s["caught"]) else 0
			loot_total += loot
			bail_total += bail
			slots[id] = int(entry.get("slot", 0))
			players[str(id)] = {
				"name": str(entry.get("name", "")),
				"slot": int(entry.get("slot", 0)),
				"escaped": escaped,
				"caught": bool(s["caught"]),
				"loot": loot,
				"bail": bail,
			}
		var pct: int = HeistRules.ratio_pct(outcome, shouted())
		var caught_now: Dictionary = {}
		for id: Variant in state:
			if bool((state[id] as Dictionary)["caught"]):
				caught_now[int(id)] = caught.get(int(id), &"")
		var stats: Dictionary = {
			"max_alert": max_alert, "caught": caught_now, "bags": bags, "sprint_s": sprint_s, "slots": slots,
		}
		var paid: int = HeistRules.payout(loot_total, pct)
		return {
			"outcome": outcome,
			"loot_total": loot_total,
			"payout_ratio": pct / 100.0,
			"payout": paid,
			"duration_s": snappedf(elapsed, 0.01),
			"players": players,
			"notes": HeistRules.pick_notes(HeistRules.note_candidates(stats)),
			"heat": HeistRules.heat_for(outcome, max_alert),
			"max_alert": max_alert,
			"bail": bail_total,
			"cash_before": cash_before,
			"cash_after": HeistRules.cash_after(cash_before, paid, bail_total),
		}
