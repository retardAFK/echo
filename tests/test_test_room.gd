extends GutTest
## The test room (spec S-023, Q8 and Q9, T-356 and T-357).

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role


func after_each() -> void:
	GameSession.role = _saved_role


func test_every_station_is_complete() -> void:
	var list: TestStationList = load("res://game/maps/test_room/stations.tres")
	assert_gt(list.stations.size(), 0)
	for station in list.stations:
		assert_ne(Text.t(station.name_key), station.name_key, "%s: a sign" % station.name_key)
		assert_not_null(station.scene, station.name_key)
		var thing := station.scene.instantiate()
		assert_true(thing is Node3D, "%s stands in the room" % station.name_key)
		thing.free()


func _open(role: GameSession.Role) -> GameMap:
	GameSession.role = role
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	return map


func test_the_room_has_its_stations_and_a_dummy_monster() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var rules := map.get_node("TestRoomRules") as TestRoom
	for station in rules.stations.stations:
		var thing := map.get_node_or_null(NodePath(station.name_key.to_pascal_case())) as Node3D
		assert_not_null(thing, station.name_key)
		if thing != null:
			assert_almost_eq(thing.global_position, station.position, Vector3.ONE * 0.01)
			assert_eq((thing.get_node("Sign") as Label3D).text, Text.t(station.name_key))
	assert_eq(map.monster.settings.catch_distance, 0.0, "a dummy: it never catches")
	assert_eq(map.game_loop, null, "no game loop: no end")


func test_gadgets_come_back() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(2)
	var player := map.player
	for gadget_def in GadgetList.default().gadgets:
		player.inventory.set_count(gadget_def.kind, 0)
	player.inventory.set_count(Inventory.Kind.BOTTLE, 0)
	TestRoom.refill(player)
	for id in player.loadout:
		var kind := GadgetList.default().by_id(id).kind
		assert_eq(player.inventory.count(kind), Loadout.SETTINGS.charges, str(id))
	assert_gt(player.inventory.count(Inventory.Kind.BOTTLE), 0)


func test_as_the_monster_a_hunted_dummy_walks() -> void:
	var map := _open(GameSession.Role.MONSTER)
	await wait_physics_frames(3)
	assert_not_null(map.avatar, "the monster is played")
	assert_not_null(map.prey, "the hunted dummy is the AI prey")
	assert_eq(map.avatar.settings.catch_distance, 0.0)
	var start := map.prey.global_position
	await wait_seconds(2.0)
	assert_gt(map.prey.global_position.distance_to(start), 0.5, "it walks")


func test_a_firecracker_deafens_the_dummy_monster() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	map.player.loadout = [&"firecracker", &"smoke"]
	var firecracker := GadgetUse.use_slot(map.player, 0) as Firecracker
	assert_not_null(firecracker)
	firecracker.arm_left = 0.0
	map.monster.global_position = firecracker.global_position + Vector3(0.5, 0, 0)
	assert_eq(Firecracker.burst_near(map.monster), 1, "the dummy sets it off like the real one")
	assert_true(map.monster.deafness.is_deaf())


func test_as_the_monster_the_scan_hears_the_hunted_dummy() -> void:
	var map := _open(GameSession.Role.MONSTER)
	await wait_physics_frames(3)
	var building: Building = map.get_buildings()[0]
	map.prey.global_position = building.get_box_transform().origin
	map.avatar.scan_target = building
	map.avatar.scan.start()
	map.avatar.scan.update(map.avatar.settings.scan_focus_time + 0.1)
	var step := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, map.prey.global_position, 4.0, map.prey)
	assert_true(map.avatar.scan_reveals(step), "its steps inside the scanned building")
