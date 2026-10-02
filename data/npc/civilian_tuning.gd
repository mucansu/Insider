class_name CivilianTuning
extends Resource
## Sivil gözlemci ayarları (US-008; GDD §6.1 sivil çarpan tablosu, §9.3; mimari.md S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/npc/civilian_tuning.tres`; buradaki varsayılanlar nötrdür. Hesap
## `CivilianRules`'ta (core/, düğümsüz); taban dolum, bantlar, eşikler ve oyuncu lehine pay US-006
## `perception_tuning.tres`'ten gelir. Başlangıç sayıları oyun testiyle ayarlanır (KR-021 geçici).

@export_group("Koni")
## Sivil görüş konisi: yarım açı (derece) ve menzil (px); yakın bant perception_tuning.near_ratio ile.
@export_range(0.0, 180.0, 0.5, "suffix:°") var half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var view_range: float = 0.0
## Koni kenarı histerezisi (AC8): görülmekte olan hedef için koni bu kadar genişler (50°/224 → 53°/238 px).
@export_range(0.0, 45.0, 0.5, "suffix:°") var hysteresis_angle_deg: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var hysteresis_range: float = 0.0

@export_group("Çarpan tablosu")
## Müşteri bölgesinde masum sayılan süre (sn); sonra oyalanma çarpanı.
@export_range(0.0, 600.0, 1.0, "suffix:s") var loiter_grace_sec: float = 0.0
@export_range(0.0, 10.0, 0.05) var loiter_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var sneak_factor: float = 0.0
@export_range(0.0, 10.0, 0.05) var sprint_factor: float = 0.0
## Personel tarafı / arka oda / "yalnızca personel" kapısı.
@export_range(0.0, 10.0, 0.05) var staff_factor: float = 0.0
## Çanta taşıma, kilit açma.
@export_range(0.0, 10.0, 0.05) var bag_or_lock_factor: float = 0.0
## Kasa ya da nakit etkileşimi (tut sürerken).
@export_range(0.0, 10.0, 0.05) var cash_factor: float = 0.0
## Bağırıştan sonra herkes (uyarı ≥ alarm_level).
@export_range(0.0, 10.0, 0.05) var alarm_factor: float = 0.0
@export_range(0, 5) var alarm_level: int = 0
## Görünüp masumken (çarpan 0) boşalma (birim/sn); görünmeyince perception_tuning.decay_per_sec.
@export_range(0.0, 1000.0, 0.5, "suffix:/s") var innocent_decay_per_sec: float = 0.0

@export_group("Gösterge ve temas")
## "?" göstergesi eşiğin bu kadar altına inince söner (istemci, ON-04).
@export_range(0.0, 50.0, 0.5) var bubble_hysteresis: float = 0.0
## Tutma/yakalama: menzil (px) ve kesintisiz temas süresi (sn).
@export_range(0.0, 256.0, 1.0, "suffix:px") var contact_reach: float = 0.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var contact_time: float = 0.0
## ON-03: oyuncu konumunu hızı yönünde ileri alma tavanı (sn; RTT/2 ile sınırlı).
@export_range(0.0, 1.0, 0.01, "suffix:s") var lead_cap_sec: float = 0.0


## Core çarpan tablosu; eşikler algı ayarından.
func rules_params(perception: PerceptionTuning) -> CivilianRules.Params:
	var p := CivilianRules.Params.new()
	p.loiter_grace = loiter_grace_sec
	p.loiter_factor = loiter_factor
	p.sneak_factor = sneak_factor
	p.sprint_factor = sprint_factor
	p.staff_factor = staff_factor
	p.bag_or_lock_factor = bag_or_lock_factor
	p.cash_factor = cash_factor
	p.alarm_factor = alarm_factor
	p.alarm_level = alarm_level
	p.innocent_decay = innocent_decay_per_sec
	p.bubble_hysteresis = bubble_hysteresis
	if perception != null:
		p.notice_at = perception.notice_threshold
		p.detect_at = perception.detect_threshold
	return p
