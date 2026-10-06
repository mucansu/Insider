class_name SfxEntry
extends Resource
## A single event in the sound catalogue (IS-024; S10 pattern, docs/tasarim/arastirma/ses-ve-sfx.md §2). Code plays sound only by event name (`SfxEmitter.play_on(self, &"door_open")`, `UiSfx.of(self).play_event(&"ui_click")`);
## the file path lives only here. Changing a sound = refreshing the `stream` file (same path) or pointing this entry to another file; no code change. Every changed file gets a line in docs/notes/assetler.md.

## Event name (unique in the catalogue; e.g. &"door_open").
@export var event: StringName = &""
@export var stream: AudioStream
## Base volume (dB); the player is set to it on every play.
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0
## Pitch range: random in [pitch_min, pitch_max] on every play (reduces fatigue on repeats).
@export_range(0.25, 4.0, 0.01) var pitch_min: float = 1.0
@export_range(0.25, 4.0, 0.01) var pitch_max: float = 1.0
## Min time between two plays of the same event from the same player (s). For repeating sounds (register tick) it also sets the rhythm
## (`SfxEmitter.repeat_while`).
@export_range(0.0, 5.0, 0.01) var min_interval: float = 0.08
## Audible distance for positional sound (AudioStreamPlayer2D), px; 0 = the player's own value. Rule: 2x the noise radius (S8)
## (ses-ve-sfx §1 rule 3); not used for UI sounds.
@export_range(0.0, 4000.0, 1.0) var max_distance: float = 0.0
## Audio bus (US-047 AC1; default_bus_layout.tres: Music, Ambience, SFX, UI, VO). Players set it on every play; a missing bus name falls back to
## Master (Godot). Level settings per bus are US-025; per-sound levels stay in `volume_db` (single place: data/sfx_catalog.tres).
@export var bus: StringName = &"SFX"
## Extra variants (US-047 AC2): one of `stream` + `variants` is picked at random on every play (reduces repetition on footsteps).
@export var variants: Array[AudioStream] = []
## Temporary placeholder sound (CC0 download; to be replaced by produced sound). Set false once the production sound arrives.
@export var placeholder: bool = true


## Pitch for this play (if the range is entered reversed, the ends swap).
func pick_pitch(rng: RandomNumberGenerator) -> float:
	var lo: float = minf(pitch_min, pitch_max)
	var hi: float = maxf(pitch_min, pitch_max)
	return lo if is_equal_approx(lo, hi) else rng.randf_range(lo, hi)


## Stream for this play: `stream` or one of `variants` (uniform); null if there is no file.
func pick_stream(rng: RandomNumberGenerator) -> AudioStream:
	var pool: Array[AudioStream] = []
	if stream != null:
		pool.append(stream)
	for v: AudioStream in variants:
		if v != null:
			pool.append(v)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)] if pool.size() > 1 else pool[0]
