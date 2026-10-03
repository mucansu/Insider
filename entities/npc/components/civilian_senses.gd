class_name CivilianSenses
extends Node
## Sivil gözlemcinin oyuncu bağlamı (US-008 AC1/AC3/AC7; GDD §6.1, §9.3; mimari.md S2, S4, S11). Yalnız host'ta
## anlamlıdır. Oyuncuların bölgesini (Level `Zones`: CustomerArea/StaffArea/Backroom), dükkân içi süresini
## (oyalanma), sürdürdüğü etkileşimi (`Interactable.held_by`: kasa/nakit → CASH, basılı tutulan diğerleri →
## TAMPER) ve çanta durumunu (`is_carrying_bag()` varsa) okuyup `CivilianRules` bağlamına çevirir;
## `factor_for` algı bileşeninin `factor_query`'sidir. Ön kapıdan içeri/dışarı geçişte `door_crossed` (zil) yayar.
## Konum her zaman eşitleyicinin en güncel konumu (`interaction_position()`, S7): aleyhte kararlar (AC8).
## Seviyeye yalnız S4 Level API'siyle (duck typing: `zone`, `marker`, `marker_sequence`, `props_root`) erişir.

## Yalnız host: oyuncu ön kapı eşiğinden geçti (içeri/dışarı).
signal door_crossed(peer_id: int, door_pos: Vector2)

const ZONE_NAMES := {
	CivilianRules.Zone.CUSTOMER: &"CustomerArea",
	CivilianRules.Zone.STAFF: &"StaffArea",
	CivilianRules.Zone.BACKROOM: &"Backroom",
}
## Arka oda nakdinin "alındı" sayıldığı prop yarıçapı (px; işaretten).
const CASH_PROP_RADIUS := 32.0

var tuning: CivilianTuning
var rules: CivilianRules.Params = null
## Zil sayılan kapı işareti ve yarıçapı (0 = zil yok).
var bell_marker: StringName = &""
var bell_radius: float = 0.0
## Test/teşhis: RTT (ms) yerine bu değer kullanılır (< 0 = Net'ten ölçülen).
var rtt_override_ms: int = -1
## İçerideki müşteri sayısı sorgusu (US-016 örtü; func() -> int). Yalnız sahibin duyusuna nüfus üreticisi bağlar;
## boşsa 0 (örtü yok).
var customers_query: Callable = Callable()
## Oyalanma süresi sorgusu (US-016; func(peer_id) -> float): sivil tanıklar sahibin sayacını okur (oyuncunun dükkân
## içi süresi tanığın ne zaman doğduğuna bağlı olmasın). Boşsa bu duyunun kendi sayacı.
var loiter_query: Callable = Callable()

var _level: Node = null
var _zones: Dictionary = {}
var _loiter: Dictionary = {}
var _inside: Dictionary = {}
## İşaret adı -> başta yanında duran prop'lar (prop_taken_near).
var _watched: Dictionary = {}


## Seviye (Level API'li ata) ve kurallar.
func setup(level: Node, civilian: CivilianTuning, perception: PerceptionTuning) -> void:
	_level = level
	tuning = civilian
	rules = civilian.rules_params(perception)
	_zones = zone_rects(level)


## Bölge dikdörtgenleri (global): Zone -> Array[Rect2]. Bölge yoksa boş (her yer dışarı).
static func zone_rects(level: Node) -> Dictionary:
	var out: Dictionary = {}
	if level == null or not level.has_method(&"zone"):
		return out
	for z: CivilianRules.Zone in ZONE_NAMES:
		var area: Area2D = level.call(&"zone", ZONE_NAMES[z]) as Area2D
		if area == null:
			continue
		var rects: Array[Rect2] = []
		for node: Node in area.find_children("*", "CollisionShape2D", false, false):
			var cs: CollisionShape2D = node as CollisionShape2D
			var box: RectangleShape2D = cs.shape as RectangleShape2D
			if box != null:
				var size: Vector2 = box.size * cs.global_scale.abs()
				rects.append(Rect2(cs.global_position - size * 0.5, size))
		out[z] = rects
	return out


