extends GutTest
## The AI monster scans buildings (spec S-009, Q3, T-078).

const SETTINGS := preload("res://game/data/monster_settings.tres")
const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
## Inside and next to the greybox building (as in test_building_scan.gd).
const INSIDE := Vector3(-11, 0.3, 13)
const NEAR := Vector3(-24, 0.3, 13)
const FAR := Vector3(19, 0.3, -18)

var _brain: MonsterBrain
var _patrol: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]


func before_each() -> void:
	_brain = MonsterBrain.new(SETTINGS)
	_brain.set_patrol(_patrol)


func _idle(delta := 0.1, arrived := false) -> void:
	_brain.update(delta, false, Vector3.ZERO, 0.0, false, arrived)


func test_settings_match_clarifications() -> void:
	assert_eq(SETTINGS.ai_scan_radius, 15.0)
	assert_eq(SETTINGS.ai_scan_time, 4.0)
	assert_eq(SETTINGS.ai_scan_cooldown, 30.0)


func test_trace_lost_after_an_empty_investigation() -> void:
	watch_signals(_brain)
	_brain.hear(Vector3(5, 0, 5))
	_idle(0.1, true)
	for i in int(SETTINGS.investigate_time / 0.1) + 2:
		_idle()
	assert_eq(_brain.state, MonsterBrain.State.PATROL)
	assert_signal_emitted_with_parameters(_brain, "trace_lost", [Vector3(5, 0, 5)])


func test_scan_needs_the_gauge() -> void:
	assert_false(_brain.can_scan("tower", false))
	assert_true(_brain.can_scan("tower", true))


func test_no_scan_during_a_chase() -> void:
	for i in 20:
		_brain.update(0.1, true, Vector3(1, 0, 1), 2.0, false, false)
	assert_eq(_brain.state, MonsterBrain.State.CHASE)
	assert_false(_brain.can_scan("tower", true))


func test_scan_stands_still_then_ends() -> void:
	watch_signals(_brain)
	_brain.start_scan("tower", Vector3(3, 0, 3))
	assert_eq(_brain.state, MonsterBrain.State.SCAN)
	assert_eq(_brain.target, Vector3(3, 0, 3))
	assert_false(_brain.can_scan("other", true), "one scan at a time")
	for i in int(SETTINGS.ai_scan_time / 0.1) + 1:
		_idle()
	assert_eq(_brain.state, MonsterBrain.State.PATROL)
	assert_signal_emitted(_brain, "scan_finished")


func test_same_building_waits_for_the_cooldown() -> void:
	_brain.start_scan("tower", Vector3.ZERO)
	_brain.stop_scan()
	assert_false(_brain.can_scan("tower", true))
	assert_true(_brain.can_scan("gallery", true))
	for i in int(SETTINGS.ai_scan_cooldown / 0.5) + 1:
		_idle(0.5)
	assert_true(_brain.can_scan("tower", true))


func test_a_noise_ends_the_scan() -> void:
	watch_signals(_brain)
	_brain.start_scan("tower", Vector3.ZERO)
	_brain.hear(Vector3(7, 0, 7))
	assert_eq(_brain.state, MonsterBrain.State.INVESTIGATE)
	assert_eq(_brain.target, Vector3(7, 0, 7))
	assert_signal_emitted(_brain, "scan_finished")


func test_spotting_ends_the_scan() -> void:
	_brain.start_scan("tower", Vector3.ZERO)
	for i in 20:
		_brain.update(0.1, true, Vector3(1, 0, 1), 2.0, false, false)
	assert_eq(_brain.state, MonsterBrain.State.CHASE)


func _map_monster() -> Array:
	GameSession.role = GameSession.Role.HUNTED
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	monster.set_physics_process(false)  # Driven by hand.
	await wait_physics_frames(2)
	return [map, monster, map.get_node("Building")]


func test_building_distance() -> void:
	var parts: Array = await _map_monster()
	var building: Building = parts[2]
	assert_eq(building.distance_to(INSIDE), 0.0)
	assert_gt(building.distance_to(NEAR), 0.0)
	assert_lt(building.distance_to(NEAR), SETTINGS.ai_scan_radius)


func test_monster_scans_the_building_near_a_lost_trace() -> void:
	var parts: Array = await _map_monster()
	var monster: Monster = parts[1]
	var building: Building = parts[2]
	monster.global_position = NEAR
	monster.brain.trace_lost.emit(NEAR)
	assert_eq(monster.scan_target, building)
	assert_true(building.scanned, "its lights flicker")
	assert_eq(monster.get_state(), MonsterBrain.State.SCAN)
	assert_true(monster.scan.active)


func test_no_scan_far_from_buildings() -> void:
	var parts: Array = await _map_monster()
	var monster: Monster = parts[1]
	monster.global_position = FAR
	monster.brain.trace_lost.emit(FAR)
	assert_null(monster.scan_target)
	assert_ne(monster.get_state(), MonsterBrain.State.SCAN)


func test_no_scan_below_the_gauge_threshold() -> void:
	var parts: Array = await _map_monster()
	var monster: Monster = parts[1]
	monster.scan.level = SETTINGS.scan_capacity * (SETTINGS.scan_min_start - 0.05)
	monster.brain.trace_lost.emit(NEAR)
	assert_null(monster.scan_target)


func test_scan_hears_a_faint_noise_inside() -> void:
	var parts: Array = await _map_monster()
	var monster: Monster = parts[1]
	var building: Building = parts[2]
	monster.global_position = NEAR
	monster.brain.trace_lost.emit(NEAR)
	monster.scan.update(SETTINGS.scan_focus_time + 0.1)  # Concentration over.
	assert_true(monster.scan.is_listening())
	# A breath, far too faint to be heard from outside without the scan.
	NoiseBus.emit_noise(NoiseEvent.Type.BREATH, INSIDE, 0.5)
	assert_eq(monster.get_state(), MonsterBrain.State.INVESTIGATE)
	assert_eq(monster.brain.target, INSIDE)
	monster._physics_process(0.016)
	assert_null(monster.scan_target, "the scan ended")
	assert_false(building.scanned)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED
