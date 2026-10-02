class_name PropDump
extends RefCounted
## Prop'ların ortak test dökümü (mimari.md S6: `"props"` anahtarı). Her prop `GROUP`'a girer ve
## `dump_state() -> Dictionary` sunar; döküm anında gruptaki bütün prop'lar düğüm adıyla toplanır:
## {"Register": {...}, "FrontDoor": {...}}. Sağlayıcı süreç başına bir kez kaydedilir (yalnız `--dump`).

const KEY := "props"
const GROUP := &"dump_props"

static var _registered: bool = false


## Prop `_ready`'de çağırır; `--dump` verilmediyse bir şey yapmaz.
static func register() -> void:
	if _registered or Args.dump_path.is_empty():
		return
	_registered = true
	Game.register_dump_provider(KEY, collect)


static func collect() -> Dictionary:
	var out: Dictionary = {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node.has_method(&"dump_state"):
			out[str(node.name)] = node.call(&"dump_state")
	return out


## Duvar saati (sn; aynı makinedeki süreçler arasında karşılaştırılabilir): sonucun görünme gecikmesi ölçümü.
static func wall_time() -> float:
	return Time.get_unix_time_from_system()
