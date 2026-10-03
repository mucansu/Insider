class_name TaskGlyph
extends Node2D
## Owner task glyph (IS-096 AC2; KR-031, GDD §9.3 "Sahip okunurluğu"): a small drawn badge above the owner's shoulder showing what the
## owner is busy with - counter / shelf / phone / back room / listening / discovery - so a player reads the attention loop at a glance.
## Visual only (KR-003): derived on every peer from the owner's existing replicated fields `net_state` (OwnerBrain.State) and `net_task`
## (agenda task or interrupt name; reliable on change) - no new network field or RPC. Polled every frame, so it follows a task change
## within one frame of the replicated value arriving. Drawn only while the owner's NpcVisual is FULL on this peer (parent
## `is_fully_visible()`, duck typing); never on a silhouette or ghost. Simple geometry (draw_*), no text; colours from the tone (S9).
## Attached as a child of the owner's `Visual` node (follows its lean offset and z) by `TaskGlyph.attach`.

enum Glyph { NONE, COUNTER, SHELF, PHONE, BACKROOM, LISTEN, DISCOVER }

const NODE_NAME := &"TaskGlyph"
## Badge centre relative to the body centre (px; upper right, clear of the body, look triangle and the "?"/"!" indicator above).
const BADGE_OFFSET := Vector2(18.0, -20.0)
const BADGE_RADIUS := 8.0
const BADGE_OUTLINE := 1.0
## Glyph line width (px) and half extent of the glyph box (px).
const LINE := 1.5
const HALF := 5.0
const ARC_POINTS := 10
## Agenda task / interrupt name -> glyph (agenda tasks: data/npc/owner_tuning.tres; interrupts: Agenda.INTERRUPT_NAMES).
## Not listed (bell, talk, ""): no glyph - the owner is looking at the door or the talking player, which the cone already shows.
const TASK_GLYPHS := {
	&"counter": Glyph.COUNTER,
	&"customer": Glyph.COUNTER,
	&"restock": Glyph.SHELF,
	&"phone": Glyph.PHONE,
	&"backroom": Glyph.BACKROOM,
	&"sent": Glyph.BACKROOM,
	&"listen": Glyph.LISTEN,
}

## The owner whose replicated fields are read (duck typing `net_state`, `net_task`); default: the parent's parent.
var subject: Node = null

var _drawn: Glyph = Glyph.NONE


## Adds the glyph under `visual` (the owner's NpcVisual) once; returns it.
static func attach(visual: Node2D, owner_node: Node = null) -> TaskGlyph:
	var existing: TaskGlyph = visual.get_node_or_null(NodePath(String(NODE_NAME))) as TaskGlyph
	if existing != null:
		return existing
	var glyph := TaskGlyph.new()
	glyph.name = NODE_NAME
	glyph.subject = owner_node
	visual.add_child(glyph)
	return glyph


## Glyph for an owner state and replicated task name: DISCOVER while discovering; in AGENDA the task's glyph; otherwise none (reaction
## states already draw "?"/"!").
static func glyph_for(state: int, task: StringName) -> Glyph:
	if state == OwnerBrain.State.DISCOVER:
		return Glyph.DISCOVER
	if state != OwnerBrain.State.AGENDA:
		return Glyph.NONE
	return int(TASK_GLYPHS.get(task, Glyph.NONE)) as Glyph


## Glyph currently shown on this peer (NONE while the owner is not fully visible).
func glyph() -> Glyph:
	if not _fully_visible():
		return Glyph.NONE
	var owner_node: Node = _subject()
	if owner_node == null:
		return Glyph.NONE
	var state_v: Variant = owner_node.get(&"net_state")
	var task_v: Variant = owner_node.get(&"net_task")
	if not state_v is int or not task_v is StringName:
		return Glyph.NONE
	return glyph_for(int(state_v), task_v as StringName)


func _process(_delta: float) -> void:
	var now: Glyph = glyph()
	if now != _drawn:
		_drawn = now
		queue_redraw()


