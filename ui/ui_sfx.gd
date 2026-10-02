class_name UiSfx
extends AudioStreamPlayer
## Arayüz sesi (IS-024): konumsuz çalar, ekranın alt düğümü (`UiSfx`). Olaylar `data/sfx_catalog.tres`'ten
## (SfxCatalog) adla çalınır; aynı olay en kısa aralıktan sık çalmaz. Düğmeler `wire_buttons(ekran)` ile
## bağlanır: odak -> ui_focus, basma -> ui_click. Uyarı merdiveni ve iş sonu ekranı kendi olaylarını çalar.
## Ses yalnız eşlik eder; hiçbir bilgi yalnız sesle verilmez (ses-ve-sfx §1 kural 7).

## Olay çalındı (yalnız gerçekten çalınınca; testler okur).
signal played(event: StringName)

const NODE_NAME := &"UiSfx"
const CLICK := &"ui_click"
const FOCUS := &"ui_focus"

## Boşsa ilk çalışta `SfxCatalog.load_default()`.
var catalog: SfxCatalog = null
## Saat (sn); testler değiştirir. Geçersizse `SfxCatalog.now_sec()`.
var clock: Callable

var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## `owner_node`'un arayüz çaları; yoksa kurar.
static func of(owner_node: Node) -> UiSfx:
	var existing: UiSfx = owner_node.get_node_or_null(NodePath(NODE_NAME)) as UiSfx
	if existing != null:
		return existing
	var player := UiSfx.new()
	player.name = NODE_NAME
	owner_node.add_child(player)
	return player


## `root` altındaki bütün düğmelere odak ve basma sesini bağlar; çaları döndürür.
static func wire_buttons(root: Node) -> UiSfx:
	var player: UiSfx = of(root)
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		button.focus_entered.connect(player.play_event.bind(FOCUS))
		button.pressed.connect(player.play_event.bind(CLICK))
	return player


## Olayı çalar; olay katalogda yoksa, çalar ağaçta değilse ya da en kısa aralık dolmadıysa false (sessiz).
func play_event(event: StringName) -> bool:
	if not is_inside_tree():
		return false
	if catalog == null:
		catalog = SfxCatalog.load_default()
	var entry: SfxEntry = catalog.take(event, _last_played, _now())
	if entry == null:
		return false
	stream = entry.stream
	volume_db = entry.volume_db
	pitch_scale = entry.pick_pitch(_rng)
	play()
	played.emit(event)
	return true


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else SfxCatalog.now_sec()
