extends GutTest
## Bench mode (spec S-009, Q2, T-075): frame statistics and camera tour.

const SETTINGS := preload("res://game/data/bench_settings.tres")


func test_empty_stats_are_zero() -> void:
	var stats := BenchStats.new()
	assert_eq(stats.frame_count(), 0)
	assert_eq(stats.average_fps(), 0.0)
	assert_eq(stats.min_fps(), 0.0)
	assert_eq(stats.low_fps(), 0.0)


func test_steady_frames() -> void:
	var stats := BenchStats.new()
	for i in 120:
		stats.add_frame(1.0 / 60.0, 200, 50000)
	assert_almost_eq(stats.average_fps(), 60.0, 0.01)
	assert_almost_eq(stats.min_fps(), 60.0, 0.01)
	assert_almost_eq(stats.low_fps(), 60.0, 0.01)


func test_slow_frames_drag_min_and_low() -> void:
	var stats := BenchStats.new()
	for i in 198:
		stats.add_frame(0.01)  # 100 images/s
	stats.add_frame(0.05)  # 20 images/s
	stats.add_frame(0.1)  # 10 images/s
	# 200 frames: the slowest 1 % is the 2 slowest frames, 0.15 s for 2 frames.
	assert_almost_eq(stats.min_fps(), 10.0, 0.001)
	assert_almost_eq(stats.low_fps(), 2.0 / 0.15, 0.001)
	assert_almost_eq(stats.average_fps(), 200.0 / (1.98 + 0.15), 0.001)


func test_low_uses_at_least_one_frame() -> void:
	var stats := BenchStats.new()
	stats.add_frame(0.02)
	stats.add_frame(0.04)
	assert_almost_eq(stats.low_fps(), 25.0, 0.001)


func test_worst_draw_calls_and_triangles() -> void:
	var stats := BenchStats.new()
	stats.add_frame(0.016, 120, 30000)
	stats.add_frame(0.016, 260, 20000)
	stats.add_frame(0.016, 90, 80000)
	assert_eq(stats.worst_draw_calls, 260)
	assert_eq(stats.worst_triangles, 80000)


func test_zero_length_frames_are_ignored() -> void:
	var stats := BenchStats.new()
	stats.add_frame(0.0)
	stats.add_frame(-1.0)
	assert_eq(stats.frame_count(), 0)


func test_dict_has_every_figure() -> void:
	var stats := BenchStats.new()
	stats.add_frame(1.0 / 30.0, 10, 20)
	var d := stats.to_dict()
	for key in ["frames", "fps_avg", "fps_min", "fps_1pc_low", "draw_calls_max", "triangles_max"]:
		assert_true(d.has(key), key)
	assert_almost_eq(float(d.fps_avg), 30.0, 0.05)


func test_tour_visits_every_viewpoint() -> void:
	var share := SETTINGS.duration / Bench.VIEWS.size()
	for i in Bench.VIEWS.size():
		var pose := Bench.pose_at(share * (i + 0.5), SETTINGS)
		var view: Array = Bench.VIEWS[i]
		var eye: Vector3 = view[0] - Vector3(Bench.ORIGIN.x, 0, Bench.ORIGIN.z)
		assert_almost_eq(pose[0], eye, Vector3.ONE * 0.001, "viewpoint %d" % i)


func test_tour_turns_around_the_look_direction() -> void:
	var start := Bench.pose_at(0.0, SETTINGS)
	var quarter := Bench.pose_at(SETTINGS.duration / Bench.VIEWS.size() / 4.0, SETTINGS)
	var a := (start[1] - start[0]).normalized()
	var b := (quarter[1] - quarter[0]).normalized()
	assert_almost_eq(rad_to_deg(a.angle_to(b)), SETTINGS.sweep_angle, 0.5)


func test_tour_clamps_past_the_end() -> void:
	var pose := Bench.pose_at(SETTINGS.duration * 2.0, SETTINGS)
	var view: Array = Bench.VIEWS[Bench.VIEWS.size() - 1]
	assert_almost_eq(
		pose[0], view[0] - Vector3(Bench.ORIGIN.x, 0, Bench.ORIGIN.z), Vector3.ONE * 0.001
	)


func test_not_requested_without_flag() -> void:
	assert_false(Bench.is_requested())
