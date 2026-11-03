extends GutTest
## Footstep noises of the player (spec S-002, T-010).

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const ONE_SECOND_FRAMES := 60

var _player: Player
var _footsteps: Array[NoiseEvent] = []


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
	_footsteps.clear()
	NoiseBus.noise_emitted.connect(_on_noise)
	# Let the player land before counting.
	await wait_physics_frames(10)
	_footsteps.clear()


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)
	for action in ["move_forward", "sprint"]:
		Input.action_release(action)


func _on_noise(event: NoiseEvent) -> void:
	if event.source == _player:
		_footsteps.append(event)


func test_silent_when_standing_still() -> void:
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_eq(_footsteps.size(), 0)


func test_walking_makes_4m_footsteps() -> void:
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES * 2)
	# About 5.6 m walked with 0.7 m strides, acceleration included.
	assert_between(_footsteps.size(), 6, 9)
	for event in _footsteps:
		assert_eq(event.type, NoiseEvent.Type.FOOTSTEP)
		assert_eq(event.noise_range, 4.0)


func test_sprinting_makes_14m_footsteps() -> void:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_gt(_footsteps.size(), 0)
	assert_eq(_footsteps[-1].noise_range, 14.0)


func test_crouching_makes_1m_footsteps() -> void:
	_player.toggle_crouch()
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_gt(_footsteps.size(), 0)
	assert_eq(_footsteps[-1].noise_range, 1.0)


func test_noise_starts_near_the_feet() -> void:
	Input.action_press("move_forward")
	await wait_physics_frames(ONE_SECOND_FRAMES)
	assert_gt(_footsteps.size(), 0)
	assert_almost_eq(_footsteps[-1].position.y, 0.3, 0.05)
