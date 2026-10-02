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

## Ping ölçümü (IS-026): host her peer'a, istemci host'a PING_INTERVAL_USEC'te bir zaman damgalı yankı RPC'si
## yollar. Uygulama ağı kare başına bir kez yokladığından her örneğe kare beklemesi biner; taşımanın
## düzgünleştirilmiş RTT'si bunun ortalamasını taşır (pencereli 30 fps'te +30-60 ms, takılmada +100 ms üstü). Gösterilen değer (_ping_estimate_ms):
##   max(son PING_WINDOW örneğin medyanı, yanıtsız kalan ikinci en eski isteğin yaşı)
## - Medyan: jitter altında gerçek RTT'nin ortasını verir (en küçük, sert ağda RTT'nin altını gösterip HUD
##   uyarısını bastırıyordu); pencerenin yarısından azını tutan aykırı (takılma) örnekleri onu şişirmez.
## Zaman damgası: istek rpc_id anında damgalanır; istek ve yanıt kuyrukta birer sonraki yoklamayı bekler, yani
## değere iki ucun kare beklemesi biner (60 fps'te ~+17-33 ms) ama ağ RTT'sinin altına inmez. Kuyruk elle
## boşaltılmaz: kare ortasında boşaltma o karenin paketlerini ayrı datagramlara bölüp sert ağda yeni katılan
## istemcide auth ERROR'unu sıklaştırıyordu (IS-026 t3 ölçümü).
## - Yanıtsız yaş, karşı uç (ya da yol) durduğunda değeri yükseltir: örnek gelmese de HUD donmaz.
## - İkinci en eski istek: ping/pong güvenilmezdir; tek kayıp istek en eski olarak kalır ama ondan sonraki
##   zamanında yanıtlanır, yani değer sıçramaz. Sağlıklı bağlantıda ikinci en eski isteğin yaşı RTT'yi
##   geçemez (RTT > aralık olsa bile); yalnız art arda iki istek RTT'den uzun yanıtsız kalınca devreye girer.
##   Bir yanıt, ondan eski bekleyen istekleri kayıp sayıp siler.
## Başlatma: güvenilmez ping, karşı uç SceneMultiplayer el sıkışmasını (auth) bitirmeden varırsa motor ERROR basar
## (kayıpta yeniden gönderilen auth paketini sırasız ping geçebiliyor). Bu yüzden host peer_connected'da
## güvenilir (auth ile aynı sıralı kanal) bir "hazır" RPC'si yollar; istemci onu alınca (kendi el sıkışması
## bitmiştir) host'a ping atmaya başlar; host da bir peer'a ancak ondan ilk geçerli ping isteği gelince atar.
## Kanal: ölçüm mesajı oyun RPC'lerinden ayrı, sırasız güvenilmez kanalda gider (güvenilir sıralı kanalda bir
## ping kaybı arkasındaki oyun olaylarını bekletirdi; Steam unreliable_ordered'ı güvenilire çevirir).
const PING_INTERVAL_USEC := 250_000
const PING_WINDOW := 16
## Yanıt bekleyen istek üst sınırı (peer başına). Aşılınca en eski ikisi korunur (yaş ölçüsü), üçüncüsü düşer.
const PING_PENDING_MAX := 8
## Host, bir peer'ın bu aralıktan sık gelen ping isteklerini yanıtlamaz (sel koruması).
const PING_MIN_REQUEST_GAP_USEC := 100_000
## Ping/pong taşıma kanalı (oyun RPC'leri 0). Steam şeritleri: yalnız 0-2 kullanılabilir (docs/arastirma/
## steam-ag.md; steam/multiplayer_peer/max_channels >= kanal + 2).
const PING_CHANNEL := 2

var _peer: MultiplayerPeer = null
var _local_id: int = 0
var _hosting: bool = false
## İstemci oturuma kabul edildi mi (connected_to_server geldi mi).
var _connected: bool = false
var _hostname_re: RegEx = RegEx.create_from_string(
		"^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$")
