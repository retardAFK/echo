extends GutTest
## Online sync of the players (S-010, Q5 and Q8, T-097): what each player is
## sent, interpolation of the others, prediction of one's own character.

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const BUILDING_SCENE := preload("res://game/entities/building/building.tscn")

var _settings: NetSettings


func before_each() -> void:
	_settings = NetSettings.new()


func test_buffer_interpolates_between_snapshots() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1.0, Vector3(0, 0, 0), 0.0)
	buffer.push(1.1, Vector3(1, 0, 0), 1.0)
	var pose := buffer.sample(1.05, 0.15)
	assert_almost_eq((pose[0] as Vector3).x, 0.5, 0.001)
	assert_almost_eq(pose[1], 0.5, 0.001)
	assert_eq(buffer.sample(0.5, 0.15)[0], Vector3.ZERO)


func test_buffer_extrapolates_a_little_then_stops() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1.0, Vector3(0, 0, 0), 0.0)
	buffer.push(1.1, Vector3(1, 0, 0), 0.0)
	assert_almost_eq((buffer.sample(1.2, 0.15)[0] as Vector3).x, 2.0, 0.001)
	assert_almost_eq((buffer.sample(5.0, 0.15)[0] as Vector3).x, 2.5, 0.001)


func test_buffer_drops_late_snapshots() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(1.0, Vector3(1, 0, 0), 0.0)
	buffer.push(0.9, Vector3(9, 0, 0), 0.0)
	assert_eq(buffer.sample(1.0, 0.0)[0], Vector3(1, 0, 0))


func test_prediction_ignores_tiny_gaps() -> void:
	var prediction := Prediction.new(_settings)
	prediction.record(1, Vector3(0, 0, 0))
	assert_eq(prediction.reconcile(1, Vector3(0.02, 0, 0)), Vector3.ZERO)
	assert_eq(prediction.pending, Vector3.ZERO)


func test_prediction_settles_small_gaps_slowly() -> void:
	# S-020, T-346: a gap under correction_threshold is no longer kept for
	# good. A player standing 0.45 m from where the room has it would aim at
	# a dropped fuse the room does not see it aim at (net_match stuck).
	var prediction := Prediction.new(_settings)
	var here := Vector3.ZERO
	var room := Vector3(0.45, 0, 0)
	var seq := 0
	for frame in 180:  # 3 s standing still, a snapshot every 3 frames.
		seq += 1
		prediction.record(seq, here)
		if frame % 3 == 0:
			here += prediction.reconcile(seq, room)
		here += prediction.step(1.0 / 60.0)
	assert_lt(here.distance_to(room), 0.05, "settled on the room's position")
	var first := Prediction.new(_settings)
	first.record(1, Vector3.ZERO)
	first.reconcile(1, room)
	assert_lt(first.step(1.0 / 60.0).length(), 0.02, "slowly: no visible jerk")


func test_prediction_corrects_medium_gaps_smoothly() -> void:
	var prediction := Prediction.new(_settings)
	prediction.record(1, Vector3.ZERO)
	prediction.record(2, Vector3(0, 0, -1))
	assert_eq(prediction.reconcile(1, Vector3(1, 0, 0)), Vector3.ZERO)
	var moved := Vector3.ZERO
	for i in 30:
		moved += prediction.step(1.0 / 60.0)
	assert_almost_eq(moved.x, 1.0, 0.01)
	assert_true(prediction.pending.is_zero_approx())
	assert_almost_eq(prediction.error_at(2, Vector3(1, 0, -1)).length(), 0.0, 0.01)


func test_prediction_jumps_on_large_gaps() -> void:
	var prediction := Prediction.new(_settings)
	prediction.record(1, Vector3.ZERO)
	assert_eq(prediction.reconcile(1, Vector3(5, 0, 0)), Vector3(5, 0, 0))
	assert_eq(prediction.pending, Vector3.ZERO)


func test_prediction_restart_ignores_older_frames() -> void:
	var prediction := Prediction.new(_settings)
	prediction.record(1, Vector3.ZERO)
	prediction.restart(1)
	assert_true(prediction.started)
	assert_false(prediction.knows(1))
	assert_eq(prediction.floor_seq, 1)


func test_visibility_rules() -> void:
	var eye := Vector3.ZERO
	var forward := Vector3.FORWARD
	assert_true(NetVisibility.sees(eye, forward, Vector3(0, 0, -10), false, true, _settings))
	assert_false(NetVisibility.sees(eye, forward, Vector3(0, 0, -10), true, true, _settings))
	assert_false(NetVisibility.sees(eye, forward, Vector3(0, 0, -10), false, false, _settings))
	assert_false(NetVisibility.sees(eye, forward, Vector3(0, 0, -50), false, true, _settings))
	assert_false(
		NetVisibility.sees(eye, forward, Vector3(0, 0, 10), false, true, _settings), "behind"
	)
	assert_true(NetVisibility.sees(eye, forward, Vector3(10, 0, 0), false, true, _settings), "side")
	assert_true(NetVisibility.sees(eye, forward, Vector3(0, 0, 0.5), false, true, _settings))


