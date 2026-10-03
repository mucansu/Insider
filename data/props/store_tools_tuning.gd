class_name StoreToolsTuning
extends Resource
## Bakkal etkileşimleri ayarları (US-010; GDD §9.3 "Oyuncunun araçları", KR-026; mimari.md S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/props/store_tools.tres`; buradaki varsayılanlar nötrdür. Tezgâh (SATIN AL / ARKA
## ODAYA GÖNDER), sahiple konuşma (OYALA) ve raf ucu (DİKKAT DAĞIT: raf devirme + telefon) okur; sahibin beyni
## dikkat dağıtma türlerini ve "yine mi?" bedelini buradan alır.

const PATH := "res://data/props/store_tools.tres"
## Dikkat dağıtma ses türleri (S8; NoiseBus'ta giden StringName). Sahip bunları DİNLE ile karşılar, sayar.
const KIND_TOPPLE := &"topple"
const KIND_CELLPHONE := &"cellphone"
const DISTRACTION_KINDS: Array[StringName] = [KIND_TOPPLE, KIND_CELLPHONE]

@export_group("Tezgâh")
## SATIN AL bedeli (ekip nakdinden; nakit yetmezse bedava, GDD §9.3).
@export_range(0, 1000) var buy_price: int = 0

@export_group("Oyala")
## Konuşma: en uzun süre (basılı tutma; dolunca sahip konuşmayı bitirir) ve menzil (sahipten, px).
@export_range(0.0, 60.0, 0.5, "suffix:s") var talk_max_sec: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var talk_range: float = 0.0

@export_group("Dikkat dağıt")
## Raf devirme gürültüsü (px; KR-026: 320, bağırışla aynı sınıf).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var topple_radius: float = 0.0
## Telefon: bırakıldıktan sonra çalma gecikmesi (sn), gürültü (px), çalma aralığı (sn) ve en çok çalma sayısı;
## sahip bu kadar yakına gelince bulur (px).
@export_range(0.0, 30.0, 0.1, "suffix:s") var phone_delay_sec: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var phone_radius: float = 0.0
@export_range(0.1, 30.0, 0.1, "suffix:s") var phone_ring_interval_sec: float = 1.0
@export_range(1, 100) var phone_ring_max: int = 1
@export_range(0.0, 256.0, 1.0, "suffix:px") var phone_find_px: float = 0.0
## İkinci (ve sonraki) dikkat dağıtmada sahibin sorumluya şüphesi ("yine mi?").
@export_range(0.0, 100.0, 1.0) var again_suspicion: float = 0.0

static var _default: StoreToolsTuning = null


## `data/props/store_tools.tres` (süreç başına bir kez yüklenir).
static func load_default() -> StoreToolsTuning:
	if _default == null:
		_default = load(PATH) as StoreToolsTuning
		if _default == null:
			push_error("StoreToolsTuning: %s yüklenemedi" % PATH)
			_default = StoreToolsTuning.new()
	return _default
