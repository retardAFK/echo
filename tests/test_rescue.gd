extends GutTest
## Capture, rescue and spectator of an online game (S-010, Q2, T-107): caught
## once, a hunted waits on its knees for a teammate; caught twice, it is out
## and watches a teammate. Solo is unchanged.

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")

var _heard := []


func before_each() -> void:
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)
	NetSession.mode = NetSession.Mode.SOLO
	GameSession.online_lobby = null
	GameSession.game_seed = 0


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func _of(type: NoiseEvent.Type) -> Array:
	return _heard.filter(func(event: NoiseEvent) -> bool: return event.type == type)


func _count(type: NoiseEvent.Type) -> int:
	return _of(type).size()


func _ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child_autofree(ground)


## A hunted of the room, with its capture rule.
func _hunted(at: Vector3) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	player.position = at
	add_child_autofree(player)
	player.capture = CaptureState.new()
	player.add_child(player.capture)
	player.capture.changed.connect(
		func(state: CaptureState.State) -> void: player.held = state != CaptureState.State.FREE
	)
	return player


func test_caught_once_it_calls_for_help_and_a_teammate_frees_it() -> void:
	_ground()
	var captured := _hunted(Vector3.ZERO)
	var teammate := _hunted(Vector3(0, 0, -1))
	var noise := NoiseBus.settings
	assert_eq(captured.capture.catch(), CaptureState.State.CAPTURED)
	assert_true(captured.held)
	await wait_physics_frames(2)
	assert_eq(_count(NoiseEvent.Type.CALL), 1, "a call at once")
	for i in roundi(noise.call_interval * 2.0 / 0.1) + 1:
		captured.capture._physics_process(0.1)
	assert_eq(_count(NoiseEvent.Type.CALL), 3, "then every call_interval")
	var call: NoiseEvent = _of(NoiseEvent.Type.CALL)[0]
	assert_eq(call.noise_range, noise.call_range)
	assert_eq(call.source, captured)
	# The captured one cannot free itself; the teammate in reach can.
	assert_false(captured.capture.wanted_by(captured))
	assert_true(captured.capture.can_interact(teammate.global_position))
	assert_false(captured.capture.can_interact(Vector3(0, 0, -3)), "1.5 m at most")
	assert_eq(captured.capture.get_prompt(), "HUD_INTERACT_RESCUE")
	var rescue_time: float = captured.settings.rescue_time
	captured.capture.hold(teammate, rescue_time - 0.1)
	captured.capture.release(teammate)
	assert_eq(captured.capture.get_hold_ratio(), 0.0, "letting go starts over")
	captured.capture.hold(teammate, rescue_time - 0.1)
	assert_true(captured.held, "not yet")
	captured.capture.hold(teammate, 0.2)
	assert_false(captured.held, "freed after holding rescue_time")
	assert_eq(_count(NoiseEvent.Type.RESCUE), 3, "two starts and the end")
	assert_false(captured.capture.is_in_group(Interactable.GROUP))


func test_caught_twice_it_is_out() -> void:
	var hunted := _hunted(Vector3.ZERO)
	hunted.capture.catch()
	assert_eq(hunted.capture.catch(), CaptureState.State.CAPTURED, "already caught: no change")
	hunted.capture._set_state(CaptureState.State.FREE)
	assert_eq(hunted.capture.catch(), CaptureState.State.OUT)
	assert_false(CaptureState.is_free_hunted(hunted))


func test_a_captured_hunted_neither_moves_nor_acts() -> void:
	_ground()
	var hunted := _hunted(Vector3.ZERO)
	hunted.inventory.take(Inventory.Kind.BOTTLE)
	hunted.held = true
	hunted.commands.move = Vector2(0, -1)
	hunted.commands.push(PlayerCommands.Action.THROW)
	await wait_physics_frames(10)
	assert_almost_eq(
		Vector2(hunted.global_position.x, hunted.global_position.z).length(), 0.0, 0.01
	)
	assert_eq(hunted.inventory.count(Inventory.Kind.BOTTLE), 1)
	assert_eq(hunted.get_gait(), PlayerMotion.Gait.CROUCH, "on its knees")
	assert_null(hunted.get_interactable())


