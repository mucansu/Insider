class_name Suspicion
extends Node
## Şüphe bileşeni (US-006 AC2; mimari.md S2, S11, GDD §6.1, KR-019): NPC'nin alt düğümü; aynı NPC'deki
## `Perception`'ın gözlemiyle oyuncu başına 0-100 ölçer (`SuspicionMeter`, core/) işletir. Yalnız host'ta işler
## (S2): her fizik adımında `perception.observe()` → ölçerler → yukarı geçilen eşikler için
## `threshold_reached(peer_id, level)` (1 "?", 2 inceleme, 3 tespit; yalnız host'ta yayılır).
##
## Çoğaltılan özet (host yetkili MultiplayerSynchronizer, değişince): `max_level` (en yüksek ölçerin düzeyi) ve
## `focus_direction` (gözlemciden o hedefin son görüldüğü konuma birim yön; düzey 0 iken ZERO; görülmeyen
## hedefin şimdiki konumu sızmaz). İstemci görseli yalnız bunları okur
## ("?"/"!" göstergesi, baş çevirme). Ayarlar perception.tuning'den (data/npc/perception_tuning.tres).

## Yalnız host'ta: `peer_id` için `level` eşiği aşağıdan geçildi.
signal threshold_reached(peer_id: int, level: int)

enum Level { CALM, NOTICE, INVESTIGATE, DETECT }

const SYNC_NAME := "SuspicionSync"
const SYNC_INTERVAL := 0.1

@export var perception: Perception

## Çoğaltılan özet durum (host yazar).
var max_level: int = Level.CALM
var focus_direction: Vector2 = Vector2.ZERO

## peer_id -> SuspicionMeter
var _meters: Dictionary = {}
## peer_id -> son görüldüğü konum (global; dolum > 0 olan son gözlem)
var _last_seen: Dictionary = {}
var _params: SuspicionMeter.Params = null


func _ready() -> void:
	if perception == null:
		push_error("Suspicion: perception atanmamış")
	add_child(_make_sync())


func _physics_process(delta: float) -> void:
	if perception == null or not multiplayer.is_server():
		return
	tick(delta)


## Tuning'den core ölçer ayarları.
static func params_for(source: PerceptionTuning) -> SuspicionMeter.Params:
	var p := SuspicionMeter.Params.new()
	p.decay_per_sec = source.decay_per_sec
	p.thresholds = PackedFloat32Array([source.notice_threshold, source.investigate_threshold,
		source.detect_threshold])
	p.grace = source.grace_sec
	p.gap_tolerance = source.gap_tolerance_sec
	return p


## Bir adım (host): gözlem → ölçerler → eşik sinyalleri → özet. Gözlemde olmayan (ayrılan) hedeflerin ölçeri
## boşalır, sıfırlanınca silinir.
func tick(delta: float) -> void:
	if _params == null:
		if perception.tuning == null:
			perception.refresh()
		_params = params_for(perception.tuning)
	var observations: Dictionary = perception.observe()
	var reached: Array = []
	for peer_id: int in observations:
		var obs: Perception.Observation = observations[peer_id]
		var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
		if meter == null:
			meter = SuspicionMeter.new()
			_meters[peer_id] = meter
		if obs.rate > 0.0:
			_last_seen[peer_id] = obs.position
		for l: int in meter.step(_params, obs.rate, delta):
			reached.append([peer_id, l])
	for peer_id: int in _meters.keys():
		if observations.has(peer_id):
			continue
		var gone: SuspicionMeter = _meters[peer_id]
		gone.step(_params, 0.0, delta)
		if gone.value <= 0.0:
			_meters.erase(peer_id)
			_last_seen.erase(peer_id)
	_update_summary()
	for item: Array in reached:
		threshold_reached.emit(int(item[0]), int(item[1]))


func value_of(peer_id: int) -> float:
	var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
	return meter.value if meter != null else 0.0


func level_of(peer_id: int) -> int:
	var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
	return meter.level if meter != null else Level.CALM


## Bütün ölçerleri sıfırlar (ör. tespit sonrası beyin yeni duruma geçerken).
func clear() -> void:
	_meters.clear()
	_last_seen.clear()
	max_level = Level.CALM
	focus_direction = Vector2.ZERO


func _update_summary() -> void:
	var best_peer: int = 0
	var best_value: float = 0.0
	for peer_id: int in _meters:
		var meter: SuspicionMeter = _meters[peer_id]
		if meter.value > best_value:
			best_value = meter.value
			best_peer = peer_id
	var top: SuspicionMeter = _meters.get(best_peer) as SuspicionMeter
	max_level = top.level if top != null else Level.CALM
	focus_direction = Vector2.ZERO
	if max_level > Level.CALM and _last_seen.has(best_peer):
		focus_direction = ((_last_seen[best_peer] as Vector2) - perception.global_position).normalized()


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:max_level", ".:focus_direction"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.delta_interval = SYNC_INTERVAL
	sync.replication_config = config
	return sync
