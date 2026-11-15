extends GutTest
## The AI prey plays the game loop when the player is the monster (spec S-007,
## T-058).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const THREAT := Vector3(30, 0, 0)

var _brain: PreyBrain
var _slots: Array[Vector3] = [Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0)]
var _hiding: Array[Vector3] = [Vector3(-20, 0, 0)]
var _transformer := Vector3(10, 0, 10)
var _exit := Vector3(0, 0, -50)


func before_each() -> void:
	_brain = PreyBrain.new(load("res://game/data/prey_settings.tres"))
	_brain.set_points([Vector3.ZERO, Vector3.ONE] as Array[Vector3], _hiding)
	_brain.set_loop(_slots, _transformer, _exit)


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED
	get_tree().paused = false


func _step(alarm := false, arrived := false, warning := false, delta := 0.1) -> void:
	_brain.update(delta, alarm, THREAT, arrived, warning)


func test_it_searches_the_slots_one_by_one() -> void:
	assert_eq(_brain.state, PreyBrain.State.SEARCH)
	assert_eq(_brain.target, _slots[0])
	_brain.next_slot()
	assert_eq(_brain.target, _slots[1], "an empty box: on to the next one")
	_brain.start_work()
	assert_eq(_brain.state, PreyBrain.State.WORK)
	assert_true(_brain.is_still(false), "it stays put while it holds")
	_brain.work_done(1, 3, false)
	assert_eq(_brain.state, PreyBrain.State.SEARCH)
	assert_eq(_brain.target, _slots[2])


func test_three_fuses_then_the_transformer_then_the_exit() -> void:
	_brain.start_work()
	_brain.work_done(3, 3, false)
	assert_eq(_brain.goal, PreyBrain.Goal.REPAIR)
	assert_eq(_brain.target, _transformer)
	_brain.start_work()
	_brain.work_done(3, 3, true)
	assert_eq(_brain.state, PreyBrain.State.ESCAPE)
	assert_eq(_brain.target, _exit)
	assert_eq(_brain.get_gait(), PlayerMotion.Gait.SPRINT, "it runs for the exit")


func test_its_caution_comes_first_then_it_goes_back_to_work() -> void:
	_brain.next_slot()
	_brain.start_work()
	_step(true)
	assert_eq(_brain.state, PreyBrain.State.FLEE, "the monster: it drops everything")
	_step(false, true)
	assert_eq(_brain.state, PreyBrain.State.HIDE)
	for i in 300:
		_step()
	assert_eq(_brain.state, PreyBrain.State.SEARCH, "back to its goal, not wandering")
	assert_eq(_brain.target, _slots[1], "the same box")


func test_it_freezes_under_a_scan_but_not_while_escaping() -> void:
	_brain.start_work()
	_step(false, false, true)
	assert_eq(_brain.state, PreyBrain.State.FREEZE)
	_step()
	assert_eq(_brain.state, PreyBrain.State.SEARCH)
	_brain.work_done(3, 3, true)
	_step(false, false, true)
	assert_eq(_brain.state, PreyBrain.State.ESCAPE)


func test_boxes_are_visited_building_by_building() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var ordered := Prey.order_boxes(map.get_fuse_boxes(), Vector3.ZERO)
	assert_eq(ordered.size(), 24)
	var changes := 0
	for i in range(1, ordered.size()):
		if ordered[i].building_name != ordered[i - 1].building_name:
			changes += 1
	assert_eq(changes, 3, "four buildings, each visited once")


func test_it_does_not_give_up_its_first_box_on_its_first_frames() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.end_screen.change_scene = false
	map.avatar.process_mode = Node.PROCESS_MODE_DISABLED
	map.avatar.global_position = Vector3(0, -50, 0)
	var prey := map.prey
	# Already standing on its first slot: no new target resets its stuck timer.
	# A full box there, so arriving keeps it on that slot too.
	prey._boxes[0].has_fuse = true
	prey.global_position = prey.brain.target
	await wait_physics_frames(5)
	assert_eq(prey.brain.slot_index, 0, "no new path yet is not being stuck")


func test_in_the_monster_role_the_prey_takes_a_fuse_and_repairs() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.end_screen.change_scene = false
	map.avatar.process_mode = Node.PROCESS_MODE_DISABLED
	map.avatar.global_position = Vector3(0, -50, 0)
	var prey := map.prey
	var loop := map.game_loop
	# No detour to a bottle lying near the box (S-008): this test is about the box.
	prey.settings = prey.settings.duplicate()
	prey.settings.pickup_detour = 0.0
	assert_true(prey.brain.is_looping())
	assert_eq(prey.get_state(), PreyBrain.State.SEARCH)
	# Straight to a full box, as if it had just walked there.
	var index := prey._boxes.find(loop.fused_boxes[0])
	prey.brain.slot_index = index
	prey.brain.target = prey._boxes[index].get_approach_point()
	prey.global_position = prey.brain.target
	await wait_until(
		# Generous: on a loaded CI runner, slow frames make game time lag real time.
		func() -> bool: return loop.rules.found() == 1,
		loop.settings.pickup_time + 15.0
	)
	assert_eq(loop.rules.found(), 1, "it held E on the box")
	# Then at the transformer with all the fuses, placements sped up.
	loop.rules.carried = 3
	loop.transformer.progress.duration = 0.3
	prey.brain.work_done(3, 3, false)
	prey.global_position = prey.brain.target
	await wait_until(func() -> bool: return loop.rules.is_repaired(), 5.0)
	await wait_physics_frames(2)
	assert_true(loop.rules.is_repaired())
	assert_eq(prey.get_state(), PreyBrain.State.ESCAPE)
