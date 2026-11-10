extends GutTest
## Ambient sounds of the cité des Tilleuls (spec S-006, T-050).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const ORIGIN := Vector3(110, 0, 110)

var _map: Node3D
var _ambience: Node3D


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_ambience = _map.get_node("Ambience")


func _plan(at: Vector3) -> Vector2:
	return Vector2(at.x + ORIGIN.x, at.z + ORIGIN.z)


func test_wind_motorway_and_swing_loop_forever() -> void:
	var wind: AudioStreamPlayer = _ambience.get_node("Wind")
	assert_true(wind.autoplay)
	var loops := [wind]
	for i in 3:
		var road: AudioStreamPlayer3D = _ambience.get_node("Motorway%d" % (i + 1))
		assert_gt(_plan(road.global_position).x, 211.0, "behind the east fence")
		loops.append(road)
	var swing: AudioStreamPlayer3D = _ambience.get_node("SwingCreak")
	assert_lt(_plan(swing.global_position).distance_to(Vector2(61, 80.5)), 1.0)
	loops.append(swing)
	for player: Node in loops:
		var stream: AudioStreamWAV = player.stream
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, player.name)
		assert_true(player.autoplay, player.name)


func test_a_train_passes_along_the_embankment() -> void:
	var train: AmbientTrain = _ambience.get_node("Train")
	assert_eq((train.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_false(train.autoplay, "the first train waits")
	for end in [train.track_start, train.track_end]:
		var at := _plan(end)
		assert_almost_eq(at.y, 1.0, 0.01, "on the embankment")
		assert_true(at.x < 0.0 or at.x > 220.0, "starts and ends out of the map")
	train.start_pass()
	assert_true(train.playing)
	assert_eq(train.passes, 1)
	assert_between(train.min_wait, 30.0, train.max_wait)


func test_ambient_sounds_betray_nobody() -> void:
	var heard := []
	var listen := func(event: NoiseEvent) -> void: heard.append(event)
	NoiseBus.noise_emitted.connect(listen)
	var train: AmbientTrain = _ambience.get_node("Train")
	train.start_pass()
	await wait_physics_frames(30)
	NoiseBus.noise_emitted.disconnect(listen)
	for event: NoiseEvent in heard:
		assert_false(
			event.source != null and _ambience.is_ancestor_of(event.source),
			"no noise event from the ambience"
		)
	for player in _ambience.get_children():
		assert_true(player is AudioStreamPlayer or player is AudioStreamPlayer3D, player.name)
