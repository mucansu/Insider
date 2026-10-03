class_name NpcMover
extends Node
## NPC gezinme bileşeni (US-008; mimari.md S4 eki, S11): yalnız host'ta. Hedefe NavigationServer2D yoluyla gider;
## beyin her adımda `desired_velocity()` okur, kök gövde hızı uygular (move_and_slide). Seviyeye yalnız S4 Level
## API'siyle (duck typing: `navigation_region`, `props_root`, `door_link`) erişir.
##
## - Harita hazır olana kadar (yineleme kimliği 0: ilk ~5 fizik karesi) bekler, yol sormaz.
## - Kapalı kapı: kapı bağı kapalıyken yol kapıdan geçmez (Door bağı durumuna bağlar). Hedefe yol yoksa ya da yol
##   hedefe varmıyorsa en uygun kapalı kapıya (NPC → kapı → hedef toplamı en kısa) yürür, kapının menzilinde
##   Interactable host API'siyle (`host_use_by_npc`) açar, sonra yeniden yol sorar.
## - Yol da kapı da yoksa `failed()` true olur (NPC durur, duvara yüklenmez; REPATH_SEC aralıkla yeniden dener):
##   beyin bunu "vardı" sayıp devam eder (I7: donmaz).
## - Yol yenileme NPC başına küçük bir zaman kaydırmasıyla dağıtılır (aynı karede toplu sorgu olmasın); hedefe
##   varmayan yol "kısmi" sayılmaz, `failed` olur ve `path_failed` ile beyne bildirilir.
## - Kapı bağı üzerindeyken (NPC gezinme çokgeninin dışında) yol yenilenmez: aksi halde en yakın çokgen noktası
##   geri tarafta kalıp NPC kapı eşiğinde ileri geri salınır.
## IS-087 ekleri (yalnız host):
## - Kısa yol (`door_shortcut`): hedefe açık bir yol olsa da kapalı bir kapıyı açarak giden yol belirgin kısaysa
##   (kazanç ≥ SHORTCUT_MIN_PX ya da ≥ SHORTCUT_RATIO × açık yol) kapıyı açarak gider (sahip arka kapı açıkken
##   caddeden dolaşmaz). Maliyet gezinme yolu uzunluklarıyla (NPC → kapı ucu + bağ + öbür uç → hedef).
## - Arkasından kapatma (`close_behind`): listedeki kapı adlarından birinin eşiğini geçince `close_delay` sn sonra
##   (hâlâ menzildeyken; kanat boşalana kadar yeniden dener) kapıyı `host_close_by_npc` ile kapatır;
##   `close_enabled` false iken (sahip alarmda) kapatmaz.
## - Kendi kapı sesi: açma/kapama, kardeş `Hearing`'in `ignore_own`'u içinde yapılır (NPC kendi kapı sesini duymaz).

## Yalnız host: hedefe yol bulunamadı (kapı da yok); NPC durur.
signal path_failed(target: Vector2)

## Yol yenileme aralığı (sn) ve hedef bu kadar kayınca yeniden sorma (px).
const REPATH_SEC := 0.5
## NPC başına yenileme kaydırmasının üst sınırı (sn; düğüm adından belirlenimci).
const REPATH_SPREAD := 0.125
const REPATH_MOVE := 16.0
## Ara noktaya varış (px).
const WAYPOINT_PX := 4.0
## Yolun son noktası hedefe bu kadar yakınsa "hedefe varan yol" (px).
const PATH_ARRIVE_PX := 32.0
## Kapıyı açma mesafesi (px; kapı menzili 40 + S2 payı içinde kalır).
const DOOR_REACH := 36.0
## Çokgenden bu kadar uzaktaysa bağ üzerinde sayılır (px).
const OFF_MESH_PX := 3.0
## Kısa yol eşikleri (IS-087 AC3): kazanç en az bu kadar px ya da açık yolun bu oranı.
const SHORTCUT_MIN_PX := 160.0
const SHORTCUT_RATIO := 0.4
## Eşik geçişi: kapı ekseni boyunca bu kadar içinde (px) taraf değişimi geçiş sayılır.
const CROSS_ALONG_PX := 24.0
## Arkasından kapatma: geçişten sonra en çok bu kadar sn yeniden denenir.
const CLOSE_GIVE_UP_SEC := 3.0
const DOOR_NOISE_KIND := &"door"
const HEARING_NODE := ^"Hearing"

