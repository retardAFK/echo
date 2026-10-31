extends GutTest

const EPSILON := 0.0001

var _settings: PlayerSettings


func before_each() -> void:
	_settings = PlayerSettings.new()


func test_speed_for_each_gait() -> void:
	assert_eq(PlayerMotion.speed_for_gait(_settings, PlayerMotion.Gait.CROUCH), 1.5)
	assert_eq(PlayerMotion.speed_for_gait(_settings, PlayerMotion.Gait.WALK), 3.0)
	assert_eq(PlayerMotion.speed_for_gait(_settings, PlayerMotion.Gait.SPRINT), 5.5)


func test_diagonal_is_not_faster() -> void:
	var straight := PlayerMotion.wish_direction(Vector2(0.0, -1.0), 0.0)
	var diagonal := PlayerMotion.wish_direction(Vector2(1.0, -1.0), 0.0)
	assert_almost_eq(straight.length(), 1.0, EPSILON)
	assert_almost_eq(diagonal.length(), 1.0, EPSILON)


func test_forward_follows_yaw() -> void:
	var forward := PlayerMotion.wish_direction(Vector2(0.0, -1.0), 0.0)
	assert_almost_eq(forward.z, -1.0, EPSILON)
	var turned := PlayerMotion.wish_direction(Vector2(0.0, -1.0), PI / 2.0)
	assert_almost_eq(turned.x, -1.0, EPSILON)
	assert_almost_eq(turned.y, 0.0, EPSILON)


func test_no_input_means_no_direction() -> void:
	assert_eq(PlayerMotion.wish_direction(Vector2.ZERO, 1.0), Vector3.ZERO)


func test_acceleration_is_gradual() -> void:
	var target := Vector3(0.0, 0.0, -3.0)
	var next := PlayerMotion.approach_velocity(Vector3.ZERO, target, _settings, 0.05)
	assert_almost_eq(next.length(), _settings.acceleration * 0.05, EPSILON)
	var reached := PlayerMotion.approach_velocity(Vector3.ZERO, target, _settings, 1.0)
	assert_eq(reached, target)


func test_braking_uses_deceleration() -> void:
	var moving := Vector3(3.0, 0.0, 0.0)
	var next := PlayerMotion.approach_velocity(moving, Vector3.ZERO, _settings, 0.05)
	assert_almost_eq(next.length(), 3.0 - _settings.deceleration * 0.05, EPSILON)


func test_pitch_is_clamped() -> void:
	var limit := deg_to_rad(_settings.pitch_limit)
	assert_almost_eq(PlayerMotion.clamp_pitch(10.0, _settings), limit, EPSILON)
	assert_almost_eq(PlayerMotion.clamp_pitch(-10.0, _settings), -limit, EPSILON)
	assert_almost_eq(PlayerMotion.clamp_pitch(0.3, _settings), 0.3, EPSILON)


func test_gait_defaults_to_walk() -> void:
	assert_eq(PlayerMotion.resolve_gait(false, false, true, false, true), PlayerMotion.Gait.WALK)


func test_sprint_needs_movement() -> void:
	assert_eq(PlayerMotion.resolve_gait(false, true, true, false, true), PlayerMotion.Gait.SPRINT)
	assert_eq(PlayerMotion.resolve_gait(false, true, false, false, true), PlayerMotion.Gait.WALK)


func test_crouch_wins_over_sprint() -> void:
	assert_eq(PlayerMotion.resolve_gait(true, true, true, false, true), PlayerMotion.Gait.CROUCH)


func test_stays_crouched_without_headroom() -> void:
	assert_eq(PlayerMotion.resolve_gait(false, false, true, true, false), PlayerMotion.Gait.CROUCH)
	assert_eq(PlayerMotion.resolve_gait(false, false, true, true, true), PlayerMotion.Gait.WALK)


func test_height_for_gait() -> void:
	assert_eq(PlayerMotion.height_for_gait(_settings, PlayerMotion.Gait.CROUCH), 1.0)
	assert_eq(PlayerMotion.height_for_gait(_settings, PlayerMotion.Gait.SPRINT), 1.75)


func test_head_bob_can_be_disabled() -> void:
	assert_gt(PlayerMotion.head_bob_amplitude(_settings, PlayerMotion.Gait.WALK), 0.0)
	assert_gt(
		PlayerMotion.head_bob_amplitude(_settings, PlayerMotion.Gait.SPRINT),
		PlayerMotion.head_bob_amplitude(_settings, PlayerMotion.Gait.WALK)
	)
	_settings.head_bob_enabled = false
	assert_eq(PlayerMotion.head_bob_amplitude(_settings, PlayerMotion.Gait.SPRINT), 0.0)


func test_head_bob_stays_within_amplitude() -> void:
	for i in 16:
		var offset := PlayerMotion.head_bob_offset(i * 0.4, 0.05)
		assert_between(offset.y, 0.0, 0.05 + EPSILON)
		assert_lte(absf(offset.x), 0.025 + EPSILON)
