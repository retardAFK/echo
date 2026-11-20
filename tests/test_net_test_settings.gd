extends GutTest
## Thresholds of the online CI tests over a bad connection (S-020, T-330,
## piste T7): net_walk --bad-link and net_match read them.

const TEST_SETTINGS := preload("res://game/data/net_test_settings.tres")


func test_the_starting_points() -> void:
	assert_eq(TEST_SETTINGS.walk_latency_ms, 150)
	assert_eq(TEST_SETTINGS.bad_jitter_ms, 100)
	assert_eq(TEST_SETTINGS.bad_max_gap, 0.75)
	assert_eq(TEST_SETTINGS.match_latency_ms, 75)


func test_a_bad_link_must_stay_under_the_visible_snap() -> void:
	var net := NetSettings.new()
	assert_lt(TEST_SETTINGS.bad_max_gap, net.correction_threshold, "a snap the player sees fails")
	assert_lt(TEST_SETTINGS.walk_max_gap, TEST_SETTINGS.bad_max_gap)
