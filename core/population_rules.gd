class_name PopulationRules
extends RefCounted
## Mekân nüfusu kuralları (US-016 AC1/AC2/AC4/AC5; GDD §9.2 tablo; oyun-yz tur 2 #13). Düğümsüz: geliş zamanları,
## üst sınırlar, müşteri/yoldan geçen planları ve sokak rotası hesabı burada; sahne ağacını bilmez (KR-003).
## Nüfus üreticisi (`entities/npc/population.gd`, yalnız host) her adımda `Schedule.tick` çağırır, dönen siparişleri
## üretir. Belirlenimcilik (I6): aynı tohum + aynı sayımlar → aynı geliş anları ve planlar (tek RNG, sabit sıra:
## önce müşteri, sonra yoldan geçen; plan geliş anında aynı RNG'den çekilir).
##
## - Müşteri: ilk geliş [first_min, first_max], sonra aralık ± sapma. Geliş anında içeride (etkin müşteri) üst
##   sınırdaysa, NPC tavanı doluysa ya da uyarı `pause_alert_level` ve üstündeyse gelmez, rota iptal: bir sonraki
##   aralık çekilir.
## - Yoldan geçen: aralık ± sapma (ilk geliş de bir aralık), sokakta üst sınır; aynı iptal kuralı.
## - NPC tavanı: toplam NPC (sahip, müşteri, yoldan geçen, mahalleli) + komşuya ayrılan yer < `max_npcs`.
## - Müşteri planı: kalış [stay_min, stay_max]; raf noktası 1-2 ([min_spots, max_spots]), her biri
##   [shop_min, shop_max] sn; iki nokta + servis + yürüme payı kalışı aşıyorsa tek nokta.
## - Yoldan geçen planı: her cam parçası için `look_chance` olasılıkla `look_sec` içeri bakış.

enum Role { CUSTOMER, PASSERBY }

const ROLE_NAMES: Array[StringName] = [&"customer", &"passerby"]


## Ayarlar (değer nesnesi; `data/npc/population.tres` doldurur, varsayılanlar nötr).
class Params:
	extends RefCounted
	var customer_first_min: float = 0.0
	var customer_first_max: float = 0.0
	var customer_interval: float = 0.0
	var customer_jitter: float = 0.0
	var customer_max: int = 0
	var stay_min: float = 0.0
	var stay_max: float = 0.0
	var min_spots: int = 1
	var max_spots: int = 1
	var shop_min: float = 0.0
	var shop_max: float = 0.0
	var serve_sec: float = 0.0
	var walk_margin_sec: float = 0.0
	var passerby_interval: float = 0.0
	var passerby_jitter: float = 0.0
	var passerby_max: int = 0
	var look_chance: float = 0.0
	var look_sec: float = 0.0
	## Cam parçası (WindowLook*) sayısı: yoldan geçen planı bu kadar bakış zarı taşır.
	var window_count: int = 0
	var max_npcs: int = 0
	## Komşuya (mahalleli) ayrılan yer: nüfus tavanın bu kadar altında durur.
	var reserve: int = 0
	## Bu uyarı kademesinden itibaren yeni sivil gelmez (0 = hiç durmaz).
	var pause_alert_level: int = 0


## Anlık sayımlar (üretici her adımda doldurur).
class Counts:
	extends RefCounted
	var customers: int = 0
	var passersby: int = 0
	## Bütün NPC'ler (sahip + siviller + mahalleli).
	var npcs: int = 0
	var alert_level: int = 0


## Bir üretim siparişi: rol + plan + geliş anı.
class Order:
	extends RefCounted
	var role: Role = Role.CUSTOMER
	var at: float = 0.0
	## Müşteri: kalış (sn), raf noktası süreleri (sn) ve seçim zarları (0..1, `pick` ile boş noktaya çevrilir).
	var stay_sec: float = 0.0
	var dwell: Array[float] = []
	var picks: Array[float] = []
	## Yoldan geçen: cam başına bakış (true = bakar).
	var looks: Array[bool] = []


