class_name PuppetSpring
extends RefCounted
## Puppet spring (US-014): damped spring, semi-implicit Euler; advances with PuppetRig's fixed step. Body squash, lean and eyes smooth with it
## (no linear motion; GDD §14.1). Stability: semi-implicit Euler blows up when w*h and 2*zeta*w*h grow (e.g. 10 Hz x damping 2, or 20 Hz);
## the step is split into substeps (at most MAX_SUBSTEPS) so both stay under STABLE_LIMIT per substep. If that is not enough, frequency
## and damping clamp to the limit; non-finite state resets to the target.

## Upper limit of w*h and 2*zeta*w*h per substep.
const STABLE_LIMIT := 0.5
const MAX_SUBSTEPS := 16

var x: float = 0.0
var v: float = 0.0


func _init(value: float = 0.0) -> void:
	x = value


func step(target: float, frequency: float, damping: float, h: float) -> void:
	var w: float = TAU * maxf(0.0, frequency)
	var zeta: float = maxf(0.0, damping)
	var stiffness: float = maxf(w * h, 2.0 * zeta * w * h)
	var count: int = clampi(ceili(stiffness / STABLE_LIMIT), 1, MAX_SUBSTEPS)
	var sub: float = h / count
	var limit: float = STABLE_LIMIT / sub
	w = minf(w, limit)
	zeta = minf(zeta, limit / maxf(2.0 * w, 0.0001))
	for i: int in count:
		v += (w * w * (target - x) - 2.0 * zeta * w * v) * sub
		x += v * sub
	if not (is_finite(x) and is_finite(v)):
		settle(target)


## Settles on the target with no velocity (silent rebuild).
func settle(value: float) -> void:
	x = value
	v = 0.0
