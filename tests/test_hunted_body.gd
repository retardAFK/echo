extends GutTest
## The hunted's animated bodies (spec S-011, T-126): which animation for which
## state, how fast it plays, which character for which seat, and the
## network puppet that drives it from the snapshots.

const SETTINGS := preload("res://game/data/hunted_body_settings.tres")
const WALK := PlayerMotion.Gait.WALK
const CROUCH := PlayerMotion.Gait.CROUCH
const SPRINT := PlayerMotion.Gait.SPRINT
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")


func test_still_hunted_idles_in_every_gait_but_crouch() -> void:
	assert_eq(HuntedBody.pick(WALK, 0.0, false, SETTINGS), HuntedBody.IDLE)
	assert_eq(HuntedBody.pick(SPRINT, 0.1, false, SETTINGS), HuntedBody.IDLE)
	assert_eq(HuntedBody.pick(CROUCH, 0.0, false, SETTINGS), HuntedBody.CROUCH_IDLE)


func test_moving_hunted_walks_runs_or_creeps() -> void:
	assert_eq(HuntedBody.pick(WALK, 3.0, false, SETTINGS), HuntedBody.WALK)
	assert_eq(HuntedBody.pick(SPRINT, 5.5, false, SETTINGS), HuntedBody.RUN)
	assert_eq(HuntedBody.pick(CROUCH, 1.5, false, SETTINGS), HuntedBody.CROUCH)


func test_captured_hunted_kneels_whatever_it_does() -> void:
	for gait: PlayerMotion.Gait in [WALK, CROUCH, SPRINT]:
		assert_eq(HuntedBody.pick(gait, 4.0, true, SETTINGS), HuntedBody.KNEEL)


func test_a_gesture_shows_unless_captured() -> void:
	var gestures := {
		HuntedBody.Gesture.THROW: HuntedBody.THROW,
		HuntedBody.Gesture.PICK: HuntedBody.PICK,
		HuntedBody.Gesture.WORK: HuntedBody.WORK,
	}
	for gesture: HuntedBody.Gesture in gestures:
		assert_eq(HuntedBody.pick(SPRINT, 5.0, false, SETTINGS, gesture), gestures[gesture])
		assert_eq(HuntedBody.pick(CROUCH, 0.0, false, SETTINGS, gesture), gestures[gesture])
		assert_eq(HuntedBody.pick(WALK, 0.0, true, SETTINGS, gesture), HuntedBody.KNEEL)


func test_a_gesture_lasts_its_length() -> void:
	var gesture := BodyGesture.new()
	gesture.play(HuntedBody.Gesture.THROW, 0.5)
	gesture.update(0.3)
	assert_eq(gesture.kind, HuntedBody.Gesture.THROW)
	gesture.update(0.3)
	assert_eq(gesture.kind, HuntedBody.Gesture.NONE)


func test_one_shots_last_as_long_as_their_animation() -> void:
	var model: Node = (load(HuntedBody.MODELS[HuntedBody.Role.PARKA]) as PackedScene).instantiate()
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	assert_almost_eq(player.get_animation(HuntedBody.THROW).length, SETTINGS.throw_time, 0.05)
	assert_almost_eq(player.get_animation(HuntedBody.PICK).length, SETTINGS.pick_time, 0.05)
	model.free()


func test_a_hunted_throwing_or_working_shows_it() -> void:
	var player: Player = (
		(load("res://game/entities/player/player.tscn") as PackedScene).instantiate()
	)
	add_child_autofree(player)
	assert_eq(player.get_gesture(), HuntedBody.Gesture.NONE)
	player.inventory.take(Inventory.Kind.BOTTLE)
	player.throw_bottle()
	assert_eq(player.get_gesture(), HuntedBody.Gesture.THROW)
	player.gesture.update(SETTINGS.throw_time + 0.01)
	assert_eq(player.get_gesture(), HuntedBody.Gesture.NONE)
	var prey: Prey = PREY_SCENE.instantiate()
	add_child_autofree(prey)
	prey.inventory.take(Inventory.Kind.DECOY)
	prey.place_decoy()
	assert_eq(prey.get_gesture(), HuntedBody.Gesture.PICK)


func test_puppet_shows_the_gesture_the_room_sends() -> void:
	var puppet := NetPuppet.new()
	puppet.seat = 2
	add_child_autofree(puppet)
	var body: HuntedBody = puppet.find_children("*", "HuntedBody", true, false)[0]
	puppet.buffer.push(0.0, Vector3.ZERO, 0.0)
	puppet.gesture = HuntedBody.Gesture.WORK
	puppet.show_at(0.0, 0.1)
	assert_eq(body.animation, HuntedBody.WORK)


