extends GutTest
## Monster state machine (spec S-003, T-014).

const SETTINGS_PATH := "res://game/data/monster_settings.tres"
const EPSILON := 0.0001
const NOISE_POS := Vector3(5, 0, 5)
const PLAYER_POS := Vector3(-3, 0, 2)

var _settings: MonsterSettings
var _brain: MonsterBrain
var _patrol: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]


func before_each() -> void:
	_settings = load(SETTINGS_PATH)
	_brain = MonsterBrain.new(_settings)
	_brain.set_patrol(_patrol)


## One frame where the monster neither sees the player nor arrives.
func _idle(delta := 0.1, arrived := false) -> void:
	_brain.update(delta, false, Vector3.ZERO, 0.0, false, arrived)


func _see(delta := 0.1, distance := 2.0, crouched := false) -> void:
	_brain.update(delta, true, PLAYER_POS, distance, crouched, false)


func _spot() -> void:
	for i in 20:
		_see()


func test_settings_match_clarifications() -> void:
	assert_eq(_settings.prowl_speed, 1.5)
	assert_eq(_settings.walk_speed, 3.5)
	assert_eq(_settings.run_speed, 6.0)
	assert_eq(_settings.prowl_range, 0.0)
	assert_eq(_settings.walk_range, 3.0)
	assert_eq(_settings.run_range, 12.0)
	assert_eq(_settings.vision_angle, 100.0)
	assert_eq(_settings.vision_range, 25.0)
	assert_eq(_settings.investigate_time, 6.0)


func test_patrol_walks_the_route_silently() -> void:
	assert_eq(_brain.state, MonsterBrain.State.PATROL)
	assert_eq(_brain.target, _patrol[0])
	assert_eq(_brain.get_pace(), MonsterBrain.Pace.PROWL)
	_idle(0.1, true)
	assert_eq(_brain.target, _patrol[1])
	_idle(0.1, true)
	_idle(0.1, true)
	assert_eq(_brain.target, _patrol[0], "loops back to the first point")


func test_noise_starts_investigation_at_walking_pace() -> void:
	_brain.hear(NOISE_POS)
	assert_eq(_brain.state, MonsterBrain.State.INVESTIGATE)
	assert_eq(_brain.target, NOISE_POS)
	assert_eq(_brain.get_pace(), MonsterBrain.Pace.WALK)


func test_investigation_lingers_then_patrols() -> void:
	_brain.hear(NOISE_POS)
	_idle(1.0)
	assert_false(_brain.lingering, "the timer waits for arrival")
	_idle(0.1, true)
	assert_true(_brain.lingering)
	assert_eq(_brain.get_pace(), MonsterBrain.Pace.PROWL)
	_idle(_settings.investigate_time)
	assert_eq(_brain.state, MonsterBrain.State.PATROL)
	assert_false(_brain.lingering)


func test_new_noise_replaces_investigation() -> void:
	_brain.hear(NOISE_POS)
	_idle(0.1, true)
	_idle(3.0)
	var other := Vector3(1, 0, 9)
	_brain.hear(other)
	assert_eq(_brain.target, other)
	assert_false(_brain.lingering, "goes to the new noise first")


func test_spot_time_grows_with_distance_and_crouch() -> void:
	var near := MonsterBrain.spot_time(0.0, false, _settings)
	var far := MonsterBrain.spot_time(_settings.vision_range, false, _settings)
	assert_almost_eq(near, 0.4, EPSILON)
	assert_almost_eq(far, 1.5, EPSILON)
	assert_almost_eq(MonsterBrain.spot_time(0.0, true, _settings), 0.8, EPSILON)


func test_spotting_is_not_instant() -> void:
	_see(0.1)
	assert_eq(_brain.state, MonsterBrain.State.PATROL)
	assert_between(_brain.spot_level, 0.0, 1.0)


func test_full_gauge_starts_chase_at_run_pace() -> void:
	_spot()
	assert_eq(_brain.state, MonsterBrain.State.CHASE)
	assert_eq(_brain.target, PLAYER_POS)
	assert_eq(_brain.get_pace(), MonsterBrain.Pace.RUN)


func test_gauge_empties_out_of_sight() -> void:
	_see(0.1)
	_idle(_settings.spot_decay_time)
	assert_eq(_brain.spot_level, 0.0)


func test_noise_ignored_during_chase() -> void:
	_spot()
	_brain.hear(NOISE_POS)
	assert_eq(_brain.state, MonsterBrain.State.CHASE)


func test_losing_sight_turns_chase_into_search() -> void:
	_spot()
	_idle(_settings.lose_sight_time - 0.5)
	assert_eq(_brain.state, MonsterBrain.State.CHASE, "keeps running to the last seen spot")
	_idle(0.6)
	assert_eq(_brain.state, MonsterBrain.State.SEARCH)
	assert_eq(_brain.target, PLAYER_POS)
	assert_eq(_brain.get_pace(), MonsterBrain.Pace.RUN)


func test_search_lingers_then_patrols() -> void:
	_spot()
	_idle(_settings.lose_sight_time + 0.1)
	_idle(0.1, true)
	assert_true(_brain.lingering)
	_idle(_settings.search_time)
	assert_eq(_brain.state, MonsterBrain.State.PATROL)


func test_seeing_again_during_search_restarts_chase() -> void:
	_spot()
	_idle(_settings.lose_sight_time + 0.1)
	_spot()
	assert_eq(_brain.state, MonsterBrain.State.CHASE)


func test_state_changes_are_signalled() -> void:
	watch_signals(_brain)
	_brain.hear(NOISE_POS)
	assert_signal_emitted_with_parameters(_brain, "state_changed", [MonsterBrain.State.INVESTIGATE])


func test_catch_distance() -> void:
	assert_true(_brain.is_catch_distance(1.0))
	assert_false(_brain.is_catch_distance(2.0))


func test_farthest_patrol_point() -> void:
	assert_eq(MonsterBrain.farthest_index(_patrol, Vector3(0, 0, 1)), 2)
	_brain.set_patrol(_patrol, 2)
	assert_eq(_brain.target, _patrol[2])
