extends Node
## Gürültü (autoload `NoiseBus`, sözleşme S8 — docs/notes/mimari.md).
## IS-003 stub'ı: imza sözleşmeyle birebir; gövdeyi oynanis yazar (hesap kuralları core/ altında).


## İstemciden çağrılırsa host'a iletilir; host `noise_listener` grubundaki düğümlerin
## `hear_noise(pos, radius, kind)` metodunu çağırır ve herkese görsel halka olayı yollar.
func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void:
	pass