func _body(size: Vector3, at: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child_autofree(body)


func _player(at: Vector3, yaw: float) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	player.position = at
	player.rotation.y = yaw
	player.commands.yaw = yaw
	add_child_autofree(player)
	return player


func test_room_sends_only_who_each_player_sees() -> void:
	_body(Vector3(100, 1, 100), Vector3(0, -0.5, 0), 1)
	_body(Vector3(10, 4, 0.5), Vector3(0, 2, -20), NoiseBus.WALLS_COLLISION_MASK)
	var net := NetGame.new()
	net.settings = _settings
	net.is_room = true
	add_child_autofree(net)
	var viewer := _player(Vector3.ZERO, 0.0)
	var seen := _player(Vector3(0, 0, -10), 0.0)
	var behind_wall := _player(Vector3(0, 0, -25), 0.0)
	var hidden_far := _player(Vector3(30, 0, 30), 0.0)
	net.add_avatar(1, 1, viewer)
	net.add_avatar(2, 2, seen)
	net.add_avatar(3, 3, behind_wall)
	net.add_avatar(4, LobbyState.MONSTER_SEAT, hidden_far)
	await wait_physics_frames(3)
	var snapshot := net.snapshot_for(1)
	var seats: Array = snapshot["others"].map(func(entry: Array) -> int: return entry[0])
	assert_eq(seats, [2], "only the player in front, in the open")
	assert_eq(snapshot["you"][0], viewer.global_position)
	var from_wall := net.snapshot_for(3)
	assert_false(
		from_wall["others"].any(func(entry: Array) -> bool: return entry[0] == 1),
		"the wall hides the viewer"
	)
	var text := var_to_str(net.snapshot_for(2))
	assert_false(text.contains(str(hidden_far.global_position.x)), "nothing of an unseen player")


func test_remote_player_follows_commands_look() -> void:
	_body(Vector3(100, 1, 100), Vector3(0, -0.5, 0), 1)
	var player := _player(Vector3.ZERO, 0.0)
	player.commands.yaw = 1.0
	player.commands.pitch = 0.3
	await wait_physics_frames(2)
	assert_almost_eq(player.rotation.y, 1.0, 0.0001)
	assert_almost_eq(player.get_pitch(), 0.3, 0.0001)


func test_puppet_moves_between_snapshots() -> void:
	var puppet := NetPuppet.new()
	add_child_autofree(puppet)
	puppet.buffer.push(1.0, Vector3(0, 0, 0), 0.0)
	puppet.buffer.push(1.1, Vector3(2, 0, 0), 0.0)
	puppet.show_at(1.05, 0.15)
	assert_almost_eq(puppet.global_position.x, 1.0, 0.001)
	assert_eq(puppet.get_child_count(), 1, "a silhouette")


func _room() -> NetGame:
	var net := NetGame.new()
	net.settings = _settings
	net.is_room = true
	add_child_autofree(net)
	return net


func _events_for(net: NetGame, place: int) -> Array:
	return (
		net
		. sent_events
		. filter(func(sent: Array) -> bool: return sent[0] == place)
		. map(func(sent: Array) -> Array: return sent[1])
	)


func test_noise_goes_to_who_hears_it_without_its_maker() -> void:
	_body(Vector3(100, 1, 100), Vector3(0, -0.5, 0), 1)
	var hunted := _player(Vector3.ZERO, 0.0)
	var other := _player(Vector3(0, 0, -4), 0.0)
	var monster: MonsterAvatar = AVATAR_SCENE.instantiate()
	monster.local_controls = false
	monster.position = Vector3(40, 0, 0)
	add_child_autofree(monster)
	await wait_physics_frames(2)
	var near := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, other.global_position, 8.0, other)
	var message := NetGame.noise_message(near, hunted, false)
	assert_eq(
		message, [NetGame.Event.NOISE, NoiseEvent.Type.FOOTSTEP, other.global_position, 8.0, false]
	)
	assert_eq(NetGame.noise_message(near, other, false), [], "not its own noise")
	assert_eq(NetGame.noise_message(near, monster, false), [], "too far to hear")
	assert_eq(NetGame.noise_message(near, monster, true).size(), 5, "the monster gets every noise")
	var silent := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, 0.0, other)
	assert_eq(NetGame.noise_message(silent, monster, true), [])


