class_name Population
extends Node
## Mekân nüfusu üreticisi (US-016 AC1/AC5/AC8; GDD §9.2; oyun-yz tur 2 #13, #20; mimari.md S2, S11). Seviyede
## `NPCs` altında durağan düğüm; kardeşleri `Owner` (StoreOwner), `StoreAlert` ve `PopulationSpawner`
## (MultiplayerSpawner, spawn_path = NPCs). Yalnız host üretir/siler; istemciler spawner'dan alır (geç katılan
## mevcut sivilleri kabulde görür). Zamanlama ve planlar `PopulationRules.Schedule`'da (tohumlu, belirlenimci),
## nokta rezervasyonu `SpotRegistry`'de; ayarlar `data/npc/population.tres`.
##
## - Üretim: müşteri sokak noktasında (`customer_spawn_marker`), raf noktaları siparişin zarlarıyla boş noktalardan
##   seçilip tutulur; yoldan geçen sokak rotasının ilk noktasında. Ad `Customer<n>` / `Passerby<n>` (n tek sayaç).
## - Sınırlar: içeride (etkin) müşteri ≤ `customer_max`, sokakta ≤ `passerby_max`; toplam NPC (sahip + siviller +
##   mahalleli) + komşu payı ≤ `max_npcs`; uyarı ≥ `pause_alert_level` iken yeni sivil gelmez. Uyarı yöneticisinin
##   komşusu tavanda yer açılana kadar bekler (`StoreAlert.room_query`).
## - Örtü: sahibin duyusuna içerideki müşteri sayısı bağlanır (`CivilianSenses.customers_query`; ×0,5 kuralı core'da);
##   sivil tanıklar sahibin oyalanma sayacını okur.
## - Dönüşüm (oyun-yz #20): sahip bağırınca (`OwnerBrain.shouted`) sahibe `convert_radius` içindeki yoldan geçenler
##   silinir, aynı yerde mahalleli üretilir (`StoreAlert.spawn_chaser_at`; NPC sayısı değişmez).
## - Kapatma: `active = false` (fikstür; ör. tests/fixtures/store_a_quiet.tscn, store_a_nopop.tscn) ya da sahip
##   etkin değilse hiç üretmez.
## Döküm "population" (S6 eki): her peer'da {npcs: [{name, role, state, events}], names (sıralı), seen, events,
## event_peers}; host'ta
## ayrıca {customers_inside, customers_spawned, passersby_spawned, served, tells, flees, looks, converted, cancelled,
## arrivals}.

const CIVILIAN_SCENE := "res://entities/npc/civilian/civilian.tscn"
const TUNING_PATH := "res://data/npc/population.tres"
const DUMP_KEY := "population"
const MAX_EVENTS := 128
const MAX_SEEN := 128

@export var tuning: PopulationTuning
@export var owner_path: NodePath = ^"../Owner"
@export var alert_path: NodePath = ^"../StoreAlert"
@export var spawner_path: NodePath = ^"../PopulationSpawner"
## false: testler `step()`'i elle sürer (sivilleri de).
@export var auto_step: bool = true
## false: hiç üretmez (fikstür).
@export var active: bool = true

## Host: nokta kayıtları ve zamanlayıcı.
var registry := SpotRegistry.new()
var schedule: PopulationRules.Schedule = null

var _owner: StoreOwner = null
var _alert: StoreAlert = null
var _spawner: MultiplayerSpawner = null
var _scene: PackedScene = null
var _serial: int = 0
## Host: sıra numarası -> sipariş/raf noktaları (spawn_function okur).
var _pending: Dictionary = {}
## Her peer'da: görülen sivil adları ve olayları (sırayla).
var _seen: Array[String] = []
var _events: Array[StringName] = []
var _event_peers: Array[int] = []
## Host sayaçları.
var _stats: Dictionary = {"customers_spawned": 0, "passersby_spawned": 0, "served": 0, "tells": 0, "flees": 0,
	"looks": 0, "converted": 0}


func _ready() -> void:
	if tuning == null:
		tuning = load(TUNING_PATH) as PopulationTuning
	_owner = get_node_or_null(owner_path) as StoreOwner
	_alert = get_node_or_null(alert_path) as StoreAlert
	_spawner = get_node_or_null(spawner_path) as MultiplayerSpawner
	_scene = load(CIVILIAN_SCENE) as PackedScene
	if _spawner != null:
		_spawner.spawn_function = _spawn_civilian
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, dump_state)
	if not _enabled():
		return
	var windows: int = _owner.senses().marker_names(tuning.window_prefix).size()
	schedule = PopulationRules.Schedule.new(tuning.rules_params(windows, _owner.owner_tuning.customer_sec),
		tuning.population_seed)
	_owner.senses().customers_query = customers_inside
	_owner.brain().shouted.connect(_on_owner_shouted)
	if _alert != null:
		_alert.room_query = has_room


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


