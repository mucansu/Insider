class_name Interactable
extends Area2D
## Etkileşim bileşeni (US-005; mimari.md S2, S7, KR-018): prop'un alt düğümü (Area2D, katman interactables).
## Prop yalnız kendi durumunu tutar ve `completed`'e bağlanıp sonucu uygular; bu bileşen istek RPC'lerini,
## host doğrulamasını, meşguliyeti ve süre sayımını taşır. Kurallar `InteractionRules`'ta (core/, düğümsüz).
##
## Akış (S7): yerel oyuncu yakındaki en yakın uygun bileşeni `can_start` ile bulur → `request_start(seq)` →
## host doğrular (S2 menzil toleransı + requirement + meşguliyet + tekrar beklemesi), `busy_by` atar ve süreyi
## sayar → oyuncu bırakırsa `request_cancel(seq)` (son TIME_TOLERANCE payındaysa tamamlanır), menzilden
## (+ tolerans) çıkarsa ya da ayrılırsa host iptal eder → süre dolunca host `completed` yayar. İsteyen peer'a
## sonuç `request_finished(seq, success)` ile döner (yalnız o peer'da yayılır). İstemci kendi başına sonuç
## üretemez: `completed`/`cancelled` yalnız host'ta yayılır.
## Aktör: `ACTOR_GROUP` grubundaki, yetkisi isteyen peer'da olan ve `interaction_position() -> Vector2`
## (host'un bildiği en güncel konum) sunan düğüm; isteğe bağlı `interaction_tags() -> Dictionary`.
## Çoğaltılan durum: `busy_by` (0 = boş) ve `progress` (sn), host yetkili MultiplayerSynchronizer
## (değişince, güvenilir; `SYNC_INTERVAL`). `enabled` ve `action_key`'i prop kendi çoğaltılan durumundan
## her peer'da türetir. `busy_by` her peer'da "kim etkileşimde" bilgisidir (`held_by`; uzak oyuncu göstergesi).
## Host engeli (IS-014): prop `start_blocker`'a `func() -> bool` verebilir; host doğrulamasında true dönerse
## istek `blocked` nedeniyle reddedilir (istemci istem süzgeci bakmaz: istem görünür kalır).
## Genel host API'si (`host_start`, `host_cancel`, `step`) RPC gövdesi, yerel istek ve fizik adımı tarafından
## çağrılır; testler de aynı yolu kullanır (§6: `_` üyelere dışarıdan erişim yok).

## Yalnız host'ta.
signal completed(peer_id: int)
## Yalnız host'ta (bırakma, menzil dışı, aktör yok).
signal cancelled(peer_id: int)
## Yalnız isteyen peer'da: host'un kararı (seq isteğin sıra numarası).
signal request_finished(seq: int, success: bool)

const GROUP := &"interactables"
## Etkileşebilen aktörlerin grubu (oyuncu kendini ekler).
const ACTOR_GROUP := &"interaction_actors"
## Fizik katmanı interactables (mimari.md §4: 4. katman).
const LAYER_BIT := 1 << 3
const SYNC_NAME := "InteractableSync"
const SYNC_INTERVAL := 0.1

@export var action_key: String = ""
@export var hold_time: float = 0.0
@export var interact_range: float = 40.0:
	set = _set_interact_range
@export var enabled: bool = true
@export var requirement: InteractionRequirement

## Çoğaltılan durum (host yazar).
var busy_by: int = 0
var progress: float = 0.0
## İsteğe bağlı host engeli: `func() -> bool` (true = şu an uygulanamaz; ret nedeni "blocked"). Yalnız host'ta
## ve yalnız yeni istek doğrulanırken çağrılır.
var start_blocker: Callable = Callable()

