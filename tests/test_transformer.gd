extends GutTest
## Transformer, siren and exit of the game loop (spec S-007, T-055).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")

var _map: GameMap
var _loop: GameLoop
var _transformer: Transformer
var _player: Player
var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_loop = _map.game_loop
	_transformer = _map.get_node("TransformerPanel")
	_player = _map.get_node("Player")
	_map.get_node("Monster").player = null  # Leave the hunted alone.


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	# A won game pauses the tree behind its end screen: the next suites would
	# wait for frames that never come (test_vault.gd hung there, T-340).
	get_tree().paused = false


func _record(event: NoiseEvent) -> void:
	if event.type in [NoiseEvent.Type.REPAIR, NoiseEvent.Type.SIREN]:
		_noises.append(event)


func _of_type(type: NoiseEvent.Type) -> Array[NoiseEvent]:
	return _noises.filter(func(event: NoiseEvent) -> bool: return event.type == type)


func _take_all_fuses() -> void:
	for box: FuseBox in _loop.fused_boxes:
		box.hold(_player, _loop.settings.pickup_time + 0.1)
	assert_eq(_loop.rules.carried, 3)


## Where the hunted stands to repair: 1 m south of the transformer.
func _beside() -> Vector3:
	return _transformer.global_position + Vector3(0, 0, _transformer.half_size.y + 1.0)


func test_the_transformer_waits_for_fuses_and_says_so() -> void:
	var label: Label3D = _transformer.get_node("WaitLabel")
	assert_true(label.visible)
	assert_string_contains(label.text, "3")
	assert_false(_transformer.can_interact(_beside()), "nothing to place yet")
	_take_all_fuses()
	assert_true(_transformer.can_interact(_beside()))
	assert_false(_transformer.can_interact(_beside() + Vector3(0, 0, 2.0)), "too far")
	assert_eq(_transformer.get_prompt(), "HUD_INTERACT_TRANSFORMER")


func test_each_fuse_takes_four_seconds_and_makes_noise() -> void:
	_take_all_fuses()
	var step := 0.1
	for i in 39:
		_transformer.hold(_player, step)
	assert_eq(_loop.rules.placed, 0, "not yet after 3.9 s")
	_transformer.hold(_player, 0.15)
	assert_eq(_loop.rules.placed, 1)
	assert_eq(_loop.rules.carried, 2)
	var repairs := _of_type(NoiseEvent.Type.REPAIR)
	assert_eq(repairs.size(), 3, "at 0, 1.5 and 3 s")
	assert_eq(repairs[0].noise_range, 8.0)
	assert_eq(repairs[0].source, _player, "counted as the hunted's noise")
	assert_string_contains(_transformer.get_node("WaitLabel").text, "2")


func test_letting_go_keeps_half_of_the_fuse_in_progress() -> void:
	_take_all_fuses()
	_transformer.hold(_player, 3.0)
	_transformer.release(_player)
	assert_almost_eq(_transformer.get_hold_ratio(), 1.5 / 4.0, 0.001)
	_transformer.hold(_player, 2.4)
	assert_eq(_loop.rules.placed, 0)
	_transformer.hold(_player, 0.2)
	assert_eq(_loop.rules.placed, 1, "1.5 + 2.6 s")


func test_three_fuses_sound_the_siren_and_open_the_exit() -> void:
	var monster: Monster = _map.get_node("Monster")
	var gate: ExitGate = _map.get_node("ExitGate")
	var closed_y := gate.position.y
	watch_signals(_loop)
	_take_all_fuses()
	for i in 3:
		_transformer.hold(_player, 4.1)
	assert_true(_loop.is_exit_open())
	assert_signal_emitted(_loop, "exit_opened")
	assert_false(_transformer.get_node("WaitLabel").visible)
	assert_eq(_transformer.get_prompt(), "", "nothing more to place")
	await wait_physics_frames(3)
	var sirens := _of_type(NoiseEvent.Type.SIREN)
	assert_eq(sirens.size(), 1)
	assert_true(NoiseBus.can_hear(sirens[0], monster.get_ear_position()), "the monster hears it")
	assert_eq(monster.get_state(), MonsterBrain.State.GUARD, "it leaves to guard the tunnel")
	var tunnel: Vector3 = _map.get_node("GuardPoints").get_child(0).global_position
	assert_lt(monster.brain.target.distance_to(tunnel), 0.5)
	await wait_seconds(_loop.settings.gate_open_time + 0.3)
	assert_almost_eq(gate.position.y, closed_y + 3.6, 0.01, "the grille is up")
	assert_between(_of_type(NoiseEvent.Type.SIREN).size(), 2, 4, "a siren every 2 s")


func test_the_siren_reaches_every_corner_of_the_cite() -> void:
	var event := NoiseEvent.new(
		NoiseEvent.Type.SIREN, _transformer.global_position, _loop.settings.siren_range
	)
	var settings: NoiseSettings = NoiseBus.settings
	for corner: Vector3 in [Vector3(-110, 1, -110), Vector3(110, 1, -110), Vector3(110, 1, 110)]:
		var walls_max := settings.max_walls_counted
		assert_true(
			NoiseMath.is_heard(
				event.noise_range, corner.distance_to(event.position), walls_max, settings
			),
			"heard at %s even behind %d walls" % [corner, walls_max]
		)


func test_the_grille_blocks_the_tunnel_until_it_rises() -> void:
	await wait_physics_frames(2)
	var space := _map.get_world_3d().direct_space_state
	var gate: ExitGate = _map.get_node("ExitGate")
	var south := gate.global_position + Vector3(0, 1, 2)
	var north := gate.global_position + Vector3(0, 1, -2)
	var ray := PhysicsRayQueryParameters3D.create(south, north)
	assert_false(space.intersect_ray(ray).is_empty(), "closed")
	gate.open()
	await wait_seconds(_loop.settings.gate_open_time + 0.3)
	assert_true(space.intersect_ray(ray).is_empty(), "open")


func test_the_hunted_wins_at_the_far_end_of_an_open_tunnel() -> void:
	watch_signals(_loop)
	var zone: ExitZone = _map.get_node("ExitZone")
	_player.global_position = zone.global_position + Vector3(0, -2.0, 0)
	await wait_physics_frames(3)
	assert_false(_loop.is_over, "the exit is still closed")
	_player.global_position = zone.global_position + Vector3(0, -2.0, 8)
	await wait_physics_frames(3)
	_take_all_fuses()
	for i in 3:
		_transformer.hold(_player, 4.1)
	_player.global_position = zone.global_position + Vector3(0, -2.0, 0)
	await wait_physics_frames(3)
	assert_true(_loop.is_over)
	assert_true(_loop.hunted_won)
	assert_signal_emitted_with_parameters(_loop, "ended", [true])
