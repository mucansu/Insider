class_name PropDef
extends Resource
## Etkileşimli nesne tanımı (US-005; mimari.md S10): `data/props/<id>.tres`, id = dosya adı. Prop sahnesi
## kendi tanımını bağlar ve `_ready`'de değerleri Interactable bileşenine aktarır (S7); sayıların tek kaynağı
## bu dosyalardır, betik varsayılanları nötrdür. Ağda yalnız durum gider, tanım gitmez.

## Etkileşim eyleminin i18n anahtarı (HUD istemi "[E] <eylem>", S9).
@export var action_key: String = ""
## İkinci durumun eylem anahtarı (ör. kapı açıkken "kapat"); boşsa action_key.
@export var alt_action_key: String = ""
## Basılı tutma süresi (sn); 0 = anlık.
@export_range(0.0, 60.0, 0.05, "suffix:s") var hold_time: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var interact_range: float = 0.0
## Tamamlanınca ekip nakdine eklenen tutar (kasa).
@export_range(0, 1000000) var cash_value: int = 0
@export var requirement: InteractionRequirement


## id = dosya adı (S10); kaydedilmemiş tanımda boş.
func id() -> StringName:
	return StringName(resource_path.get_file().get_basename())
