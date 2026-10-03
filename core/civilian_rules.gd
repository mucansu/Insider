class_name CivilianRules
extends RefCounted
## Sivil gözlemci kuralları (US-008 AC1/AC3/AC7/AC8; GDD §6.1 sivil çarpan tablosu, §9.3, §12; KR-020/021).
## Düğümsüz: yalnız değerlerle çalışır (Vector2, float, int, Rect2); sahne ağacını bilmez (KR-003, KR-018).
##
## - Davranış çarpanı: muhafızın kip çarpanının yerine geçer (`Perception.factor_query`). Oyuncunun o an yaptığı
##   **en şüpheli** davranışın çarpanı alınır (çarpılmaz): müşteri bölgesinde yürüme ilk `loiter_grace` sn 0,
##   sonra oyalanma; sızma; koşma (dükkân içinde); personel tarafı / arka oda; çanta ya da kilit; kasa/nakit
##   etkileşimi (tut sürerken); bağırıştan sonra herkes. Dışarıda (sokak) yalnız kilit/çanta/kasa ve bağırış
##   satırları işler. Dolum = taban × bant × çarpan (PerceptionRules), boşalma görünmeyince `decay` (tuning),
##   görünüp masumken (çarpan 0) `innocent_decay`.
## - Örtü (US-016 AC6, GDD §9.2): içeride ≥ 1 müşteri varken (`Context.customers_inside`, yalnız sahibin bağlamı
##   doldurur) müşteri bölgesindeki hedefin çarpanı ×`cover_factor` (dikkat bölünür); personel tarafı ve kasa
##   satırları etkilenmez.
## - Tepki göstergesi ("?"/"!"): istemcide çoğaltılan ölçerden eşikle türetilir (ON-04); "?" histerezisli,
##   "!" beyin alarm durumundayken kilitli (tespit sonrası kısa saklanmada titremez).
## - Temas (tutma/yakalama): host'un en güncel konumu `velocity × min(RTT/2, lead_cap)` ileri alınır (ON-03,
##   oyuncu lehine: kaçan oyuncu ileride sayılır); `reach` içinde `contact_time` kesintisiz kalınca olur.

enum Zone { OUTSIDE, CUSTOMER, STAFF, BACKROOM }
## Tabloda çarpanı veren satır (döküm `behaviour`).
enum Behaviour { INNOCENT, LOITER, SNEAK, SPRINT, STAFF_SIDE, BAG_OR_LOCK, CASH, ALARM }
## Oyuncunun sürdürdüğü (busy_by) etkileşimin türü.
enum Interaction { NONE, TAMPER, CASH }
## İstemci göstergesi.
enum Bubble { NONE, NOTICE, ALARM }

const BEHAVIOUR_NAMES: Array[StringName] = [&"innocent", &"loiter", &"sneak", &"sprint", &"staff_side",
	&"bag_or_lock", &"cash", &"alarm"]
const ZONE_NAMES: Array[StringName] = [&"outside", &"customer", &"staff", &"backroom"]


## Çarpan tablosu (değer nesnesi; `data/npc/civilian_tuning.tres`'ten doldurulur, varsayılanlar nötr).
class Params:
	extends RefCounted
	## Müşteri bölgesinde masum sayılan süre (sn) ve sonrası oyalanma çarpanı.
	var loiter_grace: float = 0.0
	var loiter_factor: float = 0.0
	var sneak_factor: float = 0.0
	var sprint_factor: float = 0.0
	var staff_factor: float = 0.0
	var bag_or_lock_factor: float = 0.0
	var cash_factor: float = 0.0
	var alarm_factor: float = 0.0
	## Bu uyarı kademesinden itibaren herkes `alarm_factor` (bakkal: 2 = sahip bağırdı).
	var alarm_level: int = 0
	## Görünüp masumken boşalma (birim/sn).
	var innocent_decay: float = 0.0
	## Gösterge eşikleri: "?" ve "!" (ölçer birimi); "?" `bubble_hysteresis` altına inince söner.
	var notice_at: float = 0.0
	var detect_at: float = 0.0
	var bubble_hysteresis: float = 0.0
	## Örtü çarpanı (US-016): içeride müşteri varken müşteri bölgesi satırları; 1 = örtü yok.
	var cover_factor: float = 1.0


## Bir hedefin bu adımdaki durumu.
class Context:
	extends RefCounted
	var zone: Zone = Zone.OUTSIDE
	var stance: PerceptionRules.Stance = PerceptionRules.Stance.WALK
	var interaction: Interaction = Interaction.NONE
	var carrying_bag: bool = false
	var alert_level: int = 0
	## Dükkân içinde geçirilen toplam süre (sn; SATIN AL sıfırlar, US-010).
	var loiter_time: float = 0.0
	## İçerideki müşteri sayısı (US-016 örtü; yalnız sahibin bağlamı doldurur).
	var customers_inside: int = 0


static func is_inside(zone: Zone) -> bool:
	return zone != Zone.OUTSIDE


## En şüpheli davranışın çarpanı (çarpılmaz, en büyüğü).
static func factor(p: Params, ctx: Context) -> float:
	var b: Behaviour = behaviour(p, ctx)
	var f: float = factor_of(p, b)
	return f * p.cover_factor if covered(ctx, b) else f


