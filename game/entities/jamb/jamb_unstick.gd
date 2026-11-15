class_name JambUnstick
extends RefCounted
## Gets an AI body off a door jamb (S-016): its capsule can catch on the
## corner of a doorway the path grazes and stay there, held still, with no
## wall reported. Held still while it wants to move, it steps back the way it
## came a moment, then walks on.

## Held still this long, in seconds, it steps back.
const STUCK_TIME := 0.3
## How fast it steps back, as a share of its pace.
const PUSH := 0.7
## How long it steps back, in seconds.
const BACK_TIME := 0.4
## Closer than this to its goal, in meters, a body held still is pressing on
## what it came for (a closet, a box): no jamb there.
const GOAL_CLEARANCE := 2.5

var _stuck_for := 0.0
var _backing_for := 0.0


## The horizontal velocity to move the body at, from the one it wants.
func update(body: CharacterBody3D, horizontal: Vector3, delta: float) -> Vector3:
	var wanted := Vector2(horizontal.x, horizontal.z).length()
	if _backing_for > 0.0:
		_backing_for -= delta
		return -horizontal.normalized() * wanted * PUSH
	var real := body.get_real_velocity()
	if wanted < 0.01 or Vector2(real.x, real.z).length() > 0.2 * wanted:
		_stuck_for = 0.0
		return horizontal
	_stuck_for += delta
	if _stuck_for < STUCK_TIME:
		return horizontal
	_stuck_for = 0.0
	_backing_for = BACK_TIME
	return -horizontal.normalized() * wanted * PUSH
