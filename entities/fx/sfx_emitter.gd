class_name SfxEmitter
extends AudioStreamPlayer2D
## Konumlu ses çalar (IS-024): sahibinin alt düğümü (`Sfx`), olayı adıyla `data/sfx_catalog.tres`'ten çalar
## (SfxCatalog). Autoload değil (§6); prop çalarını `_ready`'de `SfxEmitter.of(self)` ile kurar.
## Dinleyici: görünümün Camera2D'si (yerel avatar); mesafe zayıflatması AudioStreamPlayer2D'den, duyulma
## mesafesi girdinin `max_distance`'ından (gürültü yarıçapı × 2; ses-ve-sfx §1 kural 3), girdide 0 ise
## DEFAULT_MAX_DISTANCE. Aynı olay en kısa aralıktan (`SfxEntry.min_interval`) sık çalmaz. Tekrarlayan ses
## (kasa boşaltma tiki): `repeat_while(olay, koşul)`.
## Çoğaltılan durum sesi (`play_on_change`): istemcide sahibin MultiplayerSynchronizer'ından gelen İLK eşitleme
## paketi taban durumdur (geç katılım/yeniden bağlanma: olay o peer'ın gözü önünde olmadı) ve sessiz uygulanır;
## sonraki değişimler çalar. Host ve çevrimdışı her zaman çalar. Ses yalnız yerel çalar; ağa ses gitmez.

## Olay çalındı (yalnız gerçekten çalınınca; testler ve ileride altyazı/görsel eş için).
signal played(event: StringName)

const NODE_NAME := &"Sfx"
## Girdi mesafe vermiyorsa (AudioStreamPlayer2D varsayılanı).
const DEFAULT_MAX_DISTANCE := 2000.0

## Boşsa ilk çalışta `SfxCatalog.load_default()`.
var catalog: SfxCatalog = null
## Saat (sn); testler değiştirir. Geçersizse `SfxCatalog.now_sec()`.
var clock: Callable
## İstemcide ilk eşitleme paketi henüz gelmedi: `play_on_change` sessiz (taban durum). `_ready` kurar;
## sahibin eşitleyicisi `delta_synchronized`/`synchronized` yayınca kalkar (`mark_synced`).
var baseline_pending: bool = false

var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _repeat_event: StringName = &""
var _repeat_while: Callable
var _played: int = 0
var _silent: int = 0


func _ready() -> void:
	_rng.randomize()
	set_process(_repeat_while.is_valid())
	var holder: Node = get_parent()
	if holder == null:
		return
	for node: Node in holder.find_children("*", "MultiplayerSynchronizer", false, false):
		var sync: MultiplayerSynchronizer = node as MultiplayerSynchronizer
		baseline_pending = not multiplayer.is_server()
		sync.delta_synchronized.connect(mark_synced)
		sync.synchronized.connect(mark_synced)


## `owner_node`'un çaları; yoksa kurar.
static func of(owner_node: Node) -> SfxEmitter:
	var existing: SfxEmitter = owner_node.get_node_or_null(NodePath(NODE_NAME)) as SfxEmitter
	if existing != null:
		return existing
	var emitter := SfxEmitter.new()
	emitter.name = NODE_NAME
	owner_node.add_child(emitter)
	return emitter


## Tek satırlık çağrı: `owner_node`'un çalarından olayı çalar.
static func play_on(owner_node: Node, event: StringName) -> bool:
	return of(owner_node).play_event(event)


## Çoğaltılan durum değişiminin sesi: istemcide ilk eşitleme paketi (taban durum) sessiz.
static func play_on_change(owner_node: Node, event: StringName) -> bool:
	var emitter: SfxEmitter = of(owner_node)
	if emitter.baseline_pending:
		emitter.count_silent()
		return false
	return emitter.play_event(event)


## İlk eşitleme paketi uygulandı: bundan sonraki değişimler çalar.
func mark_synced() -> void:
	baseline_pending = false


func count_silent() -> void:
	_silent += 1


## Döküm için (S6 "props"): çalınan ve taban durum olarak sessiz geçilen ses sayısı.
func stats() -> Dictionary:
	return {"played": _played, "silent": _silent}


## Olayı çalar; olay katalogda yoksa, dosyası yoksa, çalar ağaçta değilse ya da en kısa aralık dolmadıysa
## false (sessiz).
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
	max_distance = entry.max_distance if entry.max_distance > 0.0 else DEFAULT_MAX_DISTANCE
	if SfxCatalog.playback_enabled():
		play()
	_played += 1
	played.emit(event)
	return true


## `condition` doğru döndükçe her karede `event` çalınmaya çalışılır (ritim = girdinin en kısa aralığı).
func repeat_while(event: StringName, condition: Callable) -> void:
	_repeat_event = event
	_repeat_while = condition
	set_process(condition.is_valid())


func _process(_delta: float) -> void:
	if _repeat_while.is_valid() and bool(_repeat_while.call()):
		play_event(_repeat_event)


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else SfxCatalog.now_sec()
