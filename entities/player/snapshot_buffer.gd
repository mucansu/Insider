class_name SnapshotBuffer
extends RefCounted
## Remote player interpolation buffer (US-004 AC4; S2, GDD §12 "remote players via 100 ms interpolation buffer").
## Method: the authoritative copy writes its state and its own-clock time (`Player.net_time`) each physics step; the synchronizer sends at
## 20 Hz. The receiver `push`es each packet (sender time, local arrival time, state); each frame `sample(local_time)` linearly
## interpolates, on the sender clock, the instant `local_time - clock_offset - delay` between the two surrounding snapshots (position lerp,
## facing slerp, look angle lerp along the shortest path - US-011b, mode from the earlier snapshot, velocity constant between snapshots).
## Clock offset (local arrival - sender time = one-way delay + clock skew) is tracked by exponential averaging: jitter is absorbed in the
## buffer and the draw clock advances smoothly; a jump over 0.5 s resets it. Drawing by sender time (not arrival time) keeps packet
## jitter out of the motion. Out-of-order or stale packets are dropped. On underrun (loss) it waits at the last state; no extrapolation
## (no overshoot while turning or against walls).

## Interpolated state.
class Frame extends RefCounted:
	var time: float = 0.0
	var position: Vector2 = Vector2.ZERO
	var facing: Vector2 = Vector2.DOWN
	var mode: int = 0
	var velocity: Vector2 = Vector2.ZERO
	## Look angle (rad; US-011b).
	var look: float = 0.0

	func _init(t: float = 0.0, pos: Vector2 = Vector2.ZERO, dir: Vector2 = Vector2.DOWN, kind: int = 0,
			vel: Vector2 = Vector2.ZERO, look_angle: float = 0.0) -> void:
		time = t
		position = pos
		facing = dir
		mode = kind
		velocity = vel
		look = look_angle


## Maximum snapshots in the buffer (1.6 s at 20 Hz).
const MAX_FRAMES := 32
## Weight of a new measurement in the clock offset average.
const OFFSET_SMOOTHING := 0.05
## If the clock offset jumps by more than this (process stalled, clock changed) the average is rebuilt from scratch (s).
const OFFSET_RESET_SEC := 0.5

## How far behind on the sender clock drawing happens (s).
var delay: float = 0.1

var _frames: Array[Frame] = []
var _offset: float = 0.0
var _has_offset: bool = false
var _underruns: int = 0


func _init(delay_sec: float = 0.1) -> void:
	delay = delay_sec


## Incoming snapshot. Dropped (returns false) if stale (sender time not past the last snapshot) or if times/position/facing/look are not
## finite (NaN/INF: a bad packet must not poison the clock or drawing).
func push(sender_time: float, local_time: float, position: Vector2, facing: Vector2, mode: int,
		look: float = 0.0) -> bool:
	if not (is_finite(sender_time) and is_finite(local_time) and position.is_finite() and facing.is_finite()
			and is_finite(look)):
		return false
	if not _frames.is_empty() and sender_time <= _frames.back().time:
		return false
	var measured: float = local_time - sender_time
	if not _has_offset or absf(measured - _offset) > OFFSET_RESET_SEC:
		_offset = measured
		_has_offset = true
	else:
		_offset += (measured - _offset) * OFFSET_SMOOTHING
	_frames.append(Frame.new(sender_time, position, facing, mode, Vector2.ZERO, look))
	if _frames.size() > MAX_FRAMES:
		_frames.pop_front()
	return true


## State to draw at `local_time`; null if the buffer is empty.
func sample(local_time: float) -> Frame:
	if _frames.is_empty():
		return null
	var t: float = local_time - _offset - delay
	while _frames.size() >= 2 and _frames[1].time <= t:
		_frames.pop_front()  # old snapshots no longer needed
	var a: Frame = _frames[0]
	if _frames.size() == 1 or t <= a.time:
		if _frames.size() == 1 and t > a.time:
			_underruns += 1  # draw time passed the newest snapshot: data late or lost
		return Frame.new(t, a.position, a.facing, a.mode, Vector2.ZERO, a.look)
	var b: Frame = _frames[1]
	var span: float = b.time - a.time
	var w: float = clampf((t - a.time) / span, 0.0, 1.0)
	return Frame.new(t, a.position.lerp(b.position, w), a.facing.slerp(b.facing, w), a.mode,
		(b.position - a.position) / span, lerp_angle(a.look, b.look, w))


func size() -> int:
	return _frames.size()


## Number of (expected) `sample` calls where draw time passed the newest snapshot; the authoritative copy always sends at 20 Hz so
## it stays 0 after warm-up on a healthy link (diagnostics/dump).
func underrun_count() -> int:
	return _underruns


## Tracked clock offset (local - sender, s); 0 if no packet yet.
func clock_offset() -> float:
	return _offset


func clear() -> void:
	_frames.clear()
	_has_offset = false
	_offset = 0.0
	_underruns = 0
