extends GutTest
## Pure noise math (spec S-002, T-008).

const SETTINGS_PATH := "res://game/data/noise_settings.tres"
const EPSILON := 0.0001

var _settings: NoiseSettings


func before_each() -> void:
	_settings = load(SETTINGS_PATH)


func test_settings_load_with_spec_ranges() -> void:
	assert_not_null(_settings)
	assert_eq(_settings.crouch_range, 1.0)
	assert_eq(_settings.walk_range, 4.0)
	assert_eq(_settings.sprint_range, 14.0)


func test_range_for_each_gait() -> void:
	assert_eq(NoiseMath.range_for_gait(_settings, PlayerMotion.Gait.CROUCH), 1.0)
	assert_eq(NoiseMath.range_for_gait(_settings, PlayerMotion.Gait.WALK), 4.0)
	assert_eq(NoiseMath.range_for_gait(_settings, PlayerMotion.Gait.SPRINT), 14.0)


func test_strides_grow_with_speed() -> void:
	var crouch := NoiseMath.stride_for_gait(_settings, PlayerMotion.Gait.CROUCH)
	var walk := NoiseMath.stride_for_gait(_settings, PlayerMotion.Gait.WALK)
	var sprint := NoiseMath.stride_for_gait(_settings, PlayerMotion.Gait.SPRINT)
	assert_lt(crouch, walk)
	assert_lt(walk, sprint)


func test_each_wall_halves_the_range() -> void:
	assert_almost_eq(NoiseMath.perceived_range(14.0, 0, _settings), 14.0, EPSILON)
	assert_almost_eq(NoiseMath.perceived_range(14.0, 1, _settings), 7.0, EPSILON)
	assert_almost_eq(NoiseMath.perceived_range(14.0, 2, _settings), 3.5, EPSILON)


func test_walls_are_capped() -> void:
	var capped := NoiseMath.perceived_range(14.0, _settings.max_walls_counted, _settings)
	assert_almost_eq(NoiseMath.perceived_range(14.0, 99, _settings), capped, EPSILON)


func test_open_space_probe_at_10m_hears_sprint_not_walk() -> void:
	# Spec S-002: a probe 10 m away in open space hears sprinting, not walking.
	assert_true(NoiseMath.is_heard(_settings.sprint_range, 10.0, 0, _settings))
	assert_false(NoiseMath.is_heard(_settings.walk_range, 10.0, 0, _settings))


func test_probe_behind_wall_at_6m_hears_sprint_not_walk() -> void:
	# Spec S-002: a probe 6 m away behind a wall hears sprinting, not walking.
	assert_true(NoiseMath.is_heard(_settings.sprint_range, 6.0, 1, _settings))
	assert_false(NoiseMath.is_heard(_settings.walk_range, 6.0, 1, _settings))


func test_gauge_levels_match_spec() -> void:
	# Spec S-002: about 9 when sprinting, 3 when walking, 1 at most when crouched.
	assert_eq(roundi(NoiseMath.gauge_level(_settings.sprint_range, _settings)), 9)
	assert_eq(roundi(NoiseMath.gauge_level(_settings.walk_range, _settings)), 3)
	assert_lte(NoiseMath.gauge_level(_settings.crouch_range, _settings), 1.0)


func test_gauge_is_clamped() -> void:
	assert_eq(NoiseMath.gauge_level(100.0, _settings), NoiseMath.GAUGE_MAX)
	assert_eq(NoiseMath.gauge_level(0.0, _settings), 0.0)


func test_gauge_empties_in_decay_time() -> void:
	var level := NoiseMath.GAUGE_MAX
	level = NoiseMath.decay_gauge(level, _settings.gauge_decay_time * 0.5, _settings)
	assert_almost_eq(level, NoiseMath.GAUGE_MAX * 0.5, EPSILON)
	level = NoiseMath.decay_gauge(level, _settings.gauge_decay_time, _settings)
	assert_eq(level, 0.0)


func test_noise_event_keeps_its_data() -> void:
	var event := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, Vector3(1.0, 0.0, 2.0), 4.0)
	assert_eq(event.type, NoiseEvent.Type.FOOTSTEP)
	assert_eq(event.position, Vector3(1.0, 0.0, 2.0))
	assert_eq(event.noise_range, 4.0)
	assert_null(event.source)
