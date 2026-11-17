class_name Loudspeaker
extends Node3D
## A loudspeaker of the cité's network (spec S-018, Q11): set off from a
## terminal, it blares for speaker_time, a SPEAKER noise of speaker_range
## every speaker_interval, once per game. The monster hears it like any
## noise: a decoy far from the one at the terminal.

const GROUP := &"loudspeakers"
const SOUND := preload("res://assets/audio/network/loudspeaker.wav")

@export var settings: NetworkSettings
## Its name in the terminals' menus, a translation key.
@export var label_key := ""

## Set off already: it does not sound twice.
var used := false
## Seconds it still sounds.
var sounding_left := 0.0
## Online client: the room decides.
var mirror := false

var _next_noise := 0.0

@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	add_to_group(GROUP)
	_sound.stream = SOUND
	DrawRange.limit(self, DrawRange.INDOOR)


func is_sounding() -> bool:
	return sounding_left > 0.0


## Set off from a terminal: true if it was still unused.
func trigger() -> bool:
	if used:
		return false
	used = true
	sounding_left = settings.speaker_time
	_next_noise = 0.0
	return true


func _physics_process(delta: float) -> void:
	if mirror or sounding_left <= 0.0:
		return
	_next_noise -= delta
	if _next_noise <= 0.0:
		_next_noise = settings.speaker_interval
		SoundSpace.play(_sound)
		NoiseBus.emit_noise(NoiseEvent.Type.SPEAKER, global_position, settings.speaker_range, self)
	sounding_left = maxf(sounding_left - delta, 0.0)


## Online client: what the room says of it.
func mirror_state(is_used: bool) -> void:
	used = is_used


## Online client: its blare heard from the room.
func voice() -> void:
	SoundSpace.play(_sound)
