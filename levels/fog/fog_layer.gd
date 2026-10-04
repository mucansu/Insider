class_name FogLayer
extends Node2D
## Vision fog layer (US-011a AC1/AC2/AC9; GDD §6.5, §14; KR-022/KR-023). Built on the client only, for the local player only (`Level.attach_fog(player)`; wiring from Game in US-011b); the host makes no visibility decision.
## Child of the level root at (0, 0): grid coordinate = level coordinate (1 tile = 32 px).
##
## - Logic: `VisionGrid` (core), updated every `update_interval_sec` (physics step) from the observer's position and facing; line of sight is `line_clear` (same rule as NPC perception).
## - Drawing: `Shade` = one level-sized quad + `fog_layer.gdshader` (one texel per tile: R unknown, G memory, B ambient weight, A dark scan; tone and saturation from ThemeTokens.GAMEPLAY_FOG_*). Unknown is an opaque flat tone (no content leaks).
##   `Outline` = sketch above the fog (wall edges + dashed door thresholds): geometry computed and drawn once; `fog_outline.gdshader` masks it per tile from the same data textures (visible only on unknown and memory tiles).
## - Transition in the shader: two data textures (`prev`, `next`) + `blend_t` (0 -> 1, `transition_sec`). The CPU writes only when the grid changes and uploads two small textures; per frame only the `blend_t` uniform advances (no tile loop).
##   A new change mid-transition pins the running tiles' current blend to `prev` (one-off mix for tiles in transition only) and restarts `blend_t` at 0: no visual jump, unchanged tiles do not wait. Reduced motion: `blend_t` is instantly 1.
## - Order: `z_index = Z_INDEX` (50); below level content (floor, props, NPCs) and future light pools (`LIGHT_POOLS_Z_MAX`). Things that must draw above the fog (teammate, edge arrow; US-011b/US-011c) use a larger z_index.

## Tile state changed (relay of VisionGrid.changed; tiles in grid coordinates).
signal vision_changed(cells: Array[Vector2i])

const Z_INDEX := 50
## Future light pools (dark zone, KR-019) stay below the fog: z_index <= this value.
const LIGHT_POOLS_Z_MAX := Z_INDEX - 1
const SHADER := preload("res://levels/fog/fog_layer.gdshader")
const OUTLINE_SHADER := preload("res://levels/fog/fog_outline.gdshader")
## Line-of-sight rule (mimari.md §4, S11; same as US-006): world (1) + vision_block (6) block; bodies in the `see_through` group (glass) let it pass.
## A shared core helper arrives in US-011b; until then `line_clear` is the single source (identical to perception.gd `has_line_of_sight`).
const SIGHT_MASK := PhysicsLayers.SIGHT_MASK
const SEE_THROUGH_GROUP := PhysicsLayers.SEE_THROUGH_GROUP
const MAX_SEE_THROUGH := 8
## Door-threshold line: dashed, thin (sketch marker; door state is unknown).
const DOOR_GAP_WIDTH := 2.0
const DOOR_GAP_DASH := 4.0

@export var tuning: VisionTuning
## Reduced motion (GDD §14.1 rule 5): instant tone transition. Wired in US-011c (setting) / US-011b.
var reduce_motion: bool = false
## Facing direction (unit; cone direction in directional mode). Input comes from US-011b.
var look_dir: Vector2 = Vector2.RIGHT
## Line of sight: func(from: Vector2, to: Vector2) -> bool, in grid (level) coordinates. Physics query if empty.
var sight: Callable = Callable()

