class_name CityWind
extends AudioStreamPlayer
## The wind of the cité (spec S-012, T-144, section 6.4): a loop that swells
## and whistles during the gusts (WindGusts), duller indoors. While a gust
## blows at full strength, NoiseBus cuts the small noises outdoors.
## Online, the room's wind is sent to every client (NetWorld), so the gusts
## blow at the same time for everyone. Plain ambience: it betrays nobody.

const WHISTLE := preload("res://assets/audio/ambience/gust.wav")

## Seed of the gusts; 0 draws one.
@export var gust_seed := 0

var audio: AudioSettings = preload("res://game/data/audio_settings.tres")
## Online client: the strength comes from the room.
var mirror := false
## 0 calm, 1 a full gust.
var strength := 0.0
var time := 0.0

var gusts: WindGusts
var _base_db := 0.0
var _whistle: AudioStreamPlayer


func _ready() -> void:
	gusts = WindGusts.new(gust_seed if gust_seed != 0 else randi(), audio)
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
	if not mirror:
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


## Online client: the room's wind.
func mirror_strength(value: float) -> void:
	mirror = true
	strength = value


## Room side: the strength to send, in steps of a twentieth.
func shared_strength() -> float:
	return snappedf(strength, 0.05)
