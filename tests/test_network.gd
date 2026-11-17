extends GutTest
## The network of the cité (S-018, part B, T-263): a hunted sits at a
## terminal and watches through the security cameras; the monster switches a
## terminal off and smashes a camera; a hunted in a cage goes through the
## cameras; online, a hunted also sees what its camera sees.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const TERMINAL_SCENE := preload("res://game/entities/network/terminal.tscn")
const CAMERA_SCENE := preload("res://game/entities/network/security_camera.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const SETTINGS := preload("res://game/data/network_settings.tres")
const PRISON_SETTINGS := preload("res://game/data/prison_settings.tres")
## In the cellar corridor, in front of its camera (world, on the floor).
const CELLAR_SPOT := Vector3(15.0, -3.0, -12.8)

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


func _ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child_autofree(ground)


## A small network: one terminal at the origin, one camera looking at it.
func _small_network() -> CityNetwork:
	var root := Node3D.new()
	add_child_autofree(root)
	var terminal: Terminal = TERMINAL_SCENE.instantiate()
	terminal.label_key = "NET_TERM_TOWER"
	root.add_child(terminal)
	var camera: SecurityCamera = CAMERA_SCENE.instantiate()
	camera.label_key = "NET_CAM_TOWER_HALL"
	root.add_child(camera)
	camera.transform = Transform3D(
		Basis.looking_at(Vector3(0, 1, 0) - Vector3(6, 3, 6), Vector3.UP), Vector3(6, 3, 6)
	)
	var network := CityNetwork.new()
	root.add_child(network)
	return network


func _player(at: Vector3) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	player.position = at
	add_child_autofree(player)
	return player


func _room(seats: Array[int]) -> GameMap:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = seats
	GameSession.online_lobby = lobby
	GameSession.game_seed = 5
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	return map


func test_a_hunted_sits_at_a_terminal_and_types() -> void:
	_ground()
	var network := _small_network()
	var terminal := network.terminals[0]
	var player := _player(terminal.seat_point() + Vector3(0.3, 0, 0.2))
	assert_true(terminal.can_interact(player.global_position))
	assert_true(terminal.wanted_by(player))
	assert_eq(terminal.get_prompt(), "HUD_INTERACT_TERMINAL")
	terminal.hold(player, SETTINGS.sit_time - 0.1)
	assert_null(player.terminal, "not yet")
	terminal.hold(player, 0.2)
	assert_eq(player.terminal, terminal)
	assert_true(terminal.is_in_use())
	assert_eq(terminal.get_prompt(), "", "taken")
	var seat := terminal.seat_point()
	assert_almost_eq(
		Vector2(player.global_position.x, player.global_position.z).distance_to(
			Vector2(seat.x, seat.z)
		),
		0.0,
		0.01
	)
	assert_true(terminal.get_node("ScreenLight").visible, "the screen lights its face")
	assert_null(player.get_interactable(), "nothing else while seated")
	await wait_physics_frames(3)
	var keys := _of(NoiseEvent.Type.KEYBOARD)
	assert_eq(keys.size(), 1, "the first keys at once")
	assert_eq(keys[0].noise_range, SETTINGS.keyboard_range)
	assert_eq(keys[0].source, player)
	assert_eq(player.get_gesture(), HuntedBody.Gesture.WORK)
	# Still while seated; moving gets it up.
	var at := player.global_position
	player.commands.move = Vector2(0, -1)
	await wait_physics_frames(2)
	assert_null(player.terminal)
	assert_false(terminal.is_in_use())
	assert_false(terminal.get_node("ScreenLight").visible)
	assert_almost_eq(player.global_position.distance_to(at), 0.0, 0.3)


func test_interact_gets_up_and_hands_stay_on_the_keyboard() -> void:
	_ground()
	var network := _small_network()
	var terminal := network.terminals[0]
	var player := _player(terminal.seat_point())
	terminal.sit(player)
	player.commands.push(PlayerCommands.Action.THROW)
	player.apply_actions()
	assert_eq(player.inventory.count(Inventory.Kind.BOTTLE), 0)
	assert_eq(player.terminal, terminal, "a click does not throw anything")
	player.commands.push(PlayerCommands.Action.INTERACT)
	player.apply_actions()
	assert_null(player.terminal)


func test_the_monster_switches_a_terminal_off() -> void:
	_ground()
	var network := _small_network()
	var terminal := network.terminals[0]
	var player := _player(terminal.seat_point())
	terminal.sit(player)
	var monster: MonsterAvatar = AVATAR_SCENE.instantiate()
	monster.local_controls = false
	add_child_autofree(monster)
	monster.global_position = terminal.seat_point() + Vector3(0.5, 0, 0)
	assert_true(terminal.wanted_by(monster))
	assert_eq(terminal.get_prompt_for(monster), "HUD_MONSTER_SWITCH_OFF")
	terminal.hold(monster, SETTINGS.monster_hold + 0.01)
	assert_false(terminal.is_on())
	assert_null(player.terminal, "thrown off")
	assert_false(terminal.wanted_by(player), "off: nobody sits")
	assert_false(terminal.wanted_by(monster))
	terminal._physics_process(SETTINGS.off_time - 1.0)
	assert_false(terminal.is_on())
	terminal._physics_process(1.5)
	assert_true(terminal.is_on(), "back on after a minute")


func test_watching_a_camera_lights_its_led_and_moves_the_view() -> void:
	_ground()
	var network := _small_network()
	var terminal := network.terminals[0]
	var camera := network.cameras[0]
	var player := _player(terminal.seat_point())
	terminal.sit(player)
	var entries := network.entries_for(terminal)
	assert_eq(entries, [[CityNetwork.Entry.CAMERA, 0, "NET_CAM_TOWER_HALL"]])
	assert_false(camera.is_led_lit())
	player.commands.push_pick(0)
	player.apply_actions()
	assert_eq(player.watching, camera)
	assert_eq(camera.watchers, 1)
	assert_true(camera.is_led_lit(), "the red LED")
	player._process(0.0)
	var view: Camera3D = player.get_node("Head/Camera3D")
	assert_almost_eq(view.global_position.distance_to(camera.eye_position()), 0.0, 0.01)
	player.commands.push_pick(0)
	player.apply_actions()
	assert_null(player.watching, "the same line again: back to its eyes")
	assert_false(camera.is_led_lit())
	player._process(0.0)
	assert_false(view.top_level)
	player.commands.push_pick(5)  # No such line.
	player.apply_actions()
	assert_null(player.watching)
	player.commands.push_pick(0)
	player.apply_actions()
	terminal.leave()
	assert_null(player.watching, "getting up stops it")
	assert_eq(camera.watchers, 0)


func test_the_monster_smashes_a_watched_camera() -> void:
	_ground()
	var network := _small_network()
	var terminal := network.terminals[0]
	var camera := network.cameras[0]
	var player := _player(terminal.seat_point())
	terminal.sit(player)
	network.watch(player, camera)
	var monster: MonsterAvatar = AVATAR_SCENE.instantiate()
	monster.local_controls = false
	add_child_autofree(monster)
	monster.global_position = Vector3(camera.global_position.x, 0, camera.global_position.z)
	assert_true(camera.can_interact(monster.global_position))
	assert_false(camera.wanted_by(player), "only the monster")
	assert_eq(camera.get_prompt_for(monster), "HUD_MONSTER_SMASH_CAMERA")
	camera.hold(monster, SETTINGS.monster_hold + 0.01)
	assert_true(camera.broken)
	var smash := _of(NoiseEvent.Type.CAMERA)
	assert_eq(smash.size(), 1)
	assert_eq(smash[0].noise_range, SETTINGS.smash_range)
	network._physics_process(0.016)
	assert_null(player.watching, "back to its eyes")
	assert_false(camera.wanted_by(monster), "dead for the game")
	network.watch(player, camera)
	assert_null(player.watching, "a dead camera shows nothing")


func test_the_cite_has_its_network() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var network := CityNetwork.of(map)
	assert_not_null(network)
	assert_eq(network.terminals.size(), 8, "the keypad of the transformer and the hospital too")
	assert_eq(network.cameras.size(), 9)
	var guards := network.terminals.filter(
		func(terminal: Terminal) -> bool: return terminal.kind == Terminal.Kind.GUARD
	)
	assert_eq(guards.size(), 1)
	var prison := Prison.of(map)
	assert_gt(guards[0].global_position.distance_to(prison.cages[0].global_position), 80.0)
	for camera in network.cameras:
		assert_ne(tr(camera.label_key), camera.label_key, "named")
	# The cellar camera sees the corridor in front of the cages.
	var cellars := network.cameras[0]
	assert_true(cellars.sees(CELLAR_SPOT + Vector3.UP * 1.6))
	assert_false(cellars.sees(CELLAR_SPOT + Vector3(0, 1.6, 6)), "a wall between")
	# The playable monster finds a terminal in front of it.
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	avatar.local_controls = false
	map.add_child(avatar)
	var terminal := network.terminals[0]
	avatar.global_position = terminal.seat_point()
	avatar.commands.yaw = terminal.global_rotation.y  # Played as from the network.
	await wait_physics_frames(2)
	avatar.global_position = terminal.seat_point()
	assert_eq(avatar.get_interactable(), terminal)


func test_in_a_cage_interact_goes_through_the_cameras() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var network := CityNetwork.of(map)
	var hunted: Player = net.avatars[11]
	map._online_catch(hunted)
	map._jail(hunted)
	hunted.commands.push(PlayerCommands.Action.INTERACT)
	hunted.apply_actions()
	assert_eq(hunted.watching, network.cameras[0])
	assert_eq(net.snapshot_for(11)["you"][11], 0)
	network.cameras[1].broken = true
	hunted.commands.push(PlayerCommands.Action.INTERACT)
	hunted.apply_actions()
	assert_eq(hunted.watching, network.cameras[2], "a dead one is skipped")
	for i in network.cameras.size() - 2:  # Cameras 3 to 7, then its eyes.
		hunted.commands.push(PlayerCommands.Action.INTERACT)
		hunted.apply_actions()
	assert_null(hunted.watching, "after the last, its own eyes")
	hunted.commands.push(PlayerCommands.Action.INTERACT)
	hunted.apply_actions()
	hunted.capture.set_free()
	network._physics_process(0.016)
	assert_null(hunted.watching, "freed: its own eyes")


func test_online_a_hunted_sees_what_its_camera_sees() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var network := CityNetwork.of(map)
	var watcher: Player = net.avatars[11]
	var seen: Player = net.avatars[12]
	var terminal := network.terminals[0]
	watcher.global_position = terminal.seat_point()
	terminal.sit(watcher)
	seen.global_position = CELLAR_SPOT
	await wait_physics_frames(2)
	seen.global_position = CELLAR_SPOT
	var seats := func() -> Array:
		return net.snapshot_for(11)["others"].map(func(entry: Array) -> int: return entry[0])
	assert_false(2 in seats.call(), "far away, behind walls")
	var you: Array = net.snapshot_for(11)["you"]
	assert_eq(you[10], 0, "its terminal")
	assert_eq(you[11], -1)
	watcher.commands.push_pick(0)  # The cellar camera.
	watcher.apply_actions()
	assert_true(2 in seats.call(), "through the camera")
	assert_eq(net.snapshot_for(11)["you"][11], 0)
	assert_false(1 in net.snapshot_for(12)["others"].map(func(e: Array) -> int: return e[0]))
	# The world state says the LED is lit and the terminal used, not by whom.
	var state: Array = net.world.state()
	assert_eq(state.size(), 13)  # The wind came last (S-012).
	assert_eq(state[7][0][0], [false, true, 0])
	assert_eq(state[7][1][0], [true, false])


func test_a_client_shows_the_room_s_network() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var network := CityNetwork.of(map)
	var watcher: Player = net.avatars[11]
	network.terminals[2].sit(watcher)
	network.watch(watcher, network.cameras[3])
	network.cameras[5].smash()
	var state: Array = net.world.state()
	var snapshot := net.snapshot_for(11)
	NetSession.mode = NetSession.Mode.SOLO  # The client's map, shown alone.
	var client: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(client)
	var mirror: CityNetwork = client.get_node("Network")
	mirror.mirror = true
	mirror.apply(state[7])
	assert_true(mirror.terminals[2].is_in_use())
	assert_true(mirror.cameras[3].is_led_lit())
	assert_true(mirror.cameras[5].broken)
	assert_false(mirror.cameras[0].is_led_lit())
	var own: Player = client.get_node("Player")
	var client_net := NetGame.new()
	client_net.world = NetWorld.new(client)
	client_net.own = own
	add_child_autofree(client_net)
	client_net._apply_network_state(own, snapshot["you"][10], snapshot["you"][11])
	assert_eq(own.terminal, mirror.terminals[2])
	assert_eq(own.watching, mirror.cameras[3])
	assert_false(mirror.terminals[2].user == own, "the room's terminal, only shown")
	client_net._apply_network_state(own, -1, -1)
	assert_null(own.terminal)
	assert_null(own.watching)


func test_the_menu_lists_the_cameras() -> void:
	_ground()
	var network := _small_network()
	var terminal := network.terminals[0]
	var player := _player(terminal.seat_point())
	var menu := TerminalMenu.new()
	menu.player = player
	add_child_autofree(menu)
	menu._process(0.0)
	assert_eq(menu.get_lines().size(), 0, "not seated: nothing")
	terminal.sit(player)
	menu._process(0.0)
	var line := "1  " + tr("HUD_TERMINAL_CAMERA") % tr("NET_CAM_TOWER_HALL")
	assert_eq(menu.get_lines(), PackedStringArray([line]))
	menu.pick(0)
	assert_eq(PlayerCommands.picked(player.commands.peek_actions()[0]), 0)
	player.apply_actions()
	menu._process(0.0)
	assert_eq(menu.get_lines(), PackedStringArray(["> " + line]))
	var feed := SecurityFeed.new()
	feed.player = player
	add_child_autofree(feed)
	feed._process(0.0)
	assert_eq(feed.get_caption(), tr("HUD_CAMERA_CAPTION") % [1, tr("NET_CAM_TOWER_HALL")])


func test_picks_cross_the_network_and_nothing_else() -> void:
	var commands := PlayerCommands.new()
	commands.push_pick(3)
	commands.push_pick(99)  # Not a line any menu has: not queued.
	var bytes := commands.to_bytes()
	assert_eq(bytes.size(), PlayerCommands.HEADER_SIZE + 1)
	var read := PlayerCommands.from_bytes(bytes)
	assert_eq(PlayerCommands.picked(read.take_actions()[0]), 3)
	bytes[PlayerCommands.HEADER_SIZE] = PlayerCommands.PICK_BASE + PlayerCommands.PICK_COUNT
	assert_true(PlayerCommands.from_bytes(bytes).take_actions().is_empty())
	bytes[PlayerCommands.HEADER_SIZE] = PlayerCommands.PICK_BASE - 1
	assert_true(PlayerCommands.from_bytes(bytes).take_actions().is_empty())
	assert_eq(PlayerCommands.picked(PlayerCommands.Action.INTERACT), -1)
