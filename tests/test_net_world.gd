extends GutTest
## Online game loop and ruses (S-010, T-099): the room's map and loop, copied
## on the clients; a client's world only mirrors the room's.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const END_SCENE := preload("res://game/ui/end_screen.tscn")


func after_each() -> void:
	NoiseBus.mirror = false
	NoiseBus.local_source = null
	get_tree().paused = false


## A map and its world, listed before the map draws anything, as GameMap does.
func _map(game_seed: int) -> Array:
	GameSession.game_seed = game_seed
	var map: GameMap = MAP_SCENE.instantiate()
	var world := NetWorld.new(map)
	add_child_autofree(map)
	map.end_screen.change_scene = false
	GameSession.game_seed = 0
	world.game_loop = map.game_loop
	return [map, world]


func test_a_client_map_and_loop_follow_the_room() -> void:
	var made := _map(11)
	var room: GameMap = made[0]
	var room_world: NetWorld = made[1]
	made = _map(22)
	var client: GameMap = made[0]
	var client_world: NetWorld = made[1]
	client.game_loop.mirror = true
	assert_eq(room_world.boxes.size(), 24)
	assert_eq(room_world.pickups.size(), client_world.pickups.size(), "same list on both sides")
	# A fuse taken in the room, an alarm set off, a bottle picked up.
	var box: FuseBox = room.game_loop.fused_boxes[0]
	box.set_fuse(false)
	room.game_loop.rules.take_fuse()
	room_world.alarms[0].interact(null)
	var bottle_index := 0
	while room_world.pickups[bottle_index].kind != Inventory.Kind.BOTTLE:
		bottle_index += 1
	room_world.pickups[bottle_index].queue_free()
	watch_signals(client.game_loop)
	client_world.apply(room_world.state())
	for i in room_world.boxes.size():
		assert_eq(client_world.boxes[i].has_fuse, room_world.boxes[i].has_fuse, "box %d" % i)
	assert_true(client_world.pickups[bottle_index].is_queued_for_deletion())
	assert_eq(client_world.alarms[0].state, CarAlarm.State.RINGING)
	assert_eq(client.game_loop.rules.found(), 1)
	assert_signal_emitted(client.game_loop, "fuses_changed")
	# Repaired and out: the client opens the exit and shows the end.
	room.game_loop.rules.carried = 0
	room.game_loop.rules.placed = room.game_loop.rules.fuse_count
	room.game_loop.finish(true)
	client_world.apply(room_world.state())
	assert_true(client.game_loop.is_exit_open())
	assert_signal_emitted(client.game_loop, "exit_opened")
	assert_true(client.game_loop.is_over)
	assert_true(client.game_loop.hunted_won)
	assert_true(client.end_screen.visible)


func test_the_room_draws_alarm_clocks_the_client_removes_them() -> void:
	var room_world: NetWorld = _map(5)[1]
	assert_eq(room_world.pickups.size(), 30, "listed before the draw")
	var present: Array = room_world.state()[1]
	assert_eq(present.count(false), 6, "10 places, 4 alarm clocks kept")


func test_a_mirroring_player_moves_but_does_not_act() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child_autofree(ground)
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	player.mirror_world = true
	add_child_autofree(player)
	player.inventory.take(Inventory.Kind.BOTTLE)
	player.commands.push(PlayerCommands.Action.THROW)
	player.commands.push(PlayerCommands.Action.CROUCH)
	await wait_physics_frames(2)
	assert_eq(player.inventory.count(Inventory.Kind.BOTTLE), 1, "the room throws it")
	assert_eq(get_tree().get_nodes_in_group(Decoy.GROUP).size(), 0)
	assert_eq(player.get_gait(), PlayerMotion.Gait.CROUCH, "crouching is its own")
	player.remote_hold_ratio = 0.4
	assert_eq(player.get_hold_ratio(), 0.4)


func test_on_a_client_only_the_local_avatar_and_the_room_make_noise() -> void:
	var heard := []
	var listen := func(event: NoiseEvent) -> void: heard.append(event.source)
	NoiseBus.noise_emitted.connect(listen)
	var own := Node3D.new()
	var other := Node3D.new()
	NoiseBus.mirror = true
	NoiseBus.local_source = own
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, 5.0, own)
	NoiseBus.emit_noise(NoiseEvent.Type.CAR_ALARM, Vector3.ZERO, 5.0, other)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, 5.0, null)
	NoiseBus.noise_emitted.disconnect(listen)
	assert_eq(heard, [own, null])
	own.free()
	other.free()


func test_the_room_announces_a_thrown_bottle_and_a_placed_alarm_clock() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var net := NetGame.new()
	net.is_room = true
	parent.add_child(net)
	net.add_avatar(1, 1, Node3D.new())
	var bottle: ThrownBottle = NetGame.BOTTLE_SCENE.instantiate()
	bottle.gravity_scale = 0.0
	parent.add_child(bottle)
	bottle.global_position = Vector3(1, 2, 3)
	bottle.linear_velocity = Vector3(0, 0, -5)
	var decoy: Decoy = NetGame.DECOY_SCENE.instantiate()
	parent.add_child(decoy)
	decoy.global_position = Vector3(4, 0, 4)
	await wait_physics_frames(1)
	var events: Array = net.sent_events.map(func(sent: Array) -> Array: return sent[1])
	assert_has(events, [NetGame.Event.BOTTLE, Vector3(1, 2, 3), Vector3(0, 0, -5)])
	assert_has(events, [NetGame.Event.DECOY, Vector3(4, 0, 4)])
	decoy.timer.state = DecoyTimer.State.RINGING
	decoy.crush()
	assert_eq(net.sent_events.back()[1], [NetGame.Event.CRUSH, Vector3(4, 0, 4)])
	net.avatars[1].free()
	net.avatars.clear()


func test_a_client_plays_copies_of_bottles_and_alarm_clocks() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var net := NetGame.new()
	parent.add_child(net)
	net.apply_event([NetGame.Event.BOTTLE, Vector3(0, 5, 0), Vector3(1, 0, 0)])
	net.apply_event([NetGame.Event.DECOY, Vector3(2, 0, 2)])
	var bottles := parent.get_children().filter(
		func(node: Node) -> bool: return node is ThrownBottle
	)
	assert_eq(bottles.size(), 1)
	assert_eq((bottles[0] as ThrownBottle).linear_velocity, Vector3(1, 0, 0))
	var decoys := get_tree().get_nodes_in_group(Decoy.GROUP)
	assert_eq(decoys.size(), 1)
	(decoys[0] as Decoy).timer.state = DecoyTimer.State.RINGING
	net.apply_event([NetGame.Event.CRUSH, Vector3(2, 0, 2.5)])
	assert_eq((decoys[0] as Decoy).timer.state, DecoyTimer.State.DONE)


func test_the_waiting_room_comes_back_after_a_game() -> void:
	var lobby := LobbyState.new()
	lobby.add_player(1)
	lobby.add_player(2)
	lobby.set_ready(1, true)
	lobby.set_ready(2, true)
	assert_true(lobby.start(lobby.leader))
	lobby.finish()
	assert_false(lobby.started)
	assert_false(lobby.is_ready(1), "everyone says again they are ready")
	assert_true(lobby.add_player(3), "newcomers welcome again")


func test_online_end_screen_goes_back_to_the_waiting_room() -> void:
	var screen: EndScreen = END_SCENE.instantiate()
	screen.online = true
	screen.change_scene = false
	add_child_autofree(screen)
	assert_eq((screen.get_node("%ReplayButton") as Button).text, "END_BACK_TO_LOBBY")
