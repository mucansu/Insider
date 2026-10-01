extends Node
## Ağ katmanı (autoload `Net`, sözleşme S1 — docs/notes/mimari.md).
## IS-003 stub'ı: imzalar sözleşmeyle birebir, gövdeler tipli varsayılan döner.
## Gövdeyi cekirdek US-001'de yazar; taşıma seçimi `_create_peer()` içinde kalır.

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_host()
signal connection_failed()
signal host_disconnected()


func host(port: int = 7777, max_peers: int = 4) -> Error:
	return ERR_UNAVAILABLE


func join(address: String, port: int = 7777) -> Error:
	return ERR_UNAVAILABLE


func leave() -> void:
	pass


func is_host() -> bool:
	return false


func is_online() -> bool:
	return false


func local_peer_id() -> int:
	return 0


## Host için 0; bilinmiyorsa -1.
func get_ping_ms(peer_id: int = 1) -> int:
	return -1
