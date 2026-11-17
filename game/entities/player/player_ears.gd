class_name PlayerEars
extends Node3D
## What the player hears (spec S-003, D-009): every noise made by someone else
## that NoiseBus says reaches the player's ears is played where it happened.
## Beyond its range, walls included, a noise stays silent. The parent is the
## listener: the hunted Player or the playable monster (S-004), anything with
## get_eye_position(). How loud and how muffled each one sounds is SoundSpace's
## rule (S-012, T-142).

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
## The hospital (S-014, T-191): a monitor's alarm, casters rolling.
const SOUND_MONITOR := preload("res://assets/audio/hospital/monitor_beep.wav")
const SOUND_ROLL := preload("res://assets/audio/hospital/roll.wav")

var heard_count := 0
var audio: AudioSettings = preload("res://game/data/audio_settings.tres")

var _sounds := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _steps := FootstepSounds.new()
## One's own footsteps and breath, without a position (S-012, Q5).
var _own_step: AudioStreamPlayer
var _own_breath: AudioStreamPlayer

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
	_sounds[NoiseEvent.Type.MONITOR] = SOUND_MONITOR
	_sounds[NoiseEvent.Type.ROLL] = SOUND_ROLL
	_own_step = AudioStreamPlayer.new()
	_own_step.name = "OwnStep"
	add_child(_own_step)
	_own_breath = AudioStreamPlayer.new()
	_own_breath.name = "OwnBreath"
	add_child(_own_breath)
	for i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.top_level = true
		add_child(voice)
		_voices.append(voice)
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if event.noise_range <= 0.0 or not is_inside_tree():
		return
	if event.source == _listener:
		_play_own(event)
		return
	if event.type in SELF_VOICED:
		return
	if event.masked and Door.is_monster(_listener):
		return  # Lost in the roar of a ventilation zone (S-014, Q5).
	if not NoiseBus.can_hear(event, _listener.get_eye_position()):
		return
	heard_count += 1
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _stream_for(event)
	voice.pitch_scale = _steps.pitch() if event.type == NoiseEvent.Type.FOOTSTEP else 1.0
	voice.max_distance = event.noise_range
	voice.global_position = event.position
	SoundSpace.play(voice)  # Distance, walls and direction (S-012, T-142).


## The sound of a noise made by someone else: a footstep sounds of the floor
## it was made on, or of the monster's scrape (S-012, T-143).
func _stream_for(event: NoiseEvent) -> AudioStream:
	if event.type == NoiseEvent.Type.FOOTSTEP:
		if event.by_monster:
			return _steps.monster_step()
		return _steps.step(FloorSurface.at(get_tree(), event.position))
	return _sounds.get(event.type, _sounds[NoiseEvent.Type.FOOTSTEP])


## One's own footstep or breath, softly, in the middle of the head (Q5).
func _play_own(event: NoiseEvent) -> void:
	var voice: AudioStreamPlayer
	match event.type:
		NoiseEvent.Type.FOOTSTEP:
			voice = _own_step
			if event.by_monster:
				voice.stream = _steps.monster_step()
			else:
				voice.stream = _steps.step(FloorSurface.at(get_tree(), event.position))
			voice.pitch_scale = _steps.pitch()
		NoiseEvent.Type.BREATH:
			voice = _own_breath
			voice.stream = _sounds[NoiseEvent.Type.BREATH]
		_:
			return
	voice.volume_db = SoundMath.self_db(event.noise_range, NoiseBus.settings.walk_range, audio)
	voice.play()