## Örtü uygulanır mı (US-016 AC6): içeride müşteri var, hedef müşteri bölgesinde, satır personel/kasa değil.
static func covered(ctx: Context, b: Behaviour) -> bool:
	return ctx.customers_inside > 0 and ctx.zone == Zone.CUSTOMER and b != Behaviour.STAFF_SIDE 		and b != Behaviour.CASH


## Çarpanı veren satır: aday satırlardan çarpanı en büyük olan (eşitlikte tablodaki sonraki).
static func behaviour(p: Params, ctx: Context) -> Behaviour:
	var best: Behaviour = Behaviour.INNOCENT
	for b: Behaviour in candidates(p, ctx):
		if factor_of(p, b) >= factor_of(p, best):
			best = b
	return best


## Bağlamda geçerli satırlar (masum hariç).
static func candidates(p: Params, ctx: Context) -> Array[Behaviour]:
	var out: Array[Behaviour] = []
	var inside: bool = is_inside(ctx.zone)
	if inside and ctx.loiter_time > p.loiter_grace:
		out.append(Behaviour.LOITER)
	if inside and ctx.stance == PerceptionRules.Stance.SNEAK:
		out.append(Behaviour.SNEAK)
	if inside and ctx.stance == PerceptionRules.Stance.SPRINT:
		out.append(Behaviour.SPRINT)
	if ctx.zone == Zone.STAFF or ctx.zone == Zone.BACKROOM:
		out.append(Behaviour.STAFF_SIDE)
	if ctx.carrying_bag or ctx.interaction == Interaction.TAMPER:
		out.append(Behaviour.BAG_OR_LOCK)
	if ctx.interaction == Interaction.CASH:
		out.append(Behaviour.CASH)
	if p.alarm_level > 0 and ctx.alert_level >= p.alarm_level:
		out.append(Behaviour.ALARM)
	return out


static func factor_of(p: Params, b: Behaviour) -> float:
	match b:
		Behaviour.LOITER:
			return p.loiter_factor
		Behaviour.SNEAK:
			return p.sneak_factor
		Behaviour.SPRINT:
			return p.sprint_factor
		Behaviour.STAFF_SIDE:
			return p.staff_factor
		Behaviour.BAG_OR_LOCK:
			return p.bag_or_lock_factor
		Behaviour.CASH:
			return p.cash_factor
		Behaviour.ALARM:
			return p.alarm_factor
	return 0.0


static func behaviour_name(b: Behaviour) -> StringName:
	return BEHAVIOUR_NAMES[b] if b >= 0 and b < BEHAVIOUR_NAMES.size() else &""


static func zone_name(z: Zone) -> StringName:
	return ZONE_NAMES[z] if z >= 0 and z < ZONE_NAMES.size() else &""


## Noktanın bölgesi: `rects` Zone -> Array[Rect2] (aynı koordinat düzleminde). Kenar dahil; hiçbiri değilse dışarı.
## Bölgeler örtüşmez (IS-023); örtüşürse personel/arka oda müşteri bölgesine baskındır.
static func zone_at(pos: Vector2, rects: Dictionary) -> Zone:
	var found: Zone = Zone.OUTSIDE
	for z: Zone in [Zone.CUSTOMER, Zone.STAFF, Zone.BACKROOM]:
		for r: Rect2 in rects.get(z, []):
			if r.grow(0.001).has_point(pos):
				found = z
	return found


## ON-03: tutma/yakalama kararında oyuncunun konumu hızı yönünde `min(RTT/2, cap)` ileri alınır.
static func predicted_position(pos: Vector2, velocity: Vector2, rtt_ms: float, cap_sec: float) -> Vector2:
	var lead: float = clampf(maxf(rtt_ms, 0.0) * 0.0005, 0.0, maxf(cap_sec, 0.0))
	return pos + velocity * lead


## Temas süresi bir adım: menzilde (`dist <= reach`) birikir, dışında sıfırlanır.
static func contact_step(contact: float, dist: float, reach: float, delta: float) -> float:
	return contact + maxf(delta, 0.0) if dist <= reach else 0.0


## Tutma penceresi: ilk tutmada `first`, sonrakilerde `repeat` (GDD §9.3: 6 sn, ikinci kez 3 sn).
static func hold_window(times_held_before: int, first: float, repeat: float) -> float:
	return first if times_held_before <= 0 else repeat


## İstemci göstergesi: alarm kilidi ya da ölçer ≥ tespit → "!"; ölçer ≥ "?" eşiği → "?"; gösterilen "?",
## ölçer `notice_at − bubble_hysteresis` altına inene kadar kalır (eşik kenarında titremez).
static func bubble(p: Params, meter: float, alarmed: bool, previous: Bubble) -> Bubble:
	if alarmed or meter >= p.detect_at - SuspicionMeter.EPSILON:
		return Bubble.ALARM
	if meter >= p.notice_at - SuspicionMeter.EPSILON:
		return Bubble.NOTICE
	if previous != Bubble.NONE and meter >= p.notice_at - p.bubble_hysteresis:
		return Bubble.NOTICE
	return Bubble.NONE