func test_a_hunted_is_never_sent_a_player_it_does_not_see_or_hear() -> void:
	_body(Vector3(100, 1, 100), Vector3(0, -0.5, 0), 1)
	var net := _room()
	var viewer := _player(Vector3.ZERO, 0.0)
	var unseen := _player(Vector3(27.5, 0, 31.5), 0.0)
	var monster: MonsterAvatar = AVATAR_SCENE.instantiate()
	monster.local_controls = false
	monster.position = Vector3(-33.5, 0, 22.5)
	add_child_autofree(monster)
	net.add_avatar(1, 1, viewer)
	net.add_avatar(2, 2, unseen)
	net.add_avatar(3, LobbyState.MONSTER_SEAT, monster)
	await wait_physics_frames(3)
	net.sent_events.clear()
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, unseen.global_position, 6.0, unseen)
	NoiseBus.emit_noise(NoiseEvent.Type.BREATH, monster.global_position, 2.0, monster)
	var text := var_to_str(_events_for(net, 1)) + var_to_str(net.snapshot_for(1))
	for far: Node3D in [unseen, monster]:
		assert_false(text.contains(str(far.global_position.x)), "nothing of %s" % far.name)
	assert_eq(_events_for(net, 3).size(), 1, "the monster gets the footstep")


func test_scan_lights_go_to_the_hunted_only() -> void:
	var building: Building = BUILDING_SCENE.instantiate()
	building.settings = MonsterSettings.new()
	add_child_autofree(building)
	var net := NetGame.new()
	net.settings = _settings
	net.is_room = true
	net.buildings = [building]
	net.add_avatar(1, 1, Node3D.new())
	net.add_avatar(2, LobbyState.MONSTER_SEAT, Node3D.new())
	add_child_autofree(net)
	building.scanned = true
	assert_eq(_events_for(net, 1), [[NetGame.Event.SCAN, 0, true]])
	assert_eq(_events_for(net, 2), [], "the monster sees its own scan")
	for avatar: Node in net.avatars.values():
		avatar.free()
	net.avatars.clear()


func test_a_human_monster_catches_a_hunted_it_touches() -> void:
	_body(Vector3(100, 1, 100), Vector3(0, -0.5, 0), 1)
	var net := _room()
	var hunted := _player(Vector3(0, 0, -1), 0.0)
	var free_one := _player(Vector3(10, 0, 0), 0.0)
	var monster: MonsterAvatar = AVATAR_SCENE.instantiate()
	monster.local_controls = false
	add_child_autofree(monster)
	net.add_avatar(1, 1, hunted)
	net.add_avatar(2, 2, free_one)
	net.add_avatar(3, LobbyState.MONSTER_SEAT, monster)
	watch_signals(net)
	net._check_catches()
	assert_signal_emitted_with_parameters(net, "hunted_caught", [hunted])
	assert_eq(monster.catch_count, 1)
	assert_signal_emit_count(net, "hunted_caught", 1, "not the one far away")


func test_client_plays_the_room_events() -> void:
	var building: Building = BUILDING_SCENE.instantiate()
	building.settings = MonsterSettings.new()
	add_child_autofree(building)
	var net := NetGame.new()
	net.settings = _settings
	net.buildings = [building]
	add_child_autofree(net)
	var heard := []
	var listen := func(event: NoiseEvent) -> void: heard.append(event)
	NoiseBus.noise_emitted.connect(listen)
	net.apply_event([NetGame.Event.NOISE, NoiseEvent.Type.BREATH, Vector3(1, 2, 3), 2.5])
	NoiseBus.noise_emitted.disconnect(listen)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0].position, Vector3(1, 2, 3))
	assert_null(heard[0].source, "nobody's noise")
	net.apply_event([NetGame.Event.SCAN, 0, true])
	assert_true(building.scanned)
	net.apply_event([NetGame.Event.SCAN, 5, false])
	watch_signals(net)
	net.apply_event([NetGame.Event.CAUGHT, 2, CaptureState.State.OUT])
	assert_signal_emitted_with_parameters(net, "caught_reported", [2, CaptureState.State.OUT])
	net.apply_event([])


func test_a_client_monster_stops_when_the_room_stopped_it() -> void:
	# S-020, T-310: the room stops it at an empty hiding spot, which the client
	# cannot predict; a stop it predicted itself (a door) is not counted twice.
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	avatar.local_controls = false
	add_child_autofree(avatar)
	var net := NetGame.new()
	autofree(net)
	net.own = avatar
	net.prediction = Prediction.new(net.settings)
	var you := [Vector3.ZERO, Vector3.ZERO, 0.0, 0, false, 0.0, 0, 0, -1, false, -1, -1]
	net.apply_snapshot({"ack": 0, "you": you + [[1, 0.9]], "others": []})
	assert_eq(avatar.stagger.left, 0.9, "stopped by the room")
	assert_eq(avatar.stagger.count, 1)
	avatar.stagger.update(1.0)
	net.apply_snapshot({"ack": 0, "you": you + [[1, 0.2]], "others": []})
	assert_eq(avatar.stagger.left, 0.0, "the same stop: not again")
	avatar.stagger.hit(0.8)  # Predicted here: a door.
	avatar.stagger.update(1.0)
	net.apply_snapshot({"ack": 0, "you": you + [[2, 0.5]], "others": []})
	assert_eq(avatar.stagger.left, 0.0, "already counted")
	assert_eq(NetGame._stagger_of(Node3D.new()), [0, 0.0], "a hunted")
