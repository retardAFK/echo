class_name PlayerEars
extends Node3D
## What the player hears (spec S-003, D-009): every noise made by someone else
## that NoiseBus says reaches the player's ears is played where it happened.
## Beyond its range, walls included, a noise stays silent. The parent is the
## listener: the hunted Player or the playable monster (S-004), anything with
## get_eye_position().

const VOICES := 4
## Noises whose maker plays its own sound where it is (S-007): the fuse boxes,
## the transformer and its siren, a breaking bottle and a ringing alarm clock, a
## hiding spot's door (S-008), a door (S-016), a cage, a terminal's keyboard,
## a smashed camera, a loudspeaker, a shutter, a relay switch (S-018). The
## ears add nothing.
const SELF_VOICED := [
	NoiseEvent.Type.FUSE,
	NoiseEvent.Type.REPAIR,
	NoiseEvent.Type.SIREN,
	NoiseEvent.Type.IMPACT,
	NoiseEvent.Type.DECOY,
	NoiseEvent.Type.HIDE,
	NoiseEvent.Type.DOOR,
	NoiseEvent.Type.CAGE,
	NoiseEvent.Type.KEYBOARD,
	NoiseEvent.Type.CAMERA,
	NoiseEvent.Type.SPEAKER,
	NoiseEvent.Type.SHUTTER,
	NoiseEvent.Type.SWITCH,
]
## The prison's bell (S-018, Q4), played where it rings.
const SOUND_BELL := preload("res://assets/audio/network/prison_bell.wav")
const SOUND_DISK := preload("res://assets/audio/network/hard_disk.wav")
const SOUND_BEEP := preload("res://assets/audio/network/keypad_beep.wav")

var heard_count := 0

var _sounds := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0

@onready var _listener: Node3D = get_parent()


func _ready() -> void:
	_sounds[NoiseEvent.Type.FOOTSTEP] = PlaceholderSounds.step()
	_sounds[NoiseEvent.Type.BREATH] = PlaceholderSounds.breath()
	_sounds[NoiseEvent.Type.CAR_ALARM] = PlaceholderSounds.alarm()
	_sounds[NoiseEvent.Type.CALL] = PlaceholderSounds.call_for_help()
	_sounds[NoiseEvent.Type.RESCUE] = PlaceholderSounds.rescue()
	_sounds[NoiseEvent.Type.BELL] = SOUND_BELL
	_sounds[NoiseEvent.Type.DISK] = SOUND_DISK
	_sounds[NoiseEvent.Type.BEEP] = SOUND_BEEP
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.top_level = true
		add_child(voice)
		_voices.append(voice)
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if event.source == _listener or event.noise_range <= 0.0 or not is_inside_tree():
		return
	if event.type in SELF_VOICED:
		return
	if not NoiseBus.can_hear(event, _listener.get_eye_position()):
		return
	heard_count += 1
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _sounds.get(event.type, _sounds[NoiseEvent.Type.FOOTSTEP])
	voice.max_distance = event.noise_range
	voice.global_position = event.position
	voice.play()
