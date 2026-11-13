extends GutTest
## Commands separated from the keyboard (S-010, T-106).

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const MONSTER_AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const ONE_SECOND_FRAMES := 60


func _floor() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	add_child_autofree(floor_body)


func test_bytes_round_trip() -> void:
	var commands := PlayerCommands.new()
	commands.seq = 70000
	commands.move = Vector2(0.5, -1.0).normalized()
	commands.yaw = 1.25
	commands.pitch = -0.5
	commands.sprint = true
	commands.scan = true
	commands.push(PlayerCommands.Action.THROW)
	commands.push(PlayerCommands.Action.CROUCH)
	var bytes := commands.to_bytes()
	assert_eq(bytes.size(), PlayerCommands.HEADER_SIZE + 2)
	var read := PlayerCommands.from_bytes(bytes)
	assert_eq(read.seq, 70000)
	assert_almost_eq(read.move.x, commands.move.x, 0.0001)
	assert_almost_eq(read.move.y, commands.move.y, 0.0001)
	assert_almost_eq(read.yaw, 1.25, 0.0001)
	assert_almost_eq(read.pitch, -0.5, 0.0001)
	assert_true(read.sprint)
	assert_false(read.interact)
	assert_true(read.scan)
	assert_eq(
		read.take_actions(), [PlayerCommands.Action.THROW, PlayerCommands.Action.CROUCH] as Array
	)


func test_malformed_bytes_are_refused() -> void:
	assert_null(PlayerCommands.from_bytes(PackedByteArray([1, 2, 3])))
	var bytes := PlayerCommands.new().to_bytes()
	bytes.encode_u8(21, 5)  # Claims 5 actions that are not there.
	assert_null(PlayerCommands.from_bytes(bytes))


func test_tampered_values_are_bounded() -> void:
	var commands := PlayerCommands.new()
	commands.move = Vector2(10.0, 0.0)
	var bytes := commands.to_bytes()
	bytes.append(200)  # An action that does not exist.
	bytes.encode_u8(21, 1)
	bytes.encode_float(12, NAN)
	var read := PlayerCommands.from_bytes(bytes)
	assert_almost_eq(read.move.length(), 1.0, 0.0001)
	assert_eq(read.yaw, 0.0)
	assert_true(read.take_actions().is_empty())


func test_take_actions_empties_the_queue() -> void:
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.INTERACT)
	assert_eq(commands.peek_actions().size(), 1)
	assert_eq(commands.take_actions().size(), 1)
	assert_true(commands.take_actions().is_empty())


func test_player_moves_from_commands_without_keyboard() -> void:
	_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	assert_eq(player.find_children("*", "LocalControls", false, false).size(), 0)
	player.commands.move = Vector2(0.0, -1.0)
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_lt(player.global_position.z, -2.0, "Forward is -Z")
	assert_almost_eq(
		Vector2(player.velocity.x, player.velocity.z).length(), player.settings.walk_speed, 0.05
	)


func test_player_applies_crouch_action_once() -> void:
	_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	player.commands.push(PlayerCommands.Action.CROUCH)
	player.commands.move = Vector2(0.0, -1.0)
	await wait_physics_frames(10)
	assert_eq(player.get_gait(), PlayerMotion.Gait.CROUCH)
	assert_true(player.commands.peek_actions().is_empty())


func test_local_player_has_controls_reading_keyboard() -> void:
	_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	Input.action_press("sprint")
	await wait_physics_frames(2)
	Input.action_release("sprint")
	assert_eq(player.find_children("*", "LocalControls", false, false).size(), 1)
	assert_true(player.commands.sprint)
	assert_gt(player.commands.seq, 0)


func test_monster_avatar_prowls_from_commands() -> void:
	_floor()
	var avatar: MonsterAvatar = MONSTER_AVATAR_SCENE.instantiate()
	avatar.local_controls = false
	add_child_autofree(avatar)
	avatar.commands.push(PlayerCommands.Action.CROUCH)
	avatar.commands.move = Vector2(0.0, -1.0)
	await wait_physics_frames(10)
	assert_eq(avatar.get_pace(), MonsterBrain.Pace.PROWL)
	assert_lt(avatar.global_position.z, 0.0)
