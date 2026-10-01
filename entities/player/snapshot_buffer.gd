class_name SnapshotBuffer
extends RefCounted
## Uzak oyuncu ara değerleme tamponu (US-004 AC4; S2, GDD §12 "uzak oyuncular 100 ms interpolasyon tamponuyla").
##
## Yöntem: yetkili kopya her fizik adımında durumunu ve kendi saatindeki anı (`Player.net_time`) yazar,
## eşitleyici 20 Hz yayar. Alıcı her paketi (gönderen anı, yerel varış anı, durum) `push` ile koyar; her karede
## `sample(yerel_an)` gönderen saatinde `yerel_an - saat_farkı - delay` anını, o anı çevreleyen iki anlık görüntü
## arasında doğrusal ara değerler (konum lerp, yön slerp, kip öncekinden, hız iki görüntü arası sabit).
## Saat farkı (yerel varış - gönderen anı = tek yön gecikme + saat kayması) üstel ortalamayla izlenir: titreşim
## (jitter) tamponda emilir ve çizim saati düzgün ilerler; 0,5 sn'den büyük sıçramada sıfırdan kurulur.
## Varış anına göre değil gönderen anına göre çizildiği için paketler arası titreşim harekete yansımaz.
## Sıra dışı ya da eski paket atılır. Tampon tükenirse (kayıp) son durumda beklenir; ileri tahmin yapılmaz
## (dönüşte ya da duvar dibinde taşma olmasın).

## Ara değerlenmiş durum.
class Frame extends RefCounted:
	var time: float = 0.0
	var position: Vector2 = Vector2.ZERO
	var facing: Vector2 = Vector2.DOWN
	var mode: int = 0
	var velocity: Vector2 = Vector2.ZERO

	func _init(t: float = 0.0, pos: Vector2 = Vector2.ZERO, dir: Vector2 = Vector2.DOWN, kind: int = 0,
			vel: Vector2 = Vector2.ZERO) -> void:
		time = t
		position = pos
		facing = dir
		mode = kind
		velocity = vel


## Tampondaki en çok anlık görüntü (20 Hz'de 1,6 sn).
const MAX_FRAMES := 32
## Saat farkı ortalamasında yeni ölçümün ağırlığı.
const OFFSET_SMOOTHING := 0.05
## Saat farkı bundan çok sıçrarsa (süreç durdu, saat değişti) ortalama sıfırdan kurulur (sn).
const OFFSET_RESET_SEC := 0.5

## Çizimin gönderen saatinde ne kadar geriden yapıldığı (sn).
var delay: float = 0.1

var _frames: Array[Frame] = []
var _offset: float = 0.0
var _has_offset: bool = false
var _underruns: int = 0


func _init(delay_sec: float = 0.1) -> void:
	delay = delay_sec


## Gelen anlık görüntü. Eskiyse (gönderen anı son görüntüden ileri değilse) atılır ve false döner.
func push(sender_time: float, local_time: float, position: Vector2, facing: Vector2, mode: int) -> bool:
	if not _frames.is_empty() and sender_time <= _frames.back().time:
		return false
	var measured: float = local_time - sender_time
	if not _has_offset or absf(measured - _offset) > OFFSET_RESET_SEC:
		_offset = measured
		_has_offset = true
	else:
		_offset += (measured - _offset) * OFFSET_SMOOTHING
	_frames.append(Frame.new(sender_time, position, facing, mode))
	if _frames.size() > MAX_FRAMES:
		_frames.pop_front()
	return true


## `local_time` anında çizilecek durum; tampon boşsa null.
func sample(local_time: float) -> Frame:
	if _frames.is_empty():
		return null
	var t: float = local_time - _offset - delay
	while _frames.size() >= 2 and _frames[1].time <= t:
		_frames.pop_front()  # artık gerekmeyen eski görüntüler
	var a: Frame = _frames[0]
	if _frames.size() == 1 or t <= a.time:
		if _frames.size() == 1 and t > a.time:
			_underruns += 1  # çizim anı en yeni görüntüyü geçti: veri geç kaldı ya da kayboldu
		return Frame.new(t, a.position, a.facing, a.mode)
	var b: Frame = _frames[1]
	var span: float = b.time - a.time
	var w: float = clampf((t - a.time) / span, 0.0, 1.0)
	return Frame.new(t, a.position.lerp(b.position, w), a.facing.slerp(b.facing, w), a.mode,
		(b.position - a.position) / span)


func size() -> int:
	return _frames.size()


## Çizim anının en yeni görüntüyü geçtiği (beklenen) `sample` çağrısı sayısı; yetkili kopya 20 Hz'de hep
## yayınladığından sağlıklı bağlantıda ısınmadan sonra 0 kalır (teşhis/döküm).
func underrun_count() -> int:
	return _underruns


## İzlenen saat farkı (yerel - gönderen, sn); henüz paket yoksa 0.
func clock_offset() -> float:
	return _offset


func clear() -> void:
	_frames.clear()
	_has_offset = false
	_offset = 0.0
	_underruns = 0