## Bir adım: oyuncuların bölgesi, oyalanma süresi ve ön kapı geçişi.
func step(delta: float) -> void:
	var door: Vector2 = marker_position(bell_marker)
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if not node.has_method(&"interaction_position"):
			continue
		var peer_id: int = node.get_multiplayer_authority()
		var pos: Vector2 = position_of(node as Node2D)
		var inside: bool = CivilianRules.is_inside(zone_of(pos))
		if inside:
			_loiter[peer_id] = float(_loiter.get(peer_id, 0.0)) + maxf(delta, 0.0)
		var was: Variant = _inside.get(peer_id)
		_inside[peer_id] = inside
		if was != null and bool(was) != inside and door.is_finite() and bell_radius > 0.0 \
				and pos.distance_to(door) <= bell_radius:
			door_crossed.emit(peer_id, door)


## İçerideki müşteri sayısı (US-016 örtü ve keşif; sorgu yoksa 0).
func customers_inside() -> int:
	return int(customers_query.call()) if customers_query.is_valid() else 0


func zone_of(pos: Vector2) -> CivilianRules.Zone:
	return CivilianRules.zone_at(pos, _zones)


func loiter_time(peer_id: int) -> float:
	if loiter_query.is_valid():
		return float(loiter_query.call(peer_id))
	return float(_loiter.get(peer_id, 0.0))


## Oyalanma sayacını sıfırlar (US-010 SATIN AL).
func reset_loiter(peer_id: int) -> void:
	_loiter[peer_id] = 0.0


## Hedefin bu andaki bağlamı.
func context_for(target: Node) -> CivilianRules.Context:
	var ctx := CivilianRules.Context.new()
	var peer_id: int = target.get_multiplayer_authority()
	ctx.zone = zone_of(position_of(target as Node2D))
	ctx.stance = Perception.stance_of(target)
	ctx.interaction = interaction_of(peer_id)
	ctx.carrying_bag = target.has_method(&"is_carrying_bag") and bool(target.call(&"is_carrying_bag"))
	ctx.alert_level = Game.alert_level()
	ctx.loiter_time = loiter_time(peer_id)
	ctx.customers_inside = customers_inside()
	return ctx


## Algının `factor_query`'si: tutulan/yakalanan oyuncu 0 (hedef değil).
func factor_for(target: Node) -> float:
	if target.has_method(&"is_free") and not bool(target.call(&"is_free")):
		return 0.0
	return CivilianRules.factor(rules, context_for(target))


func behaviour_for(target: Node) -> CivilianRules.Behaviour:
	return CivilianRules.behaviour(rules, context_for(target))


## Oyuncunun sürdürdüğü etkileşimin türü (host'taki `busy_by`).
func interaction_of(peer_id: int) -> CivilianRules.Interaction:
	var item: Interactable = Interactable.held_by(get_tree(), peer_id)
	if item == null:
		return CivilianRules.Interaction.NONE
	var def: Variant = item.get_parent().get(&"def") if item.get_parent() != null else null
	if def is PropDef and (def as PropDef).cash_value > 0:
		return CivilianRules.Interaction.CASH
	return CivilianRules.Interaction.TAMPER if item.hold_time > 0.0 else CivilianRules.Interaction.NONE


## `interaction_actors` grubundaki o peer'ın oyuncusu (yoksa null).
func player(peer_id: int) -> Node2D:
	if peer_id == 0:
		return null
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == peer_id and node is Node2D:
			return node as Node2D
	return null


## Host'un bildiği en güncel konum (S7); yoksa çizilen konum.
static func position_of(target: Node2D) -> Vector2:
	if target == null:
		return Vector2.INF
	if target.has_method(&"interaction_position"):
		var pos: Variant = target.call(&"interaction_position")
		if pos is Vector2:
			return pos
	return target.global_position


## ON-03: temas kararında konum hızı yönünde min(RTT/2, cap) ileri alınır (host'ta RTT o peer'ın ping'i).
func predicted(target: Node2D, cap_sec: float) -> Vector2:
	if target == null:
		return Vector2.INF
	var vel: Variant = target.get(&"velocity")
	var velocity: Vector2 = vel if vel is Vector2 else Vector2.ZERO
	var rtt: int = rtt_of(target.get_multiplayer_authority())
	return CivilianRules.predicted_position(position_of(target), velocity, float(rtt), cap_sec)


## Host'tan o peer'a RTT (ms; bilinmiyorsa 0).
func rtt_of(peer_id: int) -> int:
	if rtt_override_ms >= 0:
		return rtt_override_ms
	return maxi(Net.get_ping_ms(peer_id), 0) if Net.is_online() else 0


