extends GutTest
## Windows and low walls to climb over (spec S-020, T-340, piste E6): the
## hunted gets over in 0.5 s, the monster in 1.5 s, both make a noise; nobody
## climbs crouched or out of reach.

const VAULT_SCENE := preload("res://game/entities/vault/vault.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const SETTINGS := preload("res://game/data/vault_settings.tres")

var _heard: Array[NoiseEvent] = []


func before_each() -> void:
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func _ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child_autofree(ground)


## A low wall along X at the origin, 0.9 m high.
func _vault() -> Vault:
	var vault: Vault = VAULT_SCENE.instantiate()
	add_child_autofree(vault)
	return vault


func _player(at: Vector3) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	player.position = at
	add_child_autofree(player)
	return player


func test_the_motion_clears_the_top_and_lands() -> void:
	var motion := VaultMotion.new()
	motion.start(Vector3(0, 0, 1), Vector3(0, 0, -1), 0.5, 1.1)
	assert_true(motion.is_active())
	assert_almost_eq(motion.position_at(0.5).y, 1.1, 0.001, "over the top at the middle")
	assert_almost_eq(motion.step(0.25).z, 0.0, 0.001)
	assert_eq(motion.step(0.3), Vector3(0, 0, -1), "landed")
	assert_false(motion.is_active())


func test_the_hunted_gets_over_in_half_a_second() -> void:
	_ground()
	var vault := _vault()
	var player := _player(Vector3(0.2, 0, 1.0))
	await wait_physics_frames(2)
	assert_true(vault.can_interact(player.global_position))
	assert_true(vault.climb(player))
	assert_eq(vault.time_for(player), SETTINGS.hunted_time)
	var made: Array[NoiseEvent] = _heard.filter(
		func(event: NoiseEvent) -> bool: return event.source == player
	)
	assert_eq(made.back().noise_range, SETTINGS.hunted_range, "a noise")
	await wait_seconds(SETTINGS.hunted_time * 0.5)
	assert_true(player.vault_motion.is_active(), "still on its way")
	assert_gt(player.global_position.y, 0.5, "up over the wall")
	await wait_seconds(SETTINGS.hunted_time * 0.5 + 0.15)
	assert_false(player.vault_motion.is_active())
	var landed := -(vault.thickness / 2.0 + SETTINGS.landing_distance)
	assert_almost_eq(player.global_position.z, landed, 0.15, "on the other side")


func test_the_way_back_lands_on_the_first_side() -> void:
	var vault := _vault()
	var landing := vault.landing_for(Vector3(0, 0, -1.0))
	assert_gt(landing.z, 0.0)
	vault.rotation.y = PI / 2.0
	var turned := vault.landing_for(Vector3(1.0, 0, 0))
	assert_lt(turned.x, 0.0, "across a wall that runs north to south")


func test_the_monster_is_slower_and_louder() -> void:
	var vault := _vault()
	var monster := Node3D.new()
	monster.add_to_group(Prison.MONSTERS_GROUP)
	add_child_autofree(monster)
	assert_eq(vault.time_for(monster), SETTINGS.monster_time)
	assert_gt(SETTINGS.monster_time, SETTINGS.hunted_time)
	assert_gt(SETTINGS.monster_range, SETTINGS.hunted_range)


func test_nobody_climbs_crouched_or_from_afar() -> void:
	_ground()
	var vault := _vault()
	var player := _player(Vector3(0, 0, 1.0))
	await wait_physics_frames(2)
	player.toggle_crouch()
	await wait_physics_frames(2)
	assert_true(player.is_sneaking())
	assert_false(vault.wanted_by(player))
	assert_false(vault.climb(player))
	assert_false(player.vault_motion.is_active())
	assert_false(vault.can_interact(Vector3(0, 0, SETTINGS.reach + 0.5)), "too far")
	assert_false(vault.can_interact(Vector3(vault.width / 2.0 + SETTINGS.reach + 0.3, 0, 0)))


func test_the_player_presses_interact_in_front_of_it() -> void:
	_ground()
	var vault := _vault()
	var player := _player(Vector3(0, 0, 1.0))
	await wait_physics_frames(2)
	player.set_look(0.0, 0.0)  # Looking north, at the wall.
	assert_eq(player.get_interactable(), vault)
	player.commands.push(PlayerCommands.Action.INTERACT)
	await wait_physics_frames(2)
	assert_true(player.vault_motion.is_active())


func test_the_played_monster_holds_interact_and_takes_longer() -> void:
	_ground()
	var vault := _vault()
	var avatar: MonsterAvatar = (
		load("res://game/entities/monster/monster_avatar.tscn").instantiate()
	)
	avatar.local_controls = false
	avatar.position = Vector3(0, 0, 1.0)
	add_child_autofree(avatar)
	await wait_physics_frames(2)
	avatar.set_look(0.0, 0.0)
	assert_eq(avatar.get_interactable(), vault)
	avatar.commands.interact = true
	await wait_physics_frames(2)
	assert_true(avatar.vault_motion.is_active())
	assert_almost_eq(avatar.vault_motion.duration, SETTINGS.monster_time, 0.001)
	await wait_seconds(SETTINGS.monster_time + 0.2)
	assert_false(avatar.vault_motion.is_active())
	assert_lt(avatar.global_position.z, 0.0, "on the other side")
	await wait_physics_frames(5)
	assert_false(avatar.vault_motion.is_active(), "holding on does not climb back")
