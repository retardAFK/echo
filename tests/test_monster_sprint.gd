extends GutTest
## The monster's run as a gauge (S-020, T-309, piste E2).

const SETTINGS := preload("res://game/data/monster_settings.tres")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")


func test_six_m_s_for_five_seconds_then_five_for_four() -> void:
	var sprint := MonsterSprint.new(SETTINGS)
	assert_eq(sprint.run_speed(), 6.0)
	for i in 299:  # Five seconds of running, a frame short.
		sprint.update(1.0 / 60.0, true)
	assert_false(sprint.is_winded())
	sprint.update(2.0 / 60.0, true)
	assert_true(sprint.is_winded(), "out of breath")
	assert_eq(sprint.run_speed(), 5.0, "slower than a sprinting hunted")
	assert_lt(sprint.run_speed(), PlayerSettings.new().sprint_speed)
	for i in 239:
		sprint.update(1.0 / 60.0, true)
	assert_true(sprint.is_winded(), "for four seconds")
	sprint.update(2.0 / 60.0, true)
	assert_false(sprint.is_winded())
	assert_eq(sprint.get_ratio(), 1.0, "then full again")


func test_walking_refills_the_gauge() -> void:
	var sprint := MonsterSprint.new(SETTINGS)
	sprint.update(3.0, true)
	assert_almost_eq(sprint.get_ratio(), 0.4, 0.001)
	sprint.update(2.0, false)
	assert_almost_eq(sprint.get_ratio(), 0.8, 0.001)
	sprint.update(10.0, false)
	assert_eq(sprint.get_ratio(), 1.0)


func test_the_played_monster_slows_down_and_sees_its_gauge() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child_autofree(ground)
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)
	await wait_physics_frames(2)
	assert_eq(avatar.get_speed(), SETTINGS.walk_speed)
	avatar.move(Vector2(0, -1), true, 1.0 / 60.0)
	assert_eq(avatar.get_speed(), SETTINGS.run_speed)
	avatar.sprint.update(SETTINGS.sprint_time, true)
	assert_eq(avatar.get_speed(), SETTINGS.winded_speed)
	var bar: SprintBar = avatar.get_node("SprintBar")
	bar._process(0.0)
	assert_almost_eq(bar.get_fill(), 0.0, 0.01, "empty: out of breath")
	assert_eq(MonsterBrain.speed_for(MonsterBrain.Pace.RUN, SETTINGS), SETTINGS.run_speed)


func test_the_ai_monster_has_a_gauge_too() -> void:
	var monster: Monster = preload("res://game/entities/monster/monster.tscn").instantiate()
	add_child_autofree(monster)
	assert_not_null(monster.sprint)
	monster.sprint.update(SETTINGS.sprint_time, true)
	assert_eq(MonsterBrain.speed_for(MonsterBrain.Pace.RUN, SETTINGS, monster.sprint), 5.0)