## İşaret konumu (global); yoksa INF.
func marker_position(marker_name: StringName) -> Vector2:
	if _level == null or marker_name.is_empty() or not _level.has_method(&"marker"):
		return Vector2.INF
	var node: Node2D = _level.call(&"marker", marker_name) as Node2D
	return node.global_position if node != null else Vector2.INF


## Sıralı işaret dizisinin adları (`<önek>1..N`; Level `marker_sequence`; US-016 sokak rotası, cam önleri).
func marker_names(prefix: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _level == null or prefix.is_empty() or not _level.has_method(&"marker_sequence"):
		return out
	for node: Variant in _level.call(&"marker_sequence", prefix):
		if node is Node:
			out.append(StringName((node as Node).name))
	return out


## İçerinin (müşteri, personel, arka oda bölgeleri) dikdörtgenleri (global; US-016 camdan bakış yönü).
func inside_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for z: Variant in _zones:
		for r: Rect2 in _zones[z]:
			out.append(r)
	return out


## Ajanda çözümleyicisi: `<ad>1..N` dizisi varsa onun konumları, yoksa tek işaret.
func marker_positions(marker_name: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _level == null:
		return out
	if _level.has_method(&"marker_sequence"):
		for node: Variant in _level.call(&"marker_sequence", marker_name):
			if node is Node2D:
				out.append((node as Node2D).global_position)
	if out.is_empty():
		var single: Vector2 = marker_position(marker_name)
		if single.is_finite():
			out.append(single)
	return out


## İşaretin yanında başlayan prop alındı mı (arka oda nakdi): çanta (US-012 Bag, duck typing `is_carried()`)
## taşınıyor ya da yerinden oynamışsa; diğer prop'larda bool `taken`/`emptied` alanı. Prop'lar ilk sorguda
## işaretin yanındakiler olarak hatırlanır (çanta taşınınca işaretten uzaklaşır).
func prop_taken_near(marker_name: StringName) -> bool:
	var at: Vector2 = marker_position(marker_name)
	if not at.is_finite():
		return false
	if not _watched.has(marker_name):
		_watched[marker_name] = _props_near(at)
	for prop: Node2D in _watched[marker_name]:
		if not is_instance_valid(prop):
			continue
		if prop.has_method(&"is_carried"):
			if bool(prop.call(&"is_carried")) or prop.global_position.distance_to(at) > CASH_PROP_RADIUS:
				return true
			continue
		for flag: StringName in [&"taken", &"emptied"]:
			var v: Variant = prop.get(flag) if flag in prop else null
			if v is bool and bool(v):
				return true
	return false


func _props_near(at: Vector2) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if _level == null or not _level.has_method(&"props_root"):
		return out
	var props: Node = _level.call(&"props_root") as Node
	if props == null:
		return out
	for child: Node in props.get_children():
		var prop: Node2D = child as Node2D
		if prop != null and prop.global_position.distance_to(at) <= CASH_PROP_RADIUS:
			out.append(prop)
	return out


## Tespit kaydı (AC8; muhafiz-davranisi §4): bant, kip, aydınlık, "?" ve tespit anı, RTT, mesafe, davranış;
## `flagged` = ağ gecikmesi kaynaklı olabilir (t_detect − t_question < 0,5 + RTT).
func detection_record(peer_id: int, obs: Perception.Observation, observer: Vector2, t_question: float,
		t_detect: float) -> Dictionary:
	var target: Node2D = player(peer_id)
	var rtt_ms: int = rtt_of(peer_id)
	var record := {
		"peer": peer_id,
		"t_question": t_question,
		"t_detect": t_detect,
		"rtt_ms": rtt_ms,
		"band": -1,
		"mode": -1,
		"lit": true,
		"dist_px": -1.0,
		"behaviour": &"",
		"zone": &"",
	}
	if obs != null:
		record["band"] = int(obs.band)
		record["mode"] = int(obs.stance)
		record["lit"] = not obs.in_dark
		record["dist_px"] = observer.distance_to(obs.position)
	if target != null:
		record["behaviour"] = CivilianRules.behaviour_name(behaviour_for(target))
		record["zone"] = CivilianRules.zone_name(zone_of(position_of(target)))
	record["flagged"] = t_question < 0.0 or t_detect - t_question < 0.5 + rtt_ms / 1000.0
	return record
