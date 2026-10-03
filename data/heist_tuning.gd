class_name HeistTuning
extends Resource
## Soygun sonucu ayarları (US-040 eli boş çekilme, US-041 kefalet / KR-029, US-042 örtü ve tanık sorgusu;
## mimari.md S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/heist_tuning.tres`; buradaki varsayılanlar nötrdür. Kurallar düğümsüz
## `HeistRules`'ta (core/heist_rules.gd); Game (host) iş başında bu kaynağı okuyup kurala verir.

const PATH := "res://data/heist_tuning.tres"

## Eli boş çekilme: yakalanmamış herkes ganimetsiz kaçış bölgesinde bu kadar kesintisiz kalınca iş `aborted`
## sonucuyla biter (sn).
@export_range(0.0, 30.0, 0.1, "suffix:s") var abort_hold_s: float = 0.0
## Kefalet: mekân kademesi -> iş sonunda yakalanan her oyuncu için ekip kasasından düşen tutar. Tabloda olmayan
## kademe en yakın alt kademenin tutarını kullanır (HeistRules.bail_for_tier).
@export var bail_by_tier: Dictionary[int, int] = {}

@export_group("Örtü ve tanık sorgusu (US-042)")
## İlişkilendirme penceresi: arkadaş bu kadar sn önce işaretlendiyse (sahip bağırdı/tuttu, maske) onunla görülen
## yakın etkileşim örtüyü bozar.
@export_range(0.0, 60.0, 0.1, "suffix:s") var cover_mark_window_s: float = 0.0
## İlişkilendirme mesafesi: etkileşen iki oyuncu arası en fazla (px).
@export_range(0.0, 256.0, 1.0, "suffix:px") var association_radius_px: float = 0.0
## İlişkilendirmeyi gören gözlemcinin o oyuncuya şüphe artışı (müşteri-tanık yolu ile aynı: population.tres
## tell_suspicion).
@export_range(0.0, 100.0, 1.0) var association_suspicion: float = 0.0
## Tanık sorgusuyla serbest bırakılan her oyuncu için ekip ısısı.
@export_range(0, 50) var witness_heat: int = 0

static var _default: HeistTuning = null


## `data/heist_tuning.tres` (süreç başına bir kez yüklenir).
static func load_default() -> HeistTuning:
	if _default == null:
		_default = load(PATH) as HeistTuning
		if _default == null:
			push_error("HeistTuning: %s yüklenemedi" % PATH)
			_default = HeistTuning.new()
	return _default
