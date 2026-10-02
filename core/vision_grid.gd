class_name VisionGrid
extends RefCounted
## Oyuncu görüş ızgarası (US-011a AC1; GDD §6.5, §14, KR-022/KR-023). Düğümsüz: sahne ağacını, fizik
## uzayını ve proje dizinlerini bilmez (KR-018). Girdi: engel ızgarası (karo sınıfları) + gözlemci konumu +
## bakış yönü + görüş hattı sonucu veren Callable; çıktı: karo durumları.
##
## Karo durumu (1 karo = 32 px, ızgara kökü (0, 0)): 0 bilinmeyen / 1 hafıza / 2 görünen / 3 çevresel (yalnız
## yönlü kip). Her `update()` çağrısında:
## - Bölge: gözlemciden karo merkezine uzaklık ve açı → görünen / çevresel / dışarıda (`zone_of`). Çevresel kip
##   (`Mode.PERIPHERAL`, 360°): yarıçap içinde her yön görünen. Yönlü kip: net koni (yarım açı, yarıçap) görünen;
##   çevresel bölge (daha geniş yarım açı, daha kısa menzil) durum 3; 360° yakın halka her kipte görünen.
## - Görüş hattı: bölgedeki açık (OPEN) ve geçit (PORTAL: kapı, cam) karolarının merkezine `sight(from, to)` ışını;
##   kural NPC'ninkiyle aynıdır (çağıran fizik sorgusunu verir: world + vision_block keser, `see_through`
##   gövdeleri geçer). Gözlemcinin kendi karosuna ışın atılmaz.
## - Komşuluk kuralı: katı karolar (SOLID: duvar, sınır, raf, tezgâh) ve ışını kesilen geçitler (kapalı kapı)
##   ışınla değil, 8 komşusundan biri bu güncellemede **ışınla** görülmüşse kendi bölgesinin durumunu alır.
##   Zincirlenmez: komşuluktan görünen katı karo başka bir katı karoyu açmaz (duvarın arkasındaki raf görünmez).
## - Karanlık karo (dark maskesi) görüş hattında bile hafıza tonunda kalır; gözlemci de karanlıktaysa ve karo
##   `dark_radius` içindeyse görünen olur. Karanlıktaki gözlemcinin yarıçapı `dark_radius` ile sınırlanır.
## - Hafıza: önceki güncellemede 2/3 olan karo artık görülmüyorsa 1 olur ve `reset()`e kadar 1 kalır
##   (`memory_enabled` kapalıysa 0'a döner). Hafıza faz içidir: seviye yüklenince yeni ızgara kurulur.
## - Maliyet: tarama yalnız önceki ∪ yeni görüş dikdörtgenidir (2/3 karolar yalnız önceki dikdörtgende olabilir);
##   sayımlar artımlı tutulur.
## Aynı girdi aynı diziyi verir (sabit tarama sırası, rastgelelik yok).

## Durum değişen karolar (sabit sırada: satır satır, soldan sağa). Değişim yoksa yayılmaz.
signal changed(cells: Array[Vector2i])

enum State { UNKNOWN = 0, MEMORY = 1, VISIBLE = 2, PERIPHERAL = 3 }
## Görüş kipi (host kuralı, GDD §6.5): çevresel 360° ya da yönlü. Adları: &"peripheral", &"directional".
enum Mode { PERIPHERAL = 0, DIRECTIONAL = 1 }
## Karo sınıfı (engel ızgarası): OPEN ışınla, SOLID komşulukla, PORTAL önce ışınla sonra komşulukla.
enum Cell { OPEN = 0, SOLID = 1, PORTAL = 2 }

const TILE := 32
## Bölge sınırlarında kayan nokta payı (px ve kosinüs).
const EPSILON := 0.0001
## `zone_of` sonucu: bölge dışı.
const OUTSIDE := -1
const MODE_NAMES: Array[StringName] = [&"peripheral", &"directional"]
const _UNLIT := 255


## Görüş ayarları (değer nesnesi; sis katmanı `VisionTuning`'den doldurur).
class Params:
	extends RefCounted
	var mode: int = Mode.PERIPHERAL
	## Aydınlıkta yarıçap (px); yönlü kipte net koninin menzili.
	var view_radius: float = 0.0
	## Karanlıktaki gözlemcinin yarıçapı (px).
	var dark_radius: float = 0.0
	## Yönlü kip: net koni ve çevresel bölge yarım açıları (derece), çevresel menzil (px).
	var cone_half_angle_deg: float = 0.0
	var peripheral_half_angle_deg: float = 0.0
	var peripheral_radius: float = 0.0
	## Her kipte her yönde görünen yakın halka (px).
	var near_radius: float = 0.0
	var memory_enabled: bool = true


