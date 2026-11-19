extends GutTest
## The guard's terminal (S-018, Q4, T-264): in the gallery, far from the
## prison; seated there for guard_time after picking "open the cages", every
## occupied cage opens with the bell. Getting up or the monster switching it
## off starts over.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const PRISON_SETTINGS := preload("res://game/data/prison_settings.tres")

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


func _bells() -> Array:
	return _heard.filter(func(event: NoiseEvent) -> bool: return event.type == NoiseEvent.Type.BELL)


func _room() -> GameMap:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = [0, 11, 12, 0] as Array[int]
	GameSession.online_lobby = lobby
	GameSession.game_seed = 5
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	return map


func _guard(network: CityNetwork) -> Terminal:
	for terminal in network.terminals:
		if terminal.kind == Terminal.Kind.GUARD:
			return terminal
	return null


## Seats a hunted at the guard's terminal and picks "open the cages".
func _start(network: CityNetwork, guard: Terminal, who: Player) -> void:
	who.global_position = guard.seat_point()
	guard.sit(who)
	var entries := network.entries_for(guard)
	assert_eq(entries[-1][0], CityNetwork.Entry.OPEN_CAGES)
	who.commands.push_pick(entries.size() - 1)
	who.apply_actions()


func test_the_guard_terminal_opens_every_cage_with_the_bell() -> void:
	var map := _room()
	var net: NetGame = map.get_node("NetGame")
	var network := CityNetwork.of(map)
	var prison := Prison.of(map)
	var guard := _guard(network)
	var others := network.terminals.filter(func(t: Terminal) -> bool: return t != guard)
	assert_false(
		network.entries_for(others[0]).any(
			func(entry: Array) -> bool: return entry[0] == CityNetwork.Entry.OPEN_CAGES
		),
		"only the guard's terminal"
	)
	var jailed: Array[Node3D] = [net.avatars[11], net.ai_hunted[3]]
	for one in jailed:
		map.room.catch_hunted(one)
		map.room.jail(one)
	var helper: Player = net.avatars[12]
	_start(network, guard, helper)
	network._physics_process(PRISON_SETTINGS.guard_time / 2.0)
	assert_almost_eq(guard.progress, 0.5, 0.01)
	assert_eq(network.state()[0][network.terminals.find(guard)][2], 50)
	assert_eq(_bells().size(), 0)
	network._physics_process(PRISON_SETTINGS.guard_time / 2.0 + 0.1)
	assert_eq(guard.progress, 0.0)
	var bells := _bells()
	assert_eq(bells.size(), 1)
	assert_eq(bells[0].noise_range, PRISON_SETTINGS.bell_range)
	assert_lt(bells[0].position.distance_to(prison.cages[1].global_position), 3.0, "at the prison")
	for one in jailed:
		assert_eq(one.get("capture").state, CaptureState.State.FREE)
		assert_false(one.get("held"))
	assert_true(prison.cages.all(func(cage: Cage) -> bool: return cage.is_free()))
	assert_eq(prison.cages.filter(func(cage: Cage) -> bool: return cage.is_open).size(), 2)
	assert_false(network.has_prisoners())


func test_getting_up_or_switched_off_starts_over() -> void:
	var map := _room()
	var net: NetGame = map.get_node("NetGame")
	var network := CityNetwork.of(map)
	var guard := _guard(network)
	var prisoner: Player = net.avatars[11]
	map.room.catch_hunted(prisoner)
	map.room.jail(prisoner)
	var helper: Player = net.avatars[12]
	_start(network, guard, helper)
	network._physics_process(PRISON_SETTINGS.guard_time - 1.0)
	guard.leave()
	network._physics_process(0.1)
	assert_eq(guard.progress, 0.0, "got up: over")
	_start(network, guard, helper)
	network._physics_process(0.1)
	assert_almost_eq(guard.progress, 0.1 / PRISON_SETTINGS.guard_time, 0.001, "from zero")
	network._physics_process(PRISON_SETTINGS.guard_time - 1.0)
	guard.switch_off()
	network._physics_process(2.0)
	assert_eq(guard.progress, 0.0, "switched off: over")
	assert_eq(prisoner.capture.state, CaptureState.State.CAPTURED)
	assert_eq(_bells().size(), 0)


func test_with_nobody_in_prison_nothing_starts() -> void:
	var map := _room()
	var net: NetGame = map.get_node("NetGame")
	var network := CityNetwork.of(map)
	var guard := _guard(network)
	var helper: Player = net.avatars[12]
	_start(network, guard, helper)
	network._physics_process(PRISON_SETTINGS.guard_time + 1.0)
	assert_eq(_bells().size(), 0)
	var menu := TerminalMenu.new()
	menu.player = helper
	add_child_autofree(menu)
	menu._process(0.0)
	var lines := menu.get_lines()
	assert_eq(
		lines[-1],
		"%d  %s  %s" % [lines.size(), tr("HUD_TERMINAL_OPEN_CAGES"), tr("HUD_TERMINAL_NOBODY")]
	)
