class_name PlayerStatus
extends Node2D
## Oyuncunun tutulma/yakalanma durumu (US-008 AC7; mimari.md S2, S3 eki, S7; GDD §9.3; KR-019 K3). Player'ın
## `Status` alt düğümü. Oyuncu kökü istemci yetkilidir (kendi hareketi), bu alt ağaç ise **host yetkilidir**
## (`_enter_tree`'de yetki 1'e çevrilir; her peer'da aynı): durum yalnız host'ta değişir ve kendi
## MultiplayerSynchronizer'ı (değişince, güvenilir) ile yayılır. Görsel ve oyuncu yalnız durumu okur.
##
## - FREE → HELD (`host_hold(window)`: sahip tuttu; pencere dolunca CAUGHT) → FREE (`Rescue` tamamlandı: ekip
##   arkadaşı 32 px içinde 1 sn "çek") ya da CAUGHT (kalıcı; `host_catch()`: mahalleli yakaladı, kurtarma yok).
## - `Rescue` (Interactable, S7) yalnız HELD iken etkin; tamamlanınca host `rescued(rescuer)` yayar.
## - Host olayları herkese `Game.raise_session_event` ile de gider (US-012 sonucu bunlardan kurar):
##   `player_held {peer, window}`, `player_caught {peer, by}` (by: &"owner" | &"chaser"), `player_rescued {peer, by}`.
## - ÇEK host'ta doğrulanır: kurtaran tutulanın kendisi olamaz ve serbest olmalıdır (tutulan/yakalanan reddedilir).
## - Pencere sayacı host'ta; istemci `hold_left()`'i HELD'e geçtiği andan yerelde sayar (yalnız gösterim).

## Her peer'da: durum değişti.
signal changed(state: int)
## Yalnız host'ta: tutulan oyuncu kurtarıldı (`rescuer` = çeken peer).
signal rescued(rescuer: int)

enum State { FREE, HELD, CAUGHT }

const SYNC_NAME := "StatusSync"
const HOST_PEER := 1
## ÇEK (GDD §9.3): ekip arkadaşı 32 px içinde 1 sn basılı tutar.
const RESCUE_KEY := "INTERACT_RESCUE"
const RESCUE_RANGE := 32.0
const RESCUE_HOLD_SEC := 1.0
## Tutma penceresi dolunca yakalayan (tutmayı yalnız sahip yapar).
const HOLD_CATCHER := &"owner"

## Çoğaltılan durum (host yazar).
var state: int = State.FREE:
	set = _set_state
## Son tutmanın penceresi (sn; çoğaltılır, istemci sayacı buradan başlar).
var hold_window: float = 0.0

var _hold_left: float = 0.0
var _times_held: int = 0
var _caught_by: StringName = &""

@onready var _rescue: Interactable = $Rescue


func _enter_tree() -> void:
	set_multiplayer_authority(HOST_PEER, true)


func _ready() -> void:
	_rescue.action_key = RESCUE_KEY
	_rescue.hold_time = RESCUE_HOLD_SEC
	_rescue.interact_range = RESCUE_RANGE
	_rescue.completed.connect(_on_rescue_completed)
	_rescue.actor_filter = _rescuer_allowed
	add_child(_make_sync())
	_apply()


func _physics_process(delta: float) -> void:
	step(delta)


## Pencere sayacı: host'ta süre dolunca CAUGHT; istemcide yalnız gösterim sayacı.
func step(delta: float) -> void:
	if state != State.HELD:
		return
	_hold_left = maxf(_hold_left - maxf(delta, 0.0), 0.0)
	if _hold_left <= 0.0 and _is_host():
		_caught_by = HOLD_CATCHER
		_become(State.CAUGHT)


func is_free() -> bool:
	return state == State.FREE


func is_held() -> bool:
	return state == State.HELD


func is_caught() -> bool:
	return state == State.CAUGHT


## Tutma penceresinden kalan (sn; HELD değilse 0).
func hold_left() -> float:
	return _hold_left if state == State.HELD else 0.0


## Yakalayan (host; yakalanmadıysa boş): &"owner" | &"chaser".
func caught_by() -> StringName:
	return _caught_by


## Bu oyunda kaç kez tutuldu (host).
func times_held() -> int:
	return _times_held


## Yalnız host: serbest oyuncuyu `window` sn tutar. Kabul edilmezse false.
func host_hold(window: float) -> bool:
	if not _is_host() or state != State.FREE:
		return false
	_times_held += 1
	hold_window = maxf(window, 0.0)
	_become(State.HELD)
	return true


## Yalnız host: kalıcı yakalama; `by` yakalayan (S3 eki: &"chaser" mahalleli, &"owner" tutma penceresi doldu).
func host_catch(by: StringName = &"") -> bool:
	if not _is_host() or state == State.CAUGHT:
		return false
	_caught_by = by
	_become(State.CAUGHT)
	return true


## ÇEK süzgeci (host): kurtaran tutulan oyuncunun kendisi olamaz; serbestlik Interactable'da (`not_free`).
func _rescuer_allowed(peer_id: int, _actor: Node) -> bool:
	return peer_id != _peer()


## Yalnız host: tutulan oyuncuyu serbest bırakır (kurtarma).
func host_release() -> bool:
	if not _is_host() or state != State.HELD:
		return false
	_become(State.FREE)
	return true


func _on_rescue_completed(rescuer: int) -> void:
	if state != State.HELD:
		return
	_become(State.FREE)
	rescued.emit(rescuer)
	_raise(&"player_rescued", {"peer": _peer(), "by": rescuer})


func _become(value: int) -> void:
	state = value
	match value:
		State.HELD:
			_raise(&"player_held", {"peer": _peer(), "window": hold_window})
		State.CAUGHT:
			_raise(&"player_caught", {"peer": _peer(), "by": _caught_by})


func _set_state(value: int) -> void:
	if value == state:
		return
	state = value
	if value == State.HELD:
		_hold_left = hold_window
	if is_node_ready():
		_apply()
	changed.emit(value)


func _apply() -> void:
	if _rescue != null:
		_rescue.enabled = state == State.HELD


func _raise(kind: StringName, data: Dictionary) -> void:
	if _is_host() and Net.is_online():  # çevrimdışı (tek başına/test) oturum olayı yok
		Game.raise_session_event(kind, data)


## Sahibi oyuncunun peer'ı (oyuncu kökünün yetkisi).
func _peer() -> int:
	var parent: Node = get_parent()
	return parent.get_multiplayer_authority() if parent != null else 0


func _is_host() -> bool:
	return _host_side()


func _make_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for prop: String in [".:hold_window", ".:state"]:
		var path := NodePath(prop)
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.replication_config = config
	return sync


## Host ya da çevrimdışı (S2). Net bayraklarından okunur: kopuş anında (döküm, son kareler) kapanmış taşımaya
## `multiplayer.is_server()` sorup hata basmasın (Game ile aynı kalıp).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
