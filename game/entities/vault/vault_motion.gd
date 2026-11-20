class_name VaultMotion
extends RefCounted
## A body getting over a window or a low wall (spec S-020, T-340, piste E6):
## from where it stood to where it lands, along an arc high enough to clear
## the top, in a set time. Pure logic: the player and the monsters ask it
## where they are each frame and do nothing else while it runs.

var from := Vector3.ZERO
var to := Vector3.ZERO
var duration := 0.0
## Height of the arc above the straight line, at its middle.
var lift := 0.0

var _elapsed := 0.0
var _active := false


## Starts getting over: from a point, to a point, in seconds, rising up to
## `top` (a world height) at the middle.
func start(p_from: Vector3, p_to: Vector3, seconds: float, top: float) -> void:
	from = p_from
	to = p_to
	duration = maxf(seconds, 0.01)
	lift = maxf(top - (from.y + to.y) / 2.0, 0.0)
	_elapsed = 0.0
	_active = true


func is_active() -> bool:
	return _active


## Moves on by delta seconds; returns where the body is now. The last step
## puts it on the landing point and ends the motion.
func step(delta: float) -> Vector3:
	if not _active:
		return to
	_elapsed += delta
	if _elapsed >= duration:
		_active = false
		return to
	return position_at(_elapsed / duration)


## Where the body is at a share of the motion, 0 to 1.
func position_at(share: float) -> Vector3:
	var t := clampf(share, 0.0, 1.0)
	return from.lerp(to, t) + Vector3.UP * lift * sin(PI * t)
