extends GutTest
## The families of hiding spots (spec S-016, Q6, T-235): low, makeshift, metal.

const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const CLOSET_SCENE := preload("res://game/entities/hiding_spot/closet.tscn")
const LOW_SCENE := preload("res://game/entities/hiding_spot/low_spot.tscn")
const MAKESHIFT_SCENE := preload("res://game/entities/hiding_spot/makeshift_spot.tscn")
const METAL_SCENE := preload("res://game/entities/hiding_spot/metal_spot.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const SETTINGS := preload("res://game/data/ruse_settings.tres")
const FAR_AWAY := Vector3(18, 0, -18)

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	GameSession.role = GameSession.Role.HUNTED


func _record(event: NoiseEvent) -> void:
	if event.type == NoiseEvent.Type.HIDE:
		_noises.append(event)


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


## A spot 2 m in front of a player at the origin, its front facing them.
func _setup(scene: PackedScene) -> Array:
	_add_floor()
	var spot: HidingSpot = scene.instantiate()
	add_child_autofree(spot)
	spot.global_position = Vector3(0, 0, -2)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(3)
	return [spot, player]


## Holds until the hidden state flips, and returns the time it took.
func _time_to_toggle(spot: HidingSpot, user: Node, step := 0.05) -> float:
	var hidden_before := spot.occupant == user
	var spent := 0.0
	while spent < 5.0:
		spot.hold(user, step)
		spent += step
		if (spot.occupant == user) != hidden_before:
			break
	spot.release(user)
	return spent


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.low_hide_time, 2.0, "Q6: low, 2 s")
	assert_eq(SETTINGS.low_noise_range, 1.0, "Q6: low, 1 m")
	assert_eq(SETTINGS.makeshift_hide_time, 0.5, "Q6: makeshift, 0.5 s")
	assert_eq(SETTINGS.makeshift_noise_range, 0.0, "Q6: makeshift, silent")
	assert_eq(SETTINGS.makeshift_reveal_distance, 2.0, "Q6: seen within 2 m")
	assert_eq(SETTINGS.metal_noise_range, 6.0, "Q6: metal, 6 m")
	assert_eq(SETTINGS.metal_open_time, 2.0, "Q6: metal, 2 s to open")


func test_a_closet_is_unchanged() -> void:
	var setup: Array = await _setup(CLOSET_SCENE)
	var spot: HidingSpot = setup[0]
	assert_eq(spot.family, HidingSpot.Family.CLOSET)
	assert_almost_eq(_time_to_toggle(spot, setup[1]), 1.0, 0.06)
	assert_eq(_noises[0].noise_range, 3.0)


func test_a_low_spot_is_slow_and_quiet() -> void:
	var setup: Array = await _setup(LOW_SCENE)
	var spot: HidingSpot = setup[0]
	var player: Player = setup[1]
	assert_almost_eq(_time_to_toggle(spot, player), 2.0, 0.06, "in: 2 s")
	assert_true(player.is_hidden())
	assert_true(spot.crouched, "lying low")
	assert_eq(_noises[0].noise_range, 1.0)
	assert_almost_eq(_time_to_toggle(spot, player), 2.0, 0.06, "out: 2 s too")
	assert_false(player.is_hidden())


func test_a_makeshift_spot_is_quick_and_silent() -> void:
	var setup: Array = await _setup(MAKESHIFT_SCENE)
	var spot: HidingSpot = setup[0]
	var player: Player = setup[1]
	assert_almost_eq(_time_to_toggle(spot, player), 0.5, 0.06)
	assert_true(player.is_hidden())
	assert_eq(_noises.size(), 0, "no noise at all")


func test_a_metal_spot_is_loud_and_slow_to_open() -> void:
	var setup: Array = await _setup(METAL_SCENE)
	var spot: HidingSpot = setup[0]
	var player: Player = setup[1]
	assert_almost_eq(_time_to_toggle(spot, player), 1.0, 0.06)
	assert_eq(_noises[0].noise_range, 6.0)
	var avatar: MonsterAvatar = AVATAR_SCENE.instantiate()
	add_child_autofree(avatar)
	avatar.set_physics_process(false)
	watch_signals(spot)
	var spent := 0.0
	while spot.occupant != null and spent < 5.0:
		spot.hold(avatar, 0.05)
		spent += 0.05
	assert_almost_eq(spent, 2.0, 0.06, "the monster: 2 s")
	assert_signal_emitted(spot, "found")
	assert_false(player.is_hidden(), "caught")


func test_makeshift_reveal_needs_a_close_monster_facing_it() -> void:
	var setup: Array = await _setup(MAKESHIFT_SCENE)
	var spot: HidingSpot = setup[0]
	var player: Player = setup[1]
	_time_to_toggle(spot, player)
	var at := spot.global_position
	var facing := Vector3.FORWARD  # Towards -Z.
	assert_true(HidingSpot.is_revealed(player, at + Vector3(0, 1.6, 1.5), facing), "1.5 m, facing")
	assert_false(HidingSpot.is_revealed(player, at + Vector3(0, 1.6, 3), facing), "3 m away")
	assert_false(HidingSpot.is_revealed(player, at + Vector3(0, 1.6, 1.5), -facing), "back to it")
	var side := at + Vector3(1.5, 1.6, 0)
	assert_true(HidingSpot.is_revealed(player, side, Vector3.LEFT), "from the side, facing it")


func test_a_closet_never_reveals() -> void:
	var setup: Array = await _setup(CLOSET_SCENE)
	var spot: HidingSpot = setup[0]
	var player: Player = setup[1]
	_time_to_toggle(spot, player)
	var eye := spot.global_position + Vector3(0, 1.6, 1.0)
	assert_false(HidingSpot.is_revealed(player, eye, Vector3.FORWARD))
	assert_true(HidingSpot.conceals(player, eye, Vector3.FORWARD))


func test_the_ai_monster_finds_a_hunted_behind_a_curtain_up_close() -> void:
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var player: Player = map.get_node("Player")
	var monster: Monster = map.get_node("Monster")
	var spot: HidingSpot = MAKESHIFT_SCENE.instantiate()
	map.add_child(spot)
	spot.global_position = Vector3(10, 0, -10)
	await wait_physics_frames(3)
	player.set_physics_process(false)
	_time_to_toggle(spot, player)
	assert_true(player.is_hidden())
	monster.global_position = spot.global_position + Vector3(0, 0, 1.5)
	monster.look_at(spot.global_position, Vector3.UP)
	await wait_seconds(0.5)
	assert_true(monster.sees_player, "seen behind the curtain")
	assert_eq(monster.open_target, spot, "it goes to open it")