var params: Params = Params.new()
## Son güncellemede atılan ışın sayısı.
var last_ray_count: int = 0

var _size: Vector2i = Vector2i.ZERO
var _cells: PackedByteArray = PackedByteArray()
var _dark: PackedByteArray = PackedByteArray()
var _states: PackedByteArray = PackedByteArray()
var _lit: PackedByteArray = PackedByteArray()
var _zone: PackedByteArray = PackedByteArray()
var _old: PackedByteArray = PackedByteArray()
var _counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Önceki güncellemenin tarama dikdörtgeni (karo, uçlar dahil); boşsa x > y.x.
var _prev_lo := Vector2i(1, 1)
var _prev_hi := Vector2i(0, 0)


## Izgarayı kurar: `grid_size` karo, `cells` satır satır `Cell` değerleri (boyu genişlik × yükseklik), `dark` aynı
## düzende 0/1 karanlık maskesi (boşsa her yer aydınlık). Bütün karolar bilinmeyen olur (değişim yayılmaz).
func setup(grid_size: Vector2i, cells: PackedByteArray, dark: PackedByteArray = PackedByteArray()) -> void:
	var total: int = maxi(grid_size.x, 0) * maxi(grid_size.y, 0)
	if cells.size() != total:
		push_error("VisionGrid: hücre sayısı %d, beklenen %d" % [cells.size(), total])
		total = 0
		grid_size = Vector2i.ZERO
		cells = PackedByteArray()
	_size = grid_size
	_cells = cells.duplicate()
	_dark = dark.duplicate() if dark.size() == total else PackedByteArray()
	if _dark.is_empty():
		_dark.resize(total)
	_states = PackedByteArray()
	_states.resize(total)
	_lit = PackedByteArray()
	_lit.resize(total)
	_lit.fill(_UNLIT)
	_zone = PackedByteArray()
	_zone.resize(total)
	_counts = PackedInt32Array([total, 0, 0, 0])
	_prev_lo = Vector2i(1, 1)
	_prev_hi = Vector2i(0, 0)
	last_ray_count = 0


## Hafızayı siler: bütün karolar bilinmeyen (değişen karolar yayılır).
func reset() -> Array[Vector2i]:
	var diff: Array[Vector2i] = []
	for y: int in _size.y:
		for x: int in _size.x:
			var i: int = y * _size.x + x
			if _states[i] != State.UNKNOWN:
				_states[i] = State.UNKNOWN
				diff.append(Vector2i(x, y))
	_counts = PackedInt32Array([_states.size(), 0, 0, 0])
	_prev_lo = Vector2i(1, 1)
	_prev_hi = Vector2i(0, 0)
	if not diff.is_empty():
		changed.emit(diff)
	return diff


func size() -> Vector2i:
	return _size


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


## Karo durumu (`State`); ızgara dışı bilinmeyen.
func state_at(cell: Vector2i) -> int:
	if not has_cell(cell):
		return State.UNKNOWN
	return _states[cell.y * _size.x + cell.x]


## Izgara koordinatındaki noktanın karo durumu.
func state_at_position(pos: Vector2) -> int:
	return state_at(cell_of(pos))


## Nokta şu an görünen karoda mı (durum 2; çevresel sayılmaz).
func is_visible(pos: Vector2) -> bool:
	return state_at_position(pos) == State.VISIBLE


## Nokta çevresel karoda mı (durum 3, yalnız yönlü kip).
func is_peripheral(pos: Vector2) -> bool:
	return state_at_position(pos) == State.PERIPHERAL


func is_dark(cell: Vector2i) -> bool:
	return has_cell(cell) and _dark[cell.y * _size.x + cell.x] != 0


## Durum dizisinin kopyası (satır satır).
func states() -> PackedByteArray:
	return _states.duplicate()


