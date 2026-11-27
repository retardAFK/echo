class_name HoldPose
extends SkeletonModifier3D
## Both arms of a hunted's skeleton reaching for what it holds (spec S-025,
## T-409): after the animation, each arm (upper arm, forearm, hand) is bent
## by a two-bone solve so that its wrist meets a target node, the elbow
## pointing down and out. The legs and the body keep the animation (walk,
## run, crouch), so a hunted carries its gun while it moves. A child of the
## Skeleton3D; HuntedBody.hold() makes it and turns it on and off.

## The bones of each arm, by the names of tools/blender/hunted.py.
const ARMS := {
	&"right": [&"upperarm_r", &"lowerarm_r", &"hand_r"],
	&"left": [&"upperarm_l", &"lowerarm_l", &"hand_l"],
}

## Where an elbow folds in the T pose of the rest: ahead (-Z).
const BEND_AHEAD := Vector3.FORWARD

## Where each wrist goes (global transforms read each frame).
var right_target: Node3D
var left_target: Node3D


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if right_target != null and right_target.is_inside_tree():
		_reach(skeleton, ARMS[&"right"], right_target.global_position, 1.0)
	if left_target != null and left_target.is_inside_tree():
		_reach(skeleton, ARMS[&"left"], left_target.global_position, -1.0)


## Bends one arm so its wrist meets target (global); side 1 right, -1 left.
func _reach(skeleton: Skeleton3D, bones: Array, target: Vector3, side: float) -> void:
	var upper := skeleton.find_bone(bones[0])
	var lower := skeleton.find_bone(bones[1])
	var hand := skeleton.find_bone(bones[2])
	if upper < 0 or lower < 0 or hand < 0:
		return
	var goal := skeleton.global_transform.affine_inverse() * target
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := elbow_point(
		shoulder,
		goal,
		skeleton.get_bone_rest(lower).origin.length(),
		skeleton.get_bone_rest(hand).origin.length(),
		Vector3(side * 0.6, -1.0, 0.2)
	)
	_aim_bone(skeleton, upper, lower, elbow)
	_bend_towards(skeleton, upper, lower, goal - elbow)
	_aim_bone(skeleton, lower, hand, goal)


## Where the elbow goes for a shoulder reaching goal with an upper arm and a
## forearm of these lengths, bent towards pole (a direction). The arm stays
## straight towards a goal out of reach.
static func elbow_point(
	shoulder: Vector3, goal: Vector3, upper: float, fore: float, pole: Vector3
) -> Vector3:
	var reach := goal - shoulder
	var distance := clampf(reach.length(), 0.001, upper + fore - 0.001)
	var along := reach.normalized()
	# Law of cosines: how far along the reach the elbow is, and how far out.
	var foot := (upper * upper - fore * fore + distance * distance) / (2.0 * distance)
	var out := sqrt(maxf(upper * upper - foot * foot, 0.0))
	var bend := (pole - along * pole.dot(along)).normalized()
	if bend.is_zero_approx():
		bend = Vector3.DOWN
	return shoulder + along * foot + bend * out


## Twists bone about itself so that the side its joint bends to (ahead, in
## the T pose of the rest) faces bend: the elbow folds like an elbow and what
## the sleeve carries (pads) stays on the outside.
func _bend_towards(skeleton: Skeleton3D, bone: int, child: int, bend: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var rest := skeleton.get_bone_global_rest(bone).basis
	var axis := (pose.basis * skeleton.get_bone_rest(child).origin).normalized()
	var now := pose.basis * (rest.inverse() * BEND_AHEAD)
	now -= axis * now.dot(axis)
	var wanted := bend - axis * bend.dot(axis)
	if now.is_zero_approx() or wanted.is_zero_approx():
		return
	var angle := now.signed_angle_to(wanted, axis)
	pose.basis = Basis(axis, angle) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


## Turns bone (its global pose) so that its child bone's origin points at to.
func _aim_bone(skeleton: Skeleton3D, bone: int, child: int, to: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var now := (pose.basis * skeleton.get_bone_rest(child).origin).normalized()
	var wanted := (to - pose.origin).normalized()
	if now.is_zero_approx() or wanted.is_zero_approx() or now.is_equal_approx(wanted):
		return
	var turn := Quaternion(now, wanted)
	pose.basis = Basis(turn) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
