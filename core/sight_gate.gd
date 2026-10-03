class_name SightGate
extends RefCounted
## NPC görünürlük kapısı (US-011b AC5; GDD §6.5 "NPC görünürlüğü"; KR-022/KR-023). Düğümsüz: yerel oyuncunun
## görüşüne göre bir NPC'nin bu peer'da nasıl çizileceğine karar verir; mantık ve çarpışma etkilenmez (yalnız
## çizim). Girdi her adımda: NPC tam görünüyor mu (görünen karo ∧ görüş hattı), çevresel bölgede mi (yönlü kip:
## çevresel karo ∧ görüş hattı), NPC'nin konumu ve geçen süre (saat dışarıdan: testlerde enjekte edilir).
##
## Durumlar ve geçişler:
## - FULL: tam çizim (gövde, koni, şüphe göstergesi, balonlar, görev ikonu).
## - SILHOUETTE: yalnız soluk siluet (MUTED α 0,5; balon/koni/yay yok), canlı konumda.
## - Görüşten çıkınca `hold_sec` (0,2 sn, GDD §12 payı) son çizim biçimi canlı konumda sürer (titreme önleme);
##   bu arada yeniden görülürse kesinti yok sayılır.
## - Sonra GHOST: son görüldüğü konumda hareketsiz siluet `ghost_sec` (1,5 sn); son `fade_sec`'te (0,3 sn) solar
##   (hareket azaltmada solma yok: süre bitince anında kaybolur). Yeniden görülünce hayalet hemen biter.
## - Sonra HIDDEN.
## Sis yoksa (sahipsiz test, menü) çağıran hep `seen = true` verir: her şey görünür.

enum Mode { HIDDEN, FULL, SILHOUETTE, GHOST }

const HOLD_SEC := 0.2
const GHOST_SEC := 1.5
const FADE_SEC := 0.3
## Hayalet ve siluet opaklığı (MUTED α 0,5).
const GHOST_ALPHA := 0.5

var hold_sec: float = HOLD_SEC
var ghost_sec: float = GHOST_SEC
var fade_sec: float = FADE_SEC
var reduce_motion: bool = false

var _mode: Mode = Mode.HIDDEN
## Görülürken son çizim biçimi (FULL ya da SILHOUETTE; tutma süresince sürer).
var _last_seen_mode: Mode = Mode.HIDDEN
var _ghost_position: Vector2 = Vector2.INF
var _unseen_for: float = INF


## Bir adım. `full`: tam görünüyor; `peripheral`: çevresel bölgede görülüyor; `pos`: NPC'nin şimdiki konumu.
## Dönüş: bu adımın çizim biçimi.
func step(full: bool, peripheral: bool, pos: Vector2, delta: float) -> Mode:
	if full or peripheral:
		_unseen_for = 0.0
		_last_seen_mode = Mode.FULL if full else Mode.SILHOUETTE
		_ghost_position = pos
		_mode = _last_seen_mode
		return _mode
	_unseen_for += maxf(delta, 0.0)
	if _last_seen_mode == Mode.HIDDEN:
		_mode = Mode.HIDDEN
	elif _unseen_for < hold_sec:
		_mode = _last_seen_mode  # canlı konumda çizilir; hayalet yine son görülen konumda donar
	elif _unseen_for < hold_sec + ghost_sec:
		_mode = Mode.GHOST
	else:
		_mode = Mode.HIDDEN
		_last_seen_mode = Mode.HIDDEN
	return _mode


func mode() -> Mode:
	return _mode


## Tam çiziliyor mu (işaretler: koni, şüphe yayı, balonlar, görev ikonu yalnız bu durumda).
func is_full() -> bool:
	return _mode == Mode.FULL


## Son görüldüğü konum (hayalet burada donar); hiç görülmediyse INF.
func ghost_position() -> Vector2:
	return _ghost_position


## Çizim opaklık çarpanı: FULL 1; SILHOUETTE 0,5; GHOST 0,5 → son `fade_sec`'te 0 (hareket azaltmada solmaz);
## HIDDEN 0.
func alpha() -> float:
	match _mode:
		Mode.FULL:
			return 1.0
		Mode.SILHOUETTE:
			return GHOST_ALPHA
		Mode.GHOST:
			if reduce_motion or fade_sec <= 0.0:
				return GHOST_ALPHA
			var left: float = hold_sec + ghost_sec - _unseen_for
			return GHOST_ALPHA * clampf(left / fade_sec, 0.0, 1.0)
	return 0.0
