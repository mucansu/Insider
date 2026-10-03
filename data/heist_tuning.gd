class_name HeistTuning
extends Resource
## Soygun sonucu ayarları (US-040 eli boş çekilme, US-041 kefalet / KR-029; mimari.md S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/heist_tuning.tres`; buradaki varsayılanlar nötrdür. Kurallar düğümsüz
## `HeistRules`'ta (core/heist_rules.gd); Game (host) iş başında bu kaynağı okuyup kurala verir.

const PATH := "res://data/heist_tuning.tres"

## Eli boş çekilme: yakalanmamış herkes ganimetsiz kaçış bölgesinde bu kadar kesintisiz kalınca iş `aborted`
## sonucuyla biter (sn).
@export_range(0.0, 30.0, 0.1, "suffix:s") var abort_hold_s: float = 0.0
## Kefalet: mekân kademesi -> iş sonunda yakalanan her oyuncu için ekip kasasından düşen tutar. Tabloda olmayan
## kademe en yakın alt kademenin tutarını kullanır (HeistRules.bail_for_tier).
@export var bail_by_tier: Dictionary[int, int] = {}

static var _default: HeistTuning = null


## `data/heist_tuning.tres` (süreç başına bir kez yüklenir).
static func load_default() -> HeistTuning:
	if _default == null:
		_default = load(PATH) as HeistTuning
		if _default == null:
			push_error("HeistTuning: %s yüklenemedi" % PATH)
			_default = HeistTuning.new()
	return _default
