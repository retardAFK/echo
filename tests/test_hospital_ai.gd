extends GutTest
## The AIs in the hospital (spec S-014, T-192): the monster picks the level it
## scans and switches beeping monitors off; the prey, fleeing, switches a
## monitor on and sends a wheelchair rolling as decoys.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const ORIGIN := Vector3(110, 0, 110)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED


func _world(x: float, h: float, y: float) -> Vector3:
	return Vector3(x, h, y) - ORIGIN


func _level(map: GameMap, level_name: String) -> Building:
	return map.get_node("Buildings/" + level_name)


func test_the_monster_scans_the_level_it_stands_in() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	var ground := _level(map, "HospitalGround")
	monster.global_position = _world(21.0, 3.1, 90.0)  # 1st floor corridor.
	assert_eq(monster.scan_choice(ground), _level(map, "HospitalFirst"))


func test_from_outside_it_scans_the_level_it_heard() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	monster.global_position = _world(40.0, 0.1, 100.0)  # In the street.
	await wait_physics_frames(2)
	monster.set("_heard_in", {"Hospital": _world(21.0, 7.0, 110.0)})
	var ground := _level(map, "HospitalGround")
	assert_eq(monster.scan_choice(ground), _level(map, "HospitalSecond"))
	monster.set("_heard_in", {})
	var picked := monster.scan_choice(ground)
	assert_eq(picked.complex, "Hospital", "one level at random")


func test_a_plain_building_is_scanned_as_it_is() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	for building in monster.buildings:
		if building.complex == "":
			assert_eq(monster.scan_choice(building), building)
			return


func test_the_monster_switches_off_a_beeping_monitor_it_passes() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monitor: Monitor = map.get_node("Monitors/Monitor1")
	monitor.interact(map.get_node("Player"))
	assert_eq(monitor.state, Monitor.State.BEEPING)
	var monster: Monster = map.get_node("Monster")
	monster.global_position = monitor.global_position + Vector3(0.8, 0.1, 0)
	await wait_physics_frames(3)
	assert_eq(monitor.state, Monitor.State.SPENT)


func test_the_fleeing_prey_uses_monitors_and_wheelchairs() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var prey: Prey = map.prey
	prey.process_mode = Node.PROCESS_MODE_DISABLED
	var monitor: Monitor = map.get_node("Monitors/Monitor1")
	prey.global_position = monitor.global_position + Vector3(0.6, 0.1, 0)
	prey.call("_use_hospital_decoys", prey.global_position + Vector3(0, 0, 10))
	assert_eq(monitor.state, Monitor.State.BEEPING)
	assert_eq(prey.ruse_counts.get(&"monitor", 0), 1)
	var chair: Wheelchair = map.get_node("Rolling/Wheelchair1")
	prey.global_position = chair.global_position + Vector3(0.8, 0.1, 0)
	prey.call("_use_hospital_decoys", prey.global_position + Vector3(0, 0, 10))
	await wait_physics_frames(2)
	assert_true(chair.is_rolling())
	assert_eq(prey.ruse_counts.get(&"wheelchair", 0), 1)
	var heading := chair.velocity.normalized()
	assert_almost_eq(absf(heading.x), 1.0, 0.05, "sideways to the threat")
