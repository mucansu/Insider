class_name SfxCatalog
extends Resource
## Ses kataloğu (IS-024; S10 kalıbı): olay adı -> SfxEntry (AudioStream + ses düzeyi + perde aralığı + en kısa
## aralık + yer tutucu işareti). Tek dosya `data/sfx_catalog.tres`; ton başına set (KR-005) gelince
## `data/audio/<ton>/` altında aynı sınıfla çoğalır. Autoload değildir (§6): çalarlar `load_default()` ile okur.
## Çalarlar: konumlu `SfxEmitter` (entities/fx), arayüz `UiSfx` (ui/). Kayıt: docs/notes/assetler.md.

const DEFAULT_PATH := "res://data/sfx_catalog.tres"
## Tam aralık kadar sonra gelen çalış geçer (kayan nokta payı, sn).
const INTERVAL_EPSILON := 0.0001

@export var entries: Array[SfxEntry] = []

## Eksik olay uyarısı süreç başına bir kez (olay -> true).
static var _warned: Dictionary = {}


## Varsayılan katalog (kaynak önbelleğinden; çalar ilk kullanımda alır ve tutar, statik kopya yok).
static func load_default() -> SfxCatalog:
	var catalog: SfxCatalog = load(DEFAULT_PATH) as SfxCatalog
	if catalog == null:
		push_warning("SfxCatalog: %s yüklenemedi; sesler sessiz" % DEFAULT_PATH)
		catalog = SfxCatalog.new()
	return catalog


## Olayın girdisi; yoksa null.
func find(event: StringName) -> SfxEntry:
	for entry: SfxEntry in entries:
		if entry != null and entry.event == event:
			return entry
	return null


func events() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: SfxEntry in entries:
		if entry != null:
			out.append(entry.event)
	return out


## Hâlâ yer tutucu olan olaylar (rapor: kaç ses üretimle değişecek).
func placeholder_events() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: SfxEntry in entries:
		if entry != null and entry.placeholder:
			out.append(entry.event)
	return out


## Çalınacaksa girdiyi döndürür: olay katalogda ve dosyası var, `last_played`'e göre en kısa aralık geçmiş
## (geçtiyse `last_played[event] = now` yazılır). Eksik olay sessizdir, süreçte bir kez `push_warning`.
func take(event: StringName, last_played: Dictionary, now: float) -> SfxEntry:
	var entry: SfxEntry = find(event)
	if entry == null or entry.stream == null:
		if not _warned.has(event):
			_warned[event] = true
			push_warning("SfxCatalog: olay yok ya da dosyasız: %s (data/sfx_catalog.tres)" % event)
		return null
	if last_played.has(event) and now - float(last_played[event]) < entry.min_interval - INTERVAL_EPSILON:
		return null
	last_played[event] = now
	return entry


## Çalar saati (sn, monoton).
static func now_sec() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
