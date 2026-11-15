extends GutTest
## The hunter's animated body (spec S-011, T-123): which animation for which
## speed and action, how fast it plays, and where it is used.

const SETTINGS := preload("res://game/data/monster_body_settings.tres")
const NONE := MonsterBody.Action.NONE


func test_speed_picks_idle_prowl_walk_or_run() -> void:
	assert_eq(MonsterBody.pick(0.0, NONE, SETTINGS), MonsterBody.IDLE)
	assert_eq(MonsterBody.pick(1.5, NONE, SETTINGS), MonsterBody.PROWL)
	assert_eq(MonsterBody.pick(3.5, NONE, SETTINGS), MonsterBody.WALK)
	assert_eq(MonsterBody.pick(6.0, NONE, SETTINGS), MonsterBody.RUN)


func test_actions_come_before_speed() -> void:
	assert_eq(MonsterBody.pick(3.0, MonsterBody.Action.SCAN, SETTINGS), MonsterBody.SCAN)
	assert_eq(MonsterBody.pick(0.0, MonsterBody.Action.OPEN, SETTINGS), MonsterBody.REACH)
	assert_eq(MonsterBody.pick(6.0, MonsterBody.Action.CATCH, SETTINGS), MonsterBody.CATCH)
	assert_eq(MonsterBody.pick(1.5, MonsterBody.Action.CRUSH, SETTINGS), MonsterBody.CRUSH)


func test_one_shots_last_as_long_as_their_animation() -> void:
	var model: Node = (load(MonsterBody.MODEL) as PackedScene).instantiate()
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	assert_almost_eq(player.get_animation(MonsterBody.CATCH).length, SETTINGS.catch_time, 0.05)
	assert_almost_eq(player.get_animation(MonsterBody.CRUSH).length, SETTINGS.crush_time, 0.05)
	model.free()


func test_the_catch_shows_the_monster_two_seconds_at_most() -> void:
	# Art direction 2.3: never more than 2 s of the monster in a row.
	var monster_settings: MonsterSettings = load("res://game/data/monster_settings.tres")
	assert_lte(monster_settings.catch_show_time, 2.0)
	assert_lte(SETTINGS.catch_time, monster_settings.catch_show_time)


func test_the_head_turns_to_the_catcher() -> void:
	var ahead := PlayerMotion.look_angles(Vector3.ZERO, Vector3(0, 0, -5))
	assert_almost_eq(ahead, Vector2.ZERO, Vector2.ONE * 0.001)
	var right := PlayerMotion.look_angles(Vector3.ZERO, Vector3(5, 0, 0))
	assert_almost_eq(right.x, -PI / 2.0, 0.001, "to the right: yaw turns clockwise")
	var up := PlayerMotion.look_angles(Vector3.ZERO, Vector3(0, 1, -1))
	assert_almost_eq(up.y, PI / 4.0, 0.001, "eyes above: the head tilts up")


func test_brain_states_give_their_action() -> void:
	assert_eq(MonsterBody.action_for(MonsterBrain.State.SCAN), MonsterBody.Action.SCAN)
	assert_eq(MonsterBody.action_for(MonsterBrain.State.OPEN), MonsterBody.Action.OPEN)
	assert_eq(MonsterBody.action_for(MonsterBrain.State.CHASE), NONE)


func test_playback_follows_speed_within_bounds() -> void:
	assert_almost_eq(
		MonsterBody.playback_scale(MonsterBody.RUN, SETTINGS.run_speed, SETTINGS), 1.0, 0.001
	)
	assert_eq(MonsterBody.playback_scale(MonsterBody.PROWL, 0.01, SETTINGS), SETTINGS.min_scale)
	assert_eq(MonsterBody.playback_scale(MonsterBody.SCAN, 5.0, SETTINGS), 1.0)


func test_model_has_every_animation_and_faces_forward() -> void:
	var model: Node = (load(MonsterBody.MODEL) as PackedScene).instantiate()
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	for anim in [
		MonsterBody.IDLE,
		MonsterBody.PROWL,
		MonsterBody.WALK,
		MonsterBody.RUN,
		MonsterBody.SCAN,
		MonsterBody.REACH,
		MonsterBody.CATCH,
		MonsterBody.CRUSH
	]:
		assert_true(player.has_animation(anim), String(anim))
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot_l")).origin
	var toes := skeleton.get_bone_global_rest(skeleton.find_bone("ball_l")).origin
	assert_lt(toes.z, ankle.z)
	model.free()


func test_monster_and_its_puppet_wear_the_hunter() -> void:
	var monster: Node = (
		(load("res://game/entities/monster/monster.tscn") as PackedScene).instantiate()
	)
	assert_true(monster.get_node("Body") is MonsterBody)
	monster.free()
	var puppet := NetPuppet.new()
	puppet.kind = NetPuppet.Kind.MONSTER
	add_child_autofree(puppet)
	assert_eq(puppet.find_children("*", "MonsterBody", true, false).size(), 1)
