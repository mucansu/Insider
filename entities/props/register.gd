class_name Register
extends Node2D
## Cash register (US-005 AC2; S7, S10): `data/props/register.tres`. Hold (3 s) -> host adds `cash_value` to team cash, the register
## becomes empty and is not interactable again. Can only be emptied from behind the counter (staff side; the definition's
## InteractionRequirement side constraint). Releasing early resets progress (Interactable). State (`emptied`, `emptied_at` host wall clock)
## replicates via host-authoritative MultiplayerSynchronizer on change; the visual (`Visual`) only reads state (KR-003).
## Dump (S6 "props"): {"emptied", "visible_delay_ms" (host decision to visible in this process; -1 if not emptied), "interact": Interactable.stats()}.
## Noise (US-009, S8): while emptying, the host emits `NoiseProfile.KIND_REGISTER` every `register_interval` s (first one also after that long;
## suppressed when under half an interval remains before the end: NoiseRules.work_tick_allowed) and on completion at the register
## position (full 3 s emptying: sec 1 and 2 + finish = 3 sounds).

const DEF_PATH := "res://data/props/register.tres"

@export var def: PropDef

## Replicated state (host writes).
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
	SfxEmitter.of(self).repeat_while(&"register_tick", func() -> bool:  # IS-024: tick while emptying
		return not emptied and progress_ratio() > 0.0)
	_apply()
	add_to_group(PropDump.GROUP)
	PropDump.register()


## Host: low-tempo sound while emptying (S8).
func _physics_process(delta: float) -> void:
	var working: bool = multiplayer.is_server() and not emptied and _interactable.busy_by != 0
	if _work_noise.tick(delta, working) and NoiseRules.work_tick_allowed(_interactable.progress,
			_interactable.hold_time, _noise_profile.register_interval):
		_emit_noise(_interactable.busy_by)


## 0..1 emptying progress (visual).
func progress_ratio() -> float:
	return _interactable.progress_ratio()


func dump_state() -> Dictionary:
	return {
		"emptied": emptied,
		"visible_delay_ms": (_seen_at - emptied_at) * 1000.0 if emptied and _seen_at >= 0.0 else -1.0,
		"interact": _interactable.stats(),
		"sfx": SfxEmitter.of(self).stats(),
	}


## Host only (Interactable.completed).
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
		SfxEmitter.play_on_change(self, &"register_done")  # IS-024: "ding", local sound
	_apply()


func _apply() -> void:
	if _interactable != null:
		_interactable.enabled = not emptied
