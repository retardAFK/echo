extends GutTest
## The prison of an online game (S-018, part A, T-262): a captured hunted
## waits in a cage, freed at the grille by a teammate; its stay runs out
## unless the monster is near; out the third time. Solo is unchanged.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const SETTINGS := preload("res://game/data/prison_settings.tres")

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


func _room(seats: Array[int]) -> GameMap:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = seats
	GameSession.online_lobby = lobby
	GameSession.game_seed = 5
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	return map


func test_rules_of_a_stay() -> void:
	assert_eq(PrisonRules.stay_for(1, SETTINGS), 120.0)
	assert_eq(PrisonRules.stay_for(2, SETTINGS), 60.0)
	assert_false(PrisonRules.is_out(2, SETTINGS))
	assert_true(PrisonRules.is_out(3, SETTINGS))
	assert_eq(PrisonRules.tick(50.0, 1.0, 30.0, SETTINGS), 49.0, "monster far: it runs")
	assert_eq(PrisonRules.tick(50.0, 1.0, 14.0, SETTINGS), 50.0, "monster within 15 m: stopped")
	assert_eq(PrisonRules.tick(50.0, 1.0, -1.0, SETTINGS), 49.0, "no monster: it runs")
	assert_eq(PrisonRules.tick(0.5, 1.0, 30.0, SETTINGS), 0.0)
	assert_true(PrisonRules.lamp_lit(30.0, 0.5, SETTINGS), "steady")
	var period := SETTINGS.blink_period
	assert_true(PrisonRules.lamp_lit(10.0, period * 0.25, SETTINGS), "blinking: on")
	assert_false(PrisonRules.lamp_lit(10.0, period * 0.75, SETTINGS), "blinking: off")


func test_with_a_prison_caught_twice_it_waits_out_the_third_time() -> void:
	var prison := Prison.new()
	prison.settings = SETTINGS
	add_child_autofree(prison)
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	player.capture = CaptureState.new()
	player.capture.prison = prison
	player.add_child(player.capture)
	assert_eq(player.capture.progress.duration, SETTINGS.free_time)
	assert_eq(player.capture.catch(), CaptureState.State.CAPTURED)
	await wait_physics_frames(3)
	assert_eq(_of(NoiseEvent.Type.CALL).size(), 0, "silent in prison (Q7)")
	assert_false(player.capture.can_interact(player.global_position), "no cage yet")
	player.capture.set_free()
	assert_eq(player.capture.catch(), CaptureState.State.CAPTURED, "second stay")
	player.capture.set_free()
	assert_eq(player.capture.catch(), CaptureState.State.OUT, "third catch")


func test_the_cite_has_three_cages_in_the_cellars() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var prison := Prison.of(map)
	assert_not_null(prison)
	assert_eq(prison.cages.size(), 3)
	for cage in prison.cages:
		assert_lt(cage.global_position.y, -2.0, "underground")
		assert_false(cage.is_open)
		assert_false(cage.is_lamp_lit())
		assert_false(cage.can_interact(cage.outside_point()), "empty: nothing to open")


func test_caught_it_goes_to_a_cage_and_a_teammate_frees_it_there() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var hunted: Player = net.avatars[11]
	var teammate: Player = net.avatars[12]
	var caught_at := hunted.global_position
	map.game_loop._on_fuse_taken(hunted)
	map._online_catch(hunted)
	assert_null(hunted.capture.get_cage(), "black screen first, where it was caught")
	await wait_seconds(SETTINGS.jail_delay + 0.2)
	var cage := hunted.capture.get_cage()
	assert_not_null(cage, "then in a cage")
	assert_almost_eq(hunted.global_position.distance_to(cage.inside_point()), 0.0, 0.5)
	assert_gt(caught_at.distance_to(hunted.global_position), 5.0)
	assert_almost_eq(map.game_loop.drops[0].global_position.distance_to(caught_at), 0.0, 0.5)
	assert_eq(cage.occupant_seat, 1)
	assert_almost_eq(cage.time_left, SETTINGS.first_stay, 0.5)
	assert_true(cage.is_lamp_lit())
	# Its teammate at the grille: 4 s of holding, the gate creaks open.
	teammate.global_position = cage.outside_point()
	assert_true(cage.can_interact(teammate.global_position))
	assert_true(cage.wanted_by(teammate))
	assert_false(cage.wanted_by(hunted))
	assert_eq(cage.get_prompt(), "HUD_INTERACT_FREE_CAGE")
	cage.hold(teammate, SETTINGS.free_time - 0.1)
	assert_true(hunted.held, "not yet")
	cage.hold(teammate, 0.2)
	assert_false(hunted.held)
	assert_true(cage.is_open)
	assert_true(cage.is_free())
	var creaks := _of(NoiseEvent.Type.CAGE)
	assert_eq(creaks.size(), 2, "at the start and at the end")
	assert_eq(creaks[0].noise_range, SETTINGS.free_range)
	assert_eq(creaks[0].source, teammate)


