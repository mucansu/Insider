class_name NoiseRing
extends Node2D
## Gürültü halkası görseli (US-009 AC5; mimari.md S8, S9; GDD §14.1 kural 2): NoiseBus her peer'da halka olayında
## seviyenin altına ekler. En az MIN_RADIUS'tan (1280×720'de 22 px çap) sesin yarıçapına DURATION sn'de
## genişler ve solar, sonra kendini kaldırır. Renk tonun ön plan rengi (KR-019: noir FG, ikinci renk yok).
## Hareket azaltmada (`reduced_motion`) genişleme yok: halka baştan tam yarıçapta görünür ve yalnız solar.
## Oyun kuralı taşımaz; yalnız kendi yaşını okur.
## Çizim koşulu (US-011b AC6; GDD §6.5 "ses halkaları yalnız duyana"): seviyede yerel oyuncunun sisi varsa halka
## yalnız kaynak karo görülüyorsa (görünen/çevresel) ya da yerel oyuncu sesi duyuyorsa çizilir — duyma NoiseBus/
## Hearing ile aynı kural: mesafe ≤ yarıçap, kulaktan kaynağa tek ışında (SightLine) görüş hattı yoksa yarıçap
## × `NoiseProfile.wall_factor` (VisionRules.ring_shown). Duyulan halka sisin üstünde çizilir (duvar arkasından
## okunur). Sis yoksa her halka çizilir. `NoiseBus.noise_shown` sözleşmesi değişmez (olay her peer'da yayılır;
## yalnız görsel gizlenir).

const DURATION := 0.4
## 22 px çap (GDD §14.1 kural 2: oyun işaretleri ≥ 22 px).
const MIN_RADIUS := 11.0
const LINE_WIDTH := 3.0
## Sonda kalan en düşük opaklık (kaybolana dek okunur).
const END_ALPHA := 0.3
const SEGMENTS := 48
const Z_INDEX := 20

## Hareket azaltma ayarı (oyuncu ayarı; UI ve kukla bayrağı bağlanınca oradan atanır).
static var reduced_motion: bool = false

var radius: float = 0.0
var _age: float = 0.0
var _shown: bool = true


func _ready() -> void:
	z_index = Z_INDEX


## Sesin yarıçapı (px). Çizim koşulu burada (konum atanmış, ağaçta) bir kez değerlendirilir.
func setup(noise_radius: float) -> void:
	radius = noise_radius
	_shown = true
	var fog: Object = FogView.fog_of(self) if is_inside_tree() else null
	if fog != null:
		var ear: Vector2 = FogView.observer_of(fog).global_position
		var seen: bool = FogView.is_tile_seen(fog, global_position)
		var distance: float = ear.distance_to(global_position)
		var los: bool = true
		if not seen and NoiseRules.can_hear(distance, radius):
			# Hearing ile aynı: kulaktan kaynağa tek ışın; kaynağın kendi gövdesi (SOURCE_MARGIN) kesmez.
			var hit: Dictionary = SightLine.first_blocker(get_world_2d().direct_space_state, ear, global_position)
			los = hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, global_position)
		_shown = VisionRules.ring_shown(seen, distance, radius, los, NoiseProfile.load_default().wall_factor)
		if _shown:
			z_index = VisionRules.ABOVE_FOG_Z
	visible = _shown
	queue_redraw()


## Bu peer'da çiziliyor mu (US-011b AC6).
func is_shown() -> bool:
	return _shown


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func age() -> float:
	return _age


func current_radius() -> float:
	return ring_radius(_age, radius, reduced_motion)


## `age` sn'deki çizim yarıçapı: MIN_RADIUS → max(yarıçap, MIN_RADIUS), yavaşlayarak; hareket azaltmada sabit.
static func ring_radius(at_age: float, noise_radius: float, reduced: bool) -> float:
	var full: float = maxf(noise_radius, MIN_RADIUS)
	if reduced:
		return full
	var t: float = clampf(at_age / DURATION, 0.0, 1.0)
	return lerpf(MIN_RADIUS, full, 1.0 - (1.0 - t) * (1.0 - t))


static func ring_alpha(at_age: float) -> float:
	return lerpf(1.0, END_ALPHA, clampf(at_age / DURATION, 0.0, 1.0))


func _draw() -> void:
	var color: Color = ThemeTokens.tone().fg_color
	color.a *= ring_alpha(_age)
	draw_arc(Vector2.ZERO, current_radius(), 0.0, TAU, SEGMENTS, color, LINE_WIDTH, true)
