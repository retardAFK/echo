extends GutTest
## A bot walks the hunted player through the cité des Tilleuls with the real
## controller and physics (spec S-006, T-044): into the tower up to the 4th
## floor, down the car park stairs, and crouching under the half-lowered shutter.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const ORIGIN := Vector3(110, 0, 110)
## A waypoint closer than this (horizontally) is passed, the bot aims at the next.
const WAYPOINT_REACH := 0.6
## The leg is done when the feet are this close to the goal.
const GOAL_REACH := 1.2
## The bot opens a closed door this close in front of it.
const DOOR_REACH := 1.2

var _map: GameMap
var _player: Player
var _goal := Vector3.ZERO
var _nav_map := RID()
var _straight := false


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	# Nobody chases the bot: the walk only checks the level geometry.
	_map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	_player = _map.get_node("Player")
	_nav_map = _map.get_world_3d().navigation_map
	await wait_until(
		func() -> bool: return NavigationServer3D.map_get_iteration_id(_nav_map) > 0, 5
	)
	var spawn: Vector3 = _map.get_spawn_points()[0]
	await wait_until(
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(_nav_map, spawn)
			return Vector2(closest.x, closest.z).distance_to(Vector2(spawn.x, spawn.z)) < 0.1,
		5
	)


func after_each() -> void:
	for action in ["move_forward", "sprint"]:
		Input.action_release(action)
	_goal = Vector3.ZERO


func _world(plan: Vector3) -> Vector3:
	return plan - ORIGIN


func _physics_process(delta: float) -> void:
	if _goal == Vector3.ZERO or not is_instance_valid(_player):
		return
	var aim := _goal
	if not _straight:
		var path := NavigationServer3D.map_get_path(_nav_map, _player.global_position, _goal, true)
		for point in path:
			var flat := Vector2(
				point.x - _player.global_position.x, point.z - _player.global_position.z
			)
			if flat.length() > WAYPOINT_REACH:
				aim = point
				break
	var to := aim - _player.global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_player.rotation.y = atan2(-to.x, -to.z)
	# A closed door in the way: the bot presses "interact", as a player would (S-016).
	var door := Door.closed_ahead(get_tree(), _player.global_position, to, DOOR_REACH)
	if door != null:
		door.hold(_player, delta)
		door.release(_player)


## Walks the player from start to goal (plan coordinates) and tells if it got there.
func _walk(start: Vector3, goal: Vector3, timeout: float, sprint := true) -> bool:
	_player.global_position = _world(start)
	_player.velocity = Vector3.ZERO
	_goal = _world(goal)
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	var target := _goal
	var reached := func() -> bool: return _player.global_position.distance_to(target) < GOAL_REACH
	await wait_until(reached, timeout)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_goal = Vector3.ZERO
	return reached.call()


func test_spawns_face_the_tower() -> void:
	# Centre of the tower, 24 x 24 m from (92, 88) on the plan.
	var tower := _world(Vector3(104, 0, 100))
	for marker: Node3D in _map.get_node("PlayerSpawns").get_children():
		var forward := -marker.global_basis.z
		var to_centre := (tower - marker.global_position) * Vector3(1, 0, 1)
		assert_gt(forward.dot(to_centre.normalized()), 0.99, "spawn %s" % marker.name)


func test_player_runs_up_to_the_4th_floor_of_the_tower() -> void:
	_straight = false
	var ok: bool = await _walk(Vector3(105, 0, 118), Vector3(113, 12, 108), 60)
	assert_true(ok, "the player is on the 4th floor (at %s)" % (_player.global_position + ORIGIN))


func test_player_runs_down_into_the_car_park() -> void:
	_straight = false
	var ok: bool = await _walk(Vector3(176, 0, 120), Vector3(160, -3, 106), 40)
	assert_true(ok, "the player is in the car park (at %s)" % (_player.global_position + ORIGIN))


func test_player_crouches_under_the_shutter() -> void:
	_straight = true
	var standing: bool = await _walk(Vector3(73.7, 0, 137), Vector3(73.7, 0, 142), 3, false)
	gut.p("standing, stopped at %s" % (_player.global_position + ORIGIN))
	assert_false(standing, "standing, the shutter stops the player")
	_player.toggle_crouch()
	await wait_physics_frames(30)
	var crouching: bool = await _walk(Vector3(73.7, 0, 137), Vector3(73.7, 0, 142), 10, false)
	assert_true(
		crouching, "crouching, the player goes under (at %s)" % (_player.global_position + ORIGIN)
	)
