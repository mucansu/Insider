extends Node2D
## US-009 test listener (tests only): counts the `heard` signal of a `Hearing` child (emitted only on the host). Dump (S6, `--dump`
## only): "noise_probes" - {"<node name>": {"heard": int, "kinds": {kind: int},
## "min_radius": float (smallest effective radius heard; -1 if none)}}. Network scenario: tests/net/noise_ring.json.

const GROUP := &"noise_probes"
const DUMP_KEY := "noise_probes"

static var _registered: bool = false

var _heard: int = 0
var _kinds: Dictionary = {}
var _min_radius: float = -1.0


func _ready() -> void:
	add_to_group(GROUP)
	var hearing: Hearing = get_node_or_null("Hearing") as Hearing
	if hearing == null:
		push_error("noise_probe: Hearing alt düğümü yok: %s" % get_path())
		return
	hearing.heard.connect(_on_heard)
	if not _registered and not Args.dump_path.is_empty():
		_registered = true
		Game.register_dump_provider(DUMP_KEY, collect)


func state() -> Dictionary:
	return {"heard": _heard, "kinds": _kinds.duplicate(), "min_radius": _min_radius}


static func collect() -> Dictionary:
	var out: Dictionary = {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node.has_method(&"state"):
			out[str(node.name)] = node.call(&"state")
	return out


func _on_heard(_pos: Vector2, radius: float, kind: StringName) -> void:
	_heard += 1
	var key: String = str(kind)
	_kinds[key] = int(_kinds.get(key, 0)) + 1
	_min_radius = radius if _min_radius < 0.0 else minf(_min_radius, radius)
