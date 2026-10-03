class_name StoreAlert
extends Node
## Bakkalın uyarı yöneticisi (US-008 AC5/AC6/AC9; GDD §6.2, §9.1 T1 uyarı eşlemesi; mimari.md S3 eki).
## Seviyede `NPCs` altında durağan düğüm; kardeşleri `Owner` (StoreOwner) ve `ChaserSpawner`
## (MultiplayerSpawner, spawn_path = NPCs). Yalnız host karar verir; sonuç Game'in çoğaltılan uyarı API'sine yazılır.
##
## - Merdiven (I4, bakkal kümesi): {0→1, 1→2, 2→3, 3→5, 2→1, 1→0} (`Fsm`; atlamalar ara kademeden yürünür).
##   Sahibin istediği kademe (`OwnerBrain.alarm_want`: 1 şüphe/sorgu, 2 bağırdı) yukarı hemen; 2 → 1 sahip
##   sakinleşince (30 sn görüş yok), 1 → 0 `alert_calm_sec` sakin kaldıktan sonra. İlk mahalleli ön/arka kapıya
##   ya da içeri girince 3 (dönmez) + polis sayacı (`police_timer_sec`, Game.alert_timer_left); sayaç bitince 5
##   ve `police_arrived` (session_event; US-012 sonucu).
## - Mahalleli: her bağırışta (ilk ve yeniden bağırış) `neighbour_delay_sec` sonra `NeighbourSpawn`'da bir komşu
##   (en fazla `max_neighbours`); koşu hedefi bağırış anındaki sahip konumu. `chaser_spawn` her peer'da yayılır.
## - US-016 ekleri: NPC tavanı (`room_query`, nüfus üreticisi bağlar; boşsa sınırsız) doluyken vadesi gelen komşu
##   yer açılana kadar bekler; yoldan geçen → mahalleli dönüşümü `spawn_chaser_at` (nüfus üreticisi bağırışta
##   çağırır; komşu sayısına girmez). Mahalleli adları tek sayaçla (`Chaser<n>`).
## Döküm "chasers": {spawned, states, catches (host)}.

## Her peer'da: mahalleli üretildi (AC10).
signal chaser_spawn(chaser: Node)
## Her peer'da: polis geldi (uyarı 5; AC10).
signal police_arrived()

const CHASER_SCENE := "res://entities/npc/chaser/chaser.tscn"
const OWNER_TUNING_PATH := "res://data/npc/owner_tuning.tres"
const EDGES := {0: [1], 1: [2, 0], 2: [3, 1], 3: [5]}
const POLICE_LEVEL := 5
const INSIDE_LEVEL := 3
const DUMP_KEY := "chasers"
const POLICE_EVENT := &"police_arrived"

@export var owner_path: NodePath = ^"../Owner"
@export var spawner_path: NodePath = ^"../ChaserSpawner"
@export var tuning: OwnerTuning
@export var auto_step: bool = true
## false: uyarı yöneticisi işlemez (NPC'siz fikstür).
@export var active: bool = true
## NPC tavanında yer var mı (US-016; func() -> bool). Boşsa sınırsız.
var room_query: Callable = Callable()

var ladder := Fsm.new(0, EDGES)

var _owner: StoreOwner = null
var _spawner: MultiplayerSpawner = null
var _chaser_scene: PackedScene = null
var _pending: Array[float] = []
var _spawned: int = 0
var _serial: int = 0
var _converted: int = 0
var _seen_spawns: int = 0
var _calm_for: float = 0.0
var _shout_at: Vector2 = Vector2.INF


func _ready() -> void:
	if tuning == null:
		tuning = load(OWNER_TUNING_PATH) as OwnerTuning
	_owner = get_node_or_null(owner_path) as StoreOwner
	_spawner = get_node_or_null(spawner_path) as MultiplayerSpawner
	_chaser_scene = load(CHASER_SCENE) as PackedScene
	if _spawner != null:
		_spawner.spawn_function = _spawn_chaser
		_spawner.spawned.connect(_on_spawned)
	Game.session_event.connect(_on_session_event)
	if active and _host_side() and _owner != null and _owner.active:
		_owner.brain().shouted.connect(_on_shouted)
	if not Args.dump_path.is_empty():
		Game.register_dump_provider(DUMP_KEY, dump_state)


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


## Bir adım (yalnız host): komşu sayaçları, istenen kademe, polis sayacı.
func step(delta: float) -> void:
	if not active or not _host_side() or _owner == null or not _owner.active:
		return
	for i: int in range(_pending.size() - 1, -1, -1):
		_pending[i] -= delta
		if _pending[i] <= 0.0 and _has_room():
			_pending.remove_at(i)
			_spawn_neighbour()
	var want: int = _owner.brain().alarm_want()
	if _any_chaser_inside():
		want = maxi(want, INSIDE_LEVEL)
	if ladder.state == INSIDE_LEVEL and Game.alert_timer_left() == 0.0:
		want = POLICE_LEVEL
	_calm_for = _calm_for + delta if want == 0 else 0.0
	ladder.step(delta)
	_apply(want)


