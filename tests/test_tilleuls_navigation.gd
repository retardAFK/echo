extends GutTest
## Navigation and AI across the cité des Tilleuls (spec S-006, T-041).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const PLAYER_SETTINGS := preload("res://game/data/player_settings.tres")
const ORIGIN := Vector3(110, 0, 110)
## Spec S-006: running across the map takes less than this.
const CROSSING_TIME := 45.0
## A route point is reached when the path ends this close to it.
const REACH := 1.0

var _map: GameMap
var _objectives := ""


func before_each() -> void:
	# Fuses only: the other objectives are drawn at random (S-018), and their
	# props must not change the walks of these tests from one run to the next.
	_objectives = OS.get_environment("ECHO_OBJECTIVES")
	OS.set_environment("ECHO_OBJECTIVES", "fuse")
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func after_each() -> void:
	OS.set_environment("ECHO_OBJECTIVES", _objectives)


func _world(plan: Vector3) -> Vector3:
	return Vector3(plan.x, plan.y, plan.z) - ORIGIN


func _nav_map() -> RID:
	# The navigation map is shared by every test: wait until this map's mesh is
	# merged, that is until a spawn point lies on it.
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


func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func _assert_reaches(nav_map: RID, from: Vector3, to: Vector3, label: String) -> void:
	var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
	assert_gt(path.size(), 1, label)
	if path.size() > 1:
		var end := path[path.size() - 1]
		assert_lt(Vector2(end.x, end.z).distance_to(Vector2(to.x, to.z)), REACH, label)
		assert_lt(absf(end.y - to.y), REACH, label)


func test_monster_patrol_reaches_every_point() -> void:
	var nav_map: RID = await _nav_map()
	var monster: Monster = _map.get_node("Monster")
	var points := monster.get_patrol_points()
	assert_gte(points.size(), 12)
	for point in points:
		_assert_reaches(nav_map, monster.global_position, point, "patrol %s" % (point + ORIGIN))


func test_patrol_goes_into_the_tower_and_the_car_park() -> void:
	var monster: Monster = _map.get_node("Monster")
	var tower: Building = _map.get_node("Buildings/Tower")
	var car_park: Building = _map.get_node("Buildings/CarPark")
	var in_tower_top := false
	var in_car_park := false
	for point in monster.get_patrol_points():
		var lifted := point + Vector3.UP * 0.5
		in_tower_top = in_tower_top or (tower.contains(lifted) and point.y > 10.0)
		in_car_park = in_car_park or car_park.contains(lifted)
	assert_true(in_tower_top, "the patrol climbs to the 4th floor of the tower")
	assert_true(in_car_park, "the patrol goes down into the car park")


func test_prey_route_and_hiding_spots_are_reachable() -> void:
	var nav_map: RID = await _nav_map()
	var start: Vector3 = _map.get_spawn_points()[0]
	for parent in ["PreyRoute", "HidingSpots"]:
		for point in Prey.markers_of(_map.get_node(parent)):
			_assert_reaches(nav_map, start, point, "%s %s" % [parent, point + ORIGIN])


func test_running_across_the_map_takes_less_than_45_s() -> void:
	var nav_map: RID = await _nav_map()
	# North to south (exit tunnel to the site fence) and west to east (wasteland
	# fence to the noise wall), around the blocks in the way.
	var crossings := [
		[Vector3(155, 0, 6), Vector3(120, 0, 209)],
		[Vector3(9, 0, 140), Vector3(207, 0, 140)],
		[Vector3(9, 0, 100), Vector3(207, 0, 100)],
		[Vector3(60, 0, 13), Vector3(60, 0, 209)],
	]
	for crossing: Array in crossings:
		var from := _world(crossing[0])
		var to := _world(crossing[1])
		_assert_reaches(nav_map, from, to, "crossing %s" % [crossing])
		var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
		var seconds := _path_length(path) / PLAYER_SETTINGS.sprint_speed
		gut.p("crossing %s: %.0f m, %.1f s" % [crossing, _path_length(path), seconds])
		assert_lt(seconds, CROSSING_TIME, "crossing %s takes %.1f s" % [crossing, seconds])


func test_ai_monster_walks_into_the_buildings() -> void:
	# A real walk with the physics, at a fast pace to keep the test short.
	var monster: Monster = _map.get_node("Monster")
	monster.player = null
	var settings: MonsterSettings = monster.settings.duplicate()
	settings.prowl_speed = 6.0
	settings.sabotage_range = 0.0  # A lit camera in sight would draw it away (S-018).
	monster.settings = settings
	monster.brain.settings = settings
	await _nav_map()
	var legs := [
		[Vector3(104, 0, 120), Vector3(108, 12, 100)],
		[Vector3(124, 0, 102), Vector3(160, -3, 106)],
		[Vector3(150, 0, 52), Vector3(176, 0, 74)],
		[Vector3(66, 0, 130), Vector3(76, 0, 142)],
	]
	for leg: Array in legs:
		var goal := _world(leg[1])
		monster.global_position = _world(leg[0])
		monster.velocity = Vector3.ZERO
		var points: Array[Vector3] = [goal]
		monster.brain.set_patrol(points, 0)
		await wait_until(func() -> bool: return monster.global_position.distance_to(goal) < 1.5, 20)
		assert_lt(
			monster.global_position.distance_to(goal),
			1.5,
			(
				"walked to %s, stopped at %s in state %s"
				% [leg[1], monster.global_position + ORIGIN, monster.brain.state]
			)
		)
