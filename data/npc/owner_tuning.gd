class_name OwnerTuning
extends Resource
## Bakkal sahibi ayarları (US-008; GDD §9.3 dikkat döngüsü ve tepki zinciri; mimari.md S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/npc/owner_tuning.tres`; buradaki varsayılanlar nötrdür. Sahibin beyni
## (`brain_owner.gd`) ve bakkalın uyarı yöneticisi (`store_alert.gd`) okur. Başlangıç sayıları oyun testiyle
## ayarlanır (KR-021 geçici).

@export_group("Ajanda")
## Ajandanın tohumu (aynı tohum → aynı görev dizisi, I6).
@export var agenda_seed: int = 0
## Görevler (ev görevi + pencere görevleri).
@export var tasks: Array[AgendaTask] = []
## Ajandada yürüme hızı (px/sn).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var walk_speed: float = 0.0
## Sahibin arkasından kapattığı iç kapılar (Props düğüm adı; IS-087 AC2: D) ve geçişten sonraki gecikme (sn).
## Ön kapı mesaide açık kalır (listede yok).
@export var close_behind_doors: Array[StringName] = []
@export_range(0.0, 5.0, 0.05, "suffix:s") var close_behind_sec: float = 0.0

@export_group("Kesmeler")
## Kapı zili (sn), müşteri servisi (sn, US-016), arka odaya gönderilme (sn, US-010), ses dinleme (sn, US-009).
@export_range(0.0, 60.0, 0.1, "suffix:s") var bell_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var customer_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var sent_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var listen_sec: float = 0.0
## İşitmenin köşe kırınımı (px; Hearing.corner_spread_px, US-010: tezgâhtaki sahip raf ucu devirmesini duvar
## köşesini sıyıran sesten de duyar; 0 = kapalı).
@export_range(0.0, 32.0, 0.5, "suffix:px") var hearing_corner_px: float = 0.0
## Ön kapı geçişini zil sayma yarıçapı (px; kapı işaretinden).
@export_range(0.0, 256.0, 1.0, "suffix:px") var bell_radius: float = 0.0
## Müşteri servisi ve arka oda kesmesinin işaretleri.
@export var counter_marker: StringName = &""
@export var backroom_marker: StringName = &""
@export var front_door_marker: StringName = &""

@export_group("Tepki")
## "?" sonrası duruş: en az / en çok (sn).
@export_range(0.0, 10.0, 0.05, "suffix:s") var look_min_sec: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var look_max_sec: float = 0.0
## Sorgu: yürüyüş hızı, durma mesafesi, bekleme ve en uzun sorgu.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var question_speed: float = 0.0
@export_range(0.0, 512.0, 1.0, "suffix:px") var question_stop: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var question_wait_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var question_max_sec: float = 0.0
## Bağırış: gürültü yarıçapı, yineleme aralığı; görüş yoksa sakinleşme süresi.
@export_range(0.0, 2048.0, 1.0, "suffix:px") var shout_radius: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var shout_repeat_sec: float = 0.0
@export_range(0.0, 600.0, 1.0, "suffix:s") var calm_after_sec: float = 0.0
## Arka oda nakdinin işareti (US-039 keşif: çanta yerinden oynamış mı).
@export var cash_marker: StringName = &""

@export_group("Servis ve keşif")
## Müşteri servisinde bakış yönü (global; GDD §9.2: batıya döner) ve "kasa açılır" anı (servisin kaçıncı sn'si;
## US-039 satış tetiği, US-010 SATIN AL aynı kancayı kullanır).
@export var serve_facing: Vector2 = Vector2.ZERO
@export_range(0.0, 60.0, 0.1, "suffix:s") var register_open_sec: float = 0.0
## Kasanın işareti (keşif: kasa `emptied`).
@export var register_marker: StringName = &""
## Keşif (US-039 AC4): DISCOVER durumu süresi (sn; durur, balon), sonra bağırış akışı.
@export_range(0.0, 10.0, 0.05, "suffix:s") var discover_sec: float = 0.0
## Arka oda tetiği (AC2): arka oda görevine (ya da gönderilmeye) varıştan bu kadar sonra nakit kontrolü (sn).
@export_range(0.0, 30.0, 0.1, "suffix:s") var backroom_check_sec: float = 0.0
## Arka oda görevinin adı (AgendaTask.name; sakinleşince ilk göreve zorlanır, AC6).
@export var backroom_task: StringName = &""
## Boşta tetiği (AC3): kasa boşken ve içeride müşteri yokken tezgâhta (ClerkSpot, ev görevi) geçen toplam süre (sn;
## 0 = kapalı).
@export_range(0.0, 600.0, 1.0, "suffix:s") var idle_discover_sec: float = 0.0

@export_group("Tutma")
## Kovalama hızı (px/sn); tutma penceresi ilk / sonraki (sn); kurtarılınca sendeleme (sn) ve kurtarana şüphe.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var hold_speed: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var hold_window_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var hold_window_repeat_sec: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var stagger_sec: float = 0.0
@export_range(0.0, 100.0, 1.0) var rescuer_suspicion: float = 0.0

@export_group("Uyarı ve mahalleli")
## Uyarı 1 → 0 için sahibin bu kadar sakin kalması (sn).
@export_range(0.0, 120.0, 0.5, "suffix:s") var alert_calm_sec: float = 0.0
## Bağırıştan komşunun çıkmasına (sn) ve en fazla komşu.
@export_range(0.0, 120.0, 0.5, "suffix:s") var neighbour_delay_sec: float = 0.0
@export_range(0, 6) var max_neighbours: int = 0
@export var neighbour_marker: StringName = &""
## Mahalleli içeride (uyarı 3) → polis sayacı (sn).
@export_range(0.0, 600.0, 1.0, "suffix:s") var police_timer_sec: float = 0.0
## Mahallelinin "içeri girdi" sayıldığı kapı işaretleri ve yarıçap (px).
@export var entry_markers: Array[StringName] = []
@export_range(0.0, 256.0, 1.0, "suffix:px") var entry_radius: float = 0.0
