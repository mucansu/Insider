class_name PopulationTuning
extends Resource
## Mekân nüfusu profili (US-016 AC1-AC5; GDD §9.2 tablo; mimari.md S10 ayar dosyası kalıbı). Değerlerin tek kaynağı
## `data/npc/population.tres`; buradaki varsayılanlar nötrdür (aralık 0 = o rol kapalı). Nüfus üreticisi
## (`entities/npc/population.gd`) ve sivil beyni (`entities/npc/civilian/brain_civilian.gd`) okur; kurallar
## `core/population_rules.gd`'de. Başlangıç sayıları oyun testiyle ayarlanır (KR-021 geçici).

@export_group("Üretim")
## Tohum (aynı tohum → aynı geliş anları ve planlar, I6).
@export var population_seed: int = 0
## NPC tavanı (sahip + siviller + mahalleli) ve komşuya ayrılan yer.
@export_range(0, 16) var max_npcs: int = 0
@export_range(0, 6) var neighbour_reserve: int = 0
## Bu uyarı kademesinden itibaren yeni sivil gelmez, içerideki müşteriler kaçar (0 = hiç).
@export_range(0, 5) var pause_alert_level: int = 0

@export_group("Müşteri")
## İlk geliş [min, max] sn; sonra aralık ± sapma (sn; 0 = müşteri yok).
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_first_min: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_first_max: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_interval: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var customer_jitter: float = 0.0
## Aynı anda en fazla müşteri.
@export_range(0, 6) var customer_max: int = 0
## Kalış [min, max] sn; raf noktası sayısı [min, max] ve nokta başına süre [min, max] sn.
@export_range(0.0, 600.0, 0.5, "suffix:s") var stay_min_sec: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var stay_max_sec: float = 0.0
@export_range(0, 5) var shop_spots_min: int = 1
@export_range(0, 5) var shop_spots_max: int = 1
@export_range(0.0, 120.0, 0.5, "suffix:s") var shop_min_sec: float = 0.0
@export_range(0.0, 120.0, 0.5, "suffix:s") var shop_max_sec: float = 0.0
## Kalış planında iki raf noktasına yer var mı hesabı için yürüme payı (sn).
@export_range(0.0, 120.0, 0.5, "suffix:s") var walk_margin_sec: float = 0.0
## Kuyrukta servis beklemenin üst sınırı (sn; sonra bırakıp çıkar).
@export_range(0.0, 120.0, 0.5, "suffix:s") var queue_wait_sec: float = 0.0
## Yürüme hızı (px/sn).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var customer_speed: float = 0.0
## İşaretler: doğduğu/çıktığı sokak noktası, ön kapı, raf noktası ve kuyruk dizileri, kuyrukta bakılan işaret.
@export var customer_spawn_marker: StringName = &""
@export var customer_exit_marker: StringName = &""
@export var front_door_marker: StringName = &""
@export var shop_prefix: StringName = &""
@export var queue_prefix: StringName = &""
@export var queue_look_marker: StringName = &""
## Görüş konisi: yarım açı (derece), menzil (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var customer_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var customer_view_range: float = 0.0

@export_group("Yoldan geçen")
## Geliş aralığı ± sapma (sn; 0 = yoldan geçen yok) ve sokakta en fazla.
@export_range(0.0, 600.0, 0.5, "suffix:s") var passerby_interval: float = 0.0
@export_range(0.0, 600.0, 0.5, "suffix:s") var passerby_jitter: float = 0.0
@export_range(0, 6) var passerby_max: int = 0
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var passerby_speed: float = 0.0
## Her cam parçasında içeri bakma olasılığı ve süresi (sn).
@export_range(0.0, 1.0, 0.01) var look_chance: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var look_sec: float = 0.0
## Rota ve cam önü işaret dizileri.
@export var route_prefix: StringName = &""
@export var window_prefix: StringName = &""
## Görüş konisi (camdan geçer): yarım açı (derece), menzil (px).
@export_range(0.0, 180.0, 0.5, "suffix:°") var passerby_half_angle_deg: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var passerby_view_range: float = 0.0

@export_group("Tanık")
## "?" sonrası duruş: eşik altına inince bu kadar sonra işine döner (sn).
@export_range(0.0, 10.0, 0.05, "suffix:s") var watch_release_sec: float = 0.0
## Sahibi görüş: görüş hattı + bu menzil (px).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var owner_sight_range: float = 0.0
## Sahibe söyleme: yürüyüş hızı, söyleme mesafesi (px), en az / en çok süre (sn) ve sahibin şüphesine eklenen.
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var tell_speed: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var tell_reach: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var tell_min_sec: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var tell_max_sec: float = 0.0
@export_range(0.0, 100.0, 1.0) var tell_suspicion: float = 0.0
## Kaçış hızı (px/sn).
@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var flee_speed: float = 0.0

@export_group("Dönüşüm")
## Sahip bağırınca bu yarıçap (px; sahibin konumundan) içindeki yoldan geçenler mahalleliye dönüşür (0 = yok).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var convert_radius: float = 0.0


## Core ayarları (`PopulationRules.Params`). `window_count` cam önü işaret sayısı; `serve_sec` sahibin servisi.
func rules_params(window_count: int, serve_sec: float) -> PopulationRules.Params:
	var p := PopulationRules.Params.new()
	p.customer_first_min = customer_first_min
	p.customer_first_max = customer_first_max
	p.customer_interval = customer_interval
	p.customer_jitter = customer_jitter
	p.customer_max = customer_max
	p.stay_min = stay_min_sec
	p.stay_max = stay_max_sec
	p.min_spots = shop_spots_min
	p.max_spots = shop_spots_max
	p.shop_min = shop_min_sec
	p.shop_max = shop_max_sec
	p.serve_sec = serve_sec
	p.walk_margin_sec = walk_margin_sec
	p.passerby_interval = passerby_interval
	p.passerby_jitter = passerby_jitter
	p.passerby_max = passerby_max
	p.look_chance = look_chance
	p.look_sec = look_sec
	p.window_count = window_count
	p.max_npcs = max_npcs
	p.reserve = neighbour_reserve
	p.pause_alert_level = pause_alert_level
	return p
