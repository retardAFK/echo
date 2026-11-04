extends GutTest
## Decisions of the AI prey (spec S-004, Q4 and Q5, T-025).

const WANDER: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(0, 0, 10)]
const HIDES: Array[Vector3] = [Vector3(-10, 0, 0), Vector3(20, 0, 20)]

var _settings := PreySettings.new()
var _brain: PreyBrain


func before_each() -> void:
	_brain = PreyBrain.new(_settings, 1)
	_brain.set_points(WANDER, HIDES)


func _step(alarm := false, arrived := false, warning := false, seconds := 0.1) -> void:
	_brain.update(seconds, alarm, Vector3(-12, 0, 0), arrived, warning)


func test_wanders_walking() -> void:
	assert_eq(_brain.state, PreyBrain.State.WANDER)
	assert_eq(_brain.get_gait(), PlayerMotion.Gait.WALK)
	assert_eq(_brain.target, WANDER[0])


func test_pauses_then_goes_to_another_point() -> void:
	_step(false, true, false, _settings.wander_pause / 2.0)
	assert_eq(_brain.target, WANDER[0], "still pausing")
	_step(false, true, false, _settings.wander_pause)
	assert_ne(_brain.target, WANDER[0])
	assert_true(WANDER.has(_brain.target))


func test_alarm_sends_it_running_to_the_farthest_hiding_spot() -> void:
	_step(true)
	assert_eq(_brain.state, PreyBrain.State.FLEE)
	assert_eq(_brain.get_gait(), PlayerMotion.Gait.SPRINT)
	assert_eq(_brain.target, HIDES[1], "the spot farthest from the monster at (-12, 0, 0)")


func test_hides_crouched_then_wanders_again() -> void:
	_step(true)
	_step(false, true)
	assert_eq(_brain.state, PreyBrain.State.HIDE)
	assert_eq(_brain.get_gait(), PlayerMotion.Gait.CROUCH)
	assert_true(_brain.is_still(false))
	_step(false, true, false, _settings.hide_time - 1.0)
	assert_eq(_brain.state, PreyBrain.State.HIDE)
	_step(false, true, false, 1.5)
	assert_eq(_brain.state, PreyBrain.State.WANDER)


func test_hearing_the_monster_while_hidden_keeps_it_hidden() -> void:
	_step(true)
	_step(false, true)
	_step(false, true, false, _settings.hide_time - 1.0)
	_step(true, true)
	_step(false, true, false, 5.0)
	assert_eq(_brain.state, PreyBrain.State.HIDE)


func test_out_of_breath_for_ten_seconds_after_running() -> void:
	assert_false(_brain.is_breathless())
	_step(true)
	_step(false, false, false, 3.0)
	_step(false, true)
	assert_true(_brain.is_breathless())
	_step(false, true, false, _settings.breathless_time - 1.0)
	assert_true(_brain.is_breathless())
	_step(false, true, false, 1.5)
	assert_false(_brain.is_breathless())


func test_freezes_on_the_scan_warning_until_it_ends() -> void:
	_step(false, false, true)
	assert_eq(_brain.state, PreyBrain.State.FREEZE)
	assert_true(_brain.is_still(false))
	_step(false, false, true, 3.0)
	assert_eq(_brain.state, PreyBrain.State.FREEZE)
	_step()
	assert_eq(_brain.state, PreyBrain.State.WANDER)


func test_frozen_prey_still_flees_from_an_alarm() -> void:
	_step(false, false, true)
	_step(true, false, true)
	assert_eq(_brain.state, PreyBrain.State.FLEE)


func test_giving_up_a_flight_hides_on_the_spot() -> void:
	_step(true)
	_brain.give_up()
	assert_eq(_brain.state, PreyBrain.State.HIDE)


func test_giving_up_a_wander_point_picks_another() -> void:
	_brain.give_up()
	assert_ne(_brain.target, WANDER[0])
