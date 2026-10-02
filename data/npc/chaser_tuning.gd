class_name ChaserTuning
extends Resource
## Mahalleli (chaser) ayarları (US-008 AC6; GDD §9.3; KR-021; ON-08). Değerlerin tek kaynağı
## `data/npc/chaser_tuning.tres`; buradaki varsayılanlar nötrdür. Hız koşudan (220) düşük: koşan oyuncu açık
## alanda 10 karoda ≥ 1 karo açar (birim test), köşe ve kapıda yakalanır.

## Koşu hızı (px/sn) ve ivme (px/sn²).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var speed: float = 0.0
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var acceleration: float = 0.0
## Görüş: koni yok (aranan kişiye bakıyor), görüş hattı + menzil (px).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var sight_range: float = 0.0
## Görüş yoksa son görülen konumu arama süresi (sn); sonra ön kapıda bekler.
@export_range(0.0, 120.0, 0.5, "suffix:s") var search_sec: float = 0.0
@export var wait_marker: StringName = &""
