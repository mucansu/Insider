class_name Fsm
extends RefCounted
## Küçük durum makinesi (US-008 AC1; mimari.md S11, KR-018). Düğümsüz: durumlar tamsayı (beynin enum'u), izinli
## geçişler isteğe bağlı bir kenar tablosuyla verilir. NPC beyinleri (`brain_owner`, `brain_chaser`) ve mekânın
## uyarı merdiveni (I4: bakkal kümesi {0→1, 1→2, 2→3, 3→5, 2→1, 1→0}) aynı sınıfı kullanır.
##
## - `go(to)`: izinli geçişse durumu değiştirir, durumdaki süre sıfırlanır, `changed` yayılır, geçmişe yazılır.
##   Kenar tablosu boşsa her geçiş izinlidir; aynı duruma geçiş yok sayılır (false).
## - `route(to)`: kenarlar üzerinden en kısa durum dizisi (şimdiki hariç, `to` dahil); ulaşılamazsa boş.
##   Uyarı merdiveninde "0'dan 2'ye" isteği 0→1→2 olarak yürünür, atlama olmaz.
## - `step(delta)`: durumdaki süreyi ve makinenin saatini (`clock`) ilerletir (beyin her adımda çağırır).
## - Geçmiş zaman damgalı: `history[i]` durumuna `history_times[i]` saatinde (sn, `clock`) girildi; döküm geçiş
##   sırasını ve süresini kanıtlar.

signal changed(from: int, to: int)

## Geçmişte tutulan en fazla geçiş (döküm/test; eskiler düşer).
const MAX_HISTORY := 256

var state: int = 0
## Şimdiki durumda geçen süre (sn).
var time_in_state: float = 0.0
## Makinenin saati (sn; `step` toplamı).
var clock: float = 0.0
## Geçilen durumlar (ilk durum dahil; en fazla MAX_HISTORY) ve giriş anları (`clock`).
var history: PackedInt32Array = PackedInt32Array()
var history_times: PackedFloat64Array = PackedFloat64Array()

## from -> PackedInt32Array (izinli hedefler); boş = serbest.
var _edges: Dictionary = {}


func _init(initial: int = 0, edges: Dictionary = {}) -> void:
	state = initial
	for from: Variant in edges:
		_edges[int(from)] = PackedInt32Array(edges[from])
	history.append(initial)
	history_times.append(0.0)


func can(to: int) -> bool:
	if to == state:
		return false
	if _edges.is_empty():
		return true
	var targets: PackedInt32Array = _edges.get(state, PackedInt32Array())
	return targets.has(to)


func go(to: int) -> bool:
	if not can(to):
		return false
	var from: int = state
	state = to
	time_in_state = 0.0
	history.append(to)
	history_times.append(clock)
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY)
		history_times = history_times.slice(history_times.size() - MAX_HISTORY)
	changed.emit(from, to)
	return true


func step(delta: float) -> void:
	time_in_state += maxf(delta, 0.0)
	clock += maxf(delta, 0.0)


## Geçmiş, döküm biçiminde: [[durum, giriş anı (sn, 3 basamak)], …]; `names` verilirse durum adı.
func history_rows(names: Array = []) -> Array:
	var out: Array = []
	for i: int in history.size():
		var s: int = history[i]
		out.append([names[s] if s >= 0 and s < names.size() else s, snappedf(history_times[i], 0.001)])
	return out


## Şimdiki durumdan `to`'ya en kısa izinli dizi (şimdiki hariç). Aynı durum ya da ulaşılamaz: boş.
func route(to: int) -> PackedInt32Array:
	return shortest_path(_edges, state, to)


## Kenar tablosunda `from` → `to` en kısa yol (from hariç). Tablo boşsa doğrudan [to].
static func shortest_path(edges: Dictionary, from: int, to: int) -> PackedInt32Array:
	if from == to:
		return PackedInt32Array()
	if edges.is_empty():
		return PackedInt32Array([to])
	var previous: Dictionary = {from: from}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == to:
			break
		for next: int in PackedInt32Array(edges.get(at, PackedInt32Array())):
			if not previous.has(next):
				previous[next] = at
				queue.append(next)
	if not previous.has(to):
		return PackedInt32Array()
	var out := PackedInt32Array()
	var walk: int = to
	while walk != from:
		out.insert(0, walk)
		walk = int(previous[walk])
	return out


## Dizi (ilk öğe başlangıç) yalnız izinli geçişlerden mi oluşuyor (yinelenen ardışık durum geçiş sayılmaz).
static func is_valid_sequence(edges: Dictionary, sequence: PackedInt32Array) -> bool:
	for i: int in range(1, sequence.size()):
		var from: int = sequence[i - 1]
		var to: int = sequence[i]
		if from == to:
			continue
		if not PackedInt32Array(edges.get(from, PackedInt32Array())).has(to):
			return false
	return true