var _seq: int = 0
var _cooldown_left: float = 0.0
var _target := InteractionRules.Target.new()
## Bileşenin kendi kurduğu menzil dairesi (sahne kendi şeklini verdiyse null); menzil değişince güncellenir.
var _range_shape: CircleShape2D = null
## Host istatistikleri (döküm): istek, kabul (busy_by atanan), tamamlanan, iptal ve nedene göre ret sayıları.
var _requests: int = 0
var _accepted: int = 0
var _completed: int = 0
var _cancelled: int = 0
var _rejected: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER_BIT
	collision_mask = 0
	monitoring = false
	if find_children("*", "CollisionShape2D", false, false).is_empty():
		_range_shape = CircleShape2D.new()
		_range_shape.radius = interact_range
		var holder := CollisionShape2D.new()
		holder.shape = _range_shape
		add_child(holder)
	add_child(_make_sync())


func _physics_process(delta: float) -> void:
	step(delta)


## `peer_id`'nin tuttuğu (host'un çoğalttığı `busy_by`) bileşen; yoksa null. Her peer'da çalışır.
static func held_by(tree: SceneTree, peer_id: int) -> Interactable:
	if tree == null or peer_id <= 0:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var item: Interactable = node as Interactable
		if item != null and item.busy_by == peer_id:
			return item
	return null


