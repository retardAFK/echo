extends GutTest
## Online sync of the players (S-010, Q5 and Q8, T-097): what each player is
## sent, interpolation of the others, prediction of one's own character.

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")

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


func test_prediction_ignores_small_gaps() -> void:
	var prediction := Prediction.new(_settings)
	prediction.record(1, Vector3(0, 0, 0))
	assert_eq(prediction.reconcile(1, Vector3(0.2, 0, 0)), Vector3.ZERO)
	assert_eq(prediction.pending, Vector3.ZERO)


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
