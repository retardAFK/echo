class_name ShotMath
extends RefCounted
## Geometry of the Versus shots and blows (spec S-024, T-371), pure:
## a flare's arc, the boss's claw arc, the UV lamp's cone.


## Next position and velocity of a flare after delta seconds.
static func step(position: Vector3, velocity: Vector3, gravity: float, delta: float) -> Array:
	var next_velocity := velocity + Vector3.DOWN * gravity * delta
	var next_position := position + (velocity + next_velocity) * 0.5 * delta
	return [next_position, next_velocity]


## Whether target is within reach of from, inside the half_angle (degrees)
## around facing (flat), and within height of it. For the claw.
static func in_arc(
	from: Vector3, facing: Vector3, target: Vector3, reach: float, half_angle: float, height: float
) -> bool:
	var offset := target - from
	if absf(offset.y) > height:
		return false
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length() > reach:
		return false
	if flat.length() < 0.001:
		return true
	var ahead := Vector3(facing.x, 0.0, facing.z).normalized()
	return rad_to_deg(ahead.angle_to(flat.normalized())) <= half_angle


## Whether target is inside the cone from eye along aim (3D), for the lamp.
static func in_cone(
	eye: Vector3, aim: Vector3, target: Vector3, reach: float, half_angle: float
) -> bool:
	var offset := target - eye
	if offset.length() > reach:
		return false
	if offset.length() < 0.001:
		return true
	return rad_to_deg(aim.normalized().angle_to(offset.normalized())) <= half_angle