func _subject() -> Node:
	if subject != null:
		return subject
	var p: Node = get_parent()
	return p.get_parent() if p != null else null


func _fully_visible() -> bool:
	var p: Node = get_parent()
	if p == null:
		return false
	return not p.has_method(&"is_fully_visible") or bool(p.call(&"is_fully_visible"))


func _draw() -> void:
	if _drawn == Glyph.NONE:
		return
	var tone: Tone = ThemeTokens.tone()
	var c: Vector2 = BADGE_OFFSET
	draw_circle(c, BADGE_RADIUS, tone.bg_color)
	draw_arc(c, BADGE_RADIUS, 0.0, TAU, 20, tone.muted_color, BADGE_OUTLINE)
	var ink: Color = ThemeTokens.GAMEPLAY_ALERT if _drawn == Glyph.DISCOVER else tone.fg_color
	match _drawn:
		Glyph.COUNTER:
			_draw_counter(c, ink)
		Glyph.SHELF:
			_draw_shelf(c, ink)
		Glyph.PHONE:
			_draw_phone(c, ink)
		Glyph.BACKROOM:
			_draw_door(c, ink)
		Glyph.LISTEN:
			_draw_listen(c, ink)
		Glyph.DISCOVER:
			_draw_magnifier(c, ink)


## Counter: a slab with a register box on it.
func _draw_counter(c: Vector2, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-HALF, HALF * 0.2), Vector2(HALF * 2.0, HALF * 0.6)), ink)
	draw_rect(Rect2(c + Vector2(-HALF * 0.3, -HALF * 0.7), Vector2(HALF * 0.9, HALF * 0.8)), ink)


## Shelf: a frame with two boards.
func _draw_shelf(c: Vector2, ink: Color) -> void:
	var box := Rect2(c + Vector2(-HALF * 0.8, -HALF), Vector2(HALF * 1.6, HALF * 2.0))
	draw_rect(box, ink, false, LINE)
	for y: float in [-HALF / 3.0, HALF / 3.0]:
		draw_line(c + Vector2(-HALF * 0.8, y), c + Vector2(HALF * 0.8, y), ink, LINE)


## Phone: a handset arc with two ear pieces.
func _draw_phone(c: Vector2, ink: Color) -> void:
	var r: float = HALF * 0.75
	var base: Vector2 = c + Vector2(0.0, HALF * 0.35)
	draw_arc(base, r, PI, TAU, ARC_POINTS, ink, LINE * 1.4)
	draw_circle(base + Vector2(-r, 0.0), HALF * 0.38, ink)
	draw_circle(base + Vector2(r, 0.0), HALF * 0.38, ink)


## Back room: a door outline with a knob.
func _draw_door(c: Vector2, ink: Color) -> void:
	draw_rect(Rect2(c + Vector2(-HALF * 0.65, -HALF), Vector2(HALF * 1.3, HALF * 2.0)), ink, false, LINE)
	draw_circle(c + Vector2(HALF * 0.3, HALF * 0.1), LINE * 0.7, ink)


## Listening: a source dot with two sound waves.
func _draw_listen(c: Vector2, ink: Color) -> void:
	var src: Vector2 = c + Vector2(-HALF * 0.7, 0.0)
	draw_circle(src, LINE * 0.8, ink)
	for r: float in [HALF * 0.7, HALF * 1.3]:
		draw_arc(src, r, -PI / 3.0, PI / 3.0, ARC_POINTS, ink, LINE)


## Discovery: a magnifying glass (alert colour).
func _draw_magnifier(c: Vector2, ink: Color) -> void:
	var lens: Vector2 = c + Vector2(-HALF * 0.25, -HALF * 0.25)
	draw_arc(lens, HALF * 0.55, 0.0, TAU, ARC_POINTS + 4, ink, LINE)
	draw_line(lens + Vector2(HALF * 0.4, HALF * 0.4), c + Vector2(HALF * 0.85, HALF * 0.85), ink, LINE * 1.4)
