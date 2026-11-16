class_name JambUnstick
extends RefCounted
## Gets an AI body off a door jamb (S-016): its capsule can catch on the
## corner of a doorway the path grazes and stay there, held still, with no
## wall reported. Held still while it wants to move, it steps back the way it
## came a moment, then walks on. It steps back aslant, to one side then the
## other: straight back, it would come back on the same corner every time (an
## open door's leaf beside the path held the monster for good, T-167).

## Held still this long, in seconds, it steps back.
const STUCK_TIME := 0.3
## How fast it steps back, as a share of its pace.
const PUSH := 0.7
## How long it steps back, in seconds.
const BACK_TIME := 0.4
## Closer than this to its goal, in meters, a body held still is pressing on
## what it came for (a closet, a box): no jamb there.
const GOAL_CLEARANCE := 2.5
## Angle between straight back and the way it steps back, in degrees.
const SIDE_ANGLE := 50.0
## Still held at the same spot after this many steps back, it is pinned (its
## capsule caught in a corner, which happened on one platform's physics only,
## T-167): it is lifted this high, in meters, to fall free.
const PINNED_TRIES := 3
const LIFT := 0.3
## Within this of where it was last held, in meters, it is the same spot.
const SAME_SPOT := 0.1

var _stuck_for := 0.0
var _backing_for := 0.0
## The side of the next step back, 1 or -1.
var _side := 1.0
## The way it steps back, as a share of what it wanted (length PUSH).
var _back := Vector3.ZERO
## Steps back in a row that ended at the same spot, and where.
var _tries := 0
var _held_at := Vector3.INF
## Set when a step back ends: the body may now be behind a corner of its
## path it had passed, so its path must be planned again (take_replan).
var _replan := false


## The horizontal velocity to move the body at, from the one it wants.
func update(body: CharacterBody3D, horizontal: Vector3, delta: float) -> Vector3:
	var wanted := Vector2(horizontal.x, horizontal.z).length()
	if _backing_for > 0.0:
		_backing_for -= delta
		_replan = _backing_for <= 0.0
		return _back * wanted
	var real := body.get_real_velocity()
	if wanted < 0.01 or Vector2(real.x, real.z).length() > 0.2 * wanted:
		_stuck_for = 0.0
		return horizontal
	_stuck_for += delta
	if _stuck_for < STUCK_TIME:
		return horizontal
	_stuck_for = 0.0
	_lift_if_pinned(body)
	_backing_for = BACK_TIME
	_back = -horizontal.normalized().rotated(Vector3.UP, deg_to_rad(SIDE_ANGLE) * _side) * PUSH
	_side = -_side
	return _back * wanted


func _lift_if_pinned(body: CharacterBody3D) -> void:
	var at := body.global_position
	_tries = _tries + 1 if at.distance_to(_held_at) < SAME_SPOT else 1
	_held_at = at
	if _tries > PINNED_TRIES:
		body.global_position += Vector3.UP * LIFT
		_tries = 0
		_held_at = Vector3.INF


## Whether a step back just ended: its path must be planned again from where
## it stands, or it heads for a point past the doorway, through the wall.
func take_replan() -> bool:
	var replan := _replan
	_replan = false
	return replan
