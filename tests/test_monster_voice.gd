extends GutTest
## The monster's voice (spec S-012, T-145): its growl as it breaks into a run,
## its cry at a catch, its breath, the scan's drone and the lights' crackle.

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const BUILDING_SCENE := preload("res://game/entities/building/building.tscn")
const SETTINGS := preload("res://game/data/monster_settings.tres")
const AUDIO := preload("res://game/data/audio_settings.tres")
const OPEN_SPOT := Vector3(0, 0, -16)

var _heard: Array[NoiseEvent] = []


func before_each() -> void:
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func _of_type(type: NoiseEvent.Type) -> Array[NoiseEvent]:
	return _heard.filter(func(e: NoiseEvent) -> bool: return e.type == type)


## Walks `metres` at a pace, one stride per frame of `delta` seconds.
func _walk(noise: MonsterNoise, pace: MonsterBrain.Pace, metres: float, delta := 0.2) -> void:
	var walked := 0.0
	while walked < metres:
		noise.update(delta, SETTINGS.stride, pace, Vector3.ZERO, Vector3.UP, null)
		walked += SETTINGS.stride


func test_the_new_noises_come_last_so_online_numbers_stay() -> void:
	assert_eq(NoiseEvent.Type.GROWL, NoiseEvent.Type.ROLL + 1)
	assert_eq(NoiseEvent.Type.SCREAM, NoiseEvent.Type.ROLL + 2)
	assert_eq(NoiseEvent.Type.FIRECRACKER, NoiseEvent.Type.SCREAM + 1)  # S-020, T-312.
	assert_eq(NoiseEvent.Type.size(), NoiseEvent.Type.FIRECRACKER + 1)


func test_it_growls_when_it_breaks_into_a_run_after_a_rest() -> void:
	var noise := MonsterNoise.new(SETTINGS)
	_walk(noise, MonsterBrain.Pace.RUN, 10.0)
	assert_eq(_of_type(NoiseEvent.Type.GROWL).size(), 1, "only the first running step")
	assert_eq(_of_type(NoiseEvent.Type.GROWL)[0].noise_range, SETTINGS.growl_range)
	_walk(noise, MonsterBrain.Pace.WALK, 3.0, SETTINGS.growl_rest)
	assert_eq(_of_type(NoiseEvent.Type.GROWL).size(), 1, "walking never growls")
	_walk(noise, MonsterBrain.Pace.RUN, 2.0)
	assert_eq(_of_type(NoiseEvent.Type.GROWL).size(), 2, "a new run after a rest")


func test_a_short_pause_does_not_growl_again() -> void:
	var noise := MonsterNoise.new(SETTINGS)
	_walk(noise, MonsterBrain.Pace.RUN, 3.0)
	noise.update(
		SETTINGS.growl_rest * 0.5, 0.0, MonsterBrain.Pace.WALK, Vector3.ZERO, Vector3.UP, null
	)
	_walk(noise, MonsterBrain.Pace.RUN, 3.0)
	assert_eq(_of_type(NoiseEvent.Type.GROWL).size(), 1)


func test_the_ai_monster_screams_when_it_catches() -> void:
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(2)
	var monster: Monster = map.get_node("Monster")
	var player: Player = map.get_node("Player")
	monster.set_physics_process(false)
	player.global_position = OPEN_SPOT + Vector3(0.5, 0, 0)
	monster.global_position = OPEN_SPOT
	monster.look_at(player.global_position, Vector3.UP)
	_heard.clear()
	monster.set_physics_process(true)
	await wait_physics_frames(3)
	var screams := _of_type(NoiseEvent.Type.SCREAM)
	assert_gt(screams.size(), 0, "a cry at the catch")
	if screams.is_empty():
		return
	assert_eq(screams[0].noise_range, SETTINGS.scream_range)
	assert_true(screams[0].by_monster)
	assert_eq(screams[0].source, monster)


