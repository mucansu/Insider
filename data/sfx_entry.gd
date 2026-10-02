class_name SfxEntry
extends Resource
## Ses kataloğunda tek olay (IS-024; S10 kalıbı, docs/tasarim/arastirma/ses-ve-sfx.md §2). Kod sesi yalnız
## olay adıyla çalar (`SfxEmitter.play_on(self, &"door_open")`, `UiSfx.of(self).play_event(&"ui_click")`);
## dosya yolu yalnız burada durur. Sesi değiştirmek = `stream` dosyasını yenilemek (aynı yol) ya da bu
## girdide başka dosyaya işaret etmek; kod değişmez. Değişen her dosya docs/notes/assetler.md'de satırdır.

## Olay adı (katalogda tekil; ör. &"door_open").
@export var event: StringName = &""
@export var stream: AudioStream
## Taban ses düzeyi (dB); çalar her çalışta buna ayarlanır.
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0
## Perde aralığı: her çalışta [pitch_min, pitch_max] içinden rastgele (tekrarda bıkkınlığı azaltır).
@export_range(0.25, 4.0, 0.01) var pitch_min: float = 1.0
@export_range(0.25, 4.0, 0.01) var pitch_max: float = 1.0
## Aynı çalardan aynı olayın iki çalışı arasındaki en kısa süre (sn). Tekrarlayan seste (kasa tiki) ritmi de
## belirler (`SfxEmitter.repeat_while`).
@export_range(0.0, 5.0, 0.01) var min_interval: float = 0.08
## Konumlu seste (AudioStreamPlayer2D) duyulma mesafesi, px; 0 = çaların kendi değeri. Kural: gürültü
## yarıçapının (S8) 2 katı (ses-ve-sfx §1 kural 3); arayüz seslerinde kullanılmaz.
@export_range(0.0, 4000.0, 1.0) var max_distance: float = 0.0
## Geçici yer tutucu ses (CC0 indirme; ileride üretilecek sesle değişecek). Üretim sesi gelince false.
@export var placeholder: bool = true


## Bu çalış için perde (aralık ters girilmişse uçlar yer değiştirir).
func pick_pitch(rng: RandomNumberGenerator) -> float:
	var lo: float = minf(pitch_min, pitch_max)
	var hi: float = maxf(pitch_min, pitch_max)
	return lo if is_equal_approx(lo, hi) else rng.randf_range(lo, hi)
