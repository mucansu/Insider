extends Node
## Ağ katmanı (autoload `Net`, sözleşme S1 — docs/notes/mimari.md).
## Godot yüksek seviye multiplayer (SceneMultiplayer) üstünde host/katıl/ayrıl. Taşıma (bugün ENet, Faz 5'te
## Steam) yalnız bu dosyadaki `_create_peer()` ve `_transport_*` yardımcılarında görünür; başka hiçbir dosya
## taşıma sınıflarına dokunmaz.
##
## Sinyal anlamları:
## - `peer_connected` / `peer_disconnected`: oturuma kabul edilmiş (el sıkışması bitmiş) uzak peer geldi/gitti.
##   İstemcide host (1) ve diğer istemciler için de yayılır.
## - `connected_to_host`: istemci kabul edildi (Game el sıkışması dahil); `is_online()` artık true.
## - `connection_failed`: katılma denemesi kabul edilmeden bitti (geçersiz adres, zaman aşımı, ret).
## - `host_disconnected`: kabul edilmiş istemcinin host bağlantısı koptu. Sinyal yayılırken `local_peer_id()`
##   hâlâ eski kimliği döner (döküm için); sinyalden hemen sonra oturum çevrimdışına döner.
## `leave()` sinyal yaymaz; oturum sonunu Game `is_online()` geçişinden anlar.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_host()
signal connection_failed()
signal host_disconnected()

## Katılma denemesinin üst süresi (ms). ENet bunu yeniden deneme adımına yuvarlar (0,5/1,5/3,5/7,5 sn...):
## 5000 -> yanıt vermeyen adreste ~7,5 sn sonra connection_failed. Bağlantı kurulunca (kabul) taşımanın
## varsayılan zaman aşımları geri gelir.
var connect_timeout_ms: int = 5000

## ENet paket kısma (throttle) ayarı: (aralık ms, hızlanma, yavaşlama). ENet RTT dalgalanmasını tıkanıklık
## sayıp güvenilmez paketleri (konum eşitlemesi) düşürebiliyor; düşük gecikmede kısma 32'den 0'a inip
## eşitlemeyi saniyelerce kesiyordu (US-001 t2). Yavaşlama 0 = kısma hiç artmaz; tıkanıklığı ENet'in
## güvenilir kanal denetimi ve oyunun düşük bant genişliği (20 Hz konum) karşılar.
const THROTTLE_INTERVAL_MS := 5000
const THROTTLE_ACCELERATION := 32
const THROTTLE_DECELERATION := 0

var _peer: MultiplayerPeer = null
var _local_id: int = 0
var _hosting: bool = false
## İstemci oturuma kabul edildi mi (connected_to_server geldi mi).
var _connected: bool = false
var _hostname_re: RegEx = RegEx.create_from_string(
		"^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$")


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Oturum açar; `max_peers` host dahil toplam oyuncu sayısıdır (en az 1).
func host(port: int = 7777, max_peers: int = 4) -> Error:
	if _peer != null:
		push_warning("Net.host: zaten bir oturum var; önce leave()")
		return ERR_ALREADY_IN_USE
	if port < 1 or port > 65535 or max_peers < 1:
		push_warning("Net.host: geçersiz port/max_peers (%d, %d)" % [port, max_peers])
		return ERR_INVALID_PARAMETER
	var peer: MultiplayerPeer = _create_peer()
	var err: Error = _transport_listen(peer, port, max_peers)
	if err != OK:
		push_warning("Net.host: %d portu açılamadı (%s)" % [port, error_string(err)])
		return err
	_peer = peer
	_hosting = true
	_connected = false
	_local_id = 1
	multiplayer.multiplayer_peer = peer
	return OK


## Host'a bağlanmayı başlatır. Sonuç `connected_to_host` ya da `connection_failed` ile gelir; adres
## geçersizse ya da taşıma başlatılamazsa hata döner ve `connection_failed` bir kare sonra yine yayılır.
func join(address: String, port: int = 7777) -> Error:
	if _peer != null:
		push_warning("Net.join: zaten bir oturum var; önce leave()")
		return ERR_ALREADY_IN_USE
	var ip: String = _resolve(address)
	if ip.is_empty() or port < 1 or port > 65535:
		push_warning("Net.join: geçersiz adres '%s:%d'" % [address, port])
		connection_failed.emit.call_deferred()
		return ERR_CANT_RESOLVE if port >= 1 and port <= 65535 else ERR_INVALID_PARAMETER
	var peer: MultiplayerPeer = _create_peer()
	var err: Error = _transport_connect(peer, ip, port)
	if err != OK:
		push_warning("Net.join: bağlantı başlatılamadı (%s)" % error_string(err))
		connection_failed.emit.call_deferred()
		return err
	_peer = peer
	_hosting = false
	_connected = false
	_local_id = peer.get_unique_id()
	multiplayer.multiplayer_peer = peer
	return OK