func test_its_breath_growl_and_cry_are_its_voice() -> void:
	for type in [NoiseEvent.Type.BREATH, NoiseEvent.Type.GROWL, NoiseEvent.Type.SCREAM]:
		var event := NoiseEvent.new(type, Vector3.ZERO, 5.0)
		assert_false(PlayerEars.is_voice(event), "not by the monster")
		event.by_monster = true
		assert_true(PlayerEars.is_voice(event))
	var step := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, 5.0)
	step.by_monster = true
	assert_false(PlayerEars.is_voice(step), "its steps are not its voice")


func test_the_voice_bus_goes_into_the_effects() -> void:
	var index := AudioServer.get_bus_index(PlayerEars.VOICE_BUS)
	assert_gt(index, 0, "declared in default_bus_layout.tres")
	assert_eq(AudioServer.get_bus_send(index), PlayerEars.EFFECTS_BUS)


func test_the_ears_play_its_voice_on_the_voice_bus() -> void:
	var listener := Node3D.new()
	var ears := PlayerEars.new()
	listener.add_child(ears)
	add_child_autofree(listener)
	var breath := NoiseEvent.new(NoiseEvent.Type.BREATH, Vector3.ZERO, 2.0)
	assert_eq(ears.call("_stream_for", breath), PlayerEars.SOUND_BREATH, "a hunted's breath")
	breath.by_monster = true
	assert_eq(ears.call("_stream_for", breath), PlayerEars.SOUND_MONSTER_BREATH)
	var scream := NoiseEvent.new(NoiseEvent.Type.SCREAM, Vector3.ZERO, 30.0)
	assert_eq(ears.call("_stream_for", scream), PlayerEars.SOUND_SCREAM)
	var growl := NoiseEvent.new(NoiseEvent.Type.GROWL, Vector3.ZERO, 12.0)
	var last: AudioStream = null
	for i in 12:
		var stream: AudioStream = ears.call("_stream_for", growl)
		assert_true(stream in PlayerEars.SOUND_GROWLS)
		assert_ne(stream, last, "never the same growl twice in a row")
		last = stream


func test_the_scan_drone_swells_with_the_concentration() -> void:
	var gauge := ScanGauge.new(SETTINGS)
	assert_eq(gauge.get_focus_ratio(), 0.0)
	var drone := ScanDrone.new(gauge)
	add_child_autofree(drone)
	drone._process(0.1)
	assert_false(drone.playing, "silent without a scan")
	assert_true(gauge.start())
	gauge.update(SETTINGS.scan_focus_time * 0.5)
	assert_almost_eq(gauge.get_focus_ratio(), 0.5, 0.01)
	drone._process(0.1)
	assert_true(drone.playing)
	var half := drone.volume_db
	gauge.update(SETTINGS.scan_focus_time)
	drone._process(0.1)
	assert_eq(gauge.get_focus_ratio(), 1.0)
	assert_gt(drone.volume_db, half, "louder once it listens")
	assert_almost_eq(drone.volume_db, AUDIO.drone_db, 0.01)
	assert_gt(drone.pitch_scale, 1.0)
	assert_eq(drone.bus, PlayerEars.VOICE_BUS)
	gauge.stop()
	drone._process(0.1)
	assert_false(drone.playing)


func test_a_scanned_buildings_lights_crackle() -> void:
	var building: Building = BUILDING_SCENE.instantiate()
	building.settings = SETTINGS
	var light := OmniLight3D.new()
	light.position = Vector3(2, 3, 0)
	building.add_child(light)
	add_child_autofree(building)
	building.scanned = true
	var crackle: AudioStreamPlayer3D = building.get_node("Crackle")
	assert_true(crackle.playing)
	assert_eq(crackle.position, light.position, "by its lights")
	assert_eq(crackle.bus, &"Ambiance")
	building.scanned = false
	assert_false(crackle.playing)
