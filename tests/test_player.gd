extends GutTest
## Physics tests of the player scene on a flat floor (spec S-001).

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const EPSILON := 0.0001
const ONE_SECOND_FRAMES := 60

var _player: Player


func before_each() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	add_child_autofree(floor_body)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(action)


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func test_eyes_at_standing_height() -> void:
	var head: Node3D = _player.get_node("Head")
	var expected := _player.settings.standing_height - _player.settings.eye_offset
	assert_almost_eq(head.position.y, expected, EPSILON)


func test_walks_forward_at_walk_speed() -> void:
	var start := _player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_lt(_player.global_position.z, start.z - 2.0, "Forward is -Z")
	assert_almost_eq(_horizontal_speed(), _player.settings.walk_speed, 0.05)


func test_diagonal_is_not_faster() -> void:
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_almost_eq(_horizontal_speed(), _player.settings.walk_speed, 0.05)


func test_stops_when_keys_released() -> void:
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	Input.action_release("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_almost_eq(_horizontal_speed(), 0.0, EPSILON)


func test_stays_on_floor() -> void:
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_true(_player.is_on_floor())
	assert_almost_eq(_player.global_position.y, 0.0, 0.05)


func test_mouse_turns_body() -> void:
	var pixels := 100.0
	_player.look(Vector2(pixels, 0.0))
	var expected := -deg_to_rad(_player.settings.mouse_sensitivity * pixels)
	assert_almost_eq(_player.rotation.y, expected, EPSILON)


func test_look_never_flips_over() -> void:
	_player.look(Vector2(0.0, -100000.0))
	assert_almost_eq(_player.get_pitch(), deg_to_rad(_player.settings.pitch_limit), EPSILON)
	_player.look(Vector2(0.0, 100000.0))
	assert_almost_eq(_player.get_pitch(), -deg_to_rad(_player.settings.pitch_limit), EPSILON)


func _add_box(size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child_autofree(body)
	return body


func test_sprints_faster_and_signals_gait() -> void:
	watch_signals(_player)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_eq(_player.get_gait(), PlayerMotion.Gait.SPRINT)
	assert_almost_eq(_horizontal_speed(), _player.settings.sprint_speed, 0.05)
	assert_signal_emitted_with_parameters(_player, "gait_changed", [PlayerMotion.Gait.SPRINT])


func test_crouch_lowers_eyes_and_slows_down() -> void:
	_player.toggle_crouch()
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_eq(_player.get_gait(), PlayerMotion.Gait.CROUCH)
	assert_almost_eq(_player.get_height(), _player.settings.crouch_height, EPSILON)
	assert_almost_eq(_horizontal_speed(), _player.settings.crouch_speed, 0.05)
	_player.toggle_crouch()
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_eq(_player.get_gait(), PlayerMotion.Gait.WALK)
	assert_almost_eq(_player.get_height(), _player.settings.standing_height, EPSILON)


func test_cannot_stand_under_low_ceiling() -> void:
	_player.toggle_crouch()
	await wait_physics_frames(ONE_SECOND_FRAMES)
	# A 1.2 m high passage, as in the spec, right above the crouched player.
	var slab := _add_box(Vector3(4.0, 0.3, 4.0), Vector3(0.0, 1.35, 0.0))
	_player.toggle_crouch()
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_eq(_player.get_gait(), PlayerMotion.Gait.CROUCH)
	assert_almost_eq(_player.get_height(), _player.settings.crouch_height, EPSILON)
	slab.free()
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_eq(_player.get_gait(), PlayerMotion.Gait.WALK)


func test_climbs_low_step() -> void:
	_add_box(Vector3(4.0, 0.25, 20.0), Vector3(0.0, 0.125, -11.0))
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES * 2)
	assert_lt(_player.global_position.z, -1.5, "Player must be on the step")
	assert_almost_eq(_player.global_position.y, 0.25, 0.05)


func test_blocked_by_low_wall() -> void:
	_add_box(Vector3(4.0, 0.6, 0.3), Vector3(0.0, 0.3, -2.0))
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES * 2)
	assert_gt(_player.global_position.z, -2.0, "Player must stay behind the wall")
	assert_almost_eq(_player.global_position.y, 0.0, 0.05)
