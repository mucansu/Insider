class_name PropDump
extends RefCounted
## Shared test dump for props (S6: `"props"` key). Each prop joins `GROUP` and exposes `dump_state() -> Dictionary`; at dump time all
## props in the group are collected by node name: {"Register": {...}, "FrontDoor": {...}}. The provider registers once per process
## (only with `--dump`).

const KEY := "props"
const GROUP := &"dump_props"

static var _registered: bool = false


## Props call this in `_ready`; does nothing without `--dump`.
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


## Wall clock (s; comparable across processes on one machine): measures the result's visible delay.
static func wall_time() -> float:
	return Time.get_unix_time_from_system()