func test_a_captured_hunted_drops_its_fuses_a_teammate_takes_them() -> void:
	var map: Node3D = add_child_autofree(Node3D.new())
	var team: Array[Node] = []
	for i in 3:
		var member := Node3D.new()
		member.position = Vector3(i * 10, 0, 0)
		map.add_child(member)
		team.append(member)
	var loop := GameLoop.new()
	loop.settings = LOOP_SETTINGS
	loop.hunted = team[0]
	loop.team = team
	map.add_child(loop)
	loop.setup(map, 1)
	loop._on_fuse_taken(team[1])
	loop._on_fuse_taken(team[1])
	watch_signals(loop)
	loop.set_captured(team[1], true)
	assert_eq(loop.carried_by(team[1]), 0)
	assert_eq(loop.rules.found(), 0)
	assert_eq(loop.drops.size(), 2)
	assert_almost_eq(loop.drops[0].global_position.distance_to(Vector3(10, 0, 0)), 0.0, 0.5)
	assert_eq(loop.free_count(), 2)
	assert_false(loop.is_over)
	var drop: FuseBox = loop.drops[0]
	assert_true(drop.can_interact(Vector3(10, 0, 1)))
	drop.hold(team[2], LOOP_SETTINGS.pickup_time + 0.1)
	assert_eq(loop.carried_by(team[2]), 1, "taken like from a fuse box")
	assert_eq(loop.drops.size(), 1)
	assert_true(drop.is_queued_for_deletion())
	assert_eq(loop.drop_positions().size(), 1)
	# Freed, then the others out or captured: the monster wins.
	loop.set_captured(team[1], false)
	assert_eq(loop.free_count(), 3)
	loop.hunted_out(team[0])
	loop.set_captured(team[1], true)
	assert_false(loop.is_over)
	loop.set_captured(team[2], true)
	assert_true(loop.is_over, "none free")
	assert_false(loop.hunted_won)


func test_a_captured_hunted_cannot_get_out() -> void:
	var team: Array[Node] = [add_child_autofree(Node3D.new()), add_child_autofree(Node3D.new())]
	var loop := GameLoop.new()
	loop.settings = LOOP_SETTINGS
	loop.hunted = team[0]
	loop.team = team
	add_child_autofree(loop)
	loop.rules.placed = loop.rules.fuse_count
	loop.set_captured(team[0], true)
	loop._on_exit_reached(team[0])
	assert_false(loop.is_over)
	loop._on_exit_reached(team[1])
	assert_true(loop.hunted_won)


func test_a_client_mirrors_the_dropped_fuses() -> void:
	var map: Node3D = add_child_autofree(Node3D.new())
	var loop := GameLoop.new()
	loop.settings = LOOP_SETTINGS
	loop.mirror = true
	map.add_child(loop)
	loop.setup(map)
	loop.apply_drops([Vector3(1, 0, 1), Vector3(5, 0, 5)])
	assert_eq(loop.drops.size(), 2)
	var kept: FuseBox = loop.drops[1]
	loop.apply_drops([Vector3(5, 0, 5)])
	assert_eq(loop.drops, [kept] as Array[FuseBox], "the one taken in the room goes")


func test_a_spectator_watches_a_teammate_and_switches() -> void:
	_ground()
	var net := NetGame.new()
	net.is_room = true
	add_child_autofree(net)
	var out := _hunted(Vector3.ZERO)
	var first := _hunted(Vector3(5, 0, 0))
	var second := _hunted(Vector3(-5, 0, 0))
	net.add_avatar(1, 1, out)
	net.add_avatar(2, 2, first)
	net.add_avatar(3, 3, second)
	first.capture.catch()
	var snapshot := net.snapshot_for(2)
	assert_eq(snapshot["you"][9], true, "it knows it is captured")
	assert_eq(net._entry(2, first)[4], true, "seen on its knees")
	out.capture.catch()
	out.capture._set_state(CaptureState.State.FREE)
	out.capture.catch()
	net.spectate(out)
	snapshot = net.snapshot_for(1)
	assert_false(snapshot.has("you"))
	assert_eq(snapshot["watch"], 2)
	assert_eq(snapshot["others"][0][0], 2, "the watched one first")
	for other: Array in net.snapshot_for(3)["others"]:
		assert_ne(other[0], 1, "out of the game: nobody sees it")
	# "interact" from the spectator: the next teammate.
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.INTERACT)
	for action in commands.take_actions():
		if action == PlayerCommands.Action.INTERACT:
			net._watching[1] = net._next_watched(net._watching[1])
	assert_eq(net.snapshot_for(1)["watch"], 3)
	net._watching[1] = net._next_watched(net._watching[1])
	assert_eq(net.snapshot_for(1)["watch"], 2, "round again")
	# The watched one out too: the next one still in the game.
	first.capture._set_state(CaptureState.State.OUT)
	assert_eq(net.snapshot_for(1)["watch"], 3)
	net.avatars.clear()


