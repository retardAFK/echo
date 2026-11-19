extends GutTest
## How game sounds are heard (spec S-012, T-142): distance, walls, direction.

const GLASS := preload("res://assets/audio/ruses/glass_break.wav")
const WALLS_LAYER := 1 << 1

var _audio := AudioSettings.new()
var _noise: NoiseSettings = preload("res://game/data/noise_settings.tres")
var _camera: Camera3D


func before_each() -> void:
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_camera.make_current()  # At the origin, looking down -Z.


func _player(at: Vector3, distance := 14.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = GLASS
	player.max_distance = distance
	player.volume_db = -2.0
	add_child_autofree(player)
	player.global_position = at
	return player


func _wall(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WALLS_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.2)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = at


func test_louder_near_than_far() -> void:
	var near := SoundMath.distance_db(3.0, 14.0, _audio)
	var far := SoundMath.distance_db(12.0, 14.0, _audio)
	assert_almost_eq(SoundMath.distance_db(0.0, 14.0, _audio), 0.0, 0.01)
	assert_gt(near, far + 10.0)
	assert_almost_eq(SoundMath.distance_db(14.0, 14.0, _audio), _audio.edge_db, 0.01)
	assert_eq(SoundMath.distance_db(14.5, 14.0, _audio), SoundMath.SILENT_DB, "beyond its range")


func test_walls_follow_the_noise_bus_rule() -> void:
	var open := SoundMath.gain_db(5.0, 14.0, 0, Vector3.FORWARD, Vector3.FORWARD, _audio, _noise)
	var one := SoundMath.gain_db(5.0, 14.0, 1, Vector3.FORWARD, Vector3.FORWARD, _audio, _noise)
	var three := SoundMath.gain_db(5.0, 14.0, 3, Vector3.FORWARD, Vector3.FORWARD, _audio, _noise)
	assert_lt(one, open + _audio.wall_db, "quieter by more than a wall: its range halves too")
	assert_eq(three, SoundMath.SILENT_DB, "14 m / 8 < 5 m: not heard, as in the spec")


func test_duller_behind_than_in_front() -> void:
	assert_eq(SoundMath.behind_db(Vector3.FORWARD, Vector3.FORWARD, _audio), 0.0)
	assert_eq(SoundMath.behind_db(Vector3.LEFT, Vector3.FORWARD, _audio), 0.0, "to the side")
	var behind := SoundMath.behind_db(Vector3.BACK, Vector3.FORWARD, _audio)
	assert_almost_eq(behind, _audio.behind_db, 0.01)


func test_muffled_path() -> void:
	assert_eq(SoundMath.muffled_path("res://a/glass.wav"), "res://a/glass_muffled.wav")
	assert_eq(SoundMath.muffled_path(""), "")


func test_a_sound_in_the_open_plays_clean() -> void:
	var player := _player(Vector3(0, 0, -5))
	var db := SoundSpace.play(player)
	assert_true(player.playing)
	assert_eq(player.stream, GLASS)
	assert_almost_eq(player.volume_db, -2.0 + db, 0.01, "its own level kept")
	assert_eq(player.attenuation_model, AudioStreamPlayer3D.ATTENUATION_DISABLED)


func test_a_sound_behind_a_wall_is_muffled_and_quieter() -> void:
	var open := SoundSpace.play(_player(Vector3(0, 0, -5)))
	_wall(Vector3(0, 0, -2.5))
	await wait_physics_frames(2)
	var player := _player(Vector3(0, 0, -5))
	var behind_wall := SoundSpace.play(player)
	assert_lt(behind_wall, open + _audio.wall_db)
	assert_eq(player.stream.resource_path, SoundMath.muffled_path(GLASS.resource_path))
	player.stop()
	_camera.global_position = Vector3(0, 0, -4)
	SoundSpace.play(player)
	assert_eq(player.stream, GLASS, "clean again on the same side")


func test_the_wall_a_sound_comes_from_does_not_muffle_it() -> void:
	_wall(Vector3(0, 0, -5))  # A door: its sound starts in it.
	await wait_physics_frames(2)
	var player := _player(Vector3(0, 0, -5))
	SoundSpace.play(player)
	assert_eq(player.stream, GLASS)


func test_out_of_reach_plays_silent() -> void:
	var player := _player(Vector3(0, 0, -30))
	assert_eq(SoundSpace.play(player), SoundMath.SILENT_DB)
	assert_true(player.playing, "still going: a long sound comes up when one comes near")
	assert_lt(player.volume_db, -70.0)


func test_every_game_sound_has_its_muffled_version() -> void:
	var sounds := [GLASS, preload("res://assets/audio/interiors/door_open.wav")]
	for stream: AudioStream in sounds:
		assert_not_null(SoundSpace.muffled_stream(stream), stream.resource_path)
