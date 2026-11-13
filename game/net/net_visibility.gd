class_name NetVisibility
extends RefCounted
## What the room sends each client about the others (S-010, plan, T-097).
## A player sees another only within sight_range, inside a cone wider than
## the camera, with nothing in between, and never someone in a hiding spot.
## Pure: the room gives the facts (positions, facing, free line of sight).


## Whether a viewer at eye, facing forward (a flat direction), sees target.
## clear_line is the result of the room's ray test between the two.
static func sees(
	eye: Vector3,
	forward: Vector3,
	target: Vector3,
	target_hidden: bool,
	clear_line: bool,
	settings: NetSettings
) -> bool:
	if target_hidden or not clear_line:
		return false
	var gap := target - eye
	if gap.length() > settings.sight_range:
		return false
	var flat_gap := Vector2(gap.x, gap.z)
	var flat_forward := Vector2(forward.x, forward.z)
	if flat_gap.length() < 1.0 or flat_forward.is_zero_approx():
		return true  # Right next to it: seen whatever the facing.
	var angle := rad_to_deg(flat_forward.angle_to(flat_gap))
	return absf(angle) <= settings.sight_half_angle
