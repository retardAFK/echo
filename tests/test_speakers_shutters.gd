extends GutTest
## Loudspeakers and metal shutters of the cité's network (S-018, Q11,
## T-265): set off from a terminal, a loudspeaker blares 25 m for 5 s, once;
## a shutter goes down for 20 s, blocking bodies, sight and noise, and can go
## down again a minute after.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const SETTINGS := preload("res://game/data/network_settings.tres")
const ORIGIN := Vector3(110, 0, 110)

var _heard := []


func before_each() -> void:
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func _of(type: NoiseEvent.Type) -> Array:
	return _heard.filter(func(event: NoiseEvent) -> bool: return event.type == type)


func _map() -> GameMap:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	return map


## Plan (x, h, y) to world.
func _world(x: float, h: float, y: float) -> Vector3:
	return Vector3(x - ORIGIN.x, h, y - ORIGIN.z)


func _ray_hits(map: Node3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	return not map.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func test_a_loudspeaker_blares_once() -> void:
	var map := _map()
	var network := CityNetwork.of(map)
	assert_eq(network.speakers.size(), 4)
	var speaker := network.speakers[0]
	assert_true(speaker.trigger())
	assert_false(speaker.trigger(), "once per game")
	for i in 60:
		speaker._physics_process(0.1)
	var blares := _of(NoiseEvent.Type.SPEAKER)
	assert_eq(blares.size(), int(SETTINGS.speaker_time / SETTINGS.speaker_interval))
	assert_eq(blares[0].noise_range, SETTINGS.speaker_range)
	assert_eq(blares[0].source, speaker)
	assert_false(speaker.is_sounding())


func test_a_shutter_closes_its_way_for_a_while() -> void:
	var map := _map()
	var network := CityNetwork.of(map)
	assert_eq(network.shutters.size(), 2)
	await wait_physics_frames(2)
	var ways := [
		[_world(141.5, -1.6, 102.0), _world(138.5, -1.6, 102.0)],
		[_world(86.5, 1.2, 148.0), _world(84.4, 1.2, 148.0)],  # Short of its fire door.
	]
	for i in network.shutters.size():
		assert_false(_ray_hits(map, ways[i][0], ways[i][1]), "open way %d" % i)
	var shutter := network.shutters[1]
	assert_true(shutter.lower())
	await wait_physics_frames(2)
	assert_true(_ray_hits(map, ways[1][0], ways[1][1]), "down: it blocks")
	assert_false(_ray_hits(map, ways[0][0], ways[0][1]), "the other one stays up")
	var rattles := _of(NoiseEvent.Type.SHUTTER)
	assert_eq(rattles.size(), 1)
	assert_eq(rattles[0].noise_range, SETTINGS.shutter_range)
	var walking: Vector3 = ways[1][0] + Vector3(0, -0.8, 0)
	assert_eq(
		RemoteShutter.down_ahead(get_tree(), walking, Vector3(-1, 0, 0), 3.0), shutter, "seen ahead"
	)
	assert_null(RemoteShutter.down_ahead(get_tree(), walking, Vector3(1, 0, 0), 3.0), "behind")
	assert_false(shutter.lower(), "already down")
	shutter._physics_process(SETTINGS.shutter_time + 0.1)
	await wait_physics_frames(2)
	assert_false(shutter.is_down())
	assert_false(_ray_hits(map, ways[1][0], ways[1][1]), "up again")
	assert_eq(_of(NoiseEvent.Type.SHUTTER).size(), 2, "going up too")
	assert_null(RemoteShutter.down_ahead(get_tree(), walking, Vector3(-1, 0, 0), 3.0))
	assert_false(shutter.lower(), "recharging")
	shutter._physics_process(SETTINGS.shutter_recharge - SETTINGS.shutter_time)
	assert_true(shutter.lower(), "a minute after it went down")


func test_picked_at_a_terminal_and_shown_online() -> void:
	var map := _map()
	var network := CityNetwork.of(map)
	var terminal := network.terminals[0]
	var player: Player = map.get_node("Player")
	player.global_position = terminal.seat_point()
	terminal.sit(player)
	var entries := network.entries_for(terminal)
	var speaker_line := entries.find([CityNetwork.Entry.SPEAKER, 2, "NET_SPEAKER_ARCADE"])
	var shutter_line := entries.find([CityNetwork.Entry.SHUTTER, 0, "NET_SHUTTER_RAMP"])
	assert_gt(speaker_line, 0)
	assert_gt(shutter_line, 0)
	player.commands.push_pick(speaker_line)
	player.commands.push_pick(shutter_line)
	player.apply_actions()
	assert_true(network.speakers[2].used)
	assert_true(network.shutters[0].is_down())
	var menu := TerminalMenu.new()
	menu.player = player
	add_child_autofree(menu)
	menu._process(0.0)
	var lines := menu.get_lines()
	assert_string_ends_with(lines[speaker_line], tr("HUD_TERMINAL_USED"))
	assert_string_ends_with(lines[shutter_line], tr("HUD_TERMINAL_DOWN"))
	var state := network.state()
	assert_eq(state[2], [false, false, true, false])
	assert_eq(state[3][0], [true, ceili(SETTINGS.shutter_recharge)])
	var client: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(client)
	var mirror: CityNetwork = client.get_node("Network")
	mirror.mirror = true
	mirror.apply(state)
	assert_true(mirror.speakers[2].used)
	assert_true(mirror.shutters[0].is_down())
	mirror.shutters[0]._physics_process(SETTINGS.shutter_time + 1.0)
	assert_true(mirror.shutters[0].is_down(), "a client waits for the room")
	state[3][0] = [false, 30]
	mirror.apply(state)
	assert_false(mirror.shutters[0].is_down())
	assert_eq(mirror.shutters[0].recharge_left, 30.0)
