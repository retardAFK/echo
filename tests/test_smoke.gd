extends GutTest
## The smoke bomb (S-020, T-335, piste R4): a cloud of 10 s that cuts sight
## through it, for the AI and in what the room sends each player.

const SETTINGS := preload("res://game/data/ruse_settings.tres")
const SMOKE_SCENE := preload("res://game/entities/smoke/smoke_cloud.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const CHASE := preload("res://game/data/chase_settings.tres")

const LEFT := Vector3(-6, 1.6, 0)
const RIGHT := Vector3(6, 1.6, 0)


func after_each() -> void:
	for node in get_tree().get_nodes_in_group(SmokeCloud.GROUP):
		node.free()


## A cloud at a place, grown to its full size.
func _cloud(at: Vector3 = Vector3.ZERO) -> SmokeCloud:
	var cloud: SmokeCloud = SMOKE_SCENE.instantiate()
	add_child(cloud)
	cloud.global_position = at
	cloud.set_physics_process(false)
	cloud.age = SETTINGS.smoke_grow_time
	return cloud


func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


func _player(at: Vector3, yaw: float) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = at
	player.rotation.y = yaw
	return player


func test_a_hunted_who_picked_it_carries_two() -> void:
	var inventory := Inventory.new(SETTINGS)
	var picked: Array[StringName] = [&"smoke", &"firecracker"]
	Loadout.equip(inventory, picked)  # Picked before the game (S-023).
	assert_eq(inventory.count(Inventory.Kind.SMOKE), Loadout.SETTINGS.charges)
	assert_false(inventory.can_take(Inventory.Kind.SMOKE))
	assert_string_contains(CarryHud.describe(inventory, false, picked), "Fumigène")


func test_the_cloud_cuts_sight_through_it_for_its_time() -> void:
	assert_false(SmokeCloud.blocks(LEFT, RIGHT), "no cloud")
	var cloud := _cloud()
	cloud.age = 0.0
	assert_false(SmokeCloud.blocks(LEFT, RIGHT), "it has not spread yet")
	cloud.age = SETTINGS.smoke_grow_time
	assert_true(SmokeCloud.blocks(LEFT, RIGHT))
	assert_true(SmokeCloud.blocks(RIGHT, LEFT), "both ways")
	var beside := Vector3(0, 0, SETTINGS.smoke_radius + 1.0)
	assert_false(SmokeCloud.blocks(LEFT + beside, RIGHT + beside), "a line beside it")
	assert_false(SmokeCloud.blocks(Vector3(0, 1.6, 0), Vector3(1, 1.6, 0)), "face to face in it")
	cloud._physics_process(SETTINGS.smoke_time)
	assert_true(cloud.done)
	assert_false(SmokeCloud.blocks(LEFT, RIGHT), "it thinned out")


func test_the_ai_loses_sight_in_the_smoke() -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	assert_true(MonsterVision.has_line_of_sight(space, LEFT, RIGHT))
	_cloud()
	assert_false(MonsterVision.has_line_of_sight(space, LEFT, RIGHT))


func test_the_room_sends_nobody_behind_the_smoke() -> void:
	_floor()
	var hunted := _player(Vector3(-6, 0.1, 0), -PI / 2.0)  # Faces +X.
	var other := _player(Vector3(6, 0.1, 0), PI / 2.0)  # Faces -X.
	await wait_physics_frames(2)
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	add_child_autofree(net)
	assert_true(net.sees(hunted, other), "in plain sight first")
	_cloud()
	assert_false(net.sees(hunted, other))
	assert_false(net.sees(other, hunted), "both ways")


func test_a_chase_loses_its_hunted_in_the_smoke() -> void:
	_floor()
	var monster := _player(Vector3(-6, 0.1, 0), -PI / 2.0)
	var hunted := _player(Vector3(6, 0.1, 0), 0.0)
	await wait_physics_frames(2)
	assert_true(ChaseWatch.sees(monster, hunted, CHASE))
	_cloud()
	assert_false(ChaseWatch.sees(monster, hunted, CHASE))


func test_the_player_sets_it_off_at_its_feet() -> void:
	_floor()
	var player := _player(Vector3(2, 0.1, 3), 0.0)
	await wait_physics_frames(2)
	assert_eq(player.loadout[1], &"smoke", "in the default loadout, slot 2")
	watch_signals(player)
	player.commands.push(PlayerCommands.Action.GADGET_2)
	player.apply_actions()
	assert_eq(player.inventory.count(Inventory.Kind.SMOKE), 1, "one of two charges used")
	assert_signal_emitted_with_parameters(player, "ruse_used", [&"smoke"])
	var clouds := get_tree().get_nodes_in_group(SmokeCloud.GROUP)
	assert_eq(clouds.size(), 1)
	assert_almost_eq(
		(clouds[0] as SmokeCloud).global_position, player.global_position, Vector3.ONE * 0.01
	)
	for i in 2:
		player.commands.push(PlayerCommands.Action.GADGET_2)
		player.apply_actions()
	assert_eq(get_tree().get_nodes_in_group(SmokeCloud.GROUP).size(), 2, "two charges per game")


func test_the_command_travels_online() -> void:
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.SECOND_WIND)
	commands.push(PlayerCommands.Action.GADGET_2)
	var copy := PlayerCommands.from_bytes(commands.to_bytes())
	assert_eq(
		copy.take_actions(),
		(
			[PlayerCommands.Action.SECOND_WIND, PlayerCommands.Action.GADGET_2]
			as Array[PlayerCommands.Action]
		)
	)


func test_online_the_room_shows_it_to_everyone() -> void:
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, Node3D.new())
	add_child_autofree(net)
	var cloud: SmokeCloud = SMOKE_SCENE.instantiate()
	net.get_parent().add_child(cloud)
	cloud.global_position = Vector3(3, 0, 4)
	await wait_physics_frames(1)
	assert_has(net.sent_events, [1, [NetGame.Event.SMOKE, Vector3(3, 0, 4)]])
	cloud.free()
	var client := NetGame.new()
	add_child_autofree(client)
	client.apply_event([NetGame.Event.SMOKE, Vector3(1, 0, 2)])
	var clouds := get_tree().get_nodes_in_group(SmokeCloud.GROUP)
	assert_eq(clouds.size(), 1)
	assert_eq((clouds[0] as SmokeCloud).global_position, Vector3(1, 0, 2))


func test_the_carried_count_travels_in_the_snapshot() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	player.loadout = [&"smoke", &"firecracker"]
	net.add_avatar(1, 1, player)
	add_child_autofree(net)
	assert_eq(net.snapshot_for(1)["you"][17], 2)
	player.inventory.use(Inventory.Kind.SMOKE)
	assert_eq(net.snapshot_for(1)["you"][17], 1)
