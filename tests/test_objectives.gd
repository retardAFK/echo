extends GutTest
## The objectives drawn at random (S-018, Q13, T-266): at least one fuse,
## and maybe a code typed on the transformer's keypad, a download brought to
## the transformer on a floppy disk, two relay switches thrown together. The
## exit opens once all are done.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
const ALL := [
	LoopRules.Objective.FUSE,
	LoopRules.Objective.CODE,
	LoopRules.Objective.DOWNLOAD,
	LoopRules.Objective.RELAY,
]

var _heard := []
## The objectives imposed before each test (the pre-run hook's).
var _before := ""


func before_each() -> void:
	_before = OS.get_environment("ECHO_OBJECTIVES")
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)
	OS.set_environment("ECHO_OBJECTIVES", _before)
	GameSession.game_seed = 0


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func _heard_type(type: NoiseEvent.Type) -> Array:
	return _heard.filter(func(event: NoiseEvent) -> bool: return event.type == type)


## The cité in solo, the player hunted, with these objectives imposed.
func _map(objectives: String) -> GameMap:
	OS.set_environment("ECHO_OBJECTIVES", objectives)
	GameSession.game_seed = 7
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	return map


func test_a_draw_has_a_fuse_and_never_twice_another_kind() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 200:
		rng.seed = i + 1
		var drawn := LoopRules.draw_objectives(ALL, 3, rng)
		assert_eq(drawn.size(), 3)
		assert_true(LoopRules.Objective.FUSE in drawn, "a fuse in every game")
		for kind in [
			LoopRules.Objective.CODE, LoopRules.Objective.DOWNLOAD, LoopRules.Objective.RELAY
		]:
			assert_lte(drawn.count(kind), 1, "never twice the same")
	var only_fuses := LoopRules.draw_objectives([], 3, rng)
	assert_eq(only_fuses, [0, 0, 0] as Array[int], "fuses only when nothing else is offered")


func test_the_rules_wait_for_every_objective() -> void:
	var rules := LoopRules.new(3)
	rules.set_objectives([LoopRules.Objective.FUSE, LoopRules.Objective.CODE])
	assert_eq(rules.fuse_count, 1)
	rules.take_fuse()
	rules.place_fuse()
	assert_false(rules.is_repaired(), "the code is still to type")
	assert_false(rules.complete(LoopRules.Objective.RELAY), "not an objective of this game")
	assert_true(rules.complete(LoopRules.Objective.CODE))
	assert_true(rules.is_repaired())


func test_relay_pairs_are_two_buildings_close_enough() -> void:
	var switches := [["a", Vector3(0, 0, 0)], ["a", Vector3(5, 0, 0)], ["b", Vector3(200, 0, 0)]]
	assert_eq(LoopRules.draw_relays(switches, 70.0, null), [], "too far, or the same building")
	switches.append(["c", Vector3(0, 0, 60)])
	var pair := LoopRules.draw_relays(switches, 70.0, RandomNumberGenerator.new())
	assert_true(pair == [0, 3] or pair == [1, 3], "a and c: %s" % [pair])


func test_the_cite_offers_every_kind_and_solo_draws_them() -> void:
	OS.set_environment("ECHO_OBJECTIVES", "")
	GameSession.game_seed = 3
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var offered := Quests.offered_by(map, LOOP_SETTINGS)
	assert_eq(offered.size(), 3, "code, download, relay")
	var rules := map.game_loop.rules
	assert_eq(rules.objectives.size(), LOOP_SETTINGS.objectives_per_game)
	var fused := map.get_fuse_boxes().filter(func(box: FuseBox) -> bool: return box.has_fuse)
	assert_eq(fused.size(), rules.fuse_count, "as many fuses as FUSE objectives")
	var spots := get_tree().get_nodes_in_group(CodeSpot.GROUP)
	assert_eq(spots.size(), 7, "a post-it behind each terminal but the keypad")
	var written := spots.filter(func(spot: CodeSpot) -> bool: return spot.get_code() != "")
	var has_code := LoopRules.Objective.CODE in rules.objectives
	assert_eq(written.size(), 1 if has_code else 0)