func test_playback_follows_speed_within_bounds() -> void:
	assert_almost_eq(
		HuntedBody.playback_scale(HuntedBody.WALK, SETTINGS.walk_speed, SETTINGS), 1.0, 0.001
	)
	assert_eq(HuntedBody.playback_scale(HuntedBody.RUN, 100.0, SETTINGS), SETTINGS.max_scale)
	assert_eq(HuntedBody.playback_scale(HuntedBody.CROUCH, 0.01, SETTINGS), SETTINGS.min_scale)
	assert_eq(HuntedBody.playback_scale(HuntedBody.IDLE, 3.0, SETTINGS), 1.0)
	assert_eq(HuntedBody.playback_scale(HuntedBody.KNEEL, 3.0, SETTINGS), 1.0)


func test_each_seat_has_its_character() -> void:
	assert_eq(HuntedBody.role_for_seat(1), HuntedBody.Role.AMBULANCIER)
	assert_eq(HuntedBody.role_for_seat(2), HuntedBody.Role.PARKA)
	assert_eq(HuntedBody.role_for_seat(3), HuntedBody.Role.MASQUE)


func test_every_character_has_its_model_and_animations() -> void:
	for role: HuntedBody.Role in HuntedBody.MODELS:
		var model: Node = (load(HuntedBody.MODELS[role]) as PackedScene).instantiate()
		var players := model.find_children("*", "AnimationPlayer", true, false)
		assert_eq(players.size(), 1, HuntedBody.MODELS[role])
		var player: AnimationPlayer = players[0]
		for anim in [
			HuntedBody.IDLE,
			HuntedBody.WALK,
			HuntedBody.RUN,
			HuntedBody.CROUCH,
			HuntedBody.CROUCH_IDLE,
			HuntedBody.KNEEL,
			HuntedBody.THROW,
			HuntedBody.PICK,
			HuntedBody.WORK
		]:
			assert_true(player.has_animation(anim), "%s in %s" % [anim, HuntedBody.MODELS[role]])
		model.free()


func test_puppet_runs_when_it_moves_fast_and_kneels_when_caught() -> void:
	var puppet := NetPuppet.new()
	puppet.seat = 2
	add_child_autofree(puppet)
	var body: HuntedBody = puppet.find_children("*", "HuntedBody", true, false)[0]
	assert_eq(body.role, HuntedBody.Role.PARKA)
	puppet.gait = SPRINT
	for i in 30:  # 5.5 m/s for half a second of snapshots.
		puppet.buffer.push(i * 0.05, Vector3(i * 0.05 * 5.5, 0, 0), 0.0)
	for i in 20:
		puppet.show_at(0.5 + i * 0.016, 0.1)
	assert_eq(body.animation, HuntedBody.RUN)
	puppet.set_down(true)
	puppet.show_at(1.0, 0.1)
	assert_eq(body.animation, HuntedBody.KNEEL)


func test_monster_puppet_has_no_hunted_body() -> void:
	var puppet := NetPuppet.new()
	puppet.kind = NetPuppet.Kind.MONSTER
	add_child_autofree(puppet)
	assert_eq(puppet.find_children("*", "HuntedBody", true, false).size(), 0)


func test_prey_wears_a_hunted_body() -> void:
	var prey: Prey = PREY_SCENE.instantiate()
	assert_true(prey.get_node("Body") is HuntedBody)
	prey.free()


func test_each_character_draws_in_three_calls_at_most() -> void:
	# Final textures (T-124): one baked atlas, plus its lights.
	var paths: Array = HuntedBody.MODELS.values() + [MonsterBody.MODEL]
	for path: String in paths:
		var model: Node = (load(path) as PackedScene).instantiate()
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1, path)
		var mesh: Mesh = (meshes[0] as MeshInstance3D).mesh
		assert_lte(mesh.get_surface_count(), 3, path)
		var atlas := (mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture
		assert_lte(atlas.get_width(), 512, "512 px at most (2.3)")
		model.free()


func test_every_character_faces_forward() -> void:
	# Godot's forward is -Z (look_at): the toes are ahead of the ankles.
	for role: HuntedBody.Role in HuntedBody.MODELS:
		var model: Node = (load(HuntedBody.MODELS[role]) as PackedScene).instantiate()
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var ankle := skeleton.get_bone_global_rest(skeleton.find_bone("foot_l")).origin
		var toes := skeleton.get_bone_global_rest(skeleton.find_bone("ball_l")).origin
		assert_lt(toes.z, ankle.z, HuntedBody.MODELS[role])
		model.free()