## Geliş zamanlayıcısı (tohumlu).
class Schedule:
	extends RefCounted
	var params: Params
	var clock: float = 0.0
	var next_customer: float = INF
	var next_passerby: float = INF
	## Üretilen ve iptal edilen gelişler (döküm, testler).
	var spawned: Array[Order] = []
	var cancelled: Array[Dictionary] = []
	var _rng := RandomNumberGenerator.new()

	func _init(p: Params, seed_value: int) -> void:
		params = p
		_rng.seed = seed_value
		if p.customer_interval > 0.0 or p.customer_first_max > 0.0:
			next_customer = _rng.randf_range(minf(p.customer_first_min, p.customer_first_max),
				maxf(p.customer_first_min, p.customer_first_max))
		if p.passerby_interval > 0.0:
			next_passerby = _interval(p.passerby_interval, p.passerby_jitter)

	## Saat `delta` ilerler; vadesi gelen gelişler için siparişler (müşteri önce). `counts` sipariş başına
	## güncellenir (aynı adımda iki geliş tavanı birlikte aşmasın).
	func tick(delta: float, counts: Counts) -> Array[Order]:
		var out: Array[Order] = []
		clock += maxf(delta, 0.0)
		if clock >= next_customer:
			if PopulationRules.may_spawn(params, counts, Role.CUSTOMER):
				var order: Order = _customer_order()
				out.append(order)
				spawned.append(order)
				counts.customers += 1
				counts.npcs += 1
			else:
				cancelled.append({"role": Role.CUSTOMER, "at": clock})
			next_customer = clock + _interval(params.customer_interval, params.customer_jitter) \
				if params.customer_interval > 0.0 else INF
		if clock >= next_passerby:
			if PopulationRules.may_spawn(params, counts, Role.PASSERBY):
				var order: Order = _passerby_order()
				out.append(order)
				spawned.append(order)
				counts.passersby += 1
				counts.npcs += 1
			else:
				cancelled.append({"role": Role.PASSERBY, "at": clock})
			next_passerby = clock + _interval(params.passerby_interval, params.passerby_jitter)
		return out

	func _interval(mean: float, jitter: float) -> float:
		var j: float = absf(jitter)
		return maxf(_rng.randf_range(mean - j, mean + j), 0.5)

	func _customer_order() -> Order:
		var o := Order.new()
		o.role = Role.CUSTOMER
		o.at = clock
		o.stay_sec = _rng.randf_range(minf(params.stay_min, params.stay_max), maxf(params.stay_min, params.stay_max))
		var lo: int = maxi(mini(params.min_spots, params.max_spots), 0)
		var hi: int = maxi(params.min_spots, params.max_spots)
		var count: int = _rng.randi_range(lo, hi)
		for i: int in count:
			o.dwell.append(_rng.randf_range(minf(params.shop_min, params.shop_max), maxf(params.shop_min, params.shop_max)))
			o.picks.append(_rng.randf())
		PopulationRules.fit_stay(o, params)
		return o

	func _passerby_order() -> Order:
		var o := Order.new()
		o.role = Role.PASSERBY
		o.at = clock
		for i: int in maxi(params.window_count, 0):
			o.looks.append(_rng.randf() < params.look_chance)
		return o


## Geliş yapılabilir mi: rol üst sınırı, NPC tavanı (komşu payı dahil) ve uyarı duraklaması.
static func may_spawn(p: Params, counts: Counts, role: Role) -> bool:
	if p.pause_alert_level > 0 and counts.alert_level >= p.pause_alert_level:
		return false
	if counts.npcs + 1 + maxi(p.reserve, 0) > p.max_npcs:
		return false
	match role:
		Role.CUSTOMER:
			return counts.customers < p.customer_max
		Role.PASSERBY:
			return counts.passersby < p.passerby_max
	return false


## İki raf noktası + servis + yürüme payı kalışı aşıyorsa noktalar sondan atılır (en az bir nokta kalır).
static func fit_stay(o: Order, p: Params) -> void:
	while o.dwell.size() > 1 and _sum(o.dwell) + p.serve_sec + p.walk_margin_sec > o.stay_sec:
		o.dwell.pop_back()
		o.picks.pop_back()


## Zar (0..1) → boş adaylardan biri (yoksa boş).
static func pick(free: Array[StringName], roll: float) -> StringName:
	if free.is_empty():
		return &""
	return free[clampi(floori(clampf(roll, 0.0, 0.999999) * free.size()), 0, free.size() - 1)]


## Sokak rotası: rota noktaları sırayla; her bakış noktası, en yakın olduğu rota parçasına parça üzerindeki
## izdüşüm sırasıyla yerleşir. Dönüş: [{"pos": Vector2, "look": int}] (look = bakış indisi, rota noktasında -1).
static func street_route(route: Array[Vector2], looks: Array[Vector2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if route.is_empty():
		return out
	## parça indisi -> [[t, bakış indisi], ...]
	var on_segment: Dictionary = {}
	for li: int in looks.size():
		var best: int = -1
		var best_d: float = INF
		var best_t: float = 0.0
		for si: int in route.size() - 1:
			var a: Vector2 = route[si]
			var b: Vector2 = route[si + 1]
			var ab: Vector2 = b - a
			var t: float = clampf((looks[li] - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d: float = looks[li].distance_to(a + ab * t)
			if d < best_d:
				best_d = d
				best = si
				best_t = t
		if best >= 0:
			if not on_segment.has(best):
				on_segment[best] = []
			(on_segment[best] as Array).append([best_t, li])
	for si: int in route.size():
		out.append({"pos": route[si], "look": -1})
		if on_segment.has(si):
			var items: Array = on_segment[si]
			items.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
			for item: Array in items:
				out.append({"pos": looks[int(item[1])], "look": int(item[1])})
	return out


## Camdan içeri bakış yönü: bakış noktasından içerinin (bölge dikdörtgenleri) en yakın noktasına birim yön; nokta
## içerideyse ya da bölge yoksa sıfır.
static func look_facing(from: Vector2, inside: Array[Rect2]) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for r: Rect2 in inside:
		var p := Vector2(clampf(from.x, r.position.x, r.end.x), clampf(from.y, r.position.y, r.end.y))
		var d: float = from.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	if not best.is_finite() or best_d <= 0.001:
		return Vector2.ZERO
	return (best - from).normalized()


static func role_name(role: int) -> StringName:
	return ROLE_NAMES[role] if role >= 0 and role < ROLE_NAMES.size() else &""


static func _sum(values: Array[float]) -> float:
	var s: float = 0.0
	for v: float in values:
		s += v
	return s
