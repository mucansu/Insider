class_name SpotRegistry
extends RefCounted
## Nokta rezervasyonu (US-016 AC1; oyun-yz tur 2 #12; GDD §9.2). Düğümsüz: işaret adı (StringName) → tutan
## sahip kimliği (int, ör. NPC sıra numarası). Aynı noktayı iki sahip aynı anda tutamaz (iki müşteri aynı rafa ya
## da kuyruk noktasına gelmez). Sahip görevi bitince/kesmede ya da silinince `release` ile bırakır. Yalnız host'ta
## kullanılır (nüfus üreticisi tek kayıt tutar, NPC'lere verir); ağ yok.

## spot -> holder (0 = yok; kayıtta tutulmaz).
var _holders: Dictionary = {}


## `spot`'u `holder` için tutar. Boşsa ya da zaten onunsa true; başkasınınsa false. Geçersiz girdi false.
func claim(spot: StringName, holder: int) -> bool:
	if spot.is_empty() or holder == 0:
		return false
	var current: int = int(_holders.get(spot, 0))
	if current != 0 and current != holder:
		return false
	_holders[spot] = holder
	return true


## `holder`'ın tuttuğu noktaları bırakır; `spot` verilirse yalnız onu (başkasınınsa dokunmaz).
func release(holder: int, spot: StringName = &"") -> void:
	if not spot.is_empty():
		if int(_holders.get(spot, 0)) == holder:
			_holders.erase(spot)
		return
	for key: StringName in _holders.keys():
		if int(_holders[key]) == holder:
			_holders.erase(key)


func is_free(spot: StringName) -> bool:
	return not _holders.has(spot)


## Noktayı tutan (0 = boş).
func holder_of(spot: StringName) -> int:
	return int(_holders.get(spot, 0))


## `holder`'ın tuttuğu noktalar (ada göre sıralı).
func spots_of(holder: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for key: StringName in _holders:
		if int(_holders[key]) == holder:
			out.append(key)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## Adaylardan boş olanlar (aday sırası korunur).
func free_of(candidates: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for spot: StringName in candidates:
		if is_free(spot):
			out.append(spot)
	return out


## Adaylardan ilk boşunu `holder` için tutar; yoksa boş StringName.
func claim_first(candidates: Array[StringName], holder: int) -> StringName:
	for spot: StringName in candidates:
		if claim(spot, holder):
			return spot
	return &""


func size() -> int:
	return _holders.size()


func clear() -> void:
	_holders.clear()
