extends Node
## Açılış sahnesi (mimari.md §2, S3, S6).
## - Argümansız: `res://ui/main_menu.tscn` varsa ona geçer; yoksa uyarı basar (headless'ta kod 0 ile çıkar,
##   pencereli açılışta boş sahnede bekler). Oturum sonrası menüye dönüşü arayüz (HUD) yapar; main.gd ve
##   Game sahne değiştirmez (çift geçiş olmasın).
## - `--host`: oturum açar, `--level` (yoksa Game.DEFAULT_LEVEL) yükler; hazır olunca stdout'a tek satır
##   READY_MARKER basar (tools/net_smoke.py bunu bekler).
## - `--join=ADDR`: bağlanır; kabul edilince READY_MARKER basar.
## - Argümanla açılan oturumda (headless ya da pencereli) menüye dönülmez, çıkılır: host kaybı kod 0,
##   katılma başarısızlığı / host, seviye ya da oyuncu sahnesi açılamaması kod 1 (döküm varsa yazılır).
## - Otomasyon (`--dump` ya da `--quit-after`; Args.is_automated()):
##   · `--quit-after=SN`: SN saniyede döküm yazılır, QUIT_LINGER_SEC daha oturumda kalınır (diğer süreçlerin
##     dökümü tam oturumu görsün), sonra Net.leave() ve kod 0 ile çıkış.
##   · Host kaybında döküm ("host_lost": true) hemen yazılır (bekleme payı yok).
##   · Dökümde ek anahtarlar: "exit_reason" (quit_after | host_lost | connection_failed | error) ve
##     "samples": duvar saatine hizalı SAMPLE_INTERVAL_SEC dilimlerinde oyuncu konumları
##     [{"slot": int, "players": {"<peer_id>": [x, y]}}]; aynı makinedeki süreçler aynı dilimi karşılaştırır.
##   · Kare hızı MAX_FPS_AUTOMATED ile sınırlanır (headless döngü işlemciyi tüketmesin).

const MAIN_MENU := "res://ui/main_menu.tscn"
const READY_MARKER := "INSIDERS_READY"
const QUIT_LINGER_SEC := 1.0
## --quit-after yedek kapanışı: normal çıkıştan bu kadar sonra (main serbest kalmışsa).
const BACKSTOP_SEC := 2.0
const SAMPLE_INTERVAL_SEC := 0.2
const MAX_SAMPLES := 3000
const MAX_FPS_AUTOMATED := 60

## Testler değiştirebilir.
var menu_scene: String = MAIN_MENU

var _finishing: bool = false
var _exit_reason: String = ""
var _sampling: bool = false
var _samples: Array[Dictionary] = []
var _last_slot: int = -1


func _ready() -> void:
	_start.call_deferred()


## Açılış kipi: &"host", &"join", &"menu" (menü sahnesi var) ya da &"none".
func start_mode(want_host: bool, join_address: String) -> StringName:
	if want_host:
		return &"host"
	if not join_address.is_empty():
		return &"join"
	if ResourceLoader.exists(menu_scene):
		return &"menu"
	return &"none"


func _start() -> void:
	var automated: bool = Args.is_automated()
	if automated:
		Engine.max_fps = MAX_FPS_AUTOMATED
		Game.register_dump_provider("exit_reason", func() -> String: return _exit_reason)
		if not Args.dump_path.is_empty():
			_sampling = true
			Game.register_dump_provider("samples", func() -> Array[Dictionary]: return _samples)
		if Args.quit_after > 0.0:
			get_tree().create_timer(Args.quit_after).timeout.connect(_finish.bind(0, "quit_after"))
			# Yedek: main bu arada serbest kalırsa (sahne değişti) süreç yine kapanır.
			var backstop: SceneTreeTimer = get_tree().create_timer(Args.quit_after + QUIT_LINGER_SEC + BACKSTOP_SEC)
			backstop.timeout.connect(Net.leave)
			backstop.timeout.connect(get_tree().quit.bind(0))
	if not Args.player_scene.is_empty():
		var scene: PackedScene = null
		if ResourceLoader.exists(Args.player_scene):
			scene = load(Args.player_scene) as PackedScene
		if scene == null:
			_fail("oyuncu sahnesi yüklenemedi: " + Args.player_scene)
			return
		Game.player_scene = scene
	if not Args.player_name.is_empty():
		Game.set_local_name(Args.player_name)
	match start_mode(Args.want_host, Args.join_address):
		&"host":
			_start_host()
		&"join":
			_start_join()
		&"menu":
			if automated:
				push_warning("main: otomasyon kipinde oturum argümanı yok; menüye geçilmiyor")
			else:
				get_tree().change_scene_to_file.call_deferred(menu_scene)
		_:
			push_warning("main: %s yok; menüsüz açılış (oturum için --host ya da --join=ADDR)" % menu_scene)
			if DisplayServer.get_name() == "headless" and not automated:
				get_tree().quit(0)


