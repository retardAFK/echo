class_name SharedPose
extends RefCounted
## Where a moving prop of the map was last sent online (S-020, T-302): the
## room sends a gurney or a wheelchair again only once it has moved more than
## MIN_MOVE or turned more than MIN_TURN, so a prop settling by a few
## millimetres does not resend the whole state of the map.

const MIN_MOVE := 0.05
const MIN_TURN := 0.05

var _position := Vector3.INF
var _yaw := 0.0


## [x, y, z, yaw] to send for node: the last ones sent, or its pose now if it
## moved or turned enough.
func of(node: Node3D) -> Array:
	var at := node.global_position
	var yaw := node.rotation.y
	if (
		not _position.is_finite()
		or at.distance_to(_position) > MIN_MOVE
		or absf(angle_difference(yaw, _yaw)) > MIN_TURN
	):
		_position = at
		_yaw = yaw
	return [
		snappedf(_position.x, 0.01),
		snappedf(_position.y, 0.01),
		snappedf(_position.z, 0.01),
		snappedf(_yaw, 0.01),
	]