func test_a_client_spectates_and_sees_captured_teammates_down() -> void:
	_ground()
	var parent: Node3D = add_child_autofree(Node3D.new())
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	parent.add_child(player)
	var net := NetGame.new()
	net.own = player
	parent.add_child(net)
	net.apply_snapshot(
		{"ack": 0, "you": [Vector3.ZERO, Vector3.ZERO, 0.0, 0, false, 0.0, 0, 0, -1, true]}
	)
	assert_true(player.held)
	(
		net
		. apply_snapshot(
			{
				"ack": 0,
				"you": [Vector3.ZERO, Vector3.ZERO, 0.0, 0, false, 0.0, 0, 0, -1, false],
				"others": [[2, Vector3(1, 0, 0), 0.0, 0, true]],
			}
		)
	)
	var puppet: NetPuppet = net.puppets[2]
	assert_true(puppet.down)
	assert_true(puppet.is_in_group(Interactable.GROUP))
	assert_true(puppet.can_interact(Vector3(0, 0, 0)))
	assert_eq(puppet.get_prompt(), "HUD_INTERACT_RESCUE")
	assert_true(puppet.wanted_by(player))
	assert_lt(puppet.get_eye_height(), 1.0, "on its knees")
	watch_signals(net)
	net.apply_snapshot({"ack": 0, "watch": 2, "pitch": 0.3, "others": [[2, Vector3.ZERO, 1.0, 0]]})
	assert_true(net.is_spectator)
	assert_signal_emitted(net, "spectating")
	assert_eq(player.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(puppet.down, "freed")
	var view := SpectatorView.new()
	view.net = net
	parent.add_child(view)
	net.puppets[2].global_position = Vector3(3, 0, 3)
	view._process(0.0)
	assert_almost_eq(view._camera.global_position.x, 3.0, 0.001)
	assert_almost_eq(view._camera.global_rotation.x, 0.3, 0.001)
	assert_true(view._camera.current)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	view._unhandled_input(click)
	assert_eq(player.commands.peek_actions(), [PlayerCommands.Action.INTERACT] as Array)


func test_online_room_capture_rule_on_the_cite() -> void:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = [0, 11, 12, 0]
	GameSession.online_lobby = lobby
	GameSession.game_seed = 3
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var net: NetGame = map.get_node("NetGame")
	var hunted: Player = net.avatars[11]
	var teammate: Player = net.avatars[12]
	var monster: Monster = map.get_node("Monster")
	map.game_loop._on_fuse_taken(hunted)
	map._online_catch(hunted)
	assert_true(hunted.held)
	assert_eq(map.game_loop.drops.size(), 1, "its fuse at its feet")
	assert_does_not_have(monster.get_targets(), hunted, "the AI monster leaves it")
	assert_has(net.sent_events, [11, [NetGame.Event.CAUGHT, 1, CaptureState.State.CAPTURED]])
	teammate.global_position = hunted.global_position + Vector3(0.5, 0, 0)
	hunted.capture.hold(teammate, teammate.settings.rescue_time + 0.1)
	assert_false(hunted.held)
	assert_has(monster.get_targets(), hunted, "chased again")
	assert_has(net.sent_events, [12, [NetGame.Event.CAUGHT, 1, CaptureState.State.FREE]])
	map._online_catch(hunted)
	assert_eq(hunted.capture.state, CaptureState.State.OUT)
	assert_eq(hunted.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(map.game_loop.free_count(), 1)
	assert_false(map.game_loop.is_over)
	assert_eq(net.snapshot_for(11)["watch"], 2, "it watches its teammate")
	map._online_catch(teammate)
	assert_true(map.game_loop.is_over, "none free: the monster wins")
	assert_false(map.game_loop.hunted_won)
