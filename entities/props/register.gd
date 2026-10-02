class_name Register
extends Node2D
## Yazar kasa (US-005 AC2; mimari.md S7, S10): `data/props/register.tres`. Basılı tut (3 sn) → host ekip
## nakdine `cash_value` ekler, kasa boş durumuna geçer ve bir daha etkileşilmez. Yalnız tezgâh arkasından
## (personel tarafı; tanımdaki InteractionRequirement taraf kısıtı) boşaltılır. Yarıda bırakılırsa ilerleme
## sıfırlanır (Interactable). Durum (`emptied`, host'un duvar saatiyle `emptied_at`) host yetkili
## MultiplayerSynchronizer ile değişince yayılır; görsel (`Visual`) yalnız durumu okur (KR-003).
## Döküm (S6 "props"): {"emptied", "visible_delay_ms" (host kararından bu süreçte görünene; boşalmadıysa -1),
## "interact": Interactable.stats()}.
## Gürültü (US-009, S8): host boşaltma sürerken `register_interval` sn'de bir (ilki de o kadar sonra; bitişe
## yarım aralıktan az kala bastırılır: NoiseRules.work_tick_allowed) ve tamamlanınca kasa konumunda
## `NoiseProfile.KIND_REGISTER` sesi yayar (3 sn tam boşaltma: 1. ve 2. sn + bitiş = 3 ses).

const DEF_PATH := "res://data/props/register.tres"

@export var def: PropDef

## Çoğaltılan durum (host yazar).
var emptied: bool = false:
	set = _set_emptied
var emptied_at: float = 0.0

var _seen_at: float = -1.0
var _noise_profile: NoiseProfile = null
var _work_noise: NoiseRules.Cadence = null

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	if def == null:
		push_error("Register: def atanmamış; %s yükleniyor" % DEF_PATH)
		def = load(DEF_PATH) as PropDef
	_interactable.action_key = def.action_key
	_interactable.hold_time = def.hold_time
	_interactable.interact_range = def.interact_range
	_interactable.requirement = def.requirement
	_interactable.completed.connect(_on_completed)
	_noise_profile = NoiseProfile.load_default()
	_work_noise = NoiseRules.Cadence.new(_noise_profile.register_interval, _noise_profile.register_interval)
	SfxEmitter.of(self).repeat_while(&"register_tick", func() -> bool:  # IS-024: boşaltılırken tik
		return not emptied and progress_ratio() > 0.0)
	_apply()
	add_to_group(PropDump.GROUP)
	PropDump.register()


## Host: boşaltma sürerken düşük tempoda ses (S8).
func _physics_process(delta: float) -> void:
	var working: bool = multiplayer.is_server() and not emptied and _interactable.busy_by != 0
	if _work_noise.tick(delta, working) and NoiseRules.work_tick_allowed(_interactable.progress,
			_interactable.hold_time, _noise_profile.register_interval):
		_emit_noise(_interactable.busy_by)


## 0..1 boşaltma ilerlemesi (görsel).
func progress_ratio() -> float:
	return _interactable.progress_ratio()


func dump_state() -> Dictionary:
	return {
		"emptied": emptied,
		"visible_delay_ms": (_seen_at - emptied_at) * 1000.0 if emptied and _seen_at >= 0.0 else -1.0,
		"interact": _interactable.stats(),
		"sfx": SfxEmitter.of(self).stats(),
	}


## Yalnız host'ta (Interactable.completed).
func _on_completed(peer_id: int) -> void:
	if emptied:
		return
	emptied_at = PropDump.wall_time()
	emptied = true
	Game.add_team_cash(def.cash_value)
	_emit_noise(peer_id)


func _emit_noise(source_peer: int) -> void:
	var kind: StringName = NoiseProfile.KIND_REGISTER
	NoiseBus.emit_noise(global_position, _noise_profile.radius_for(kind), kind, source_peer)


func _set_emptied(value: bool) -> void:
	if value == emptied:
		return
	emptied = value
	if value:
		_seen_at = PropDump.wall_time()
		SfxEmitter.play_on_change(self, &"register_done")  # IS-024: "çın", yerel ses
	_apply()


func _apply() -> void:
	if _interactable != null:
		_interactable.enabled = not emptied
