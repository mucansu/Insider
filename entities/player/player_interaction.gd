class_name PlayerInteraction
extends Node
## Oyuncunun etkileşim tarafı (US-005; mimari.md S7): yalnız yerel oyuncuda çalışır. Player her fizik adımında
## `tick` çağırır; bu düğüm yakındaki en yakın uygun Interactable'ı bulur (kurallar InteractionRules'ta,
## toleranssız), `interact` basılınca (basılı tutmanın ön kenarı; bot `hold` adımı da) host'a istek yollar,
## bırakınca ya da hedeften (+ S2 toleransı) uzaklaşınca iptal yollar. Sonuç host'tan gelir (S2): istemci
## kendi başına sonuç üretmez. İlerleme yerelde hemen gösterilir (GDD §12): `started` basışta yayılır; host
## reddederse ya da iptal ederse `finished(false)` (ceza yok, ilerleme sıfır).
## Bırakma, sürenin son TIME_TOLERANCE payında olursa host'un kararı (tamam sayılabilir) beklenir; daha
## erken bırakmada `finished(false)` hemen yayılır. Her istek bir sıra numarası taşır: geç gelen eski karar
## yeni isteği bitirmez. Player sinyalleri (interaction_*; HUD sözleşmesi) bunlardan yayılır.
## US-010 (istem satırları): her Interactable bir girdi eylemine bağlıdır (`input_action`: `interact` E, `intimidate`
## Q). Hedef her eylem için ayrı seçilir (en yakın uygun); `target_changed` E satırını, `alt_target_changed` Q
## satırını bildirir (iki satır). Aynı anda tek etkileşim sürer; süren etkileşim kendi eyleminin tuşu
## bırakılınca biter.

signal target_changed(action_key: String)
## Q (`intimidate`) satırının hedefi değişti (boş = yok; US-010).
signal alt_target_changed(action_key: String)
signal started(action_key: String, duration: float)
signal finished(success: bool)

## Bırakıldıktan sonra host kararı bu kadar gecikirse (bağlantı sorunu) etkileşim başarısız sayılır.
const VERDICT_TIMEOUT_SEC := 2.0
## Bırakmada kararın bekleneceği pay, TIME_TOLERANCE'a ek (sn): host'un ilerlemesi yerel süreden ağ
## titremesi kadar ileride olabilir; sınırda yerel "yarıda kaldı" ile host'un "tamam"ı çelişmesin.
const RELEASE_MARGIN := 0.1
## Q satırının girdi eylemi (S5; Interactable.input_action); diğer her eylem E satırıdır.
const ALT_ACTION := &"intimidate"

var _target: Interactable = null
var _target_key: String = ""
var _alt_target: Interactable = null
var _alt_target_key: String = ""
## Süren etkileşim Q ile mi başladı (bırakma o tuşla denetlenir).
var _active_alt: bool = false
var _was_alt_held: bool = false
var _active: Interactable = null
var _seq: int = 0
var _elapsed: float = 0.0
var _hold_time: float = 0.0
var _released: bool = false
var _waited: float = 0.0
var _was_held: bool = false
var _started_at: float = 0.0
## Döküm (S6 "interaction"): yollanan istek, başarı, başarısızlık; son başarının sonuç gecikmesi
## (basıştan host kararına geçen süre − basılı tutma süresi ≈ RTT; ms).
var _requests: int = 0
var _successes: int = 0
var _failures: int = 0
var _result_delay_ms: float = -1.0


## Yerel oyuncunun bir fizik adımı: `held` = interact basılı mı, `actor_pos` = global konum; `alt_held` = intimidate
## (Q) basılı mı (US-010).
func tick(delta: float, held: bool, actor_pos: Vector2, peer_id: int, actor_tags: Dictionary = {},
		alt_held: bool = false) -> void:
	if _active != null and not is_instance_valid(_active):
		_active = null
		_finish(false)
	if _active != null:
		_elapsed += delta
		var still: bool = alt_held if _active_alt else held
		if _released:
			_waited += delta
			if _waited > VERDICT_TIMEOUT_SEC:
				_finish(false)
		elif not still or not _active.in_reach(actor_pos):
			_release()
	if _active == null:
		_select_target(actor_pos, peer_id, actor_tags)
		if held and not _was_held and _target != null:
			_start(_target, false)
		elif alt_held and not _was_alt_held and _alt_target != null:
			_start(_alt_target, true)
	_was_held = held
	_was_alt_held = alt_held