func test_the_code_typed_on_the_keypad() -> void:
	var map := _map("fuse,code")
	var quests := map.game_loop.quests
	assert_eq(quests.code.length(), 4)
	assert_eq(quests.code_spot.get_code(), quests.code, "written on one post-it")
	var network: CityNetwork = map.get_node("Network")
	var is_keypad := func(terminal: Terminal) -> bool: return terminal.kind == Terminal.Kind.CODE
	var keypad: Terminal = network.terminals.filter(is_keypad)[0]
	var entries := network.entries_for(keypad)
	assert_eq(entries.size(), 10, "keys 1 to 9 and 0")
	var player: Player = map.get_node("Player")
	player.global_position = keypad.seat_point()
	keypad.sit(player)
	var wrong := "0000" if quests.code != "0000" else "1111"
	_type(player, wrong)
	assert_eq(_heard_type(NoiseEvent.Type.BEEP).size(), 1, "a wrong code beeps")
	assert_false(map.game_loop.rules.is_done(LoopRules.Objective.CODE))
	_type(player, quests.code)
	assert_true(map.game_loop.rules.is_done(LoopRules.Objective.CODE))
	assert_true(network.entries_for(keypad).is_empty(), "nothing more to type")


func _type(player: Player, code: String) -> void:
	for character in code:
		var digit := int(character)
		player.commands.push_pick(9 if digit == 0 else digit - 1)
		player.apply_actions()


func test_the_download_makes_a_floppy_disk_for_the_transformer() -> void:
	var map := _map("download")
	var loop := map.game_loop
	var quests := loop.quests
	var network: CityNetwork = map.get_node("Network")
	var terminal := quests.download_terminal
	assert_not_null(terminal)
	var entries := network.entries_for(terminal)
	assert_eq(entries[-1][0], CityNetwork.Entry.DOWNLOAD)
	var player: Player = map.get_node("Player")
	player.global_position = terminal.seat_point()
	terminal.sit(player)
	player.commands.push_pick(entries.size() - 1)
	player.apply_actions()
	assert_eq(quests.download_ratio(), 0.0)
	terminal.leave()
	quests._physics_process(LOOP_SETTINGS.download_time * 0.5)
	assert_almost_eq(quests.download_ratio(), 0.5, 0.01, "runs with nobody there")
	assert_gt(_heard_type(NoiseEvent.Type.DISK).size(), 0, "the disk scratches")
	terminal.switch_off()
	quests._physics_process(0.1)
	assert_eq(quests.download_ratio(), -1.0, "switched off: start over")
	terminal.off_left = 0.0
	quests.start_download(terminal)
	quests._physics_process(LOOP_SETTINGS.download_time + 0.1)
	assert_not_null(quests.disk, "a floppy disk by the terminal")
	assert_lt(quests.disk.global_position.distance_to(terminal.global_position), 1.5)
	quests.disk.hold(player, LOOP_SETTINGS.pickup_time + 0.1)
	assert_true(quests.carries_disk(player))
	loop.drop_fuses(player)
	assert_not_null(quests.disk, "dropped where its carrier was caught")
	quests.disk.hold(player, LOOP_SETTINGS.pickup_time + 0.1)
	var transformer := loop.transformer
	assert_eq(transformer.get_prompt(), "HUD_INTERACT_TRANSFORMER_DISK")
	assert_true(transformer.wanted_by(player))
	transformer.hold(player, LOOP_SETTINGS.repair_time + 0.1)
	assert_true(loop.rules.is_done(LoopRules.Objective.DOWNLOAD))
	assert_true(loop.is_exit_open(), "the only objective")


func test_both_relay_switches_within_the_window() -> void:
	var map := _map("fuse,relay")
	var loop := map.game_loop
	var quests := loop.quests
	assert_eq(quests.relays.size(), 2)
	assert_ne(quests.relays[0].building_name, quests.relays[1].building_name)
	var player: Player = map.get_node("Player")
	var first := quests.relays[0]
	first.thrown.emit(player)
	assert_true(first.is_down)
	assert_eq(_heard_type(NoiseEvent.Type.SWITCH).size(), 1)
	quests._physics_process(LOOP_SETTINGS.relay_window + 0.1)
	assert_false(first.is_down, "too late: it clicks back")
	first.thrown.emit(player)
	quests._physics_process(LOOP_SETTINGS.relay_window * 0.5)
	quests.relays[1].thrown.emit(player)
	assert_true(loop.rules.is_done(LoopRules.Objective.RELAY))
	assert_false(loop.is_exit_open(), "the fuse is still missing")
	assert_eq(loop.transformer.get_node("WaitLabel").text, Text.count("HUD_TRANSFORMER_WAITS", 1))


