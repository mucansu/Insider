class_name Level
extends Node2D
## Seviye kökü (mimari.md S4, KR-018). `levels/tools/build_levels.gd` her üretilen sahnenin köküne atar.
## Çekirdek ve diğer sistemler seviye düğümlerine yalnız bu API ile erişir, ad dizesiyle gezmez; düğüm adları
## (S4 zorunlu çocukları) yalnız burada ve üreticide geçer. Sorgular ağaç dışında da çalışır (Game seviyeyi
## ağaca eklemeden önce kurar). Zorunlu çocuk yoksa ilgili kök null döner, doğma noktası sayısı 0 olur.

const _PLAYERS := ^"Players"
const _PROPS := ^"Props"
const _NPCS := ^"NPCs"
const _SPAWN_POINTS := ^"SpawnPoints"
const _MARKERS := ^"Markers"
const _ZONES := ^"Zones"
const _NAVIGATION := ^"Navigation"
const _TILES := ^"Tiles"


## Oyuncu düğümlerinin kabı (Game üretir; düğüm adı peer kimliği).
func players_root() -> Node2D:
	return get_node_or_null(_PLAYERS) as Node2D


## Etkileşimli nesnelerin kabı.
func props_root() -> Node2D:
	return get_node_or_null(_PROPS) as Node2D


## NPC'lerin kabı.
func npcs_root() -> Node2D:
	return get_node_or_null(_NPCS) as Node2D


## `SpawnPoints` altındaki doğma noktası sayısı (sahne sırasıyla Spawn1..N).
func spawn_count() -> int:
	return _spawn_points().size()


## `index`. doğma noktası (index doğma noktası sayısına göre çevrilir), `players_root()` koordinatında: oyuncu
## düğümünün `position`'ı olarak doğrudan kullanılır. Doğma noktası ya da Players yoksa Vector2.ZERO.
func spawn_position(index: int) -> Vector2:
	var points: Array[Node2D] = _spawn_points()
	var players: Node2D = players_root()
	if points.is_empty() or players == null:
		return Vector2.ZERO
	var at: Vector2 = _to_level(points[posmod(index, points.size())]).origin
	return _to_level(players).affine_inverse() * at


## `Markers` altındaki adlı yerleşim işareti (ör. &"Register", &"BackDoor"); yoksa null.
func marker(marker_name: StringName) -> Node2D:
	return _child_of(_MARKERS, marker_name) as Node2D


## Sıralı işaret dizisi: `<prefix>1`, `<prefix>2` … ilk eksik numaraya kadar (ör. &"StreetRoute" sokak
## rotası, &"ShopSpot" müşteri raf noktaları; IS-023). Yoksa boş dizi.
func marker_sequence(prefix: StringName) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var next: Node2D = marker(StringName("%s%d" % [prefix, 1]))
	while next != null:
		out.append(next)
		next = marker(StringName("%s%d" % [prefix, out.size() + 1]))
	return out


## `Zones` altındaki adlı tetik bölgesi (ör. &"EscapeZone"; Area2D, katman triggers, oyuncuları izler); yoksa null.
func zone(zone_name: StringName) -> Area2D:
	return _child_of(_ZONES, zone_name) as Area2D


## Seviyenin gezinme bölgesi (üretimde bake edilmiş NavigationPolygon); yoksa null.
func navigation_region() -> NavigationRegion2D:
	return get_node_or_null(_NAVIGATION) as NavigationRegion2D


## Kapı işaretinin (ör. &"BackDoor") gezinme bağı: kapı karosu çokgende engeldir, geçiş bu bağla olur.
## Kapı kapanınca `enabled = false` yapılır (kapı durumunu bağlayan sistem; US-008). Yoksa null.
func door_link(door_name: StringName) -> NavigationLink2D:
	return _child_of(_NAVIGATION, door_name) as NavigationLink2D


## `container` altındaki doğrudan çocuk; yol parçası içeren ad ("../Players" gibi) kabul edilmez.
func _child_of(container: NodePath, child_name: StringName) -> Node:
	var text: String = String(child_name)
	var parent: Node = get_node_or_null(container)
	if parent == null or text.is_empty() or text.validate_node_name() != text:
		return null
	return parent.get_node_or_null(NodePath(text))


## Haritanın oynanabilir alan dikdörtgeni (IS-027; kamera sınırı): `Tiles` ızgarasının tamamı, harita kenarı
## dolgusu (sınır karoları) dahil; bu köke göre (kökün kendi dönüşümü hariç). `Tiles` yoksa ya da boşsa
## alanı sıfır olan Rect2() — çağıran sınır uygulamaz.
func map_rect() -> Rect2:
	var tiles: LevelLayout = get_node_or_null(_TILES) as LevelLayout
	if tiles == null:
		return Rect2()
	var size: Vector2i = tiles.size_in_tiles()
	if size.x <= 0 or size.y <= 0:
		return Rect2()
	return _to_level(tiles) * Rect2(Vector2.ZERO, Vector2(size * LevelLayout.TILE))


func _spawn_points() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var points: Node = get_node_or_null(_SPAWN_POINTS)
	if points != null:
		for child: Node in points.get_children():
			if child is Node2D:
				out.append(child as Node2D)
	return out


## Düğümün bu köke göre dönüşümü (ağaç dışında da; global_transform ağaç ister).
func _to_level(node: Node2D) -> Transform2D:
	var xform: Transform2D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != self:
		if parent is Node2D:
			xform = (parent as Node2D).transform * xform
		parent = parent.get_parent()
	return xform
