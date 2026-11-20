class_name RouteWatch
extends Node
## Records, every sample_time of game time, where the monster and each hunted
## are, in the RouteLog of its GameLoop (spec S-020, T-339, piste U2). Runs in
## solo and on the room, not on the clients (they get the room's log at the
## end). The monster is the node of the "monsters" group, as for ChaseWatch.

var game_loop: GameLoop

var _next := 0.0


func _physics_process(_delta: float) -> void:
	if game_loop == null or game_loop.is_over:
		return
	if game_loop.elapsed >= _next:
		sample()


## Records the positions now, and plans the next look.
func sample() -> void:
	var routes := game_loop.routes
	var points: Array[Vector2] = [_flat(ChaseWatch.find_monster(get_tree()))]
	for member in game_loop.team:
		if not is_instance_valid(member) or member in game_loop.out:
			points.append(RouteLog.MISSING)
		else:
			points.append(_flat(member as Node3D))
	routes.record(points, game_loop.elapsed)
	_next = routes.size() * routes.sample_time


static func _flat(node: Node3D) -> Vector2:
	if node == null or not node.is_inside_tree():
		return RouteLog.MISSING
	return Vector2(node.global_position.x, node.global_position.z)
