class_name ScanDrone
extends AudioStreamPlayer
## The drone in the monster's head while it scans (spec S-012, Q7): it swells
## and rises with the concentration, and only the monster hears it.

const SOUND := preload("res://assets/audio/voices/scan_drone.wav")

var gauge: ScanGauge
var audio: AudioSettings = preload("res://game/data/audio_settings.tres")


func _init(p_gauge: ScanGauge = null) -> void:
	gauge = p_gauge
	name = "ScanDrone"
	stream = SOUND
	bus = &"Voix"


func _process(_delta: float) -> void:
	var level := gauge.get_focus_ratio() if gauge != null else 0.0
	if level <= 0.0:
		if playing:
			stop()
		return
	volume_db = volume_for(level, audio)
	pitch_scale = 1.0 + audio.drone_pitch_rise * level
	if not playing:
		play()


## Volume of the drone for a concentration from 0 to 1.
static func volume_for(level: float, p_audio: AudioSettings) -> float:
	return lerpf(p_audio.drone_min_db, p_audio.drone_db, clampf(level, 0.0, 1.0))