## Bir adım (yalnız host): zamanlayıcı → üretim; elle sürülüyorsa (auto_step false) siviller de adımlanır.
func step(delta: float) -> void:
	if not _enabled():
		return
	for order: PopulationRules.Order in schedule.tick(delta, counts()):
		_spawn(order)
	if not auto_step:
		for civ: Civilian in civilians():
			civ.auto_step = false
			civ.step(delta)


## Anlık sayımlar (zamanlayıcı girdisi).
func counts() -> PopulationRules.Counts:
	var c := PopulationRules.Counts.new()
	for civ: Civilian in civilians():
		if civ.is_customer():
			c.customers += 1
		else:
			c.passersby += 1
	c.npcs = npc_count()
	c.alert_level = Game.alert_level()
	return c


## Bütün NPC'ler (etkin sahip + siviller + mahalleli; silinmeyi bekleyenler hariç).
func npc_count() -> int:
	var n: int = 0
	var root: Node = get_parent()
	if root == null:
		return 0
	for child: Node in root.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Civilian or child is Chaser:
			n += 1
		elif child is StoreOwner and (child as StoreOwner).active:
			n += 1
	return n


## Tavanda yer var mı (uyarı yöneticisinin komşusu için; komşu payı dahil değil).
func has_room() -> bool:
	return npc_count() < tuning.max_npcs


## Yaşayan siviller (ağaçtaki, silinmeyi beklemeyen).
func civilians() -> Array[Civilian]:
	var out: Array[Civilian] = []
	var root: Node = get_parent()
	if root == null:
		return out
	for child: Node in root.get_children():
		if child is Civilian and not child.is_queued_for_deletion():
			out.append(child as Civilian)
	return out


## İçerideki müşteri sayısı (örtü; keşif boşta tetiği): bölgesi içeri olan müşteriler.
func customers_inside() -> int:
	var n: int = 0
	if _owner == null:
		return 0
	var senses: CivilianSenses = _owner.senses()
	for civ: Civilian in civilians():
		if civ.is_customer() and CivilianRules.is_inside(senses.zone_of(civ.global_position)):
			n += 1
	return n


## Host: boş kuyruk noktasını tutar (sıra: QueueSpot1, QueueSpot2 …); yoksa boş.
func claim_queue(serial: int) -> StringName:
	return registry.claim_first(_spots(tuning.queue_prefix), serial)


## İşaret dizisi adları (`<önek>1..N`); dizi yoksa ve önek tek bir işaretse o (ör. fikstürde tek raf noktası).
func _spots(prefix: StringName) -> Array[StringName]:
	var senses: CivilianSenses = _owner.senses()
	var out: Array[StringName] = senses.marker_names(prefix)
	if out.is_empty() and senses.marker_position(prefix).is_finite():
		out.append(prefix)
	return out


## Host: sivilin tuttuğu noktaları bırakır.
func release_spots(serial: int) -> void:
	registry.release(serial)


func dump_state() -> Dictionary:
	var rows: Array = []
	var names: Array[String] = []
	for civ: Civilian in civilians():
		rows.append(civ.dump_row())
		names.append(String(civ.name))
	names.sort()
	var out := {
		"active": active,
		"npcs": rows,
		"names": names,
		"seen": _seen.duplicate(),
		"events": _events.duplicate(),
		"event_peers": _event_peers.duplicate(),
	}
	if _host_side() and schedule != null:
		out.merge(_stats.duplicate())
		for civ: Civilian in civilians():
			if civ.brain().served:
				out["served"] = int(out["served"]) + 1  # servis olmuş, henüz çıkmamış
		out["customers_inside"] = customers_inside()
		out["cancelled"] = schedule.cancelled.size()
		var arrivals: Array = []
		for o: PopulationRules.Order in schedule.spawned:
			arrivals.append([PopulationRules.role_name(o.role), snappedf(o.at, 0.01)])
		out["arrivals"] = arrivals
	return out