## Kapalı kapıyı açarak giden kısa yolu seç (IS-087 AC3; sahip).
var door_shortcut: bool = false
## Arkasından kapatılan kapıların adları (Props altındaki düğüm adı; IS-087 AC2) ve gecikme (sn).
var close_behind: Array[StringName] = []
var close_delay: float = 0.6
## false: arkasından kapatma beklemede (beyin alarmda kapatmaz).
var close_enabled: bool = true

var _target: Vector2 = Vector2.INF
var _speed: float = 0.0
var _stop: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _index: int = 0
var _repath_left: float = 0.0
var _path_target: Vector2 = Vector2.INF
var _failed: bool = false
var _spread: float = -1.0
var _door: Node2D = null
## Seçilen kapının NPC tarafındaki bağ ucu.
var _door_near: Vector2 = Vector2.INF
## Arkasından kapatma: kapı adı -> son taraf (±1); kapı adı -> geçişten beri geçen süre (sn).
var _door_side: Dictionary = {}
var _close_wait: Dictionary = {}
## Teşhis (döküm/test): açılan, kısa yol için seçilen ve arkasından kapatılan kapı sayısı.
var doors_opened: int = 0
var shortcuts: int = 0
var doors_closed: int = 0


## Hedefe `speed` px/sn ile git; `stop_distance` içinde varılmış sayılır.
func move_to(target: Vector2, speed: float, stop_distance: float = 0.0) -> void:
	if not target.is_finite():
		stop()
		return
	_speed = maxf(speed, 0.0)
	_stop = maxf(stop_distance, 0.0)
	if not _target.is_finite() or _target.distance_to(target) > REPATH_MOVE:
		_repath_left = 0.0
		_failed = false
	_target = target


func stop() -> void:
	_target = Vector2.INF
	_path = PackedVector2Array()
	_door = null
	_failed = false


func target() -> Vector2:
	return _target


func arrived() -> bool:
	return not _target.is_finite() or _body_pos().distance_to(_target) <= maxf(_stop, WAYPOINT_PX)


## Hedefe gidilemiyor (yol yok, açılacak kapı yok).
func failed() -> bool:
	return _failed


## Gezinme haritası hazır mı (yineleme kimliği > 0).
func map_ready() -> bool:
	var map: RID = _map()
	return map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0


## Bu adımın istenen hızı (global px/sn). Arkasından kapatma her çağrıda (varılmış olsa da) işler.
func desired_velocity(delta: float) -> Vector2:
	_track_doors(delta)
	if arrived():
		return Vector2.ZERO
	var here: Vector2 = _body_pos()
	if not map_ready():
		return Vector2.ZERO
	_repath_left -= maxf(delta, 0.0)
	if _failed:
		if _repath_left > 0.0:
			return Vector2.ZERO
		_plan(here)  # yol yoktu: aralıkla yeniden dener (kapı açılmış, harita güncellenmiş olabilir)
		if _failed:
			return Vector2.ZERO
	var due: bool = _repath_left <= 0.0 or _path.is_empty() or _path_target.distance_to(_target) > REPATH_MOVE
	if due and (_path.is_empty() or not _on_link(here)):
		_plan(here)
	if _door != null and here.distance_to(_door.global_position) <= DOOR_REACH:
		_open(_door, here)
		_repath_left = 0.0
		return Vector2.ZERO
	while _index < _path.size() and here.distance_to(_path[_index]) <= WAYPOINT_PX:
		_index += 1
	if _index >= _path.size():
		if _door != null:
			var to_door: Vector2 = _door.global_position - here
			return to_door.limit_length(_speed) if to_door.length() > WAYPOINT_PX else Vector2.ZERO
		var rest: Vector2 = _target - here
		return rest.normalized() * minf(_speed, rest.length() / maxf(delta, 0.0001))
	var step: Vector2 = _path[_index] - here
	return step.normalized() * _speed