var _grid := VisionGrid.new()
var _observer: Node2D = null
var _shade: Node2D = null
var _outline: Node2D = null
var _prev_img: Image = null
var _next_img: Image = null
var _prev_tex: ImageTexture = null
var _next_tex: ImageTexture = null
var _material: ShaderMaterial = null
var _outline_material: ShaderMaterial = null
var _outline_rects: Array[Rect2] = []
var _outline_gaps := PackedVector2Array()
var _dark := PackedByteArray()
## Transition progress (0 -> 1); at 1 the `prev` image is meaningless (shown = `next`).
var _blend_t: float = 1.0
## Tiles where `prev` and `next` may differ (last unfinished transitions); the flag array prevents repeats.
var _moving := PackedInt32Array()
var _in_moving := PackedByteArray()
var _query := PhysicsRayQueryParameters2D.new()
var _exclude: Array[RID] = []
var _space: PhysicsDirectSpaceState2D = null
var _since_update: float = 0.0
var _updates: int = 0
var _update_usec_total: int = 0
var _rays_max: int = 0


func _init() -> void:
	z_index = Z_INDEX
	_grid.changed.connect(_on_grid_changed)
	_query.collision_mask = SIGHT_MASK
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	_query.hit_from_inside = false


func _ready() -> void:
	if tuning == null:
		tuning = load(VisionTuning.PATH) as VisionTuning
	_grid.params = params_for(tuning, tuning.default_mode)
	_shade = Node2D.new()
	_shade.name = "Shade"
	_shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_shade.material = _material
	_shade.draw.connect(_draw_shade)
	add_child(_shade)
	_outline = Node2D.new()
	_outline.name = "Outline"
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline.material = _outline_material
	_outline.draw.connect(_draw_outline)
	add_child(_outline)
	_apply_theme()
	_rebuild_texture()


## Core vision values from the settings (`mode`: VisionGrid.Mode).
static func params_for(source: VisionTuning, mode: int) -> VisionGrid.Params:
	var p := VisionGrid.Params.new()
	p.mode = mode
	p.view_radius = source.view_radius
	p.dark_radius = source.dark_radius
	p.cone_half_angle_deg = source.cone_half_angle_deg
	p.peripheral_half_angle_deg = source.peripheral_half_angle_deg
	p.peripheral_radius = source.peripheral_radius
	p.near_radius = source.near_radius
	p.memory_enabled = source.memory_enabled
	return p


## Builds the grid from the level: obstacle grid (`Level.vision_cells`) and sketch geometry (once). Memory is reset.
func setup_from_level(level: Level) -> void:
	setup(level.vision_size(), level.vision_cells())
	_build_outline(level.layout())


## Builds the grid directly (`VisionGrid.setup`); memory is reset. The sketch is emptied (`setup_from_level` builds it).
func setup(size: Vector2i, cells: PackedByteArray, dark: PackedByteArray = PackedByteArray()) -> void:
	_grid.setup(size, cells, dark)
	var total: int = _grid.size().x * _grid.size().y
	_dark = PackedByteArray()
	_dark.resize(total)
	for y: int in _grid.size().y:
		for x: int in _grid.size().x:
			_dark[y * _grid.size().x + x] = 1 if _grid.is_dark(Vector2i(x, y)) else 0
	_blend_t = 1.0
	_moving = PackedInt32Array()
	_in_moving = PackedByteArray()
	_in_moving.resize(total)
	_outline_rects = []
	_outline_gaps = PackedVector2Array()
	if is_node_ready():
		_rebuild_texture()


## Starts tracking the observer (local player) and updates at once. null stops tracking (grid freezes).
func follow(observer: Node2D) -> void:
	_observer = observer
	_since_update = 0.0
	if _observer != null and is_inside_tree():
		update_now()


func observer() -> Node2D:
	return _observer


