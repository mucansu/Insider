class_name InteractionRequirement
extends Resource
## Etkileşim gereksinimi (US-005; mimari.md S7): Interactable'ın isteğe bağlı koşulu. Kurallar
## `core/interaction_rules.gd`'de; bu dosya yalnız veridir (S10 kalıbı). Örnek: kasa yalnız tezgâh arkasından
## (personel tarafı) boşaltılır → `side` = prop'un yerel ekseninde personel yönü, `side_min` = tezgâh kenarı.

## Gereken etiket (ör. &"lockpick"; boş = yok) ve en düşük kademesi (Faz 2+: loadout/perk verisinden).
@export var required_tag: StringName = &""
@export_range(0, 10) var min_tier: int = 0
## Taraf kısıtı: aktörün bulunması gereken yön, prop'un YEREL ekseninde (prop dönünce birlikte döner);
## ZERO = kısıt yok. Aktör, Interactable merkezinden bu yön boyunca en az `side_min` px ötede olmalı.
@export var side: Vector2 = Vector2.ZERO
@export_range(-64.0, 64.0, 1.0, "suffix:px") var side_min: float = 0.0
