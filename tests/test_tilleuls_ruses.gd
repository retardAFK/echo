extends GutTest
## Ruses in the cité des Tilleuls (spec S-008, T-067): bottles, alarm clocks
## and hiding spots placed by build_tilleuls, within reach of the navigation.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const VISITABLE := ["Tower", "SocialCentre", "Gallery", "CarPark"]

var _map: GameMap


func _add_map() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _pickups(map: Node, kind: Inventory.Kind) -> Array[Pickup]:
	var found: Array[Pickup] = []
	for node in map.get_node("Pickups").find_children("*", "Node3D", true, false):
		var pickup := node as Pickup
		if pickup != null and pickup.kind == kind and not pickup.is_queued_for_deletion():
			found.append(pickup)
	return found


func _nav_map() -> RID:
	var nav_map := _map.get_world_3d().navigation_map
	var spawn: Vector3 = _map.get_spawn_points()[0]
	await wait_until(
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, spawn)
			return Vector2(closest.x, closest.z).distance_to(Vector2(spawn.x, spawn.z)) < 0.1,
		5
	)
	return nav_map


## End of the path from the spawn toward a point.
func _path_end(nav_map: RID, to: Vector3) -> Vector3:
	var path := NavigationServer3D.map_get_path(nav_map, _map.get_spawn_points()[0], to, true)
	return path[path.size() - 1] if path.size() > 0 else Vector3.INF


func test_twenty_bottles_and_ten_places_for_alarm_clocks() -> void:
	var map: Node = MAP_SCENE.instantiate()  # Out of the tree: no game drawn yet.
	assert_eq(_pickups(map, Inventory.Kind.BOTTLE).size(), 20)
	assert_eq(_pickups(map, Inventory.Kind.DECOY).size(), 10)
	map.free()


func test_a_game_keeps_four_alarm_clocks_and_every_bottle() -> void:
	_add_map()
	var settings: RuseSettings = _pickups(_map, Inventory.Kind.BOTTLE)[0].settings
	assert_eq(_pickups(_map, Inventory.Kind.DECOY).size(), settings.decoys_per_game)
	assert_eq(_pickups(_map, Inventory.Kind.BOTTLE).size(), 20)


func test_three_closets_in_each_visitable_building_and_six_dumpsters_outside() -> void:
	_add_map()
	var spots := _map.get_hiding_spots()
	assert_eq(spots.size(), 18)
	var closets := {}
	var outside := 0
	for spot in spots:
		var inside := ""
		for building in _map.get_buildings():
			if building.contains(spot.global_position + Vector3.UP * 0.5):
				inside = String(building.name)
		if spot.crouched:
			assert_eq(inside, "", "%s stands outside" % spot.name)
			outside += 1
		else:
			closets[inside] = closets.get(inside, 0) + 1
	assert_eq(outside, 6)
	for building_name: String in VISITABLE:
		assert_eq(closets.get(building_name, 0), 3, building_name)


func test_each_hiding_spot_opens_onto_the_navigation() -> void:
	_add_map()
	var nav_map: RID = await _nav_map()
	for spot in _map.get_hiding_spots():
		var exit := spot.get_exit_point()
		var end := _path_end(nav_map, exit)
		assert_lt(Vector2(end.x, end.z).distance_to(Vector2(exit.x, exit.z)), 0.6, spot.name)
		assert_lt(absf(end.y - exit.y), 1.0, spot.name)


func test_each_pickup_can_be_reached_and_taken() -> void:
	_add_map()
	var nav_map: RID = await _nav_map()
	var pickups := _pickups(_map, Inventory.Kind.BOTTLE)
	pickups.append_array(_pickups(_map, Inventory.Kind.DECOY))
	for pickup in pickups:
		var end := _path_end(nav_map, pickup.global_position)
		assert_true(pickup.can_interact(end + Vector3.UP * 0.3), "%s %s" % [pickup.name, end])
