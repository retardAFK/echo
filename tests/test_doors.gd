extends GutTest
## Doors that open and close (spec S-016, T-232).

const DOOR_SCENE := preload("res://game/entities/door/door.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const SETTINGS := preload("res://game/data/door_settings.tres")


## Someone who opens doors crouched or prowling.
class Sneaker:
	extends Node3D

	func is_sneaking() -> bool:
		return true


var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	if event.type == NoiseEvent.Type.DOOR:
		_noises.append(event)


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


## A closed door at the origin, its leaf across X, waiting a frame for physics.
func _door() -> Door:
	var door: Door = DOOR_SCENE.instantiate()
	add_child_autofree(door)
	await wait_physics_frames(2)
	return door


func _space() -> PhysicsDirectSpaceState3D:
	return get_viewport().get_world_3d().direct_space_state


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.open_range, 6.0, "Q1: 6 m standing (section 6.2)")
	assert_eq(SETTINGS.quiet_range, 2.0, "Q1: 2 m crouched")
	assert_eq(SETTINGS.quiet_time, 1.0, "Q1: 1 s crouched")
	assert_eq(SETTINGS.smash_range, 12.0, "Q2: 12 m smashed")


func test_a_closed_door_is_a_wall_and_an_open_one_is_not() -> void:
	var door: Door = await _door()
	var front := Vector3(0, 1.2, 2)
	var back := Vector3(0, 1.2, -2)
	assert_false(MonsterVision.has_line_of_sight(_space(), front, back), "Q1: blocks sight")
	assert_eq(NoiseBus.walls_between(front, back), 1, "Q1: muffles noise like a wall")
	door.toggle(null, SETTINGS.open_range)
	await wait_physics_frames(2)
	assert_true(door.is_open)
	assert_true(MonsterVision.has_line_of_sight(_space(), front, back), "open: sees through")
	assert_eq(NoiseBus.walls_between(front, back), 0, "open: no wall")


func test_player_opens_and_closes_it_standing_with_a_noise_of_6_m() -> void:
	_add_floor()
	var door: Door = await _door()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0, 0, 1.2)
	await wait_physics_frames(3)
	assert_eq(player.get_interactable(), door, "in reach, in front")
	assert_eq(door.get_prompt_for(player), "HUD_INTERACT_DOOR_OPEN")
	assert_true(door.hold(player, 0.016), "standing: at once")
	assert_true(door.is_open)
	assert_eq(_noises.size(), 1)
	assert_eq(_noises[0].noise_range, 6.0)
	assert_eq(door.get_prompt_for(player), "HUD_INTERACT_DOOR_CLOSE")
	assert_false(door.hold(player, 0.016), "holding on does not swing it back")
	door.release(player)
	assert_true(door.hold(player, 0.016), "a new press closes it")
	assert_false(door.is_open)
	assert_eq(_noises.size(), 2)


func test_crouched_it_takes_1_s_and_makes_a_noise_of_2_m() -> void:
	var door: Door = await _door()
	var sneaker := Sneaker.new()
	add_child_autofree(sneaker)
	sneaker.global_position = Vector3(0, 0, 1)
	assert_false(door.hold(sneaker, 0.5))
	assert_almost_eq(door.get_hold_ratio(), 0.5, 0.01)
	assert_false(door.is_open, "half way")
	assert_true(door.hold(sneaker, 0.6))
	assert_true(door.is_open)
	assert_eq(_noises.size(), 1)
	assert_eq(_noises[0].noise_range, 2.0)


func test_a_crouched_player_sneaks() -> void:
	_add_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(3)
	assert_false(Door.sneaks(player))
	player.toggle_crouch()
	await wait_physics_frames(3)
	assert_true(Door.sneaks(player))


func test_it_swings_away_from_the_one_who_opens_it() -> void:
	var door: Door = await _door()
	var sneaker := Sneaker.new()
	add_child_autofree(sneaker)
	sneaker.global_position = Vector3(0, 0, 1)
	door.toggle(sneaker, 0.0)
	await wait_seconds(SETTINGS.swing_time + 0.1)
	var leaf: Node3D = door.get_node("Hinge/Leaf")
	assert_lt(leaf.global_position.z, -0.3, "opened from +Z: swings to -Z")
	door.toggle(sneaker, 0.0)
	sneaker.global_position = Vector3(0, 0, -1)
	door.toggle(sneaker, 0.0)
	await wait_seconds(SETTINGS.swing_time + 0.1)
	assert_gt(leaf.global_position.z, 0.3, "opened from -Z: swings to +Z")


func test_closed_ahead_finds_only_a_closed_door_in_front() -> void:
	var door: Door = await _door()
	var tree := get_tree()
	var from := Vector3(0, 0, 1)
	assert_eq(Door.closed_ahead(tree, from, Vector3.FORWARD, 1.5), door, "ahead")
	assert_null(Door.closed_ahead(tree, from, Vector3.BACK, 1.5), "behind")
	assert_null(Door.closed_ahead(tree, from, Vector3.RIGHT, 1.5), "beside")
	assert_null(Door.closed_ahead(tree, Vector3(0, 0, 3), Vector3.FORWARD, 1.5), "too far")
	assert_null(Door.closed_ahead(tree, Vector3(0, 3, 1), Vector3.FORWARD, 1.5), "other floor")
	door.open_by(null)
	assert_null(Door.closed_ahead(tree, from, Vector3.FORWARD, 1.5), "open")


func test_the_running_monster_smashes_it_with_a_noise_of_12_m() -> void:
	_add_floor()
	var door: Door = await _door()
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)  # Driven by hand.
	avatar.global_position = Vector3(0, 0, 3)
	await wait_physics_frames(3)
	for i in 60:
		avatar.move(Vector2(0, -1), true, 1.0 / 60.0)
		if door.is_open:
			break
		await wait_physics_frames(1)
	assert_true(door.is_open, "Q2: smashed open on the run")
	assert_eq(_noises.size(), 1)
	assert_eq(_noises[0].noise_range, 12.0)
	assert_eq(door.last_user, avatar)


func test_the_walking_monster_does_not_smash_it() -> void:
	_add_floor()
	var door: Door = await _door()
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)
	avatar.global_position = Vector3(0, 0, 2)
	await wait_physics_frames(3)
	for i in 60:
		avatar.move(Vector2(0, -1), false, 1.0 / 60.0)
		await wait_physics_frames(1)
	assert_false(door.is_open, "walking into it: it stays shut")
	assert_gt(avatar.global_position.z, 0.0, "and stops the monster")


func test_the_monster_opens_it_by_hand() -> void:
	_add_floor()
	var door: Door = await _door()
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)
	avatar.global_position = Vector3(0, 0, 1.2)
	await wait_physics_frames(3)
	assert_eq(avatar.get_interactable(), door)
	assert_true(door.hold(avatar, 0.016))
	assert_true(door.is_open)
	assert_eq(_noises[0].noise_range, 6.0, "walking: the loud way")
	door.release(avatar)
	avatar.toggle_prowl()
	assert_false(door.hold(avatar, 0.5), "prowling: the quiet way")
	assert_true(door.hold(avatar, 0.6))
	assert_eq(_noises[1].noise_range, 2.0)
