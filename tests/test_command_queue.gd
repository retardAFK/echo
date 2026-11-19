extends GutTest
## The room plays one frame of a player's commands per physics frame, from a
## queue (S-020, T-321): bursts, lost packets and actions.

var _settings := NetSettings.new()


## Frame seq of a client walking: move.x is its number, to tell them apart.
func _frame(seq: int) -> PlayerCommands:
	var frame := PlayerCommands.new()
	frame.seq = seq
	frame.move = Vector2(0.0, -1.0)
	frame.sprint = seq % 2 == 0
	return frame


## The packet the client sends after frame last: its last frames_per_packet
## frames, through the bytes, as on the network.
func _packet(last: int) -> Array[PlayerCommands]:
	var frames: Array[PlayerCommands] = []
	for seq in range(maxi(1, last - _settings.frames_per_packet + 1), last + 1):
		frames.append(_frame(seq))
	return PlayerCommands.frames_from_bytes(PlayerCommands.frames_to_bytes(frames))


func test_settings_follow_the_request() -> void:
	assert_eq(_settings.frames_per_packet, 4)
	assert_between(_settings.command_lead, 2, 3)


func test_a_packet_carries_its_last_frames_through_the_bytes() -> void:
	var frames := _packet(10)
	assert_eq(frames.size(), 4)
	assert_eq(frames.map(func(f: PlayerCommands) -> int: return f.seq), [7, 8, 9, 10])
	assert_true(frames[1].sprint)
	assert_almost_eq(frames[0].move.y, -1.0, 0.0001)
	assert_eq(PlayerCommands.frames_from_bytes(PackedByteArray([3, 1, 2])).size(), 0, "malformed")


func test_a_burst_plays_one_frame_per_room_frame_with_the_right_number() -> void:
	# The client makes one frame per physics frame and sends a packet every 2;
	# the network holds them back and lets 3 packets through at once every
	# 6 frames. The room plays exactly one frame per physics frame: the number
	# it sends back is the frame it played, and where it has the player at
	# that number is where the client predicted it (one step per frame).
	var queue := CommandQueue.new(_settings)
	var held_back: Array = []
	var played: Array[int] = []
	for tick in range(1, 241):
		if tick % 2 == 0:
			held_back.append(_packet(tick))
		if tick % 6 == 0:
			for packet: Array[PlayerCommands] in held_back:
				queue.receive(packet)
			held_back.clear()
		var frame := queue.next()
		if frame.seq > 0 and (played.is_empty() or frame.seq != played[-1]):
			played.append(frame.seq)
	var gaps := 0
	for i in range(1, played.size()):
		if played[i] != played[i - 1] + 1:
			gaps += 1
	assert_eq(gaps, 0, "every frame, in order, once")
	assert_eq(played[0], 1)
	assert_gt(played.size(), 220)


func test_prediction_gap_stays_zero_in_bursts() -> void:
	# The room's position after the frame it acknowledges equals the client's
	# predicted position at that number, as long as the queue never ran dry.
	var queue := CommandQueue.new(_settings)
	var room_x := 0.0
	var worst := 0.0
	var held_back: Array = []
	for tick in range(1, 301):
		if tick % 2 == 0:
			held_back.append(_packet(tick))
		if tick % 4 == 0:  # Bursts of 2 packets, 4 frames.
			for packet: Array[PlayerCommands] in held_back:
				queue.receive(packet)
			held_back.clear()
		var frame := queue.next()
		if frame.seq == 0:
			continue  # Waiting for the lead, before the first frame.
		room_x += 1.0  # One step per frame played.
		var predicted := float(frame.seq)  # The client's step count at that number.
		worst = maxf(worst, absf(room_x - predicted))
	assert_eq(worst, 0.0, "the number sent back is the frame really played")


func test_a_lost_packet_loses_no_frame_and_no_action_and_plays_none_twice() -> void:
	var queue := CommandQueue.new(_settings)
	var played: Array[int] = []
	var actions: Array = []
	queue.add_action(5, PlayerCommands.Action.THROW)  # Reliable, with its frame.
	queue.add_action(9, PlayerCommands.Action.DECOY)
	for tick in range(1, 41):
		if tick % 2 == 0 and tick != 10:  # The packet after frame 10 is lost.
			queue.receive(_packet(tick))
			queue.receive(_packet(tick))  # And one comes twice.
		var frame := queue.next()
		if frame.seq > 0 and (played.is_empty() or frame.seq > played[-1]):
			played.append(frame.seq)
		for action in frame.take_actions():
			actions.append([frame.seq, action])
	for i in range(1, played.size()):
		assert_eq(played[i], played[i - 1] + 1, "frame %d not lost" % played[i])
	assert_eq(
		actions,
		[[5, PlayerCommands.Action.THROW], [9, PlayerCommands.Action.DECOY]],
		"each action once, with its frame"
	)


func test_a_dry_queue_plays_the_last_frame_again_without_a_new_number() -> void:
	var queue := CommandQueue.new(_settings)
	queue.receive(_packet(4))
	var seqs := []
	for i in 8:
		seqs.append(queue.next().seq)
	assert_eq(seqs, [1, 2, 3, 4, 4, 4, 4, 4])
	var again := queue.next()
	assert_true(again.sprint, "the last frame held: frame 4 sprints")
	queue.receive(_packet(5))  # Back: it waits for its lead again.
	assert_eq(queue.next().seq, 4)


func test_an_action_whose_frame_is_lost_plays_with_the_next_one() -> void:
	var queue := CommandQueue.new(_settings)
	queue.add_action(5, PlayerCommands.Action.CROUCH)
	var frames: Array[PlayerCommands] = []
	for seq in [1, 2, 3, 4, 6, 7]:  # Frame 5 lost beyond the redundancy.
		frames.append(_frame(seq))
	queue.receive(frames)
	var got := []
	for i in 6:
		var frame := queue.next()
		for action in frame.take_actions():
			got.append([frame.seq, action])
	assert_eq(got, [[4, PlayerCommands.Action.CROUCH]], "once, not lost")


func test_an_action_whose_frame_never_comes_is_played_anyway() -> void:
	var queue := CommandQueue.new(_settings)
	queue.add_action(50, PlayerCommands.Action.CROUCH)
	var got := []
	for i in queue.action_wait + 1:
		got.append_array(queue.next().take_actions())
	assert_eq(got, [PlayerCommands.Action.CROUCH], "late, never lost")


func test_old_and_doubled_frames_are_dropped() -> void:
	var queue := CommandQueue.new(_settings)
	queue.receive(_packet(4))
	queue.receive(_packet(4))
	assert_eq(queue.size(), 4)
	for i in 4:
		queue.next()
	queue.receive(_packet(4))
	assert_eq(queue.size(), 0, "already played")
