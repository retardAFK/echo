class_name CityWind
extends AudioStreamPlayer
## The wind of the cité (spec S-012, T-144, section 6.4): a loop that swells
## and whistles during the gusts (WindGusts), duller indoors. While a gust
## blows at full strength, NoiseBus cuts the small noises outdoors.
## Online, the room sends its seed and time to every client once a second
## (NetWorld.clock, S-020, T-300): the client draws the same gusts and blows
## them on its own clock, so the gusts blow at the same time for everyone.
## Plain ambience: it betrays nobody.

const WHISTLE := preload("res://assets/audio/ambience/gust.wav")

## Seed of the gusts; 0 draws one.
@export var gust_seed := 0

var audio: AudioSettings = preload("res://game/data/audio_settings.tres")
## 0 calm, 1 a full gust.
var strength := 0.0
var time := 0.0

var gusts: WindGusts
## The seed the gusts were drawn from.
var seed_used := 0
var _base_db := 0.0
var _whistle: AudioStreamPlayer


func _ready() -> void:
	seed_used = gust_seed if gust_seed != 0 else randi()
	gusts = WindGusts.new(seed_used, audio)
	_base_db = volume_db
	_whistle = AudioStreamPlayer.new()
	_whistle.name = "Whistle"
	_whistle.stream = WHISTLE
	_whistle.volume_db = SoundMath.SILENT_DB
	_whistle.bus = bus
	add_child(_whistle)


func _exit_tree() -> void:
	NoiseBus.wind_gust = false


func _process(delta: float) -> void:
	time += delta
	strength = gusts.strength(time)
	NoiseBus.wind_gust = strength >= 1.0
	var camera := get_viewport().get_camera_3d()
	var indoors := camera != null and Building.any_contains(get_tree(), camera.global_position)
	volume_db = _base_db + audio.gust_db * strength + (audio.indoor_wind_db if indoors else 0.0)
	if strength > 0.0:
		if not _whistle.playing and is_inside_tree():
			_whistle.play()
		var whistle_db := audio.whistle_db + (audio.indoor_wind_db if indoors else 0.0)
		_whistle.volume_db = lerpf(SoundMath.SILENT_DB / 2.0, whistle_db, sqrt(strength))
	elif _whistle.playing:
		_whistle.stop()


## Online client: the room's gusts, from their seed, at the room's time.
func sync(room_seed: int, room_time: float) -> void:
	if room_seed != seed_used:
		seed_used = room_seed
		gusts = WindGusts.new(room_seed, audio)
	time = room_time
	strength = gusts.strength(time)
