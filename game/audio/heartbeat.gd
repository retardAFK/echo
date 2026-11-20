class_name Heartbeat
extends AudioStreamPlayer
## The hunted's heart in a hiding spot (spec S-020, T-327, piste H3): one
## "lub-dub" again and again, faster as the monster comes near, so that the
## one hidden feels it coming. TensionMusic owns it and gives it, every frame,
## whether the listener hides and how far the monster is (it has that
## distance already for the music). On the Effets bus: the danger duck of
## T-326 does not lower it.

const SOUND := preload("res://assets/audio/music/heartbeat.wav")

var audio: AudioSettings = preload("res://game/data/audio_settings.tres")
## Beats played since the start (tests).
var beats := 0

var _left := 0.0


func _ready() -> void:
	name = "Heartbeat"
	stream = SOUND
	bus = &"Effets"
	volume_db = audio.heart_db


## One frame: beats while hidden, at the pace the monster's distance asks for
## (-1: no monster).
func update(delta: float, hidden: bool, distance: float) -> void:
	if not hidden:
		_left = audio.heart_first_delay
		return
	_left -= delta
	if _left > 0.0:
		return
	_left += interval(distance, audio)
	beats += 1
	if is_inside_tree():
		play()


## Seconds between two beats: heart_slow_interval with the monster at
## heart_far or more (or none), heart_fast_interval at heart_near or less.
static func interval(distance: float, p_audio: AudioSettings) -> float:
	if distance < 0.0:
		return p_audio.heart_slow_interval
	var t := clampf(
		(p_audio.heart_far - distance) / maxf(p_audio.heart_far - p_audio.heart_near, 0.01),
		0.0,
		1.0
	)
	return lerpf(p_audio.heart_slow_interval, p_audio.heart_fast_interval, t)
