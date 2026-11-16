extends GutTest
## The hospital Saint-Roch of the cité des Tilleuls, greybox (spec S-014, T-183):
## every room of its 4 levels can be reached on foot by the AI, by the
## stairs, the quay's ramp and the fire escape; it can be scanned.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const Hospital := preload("res://tools/godot/hospital.gd")
const ORIGIN := Vector3(110, 0, 110)
## The end of the AI's path is this close to the target.
const REACH := 1.0
## Middles of the rooms west and east of the corridor.
const WEST_X := 14.75
const EAST_X := 27.25

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


## A plan point (x, height, y) in the world.
func _world(plan: Vector3) -> Vector3:
	return Vector3(plan.x, plan.y, plan.z) - ORIGIN


func _nav_map() -> RID:
	var nav_map := _map.get_world_3d().navigation_map
	var spawn: Vector3 = _map.get_spawn_points()[0]
	await wait_until(func() -> bool: return NavigationServer3D.map_get_iteration_id(nav_map) > 0, 5)
	await wait_until(
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, spawn)
			return Vector2(closest.x, closest.z).distance_to(Vector2(spawn.x, spawn.z)) < 0.1,
		5
	)
	return nav_map


func _assert_reachable(nav_map: RID, plan: Vector3, what: String) -> void:
	var start: Vector3 = _map.get_spawn_points()[0]
	var at := _world(plan)
	var path := NavigationServer3D.map_get_path(nav_map, start, at, true)
	assert_gt(path.size(), 1, what)
	if path.size() > 1:
		var end := path[path.size() - 1]
		assert_lt(
			Vector2(end.x, end.z).distance_to(Vector2(at.x, at.z)), REACH, "%s %s" % [what, plan]
		)
		assert_lt(absf(end.y - at.y), REACH, "%s %s" % [what, plan])


func test_the_corridor_of_every_level_can_be_reached() -> void:
	var nav_map: RID = await _nav_map()
	for level: float in Hospital.LEVELS:
		for y in [62.0, 94.0, 125.0]:
			_assert_reachable(nav_map, Vector3(21, level, y), "corridor")


func test_every_room_can_be_reached() -> void:
	var nav_map: RID = await _nav_map()
	for level: float in Hospital.LEVELS:
		for room: Array in Hospital.WEST_ROOMS[level]:
			_assert_reachable(
				nav_map, Vector3(WEST_X, level, (room[0] + room[1]) / 2.0), "west room"
			)
		for room: Array in Hospital.EAST_ROOMS[level]:
			_assert_reachable(
				nav_map, Vector3(EAST_X, level, (room[0] + room[1]) / 2.0), "east room"
			)


func test_quay_and_fire_escape_can_be_reached() -> void:
	var nav_map: RID = await _nav_map()
	var apron: Rect2 = Hospital.QUAY_APRON
	_assert_reachable(nav_map, Vector3(apron.get_center().x, -3, apron.get_center().y), "quay")
	var landing: Rect2 = Hospital.ESCAPE_LANDING
	_assert_reachable(
		nav_map, Vector3(landing.get_center().x, 6, landing.get_center().y), "escape top"
	)
	var mid: Rect2 = Hospital.ESCAPE_MID
	_assert_reachable(nav_map, Vector3(mid.get_center().x, 3, mid.get_center().y), "escape middle")


func test_the_hospital_can_be_scanned_on_every_level() -> void:
	var hospital: Building = _map.get_node("Buildings/Hospital")
	for level: float in Hospital.LEVELS:
		assert_true(hospital.contains(_world(Vector3(21, level + 1, 94))), "level %d" % level)
	assert_true(hospital.contains(_world(Vector3(8, -2, 92))), "the quay")
	assert_false(hospital.contains(_world(Vector3(40, 1, 94))), "the forecourt")


func test_its_walls_hide_and_muffle() -> void:
	var body: StaticBody3D = _map.get_node("Structures/Hospital/Walls")
	assert_eq(body.collision_layer, NoiseBus.WALLS_COLLISION_MASK)
