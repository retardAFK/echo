extends GutTest
## The social centre of the Tilleuls (spec S-016, T-237): four ways out, the
## kitchen and its hatch, offices that open onto each other, the stage and
## its wings.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const ORIGIN := Vector3(110, 0, 110)
const REACH := 1.0
## Plan points (x, height, y) the AIs reach from outside.
const PLACES := {
	"north entrance": Vector3(161.5, 0, 58),
	"west entrance": Vector3(138, 0, 71.5),
	"kitchen back door": Vector3(157.6, 0, 86),
	"kitchen": Vector3(156, 0, 81),
	"last office": Vector3(170, 0, 80),
	"wings": Vector3(140.85, 0, 70),
}

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


func _doors_near(plan: Vector3, radius: float) -> Array[Door]:
	var found: Array[Door] = []
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if _map.is_ancestor_of(door) and door.global_position.distance_to(_world(plan)) < radius:
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


func test_the_doors_of_the_social_centre() -> void:
	assert_eq(_doors_near(Vector3(161.5, 0, 60.15), 1.5).size(), 2, "north, double")
	assert_eq(_doors_near(Vector3(140.15, 0, 71.5), 1.5).size(), 2, "west, double")
	assert_eq(_doors_near(Vector3(160, 0, 67), 1.2).size(), 2, "hall to corridor")
	assert_eq(_doors_near(Vector3(160, 0, 74), 1.2).size(), 2, "hall to corridor, south")
	assert_eq(_doors_near(Vector3(157.6, 0, 83.85), 0.3).size(), 1, "kitchen back door")
	for y: float in [68.0, 76.0]:
		assert_eq(_doors_near(Vector3(172.6, 0, y), 0.3).size(), 1, "between offices at %s" % y)
	var exits := _doors_near(Vector3(161.5, 0, 83.85), 0.3)
	assert_eq(exits.size(), 1)
	if exits.size() == 1:
		assert_eq(exits[0].kind, Door.Kind.EMERGENCY, "the end of the corridor")


func test_the_emergency_exit_opens_from_the_corridor_only() -> void:
	var exit: Door = _doors_near(Vector3(161.5, 0, 83.85), 0.3)[0]
	var inside := Node3D.new()
	var outside := Node3D.new()
	add_child_autofree(inside)
	add_child_autofree(outside)
	inside.global_position = _world(Vector3(161.5, 0, 82.5))
	outside.global_position = _world(Vector3(161.5, 0, 85.5))
	assert_false(exit.can_use(outside), "no handle outside")
	assert_true(exit.can_use(inside), "the crash bar")


func test_the_ais_never_plan_through_the_emergency_exit() -> void:
	var nav_map: RID = await _nav_map()
	var path := _path(nav_map, Vector3(161.5, 0, 82.5), Vector3(161.5, 0, 86))
	assert_gt(_length(path), 8.0, "around, by another door")


func test_the_offices_open_onto_each_other() -> void:
	var nav_map: RID = await _nav_map()
	# From the first office to the last one, through the doors between them:
	# barely longer than the straight line.
	var path := _path(nav_map, Vector3(175, 0, 64), Vector3(175, 0, 80))
	assert_lt(_length(path), 20.0)


func test_spots_of_every_family_in_the_social_centre() -> void:
	var centre: Building = _map.get_node("Buildings/SocialCentre")
	var families := {}
	for spot: HidingSpot in _map.get_node("Hideouts").get_children():
		if centre.contains(spot.global_position + Vector3.UP * 0.5):
			families[spot.family] = families.get(spot.family, 0) + 1
	assert_eq(families.get(HidingSpot.Family.CLOSET, 0), 3)
	assert_eq(families.get(HidingSpot.Family.LOW, 0), 2, "under the stage")
	assert_eq(families.get(HidingSpot.Family.MAKESHIFT, 0), 2, "the wings, the chairs")
	assert_eq(families.get(HidingSpot.Family.METAL, 0), 1, "the cold cabinet")
