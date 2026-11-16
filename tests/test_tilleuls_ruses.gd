extends GutTest
## Ruses in the cité des Tilleuls (spec S-008, T-067): bottles, alarm clocks
## and hiding spots placed by build_tilleuls, within reach of the navigation.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const VISITABLE := ["Tower", "SocialCentre", "Gallery", "CarPark"]
## A hiding spot this close to a door, in meters, would catch the aim of whoever
## opens it (T-167).
const DOORWAY_CLEARANCE := 1.0

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
	await wait_until(func() -> bool: return NavigationServer3D.map_get_iteration_id(nav_map) > 0, 5)
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
	var closet_family := spots.filter(
		func(spot: HidingSpot) -> bool: return spot.family == HidingSpot.Family.CLOSET
	)
	assert_eq(closet_family.size(), 18, "the other families come on top (S-016)")
	assert_eq(spots.size(), 40, "about 40 hiding spots in all (S-016, Q6)")
	var closets := {}
	var outside := 0
	for spot in spots:
		if spot.family != HidingSpot.Family.CLOSET:
			continue
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


func test_no_hiding_spot_stands_against_a_fuse_box() -> void:
	# A closet once stood on a fuse box of the gallery: its body muffled the
	# box, and the monster beside it did not hear the fuse being taken.
	_add_map()
	await wait_physics_frames(2)
	var monster: Monster = _map.get_node("Monster")
	monster.player = null
	for box: FuseBox in _map.get_fuse_boxes():
		monster.global_position = box.get_approach_point()
		var noise := NoiseEvent.new(NoiseEvent.Type.FUSE, box.global_position, 3.0, null)
		assert_true(NoiseBus.can_hear(noise, monster.get_ear_position()), str(box.get_path()))


func test_no_alarm_clock_lies_in_front_of_a_fuse_box() -> void:
	# An alarm clock once lay on a fuse slot of the gallery: when both were
	# drawn, it caught the aim in front of the box and the box could not be
	# used (the online test of 4 players got stuck there).
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var slots := map.get_node("FuseSlots").find_children("Slot*", "Marker3D")
	assert_gt(slots.size(), 0)
	for pickup in _pickups(map, Inventory.Kind.DECOY):
		for slot: Marker3D in slots:
			var gap := pickup.global_position.distance_to(slot.global_position)
			assert_gt(gap, 2.0, "%s near %s" % [pickup.name, slot.get_path()])


func test_no_hiding_spot_stands_where_a_fuse_box_is_used() -> void:
	# A closet of the gallery once stood where one uses a fuse box: it
	# blocked the way and caught the aim (the online test of 4 players got
	# stuck there, S-018).
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var spots := map.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node is HidingSpot
	)
	assert_gt(spots.size(), 0)
	for box: FuseBox in map.get_fuse_boxes():
		var at := box.get_approach_point()
		for spot: Node3D in spots:
			var gap := Vector2(spot.global_position.x - at.x, spot.global_position.z - at.z)
			var near := gap.length() < 1.5 and absf(spot.global_position.y - at.y) < 2.0
			assert_false(near, "%s near %s" % [spot.name, box.get_path()])


func test_no_hiding_spot_stands_in_a_doorway() -> void:
	# The boxes of the tobacconist once stood by its back door: they caught
	# the aim of whoever opened the door, who hid in them instead, and the
	# AI monster stayed caught on them (the online test of 4 players got
	# stuck there, T-167).
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var spots := map.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node is HidingSpot
	)
	for node in map.get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		for spot: Node3D in spots:
			var flat := door.closest_flat_point(spot.global_position)
			var gap := flat.distance_to(Vector2(spot.global_position.x, spot.global_position.z))
			var near := (
				gap < DOORWAY_CLEARANCE
				and absf(spot.global_position.y - door.global_position.y) < 2.0
			)
			assert_false(near, "%s near %s (%.2f m)" % [spot.name, door.name, gap])
