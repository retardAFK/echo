extends GutTest
## The sounds of the hospital (spec S-014, T-191, tools/audio/hospital_sounds.py).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const NEON_SCENE := preload("res://game/entities/neon/neon_tube.tscn")
const ORIGIN := Vector3(110, 0, 110)

var _map: GameMap
var _heard: Array[NoiseEvent] = []


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func test_the_ears_know_the_monitor_and_the_casters() -> void:
	var ears: PlayerEars = _map.get_node("Player").find_children("*", "PlayerEars", true, false)[0]
	var sounds: Dictionary = ears.get("_sounds")
	assert_eq(sounds[NoiseEvent.Type.MONITOR], PlayerEars.SOUND_MONITOR)
	assert_eq(sounds[NoiseEvent.Type.ROLL], PlayerEars.SOUND_ROLL)


func test_a_shoved_gurney_crashes_by_itself() -> void:
	var gurney: Gurney = _map.get_node("Rolling/Gurney1")
	var monster: Monster = _map.get_node("Monster")
	gurney.shove(monster)
	var shoves := _heard.filter(func(e: NoiseEvent) -> bool: return e.source == monster)
	assert_eq(shoves.size(), 1)
	assert_eq(shoves[0].type, NoiseEvent.Type.IMPACT, "self voiced")
	assert_true(NoiseEvent.Type.IMPACT in PlayerEars.SELF_VOICED)
	assert_true((gurney.get_node("Crash") as AudioStreamPlayer3D).playing)


func test_a_dead_tube_falls_silent() -> void:
	var neon: NeonTube = NEON_SCENE.instantiate()
	add_child_autofree(neon)
	neon.set_process(false)
	var buzz: AudioStreamPlayer3D = neon.get_node("Buzz")
	await wait_process_frames(2)
	assert_true(buzz.playing, "lit, it buzzes")
	while neon.lit:
		neon.step(0.05)
	assert_false(buzz.playing)


func test_the_ventilation_roars_and_the_morgue_drips() -> void:
	for zone in _map.get_node("Ventilation").get_children():
		var roar: AudioStreamPlayer3D = zone.get_node("Roar")
		assert_true(roar.autoplay, zone.name)
		assert_true(roar.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "a loop")
	assert_eq(_map.get_node("HospitalSounds").find_children("Drip*").size(), 2)


func test_far_off_noises_play_down_the_corridor_inside_the_hospital() -> void:
	var distant: DistantSounds = _map.get_node("HospitalSounds/Distant")
	var from := Vector3(21, 1.5, 70) - ORIGIN
	assert_true(distant.contains(from))
	for i in 10:
		var at := distant.play_near(from)
		assert_true(distant.contains(at), "inside")
		assert_gt(at.distance_to(from), 10.0, "far off")
	assert_false(distant.contains(Vector3(60, 1.5, 70) - ORIGIN), "outside")
