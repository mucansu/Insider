class_name AgendaTask
extends Resource
## Ajanda görevi (US-008 AC1; GDD §9.3 sahibin dikkat döngüsü): {işaret, süre aralığı, bakış yönü, koni daralması}.
## `Agenda` bileşeni listeyi tohumlu RNG ile sıralar; sayıların tek kaynağı NPC ayar dosyası (ör.
## `data/npc/owner_tuning.tres` alt kaynakları). Süre, NPC işarete vardıktan sonra sayılır.

## Görev adı (task_changed sinyali, döküm; ör. &"counter", &"restock").
@export var name: StringName = &""
## Seviye işareti (S4 Markers). Önek bir dizi ise (`RestockSpot` → RestockSpot1..N) her seferinde biri seçilir.
@export var marker: StringName = &""
@export_range(0.0, 600.0, 0.5, "suffix:s") var min_sec: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var max_sec: float = 0.0
## Vardıktan sonra bakış yönü (global, birim; sıfır = varış yönü korunur).
@export var facing: Vector2 = Vector2.ZERO
## Koni yarım açısı (derece); 0 = NPC'nin varsayılan konisi (telefon: daralır).
@export_range(0.0, 180.0, 0.5, "suffix:°") var half_angle_deg: float = 0.0
## Ev görevi (tezgâh): ajanda ev ↔ diğer görevler dönüşümlü ilerler.
@export var home: bool = false
## Kapı zili bu görevi keser mi (telefon kesmez).
@export var bell_interrupts: bool = true
## Görev noktasındayken çıkan ajanda sesi (US-011b; NoiseProfile türü, ör. &"phone", &"shelf"; boş = sessiz) ve
## aralığı (sn; ilk ses de varıştan bu kadar sonra). Yarıçap NoiseProfile'dan.
@export var noise_kind: StringName = &""
@export_range(0.0, 60.0, 0.1, "suffix:s") var noise_interval_sec: float = 0.0
