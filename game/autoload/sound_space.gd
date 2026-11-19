extends Node
## Plays the game's noises in 3D the way the noise system hears them (spec
## S-012, T-142). Every game sound played by an AudioStreamPlayer3D goes
## through play(): its volume follows the distance to the listener (the
## current camera) against the player's max_distance, walls muffle it (its
## _muffled version, made by tools/audio/muffle.py) and quiet it, and it is a
## little duller behind. Ambience loops do not come here: they betray nobody.

var settings: AudioSettings = preload("res://game/data/audio_settings.tres")

## Clean stream -> its muffled version, or null when it has none.
var _muffled := {}
## Muffled stream -> its clean version.
var _clean := {}
var _tracked: Array[AudioStreamPlayer3D] = []
var _track_left := 0.0


## Plays a game sound from where its player stands, as heard by the camera.
## A sound out of reach (beyond its range, or behind too many walls) plays
## silent: a long one comes up if the listener comes near. Returns the volume
## applied, SoundMath.SILENT_DB when out of reach.
func play(player: AudioStreamPlayer3D, from_position := 0.0) -> float:
	if player == null or not player.is_inside_tree():
		return SoundMath.SILENT_DB
	if not player.has_meta(&"base_db"):
		player.set_meta(&"base_db", player.volume_db)
	player.stream = clean_stream(player.stream)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	if player.max_distance > 0.0:
		# Our curve, not Godot's: its own fade towards max_distance still cut
		# the sounds in the browser (T-147). The range is kept aside.
		player.set_meta(&"noise_range", player.max_distance)
		player.max_distance = 0.0
	var camera := player.get_viewport().get_camera_3d()
	if camera == null:
		player.play(from_position)  # No listener (a room on a server): nothing to shape.
		return 0.0
	var walls := walls_to(player.global_position, camera.global_position)
	var db := _gain(player, camera, walls)
	if walls > 0:
		var muffled := muffled_stream(player.stream)
		if muffled != null:
			player.stream = muffled
	player.volume_db = float(player.get_meta(&"base_db")) + db
	player.play(from_position)
	if not _tracked.has(player):
		_tracked.append(player)
	return db


## Range of a player's sound: its max_distance (kept aside by play()), or the
## default.
func range_of(player: AudioStreamPlayer3D) -> float:
	if player.max_distance > 0.0:
		return player.max_distance
	return float(player.get_meta(&"noise_range", settings.default_range))


## Walls between a sound and the listener, as NoiseBus counts them, except a
## wall right at the sound: the door or the shutter that makes it.
func walls_to(from: Vector3, to: Vector3) -> int:
	var margin := settings.own_wall_margin
	var length := from.distance_to(to)
	if length <= margin:
		return 0
	var start := from + (to - from) / length * margin
	return NoiseBus.walls_between(start, to)


## The muffled version of a stream, or null.
func muffled_stream(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	if _muffled.has(stream):
		return _muffled[stream]
	var path := SoundMath.muffled_path(stream.resource_path)
	var muffled: AudioStream = null
	if not path.is_empty() and ResourceLoader.exists(path):
		muffled = load(path)
		_clean[muffled] = stream
	_muffled[stream] = muffled
	return muffled


## The clean version of a stream that may be muffled.
func clean_stream(stream: AudioStream) -> AudioStream:
	return _clean.get(stream, stream)


func _process(delta: float) -> void:
	if _tracked.is_empty():
		return
	_track_left -= delta
	if _track_left > 0.0:
		return
	_track_left = settings.track_interval
	var camera := get_viewport().get_camera_3d()
	for i in range(_tracked.size() - 1, -1, -1):
		var player := _tracked[i]
		if not is_instance_valid(player) or not player.playing or not player.is_inside_tree():
			_tracked.remove_at(i)
			continue
		if camera == null:
			continue
		var walls := walls_to(player.global_position, camera.global_position)
		var db := _gain(player, camera, walls)
		player.volume_db = float(player.get_meta(&"base_db")) + maxf(db, SoundMath.SILENT_DB)


func _gain(player: AudioStreamPlayer3D, camera: Camera3D, walls: int) -> float:
	var to_sound := player.global_position - camera.global_position
	return SoundMath.gain_db(
		to_sound.length(),
		range_of(player),
		walls,
		to_sound,
		-camera.global_basis.z,
		settings,
		NoiseBus.settings
	)
