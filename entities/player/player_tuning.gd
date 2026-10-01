class_name PlayerTuning
extends Resource
## Oyuncu hareket ve ağ ayarları (US-004; mimari.md S10 ayar dosyası kalıbı). Değerlerin tek kaynağı
## `data/player_tuning.tres` (yürü 140, sız 70, koş 220 px/sn …); buradaki varsayılanlar nötrdür, oyuncu
## sahnesi o dosyayı bağlar. Hesap PlayerMotion'da (düğümsüz), ara değerleme SnapshotBuffer'da.

## Hareket kiplerinin tam hızı (px/sn; US-004 AC2).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var walk_speed: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var sneak_speed: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var sprint_speed: float = 0.0
## Girdi varken hedef hıza yaklaşma ivmesi (px/sn²).
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var acceleration: float = 0.0
## Girdi bırakılınca ya da daha yavaş hedefe geçince fren ivmesi (px/sn²).
@export_range(0.0, 10000.0, 1.0, "suffix:px/s²") var deceleration: float = 0.0
## Uzak kopyaların ne kadar geriden çizildiği (sn; GDD §12 "100 ms interpolasyon tamponu", S2).
@export_range(0.0, 1.0, 0.005, "suffix:s") var interpolation_delay: float = 0.0
## Yerel oyuncu kamerasının yakınlaştırması.
@export_range(0.25, 4.0, 0.05) var camera_zoom: float = 1.0
