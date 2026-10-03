class_name VisionRules
extends RefCounted
## Görüş oturum kuralları (US-011b AC2/AC6/AC7; GDD §6.5; mimari.md S2, S3 eki "Görüş ekleri", KR-022/KR-023).
## Düğümsüz: Game ve görseller yalnız bu kurallara sorar.
## - Görüş kipi (`vision_mode`, VisionGrid.Mode: 0 çevresel 360°, 1 yönlü) host'un oyun kuralıdır: yalnız host,
##   seviye başlamadan seçer; istemciye çoğaltılır, istemcinin kendi yazması etkisizdir.
## - Maruziyet (`exposure`, oyuncu başına): 0 gizli · 1 görünür (bir gözlemcinin konisinde ve görüş hattında) ·
##   2 görüldü (herhangi bir gözlemcinin ona şüphesi ≥ SEEN_THRESHOLD). Yalnız host yazar (algı/şüphe özetinden),
##   istemci yalnız çoğaltılanı uygular.
## - Ses halkası çizim koşulu: kaynak karo görünen (ya da çevresel) ∨ yerel oyuncu sesin etkin yarıçapında
##   (görüş hattı yoksa ×wall_factor; NoiseBus/Hearing ile aynı kural, NoiseRules).
## - Hafıza mandalı (`Latch`): prop görseli görünmeyen karoda son görülen durumda donar.

enum Exposure { HIDDEN = 0, VISIBLE = 1, SEEN = 2 }

## "Görüldü" eşiği (GDD §6.1: 30 "?").
const SEEN_THRESHOLD := 30.0
## Maruziyetin host'ta hesaplanıp yayınlandığı aralık (sn; 10 Hz).
const EXPOSURE_INTERVAL_SEC := 0.1
## Sisin (FogLayer.Z_INDEX = 50) üstünde çizilmesi gerekenlerin z_index'i (ekip arkadaşı, siluet, hayalet, duyulan
## ses halkası; mimari.md S3 eki: > 50).
const ABOVE_FOG_Z := 60
## NPC görsellerinin grubu (Game dökümü `visible_npcs` bu gruptan okur; duck typing `is_fully_visible()`).
const NPC_VISUAL_GROUP := &"vision_npc_visuals"
## Dökümde peer başına tutulan en fazla maruziyet geçişi.
const MAX_HISTORY := 32


## Tek gözlemcinin bir oyuncuya bakışından maruziyet: şüphe ≥ eşik → 2; konide ve görüş hattında → 1; yoksa 0.
static func exposure_level(in_view: bool, suspicion: float) -> int:
	if suspicion >= SEEN_THRESHOLD:
		return Exposure.SEEN
	return Exposure.VISIBLE if in_view else Exposure.HIDDEN


## Birden çok gözlemcinin en yükseği.
static func combine(a: int, b: int) -> int:
	return maxi(a, b)


## Ses halkası bu peer'da çizilir mi: kaynak karo görülüyor ∨ yerel oyuncu sesi duyuyor (mesafe ≤ etkin yarıçap;
## görüş hattı yoksa yarıçap × wall_factor).
static func ring_shown(source_seen: bool, distance: float, radius: float, line_of_sight: bool,
		wall_factor: float) -> bool:
	if source_seen:
		return true
	return NoiseRules.can_hear(distance, NoiseRules.effective_radius(radius, line_of_sight, wall_factor))


## Hafıza mandalı: görülürken canlı değeri izler, görülmezken son görüleni tutar. Hiç görülmediyse `has_value()`
## false (çizilmez); sis yoksa çağıran hep `seen = true` verir.
class Latch:
	extends RefCounted
	var _value: Variant = null
	var _has: bool = false

	## Bu adımın gösterilecek değeri.
	func update(seen: bool, live: Variant) -> Variant:
		if seen:
			_value = live
			_has = true
		return _value

	func has_value() -> bool:
		return _has

	func value() -> Variant:
		return _value


## Oturumun görüş durumu (Game tutar): kip ve oyuncu maruziyetleri. `authority` = bu peer host (ya da
## çevrimdışı); yazma yöntemleri yetkisizken etkisizdir ve false döner.
class Session:
	extends RefCounted
	var _mode: int = 0
	## peer_id -> 0/1/2
	var _exposure: Dictionary = {}
	## peer_id -> Array[int] (geçiş geçmişi; ilk öğe ilk bilinen düzey)
	var _history: Dictionary = {}

	func _init(default_mode: int = 0) -> void:
		_mode = clampi(default_mode, 0, VisionGrid.MODE_NAMES.size() - 1)

	func mode() -> int:
		return _mode

	## Host kuralı: yalnız yetkili ve seviye yokken; geçersiz kip reddedilir.
	func set_mode(mode: int, authority: bool, level_active: bool) -> bool:
		if not authority or level_active or mode < 0 or mode >= VisionGrid.MODE_NAMES.size():
			return false
		_mode = mode
		return true

	## Çoğaltılan kip (istemci; host'tan gelir). Geçersizse yok sayılır.
	func apply_mode(mode: int) -> bool:
		if mode < 0 or mode >= VisionGrid.MODE_NAMES.size() or mode == _mode:
			return false
		_mode = mode
		return true

	func exposure(peer_id: int) -> int:
		return int(_exposure.get(peer_id, Exposure.HIDDEN))

	func exposures() -> Dictionary:
		return _exposure.duplicate()

	func history() -> Dictionary:
		return _history.duplicate(true)

	## Host: maruziyetleri yazar (yetkisizse etkisiz, boş döner). Dönüş: değişen peer -> yeni düzey.
	func write(levels: Dictionary, authority: bool) -> Dictionary:
		if not authority:
			return {}
		return apply(levels)

	## Çoğaltılan tam tablo (istemci; host'ta `write` aynı yolu kullanır). Tabloda olmayan peer 0 sayılır.
	## Dönüş: değişen peer -> yeni düzey.
	func apply(levels: Dictionary) -> Dictionary:
		var changed: Dictionary = {}
		var peers: Array = _exposure.keys()
		for key: Variant in levels:
			if typeof(key) == TYPE_INT and not peers.has(key):
				peers.append(key)
		for peer: Variant in peers:
			var peer_id: int = int(peer)
			var raw: Variant = levels.get(peer_id, Exposure.HIDDEN)
			var level: int = clampi(int(raw) if typeof(raw) == TYPE_INT else 0, Exposure.HIDDEN, Exposure.SEEN)
			if not _history.has(peer_id):
				_history[peer_id] = [Exposure.HIDDEN]
			var was: int = exposure(peer_id)
			if levels.has(peer_id):
				_exposure[peer_id] = level
			else:
				_exposure.erase(peer_id)
			if level != was:
				changed[peer_id] = level
				var rows: Array = _history[peer_id]
				rows.append(level)
				if rows.size() > MAX_HISTORY:
					rows.pop_front()
		return changed

	## Oturum/seviye sonu: tablo boşalır (geçmiş korunur ki döküm görsün). Dönüş: 0'a düşen peer'lar.
	func clear_exposures() -> Dictionary:
		return apply({})

	## Peer oturumdan ayrıldı: maruziyeti ve geçiş geçmişi silinir (döküm ve tablo ayrılanı taşımaz). Dönüş: 0'a
	## düşen peer (maruziyeti 0 değilse) -> 0.
	func forget(peer_id: int) -> Dictionary:
		var was: int = exposure(peer_id)
		_exposure.erase(peer_id)
		_history.erase(peer_id)
		return {peer_id: Exposure.HIDDEN} if was != Exposure.HIDDEN else {}
