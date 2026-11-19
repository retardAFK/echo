extends GutTest
## Holding one's breath (S-020, T-311, piste H2).

const SETTINGS := preload("res://game/data/player_settings.tres")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const CLOSET_SCENE := preload("res://game/entities/hiding_spot/closet.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _from(source: Object, type: NoiseEvent.Type) -> int:
	return (
		_noises
		. filter(func(e: NoiseEvent) -> bool: return e.source == source and e.type == type)
		. size()
	)


func _floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)


func test_six_seconds_then_forty_to_recharge() -> void:
	var breath := BreathHold.new(SETTINGS)
	assert_eq(SETTINGS.breath_hold_time, 6.0)
	assert_eq(SETTINGS.breath_recharge_time, 40.0)
	breath.update(1.0, true)
	assert_true(breath.holding)
	breath.update(5.5, true)
	assert_false(breath.holding, "out of air")
	assert_eq(breath.recharge_left, 40.0)
	breath.update(20.0, true)
	assert_false(breath.holding, "not before the recharge")
	assert_almost_eq(breath.get_ratio(), 0.5, 0.001)
	breath.update(20.0, false)
	assert_eq(breath.left, 6.0, "ready again")


func test_letting_go_early_starts_the_recharge() -> void:
	var breath := BreathHold.new(SETTINGS)
	breath.update(2.0, true)
	breath.update(0.1, false)
	assert_false(breath.holding)
	assert_eq(breath.recharge_left, 40.0)


func test_the_key_goes_over_the_network() -> void:
	var commands := PlayerCommands.new()
	commands.hold_breath = true
	assert_true(PlayerCommands.from_bytes(commands.to_bytes()).hold_breath)
	assert_true(InputMap.has_action("hold_breath"))
	assert_has(ControlsText.keys_for(GameSession.Role.HUNTED), "CONTROLS_HOLD_BREATH")


func test_walking_holding_its_breath_makes_no_footstep() -> void:
	_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	await wait_physics_frames(3)
	player.commands.move = Vector2(0, -1)
	player.commands.hold_breath = true
	await wait_seconds(2.0)
	assert_true(player.breath_hold.holding)
	assert_eq(_from(player, NoiseEvent.Type.FOOTSTEP), 0, "silent steps")
	player.commands.hold_breath = false
	await wait_seconds(1.5)
	assert_gt(_from(player, NoiseEvent.Type.FOOTSTEP), 0, "breathing again: steps heard")


func test_hidden_near_the_monster_it_must_hold_its_breath() -> void:
	_floor()
	var closet: HidingSpot = CLOSET_SCENE.instantiate()
	add_child_autofree(closet)
	closet.global_position = Vector3(0, 0, -2)
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	await wait_physics_frames(3)
	closet.hold(player, 0.6)
	closet.hold(player, 0.6)
	closet.release(player)
	assert_true(player.is_hidden())
	await wait_seconds(1.2)
	assert_eq(_from(player, NoiseEvent.Type.BREATH), 0, "no monster near: silent")
	var monster: MonsterAvatar = AVATAR_SCENE.instantiate()
	monster.local_controls = false
	add_child_autofree(monster)
	monster.set_physics_process(false)
	monster.global_position = closet.global_position + Vector3(1.5, 0, 0)
	player.commands.hold_breath = true
	await wait_seconds(1.2)
	assert_eq(_from(player, NoiseEvent.Type.BREATH), 0, "holding it")
	player.commands.hold_breath = false
	await wait_seconds(1.2)
	var breaths := _noises.filter(func(e: NoiseEvent) -> bool: return e.source == player)
	assert_gt(breaths.size(), 0, "it breathes, the monster 1.5 m away")
	assert_eq(breaths[0].noise_range, SETTINGS.hidden_breath_range)


func test_the_bar_shows_the_breath_left() -> void:
	var breath := BreathHold.new(SETTINGS)
	var bar := BreathBar.new(breath)
	add_child_autofree(bar)
	breath.update(3.0, true)
	bar._process(0.0)
	assert_almost_eq(bar.get_fill(), 0.5, 0.01)
