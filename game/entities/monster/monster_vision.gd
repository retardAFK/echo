class_name MonsterVision
extends RefCounted
## Monster line of sight (spec S-003): field of view, range, then one ray
## against the world and walls layers.

## Layers that block the monster's sight: world (1) and walls (2).
const SIGHT_MASK := (1 << 0) | (1 << 1)


## Whether a point is inside the field of view and range, ignoring obstacles.
static func in_view_cone(
	eye: Vector3, forward: Vector3, point: Vector3, settings: MonsterSettings
) -> bool:
	var to_point := point - eye
	if to_point.length() > settings.vision_range:
		return false
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	var flat_to_point := Vector3(to_point.x, 0.0, to_point.z)
	if flat_to_point.length_squared() < 0.0001:
		return true  # Right on top of the monster.
	var angle := rad_to_deg(flat_forward.angle_to(flat_to_point))
	return angle <= settings.vision_angle / 2.0


## Whether nothing on the world or walls layers stands between the two points.
static func has_line_of_sight(
	space: PhysicsDirectSpaceState3D, eye: Vector3, point: Vector3
) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)
	return space.intersect_ray(query).is_empty()