func test_a_stay_runs_out_unless_the_monster_is_near() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var monster: Monster = map.get_node("Monster")
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	var hunted: Player = net.avatars[11]
	var prison := Prison.of(map)
	map._online_catch(hunted)
	map._jail(hunted)
	var cage := hunted.capture.get_cage()
	monster.global_position = cage.outside_point() + Vector3(5, 0, 0)
	prison._physics_process(10.0)
	assert_eq(cage.time_left, SETTINGS.first_stay, "the monster guards: the clock stops")
	monster.global_position = Vector3(0, 0, 0)
	prison._physics_process(10.0)
	assert_eq(cage.time_left, SETTINGS.first_stay - 10.0)
	prison._physics_process(SETTINGS.first_stay)
	assert_eq(hunted.capture.state, CaptureState.State.OUT, "too late: out")
	assert_true(cage.is_free())
	assert_false(cage.is_open, "an empty cage stays shut")
	assert_eq(net.snapshot_for(11)["watch"], 2, "it watches its teammate")


func test_second_stay_is_shorter() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var hunted: Player = net.avatars[11]
	map._online_catch(hunted)
	map._jail(hunted)
	hunted.capture.set_free()
	map._online_catch(hunted)
	map._jail(hunted)
	assert_eq(hunted.capture.get_cage().time_left, SETTINGS.second_stay)


func test_the_monster_wins_when_all_are_in_prison() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	for one: Node3D in [net.avatars[11], net.avatars[12], net.ai_hunted[3]]:
		map._online_catch(one)
		map._jail(one)
	assert_true(map.game_loop.is_over)
	assert_false(map.game_loop.hunted_won)
	var prison := Prison.of(map)
	assert_true(prison.cages.all(func(cage: Cage) -> bool: return not cage.is_free()))


func test_the_guard_frees_everyone_with_the_bell() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var prison := Prison.of(map)
	var a: Player = net.avatars[11]
	var b: Player = net.avatars[12]
	for one: Player in [a, b]:
		map._online_catch(one)
		map._jail(one)
	var freed := prison.open_all()
	assert_eq(freed.size(), 2)
	var bells := _of(NoiseEvent.Type.BELL)
	assert_eq(bells.size(), 1)
	assert_eq(bells[0].noise_range, SETTINGS.bell_range)


func test_a_client_sees_the_cages_and_its_time_left() -> void:
	var map := _room([0, 11, 12, 0])
	var net: NetGame = map.get_node("NetGame")
	var hunted: Player = net.avatars[11]
	map._online_catch(hunted)
	map._jail(hunted)
	var state := net.world.state()
	assert_eq(state.size(), 13)  # The wind came last (S-012).
	assert_eq(state[6][0], [1, false, ceili(SETTINGS.first_stay)])
	var client: GameMap = MAP_SCENE.instantiate()
	NetSession.mode = NetSession.Mode.SOLO  # Shown alone: only its prison is used.
	add_child_autofree(client)
	var prison := Prison.of(client)
	prison.mirror = true
	prison.apply(state[6])
	assert_eq(prison.cages[0].occupant_seat, 1)
	assert_eq(prison.cage_of_seat(1), prison.cages[0])
	var hud := PrisonHud.new()
	hud.prison = prison
	hud.seat = 1
	add_child_autofree(hud)
	hud._process(0.0)
	assert_eq(hud.get_text(), PrisonHud.text_for(SETTINGS.first_stay))
	assert_eq(PrisonHud.text_for(102.0), tr("HUD_PRISON_TIME") % [1, 42])
	hud.seat = 2
	hud._process(0.0)
	assert_eq(hud.get_text(), "", "not in prison: nothing")
	prison.apply([[-1, true, 0], [-1, false, 0], [-1, false, 0]])
	await wait_seconds(0.5)
	assert_true(prison.cages[0].is_open, "freed: the gate swings")


func test_solo_has_no_prison_rule() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	assert_null(map._prison)
	assert_null(map.get_node("Player").get("capture"))
