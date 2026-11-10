extends GutTest
## The visitable buildings of the cité des Tilleuls (spec S-006, Q3 to Q6, T-040).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const ORIGIN := Vector3(110, 0, 110)
const VISITABLE := ["Tower", "SocialCentre", "Gallery", "CarPark"]
const SCANNABLE := ["Tower", "SocialCentre", "Gallery", "CarPark", "Garages"]
const FACADES := ["BarreA", "BarreB", "BarreC", "BarreD", "BarreE", "BarreF", "BarreG"]
## A fuse slot must be reachable by the AI monster: the end of the path is this close.
const REACH := 1.0

var _map: GameMap


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func _building(building_name: String) -> Building:
	return _map.get_node("Buildings/%s" % building_name)


func _slots(building_name: String) -> Array[Vector3]:
	return Prey.markers_of(_map.get_node("FuseSlots/%s" % building_name))


func _nav_map() -> RID:
	# The navigation map is shared by every test: wait until this map's mesh is
	# merged, that is until a spawn point lies on it.
	var nav_map := _map.get_world_3d().navigation_map
	var spawn: Vector3 = _map.get_spawn_points()[0]
	await wait_until(
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, spawn)
			return Vector2(closest.x, closest.z).distance_to(Vector2(spawn.x, spawn.z)) < 0.1,
		5
	)
	return nav_map


func test_only_the_planned_targets_can_be_scanned() -> void:
	var names: Array[String] = []
	for building in _map.get_buildings():
		names.append(String(building.name))
	names.sort()
	var expected: Array[String] = []
	expected.assign(SCANNABLE)
	expected.sort()
	assert_eq(names, expected, "Q6: the 4 visitable buildings and the garages")


func test_facades_are_not_scannable() -> void:
	for facade in FACADES:
		var mesh: MeshInstance3D = _map.get_node("Structures/%s/Mesh" % facade)
		var center := mesh.global_transform * mesh.get_aabb().get_center()
		for building in _map.get_buildings():
			assert_false(building.contains(center), "%s is not in %s" % [facade, building.name])


func test_each_visitable_building_has_four_fuse_slots_inside() -> void:
	for building_name in VISITABLE:
		var slots := _slots(building_name)
		assert_eq(slots.size(), 4, building_name)
		for slot in slots:
			assert_true(
				_building(building_name).contains(slot + Vector3.UP * 0.5),
				"%s slot %s" % [building_name, slot + ORIGIN]
			)
	assert_eq(get_tree().get_nodes_in_group("fuse_slot").size(), 16)


func test_fuse_slots_stand_on_a_floor() -> void:
	await wait_physics_frames(2)
	var space := _map.get_world_3d().direct_space_state
	for slot in get_tree().get_nodes_in_group("fuse_slot"):
		var at: Vector3 = slot.global_position
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN, 1)
		var hit := space.intersect_ray(query)
		assert_false(hit.is_empty(), "floor under %s" % (at + ORIGIN))
		if not hit.is_empty():
			assert_almost_eq(hit["position"].y, at.y, 0.1, "floor under %s" % (at + ORIGIN))


func test_every_fuse_slot_can_be_reached_from_a_spawn() -> void:
	var nav_map: RID = await _nav_map()
	var start: Vector3 = _map.get_spawn_points()[0]
	for slot in get_tree().get_nodes_in_group("fuse_slot"):
		var at: Vector3 = slot.global_position
		var path := NavigationServer3D.map_get_path(nav_map, start, at, true)
		assert_gt(path.size(), 1, "path to %s" % (at + ORIGIN))
		if path.size() > 1:
			var end := path[path.size() - 1]
			assert_lt(
				Vector2(end.x, end.z).distance_to(Vector2(at.x, at.z)),
				REACH,
				"path to %s" % (at + ORIGIN)
			)
			assert_lt(absf(end.y - at.y), REACH, "path to %s" % (at + ORIGIN))


func test_tower_top_landing_is_closed_by_a_grille() -> void:
	# Q4: past the 4th floor the stairs are closed; nothing walkable above 13 m.
	var nav_map: RID = await _nav_map()
	var start: Vector3 = _map.get_spawn_points()[0]
	var above := Vector3(102, 13.5, 92) - ORIGIN
	var path := NavigationServer3D.map_get_path(nav_map, start, above, true)
	var end := path[path.size() - 1] if path.size() > 0 else start
	assert_lt(end.y, 12.5, "the grille stops the climb at the 4th floor")


func test_scan_volumes_cover_the_inside() -> void:
	var tower := _building("Tower")
	assert_true(tower.contains(Vector3(104, 13, 108) - ORIGIN), "4th floor is in the tower scan")
	assert_false(tower.contains(Vector3(104, 20, 100) - ORIGIN), "the closed storeys are not")
	assert_true(_building("CarPark").contains(Vector3(160, -2, 106) - ORIGIN))
	assert_true(_building("Garages").contains(Vector3(13, 1, 158) - ORIGIN))
