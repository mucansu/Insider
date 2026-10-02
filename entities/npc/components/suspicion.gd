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
##
## Sivil eki (US-008, yalnız ekleme; varsayılanlar muhafız davranışını değiştirmez):
## - `innocent_decay_per_sec` ≥ 0 ise görüş hattında olup masum davranan (dolum 0) hedefin ölçeri bu hızla boşalır
##   (GDD §6.1: 10/sn; görünmeyince tuning'deki 20/sn).
## - `apply_delta(peer_id, delta)` host API'si: ölçeri doğrudan değiştirir (US-010 OYALA −40, ÇEK kurtarana +100);
##   yukarı geçilen eşikler `threshold_reached` yayar.
## - `latch_level`: beyin tespit sonrası özet düzeyi kilitler (çoğaltılan `max_level` kısa saklanmada titremez).
## - `last_observations()`: son adımın gözlemleri (beyin hedef seçimi ve döküm için).

## Yalnız host'ta: `peer_id` için `level` eşiği aşağıdan geçildi.
signal threshold_reached(peer_id: int, level: int)

enum Level { CALM, NOTICE, INVESTIGATE, DETECT }

const SYNC_NAME := "SuspicionSync"
const SYNC_INTERVAL := 0.1
## Çoğaltılan `focus_direction` bileşenlerinin adımı (S11 eki: ON_CHANGE sürekli değerler 1/16'ya yuvarlanır).
const FOCUS_STEP := 1.0 / 16.0

@export var perception: Perception

## Çoğaltılan özet durum (host yazar).
var max_level: int = Level.CALM
var focus_direction: Vector2 = Vector2.ZERO
## Görünüp masumken boşalma (birim/sn); < 0 = yok (görünmeyen gibi boşalır).
var innocent_decay_per_sec: float = -1.0
## Özet düzeyin alt sınırı (beyin yazar; 0 = kilit yok).
var latch_level: int = Level.CALM

## peer_id -> SuspicionMeter
var _meters: Dictionary = {}
## peer_id -> son görüldüğü konum (global; dolum > 0 olan son gözlem)
var _last_seen: Dictionary = {}
var _params: SuspicionMeter.Params = null
var _innocent: SuspicionMeter.Params = null
var _observations: Dictionary = {}


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
	if innocent_decay_per_sec >= 0.0 and (_innocent == null or _innocent.decay_per_sec != innocent_decay_per_sec):
		_innocent = params_for(perception.tuning)
		_innocent.decay_per_sec = innocent_decay_per_sec
	var observations: Dictionary = perception.observe()
	_observations = observations
	var reached: Array = []
	for peer_id: int in observations:
		var obs: Perception.Observation = observations[peer_id]
		var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
		if meter == null:
			meter = SuspicionMeter.new()
			_meters[peer_id] = meter
		var innocent_seen: bool = obs.rate <= 0.0 and innocent_decay_per_sec >= 0.0 and obs.line_clear \
				and obs.band != PerceptionRules.Band.NONE and not obs.in_dark
		if obs.rate > 0.0 or innocent_seen:
			_last_seen[peer_id] = obs.position  # sivil: masum ama görülen hedefin yeri de bilinir (sorgu)
		var p: SuspicionMeter.Params = _params
		if innocent_seen:
			p = _innocent
		for l: int in meter.step(p, obs.rate, delta):
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


## Host API (US-008 AC4): ölçeri `delta` kadar değiştirir (0..MAX). Yukarı geçilen eşikler sinyal yayar;
## son görülen konum değişmez (görülmeden verilen şüphe konum sızdırmaz).
func apply_delta(peer_id: int, delta: float) -> void:
	if perception == null or not multiplayer.is_server():
		return
	if _params == null:
		if perception.tuning == null:
			perception.refresh()
		_params = params_for(perception.tuning)
	var meter: SuspicionMeter = _meters.get(peer_id) as SuspicionMeter
	if meter == null:
		meter = SuspicionMeter.new()
		_meters[peer_id] = meter
	meter.value = clampf(meter.value + delta, 0.0, SuspicionMeter.MAX_VALUE)
	var new_level: int = SuspicionMeter.level_for(_params, meter.value)
	var reached: PackedInt32Array = PackedInt32Array()
	for l: int in range(meter.level + 1, new_level + 1):
		reached.append(l)
	meter.level = new_level
	_update_summary()
	for l: int in reached:
		threshold_reached.emit(peer_id, l)


## Hedefin ölçerini siler (ör. yakalanan oyuncu artık hedef değil).
func forget(peer_id: int) -> void:
	_meters.erase(peer_id)
	_last_seen.erase(peer_id)
	_update_summary()


## Ölçeri olan hedefler.
func peers() -> Array[int]:
	var out: Array[int] = []
	for peer_id: int in _meters:
		out.append(peer_id)
	return out


## Son adımın gözlemleri: peer_id -> Perception.Observation.
func last_observations() -> Dictionary:
	return _observations


## Hedefin son görüldüğü konum (global); hiç görülmediyse INF.
func last_seen_position(peer_id: int) -> Vector2:
	return _last_seen.get(peer_id, Vector2.INF)


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
	max_level = maxi(top.level if top != null else Level.CALM, latch_level)
	focus_direction = Vector2.ZERO
	if max_level > Level.CALM and _last_seen.has(best_peer):
		# S11 eki (US-008): sürekli değer ON_CHANGE çoğaltılmadan önce 1/16 adıma yuvarlanır (her karede güvenilir
		# delta üretmesin).
		var dir: Vector2 = ((_last_seen[best_peer] as Vector2) - perception.global_position).normalized()
		focus_direction = dir.snapped(Vector2.ONE * FOCUS_STEP)


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
