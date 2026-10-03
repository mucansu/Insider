class_name NoiseRing
extends Node2D
## Noise ring visual (US-009 AC5; S8, S9; GDD §14.1 rule 2): NoiseBus adds one under the level on every peer per ring event.
## Grows from MIN_RADIUS to the sound radius in DURATION s while fading, then frees itself. Colour: tone foreground (KR-019).
## Under `reduced_motion` there is no growth: full radius from the start, fade only. Carries no game rules.
## Draw condition (US-011b AC6; GDD §6.5): with local fog, draw only if the source tile is seen or the local player hears it
## (same rule as Hearing: distance <= radius, radius x `NoiseProfile.wall_factor` without line of sight; VisionRules.ring_shown).
## Heard rings draw above fog. No fog: every ring draws. `NoiseBus.noise_shown` contract unchanged (only the visual is hidden).

const DURATION := 0.4
## 22 px diameter (GDD §14.1 rule 2: game markers >= 22 px).
const MIN_RADIUS := 11.0
const LINE_WIDTH := 3.0
## Lowest opacity at the end (readable until gone).
const END_ALPHA := 0.3
const SEGMENTS := 48
const Z_INDEX := 20

## Reduced-motion setting (player option; assigned from UI/puppet flag once wired).
static var reduced_motion: bool = false

var radius: float = 0.0
var _age: float = 0.0
var _shown: bool = true


func _ready() -> void:
	z_index = Z_INDEX


## Sound radius (px). The draw condition is evaluated once here (position set, in tree).
func setup(noise_radius: float) -> void:
	radius = noise_radius
	_shown = true
	var fog: Object = FogView.fog_of(self) if is_inside_tree() else null
	if fog != null:
		var ear: Vector2 = FogView.observer_of(fog).global_position
		var seen: bool = FogView.is_tile_seen(fog, global_position)
		var distance: float = ear.distance_to(global_position)
		var los: bool = true
		if not seen and NoiseRules.can_hear(distance, radius):
			# Same as Hearing: one ray ear->source; the source's own body (SOURCE_MARGIN) does not block.
			var hit: Dictionary = SightLine.first_blocker(get_world_2d().direct_space_state, ear, global_position)
			los = hit.is_empty() or not NoiseRules.hit_blocks(hit["position"] as Vector2, global_position)
		_shown = VisionRules.ring_shown(seen, distance, radius, los, NoiseProfile.load_default().wall_factor)
		if _shown:
			z_index = VisionRules.ABOVE_FOG_Z
	visible = _shown
	queue_redraw()


## Whether drawn on this peer (US-011b AC6).
func is_shown() -> bool:
	return _shown


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func age() -> float:
	return _age


func current_radius() -> float:
	return ring_radius(_age, radius, reduced_motion)


## Draw radius at `age` s: MIN_RADIUS -> max(radius, MIN_RADIUS), decelerating; constant under reduced motion.
static func ring_radius(at_age: float, noise_radius: float, reduced: bool) -> float:
	var full: float = maxf(noise_radius, MIN_RADIUS)
	if reduced:
		return full
	var t: float = clampf(at_age / DURATION, 0.0, 1.0)
	return lerpf(MIN_RADIUS, full, 1.0 - (1.0 - t) * (1.0 - t))


static func ring_alpha(at_age: float) -> float:
	return lerpf(1.0, END_ALPHA, clampf(at_age / DURATION, 0.0, 1.0))


func _draw() -> void:
	var color: Color = ThemeTokens.tone().fg_color
	color.a *= ring_alpha(_age)
	draw_arc(Vector2.ZERO, current_radius(), 0.0, TAU, SEGMENTS, color, LINE_WIDTH, true)