## Bir zaman adımı: tekrar beklemesi azalır; host'ta süren etkileşimin süresi sayılır, aktör menzilden
## (+ S2 toleransı) çıktıysa ya da ayrıldıysa iptal edilir. Fizik adımı çağırır.
func step(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if busy_by == 0 or not _is_host():
		return
	var actor: Node = _actor(busy_by)
	if actor == null or not InteractionRules.keeps_going(_spec(), _actor_position(actor)):
		_finish(false)
		return
	progress = InteractionRules.advance(progress, delta)
	if InteractionRules.is_complete(progress, hold_time):
		_finish(true)


## İstemci tarafı uygunluk (toleranssız; istem ve hedef seçimi için). Host ayrıca doğrular.
func can_start(peer_id: int, actor_pos: Vector2, actor_tags: Dictionary = {}) -> bool:
	return InteractionRules.check(_spec(), peer_id, actor_pos, actor_tags) == InteractionRules.Result.OK


## Süren etkileşim için aktör hâlâ erişimde mi (S2 toleransıyla).
func in_reach(actor_pos: Vector2) -> bool:
	return InteractionRules.keeps_going(_spec(), actor_pos)


## 0..1 ilerleme (çoğaltılan durumdan; görseller okur).
func progress_ratio() -> float:
	return InteractionRules.ratio(progress, hold_time) if busy_by != 0 else 0.0


## Yerel oyuncu: etkileşim isteği (host'ta doğrudan, istemcide RPC).
func request_start(seq: int) -> void:
	if _is_host():
		host_start(multiplayer.get_unique_id(), seq)
	else:
		_rpc_start.rpc_id(1, seq)


## Yerel oyuncu: bıraktı ya da uzaklaştı.
func request_cancel(seq: int) -> void:
	if _is_host():
		host_cancel(multiplayer.get_unique_id(), seq)
	else:
		_rpc_cancel.rpc_id(1, seq)


## Host istatistikleri (S6 dökümü; istemcide sıfır). Değişmezler: requests = accepted + rejected_total;
## accepted = completed + cancelled + (süren etkileşim varsa 1).
func stats() -> Dictionary:
	var rejected_total: int = 0
	for reason: String in _rejected:
		rejected_total += int(_rejected[reason])
	return {
		"busy_by": busy_by,
		"requests": _requests,
		"accepted": _accepted,
		"completed": _completed,
		"cancelled": _cancelled,
		"rejected": _rejected.duplicate(),
		"rejected_total": rejected_total,
	}


# --- RPC (S2: istemci→host any_peer + gönderen doğrulaması; host→isteyen authority) ---

@rpc("any_peer", "call_remote", "reliable")
func _rpc_start(seq: int) -> void:
	host_start(multiplayer.get_remote_sender_id(), seq)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel(seq: int) -> void:
	host_cancel(multiplayer.get_remote_sender_id(), seq)


@rpc("authority", "call_remote", "reliable")
func _rpc_result(seq: int, success: bool) -> void:
	request_finished.emit(seq, success)


# --- host ---

## Yalnız host'ta (değilse yok sayılır): `peer_id`'nin `seq` numaralı başlatma isteğini doğrular ve kabul ya da
## reddeder (RPC gövdesi; host'un kendi isteği de buradan geçer).
func host_start(peer_id: int, seq: int) -> void:
	if peer_id <= 0 or not _is_host():
		return
	if busy_by == peer_id:
		_seq = seq  # aynı peer'ın yinelenen isteği: süren etkileşim sürer, karar yeni sıra numarasıyla gider
		return
	_requests += 1
	var actor: Node = _actor(peer_id)
	var result: InteractionRules.Result = InteractionRules.Result.NO_ACTOR
	if actor != null:
		var spec: InteractionRules.Target = _spec()
		spec.blocked = start_blocker.is_valid() and bool(start_blocker.call())
		result = InteractionRules.host_check(spec, peer_id, _actor_position(actor), _actor_tags(actor),
			_cooldown_left)
	if result != InteractionRules.Result.OK:
		var reason: String = InteractionRules.result_name(result)
		_rejected[reason] = int(_rejected.get(reason, 0)) + 1
		_send_result(peer_id, seq, false)
		return
	busy_by = peer_id
	progress = 0.0
	_seq = seq
	_accepted += 1
	if InteractionRules.is_complete(progress, hold_time):
		_finish(true)


## Yalnız host'ta: `peer_id` bıraktı. Süren etkileşim o peer'ın ve aynı sıra numarasıyla değilse etkisiz; son
## TIME_TOLERANCE payındaysa tamamlanır, değilse iptal.
func host_cancel(peer_id: int, seq: int) -> void:
	if not _is_host() or busy_by != peer_id or seq != _seq:
		return  # bitmiş ya da başkasının etkileşimi
	_finish(InteractionRules.release_completes(progress, hold_time))


## Etkileşimi bitirir: ilerleme sıfırlanır (yarıda bırakılan dahil), sinyal yayılır, isteyene sonuç gider.
func _finish(success: bool) -> void:
	var peer_id: int = busy_by
	var seq: int = _seq
	busy_by = 0
	progress = 0.0
	if success:
		_completed += 1
		_cooldown_left = InteractionRules.REPEAT_COOLDOWN
		completed.emit(peer_id)
	else:
		_cancelled += 1
		cancelled.emit(peer_id)
	_send_result(peer_id, seq, success)


func _send_result(peer_id: int, seq: int, success: bool) -> void:
	if peer_id == multiplayer.get_unique_id():
		request_finished.emit(seq, success)
	elif multiplayer.get_peers().has(peer_id):
		_rpc_result.rpc_id(peer_id, seq, success)


func _set_interact_range(value: float) -> void:
	interact_range = value
	if _range_shape != null:
		_range_shape.radius = value


func _is_host() -> bool:
	return multiplayer.is_server()


func _actor(peer_id: int) -> Node:
	for node: Node in get_tree().get_nodes_in_group(ACTOR_GROUP):
		if node.get_multiplayer_authority() == peer_id and node.has_method(&"interaction_position"):
			return node
	return null


static func _actor_position(actor: Node) -> Vector2:
	var pos: Variant = actor.call(&"interaction_position")
	return pos if pos is Vector2 else Vector2.INF


static func _actor_tags(actor: Node) -> Dictionary:
	if not actor.has_method(&"interaction_tags"):
		return {}
	var tags: Variant = actor.call(&"interaction_tags")
	return tags if tags is Dictionary else {}


## Kuralların gördüğü hedef durumu (taraf kısıtı prop'la birlikte döner).
func _spec() -> InteractionRules.Target:
	_target.position = global_position
	_target.interact_range = interact_range
	_target.enabled = enabled
	_target.busy_by = busy_by
	_target.blocked = false
	if requirement != null:
		_target.side = requirement.side.rotated(global_rotation)
		_target.side_min = requirement.side_min
		_target.tag = requirement.required_tag
		_target.tier = requirement.min_tier
	else:
		_target.side = Vector2.ZERO
		_target.side_min = 0.0
		_target.tag = &""
		_target.tier = 0
	return _target


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:busy_by", ".:progress"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.delta_interval = SYNC_INTERVAL
	sync.replication_config = config
	return sync
