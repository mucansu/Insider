extends Node
## Gürültü (autoload `NoiseBus`, sözleşme S8 — docs/notes/mimari.md; US-009). Yarıçaplar ve türler
## `data/noise_profile.tres` (NoiseProfile), kurallar `core/noise_rules.gd` (NoiseRules, düğümsüz).
##
## Akış: `emit_noise` host'ta doğrudan yayılır; istemcide host'a güvenilir RPC ile iletilir (S2). Host istemci
## isteğini `host_request` ile doğrular: gönderen = `get_remote_sender_id()`, kaynak 0 ya da gönderenin kendisi
## (başka peer adına ses yok), tür yalnız hareket sesi (NoiseProfile.MOVEMENT_KINDS), yarıçap host'un tanımından
## (istemcinin yarıçapına güvenilmez), konum host'un bildiği aktör konumuna NoiseRules.POSITION_TOLERANCE içinde,
## aynı göndericinin son kabul edilen isteğinden en az `step_interval × CLIENT_RATE_FACTOR` sn sonra (yoksa `rate`).
## Yayılan ses: host `noise_listener` grubundaki düğümlerin `hear_noise(pos, radius, kind)` metodunu çağırır
## (duck typing; dinleyici kendi mesafe/duvar kuralını uygular) ve herkese görsel halka olayı yollar
## (`authority`, güvenilmez: yalnız görsel). Her peer halka olayında `noise_shown` yayar ve geçerli seviyenin
## altına halka görseli ekler (`RING_SCENE`, yol dizesinden `load()`: derleme bağımlılığı yok).
## Döküm (S6, yalnız `--dump`): "noise" anahtarı — `stats()`.

## Halka olayı (her peer'da; host'ta yerel yayılımla birlikte).
signal noise_shown(pos: Vector2, radius: float, kind: StringName)

const LISTENER_GROUP := PhysicsLayers.NOISE_LISTENER_GROUP
const LISTENER_METHOD := &"hear_noise"
## Etkileşim aktörleri grubu (S7 `Interactable.ACTOR_GROUP`): `interaction_position()` host'un bildiği en güncel
## konumu verir. Autoload entities/'i bilmez; ad core/'daki tek kaynaktan (PhysicsLayers, §6, duck typing).
const ACTOR_GROUP := PhysicsLayers.ACTORS_GROUP
const ACTOR_POSITION_METHOD := &"interaction_position"
const RING_SCENE := "res://entities/fx/noise_ring.tscn"
const DUMP_KEY := "noise"

var _profile: NoiseProfile = null
var _ring_scene: PackedScene = null
## Sayaçlar (döküm): bu süreçte yayılması istenen ses (yerel çağrı), host'ta kabul edilen istemci isteği ve
## nedene göre ret, host'ta dinleyicilere dağıtılan ses ve dinleyici çağrısı, bu peer'da görülen halka olayı.
var _emitted: int = 0
var _accepted: int = 0
var _rejected: Dictionary = {}
var _dispatched: int = 0
var _delivered: int = 0
var _rings: int = 0
var _ring_kinds: Dictionary = {}
## Host: gönderen peer -> son kabul edilen isteğin anı (sn; tempo sınırı).
var _last_accept: Dictionary = {}


func _ready() -> void:
	_profile = NoiseProfile.load_default()
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, stats)


## İstemciden çağrılırsa host'a iletilir; host `noise_listener` grubundaki düğümlerin
## `hear_noise(pos, radius, kind)` metodunu çağırır ve herkese görsel halka olayı yollar.
## Sıfır yarıçaplı ses yayılmaz. İstemcide `radius` yalnız yerel ön süzgeçtir: host türün tanımdaki yarıçapını
## kullanır. `source_peer` sesi çıkaranın peer kimliği (0 = dünya).
func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void:
	if radius <= 0.0 or not pos.is_finite():
		return
	if _is_host():
		_emitted += 1
		_dispatch(pos, radius, kind)
	elif _is_connected():
		_emitted += 1
		_rpc_request.rpc_id(1, pos, kind, source_peer)


