class_name VisionTuning
extends Resource
## Oyuncu görüşü ve sis ayarları (US-011a AC1; GDD §6.5, KR-022/KR-023; mimari.md S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/vision_tuning.tres`; buradaki varsayılanlar nötrdür. Hesap core/'da
## (`VisionGrid`); sis katmanı (`FogLayer`, levels/fog) bu kaynağı okuyup `VisionGrid.Params`'a çevirir.
## Başlangıç sayıları oyun testiyle ayarlanır (GDD §6.5 "başlangıç değerleri").

const PATH := "res://data/vision_tuning.tres"

@export_group("Menzil")
## Aydınlıkta görüş yarıçapı (px): NPC menzili + 1 karo.
@export_range(0.0, 2048.0, 1.0, "suffix:px") var view_radius: float = 0.0
## Karanlık bölgede duran oyuncunun yarıçapı (px; KR-019 ikili ışık).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var dark_radius: float = 0.0
## Görüş kenarı soluklaşması (yalnız görsel, px): yarıçapın son bu kadarı hafıza tonuna kayar.
@export_range(0.0, 256.0, 1.0, "suffix:px") var soft_edge_px: float = 0.0

@export_group("Kip")
## Varsayılan görüş kipi (VisionGrid.Mode: 0 peripheral = çevresel 360°, 1 directional = yönlü). Host kuralı;
## seçimi US-011b/US-011d.
@export_enum("Peripheral", "Directional") var default_mode: int = 0
## Yönlü kip: net koni yarım açısı (derece; 45 → 90° koni), menzil = view_radius.
@export_range(0.0, 180.0, 0.5, "suffix:°") var cone_half_angle_deg: float = 0.0
## Yönlü kip: çevresel bölge yarım açısı (derece; 90 → önde 180°) ve menzili (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var peripheral_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var peripheral_radius: float = 0.0
## 360° yakın halka (px): her kipte bu mesafe her yönde görünür (görüş hattı yine gerekir).
@export_range(0.0, 512.0, 1.0, "suffix:px") var near_radius: float = 0.0
## Bakış dönüş tavanı (derece/sn); bakış girdisi US-011b'de uygular, burada yalnız sayı.
@export_range(0.0, 1080.0, 1.0, "suffix:°/s") var max_turn_deg_per_sec: float = 0.0

@export_group("Zamanlama ve hafıza")
## Izgara güncelleme aralığı (sn).
@export_range(0.01, 1.0, 0.01, "suffix:s") var update_interval_sec: float = 0.1
## Görülen karo görüşten çıkınca hafızada kalır (faz içi; seviye yüklenince sıfırlanır).
@export var memory_enabled: bool = true
## Karo tonu geçişi (sn); hareket azaltma açıkken anlık.
@export_range(0.0, 2.0, 0.01, "suffix:s") var transition_sec: float = 0.0
## Karo kenarı yumuşatma (px; yalnız görsel).
@export_range(0.0, 32.0, 1.0, "suffix:px") var edge_blur_px: float = 0.0
