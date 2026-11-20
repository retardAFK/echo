extends GutTest
## The hunted's second wind (S-020, T-338, piste E5): once a minute, 2 s at
## 6.5 m/s, very loud.

const SETTINGS := preload("res://game/data/player_settings.tres")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")

var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _running_player() -> Player:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.commands.move = Vector2(0, -1)
	player.commands.sprint = true
	return player


func _flat_speed(player: Player) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func test_settings_follow_the_roadmap() -> void:
	assert_eq(SETTINGS.second_wind_time, 2.0)
	assert_eq(SETTINGS.second_wind_speed, 6.5)
	assert_eq(SETTINGS.second_wind_recharge, 60.0)
	assert_gt(SETTINGS.second_wind_speed, SETTINGS.sprint_speed)


func test_once_a_minute_for_two_seconds() -> void:
	var wind := SecondWind.new(SETTINGS)
	assert_true(wind.start())
	assert_true(wind.is_active())
	wind.update(1.9)
	assert_true(wind.is_active())
	wind.update(0.2)
	assert_false(wind.is_active(), "two seconds")
	assert_false(wind.start(), "once a minute")
	wind.update(57.8)
	assert_false(wind.is_ready())
	wind.update(0.2)
	assert_true(wind.start(), "a minute after the last one started")


func test_the_player_bursts_faster_than_a_sprint_and_loud() -> void:
	var player := _running_player()
	await wait_physics_frames(40)
	assert_almost_eq(_flat_speed(player), SETTINGS.sprint_speed, 0.1, "sprinting first")
	_noises.clear()
	player.commands.push(PlayerCommands.Action.SECOND_WIND)
	await wait_physics_frames(60)
	assert_almost_eq(_flat_speed(player), SETTINGS.second_wind_speed, 0.1)
	var gasps := _noises.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.BREATH
	)
	assert_eq(gasps.size(), 1, "a gasp as it starts")
	assert_eq(gasps[0].noise_range, SETTINGS.second_wind_range)
	var steps := _noises.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.FOOTSTEP
	)
	assert_gt(steps.size(), 0)
	for step: NoiseEvent in steps:
		assert_eq(step.noise_range, SETTINGS.second_wind_range, "every step heard far")
	await wait_physics_frames(90)
	assert_false(player.second_wind.is_active())
	assert_almost_eq(_flat_speed(player), SETTINGS.sprint_speed, 0.1, "back to a sprint")
	player.commands.push(PlayerCommands.Action.SECOND_WIND)
	await wait_physics_frames(30)
	assert_almost_eq(_flat_speed(player), SETTINGS.sprint_speed, 0.1, "not again so soon")


func test_an_online_client_predicts_it() -> void:
	var player := _running_player()
	player.mirror_world = true
	await wait_physics_frames(2)
	player.commands.push(PlayerCommands.Action.SECOND_WIND)
	await wait_physics_frames(2)
	assert_true(player.second_wind.is_active(), "the client moves with the room")
	var gasps := _noises.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.BREATH
	)
	assert_eq(gasps.size(), 0, "the room makes the noise")


func test_the_command_travels_online() -> void:
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.SECOND_WIND)
	var copy := PlayerCommands.from_bytes(commands.to_bytes())
	assert_eq(
		copy.take_actions(), [PlayerCommands.Action.SECOND_WIND] as Array[PlayerCommands.Action]
	)


func test_the_bar_shows_the_burst_then_the_recharge() -> void:
	var wind := SecondWind.new(SETTINGS)
	var bar := SecondWindBar.new(wind)
	add_child_autofree(bar)
	bar._process(0.0)
	assert_eq(bar.get_fill(), 1.0, "ready")
	wind.start()
	wind.update(1.0)
	bar._process(0.0)
	assert_almost_eq(bar.get_fill(), 0.5, 0.01, "half the burst left")
	wind.update(29.0)  # 30 s since it started.
	bar._process(0.0)
	assert_almost_eq(bar.get_fill(), 0.5, 0.01, "half recharged")
