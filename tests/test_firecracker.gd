extends GutTest
## The firecracker (S-020, T-312, piste R1): placed on the ground, it goes off
## under the monster, which then hears nothing for 6 s.

const SETTINGS := preload("res://game/data/ruse_settings.tres")
const FIRECRACKER_SCENE := preload("res://game/entities/firecracker/firecracker.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _firecracker(at: Vector3) -> Firecracker:
	var firecracker: Firecracker = FIRECRACKER_SCENE.instantiate()
	add_child_autofree(firecracker)
	firecracker.global_position = at
	return firecracker


func _avatar(at: Vector3) -> MonsterAvatar:
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)  # Driven by hand.
	avatar.global_position = at
	return avatar


func test_settings_follow_the_roadmap() -> void:
	assert_eq(SETTINGS.deafen_time, 6.0)
	assert_eq(SETTINGS.start_firecrackers, 1)
	assert_eq(SETTINGS.max_firecrackers, 1)
	var inventory := Inventory.new(SETTINGS)
	assert_eq(inventory.count(Inventory.Kind.FIRECRACKER), 1, "one per hunted, from the start")
	assert_false(inventory.can_take(Inventory.Kind.FIRECRACKER))
	assert_string_contains(CarryHud.describe(inventory), "Pétard")


func test_deafness_counts_down_and_never_shortens() -> void:
	var deafness := Deafness.new()
	assert_false(deafness.is_deaf())
	deafness.deafen(6.0)
	deafness.deafen(2.0)
	assert_eq(deafness.left, 6.0, "never shortens a longer deafness")
	deafness.update(5.9)
	assert_true(deafness.is_deaf())
	deafness.update(1.0)
	assert_false(deafness.is_deaf())
	assert_eq(deafness.left, 0.0)
	assert_false(Deafness.of(Node3D.new()), "anything else is never deaf")


func test_it_goes_off_under_the_monster_once_armed() -> void:
	var firecracker := _firecracker(Vector3.ZERO)
	var avatar := _avatar(Vector3(1.0, 0, 0))
	await wait_physics_frames(2)
	assert_false(firecracker.is_armed(), "the one who placed it can step away")
	assert_eq(Firecracker.burst_near(avatar), 0)
	firecracker.arm_left = 0.0
	avatar.global_position = Vector3(SETTINGS.firecracker_trigger_distance + 0.5, 0, 0)
	assert_eq(Firecracker.burst_near(avatar), 0, "too far")
	avatar.global_position = Vector3(1.0, 0, 0)
	assert_eq(Firecracker.burst_near(avatar), 1)
	assert_eq(avatar.deafness.left, SETTINGS.deafen_time)
	var cracks := _noises.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.FIRECRACKER
	)
	assert_eq(cracks.size(), 1, "the hunted hear it")
	assert_eq(cracks[0].noise_range, SETTINGS.firecracker_range)
	assert_eq(Firecracker.burst_near(avatar), 0, "only once")


func test_the_deaf_monster_sees_no_noise() -> void:
	var avatar := _avatar(Vector3.ZERO)
	await wait_physics_frames(1)
	var markers := NoiseMarkers.new()
	markers.monster = avatar
	add_child_autofree(markers)
	var near := Vector3(2, 0, 0)
	avatar.deafness.deafen(6.0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, 8.0, self)
	assert_eq(markers.get_active_count(), 0, "deafened: no ring")
	var event := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, near, 8.0, null)
	assert_eq(NetGame.noise_message(event, avatar, true), [], "online, the room sends nothing")
	avatar.deafness.update(7.0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, 8.0, self)
	assert_eq(markers.get_active_count(), 1, "then it hears again")
	assert_false(NetGame.noise_message(event, avatar, true).is_empty())


func test_the_deaf_ai_monster_does_not_come() -> void:
	GameSession.role = GameSession.Role.HUNTED
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	monster.set_physics_process(false)
	await wait_physics_frames(2)
	var near := monster.global_position + Vector3(4, 0, 0)
	monster.deafness.deafen(SETTINGS.deafen_time)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, 10.0, self)
	assert_ne(monster.brain.state, MonsterBrain.State.INVESTIGATE, "deafened")
	monster.deafness.update(SETTINGS.deafen_time)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, 10.0, self)
	assert_eq(monster.brain.state, MonsterBrain.State.INVESTIGATE, "then it hears again")


func test_the_player_places_it_with_its_key() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(2)
	player.commands.push(PlayerCommands.Action.FIRECRACKER)
	player.apply_actions()
	assert_eq(player.inventory.count(Inventory.Kind.FIRECRACKER), 0)
	assert_eq(get_tree().get_nodes_in_group(Firecracker.GROUP).size(), 1)
	player.commands.push(PlayerCommands.Action.FIRECRACKER)
	player.apply_actions()
	assert_eq(get_tree().get_nodes_in_group(Firecracker.GROUP).size(), 1, "only one per game")
	for node in get_tree().get_nodes_in_group(Firecracker.GROUP):
		node.free()


func test_the_command_travels_online() -> void:
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.FIRECRACKER)
	var copy := PlayerCommands.from_bytes(commands.to_bytes())
	assert_eq(
		copy.take_actions(), [PlayerCommands.Action.FIRECRACKER] as Array[PlayerCommands.Action]
	)
