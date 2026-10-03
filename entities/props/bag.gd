class_name Bag
extends Node2D
## Nakit çantası (US-012; GDD §9.3; mimari.md S7, S8, S10): `data/props/bag.tres`. Arka oda nakdi (BackroomCash).
## İki Interactable bileşeni (S7):
## - `Take`: yerdeki çantayı basılı tutarak al (tanımdaki süre, 2 sn); yalnız eli boş oyuncu (etiket `free_hands`).
## - `Handoff`: taşıyanın yanındaki eli boş ekip arkadaşı 0,3 sn tutarak devralır (taşıyan kendi çantasını
##   göremez: eli dolu). Bileşen çantayla birlikte taşıyanın üstünde durur.
## Host kuralları (HeistRules): taşıyan koşarken (`is_sprinting()`) her tam saniyede %25 düşürür; düşen çanta
## taşıyanın son bilinen konumunda yere iner ve 160 px gürültü yayar (S8, `NoiseBus.emit_noise`). Taşıyan
## ayrılırsa ya da Game yakalandığını bildirirse (`host_drop`) de düşer; düşen çanta 0,3 sn yeniden alınamaz
## (KR-026). İş bitince Game `host_lock` çağırır: host yeni alma/devir isteklerini reddeder (`blocked`). Değer (`value`) tanımdan; kaçışta
## taşıyanın ganimeti sayılır (Game okur).
## Çoğaltılan durum (host yazar, MultiplayerSynchronizer, değişince): `carrier` (0 = yerde), `floor_position`
## (Props koordinatında), `drops`. Konum her peer'da durumdan türetilir: taşınırken taşıyan düğümün üstünde.
## Görsel (`Visual`) yalnız durumu okur (KR-003). Döküm (S6 "props"): `dump_state()`.

## Yalnız host'ta: çanta alındı ya da devralındı (not: "Hamal").
signal taken(peer_id: int)
## Yalnız host'ta: çanta düştü (koşu, yakalanma, ayrılma).
signal dropped(peer_id: int)

const DEF_PATH := "res://data/props/bag.tres"
## Taşınırken taşıyan merkezine göre düğüm konumu (devir bileşeni, sis hafızası, döküm). Çizilen tutuş ayrı:
## BagVisual, taşıyanın kukla elinden BagCarry ile türetir (IS-085).
const CARRY_OFFSET := Vector2(10.0, 6.0)

@export var def: PropDef

## Çoğaltılan durum (host yazar).
var carrier: int = 0:
	set = _set_carrier
var floor_position: Vector2 = Vector2.ZERO
var drops: int = 0
## Ganimet değeri (tanımdan; GDD 300-600 tohumu gelene dek sabit).
var value: int = 0

## Host: düşürme zarı `func() -> float` (0..1); geçersizse kendi RandomNumberGenerator'ı. Testler değiştirir.
var roll_source: Callable = Callable()
## Host: gürültü çıkışı, S8 imzası `func(pos: Vector2, radius: float, kind: StringName, source_peer: int)`;
## geçersizse NoiseBus. Testler değiştirir.
var noise_sink: Callable = Callable()

var _run_s: float = 0.0
var _takes: int = 0
## Host: iş bitti (yeni alma/devir reddedilir) ve düşmeden sonra kalan yeniden alma kilidi (sn).
var _locked: bool = false
var _retake_left: float = 0.0
## Bu peer'da görülen taşıyanlar (çoğaltılan `carrier`'dan; yalnız döküm/teşhis).
var _seen_carriers: Array[int] = []
var _rng := RandomNumberGenerator.new()

@onready var _take: Interactable = $Take
@onready var _handoff: Interactable = $Handoff


func _ready() -> void:
	if def == null:
		push_error("Bag: def atanmamış; %s yükleniyor" % DEF_PATH)
		def = load(DEF_PATH) as PropDef
	add_to_group(HeistRules.BAG_GROUP)
	value = def.cash_value
	floor_position = position
	_take.action_key = def.action_key
	_take.hold_time = def.hold_time
	_take.interact_range = def.interact_range
	_take.requirement = def.requirement
	_handoff.action_key = def.alt_action_key if not def.alt_action_key.is_empty() else def.action_key
	_handoff.hold_time = HeistRules.HANDOFF_HOLD_TIME
	_handoff.interact_range = def.interact_range
	_handoff.requirement = def.requirement
	_take.completed.connect(_on_take_completed)
	_handoff.completed.connect(_on_handoff_completed)
	_take.start_blocker = _take_blocked
	_handoff.start_blocker = _handoff_blocked
	_rng.randomize()
	_apply()
	add_to_group(PropDump.GROUP)
	PropDump.register()


## `peer_id`'nin taşıdığı çanta (her peer'da, çoğaltılan durumdan); yoksa null.
static func carried_by(tree: SceneTree, peer_id: int) -> Bag:
	if tree == null or peer_id <= 0:
		return null
	for node: Node in tree.get_nodes_in_group(HeistRules.BAG_GROUP):
		var bag: Bag = node as Bag
		if bag != null and bag.carrier == peer_id:
			return bag
	return null