## Oturumdan çıkar (host ise oturumu kapatır; istemcilere host_disconnected gider). Sinyal yaymaz.
func leave() -> void:
	if _peer == null:
		return
	var peer: MultiplayerPeer = _peer
	_reset()
	peer.close()
	# Kapatıp aynı çağrıda değiştirmek SceneMultiplayer'ın yerelde server_disconnected yaymasını önler.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_host() -> bool:
	return _peer != null and _hosting


## Host oturumu açık ya da istemci kabul edilmiş.
func is_online() -> bool:
	return _peer != null and (_hosting or _connected)


## Oturumdaki kimlik (host 1); oturum yokken 0.
func local_peer_id() -> int:
	return _local_id if _peer != null else 0


## Host için 0; bilinmiyorsa -1. İstemci yalnız host'a olan gecikmeyi bilir (diğer istemciler -1).
## Değer taşımanın düzgünleştirilmiş gidiş-dönüş süresidir (ms); ilk saniyelerde yakınsar.
func get_ping_ms(peer_id: int = 1) -> int:
	if not is_online():
		return -1
	if peer_id == _local_id:
		return 0
	if _hosting and not multiplayer.get_peers().has(peer_id):
		return -1
	if not _hosting and peer_id != 1:
		return -1
	return _transport_rtt_ms(peer_id)


# --- sinyal köprüleri ---

func _on_peer_connected(peer_id: int) -> void:
	if _peer == null:
		return
	if _hosting:
		_transport_tune_peer(peer_id)
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if _peer != null:
		peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	if _peer == null or _hosting:
		return
	_connected = true
	_transport_restore_timeouts(_peer)
	_transport_tune_peer(1)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	if _peer == null:
		return
	_drop_peer()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	if _peer == null:
		return
	if _hosting:
		push_warning("Net: host taşıması beklenmedik biçimde kapandı")
		_drop_peer()
		return
	var was_connected: bool = _connected
	_connected = false
	# Kimlik, sinyal dinleyicileri (döküm) için sinyalden sonra bırakılır.
	if was_connected:
		host_disconnected.emit()
	else:
		connection_failed.emit()
	_drop_peer()


func _drop_peer() -> void:
	_reset()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _reset() -> void:
	_peer = null
	_hosting = false
	_connected = false
	_local_id = 0


## IP ise olduğu gibi, geçerli bir alan adıysa çözümlenmiş IP; aksi hâlde "".
func _resolve(address: String) -> String:
	var addr: String = address.strip_edges()
	if addr.is_valid_ip_address():
		return addr
	if addr.is_empty() or _hostname_re.search(addr) == null:
		return ""
	return IP.resolve_hostname(addr, IP.TYPE_ANY)


# --- taşıma (yalnız burada; Faz 5'te Steam bu yardımcıların arkasına eklenir) ---

func _create_peer() -> MultiplayerPeer:
	return ENetMultiplayerPeer.new()


func _transport_listen(peer: MultiplayerPeer, port: int, max_peers: int) -> Error:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	var err: Error = enet.create_server(port, maxi(1, max_peers - 1))
	if err == OK and max_peers == 1:
		enet.refuse_new_connections = true
	return err


func _transport_connect(peer: MultiplayerPeer, ip: String, port: int) -> Error:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	var err: Error = enet.create_client(ip, port)
	if err != OK:
		return err
	var server: ENetPacketPeer = enet.get_peer(1)
	if server != null and connect_timeout_ms > 0:
		# (limit, en az, en çok) ms: yanıt vermeyen host için bekleme connect_timeout_ms ile sınırlı.
		server.set_timeout(0, connect_timeout_ms, connect_timeout_ms)
	return OK


func _transport_restore_timeouts(peer: MultiplayerPeer) -> void:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	if enet == null:
		return
	var server: ENetPacketPeer = enet.get_peer(1)
	if server != null:
		server.set_timeout(0, 0, 0)  # 0 = ENet varsayılanları


## Bağlı peer'ın paket kısmasını kapatır (bkz. THROTTLE_*); ayar ENet komutuyla karşı uca da gider.
func _transport_tune_peer(peer_id: int) -> void:
	var enet: ENetMultiplayerPeer = _peer as ENetMultiplayerPeer
	if enet == null:
		return
	var remote: ENetPacketPeer = enet.get_peer(peer_id)
	if remote != null:
		remote.throttle_configure(THROTTLE_INTERVAL_MS, THROTTLE_ACCELERATION, THROTTLE_DECELERATION)


func _transport_rtt_ms(peer_id: int) -> int:
	var enet: ENetMultiplayerPeer = _peer as ENetMultiplayerPeer
	if enet == null:
		return -1
	var remote: ENetPacketPeer = enet.get_peer(peer_id)
	if remote == null:
		return -1
	return roundi(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