## Durumdaki karo sayısı.
func count(state: int) -> int:
	return _counts[state] if state >= 0 and state < _counts.size() else 0


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Ad → kip (`&"peripheral"` / `&"directional"`); bilinmeyen ad uyarıyla çevresel.
static func mode_from_name(mode_name: StringName) -> int:
	var index: int = MODE_NAMES.find(mode_name)
	if index < 0:
		push_warning("VisionGrid: bilinmeyen görüş kipi '%s', peripheral kullanılıyor" % mode_name)
		return Mode.PERIPHERAL
	return index


static func mode_name(mode: int) -> StringName:
	return MODE_NAMES[mode] if mode >= 0 and mode < MODE_NAMES.size() else MODE_NAMES[Mode.PERIPHERAL]


## Gözlemciye göre `offset`teki noktanın bölgesi: State.VISIBLE, State.PERIPHERAL ya da OUTSIDE. Yönlü kipte
## bakış sıfırsa yalnız yakın halka görünür. Sınırlar dahil.
static func zone_of(offset: Vector2, look_dir: Vector2, p: Params, observer_dark: bool = false) -> int:
	var cap: float = minf(p.view_radius, p.dark_radius) if observer_dark else p.view_radius
	var dist: float = offset.length()
	if dist <= minf(p.near_radius, cap) + EPSILON:
		return State.VISIBLE
	if dist > cap + EPSILON:
		return OUTSIDE
	if p.mode != Mode.DIRECTIONAL:
		return State.VISIBLE
	if look_dir.is_zero_approx():
		return OUTSIDE
	var cos_angle: float = offset.dot(look_dir.normalized()) / dist
	if cos_angle >= cos(deg_to_rad(clampf(p.cone_half_angle_deg, 0.0, 180.0))) - EPSILON:
		return State.VISIBLE
	if dist <= minf(p.peripheral_radius, cap) + EPSILON \
			and cos_angle >= cos(deg_to_rad(clampf(p.peripheral_half_angle_deg, 0.0, 180.0))) - EPSILON:
		return State.PERIPHERAL
	return OUTSIDE