func _plan(here: Vector2) -> void:
	if _spread < 0.0:
		var key: String = String(get_parent().name) if get_parent() != null else ""
		_spread = float(absi(key.hash()) % 1000) / 1000.0 * REPATH_SPREAD
	_repath_left = REPATH_SEC + _spread
	_path_target = _target
	_door = null
	_index = 0
	_path = _query(here, _target)
	if _reaches(_path, _target):
		_failed = false
		if door_shortcut:
			var shortcut: Node2D = _shortcut_door(here, _target, path_length(_path))
			if shortcut != null:
				shortcuts += 1
				_door = shortcut
				_path = _query(here, _door_near)
		return
	var door: Node2D = _best_closed_door(here, _target)
	if door == null:
		var was: bool = _failed
		_failed = here.distance_to(_target) > PATH_ARRIVE_PX  # hedefe yol yok: duvara yüklenmez, durur
		_path = PackedVector2Array()
		if _failed and not was:
			path_failed.emit(_target)
		return
	_door = door
	_path = _query(here, _door_near)
	_failed = false


func _on_link(here: Vector2) -> bool:
	var map: RID = _map()
	return map.is_valid() and NavigationServer2D.map_get_closest_point(map, here).distance_to(here) > OFF_MESH_PX


func _query(from: Vector2, to: Vector2) -> PackedVector2Array:
	var map: RID = _map()
	if not map.is_valid():
		return PackedVector2Array()
	return NavigationServer2D.map_get_path(map, from, to, true)


static func _reaches(path: PackedVector2Array, to: Vector2) -> bool:
	return path.size() >= 2 and path[path.size() - 1].distance_to(to) <= PATH_ARRIVE_PX


## Hedefe yolu kesen kapalı kapılardan NPC → kapı → hedef toplamı en kısa olanı (yalnız NPC tarafından kapıya ve
## kapının öbür yanından hedefe yolu olanlar: açmak hedefe götürmeyecekse kapıya dokunulmaz).
func _best_closed_door(from: Vector2, to: Vector2) -> Node2D:
	var level: Node = _level()
	if level == null or not level.has_method(&"props_root"):
		return null
	var props: Node = level.call(&"props_root") as Node
	if props == null:
		return null
	var best: Node2D = null
	var best_cost: float = INF
	for child: Node in props.get_children():
		var door: Node2D = child as Node2D
		if door == null or not (&"is_open" in door) or bool(door.get(&"is_open")):
			continue
		if level.call(&"door_link", StringName(door.name)) == null:
			continue
		var near: Vector2 = _near_end(door, from, to)
		if not near.is_finite():
			continue  # bu kapıyı açmak hedefe götürmez
		var cost: float = from.distance_to(door.global_position) + door.global_position.distance_to(to)
		if cost < best_cost:
			best_cost = cost
			best = door
			_door_near = near
	return best


## Kapı bağının NPC tarafındaki ucu: `from`'dan yolu olan uç, öbür uçtan `to`'ya yol varsa; yoksa INF.
func _near_end(door: Node2D, from: Vector2, to: Vector2) -> Vector2:
	var link: NavigationLink2D = _level().call(&"door_link", StringName(door.name)) as NavigationLink2D
	if link == null:
		return Vector2.INF
	var ends: Array[Vector2] = [link.to_global(link.start_position), link.to_global(link.end_position)]
	for i: int in 2:
		var near: Vector2 = ends[i]
		var far: Vector2 = ends[1 - i]
		if _reaches(_query(from, near), near) and _reaches(_query(far, to), to):
			return near
	return Vector2.INF


func _open(door: Node2D, here: Vector2) -> void:
	var item: Interactable = door.get_node_or_null(^"Interactable") as Interactable
	if item != null and &"is_open" in door and not bool(door.get(&"is_open")):
		# yalnız "aç": açık kapıya dokunulmaz (kapatmaz); kendi kapı sesini duymaz (IS-087 AC1)
		if bool(_as_own_noise(door.global_position, func() -> bool: return item.host_use_by_npc(here))):
			doors_opened += 1
	_door = null


