extends GutTest
## The room's clock on a client (S-020, T-320): snapshots dated with the
## room's physics frame, so a burst of them still plays at an even pace.

var _settings := NetSettings.new()


func test_snapshots_are_dated_with_the_room_frame() -> void:
	# S-020, T-320: two snapshots that come 5 ms apart but were taken 3 room
	# frames apart keep their 50 ms between them.
	var net := NetGame.new()
	autofree(net)
	add_child(net)
	net.own = Node3D.new()
	autofree(net.own)
	net.prediction = Prediction.new(net.settings)
	net.apply_snapshot({"frame": 300, "ack": 0, "others": [[2, Vector3(0, 0, 0), 0.0]]})
	net.apply_snapshot({"frame": 303, "ack": 0, "others": [[2, Vector3(0.3, 0, 0), 0.0]]})
	var buffer: SnapshotBuffer = net.puppets[2].buffer
	var middle := net.room_clock.room_time(300) + 1.5 / Engine.physics_ticks_per_second
	assert_almost_eq((buffer.sample(middle, 0.0)[0] as Vector3).x, 0.15, 0.001)
	assert_true(net.room_clock.started)
	remove_child(net)


func test_a_burst_of_snapshots_still_plays_at_an_even_pace() -> void:
	# A runner at 6 m/s, a snapshot every 3 room frames; they come in pairs
	# 5 ms apart, every 100 ms (TCP holding one back). Shown 0.2 s in the past
	# on the room's clock, it moves the same distance every frame.
	var clock := RoomClock.new(_settings)
	var buffer := SnapshotBuffer.new()
	var fps := float(Engine.physics_ticks_per_second)
	var latency := 0.1
	var arrivals := []  # [local time it arrives, room frame], in order.
	for n in 80:
		var taken := n * 3 / fps
		var held := 0.045 if n % 2 == 0 else 0.0  # Held back, then both at once.
		arrivals.append([taken + latency + held, n * 3])
	var shown := []
	var local := 0.0
	while local < 3.5:
		while not arrivals.is_empty() and arrivals[0][0] <= local:
			var arrival: Array = arrivals.pop_front()
			var at := clock.room_time(arrival[1])
			clock.observe(arrival[1], arrival[0])
			buffer.push(at, Vector3(at * 6.0, 0, 0), 0.0)
		if local > 1.0:
			var time := clock.now(local) - _settings.interpolation_delay
			shown.append((buffer.sample(time, _settings.max_extrapolation)[0] as Vector3).x)
		local += 1.0 / fps
	assert_almost_eq(clock.offset, latency, 0.001, "the quickest trip")
	var step := 6.0 / fps
	for i in range(1, shown.size()):
		assert_almost_eq(shown[i] - shown[i - 1], step, step * 0.5, "no jump, no stop")


func test_the_room_clock_follows_slowly_never_by_a_jump() -> void:
	var clock := RoomClock.new(_settings)
	clock.observe(60, 1.1)  # Room time 1 s, 0.1 s trip.
	assert_almost_eq(clock.offset, 0.1, 0.0001)
	clock.observe(66, 1.15)  # Room time 1.1 s, a quicker trip of 0.05 s.
	assert_lt(clock.offset, 0.1, "follows")
	assert_gt(clock.offset, 0.09, "slowly")
	clock.observe(600, 30.0)  # The room started again: far off, it jumps.
	assert_almost_eq(clock.offset, 30.0 - 10.0, 0.0001)
