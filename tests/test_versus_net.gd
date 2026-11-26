extends GutTest
## The Versus online (spec S-024, T-381): what the room sends of a kit and
## how a client copies it, the chests copied, the prompts as data, the mode
## events of the network.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT
	Engine.time_scale = 1.0


func _open() -> VersusMode:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


func test_a_client_copies_the_kit_the_room_sends() -> void:
	var versus := await _open()
	var room_kit := versus.local_hunter()
	room_kit.equip(versus.item(&"uv_laser"))
	room_kit.equip(versus.item(&"medkit"))
	room_kit.take_blow(1)
	var state := VersusNet.hunter_state(room_kit)
	var copy := HunterKit.new(versus)
	var scene: PackedScene = load(versus.get_parent().player.scene_file_path)
	var body: Player = scene.instantiate()
	body.local_controls = false
	add_child_autofree(body)
	body.add_child(copy)
	var net := NetGame.new()
	var link := VersusNet.new(versus, net)
	add_child(link)
	watch_signals(copy)
	link.apply_hunter_state(copy, state)
	assert_eq(copy.vitals.health, room_kit.vitals.health)
	assert_signal_emitted(copy, "hurt", "the red edge on the client too")
	assert_eq(copy.loadout.weapon, versus.item(&"uv_laser"))
	assert_not_null(copy.laser)
	assert_eq(copy.loadout.tool_in(0), versus.item(&"medkit"))
	assert_eq(copy.loadout.uses[0], room_kit.loadout.uses[0])
	link.free()
	net.free()


func test_the_prompts_are_data_a_client_can_show() -> void:
	var versus := await _open()
	var kit := versus.local_hunter()
	assert_eq(KitPrompts.of_hunter(kit), [], "nothing in reach")
	kit.vitals.hurt(99)
	var prompt := KitPrompts.of_hunter(kit)
	assert_eq(prompt[0], "VERSUS_DOWN_TIME")
	assert_eq(KitPrompts.text_of(prompt), Text.t("VERSUS_DOWN_TIME", prompt[1]))
	var take := KitPrompts.text_of(["VERSUS_CHEST_TAKE", "VERSUS_ITEM_MEDKIT", 0.5])
	assert_string_contains(take, Text.t("VERSUS_ITEM_MEDKIT"))


func test_a_client_copies_the_chests() -> void:
	var versus := await _open()
	var net := NetGame.new()
	var link := VersusNet.new(versus, net)
	add_child(link)
	var at := Vector3(3, 0, 4)
	link.apply_net_event([VersusNet.Event.CHESTS, [[at, "uv_laser", true, 0]]])
	var chests := versus.get_tree().get_nodes_in_group(VersusChest.GROUP)
	assert_eq(chests.size(), 1)
	var chest := chests[0] as VersusChest
	assert_eq(chest.global_position, at)
	assert_true(chest.is_open)
	assert_eq(chest.item, versus.item(&"uv_laser"))
	assert_eq(link.chest_values(), [[at, "uv_laser", true, 0]], "the same values as the room's")
	link.free()
	net.free()


func test_the_network_carries_mode_events_to_a_seat_or_all() -> void:
	var net := NetGame.new()
	net.is_room = true
	net.avatars = {7: Node3D.new(), 8: Node3D.new()}
	net.seats = {7: 0, 8: 2}
	net.send_mode_event([1, "x"], 2)
	assert_eq(net.sent_events, [[8, [NetGame.Event.MODE, [1, "x"]]]])
	net.sent_events.clear()
	net.send_mode_event([3])
	assert_eq(net.sent_events.size(), 2, "to everyone")
	for node: Node in net.avatars.values():
		node.free()
	net.free()
