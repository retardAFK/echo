extends GutTest
## The car park of the Tilleuls and the cellar corridor (spec S-016, T-239):
## four ways out (ramp, south-east stairs, new north stairs, the cellars),
## the technical room, spots in the wrecks and in a cellar cage.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const ORIGIN := Vector3(110, 0, 110)
const REACH := 1.0

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _world(plan: Vector3) -> Vector3:
	return plan - ORIGIN


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


func _path(nav_map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(nav_map, _world(from), _world(to), true)


func _length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


func _ends_at(path: PackedVector3Array, plan: Vector3) -> bool:
	if path.size() < 2:
		return false
	var end := path[path.size() - 1]
	var to := _world(plan)
	return (
		Vector2(end.x, end.z).distance_to(Vector2(to.x, to.z)) < REACH
		and absf(end.y - to.y) < REACH
	)


func _doors_near(plan: Vector3, radius: float) -> Array[Door]:
	var found: Array[Door] = []
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if _map.is_ancestor_of(door) and door.global_position.distance_to(_world(plan)) < radius:
			found.append(door)
	return found


func test_four_ways_out_of_the_car_park() -> void:
	var nav_map: RID = await _nav_map()
	var inside := Vector3(160, -3, 106)
	var ways := {
		"the ramp": Vector3(126, 0, 102),
		"the south-east stairs": Vector3(180.5, 0, 113.2),
		"the north stairs": Vector3(168, 0, 96.6),
		"the cellars, to the tower": Vector3(95.6, 0, 94),
	}
	for way: String in ways:
		assert_true(_ends_at(_path(nav_map, inside, ways[way]), ways[way]), way)


func test_the_north_stairs_are_a_shortcut() -> void:
	var nav_map: RID = await _nav_map()
	var path := _path(nav_map, Vector3(178, -3, 97), Vector3(168, 0, 96.6))
	assert_true(_ends_at(path, Vector3(168, 0, 96.6)))
	assert_lt(_length(path), 20.0, "up the north stairs, not round by the ramp")
	var doors := _doors_near(Vector3(176.15, -3, 96.65), 1.5)
	assert_eq(doors.size(), 2, "a double fire door at their foot")
	for door in doors:
		assert_eq(door.kind, Door.Kind.FIRE)


func test_the_cellar_corridor_joins_the_tower_and_the_car_park() -> void:
	var nav_map: RID = await _nav_map()
	var path := _path(nav_map, Vector3(96, 0, 92), Vector3(145, -3, 97))
	assert_true(_ends_at(path, Vector3(145, -3, 97)))
	var under := false
	for point in path:
		var plan := point + ORIGIN
		under = under or (plan.y < -2.0 and plan.x > 110.0 and plan.x < 135.0)
	assert_true(under, "the shortest way is under the street")


func test_the_technical_room_has_its_door() -> void:
	assert_eq(_doors_near(Vector3(174, -3, 104.6), 0.3).size(), 1)


func test_spots_of_every_family_in_the_car_park() -> void:
	var car_park: Building = _map.get_node("Buildings/CarPark")
	var families := {}
	for spot: HidingSpot in _map.get_node("Hideouts").get_children():
		if car_park.contains(spot.global_position + Vector3.UP * 0.5):
			families[spot.family] = families.get(spot.family, 0) + 1
	assert_eq(families.get(HidingSpot.Family.CLOSET, 0), 3)
	assert_eq(families.get(HidingSpot.Family.LOW, 0), 1, "under a wreck")
	assert_eq(families.get(HidingSpot.Family.MAKESHIFT, 0), 1, "in a cellar cage")
	assert_eq(families.get(HidingSpot.Family.METAL, 0), 2, "two wrecks' boots")


func test_the_ai_monster_walks_the_cellar_corridor() -> void:
	var monster: Monster = _map.get_node("Monster")
	monster.player = null
	var settings: MonsterSettings = monster.settings.duplicate()
	settings.prowl_speed = 6.0
	monster.settings = settings
	monster.brain.settings = settings
	await _nav_map()
	var goal := _world(Vector3(145, -3, 97))
	monster.global_position = _world(Vector3(96, 0, 92))
	monster.velocity = Vector3.ZERO
	var points: Array[Vector3] = [goal]
	monster.brain.set_patrol(points, 0)
	var went_under := false
	for i in 25 * 4:
		await wait_seconds(0.25)
		var plan := monster.global_position + ORIGIN
		went_under = went_under or (plan.y < -2.0 and plan.x > 110.0 and plan.x < 135.0)
		if monster.global_position.distance_to(goal) < 1.5:
			break
	assert_lt(monster.global_position.distance_to(goal), 1.5, "through two fire doors")
	assert_true(went_under, "under the street")