var _ping_next_usec: int = 0
var _ping_seq: int = 0
## peer -> {seq: gönderim usec}
var _ping_pending: Dictionary[int, Dictionary] = {}
## peer -> son PING_WINDOW gidiş-dönüş (usec)
var _ping_samples: Dictionary[int, Array] = {}
## Host: peer -> son yanıtlanan istek anı (usec)
var _ping_last_request: Dictionary[int, int] = {}
## Ping atılabilecek peer'lar (bkz. "Başlatma").
var _ping_ready: Dictionary[int, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
## Değer ağ gidiş-dönüş süresidir (ms, en az 1; bkz. PING_* ve _ping_estimate_ms); ilk yanıt gelene dek
## (~çeyrek saniye) taşımanın düzgünleştirilmiş RTT'si.
func get_ping_ms(peer_id: int = 1) -> int:
	if not is_online():
		return -1
	if peer_id == _local_id:
		return 0
	if _hosting and not multiplayer.get_peers().has(peer_id):
		return -1
	if not _hosting and peer_id != 1:
		return -1
	var estimate: int = _ping_estimate_ms(
			_ping_samples.get(peer_id, []), _ping_pending.get(peer_id, {}), Time.get_ticks_usec())
	if (_ping_samples.get(peer_id, []) as Array).is_empty():
		return maxi(estimate, _transport_rtt_ms(peer_id))
	return estimate


## Gösterilecek ping (ms, en az 1): max(örnek penceresinin medyanı, yanıtsız ikinci en eski isteğin yaşı);
## ikisi de yoksa -1. `samples` usec; `pending` {seq: gönderim usec}, sıra numarasına göre artan.
static func _ping_estimate_ms(samples: Array, pending: Dictionary, now_usec: int) -> int:
	var value: int = -1
	if not samples.is_empty():
		value = _median_usec(samples)
	if pending.size() >= 2:
		var second_oldest: int = int(pending[pending.keys()[1]])
		value = maxi(value, now_usec - second_oldest)
	if value < 0:
		return -1
	return maxi(1, roundi(float(value) / 1000.0))


## Medyan; çift sayıda örnekte iki ortanın ortalaması (simetrik jitter'de yansız, alt orta aşağı çekerdi).
@warning_ignore("integer_division")
static func _median_usec(samples: Array) -> int:
	var sorted: Array = samples.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	if sorted.size() % 2 == 1:
		return int(sorted[mid])
	return (int(sorted[mid - 1]) + int(sorted[mid])) / 2


## Ölçümün kaynağı (döküm ve testler için): {"source": "ping" (yankı örnekleri) | "transport" (ilk yanıta
## dek taşıma RTT'si) | "self" | "none", "samples": penceredeki yankı örneği sayısı}.
func get_ping_info(peer_id: int = 1) -> Dictionary:
	if get_ping_ms(peer_id) < 0:
		return {"source": "none", "samples": 0}
	if peer_id == _local_id:
		return {"source": "self", "samples": 0}
	var count: int = (_ping_samples.get(peer_id, []) as Array).size()
	return {"source": "ping" if count > 0 else "transport", "samples": count}


# --- ping ölçümü ---

func _process(_delta: float) -> void:
	if not is_online():
		return
	var now: int = Time.get_ticks_usec()
	if now < _ping_next_usec:
		return
	_ping_next_usec = now + PING_INTERVAL_USEC
	for peer_id: int in multiplayer.get_peers():
		if _ping_ready.has(peer_id) and (_hosting or peer_id == 1):
			_ping_seq += 1
			_note_ping_request(peer_id, _ping_seq, Time.get_ticks_usec())
			_rpc_ping.rpc_id(peer_id, _ping_seq)


## Gönderilen isteği bekleyenlere ekler; tablo dolarsa en eski ikisi (yaş ölçüsü) korunur, üçüncüsü düşer.
func _note_ping_request(peer_id: int, seq: int, now_usec: int) -> void:
	var pending: Dictionary = _ping_pending.get_or_add(peer_id, {})
	pending[seq] = now_usec
	while pending.size() > PING_PENDING_MAX:
		pending.erase(pending.keys()[2])


## Yanıt beklenen bir isteğe aitse örnek ekler (true); ondan eski bekleyen istekler kayıp sayılıp silinir.
func _note_ping_reply(peer_id: int, seq: int, now_usec: int) -> bool:
	if not _ping_pending.has(peer_id):
		return false
	var pending: Dictionary = _ping_pending[peer_id]
	if not pending.has(seq):
		return false
	var sent_usec: int = int(pending[seq])
	for key: Variant in pending.keys():
		if int(key) <= seq:
			pending.erase(key)
	var samples: Array = _ping_samples.get_or_add(peer_id, [])
	samples.push_back(maxi(0, now_usec - sent_usec))
	while samples.size() > PING_WINDOW:
		samples.pop_front()
	return true


## Yankı isteği yanıtlanır mı: host oturumdaki her peer'dan (PING_MIN_REQUEST_GAP_USEC sıklık sınırıyla),
## istemci yalnız host'tan (1) kabul eder.
func _accept_ping_request(sender: int, peers: PackedInt32Array, hosting: bool, now_usec: int) -> bool:
	if not peers.has(sender):
		return false
	if not hosting:
		return sender == 1
	if _ping_last_request.has(sender) and now_usec - _ping_last_request[sender] < PING_MIN_REQUEST_GAP_USEC:
		return false
	_ping_last_request[sender] = now_usec
	return true


@rpc("any_peer", "call_remote", "unreliable", PING_CHANNEL)
func _rpc_ping(seq: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _peer == null:
		return
	if not _accept_ping_request(sender, multiplayer.get_peers(), _hosting, Time.get_ticks_usec()):
		return
	if _hosting:
		_ping_ready[sender] = true
	_rpc_pong.rpc_id(sender, seq)


## Yankı yanıtı: yalnız o peer'a gönderilmiş, yanıtı beklenen istek sayılır.
@rpc("any_peer", "call_remote", "unreliable", PING_CHANNEL)
func _rpc_pong(seq: int) -> void:
	_note_ping_reply(multiplayer.get_remote_sender_id(), seq, Time.get_ticks_usec())


## Host'tan istemciye: el sıkışması iki uçta da bitti, ping başlayabilir (güvenilir: auth'tan sonra varır).
@rpc("authority", "call_remote", "reliable")
func _rpc_ping_hello() -> void:
	if _peer != null and not _hosting and multiplayer.get_remote_sender_id() == 1:
		_ping_ready[1] = true


func _forget_ping(peer_id: int) -> void:
	_ping_ready.erase(peer_id)
	_ping_pending.erase(peer_id)
	_ping_samples.erase(peer_id)
	_ping_last_request.erase(peer_id)


# --- sinyal köprüleri ---

func _on_peer_connected(peer_id: int) -> void:
	if _peer == null:
		return
	if _hosting:
		_transport_tune_peer(peer_id)
		_rpc_ping_hello.rpc_id(peer_id)
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_forget_ping(peer_id)
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
	_ping_pending.clear()
	_ping_samples.clear()
	_ping_last_request.clear()
	_ping_ready.clear()
	_ping_next_usec = 0


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

