class_name SfxCatalog
extends Resource
## Sound catalogue (IS-024; S10 pattern): event name -> SfxEntry (AudioStream + volume + pitch range + min interval + placeholder flag). A single file `data/sfx_catalog.tres`;
## per-tone sets (KR-005) will multiply under `data/audio/<tone>/` with the same class. Not an autoload (§6): players read it with `load_default()`.
## Players: positional `SfxEmitter` (entities/fx), UI `UiSfx` (ui/). Log: docs/notes/assetler.md.

const DEFAULT_PATH := "res://data/sfx_catalog.tres"
## A play after the full interval passes (float margin, s).
const INTERVAL_EPSILON := 0.0001

@export var entries: Array[SfxEntry] = []
## Looping beds (US-047): ambience and music, played by `Soundscape` (entities/fx), not through `take()`. Same entry class: `event` = loop id,
## `stream` = looping OGG under assets/ambience|music, `volume_db` = full level, `bus` = Ambience/Music. All mix levels live in this file.
@export var loops: Array[SfxEntry] = []

## Missing-event warning once per process (event -> true).
static var _warned: Dictionary = {}
## Tests: really play even headless (only for the sound playback test; returns to false afterwards).
static var force_playback: bool = false


## Default catalogue (from the resource cache; the player takes it on first use and keeps it, no static copy).
static func load_default() -> SfxCatalog:
	var catalog: SfxCatalog = load(DEFAULT_PATH) as SfxCatalog
	if catalog == null:
		push_warning("SfxCatalog: %s yüklenemedi; sesler sessiz" % DEFAULT_PATH)
		catalog = SfxCatalog.new()
	return catalog


## The event's entry; null if absent.
func find(event: StringName) -> SfxEntry:
	for entry: SfxEntry in entries:
		if entry != null and entry.event == event:
			return entry
	return null


## Loop entry by id (US-047); null if absent.
func find_loop(id: StringName) -> SfxEntry:
	for entry: SfxEntry in loops:
		if entry != null and entry.event == id:
			return entry
	return null


func events() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: SfxEntry in entries:
		if entry != null:
			out.append(entry.event)
	return out


## Events that are still placeholders (report: how many sounds production will replace).
func placeholder_events() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: SfxEntry in entries + loops:
		if entry != null and entry.placeholder:
			out.append(entry.event)
	return out


## Returns the entry if it should play: the event is in the catalogue and has a file, and the min interval since `last_played` has passed
## (`last_played[event] = now` is written when it has). A missing event is silent, with one `push_warning` per process.
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


## Whether the audio stream should really start. Headless (server, unit/net tests; dummy audio driver) has no listener: players process the event
## (stream, volume, pitch, `played`, counters) but do not call `play()`, because a stream started just before shutdown can leak its playback object (IS-029 gate "leaked / still in use at exit").
static func playback_enabled() -> bool:
	return force_playback or DisplayServer.get_name() != "headless"


## Player clock (s, monotonic).
static func now_sec() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
