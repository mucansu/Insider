class_name PerceptionTuning
extends Resource
## Algı ve şüphe ayarları (US-006 AC3; mimari.md S10 ayar dosyası kalıbı, S11, KR-019). Değerlerin tek kaynağı
## `data/npc/perception_tuning.tres`; buradaki varsayılanlar nötrdür. Hesap core/'da (PerceptionRules,
## SuspicionMeter); Perception/Suspicion bileşenleri bu kaynağı okuyup core değer nesnelerine çevirir.
## Başlangıç sayıları oyun testiyle ayarlanır (KR-019 geçici).

@export_group("Koni")
## Muhafız görüş konisi: yarım açı (derece) ve menzil (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var guard_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var guard_view_range: float = 0.0
## Kamera görüş konisi (kamera = hareketsiz gözlemci, aynı algı kodu).
@export_range(0.0, 180.0, 0.5, "suffix:°") var camera_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var camera_view_range: float = 0.0
## Yakın bant sınırı: menzilin oranı (R/2 → 0,5).
@export_range(0.0, 1.0, 0.01) var near_ratio: float = 0.0
## Bant çarpanları.
@export_range(0.0, 10.0, 0.05) var near_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var far_factor: float = 0.0
## Gözlemcinin bakış yönü dönüş tavanı (derece/sn).
@export_range(0.0, 1080.0, 1.0, "suffix:°/s") var max_turn_deg_per_sec: float = 0.0

@export_group("Dolum")
## Temel dolum (birim/sn): dolum = temel × bant × durum.
@export_range(0.0, 1000.0, 0.5, "suffix:/s") var base_fill_per_sec: float = 0.0
## Durum çarpanları (hareket kipi); karanlık bölge kipi ezer.
@export_range(0.0, 10.0, 0.05) var sprint_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var walk_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var sneak_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var dark_factor: float = 0.0
## Görülmezken boşalma (birim/sn).
@export_range(0.0, 1000.0, 0.5, "suffix:/s") var decay_per_sec: float = 0.0

@export_group("Eşikler")
## "?" (gözlemci bakar), inceleme, tespit (0-100).
@export_range(0.0, 100.0, 1.0) var notice_threshold: float = 0.0
@export_range(0.0, 100.0, 1.0) var investigate_threshold: float = 0.0
@export_range(0.0, 100.0, 1.0) var detect_threshold: float = 0.0
## Oyuncu lehine pay (sn; S2, GDD §12).
@export_range(0.0, 2.0, 0.01, "suffix:s") var grace_sec: float = 0.0
## Görülme dizisini bozmayan kısa kesinti (sn): bundan kısa görüş kaybında pay sıfırlanmaz, boşalma başlamaz.
@export_range(0.0, 2.0, 0.01, "suffix:s") var gap_tolerance_sec: float = 0.0