## Etkileşim sürüyor mu (istek yollandı, karar gelmedi).
func is_active() -> bool:
	return _active != null


## Şu anki hedefin eylem anahtarı (boş = hedef yok).
func target_key() -> String:
	return _target_key


## Q satırının hedefinin eylem anahtarı (boş = yok; US-010).
func alt_target_key() -> String:
	return _alt_target_key


func stats() -> Dictionary:
	return {
		"requests": _requests,
		"successes": _successes,
		"failures": _failures,
		"result_delay_ms": _result_delay_ms,
	}


func _select_target(actor_pos: Vector2, peer_id: int, actor_tags: Dictionary) -> void:
	var candidates: Array[Interactable] = []
	var positions := PackedVector2Array()
	var alt_candidates: Array[Interactable] = []
	var alt_positions := PackedVector2Array()
	var actor: Node = get_parent()
	if actor != null and not actor.is_in_group(Interactable.ACTOR_GROUP):
		actor = null
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var item: Interactable = node as Interactable
		if item == null or (actor != null and actor.is_ancestor_of(item)):
			continue  # oyuncunun kendi bileşeni (ÇEK, US-008) kendisine hedef olmaz
		if item.can_start(peer_id, actor_pos, actor_tags):
			if item.input_action == ALT_ACTION:
				alt_candidates.append(item)
				alt_positions.append(item.global_position)
			else:
				candidates.append(item)
				positions.append(item.global_position)
	var index: int = InteractionRules.nearest(actor_pos, positions)
	var target: Interactable = candidates[index] if index >= 0 else null
	var key: String = target.action_key if target != null else ""
	_target = target
	if key != _target_key:
		_target_key = key
		target_changed.emit(key)
	var alt_index: int = InteractionRules.nearest(actor_pos, alt_positions)
	var alt_target: Interactable = alt_candidates[alt_index] if alt_index >= 0 else null
	var alt_key: String = alt_target.action_key if alt_target != null else ""
	_alt_target = alt_target
	if alt_key != _alt_target_key:
		_alt_target_key = alt_key
		alt_target_changed.emit(alt_key)


func _start(target: Interactable, alt: bool) -> void:
	_seq += 1
	_active = target
	_active_alt = alt
	_elapsed = 0.0
	_hold_time = target.hold_time
	_released = false
	_waited = 0.0
	_started_at = Time.get_ticks_usec() / 1_000_000.0
	_requests += 1
	target.request_finished.connect(_on_verdict)
	started.emit(target.action_key, maxf(target.hold_time, 0.0))
	target.request_start(_seq)  # host'ta karar aynı çağrıda gelebilir (anlık eylem)


func _release() -> void:
	if _hold_time > 0.0:
		_active.request_cancel(_seq)
		if _active == null:
			return  # host'ta karar aynı çağrıda geldi
	if InteractionRules.release_completes(_elapsed + RELEASE_MARGIN, _hold_time):
		_released = true  # son pay: host tamam sayabilir, kararı bekle
		_waited = 0.0
	else:
		_finish(false)


func _on_verdict(seq: int, success: bool) -> void:
	if seq != _seq or _active == null:
		return
	if success:
		_result_delay_ms = (Time.get_ticks_usec() / 1_000_000.0 - _started_at - _hold_time) * 1000.0
	_finish(success)


func _finish(success: bool) -> void:
	if _active != null and is_instance_valid(_active) and _active.request_finished.is_connected(_on_verdict):
		_active.request_finished.disconnect(_on_verdict)
	_active = null
	if success:
		_successes += 1
	else:
		_failures += 1
	finished.emit(success)
