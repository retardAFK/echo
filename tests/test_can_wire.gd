extends GutTest
## The can wire (S-020, T-333, piste R5): stretched across a passage, it
## rattles once when the monster crosses it, and the hunted hear it far.

const SETTINGS := preload("res://game/data/ruse_settings.tres")
const WIRE_SCENE := preload("res://game/entities/can_wire/can_wire.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	for node in get_tree().get_nodes_in_group(CanWire.GROUP):
		node.free()


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _rattles() -> Array[NoiseEvent]:
	return _noises.filter(func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.CANS)


func _wire(at: Vector3, yaw := 0.0) -> CanWire:
	var wire: CanWire = WIRE_SCENE.instantiate()
	add_child(wire)
	wire.global_position = at
	wire.global_rotation = Vector3(0.0, yaw, 0.0)
	return wire


func _avatar(at: Vector3) -> MonsterAvatar:
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)  # Driven by hand.
	avatar.global_position = at
	return avatar


func test_a_hunted_who_picked_it_carries_two() -> void:
	var inventory := Inventory.new(SETTINGS)
	var picked: Array[StringName] = [&"can_wire", &"firecracker"]
	Loadout.equip(inventory, picked)  # Picked before the game (S-023).
	assert_eq(inventory.count(Inventory.Kind.CAN_WIRE), Loadout.SETTINGS.charges)
	assert_false(inventory.can_take(Inventory.Kind.CAN_WIRE))
	assert_string_contains(CarryHud.describe(inventory, false, picked), "Fil à canettes")


func test_the_string_runs_across_the_way_it_was_placed() -> void:
	var wire := _wire(Vector3.ZERO, PI / 2.0)
	var ends := wire.ends()
	assert_almost_eq(ends[0].distance_to(ends[1]), SETTINGS.can_wire_length, 0.01)
	assert_almost_eq(absf(ends[0].z), SETTINGS.can_wire_length / 2.0, 0.01, "turned a quarter")
	assert_true(wire.crossed_by(Vector3(0.2, 0, 1.0)))
	assert_false(wire.crossed_by(Vector3(0, 0, SETTINGS.can_wire_length)), "past its end")
	assert_false(wire.crossed_by(Vector3(1.5, 0, 0)), "beside the string")


func test_it_rattles_once_under_the_monster_once_armed() -> void:
	var wire := _wire(Vector3.ZERO)
	var avatar := _avatar(Vector3(0.5, 0, 0.1))
	await wait_physics_frames(2)
	assert_false(wire.is_armed(), "the one who placed it can step away")
	assert_eq(CanWire.yank_near(avatar), 0)
	wire.arm_left = 0.0
	avatar.global_position = Vector3(0.5, 0, 2.0)
	assert_eq(CanWire.yank_near(avatar), 0, "not on the string")
	avatar.global_position = Vector3(0.5, 0, 0.1)
	assert_eq(CanWire.yank_near(avatar), 1)
	assert_eq(_rattles().size(), 1)
	assert_eq(_rattles()[0].noise_range, SETTINGS.can_wire_range)
	assert_eq(CanWire.yank_near(avatar), 0, "only once")
	assert_eq(_rattles().size(), 1)


func test_the_moving_monster_yanks_it() -> void:
	var wire := _wire(Vector3.ZERO)
	wire.arm_left = 0.0
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.global_position = Vector3(0, 0, 0.2)
	await wait_physics_frames(3)
	assert_true(wire.done, "the room's monster avatar checks its feet every frame")


func test_the_player_stretches_it_with_its_key() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.rotation.y = PI / 2.0
	await wait_physics_frames(2)
	player.loadout = [&"can_wire", &"smoke"]  # Picked before the game (S-023).
	watch_signals(player)
	player.commands.push(PlayerCommands.Action.GADGET_1)
	player.apply_actions()
	assert_eq(player.inventory.count(Inventory.Kind.CAN_WIRE), 1, "one of two charges used")
	assert_signal_emitted_with_parameters(player, "ruse_used", [&"can_wire"])
	var wires := get_tree().get_nodes_in_group(CanWire.GROUP)
	assert_eq(wires.size(), 1)
	var wire := wires[0] as CanWire
	var along := (wire.ends()[1] - wire.ends()[0]).normalized()
	assert_almost_eq(along.dot(-player.global_basis.z), 0.0, 0.01, "across the way it faces")
	for i in 2:
		player.commands.push(PlayerCommands.Action.GADGET_1)
		player.apply_actions()
	assert_eq(get_tree().get_nodes_in_group(CanWire.GROUP).size(), 2, "two charges per game")


func test_the_command_travels_online() -> void:
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.GADGET_1)
	var copy := PlayerCommands.from_bytes(commands.to_bytes())
	assert_eq(copy.take_actions(), [PlayerCommands.Action.GADGET_1] as Array[PlayerCommands.Action])


func test_online_the_room_tells_everyone() -> void:
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, Node3D.new())
	net.add_avatar(2, LobbyState.MONSTER_SEAT, Node3D.new())
	add_child_autofree(net)
	var wire: CanWire = WIRE_SCENE.instantiate()
	net.get_parent().add_child(wire)
	wire.global_position = Vector3(3, 0, 4)
	wire.global_rotation.y = 1.0
	await wait_physics_frames(1)
	for place in [1, 2]:
		assert_has(net.sent_events, [place, [NetGame.Event.CAN_WIRE, Vector3(3, 0, 4), 1.0]])
	wire.rattle()
	assert_has(net.sent_events, [1, [NetGame.Event.RATTLE, Vector3(3, 0, 4)]])


func test_a_client_copy_rattles_only_when_the_room_says() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var net := NetGame.new()
	parent.add_child(net)
	net.apply_event([NetGame.Event.CAN_WIRE, Vector3(1, 0, 2), 0.5])
	var wires := get_tree().get_nodes_in_group(CanWire.GROUP)
	assert_eq(wires.size(), 1)
	var copy := wires[0] as CanWire
	assert_true(copy.mirror)
	assert_almost_eq(copy.global_rotation.y, 0.5, 0.001)
	copy.arm_left = 0.0
	assert_false(copy.is_armed(), "the room yanks it, not the client")
	net.apply_event([NetGame.Event.RATTLE, Vector3(1, 0, 2)])
	assert_true(copy.done)
	assert_eq(_rattles().size(), 0, "the room already sent the noise")


func test_the_carried_count_travels_in_the_snapshot() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, player)
	add_child_autofree(net)
	player.inventory.use(Inventory.Kind.CAN_WIRE)
	var you: Array = net.snapshot_for(1)["you"]
	assert_eq(you[15], 0)
