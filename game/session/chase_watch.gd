class_name ChaseWatch
extends Node
## Looks, every sample_time, whether the monster sees each hunted, and gives
## the facts to the ChaseStats of its GameLoop (spec S-020, T-322, piste E8).
## Runs in solo and on the room, not on the clients (they copy the room's
## figures). Works with the AI monster and the monster played by a person:
## the monster is the node of the "monsters" group (Prison.MONSTERS_GROUP).

var game_loop: GameLoop
var settings: ChaseSettings

var _left := 0.0


func _physics_process(delta: float) -> void:
	if game_loop == null or game_loop.is_over:
		return
	_left -= delta
	if _left > 0.0:
		return
	var step := settings.sample_time - _left
	_left = settings.sample_time
	var monster := _monster()
	if monster == null:
		return
	for member in game_loop.team:
		if not is_instance_valid(member) or not member is Node3D:
			continue
		var hunted := member as Node3D
		var caught := game_loop.is_captured(hunted)  # Out for good: ChaseStats.leave().
		var distance := monster.global_position.distance_to(hunted.global_position)
		var seen := not caught and sees(monster, hunted, settings)
		game_loop.chases.step(hunted.get_instance_id(), step, distance, seen, caught)


func _monster() -> Node3D:
	for node in get_tree().get_nodes_in_group(Prison.MONSTERS_GROUP):
		if node is Node3D and node.is_inside_tree() and node.can_process():
			return node  # A switched-off avatar (simulations) is no monster.
	return null


## Whether the monster sees the hunted: not hidden, within lost_range, in
## front of it (view_half_angle) and nothing in between.
static func sees(monster: Node3D, hunted: Node3D, p_settings: ChaseSettings) -> bool:
	if HidingSpot.is_hidden(hunted):
		return false
	var eye: Vector3 = monster.get_eye_position()
	var aim: Vector3 = hunted.get_eye_position()
	var gap := aim - eye
	if gap.length() > p_settings.lost_range or SmokeCloud.blocks(eye, aim):
		return false  # Too far, or lost in a smoke bomb's cloud (S-020, T-335).
	var flat_gap := Vector2(gap.x, gap.z)
	var forward := -monster.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z)
	if flat_gap.length() >= 1.0 and not flat_forward.is_zero_approx():
		if absf(rad_to_deg(flat_forward.angle_to(flat_gap))) > p_settings.view_half_angle:
			return false
	var query := PhysicsRayQueryParameters3D.create(eye, aim, NetGame.SIGHT_MASK)
	var skip: Array[RID] = []
	for body: Node3D in [monster, hunted]:
		if body is CollisionObject3D:
			skip.append((body as CollisionObject3D).get_rid())
	query.exclude = skip
	return monster.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