func is_carried() -> bool:
	return carrier != 0


## 0..1 alma/devir ilerlemesi (görsel).
func progress_ratio() -> float:
	return maxf(_take.progress_ratio(), _handoff.progress_ratio())


func _physics_process(delta: float) -> void:
	step(delta)


## Bir zaman adımı (fizik adımı çağırır; testler de aynı yolu kullanır): konum durumdan izlenir; host'ta taşıyan
## koştuysa geçilen her tam saniyede düşürme zarı atılır, taşıyan yoksa (ayrıldı) çanta düşer.
func step(delta: float) -> void:
	_follow()
	_retake_left = maxf(_retake_left - delta, 0.0)
	if carrier == 0 or not multiplayer.is_server():
		return
	var actor: Node = _carrier_node()
	if actor == null:
		host_drop()
		return
	if HeistRules.node_flag(actor, HeistRules.SPRINT_METHODS):
		var before: float = _run_s
		_run_s += delta
		for i: int in HeistRules.rolls_due(before, _run_s):
			if HeistRules.drops(_roll()):
				host_drop()
				return


func _process(_delta: float) -> void:
	_follow()


## Yalnız host'ta (değilse yok sayılır): çanta taşıyanın son bilinen konumunda yere düşer ve gürültü yayar.
func host_drop() -> void:
	if carrier == 0 or not multiplayer.is_server():
		return
	var peer: int = carrier
	var actor: Node = _carrier_node()
	var at: Vector2 = global_position
	if actor != null and actor.has_method(&"interaction_position"):
		at = actor.call(&"interaction_position")
	var parent: Node2D = get_parent() as Node2D
	floor_position = parent.to_local(at) if parent != null else at
	drops += 1
	_run_s = 0.0
	_retake_left = HeistRules.BAG_RETAKE_DELAY
	carrier = 0
	_emit_noise(at, peer)
	dropped.emit(peer)


## Yalnız host'ta: iş bitti; yeni alma/devir istekleri reddedilir.
func host_lock() -> void:
	if multiplayer.is_server():
		_locked = true


func dump_state() -> Dictionary:
	return {
		"carrier": carrier,
		"seen_carriers": _seen_carriers,
		"drops": drops,
		"takes": _takes,
		"value": value,
		"pos": global_position,
		"take": _take.stats(),
		"handoff": _handoff.stats(),
	}


# --- host ---

func _on_take_completed(peer_id: int) -> void:
	if carrier == 0:
		_give(peer_id)


func _on_handoff_completed(peer_id: int) -> void:
	if carrier != 0 and carrier != peer_id:
		_give(peer_id)


func _take_blocked() -> bool:
	return _locked or _retake_left > 0.0


func _handoff_blocked() -> bool:
	return _locked


func _give(peer_id: int) -> void:
	if _locked or peer_id <= 0 or carried_by(get_tree(), peer_id) != null:
		return  # eli dolu (başka çanta)
	_run_s = 0.0
	_takes += 1
	carrier = peer_id
	taken.emit(peer_id)


func _roll() -> float:
	if roll_source.is_valid():
		return float(roll_source.call())
	return _rng.randf()


func _emit_noise(at: Vector2, peer: int) -> void:
	if noise_sink.is_valid():
		noise_sink.call(at, HeistRules.BAG_DROP_NOISE_RADIUS, HeistRules.BAG_DROP_NOISE_KIND, peer)
	else:
		NoiseBus.emit_noise(at, HeistRules.BAG_DROP_NOISE_RADIUS, HeistRules.BAG_DROP_NOISE_KIND, peer)


## Taşıyan oyuncu düğümü (her peer'da çoğaltılan `carrier`'dan); yoksa null. Görsel okur.
func carrier_node() -> Node2D:
	return _carrier_node()


# --- durum ---

## Taşıyan oyuncu düğümü (S7 aktörü: yetkisi taşıyanda); yoksa null.
func _carrier_node() -> Node2D:
	if carrier == 0 or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Interactable.ACTOR_GROUP):
		if node.get_multiplayer_authority() == carrier and node is Node2D:
			return node as Node2D
	return null


## Konum durumdan: taşınırken taşıyanın üstünde, yerdeyse floor_position.
func _follow() -> void:
	var actor: Node2D = _carrier_node()
	if actor != null:
		global_position = actor.global_position + CARRY_OFFSET
	elif position != floor_position:
		position = floor_position


func _set_carrier(new_carrier: int) -> void:
	if new_carrier == carrier:
		return
	carrier = new_carrier
	if new_carrier != 0 and not _seen_carriers.has(new_carrier):
		_seen_carriers.append(new_carrier)
	_apply()


func _apply() -> void:
	if _take != null:
		_take.enabled = carrier == 0
	if _handoff != null:
		_handoff.enabled = carrier != 0
	if is_inside_tree():
		_follow()