## Yol uzunluğu (px).
static func path_length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## Kısa yol (IS-087 AC3): açık yoldan (`open_length`) belirgin kısa giden kapalı kapı; yoksa null. Seçilirse
## `_door_near` NPC tarafındaki uçtur.
func _shortcut_door(from: Vector2, to: Vector2, open_length: float) -> Node2D:
	var level: Node = _level()
	if level == null or not level.has_method(&"props_root"):
		return null
	var props: Node = level.call(&"props_root") as Node
	if props == null:
		return null
	var best: Node2D = null
	var best_cost: float = INF
	var best_near: Vector2 = Vector2.INF
	for child: Node in props.get_children():
		var door: Node2D = child as Node2D
		if door == null or not (&"is_open" in door) or bool(door.get(&"is_open")):
			continue
		var link: NavigationLink2D = level.call(&"door_link", StringName(door.name)) as NavigationLink2D
		if link == null:
			continue
		var ends: Array[Vector2] = [link.to_global(link.start_position), link.to_global(link.end_position)]
		for i: int in 2:
			var near_path: PackedVector2Array = _query(from, ends[i])
			if not _reaches(near_path, ends[i]):
				continue
			var far_path: PackedVector2Array = _query(ends[1 - i], to)
			if not _reaches(far_path, to):
				continue
			var cost: float = path_length(near_path) + ends[0].distance_to(ends[1]) + path_length(far_path)
			if cost < best_cost:
				best_cost = cost
				best = door
				best_near = ends[i]
	if best == null:
		return null
	var saving: float = open_length - best_cost
	if saving < SHORTCUT_MIN_PX and saving < SHORTCUT_RATIO * open_length:
		return null
	_door_near = best_near
	return best


## Arkasından kapatma (IS-087 AC2): listedeki kapının eşiğini geçince `close_delay` sonra kapatır.
func _track_doors(delta: float) -> void:
	if close_behind.is_empty():
		return
	var level: Node = _level()
	if level == null or not level.has_method(&"props_root"):
		return
	var props: Node = level.call(&"props_root") as Node
	if props == null:
		return
	var here: Vector2 = _body_pos()
	for door_name: StringName in close_behind:
		var door: Node2D = props.get_node_or_null(NodePath(String(door_name))) as Node2D
		if door == null or not (&"is_open" in door):
			continue
		var offset: Vector2 = here - door.global_position
		var normal: Vector2 = Vector2.DOWN.rotated(door.global_rotation)
		var side: float = signf(offset.dot(normal))
		var was: float = float(_door_side.get(door_name, side))
		if side != 0.0:
			_door_side[door_name] = side
		if side != 0.0 and was != 0.0 and side != was and absf(offset.dot(normal.orthogonal())) <= CROSS_ALONG_PX:
			_close_wait[door_name] = 0.0
		if not _close_wait.has(door_name):
			continue
		var waited: float = float(_close_wait[door_name]) + maxf(delta, 0.0)
		_close_wait[door_name] = waited
		if not bool(door.get(&"is_open")) or waited > CLOSE_GIVE_UP_SEC:
			_close_wait.erase(door_name)
		elif close_enabled and waited >= close_delay and door.has_method(&"host_close_by_npc"):
			var closer := func() -> bool: return bool(door.call(&"host_close_by_npc", here))
			if bool(_as_own_noise(door.global_position, closer)):
				doors_closed += 1
				_close_wait.erase(door_name)


## Kendi eylemi: kardeş Hearing varsa eylemin kapı sesi duyulmaz (IS-087 AC1).
func _as_own_noise(at: Vector2, action: Callable) -> Variant:
	var body: Node = get_parent()
	var hearing: Node = body.get_node_or_null(HEARING_NODE) if body != null else null
	if hearing != null and hearing.has_method(&"ignore_own"):
		return hearing.call(&"ignore_own", at, DOOR_NOISE_KIND, action)
	return action.call()


func _map() -> RID:
	var level: Node = _level()
	if level != null and level.has_method(&"navigation_region"):
		var region: NavigationRegion2D = level.call(&"navigation_region") as NavigationRegion2D
		if region != null and region.is_inside_tree():
			return region.get_navigation_map()
	var body: Node2D = get_parent() as Node2D
	return body.get_world_2d().navigation_map if body != null and body.is_inside_tree() else RID()


## En yakın Level API'li ata (S4; duck typing).
func _level() -> Node:
	var node: Node = get_parent()
	while node != null and not node.has_method(&"door_link"):
		node = node.get_parent()
	return node


func _body_pos() -> Vector2:
	var body: Node2D = get_parent() as Node2D
	return body.global_position if body != null else Vector2.ZERO
