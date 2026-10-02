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

@export_group("Kesmeler")
## Kapı zili (sn), müşteri servisi (sn, US-016), arka odaya gönderilme (sn, US-010), ses dinleme (sn, US-009).
@export_range(0.0, 60.0, 0.1, "suffix:s") var bell_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var customer_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var sent_sec: float = 0.0
@export_range(0.0, 60.0, 0.1, "suffix:s") var listen_sec: float = 0.0
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
## Arka oda nakdi alınmışsa sakinleştikten bu kadar sonra yeniden bağırır (+1 komşu).
@export_range(0.0, 600.0, 1.0, "suffix:s") var recheck_shout_sec: float = 0.0
@export var cash_marker: StringName = &""

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
