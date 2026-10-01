extends TestCase
## Net (autoload/net.gd, S1) tek süreçli birim testleri (US-001 AC7). Çok süreçli davranış tests/net/*.json.

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


## `connection_failed` sayacı artana ya da süre dolana kadar kare bekler.
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
	Net.leave()  # çevrimdışıyken etkisiz


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
	# Port bırakıldı: aynı porta yeniden host olunabilir.
	eq(Net.host(port), OK)
	Net.leave()
	_unwatch()


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
	# Başarısızlıktan sonra yeniden denenebilir.
	eq(Net.host(free_udp_port()), OK)
	Net.leave()
	_unwatch()


func test_transport_is_private_to_net() -> void:
	# S1: taşıma sınıflarına yalnız net.gd dokunur.
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
