extends GutTest
## Second chances in the Versus (spec S-025, T-414): the adrenaline syringe
## (SyringeShot) gets a downed hunted up alone; a return terminal
## (ReturnTerminals) brings back a teammate who is out, once.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func _open() -> VersusMode:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


## A second hunted kit on a plain body (an AI prey's way), driven by hand.
func _teammate(versus: VersusMode, at: Vector3) -> HunterKit:
	var body := CharacterBody3D.new()
	versus.add_child(body)
	body.global_position = at
	var kit := HunterKit.new(versus)
	body.add_child(kit)
	kit.set_physics_process(false)
	versus.hunters.append(kit)
	versus.rules.hunted.append(kit.vitals)
	return kit


func _item(versus: VersusMode, id: StringName) -> VersusItem:
	for item in versus.settings.items:
		if item.id == id:
			return item
	return null


func _knock_out(kit: HunterKit) -> void:
	kit.vitals.revives_left = 0
	kit.vitals.hurt(99)


func test_the_syringe_is_a_tool_of_the_chests() -> void:
	var versus := await _open()
	var syringe := _item(versus, SyringeShot.ID)
	assert_not_null(syringe, "listed in items")
	assert_eq(syringe.slot, VersusItem.Slot.TOOL)
	assert_gt(syringe.weight, 0.0)
	assert_ne(Text.t(syringe.name_key), syringe.name_key, "it has a name")


func test_a_downed_player_gets_up_alone_with_its_syringe() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	player.equip(_item(versus, SyringeShot.ID))
	versus.rules.hunted.append(HuntedVitals.new(versus.settings))  # Someone stands: it goes on.
	var revives := player.vitals.revives_left
	player.take_blow(versus.settings.hunted_health)
	assert_true(player.vitals.is_down())
	assert_eq(KitPrompts.of_hunter(player)[0], "VERSUS_DOWN_SYRINGE_1")
	Input.action_press("gadget_1")
	await wait_physics_frames(2)
	Input.action_release("gadget_1")
	assert_true(player.syringe.is_going(), "the injection starts")
	assert_eq(KitPrompts.of_hunter(player)[0], "VERSUS_SYRINGE_GOING")
	await wait_seconds(versus.settings.syringe_time + 0.2)
	assert_true(player.vitals.is_standing(), "up alone")
	assert_eq(player.vitals.revives_left, revives - 1, "one revive used")
	assert_eq(SyringeShot.slot_of(player), -1, "the syringe is spent")


func test_an_ai_prey_uses_its_syringe_at_once_and_the_standing_do_not() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var mate := _teammate(versus, player.body.global_position + Vector3(4, 0, 0))
	mate.equip(_item(versus, SyringeShot.ID))
	mate.syringe.update(mate, 1.0)
	assert_false(mate.syringe.is_going(), "not while standing")
	assert_false(mate.use_tool(0), "no use standing: kept")
	mate.take_blow(versus.settings.hunted_health)
	mate.syringe.update(mate, 0.01)
	assert_true(mate.syringe.is_going())
	mate.syringe.update(mate, versus.settings.syringe_time)
	assert_true(mate.vitals.is_standing())


func test_bring_back_stands_an_out_hunted_up() -> void:
	var settings: VersusSettings = SETTINGS
	var vitals := HuntedVitals.new(settings)
	assert_false(vitals.bring_back(), "not out")
	vitals.revives_left = 0
	vitals.hurt(99)
	assert_true(vitals.is_out())
	watch_signals(vitals)
	assert_true(vitals.bring_back())
	assert_signal_emitted(vitals, "back")
	assert_true(vitals.is_standing())
	assert_eq(vitals.health, settings.terminal_health)
	assert_eq(vitals.revives_left, settings.terminal_revives)


func test_a_terminal_brings_an_out_teammate_back_once() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var at := player.body.global_position
	var terminal := versus.terminals.add(at + Vector3(0, 0, -1.2))
	var mate := _teammate(versus, at + Vector3(10, 0, 0))
	assert_false(versus.terminals.hold(player, true, 1.0), "nobody out: nothing to do")
	_knock_out(mate)
	assert_true(mate.vitals.is_out())
	await wait_physics_frames(2)
	assert_true(terminal.lit, "lit while a teammate is out")
	assert_eq(KitPrompts.of_hunter(player)[0], "VERSUS_TERMINAL")
	assert_eq(KitPrompts.of_hunter(mate)[0], "VERSUS_OUT_TERMINAL")
	watch_signals(NoiseBus)
	player._hold_interact(true, versus.settings.terminal_time * 0.5)
	assert_signal_emitted(NoiseBus, "noise_emitted", "the boss hears it")
	assert_almost_eq(versus.terminals.ratio_of(player), 0.5, 0.01)
	assert_true(mate.vitals.is_out())
	player._hold_interact(true, versus.settings.terminal_time * 0.5 + 0.01)
	assert_true(mate.vitals.is_standing(), "back")
	assert_eq(mate.vitals.health, versus.settings.terminal_health)
	assert_almost_eq(mate.body.global_position.distance_to(terminal.back_point()), 0.0, 0.01)
	assert_true(terminal.used and not terminal.lit, "it goes dark")
	_knock_out(mate)
	assert_false(versus.terminals.hold(player, true, 99.0), "it works once")
	assert_true(mate.vitals.is_out())
	assert_eq(KitPrompts.of_hunter(mate)[0], "VERSUS_OUT", "no terminal left")


func test_letting_go_starts_over() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var at := player.body.global_position
	versus.terminals.add(at + Vector3(0, 0, -1.2))
	var mate := _teammate(versus, at + Vector3(10, 0, 0))
	_knock_out(mate)
	player._hold_interact(true, versus.settings.terminal_time * 0.8)
	player._hold_interact(false, 0.1)
	assert_eq(versus.terminals.ratio_of(player), -1.0)
	player._hold_interact(true, versus.settings.terminal_time * 0.8)
	assert_true(mate.vitals.is_out(), "the time starts over")


func test_a_client_copies_the_terminals() -> void:
	var versus := await _open()
	var terminal := versus.terminals.add(Vector3(0, 0, -5))
	versus.terminals.mirror([[false, true]])
	assert_true(terminal.lit)
	versus.terminals.mirror([[true, true]])
	assert_true(terminal.used and not terminal.lit, "used: dark")
	assert_eq(versus.terminals.values(), [[true, false]])


func test_the_arena_has_terminals_facing_its_centre() -> void:
	var settings: VersusSettings = SETTINGS
	var arena: VersusArena = settings.arenas[0]
	assert_eq(arena.terminal_spots.size(), 2)
	for i in arena.terminal_spots.size():
		var spot := arena.terminal_spots[i]
		assert_true(arena.contains(spot), "inside: %s" % spot)
		var facing := Basis(Vector3.UP, arena.terminal_yaw(i)) * Vector3.BACK
		var centre := arena.bounds.get_center()
		var toward := Vector3(centre.x - spot.x, 0, centre.y - spot.z).normalized()
		assert_gt(facing.dot(toward), 0.99, "its screen faces the centre")
