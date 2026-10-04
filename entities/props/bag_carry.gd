class_name BagCarry
extends RefCounted
## Visual grip of the carried bag (IS-085; GDD §14.1, KR-017 smooth movement): node-free computation (KR-003).
## Input = carrier's puppet state (body facing, both hands relative to carrier, back turned, velocity); output = grip point (`grip`,
## px), pendulum angle (`angle`, rad) and draw layer (`front`). No logic/network/bag rules: each peer derives it from the puppet it sees.
## - Side: bag in the near hand (right hand facing right, left facing left); near-vertical facing keeps the last side (no jitter).
##   Grip sits slightly above the hand (hip height, not foot height).
## - Smooth transition: grip approaches target exponentially (~0.15 s side swap); teleport/new carrier snaps instantly.
## - Sway: damped pendulum driven by puppet hand swing and carrier horizontal speed; decays at rest. Under reduced motion there is
##   no sway (angle 0) and the hand is read from the swing-free rest pose (caller passes `rest` hands).

## Side flips when the horizontal facing component passes this threshold; below it the last side is kept.
const SIDE_THRESHOLD := 0.35
## Grip point this far above the hand (px).
const GRIP_LIFT := 3.0
## Exponential approach rate of the grip to its target (1/s).
const FOLLOW_RATE := 18.0
## Pendulum target angle (rad) = puppet hand horizontal speed x SWING_GAIN + carrier horizontal speed x DRAG_GAIN
## (rad / (px/s)), capped at SWAY_MAX: walk swing gives a small sway, walking drags the bag slightly behind.
const SWING_GAIN := 0.004
const DRAG_GAIN := 0.0006
const SWAY_MAX := 0.3
const SWAY_STIFFNESS := 90.0
const SWAY_DAMPING := 7.0
## Longest time handled per update (s) and inner step (s): a hitched frame must not blow up the spring.
const MAX_DELTA := 0.25
const STEP := 1.0 / 120.0
## Grip farther than this (px) from its target counts as a teleport: snaps instantly.
const SNAP_DISTANCE := 48.0

## Carrying hand: +1 right, -1 left.
var side: int = 1
## Grip point (px relative to carrier center).
var grip: Vector2 = Vector2.ZERO
## Pendulum angle (rad; positive: bag bottom to the left, i.e. lags behind when moving right).
var angle: float = 0.0
var angular_velocity: float = 0.0
## Drawn in front of the carrier (behind when back is turned).
var front: bool = true

var _built: bool = false


## Carrying hand from facing: that direction once the horizontal component passes the threshold, else `current`.
static func pick_side(face: Vector2, current: int) -> int:
	if face.x > SIDE_THRESHOLD:
		return 1
	if face.x < -SIDE_THRESHOLD:
		return -1
	return current


## Hands array in PuppetBody.hands order [left, right]; side -> index.
static func hand_index(which_side: int) -> int:
	return 1 if which_side > 0 else 0


func is_built() -> bool:
	return _built


## Snaps at the next update (carrier changed, bag dropped).
func reset() -> void:
	_built = false


## One frame. `face` body facing (unit), `hands` px relative to carrier [left, right], `back` back turned,
## `carrier_velocity` carrier speed (px/s), `reduced` reduced motion.
func update(delta: float, face: Vector2, hands: PackedVector2Array, back: bool, carrier_velocity: Vector2,
		reduced: bool) -> void:
	if hands.size() < 2:
		return
	side = pick_side(face, side)
	front = not back
	var target: Vector2 = hands[hand_index(side)] + Vector2(0.0, -GRIP_LIFT)
	if not _built or grip.distance_to(target) > SNAP_DISTANCE:
		grip = target
		angle = 0.0
		angular_velocity = 0.0
		_built = true
		return
	var left: float = clampf(delta, 0.0, MAX_DELTA)
	if left <= 0.0:
		return
	var before: Vector2 = grip
	grip = target + (grip - target) * exp(-FOLLOW_RATE * left)
	if reduced:
		angle = 0.0
		angular_velocity = 0.0
		return
	var goal: float = (grip.x - before.x) / left * SWING_GAIN + carrier_velocity.x * DRAG_GAIN
	goal = clampf(goal, -SWAY_MAX, SWAY_MAX) if is_finite(goal) else 0.0
	while left > 0.0:
		var h: float = minf(STEP, left)
		left -= h
		angular_velocity += ((goal - angle) * SWAY_STIFFNESS - angular_velocity * SWAY_DAMPING) * h
		angle = clampf(angle + angular_velocity * h, -SWAY_MAX, SWAY_MAX)