## Facing direction (global; zero is ignored). Takes effect on the next update.
func set_look_dir(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		look_dir = direction.normalized()


## Vision mode (`VisionGrid.Mode`); takes effect on the next update.
func set_mode(mode: int) -> void:
	_grid.params.mode = mode


func mode() -> int:
	return _grid.params.mode


func grid() -> VisionGrid:
	return _grid


## Tile state (`VisionGrid.State`; grid/level tile coordinate).
func state_at(cell: Vector2i) -> int:
	return _grid.state_at(cell)


## Tile state of a global point.
func state_at_position(global_pos: Vector2) -> int:
	return _grid.state_at_position(to_local(global_pos))


## Whether a global point is on a visible tile (state 2). (`_at` avoids confusion with CanvasItem.is_visible.)
func is_visible_at(global_pos: Vector2) -> bool:
	return _grid.is_visible(to_local(global_pos))


## Whether a global point is on an ambient tile (state 3).
func is_peripheral_at(global_pos: Vector2) -> bool:
	return _grid.is_peripheral(to_local(global_pos))


## Line of sight (global endpoints): world + vision_block block; **bodies** in the `see_through` or `low_obstacle` group
## (PhysicsLayers.passes_sight: glass, counter - IS-098) are excluded and the ray is recast from the start
## (no continuation point is computed, so an adjacent wall cannot be skipped). The group applies at body level only; player and NPC bodies are not in the mask.
## Same rule as perception.gd `has_line_of_sight`.
func line_clear(from: Vector2, to: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState2D = _space if _space != null else get_world_2d().direct_space_state
	_exclude.clear()
	_query.from = from
	_query.to = to
	_query.exclude = _exclude
	for _i: int in MAX_SEE_THROUGH + 1:
		var hit: Dictionary = space.intersect_ray(_query)
		if hit.is_empty():
			return true
		var collider: Node = hit.get("collider") as Node
		if collider != null and PhysicsLayers.passes_sight(collider.get_groups()):
			_exclude.append(hit["rid"] as RID)
			_query.exclude = _exclude
			continue
		return false
	return false


## Whether the observer sees the point: tile visible and line of sight from the observer to the point (NPC visibility gate, US-011b).
func can_see(global_pos: Vector2) -> bool:
	if _observer == null or not is_visible_at(global_pos):
		return false
	return line_clear(_observer.global_position, global_pos)


## Clears memory (phase change; loading a level already builds a new layer).
func reset_memory() -> void:
	_grid.reset()


## Updates the grid now (also resets the timer).
func update_now() -> void:
	if _observer == null or not is_inside_tree():
		return
	_since_update = 0.0
	var origin: Vector2 = to_local(_observer.global_position)
	var started: int = Time.get_ticks_usec()
	_space = get_world_2d().direct_space_state
	_grid.update(origin, look_dir, sight if sight.is_valid() else _physics_sight)
	_space = null
	_update_usec_total += Time.get_ticks_usec() - started
	_updates += 1
	_rays_max = maxi(_rays_max, _grid.last_ray_count)


## Dump/measurement summary (the US-011b `"vision"` dump extends it).
func stats() -> Dictionary:
	return {
		"mode": String(VisionGrid.mode_name(_grid.params.mode)),
		"visible_tiles": _grid.count(VisionGrid.State.VISIBLE),
		"peripheral_tiles": _grid.count(VisionGrid.State.PERIPHERAL),
		"memory_tiles": _grid.count(VisionGrid.State.MEMORY),
		"rays_per_update": _grid.last_ray_count,
		"rays_max": _rays_max,
		"updates": _updates,
		"update_ms_avg": (_update_usec_total / 1000.0) / _updates if _updates > 0 else 0.0,
	}


## Drawn tone weights of a tile (unknown, memory, ambient); an intermediate value during a transition.
## The value the shader sees: mix(prev, next, blend_t) (at 8-bit texture precision).
func shown_weights(cell: Vector2i) -> Vector3:
	if not _grid.has_cell(cell) or _next_img == null:
		return Vector3(1, 0, 0)
	var shown: Color = _next_img.get_pixelv(cell)
	if _blend_t < 1.0:
		shown = _prev_img.get_pixelv(cell).lerp(shown, _blend_t)
	return Vector3(shown.r, shown.g, shown.b)


## Transition progress (shader `blend_t`).
func blend_t() -> float:
	return _blend_t


## Sketch-line visibility on a tile (same formula as fog_outline.gdshader: unknown + memory weight).
func outline_alpha(cell: Vector2i) -> float:
	var w: Vector3 = shown_weights(cell)
	return clampf(w.x + w.y, 0.0, 1.0)


## Cached sketch geometry: wall-edge strips and door-threshold endpoint pairs (level coordinates).
func outline_rects() -> Array[Rect2]:
	return _outline_rects


func outline_gaps() -> PackedVector2Array:
	return _outline_gaps


func is_animating() -> bool:
	return _blend_t < 1.0


func _physics_process(delta: float) -> void:
	if _observer == null:
		return
	if not is_instance_valid(_observer):
		_observer = null
		return
	_since_update += delta
	if _since_update + 0.000001 >= tuning.update_interval_sec:
		update_now()


func _process(delta: float) -> void:
	if _material != null and _observer != null and is_instance_valid(_observer):
		_material.set_shader_parameter(&"view_origin", to_local(_observer.global_position))
		_material.set_shader_parameter(&"view_radius", _view_radius())
	if _blend_t >= 1.0:
		return
	var duration: float = tuning.transition_sec
	_set_blend(1.0 if reduce_motion or duration <= 0.0 else minf(_blend_t + delta / duration, 1.0))


func _physics_sight(from: Vector2, to: Vector2) -> bool:
	return line_clear(to_global(from), to_global(to))


func _view_radius() -> float:
	var origin_cell: Vector2i = VisionGrid.cell_of(to_local(_observer.global_position))
	if _grid.is_dark(origin_cell):
		return minf(tuning.view_radius, tuning.dark_radius)
	return tuning.view_radius


## Grid change -> data textures. 1) Close the running transition: transitioning tiles' `prev` is pinned to the current blend (or `next` if finished).
## 2) The changed tiles' target is written to `next`. 3) blend_t = 0 (1 under reduced motion) and the two textures are uploaded once.
## Loops cover only tiles in transition and changed tiles.
func _on_grid_changed(cells: Array[Vector2i]) -> void:
	if _next_img != null:
		var instant: bool = reduce_motion or tuning == null or tuning.transition_sec <= 0.0
		var width: int = _grid.size().x
		var settle: float = 1.0 if instant else _blend_t
		var kept: int = 0
		for k: int in _moving.size():
			var cell_index: int = _moving[k]
			var at := Vector2i(cell_index % width, _row_of(cell_index, width))
			var goal: Color = _next_img.get_pixelv(at)
			var now: Color = goal if settle >= 1.0 else _prev_img.get_pixelv(at).lerp(goal, settle)
			_prev_img.set_pixelv(at, now)
			if _prev_img.get_pixelv(at) == goal:
				_in_moving[cell_index] = 0  # reached the target at 8 bit: no longer in transition
			else:
				_moving[kept] = cell_index
				kept += 1
		_moving.resize(kept)
		for cell: Vector2i in cells:
			var target: Color = _target_color(cell)
			_next_img.set_pixelv(cell, target)
			if instant:
				_prev_img.set_pixelv(cell, target)
				continue
			var cell_index: int = cell.y * width + cell.x
			if _in_moving[cell_index] == 0:
				_in_moving[cell_index] = 1
				_moving.append(cell_index)
		_prev_tex.update(_prev_img)
		_next_tex.update(_next_img)
		_set_blend(1.0 if instant else 0.0)
	vision_changed.emit(cells)


func _apply_theme() -> void:
	_material.set_shader_parameter(&"unknown_color", ThemeTokens.GAMEPLAY_FOG_UNKNOWN)
	_material.set_shader_parameter(&"memory_color", ThemeTokens.GAMEPLAY_FOG_MEMORY)
	_material.set_shader_parameter(&"peripheral_color", ThemeTokens.GAMEPLAY_FOG_PERIPHERAL)
	_material.set_shader_parameter(&"hatch_color", ThemeTokens.GAMEPLAY_FOG_DARK_HATCH)
	_material.set_shader_parameter(&"unknown_saturation", ThemeTokens.GAMEPLAY_FOG_UNKNOWN_SATURATION)
	_material.set_shader_parameter(&"memory_saturation", ThemeTokens.GAMEPLAY_FOG_MEMORY_SATURATION)
	_material.set_shader_parameter(&"peripheral_saturation", ThemeTokens.GAMEPLAY_FOG_PERIPHERAL_SATURATION)
	_material.set_shader_parameter(&"tile_px", float(VisionGrid.TILE))
	_material.set_shader_parameter(&"edge_px", tuning.edge_blur_px)
	_material.set_shader_parameter(&"soft_edge_px", tuning.soft_edge_px)
	_material.set_shader_parameter(&"view_radius", tuning.view_radius)
	_outline_material.set_shader_parameter(&"tile_px", float(VisionGrid.TILE))


func _rebuild_texture() -> void:
	var size: Vector2i = _grid.size()
	if size.x <= 0 or size.y <= 0:
		_prev_img = null
		_next_img = null
		_prev_tex = null
		_next_tex = null
	else:
		_next_img = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		for y: int in size.y:
			for x: int in size.x:
				_next_img.set_pixel(x, y, _target_color(Vector2i(x, y)))
		_prev_img = _next_img.duplicate() as Image
		_prev_tex = ImageTexture.create_from_image(_prev_img)
		_next_tex = ImageTexture.create_from_image(_next_img)
		for mat: ShaderMaterial in [_material, _outline_material]:
			mat.set_shader_parameter(&"grid_size", Vector2(size))
			mat.set_shader_parameter(&"prev_data", _prev_tex)
			mat.set_shader_parameter(&"next_data", _next_tex)
	_set_blend(1.0)
	_shade.queue_redraw()
	_outline.queue_redraw()


func _set_blend(value: float) -> void:
	_blend_t = value
	if _material != null:
		_material.set_shader_parameter(&"blend_t", value)
		_outline_material.set_shader_parameter(&"blend_t", value)


## Target data value of a tile (data texture, not colour): R unknown, G memory, B ambient weight (0/1); A dark scan
## (dark tile and not unknown).
func _target_color(cell: Vector2i) -> Color:
	var state: int = _grid.state_at(cell)
	var data := Color()
	data.r = 1.0 if state == VisionGrid.State.UNKNOWN else 0.0
	data.g = 1.0 if state == VisionGrid.State.MEMORY else 0.0
	data.b = 1.0 if state == VisionGrid.State.PERIPHERAL else 0.0
	data.a = 1.0 if state != VisionGrid.State.UNKNOWN and _dark[cell.y * _grid.size().x + cell.x] != 0 else 0.0
	return data


static func _row_of(cell_index: int, width: int) -> int:
	@warning_ignore("integer_division")
	return cell_index / width


## Sketch geometry (once): edge strips of wall/glass tiles and threshold lines of door gaps.
func _build_outline(layout: LevelLayout) -> void:
	_outline_rects = []
	_outline_gaps = PackedVector2Array()
	if layout != null:
		var size: Vector2i = _grid.size()
		for y: int in size.y:
			for x: int in size.x:
				_outline_rects.append_array(layout.wall_edge_rects(Vector2i(x, y)))
				_outline_gaps.append_array(layout.door_gap_segment(Vector2i(x, y)))
	if _outline != null:
		_outline.queue_redraw()


## Single quad; the texture is read in the shader from the `next_data`/`prev_data` uniforms (TEXTURE carries only UV).
func _draw_shade() -> void:
	if _next_tex == null:
		return
	_shade.draw_texture_rect(_next_tex, Rect2(Vector2.ZERO, Vector2(_grid.size() * VisionGrid.TILE)), false)


## Sketch: from the cache, once (strips first, then dashed thresholds); tile mask in the shader.
func _draw_outline() -> void:
	var color: Color = ThemeTokens.tone().level_wall_edge_color
	for edge: Rect2 in _outline_rects:
		_outline.draw_rect(edge, color)
	for k: int in range(0, _outline_gaps.size() - 1, 2):
		_outline.draw_dashed_line(_outline_gaps[k], _outline_gaps[k + 1], color, DOOR_GAP_WIDTH, DOOR_GAP_DASH)