func _start_host() -> void:
	var err: Error = Net.host(Args.port)
	if err != OK:
		_fail("host açılamadı: port %d (%s)" % [Args.port, error_string(err)])
		return
	var level: String = Args.level if not Args.level.is_empty() else Game.DEFAULT_LEVEL
	if not ResourceLoader.exists(level):
		_fail("seviye bulunamadı: " + level)
		return
	Game.start_level(level)
	if Game.current_level() == null:
		_fail("seviye yüklenemedi: " + level)
		return
	print("%s host port=%d level=%s" % [READY_MARKER, Args.port, level])


func _start_join() -> void:
	Net.connected_to_host.connect(_on_connected_to_host)
	Net.connection_failed.connect(_on_connection_failed)
	Net.host_disconnected.connect(_on_host_disconnected)
	Net.join(Args.join_address, Args.port)  # hata olursa connection_failed da yayılır


func _on_connected_to_host() -> void:
	print("%s client peer=%d" % [READY_MARKER, Net.local_peer_id()])


func _on_connection_failed() -> void:
	push_warning("main: %s:%d adresine bağlanılamadı" % [Args.join_address, Args.port])
	_finish(1, "connection_failed")


func _on_host_disconnected() -> void:
	if _finishing:
		return  # çıkış sırasında (bekleme payında) host'un ayrılması beklenen durum
	push_warning("main: host bağlantısı koptu")
	_finish(0, "host_lost")


func _fail(message: String) -> void:
	push_error("main: " + message)
	_finish(1, "error")


func _finish(code: int, reason: String) -> void:
	if _finishing:
		return
	_finishing = true
	_exit_reason = reason
	_write_dump()
	var tree: SceneTree = get_tree()
	if reason == "quit_after" and Net.is_online():
		# Bekleme payında main serbest kalabilir (pencerelide host ayrılınca HUD menüye geçer); bu yüzden
		# await yok: zamanlayıcı doğrudan Net.leave ve tree.quit'e bağlı (main'e bağlı değil).
		var timer: SceneTreeTimer = tree.create_timer(QUIT_LINGER_SEC)
		timer.timeout.connect(Net.leave)
		timer.timeout.connect(tree.quit.bind(code))
		return
	Net.leave()
	tree.quit(code)


func _write_dump() -> void:
	if Args.dump_path.is_empty():
		return
	var file: FileAccess = FileAccess.open(Args.dump_path, FileAccess.WRITE)
	if file == null:
		push_error("main: döküm yazılamadı: %s (%s)" % [Args.dump_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(Game.collect_dump(), "  ", true))
	file.close()


func _process(_delta: float) -> void:
	if not _sampling or _finishing:
		return
	var slot: int = floori(Time.get_unix_time_from_system() / SAMPLE_INTERVAL_SEC)
	if slot == _last_slot:
		return
	_last_slot = slot
	var level: Level = Game.current_level() as Level
	var root: Node2D = level.players_root() if level != null else null
	if root == null:
		return
	var positions: Dictionary = {}
	for child: Node in root.get_children():
		if child is Node2D:
			var p: Vector2 = (child as Node2D).position
			positions[str(child.name)] = [p.x, p.y]
	if positions.is_empty() or _samples.size() >= MAX_SAMPLES:
		return
	_samples.append({"slot": slot, "players": positions})