## Yalnız host'ta: `sender`'ın gürültü isteğini doğrular ve kabul edilirse yayar (RPC gövdesi; testler de bu
## yolu kullanır). Host değilse etkisizdir ve NO_ACTOR döner. `now`: isteğin anı (sn; < 0 ise saat; testler verir).
func host_request(sender: int, pos: Vector2, kind: StringName, source_peer: int,
		now: float = -1.0) -> NoiseRules.Result:
	if not _is_host():
		return NoiseRules.Result.NO_ACTOR
	if now < 0.0:
		now = Time.get_ticks_usec() / 1_000_000.0
	var radius: float = _profile.radius_for(kind)
	var actor: Node = _actor(sender)
	var known: Vector2 = Vector2.INF
	if actor != null:
		var at: Variant = actor.call(ACTOR_POSITION_METHOD)
		if at is Vector2:
			known = at
	var result: NoiseRules.Result = NoiseRules.check_client(sender, source_peer,
		NoiseProfile.is_movement_kind(kind), radius, pos, known, actor != null)
	if result == NoiseRules.Result.OK and _last_accept.has(sender):
		if not NoiseRules.within_rate(now - float(_last_accept[sender]), _profile.step_interval):
			result = NoiseRules.Result.RATE
	if result != NoiseRules.Result.OK:
		var reason: String = NoiseRules.result_name(result)
		_rejected[reason] = int(_rejected.get(reason, 0)) + 1
		return result
	_last_accept[sender] = now
	_accepted += 1
	_dispatch(pos, radius, kind)
	return result


## Döküm/teşhis sayaçları (S6 "noise").
func stats() -> Dictionary:
	var rejected_total: int = 0
	for reason: String in _rejected:
		rejected_total += int(_rejected[reason])
	return {
		"emitted": _emitted,
		"accepted": _accepted,
		"rejected": _rejected.duplicate(),
		"rejected_total": rejected_total,
		"dispatched": _dispatched,
		"delivered": _delivered,
		"rings": _rings,
		"ring_kinds": _ring_kinds.duplicate(),
	}


# --- RPC (S2: istemci→host any_peer + gönderen doğrulaması; host→herkes authority, görsel: güvenilmez) ---

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(pos: Vector2, kind: StringName, source_peer: int) -> void:
	host_request(multiplayer.get_remote_sender_id(), pos, kind, source_peer)


@rpc("authority", "call_remote", "unreliable")
func _rpc_ring(pos: Vector2, radius: float, kind: StringName) -> void:
	_show_ring(pos, radius, kind)


# --- host ---

func _dispatch(pos: Vector2, radius: float, kind: StringName) -> void:
	_dispatched += 1
	for node: Node in get_tree().get_nodes_in_group(LISTENER_GROUP):
		if node.has_method(LISTENER_METHOD):
			_delivered += 1
			node.call(LISTENER_METHOD, pos, radius, kind)
	_show_ring(pos, radius, kind)
	if not multiplayer.get_peers().is_empty():
		_rpc_ring.rpc(pos, radius, kind)


func _actor(peer_id: int) -> Node:
	if peer_id <= 0:
		return null
	for node: Node in get_tree().get_nodes_in_group(ACTOR_GROUP):
		if node.get_multiplayer_authority() == peer_id and node.has_method(ACTOR_POSITION_METHOD):
			return node
	return null


# --- her peer ---

func _show_ring(pos: Vector2, radius: float, kind: StringName) -> void:
	_rings += 1
	var key: String = str(kind)
	_ring_kinds[key] = int(_ring_kinds.get(key, 0)) + 1
	noise_shown.emit(pos, radius, kind)
	var level: Node = Game.current_level()
	if level == null or not level.is_inside_tree():
		return
	if _ring_scene == null:
		_ring_scene = load(RING_SCENE) as PackedScene
		if _ring_scene == null:
			push_error("NoiseBus: halka sahnesi yüklenemedi: " + RING_SCENE)
			return
	var ring: Node2D = _ring_scene.instantiate() as Node2D
	if ring == null:
		return
	level.add_child(ring)
	ring.global_position = pos
	if ring.has_method(&"setup"):
		ring.call(&"setup", radius)


func _is_host() -> bool:
	return multiplayer.is_server()


func _is_connected() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
