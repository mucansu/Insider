class_name FootstepEmitter
extends SfxEmitter
## Cosmetic footsteps of one character (US-047 AC2): child `Footsteps` of the player scene, on every copy. Each frame it reads the owner's
## movement mode and speed (local copy: real velocity after `move_and_slide`; remote copy: the interpolated `velocity`/`move_mode` the
## player already derives from replicated state) and plays `walk_step` / `run_step` from the catalog on FootstepRules' cadence. Sneaking and
## standing are silent. Local sound only: nothing goes to NoiseBus or the network (no new RPC/field; PROTOCOL_VERSION unchanged).
## Owner contract (duck typed): `move_mode: int` (PlayerMotion.Mode) and `velocity: Vector2`; optional `is_local()`.

var _cadence := FootstepRules.Cadence.new()


func _ready() -> void:
	super._ready()
	set_process(true)


func _process(delta: float) -> void:
	var holder: Node = get_parent()
	if holder == null:
		return
	var event: StringName = _cadence.tick(delta, gait_of(holder))
	if not event.is_empty():
		play_event(event)


## Gait of `holder` this frame (STILL if it does not expose the movement contract).
static func gait_of(holder: Node) -> FootstepRules.Gait:
	if not (&"move_mode" in holder) or not (&"velocity" in holder):
		return FootstepRules.Gait.STILL
	var mode: int = int(holder.get(&"move_mode"))
	var vel: Vector2 = holder.get(&"velocity")
	var body: CharacterBody2D = holder as CharacterBody2D
	if body != null and holder.has_method(&"is_local") and bool(holder.call(&"is_local")):
		vel = body.get_real_velocity()  # local: pushing a wall is not walking
	return FootstepRules.gait_for(mode == PlayerMotion.Mode.SNEAK, mode == PlayerMotion.Mode.SPRINT, vel.length())