func _spawn(order: PopulationRules.Order) -> void:
	if _spawner == null or _scene == null:
		return
	_serial += 1
	var spots: Array[StringName] = []
	var at: Vector2 = Vector2.INF
	var senses: CivilianSenses = _owner.senses()
	if order.role == PopulationRules.Role.CUSTOMER:
		var free: Array[StringName] = registry.free_of(_spots(tuning.shop_prefix))
		for roll: float in order.picks:
			var spot: StringName = PopulationRules.pick(free, roll)
			if spot.is_empty() or not registry.claim(spot, _serial):
				continue
			free.erase(spot)
			spots.append(spot)
		at = senses.marker_position(tuning.customer_spawn_marker)
		_stats["customers_spawned"] = int(_stats["customers_spawned"]) + 1
	else:
		var route: Array[StringName] = senses.marker_names(tuning.route_prefix)
		at = senses.marker_position(route[0]) if not route.is_empty() else Vector2.INF
		_stats["passersby_spawned"] = int(_stats["passersby_spawned"]) + 1
	if not at.is_finite():
		registry.release(_serial)
		push_warning("Population: doğma işareti yok; sivil üretilmedi")
		return
	_pending[_serial] = {"order": order, "spots": spots}
	var root: Node2D = get_parent() as Node2D
	_spawner.spawn({"n": _serial, "role": int(order.role), "pos": root.to_local(at) if root != null else at})
	_pending.erase(_serial)


## Spawner'ın spawn_function'ı (host'ta spawn() içinde, istemcide paket gelince).
func _spawn_civilian(data: Variant) -> Node:
	var d: Dictionary = data if data is Dictionary else {}
	var civ: Civilian = _scene.instantiate() as Civilian
	var n: int = int(d.get("n", 0))
	civ.serial = n
	civ.tuning = tuning  # nüfus profili (fikstür kendi profilini verebilir); her peer'da aynı
	civ.role = int(d.get("role", PopulationRules.Role.CUSTOMER))
	civ.name = "%s%d" % ["Passerby" if civ.role == PopulationRules.Role.PASSERBY else "Customer", n]
	if d.get("pos") is Vector2:
		civ.position = d["pos"]
	if _host_side() and _pending.has(n):
		var p: Dictionary = _pending[n]
		civ.order = p["order"] as PopulationRules.Order
		civ.shop_spots = p["spots"]
		civ.population = self
		civ.store_owner = _owner
		civ.ready.connect(_on_civilian_ready.bind(civ), CONNECT_ONE_SHOT)
	civ.event_raised.connect(_on_civilian_event)
	if _seen.size() < MAX_SEEN:
		_seen.append(String(civ.name))
	return civ


func _on_civilian_ready(civ: Civilian) -> void:
	civ.senses().loiter_query = _owner.senses().loiter_time
	civ.brain().gone.connect(_on_civilian_gone.bind(civ), CONNECT_ONE_SHOT)


func _on_civilian_gone(civ: Civilian) -> void:
	if not is_instance_valid(civ):
		return
	var b: CivilianBrain = civ.brain()
	if b.served:
		_stats["served"] = int(_stats["served"]) + 1
	_stats["looks"] = int(_stats["looks"]) + b.looks
	_despawn(civ)


func _despawn(civ: Civilian) -> void:
	registry.release(civ.serial)
	civ.queue_free()  # spawner istemcilerde de siler


func _on_civilian_event(_civ: Civilian, kind: StringName, peer_id: int) -> void:
	if _events.size() < MAX_EVENTS:
		_events.append(kind)
		_event_peers.append(peer_id)
	if not _host_side():
		return
	if String(kind).ends_with("_tell"):
		_stats["tells"] = int(_stats["tells"]) + 1
	elif String(kind).ends_with("_flee"):
		_stats["flees"] = int(_stats["flees"]) + 1


## Sahip bağırdı (host): menzildeki yoldan geçenler mahalleliye dönüşür (oyun-yz #20).
func _on_owner_shouted(_late: bool) -> void:
	if _alert == null or tuning.convert_radius <= 0.0:
		return
	var at: Vector2 = _owner.global_position
	for civ: Civilian in civilians():
		if civ.is_customer() or civ.global_position.distance_to(at) > tuning.convert_radius:
			continue
		var pos: Vector2 = civ.global_position
		_stats["looks"] = int(_stats["looks"]) + civ.brain().looks
		_despawn(civ)
		if _alert.spawn_chaser_at(pos, at) != null:
			_stats["converted"] = int(_stats["converted"]) + 1


func _enabled() -> bool:
	return active and _host_side() and tuning != null and _owner != null and _owner.active and _spawner != null


## Host ya da çevrimdışı (S2; Net bayraklarından, Game ile aynı kalıp).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
