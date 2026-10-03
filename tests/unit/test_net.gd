extends TestCase
## Net (autoload/net.gd, S1) single-process unit tests (US-001 AC7). Multi-process behaviour: tests/net/*.json.

var _failed: int = 0
var _connected: int = 0
var _host_lost: int = 0
var _peer_events: int = 0


func _watch() -> void:
	Net.connection_failed.connect(_on_failed)
	Net.connected_to_host.connect(_on_connected)
	Net.host_disconnected.connect(_on_host_lost)
	Net.peer_connected.connect(_on_peer)
	Net.peer_disconnected.connect(_on_peer)


func _unwatch() -> void:
	Net.connection_failed.disconnect(_on_failed)
	Net.connected_to_host.disconnect(_on_connected)
	Net.host_disconnected.disconnect(_on_host_lost)
	Net.peer_connected.disconnect(_on_peer)
	Net.peer_disconnected.disconnect(_on_peer)


func _on_failed() -> void:
	_failed += 1


func _on_connected() -> void:
	_connected += 1


func _on_host_lost() -> void:
	_host_lost += 1


func _on_peer(_id: int) -> void:
	_peer_events += 1


static func free_udp_port() -> int:
	var udp := PacketPeerUDP.new()
	udp.bind(0, "127.0.0.1")
	var port: int = udp.get_local_port()
	udp.close()
	return port


