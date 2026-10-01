extends Node
## Oturum ve oyuncular (autoload `Game`, sözleşme S3 — docs/notes/mimari.md).
## IS-003 stub'ı: imzalar sözleşmeyle birebir, gövdeler tipli varsayılan döner.
## Gövdeyi (seviye yükleme, PlayerSpawner, ekip nakdi, döküm) cekirdek US-001'de yazar.

signal players_changed()
signal local_player_changed(player: Node)
signal team_cash_changed(value: int)
signal level_loaded(level: Node)
## Herkeste yayılır (ör. &"police_called").
signal session_event(kind: StringName, data: Dictionary)

const DEFAULT_LEVEL := "res://levels/store_a.tscn"
const HUD_SCENE := "res://ui/hud.tscn"

## Varsayılanı res://entities/player/player.tscn (US-001 bağlar); testler değiştirebilir.
var player_scene: PackedScene


## Bağlanınca host'a bildirilir.
func set_local_name(player_name: String) -> void:
	pass


## peer_id -> {"name": String, "color": Color}
func players() -> Dictionary:
	return {}


## Yerel oyuncu düğümü ya da null.
func local_player() -> Node:
	return null


## Yalnız host; herkese yükletir.
func start_level(level_path: String) -> void:
	pass


func current_level() -> Node:
	return null


## Yalnız host.
func add_team_cash(amount: int) -> void:
	pass


func team_cash() -> int:
	return 0


## Yalnız host; herkese yayınlar, dökümde "events" listesine girer.
func raise_session_event(kind: StringName, data: Dictionary = {}) -> void:
	pass


func register_dump_provider(key: String, provider: Callable) -> void:
	pass


func collect_dump() -> Dictionary:
	return {}
