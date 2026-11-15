extends GutTest
## The tower of the Tilleuls (spec S-016, T-236): double doors, a fire door on
## every landing, four flats behind their doors on every storey, the fire
## escape outside, the cellars down to the car park.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const ORIGIN := Vector3(110, 0, 110)
const REACH := 1.0
## Plan points (x, height, y) the AIs must reach from outside the tower.
const PLACES := {
	"north entrance": Vector3(108, 0, 86),
	"south entrance": Vector3(105, 0, 114),
	"4th floor, north-west flat": Vector3(94, 12, 92),
	"4th floor, north-east flat": Vector3(113, 12, 92),
	"3rd floor, south-west flat": Vector3(95, 9, 105),
	"2nd floor, south-east flat": Vector3(113, 6, 109),
	"fire escape, top landing": Vector3(119, 12, 100),
	"cellar corridor": Vector3(110, -3, 97.2),
	"car park": Vector3(150, -3, 106),
}

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


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


func _doors_near(plan: Vector3, radius: float) -> Array[Door]:
	var found: Array[Door] = []
	var at := _world(plan)
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if _map.is_ancestor_of(door) and door.global_position.distance_to(at) < radius:
			found.append(door)
	return found


func test_every_place_can_be_reached_from_outside() -> void:
	var nav_map: RID = await _nav_map()
	var start: Vector3 = _map.get_spawn_points()[0]
	for place: String in PLACES:
		var to := _world(PLACES[place])
		var path := NavigationServer3D.map_get_path(nav_map, start, to, true)
		assert_gt(path.size(), 1, place)
		if path.size() > 1:
			var end := path[path.size() - 1]
			assert_lt(Vector2(end.x, end.z).distance_to(Vector2(to.x, to.z)), REACH, place)
			assert_lt(absf(end.y - to.y), REACH, place)


func test_the_hall_has_double_doors_north_and_south() -> void:
	assert_eq(_doors_near(Vector3(108, 0, 88), 2.5).size(), 2, "north")
	assert_eq(_doors_near(Vector3(105, 0, 112), 2.5).size(), 2, "south")


func test_double_fire_doors_close_the_stair_landing_on_every_storey() -> void:
	for level in range(1, 5):
		var doors := _doors_near(Vector3(103.2, level * 3.0, 100), 3.5)
		var fire := doors.filter(func(d: Door) -> bool: return d.kind == Door.Kind.FIRE)
		assert_eq(fire.size(), 4, "storey %d" % level)


func test_every_flat_has_its_front_door() -> void:
	for level in range(1, 5):
		for front: Vector2 in [
			Vector2(97.6, 98.5), Vector2(108.6, 98.5), Vector2(99.1, 101.5), Vector2(106.6, 101.5)
		]:
			var doors := _doors_near(Vector3(front.x, level * 3.0, front.y), 0.3)
			assert_eq(doors.size(), 1, "storey %d, door at %s" % [level, front])


func test_the_fire_escape_is_metal_and_reached_by_a_fire_door() -> void:
	var tree := get_tree()
	assert_true(MetalFloor.under(tree, _world(Vector3(118, 6.1, 100))), "landing")
	assert_true(MetalFloor.under(tree, _world(Vector3(117.3, 1.0, 96))), "flight")
	assert_false(MetalFloor.under(tree, _world(Vector3(110, 6.1, 100))), "inside")
	for level in range(1, 5):
		var doors := _doors_near(Vector3(115.85, level * 3.0, 100), 0.3)
		assert_eq(doors.size(), 1, "storey %d" % level)
		if doors.size() == 1:
			assert_eq(doors[0].kind, Door.Kind.FIRE)


func test_the_cellars_belong_to_the_tower_then_the_car_park() -> void:
	var tower: Building = _map.get_node("Buildings/Tower")
	var car_park: Building = _map.get_node("Buildings/CarPark")
	assert_true(tower.contains(_world(Vector3(96, -1.5, 97))), "the cellar stairs")
	assert_true(car_park.contains(_world(Vector3(125, -2, 97))), "the corridor")
	assert_true(car_park.contains(_world(Vector3(126, -2, 95))), "the cages")
	assert_false(tower.contains(_world(Vector3(125, -2, 97))))
	assert_eq(car_park.distance_to(_world(Vector3(125, -2, 97))), 0.0)
	var fire := _doors_near(Vector3(116.5, -3, 97.2), 1.5)
	assert_eq(fire.size(), 2, "a double fire door under the street")


func test_the_tower_has_spots_of_every_family() -> void:
	var tower: Building = _map.get_node("Buildings/Tower")
	var families := {}
	for spot: HidingSpot in _map.get_node("Hideouts").get_children():
		if tower.contains(spot.global_position + Vector3.UP * 0.5):
			families[spot.family] = families.get(spot.family, 0) + 1
	assert_eq(families.get(HidingSpot.Family.CLOSET, 0), 3)
	assert_eq(families.get(HidingSpot.Family.LOW, 0), 4)
	assert_eq(families.get(HidingSpot.Family.MAKESHIFT, 0), 4)
	assert_eq(families.get(HidingSpot.Family.METAL, 0), 1)
