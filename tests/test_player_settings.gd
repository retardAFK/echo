extends GutTest

const SETTINGS_PATH := "res://game/data/player_settings.tres"

var _settings: PlayerSettings


func before_each() -> void:
	_settings = load(SETTINGS_PATH)


func test_settings_load() -> void:
	assert_not_null(_settings, "Player settings must load: %s" % SETTINGS_PATH)
	assert_true(_settings is PlayerSettings)


func test_speeds_are_ordered() -> void:
	assert_gt(_settings.crouch_speed, 0.0)
	assert_gt(_settings.walk_speed, _settings.crouch_speed)
	assert_gt(_settings.sprint_speed, _settings.walk_speed)


func test_crouch_is_lower_than_standing() -> void:
	assert_lt(_settings.crouch_height, _settings.standing_height)
	assert_gt(_settings.crouch_height, _settings.capsule_radius * 2.0)


func test_crouch_fits_under_low_passage() -> void:
	# Spec S-001: a crouched player passes under a 1.2 m obstacle.
	assert_lt(_settings.crouch_height, 1.2)
	assert_gt(_settings.standing_height, 1.2)


func test_step_height_matches_spec() -> void:
	# Spec S-001: a 0.25 m step is climbed, a 0.6 m wall is not.
	assert_gte(_settings.max_step_height, 0.25)
	assert_lt(_settings.max_step_height, 0.6)