## Waits frames until the `connection_failed` counter rises or time runs out.
func _wait_failed(timeout_sec: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while _failed == 0 and Time.get_ticks_msec() < deadline:
		await tree().process_frame
	return _failed > 0


func test_offline_defaults() -> void:
	is_false(Net.is_online())
	is_false(Net.is_host())
	eq(Net.local_peer_id(), 0)
	eq(Net.get_ping_ms(), -1)
	eq(Net.get_ping_ms(1), -1)
	Net.leave()  # no effect while offline


func test_host_and_leave() -> void:
	_watch()
	var port: int = free_udp_port()
	eq(Net.host(port, 4), OK)
	is_true(Net.is_host())
	is_true(Net.is_online())
	eq(Net.local_peer_id(), 1)
	eq(Net.get_ping_ms(1), 0, "host için 0")
	eq(Net.get_ping_ms(), 0)
	eq(Net.get_ping_ms(123456), -1, "bilinmeyen peer -1")
	eq(Net.host(port), ERR_ALREADY_IN_USE)
	eq(Net.join("127.0.0.1", port), ERR_ALREADY_IN_USE)
	await tree().process_frame
	Net.leave()
	is_false(Net.is_online())
	is_false(Net.is_host())
	eq(Net.local_peer_id(), 0)
	await tree().process_frame
	await tree().process_frame
	eq([_failed, _connected, _host_lost, _peer_events], [0, 0, 0, 0], "leave() sinyal yaymaz")
	# Port released: the same port can be hosted again.
	eq(Net.host(port), OK)
	Net.leave()
	_unwatch()


func test_ping_estimate_is_window_median() -> void:
	# IS-026: the displayed ping is the median of the echo window (ms, rounded, at least 1); with an even number of samples the
	# mean of the two middle ones. A minority of stall samples does not inflate the value.
	eq(Net._ping_estimate_ms([], {}, 0), -1, "örnek yok")
	eq(Net._ping_estimate_ms([31_000, 62_400, 187_000, 30_600], {}, 0), 47, "çift: iki ortanın ortalaması")
	eq(Net._ping_estimate_ms([166_200, 155_400, 157_900], {}, 0), 158, "tek: orta")
	eq(Net._ping_estimate_ms([200], {}, 0), 1, "yerelde 0'a yuvarlanmaz (0 yalnız kendisi)")
	eq(Net._ping_estimate_ms([20_000], {1: 0}, 900_000), 20, "tek yanıtsız istek (kayıp olabilir) sayılmaz")
	eq(Net._ping_estimate_ms([20_000], {1: 0, 2: 250_000}, 900_000), 650, "ikinci en eski isteğin yaşı")
	eq(Net._ping_estimate_ms([], {1: 0, 2: 250_000}, 400_000), 150, "örnek yokken de yaş")


func test_ping_estimate_under_jitter_stays_near_nominal() -> void:
	# Hard network: samples nominal 150 ms +-30 ms (uniform; fixed seeds, deterministic). The smallest (t2) dropped to ~120 here and
	# broke the latency proof and the HUD warning. The standard error of the median of 16 samples is ~7.5 ms in this distribution:
	# >= 90% of trials must be within +-10% of nominal, all within +-20% (the statistical limit of a single window; tighter would
	# lengthen the window and slow the HUD response).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var min_low: int = 0
	var near: int = 0
	for trial: int in 50:
		rng.seed = 1000 + trial
		var samples: Array = []
		for i: int in Net.PING_WINDOW:
			samples.append(150_000 + rng.randi_range(-30_000, 30_000))
		var est: int = Net._ping_estimate_ms(samples, {}, 0)
		if int(samples.min()) < 135_000:
			min_low += 1
		if est >= 135 and est <= 165:
			near += 1
		if not is_true(est >= 120 and est <= 180, "deneme %d: %d ms nominal 150'ye ±%%20 değil" % [trial, est]):
			return
	is_true(near >= 45, "denemelerin >= %%90'ı ±%%10 içinde (%d/50)" % near)
	is_true(min_low >= 40, "karşılaştırma: en küçük örnek çoğu denemede -%%10 altında (%d/50)" % min_low)


func test_ping_estimate_ignores_minority_outliers() -> void:
	# 1..7 of 16 samples are stall outliers (e.g. 187-900 ms): the median stays at the network latency.
	for outliers: int in range(1, 8):
		var samples: Array = []
		for i: int in Net.PING_WINDOW:
			samples.append(900_000 - i * 50_000 if i < outliers else 20_000 + (i % 3) * 1000)
		samples.shuffle()
		var est: int = Net._ping_estimate_ms(samples, {}, 0)
		is_true(est >= 20 and est <= 22, "%d aykırı örnek medyanı bozmamalı (%d ms)" % [outliers, est])


func test_ping_rpc_config_is_unreliable_on_own_channel() -> void:
	# Coordinator decision (IS-026 t2): ping/pong is unordered unreliable, on a channel separate from game RPCs.
	var config: Dictionary = (Net.get_script() as Script).get_rpc_config()
	for method: String in ["_rpc_ping", "_rpc_pong"]:
		if not is_true(config.has(method), "%s RPC olarak tanımlı" % method):
			continue
		var c: Dictionary = config[method]
		eq(c.get("rpc_mode"), MultiplayerAPI.RPC_MODE_ANY_PEER, method + " any_peer")
		eq(c.get("transfer_mode"), MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, method + " unreliable (sırasız)")
		eq(c.get("channel"), Net.PING_CHANNEL, method + " kendi kanalı")
		eq(c.get("call_local"), false, method + " call_remote")
	# The start message is reliable and on the same ordered channel as auth (0): ping must not arrive before the handshake.
	var hello: Dictionary = config.get("_rpc_ping_hello", {})
	eq(hello.get("rpc_mode"), MultiplayerAPI.RPC_MODE_AUTHORITY, "hello yalnız host'tan")
	eq(hello.get("transfer_mode"), MultiplayerPeer.TRANSFER_MODE_RELIABLE, "hello güvenilir")
	eq(hello.get("channel", 0), 0, "hello kanal 0 (varsayılan)")
	ne(Net.PING_CHANNEL, 0, "oyun RPC kanalından ayrı")
	is_true(Net.PING_CHANNEL <= 2, "Steam şerit sınırı (0-2)")


## IS-026 t2: a peer with 20 ms RTT; a request every 250 ms, the sequence numbers in `lost` stay unanswered.
func _simulate_pings(peer_id: int, first_seq: int, count: int, lost: Array[int]) -> void:
	for i: int in count:
		var seq: int = first_seq + i
		var sent: int = seq * 250_000
		Net._note_ping_request(peer_id, seq, sent)
		if not lost.has(seq):
			is_true(Net._note_ping_reply(peer_id, seq, sent + 20_000))


func _estimate(peer_id: int, now_ms: int) -> int:
	return Net._ping_estimate_ms(Net._ping_samples.get(peer_id, []), Net._ping_pending.get(peer_id, {}), now_ms * 1000)


func test_ping_stall_raises_value_single_loss_does_not() -> void:
	var p: int = 77
	Net._forget_ping(p)
	_simulate_pings(p, 0, 16, [])
	eq(_estimate(p, 3_990), 20, "sağlıklı: 20 ms")
	# Single loss: 16 unanswered, 17 answered on time -> the value does not jump; 17's reply counts 16 as lost.
	Net._note_ping_request(p, 16, 4_000_000)
	eq(_estimate(p, 4_240), 20, "tek yanıtsız istek")
	Net._note_ping_request(p, 17, 4_250_000)
	eq(_estimate(p, 4_265), 20, "kayıptan sonraki istek henüz yolda")
	is_true(Net._note_ping_reply(p, 17, 4_270_000))
	eq((Net._ping_pending[p] as Dictionary).size(), 0, "yanıt eski bekleyenleri siler")
	eq(_estimate(p, 4_300), 20, "tek kayıp değeri şişirmedi")
	# The far end stops (18..26 unanswered): the value rises, the table is pruned keeping the oldest two.
	_simulate_pings(p, 18, 9, [18, 19, 20, 21, 22, 23, 24, 25, 26])
	var pending: Dictionary = Net._ping_pending[p]
	eq(pending.size(), Net.PING_PENDING_MAX, "tablo sınırlı")
	eq([pending.keys()[0], pending.keys()[1]], [18, 19], "en eski ikisi korunur")
	eq(_estimate(p, 5_000), 250, "takılma başı: yaş görünür")
	is_true(_estimate(p, 6_500) >= 1_500, "takılma sürdükçe değer yükselir (HUD uyarı eşiğini geçer)")
	is_false(Net._note_ping_reply(p, 20, 6_500_000), "budanmış isteğe gelen yanıt sayılmaz")
	is_false(Net._note_ping_reply(p, 999, 6_500_000), "bilinmeyen sıra numarası sayılmaz")
	is_false(Net._note_ping_reply(p + 1, 26, 6_500_000), "başka peer'a gitmiş istek sayılmaz")
	# Stall ends: a new request is answered, the value returns to the network latency.
	_simulate_pings(p, 27, 1, [])
	eq(_estimate(p, 6_800), 20, "takılma bitince değer düşer")
	Net._forget_ping(p)


func test_ping_request_acceptance() -> void:
	Net._forget_ping(5)
	var peers: PackedInt32Array = PackedInt32Array([1, 5])
	is_true(Net._accept_ping_request(5, peers, true, 1_000_000), "host: oturumdaki peer")
	is_false(Net._accept_ping_request(5, peers, true, 1_050_000), "host: 100 ms içinde ikinci istek reddedilir")
	is_true(Net._accept_ping_request(5, peers, true, 1_150_000), "host: aralık dolunca kabul")
	is_false(Net._accept_ping_request(6, peers, true, 2_000_000), "host: oturumda olmayan peer")
	is_false(Net._accept_ping_request(0, peers, true, 2_000_000), "host: RPC dışı çağrı (gönderen 0)")
	is_false(Net._accept_ping_request(5, peers, false, 3_000_000), "istemci: host dışından istek reddedilir")
	is_true(Net._accept_ping_request(1, peers, false, 3_000_000), "istemci: host'tan istek")
	Net._forget_ping(5)


func test_unsolicited_pong_is_ignored_and_leave_clears_ping_state() -> void:
	var port: int = free_udp_port()
	eq(Net.host(port, 4), OK)
	# On a call outside an RPC the sender is 0: an unexpected reply adds no sample.
	Net._rpc_pong(1)
	Net._rpc_ping(1)
	Net._rpc_ping_hello()
	is_true(Net._ping_samples.is_empty(), "istenmemiş yanıt sayılmaz")
	is_true(Net._ping_ready.is_empty(), "RPC dışı istek/hello ping'i başlatmaz")
	Net._ping_samples[42] = [10_000]
	Net._ping_pending[42] = {7: 0}
	eq(Net.get_ping_ms(42), -1, "oturumda olmayan peer -1 (eski örnek olsa da)")
	await tree().process_frame
	await tree().process_frame
	eq(Net.get_ping_ms(), 0, "host için 0")
	eq(Net.get_ping_info(), {"source": "self", "samples": 0})
	eq(Net.get_ping_info(42)["source"], "none", "oturumda olmayan peer")
	Net.leave()
	is_true(Net._ping_samples.is_empty() and Net._ping_pending.is_empty(), "leave ping durumunu siler")
	eq(Net.get_ping_ms(), -1)


func test_host_rejects_bad_parameters() -> void:
	eq(Net.host(0), ERR_INVALID_PARAMETER)
	eq(Net.host(70000), ERR_INVALID_PARAMETER)
	eq(Net.host(free_udp_port(), 0), ERR_INVALID_PARAMETER)
	is_false(Net.is_online())


func test_invalid_address_emits_connection_failed() -> void:
	_watch()
	for address: String in ["bad address!", "", "  ", "-nope-.example", "1.2.3.4.5.6:7"]:
		_failed = 0
		var err: Error = Net.join(address, 7777)
		ne(err, OK, "geçersiz adres hata dönmeli: '%s'" % address)
		is_false(Net.is_online())
		eq(Net.local_peer_id(), 0)
		is_true(await _wait_failed(1.0), "connection_failed yayılmalı: '%s'" % address)
	_failed = 0
	ne(Net.join("127.0.0.1", 0), OK, "geçersiz port")
	is_true(await _wait_failed(1.0))
	eq([_connected, _host_lost], [0, 0])
	_unwatch()


func test_unreachable_host_times_out_with_connection_failed() -> void:
	_watch()
	var previous: int = Net.connect_timeout_ms
	Net.connect_timeout_ms = 1000
	var t0: int = Time.get_ticks_msec()
	eq(Net.join("127.0.0.1", free_udp_port()), OK, "bağlanma denemesi başlar")
	is_false(Net.is_online(), "kabul edilmeden çevrimiçi sayılmaz")
	ne(Net.local_peer_id(), 0, "denemede kimlik atanmış")
	is_true(await _wait_failed(5.0), "kapalı porta bağlanma connection_failed ile bitmeli")
	is_true(Time.get_ticks_msec() - t0 < 4000, "connect_timeout_ms'ye uyulmalı")
	is_false(Net.is_online())
	eq(Net.local_peer_id(), 0)
	eq([_connected, _host_lost], [0, 0])
	Net.connect_timeout_ms = previous
	# Can be retried after a failure.
	eq(Net.host(free_udp_port()), OK)
	Net.leave()
	_unwatch()


func test_transport_is_private_to_net() -> void:
	# S1: only net.gd touches the transport classes.
	var offenders: PackedStringArray = []
	for path: String in _scripts_under("res://"):
		if path == "res://autoload/net.gd" or path.begins_with("res://tests/"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if text.contains("ENetMultiplayerPeer") or text.contains("ENetPacketPeer") or text.contains("SteamMultiplayerPeer"):
			offenders.append(path)
	eq(offenders, PackedStringArray(), "taşıma sınıfı net.gd dışında kullanılmış")


static func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts_under(dir.path_join(d)))
	return out