## Gözlemci `origin`de (ızgara koordinatı, px), `look_dir` yönüne bakarken ızgarayı günceller. `sight` =
## func(from: Vector2, to: Vector2) -> bool (görüş hattı açık mı). Değişen karoları döndürür ve `changed` yayar.
func update(origin: Vector2, look_dir: Vector2, sight: Callable) -> Array[Vector2i]:
	var diff: Array[Vector2i] = []
	if _size.x <= 0 or _size.y <= 0:
		return diff
	# Bölge eşikleri (zone_of ile aynı kurallar; döngü içinde yeniden hesaplanmasın diye bir kez).
	var w: int = _size.x
	var origin_cell: Vector2i = cell_of(origin)
	var observer_dark: bool = is_dark(origin_cell)
	var cap: float = minf(params.view_radius, params.dark_radius) if observer_dark else params.view_radius
	var cap_sq: float = (cap + EPSILON) * (cap + EPSILON)
	var near_r: float = minf(params.near_radius, cap) + EPSILON
	var near_sq: float = near_r * near_r
	var peri_r: float = minf(params.peripheral_radius, cap) + EPSILON
	var peri_sq: float = peri_r * peri_r
	var dark_sq: float = (params.dark_radius + EPSILON) * (params.dark_radius + EPSILON)
	var directional: bool = params.mode == Mode.DIRECTIONAL
	var look: Vector2 = look_dir.normalized() if not look_dir.is_zero_approx() else Vector2.ZERO
	var cos_cone: float = cos(deg_to_rad(clampf(params.cone_half_angle_deg, 0.0, 180.0))) - EPSILON
	var cos_peri: float = cos(deg_to_rad(clampf(params.peripheral_half_angle_deg, 0.0, 180.0))) - EPSILON
	# Karo merkezi en çok (k - 0,5) karo uzakta olabilir: k ≤ ceil(erişim / TILE + 0,5) - 1.
	var span: int = ceili(maxf(cap, near_r) / TILE + 0.5) - 1
	var lo := Vector2i(clampi(origin_cell.x - span, 0, w - 1), clampi(origin_cell.y - span, 0, _size.y - 1))
	var hi := Vector2i(clampi(origin_cell.x + span, 0, w - 1), clampi(origin_cell.y + span, 0, _size.y - 1))
	var u_lo: Vector2i = lo
	var u_hi: Vector2i = hi
	if _prev_lo.x <= _prev_hi.x:
		u_lo = Vector2i(mini(lo.x, _prev_lo.x), mini(lo.y, _prev_lo.y))
		u_hi = Vector2i(maxi(hi.x, _prev_hi.x), maxi(hi.y, _prev_hi.y))
	var u_w: int = u_hi.x - u_lo.x + 1
	_old.resize(u_w * (u_hi.y - u_lo.y + 1))
	# 0) Önceki ∪ yeni dikdörtgen: eski durumu sakla, görülenleri hafızaya indir.
	var forget: int = State.MEMORY if params.memory_enabled else State.UNKNOWN
	for y: int in range(u_lo.y, u_hi.y + 1):
		var row: int = y * w
		var old_row: int = (y - u_lo.y) * u_w - u_lo.x
		for x: int in range(u_lo.x, u_hi.x + 1):
			var s: int = _states[row + x]
			_old[old_row + x] = s
			if s == State.VISIBLE or s == State.PERIPHERAL:
				_states[row + x] = forget
	# 1) Bölge (bütün karolar) ve ışın (açık ve geçit karoları). _lit: ışınla görülen bölge, _zone: bölge.
	var rays: int = 0
	for y: int in range(lo.y, hi.y + 1):
		var row: int = y * w
		var cy: float = (y + 0.5) * TILE - origin.y
		for x: int in range(lo.x, hi.x + 1):
			var i: int = row + x
			var cx: float = (x + 0.5) * TILE - origin.x
			var dist_sq: float = cx * cx + cy * cy
			var zone: int = _UNLIT
			if dist_sq <= near_sq:
				zone = State.VISIBLE
			elif dist_sq <= cap_sq:
				if not directional:
					zone = State.VISIBLE
				elif look != Vector2.ZERO:
					var cos_angle: float = (cx * look.x + cy * look.y) / sqrt(dist_sq)
					if cos_angle >= cos_cone:
						zone = State.VISIBLE
					elif cos_angle >= cos_peri and dist_sq <= peri_sq:
						zone = State.PERIPHERAL
			_zone[i] = zone
			if zone == _UNLIT or _cells[i] == Cell.SOLID:
				continue
			if x != origin_cell.x or y != origin_cell.y:
				rays += 1
				if not bool(sight.call(origin, Vector2(cx, cy) + origin)):
					continue
			_lit[i] = zone
	# 2) Işınla görülenler ve komşuluk kuralı (katı karolar, kesilen geçitler; yalnız ışınla görülen komşudan,
	# zincirlenmez). Karanlık karo hafıza tonunda kalır; gözlemci de karanlıkta ve yakınsa görünür.
	for y: int in range(lo.y, hi.y + 1):
		var row: int = y * w
		for x: int in range(lo.x, hi.x + 1):
			var i: int = row + x
			var zone: int = _lit[i]
			if zone == _UNLIT:
				zone = _zone[i]
				if zone == _UNLIT or _cells[i] == Cell.OPEN or not _neighbour_lit(x, y):
					continue
			if _dark[i] != 0:
				var cx: float = (x + 0.5) * TILE - origin.x
				var cy: float = (y + 0.5) * TILE - origin.y
				if not observer_dark or cx * cx + cy * cy > dark_sq:
					zone = State.MEMORY
			_states[i] = zone
	for y: int in range(lo.y, hi.y + 1):
		var row: int = y * w
		for x: int in range(lo.x, hi.x + 1):
			_lit[row + x] = _UNLIT
	# 3) Fark (satır satır, soldan sağa) ve sayımlar.
	for y: int in range(u_lo.y, u_hi.y + 1):
		var row: int = y * w
		var old_row: int = (y - u_lo.y) * u_w - u_lo.x
		for x: int in range(u_lo.x, u_hi.x + 1):
			var now: int = _states[row + x]
			var was: int = _old[old_row + x]
			if now != was:
				_counts[was] -= 1
				_counts[now] += 1
				diff.append(Vector2i(x, y))
	_prev_lo = lo
	_prev_hi = hi
	last_ray_count = rays
	if not diff.is_empty():
		changed.emit(diff)
	return diff


func _neighbour_lit(x: int, y: int) -> bool:
	for ny: int in range(maxi(y - 1, 0), mini(y + 1, _size.y - 1) + 1):
		var row: int = ny * _size.x
		for nx: int in range(maxi(x - 1, 0), mini(x + 1, _size.x - 1) + 1):
			if _lit[row + nx] != _UNLIT:
				return true
	return false