func test_relay_switches_hang_on_a_wall() -> void:
	var map := _map("fuse")
	await wait_physics_frames(2)
	var space := map.get_world_3d().direct_space_state
	var switches := get_tree().get_nodes_in_group(RelaySwitch.GROUP)
	assert_eq(switches.size(), 5, "and the hospital's (S-014)")
	for switch: RelaySwitch in switches:
		assert_false(switch.armed, "not drawn this game")
		var at := switch.global_position + Vector3.UP * 1.3 + switch.global_basis.z * 0.3
		var behind := PhysicsRayQueryParameters3D.create(at, at - switch.global_basis.z * 0.6, 2)
		assert_false(space.intersect_ray(behind).is_empty(), "wall behind %s" % switch.name)


func test_a_client_shows_the_room_s_objectives() -> void:
	var room := _map("fuse,code,download,relay")
	var room_world := NetWorld.new(room)
	room_world.game_loop = room.game_loop
	var client := _map("fuse")
	var client_world := NetWorld.new(client)
	client_world.game_loop = client.game_loop
	client.game_loop.quests.free()
	client.game_loop.mirror = true
	client.game_loop._add_quests()
	var mirror := client.game_loop.quests
	var quests := room.game_loop.quests
	# The room's game: the code typed halfway, the download done, a relay down.
	var network: CityNetwork = room.get_node("Network")
	var keypad: Terminal = network.terminals[-1]
	quests.type_digit(keypad, int(quests.code[0]))
	quests.start_download(quests.download_terminal)
	quests._physics_process(LOOP_SETTINGS.download_time + 0.1)
	quests.relays[0].thrown.emit(room.get_node("Player"))
	client_world.apply(room_world.state())
	var rules := client.game_loop.rules
	assert_eq(Array(rules.objectives), Array(room.game_loop.rules.objectives))
	assert_eq(rules.fuse_count, 1)
	assert_eq(mirror.code_spot.get_parent().get_child_count(), 7)  # With the hospital (S-014).
	assert_eq(mirror.code, quests.code)
	assert_eq(mirror.code_spot.get_index(), quests.code_spot.get_index(), "the same post-it")
	assert_eq(mirror.typed_on(client.get_node("Network").terminals[-1]), quests.code[0])
	assert_eq(mirror.download_terminal.name, quests.download_terminal.name)
	assert_not_null(mirror.disk, "the floppy disk lies by the terminal")
	assert_true(mirror.disk.global_position.is_equal_approx(quests.disk.global_position))
	assert_eq(mirror.relays.size(), 2)
	assert_true(mirror.relays[0].is_down)
	assert_false(mirror.relays[1].is_down)
	assert_true(mirror.relays[1].armed)
	# Taken, then the relay and the code done: the disk goes, the HUD counts.
	quests.disk.hold(room.get_node("Player"), LOOP_SETTINGS.pickup_time + 0.1)
	quests.relays[1].thrown.emit(room.get_node("Player"))
	for character in quests.code.substr(1):
		quests.type_digit(keypad, int(character))
	watch_signals(client.game_loop)
	client_world.apply(room_world.state())
	assert_null(mirror.disk)
	assert_true(mirror.carries_disk(client.get_node("Player")))
	assert_true(rules.is_done(LoopRules.Objective.RELAY))
	assert_true(rules.is_done(LoopRules.Objective.CODE))
	assert_false(mirror.wants_code())
	assert_signal_emitted(client.game_loop, "fuses_changed")
	assert_false(client.game_loop.is_exit_open(), "the fuse and the disk are missing")


func test_the_keypad_is_a_box_on_the_transformer_wall() -> void:
	# S-020, T-316 (N2): no PC on a desk outdoors.
	var map := _map("fuse,code")
	var network: CityNetwork = map.get_node("Network")
	var is_keypad := func(terminal: Terminal) -> bool: return terminal.kind == Terminal.Kind.CODE
	var keypad: Terminal = network.terminals.filter(is_keypad)[0]
	assert_false(keypad.has_node("Desk"), "no desk")
	assert_true(keypad.has_node("Case"), "a wall box")
	var from := keypad.to_global(Vector3(0.0, 1.25, 0.5))
	var to := keypad.to_global(Vector3(0.0, 1.25, -0.3))
	var query := PhysicsRayQueryParameters3D.create(from, to, NoiseBus.WALLS_COLLISION_MASK)
	var hit := map.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "a wall right behind it")
	if not hit.is_empty():
		assert_lt(to.distance_to(hit.position), 0.35, "flat on the wall")
	var seat := keypad.seat_point()
	assert_true(keypad.can_interact(seat + Vector3.UP * 0.9), "reached from its seat")