func level() -> int:
	return ladder.state


func chasers() -> Array[Chaser]:
	var out: Array[Chaser] = []
	var root: Node = get_parent()
	if root != null:
		for child: Node in root.get_children():
			if child is Chaser:
				out.append(child as Chaser)
	return out


func dump_state() -> Dictionary:
	var states: Array[StringName] = []
	var catches: Array[int] = []
	for c: Chaser in chasers():
		states.append(c.state_name())
		if _host_side():
			catches.append_array(c.brain().catches)
	var out := {"spawned": _seen_spawns, "states": states}
	if _host_side():
		out["catches"] = catches
		out["ladder"] = ladder.history_rows()  # [kademe, giriş anı]; I4 kanıtı (istemcide Game "alert.history")
	return out


func _apply(want: int) -> void:
	var current: int = ladder.state
	if want > current:
		for next: int in ladder.route(want):
			_enter(next)
		return
	if current == 2 and want <= 1:
		_enter(1)
	elif current == 1 and want == 0 and _calm_for >= tuning.alert_calm_sec:
		_enter(0)


func _enter(next: int) -> void:
	if not ladder.go(next):
		return
	Game.set_alert_level(next)
	if next == INSIDE_LEVEL:
		Game.set_alert_timer(tuning.police_timer_sec)
	elif next == POLICE_LEVEL:
		if Net.is_online():
			Game.raise_session_event(POLICE_EVENT, {})  # her peer'da session_event → police_arrived
		else:
			police_arrived.emit()  # çevrimdışı: oturum olayı yok


func _on_shouted(_recheck: bool) -> void:
	_shout_at = _owner.global_position
	if _spawned + _pending.size() < tuning.max_neighbours:
		_pending.append(tuning.neighbour_delay_sec)


func _spawn_neighbour() -> void:
	if _spawner == null or _owner == null:
		return
	var at: Vector2 = _owner.senses().marker_position(tuning.neighbour_marker)
	if not at.is_finite():
		push_warning("StoreAlert: %s işareti yok; komşu üretilmedi" % tuning.neighbour_marker)
		return
	_spawned += 1
	_spawn(at, _shout_at)


## Host (US-016 dönüşüm): `at`'ta (global) koşu hedefi `goal` olan mahalleli üretir; komşu sayısına girmez.
func spawn_chaser_at(at: Vector2, goal: Vector2) -> Node:
	if not active or not _host_side() or _spawner == null or not at.is_finite():
		return null
	_converted += 1
	return _spawn(at, goal)


func converted_count() -> int:
	return _converted


func _spawn(at: Vector2, goal: Vector2) -> Node:
	_serial += 1
	var root: Node2D = get_parent() as Node2D
	var data := {"n": _serial, "pos": root.to_local(at) if root != null else at, "goal": goal}
	var node: Node = _spawner.spawn(data)
	if node != null:
		_on_spawned(node)
	return node


func _has_room() -> bool:
	return not room_query.is_valid() or bool(room_query.call())


## Spawner'ın spawn_function'ı (host'ta spawn() içinde, istemcide paket gelince).
func _spawn_chaser(data: Variant) -> Node:
	var d: Dictionary = data if data is Dictionary else {}
	var chaser: Chaser = _chaser_scene.instantiate() as Chaser
	chaser.name = "Chaser%d" % int(d.get("n", 0))
	if d.get("pos") is Vector2:
		chaser.position = d["pos"]
	if d.get("goal") is Vector2:
		chaser.goal = d["goal"]
	return chaser


func _on_spawned(node: Node) -> void:
	_seen_spawns += 1
	chaser_spawn.emit(node)


func _on_session_event(kind: StringName, _data: Dictionary) -> void:
	if kind == POLICE_EVENT:
		police_arrived.emit()


## Bir mahalleli ön/arka kapıya vardı ya da içeride (uyarı 3).
func _any_chaser_inside() -> bool:
	var senses: CivilianSenses = _owner.senses()
	for c: Chaser in chasers():
		var pos: Vector2 = c.global_position
		if CivilianRules.is_inside(senses.zone_of(pos)):
			return true
		for marker_name: StringName in tuning.entry_markers:
			var door: Vector2 = senses.marker_position(marker_name)
			if door.is_finite() and pos.distance_to(door) <= tuning.entry_radius:
				return true
	return false


## Host ya da çevrimdışı (S2). Net bayraklarından okunur: kopuş anında (döküm, son kareler) kapanmış taşımaya
## `multiplayer.is_server()` sorup hata basmasın (Game ile aynı kalıp).
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
