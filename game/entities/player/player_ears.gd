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
## a smashed camera, a loudspeaker, a shutter, a relay switch (S-018), a
## firecracker and a can wire (S-020). The ears add nothing.
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
	NoiseEvent.Type.FIRECRACKER,
	NoiseEvent.Type.CANS,
]
## The prison's bell (S-018, Q4), played where it rings.
const SOUND_BELL := preload("res://assets/audio/network/prison_bell.wav")
const SOUND_DISK := preload("res://assets/audio/network/hard_disk.wav")
const SOUND_BEEP := preload("res://assets/audio/network/keypad_beep.wav")
## The hospital (S-014, T-191): a monitor's alarm, casters rolling.
const SOUND_MONITOR := preload("res://assets/audio/hospital/monitor_beep.wav")
const SOUND_ROLL := preload("res://assets/audio/hospital/roll.wav")
## Our own voices (S-012, T-145 and T-149), instead of the placeholders.
const SOUND_BREATH := preload("res://assets/audio/voices/hunted_breath.wav")
const SOUND_CAR_ALARM := preload("res://assets/audio/voices/car_alarm.wav")
const SOUND_CALL := preload("res://assets/audio/voices/call_for_help.wav")
const SOUND_RESCUE := preload("res://assets/audio/voices/rescue.wav")
const SOUND_MONSTER_BREATH := preload("res://assets/audio/voices/monster_breath.wav")
const SOUND_SCREAM := preload("res://assets/audio/voices/monster_scream.wav")
const SOUND_GROWLS: Array[AudioStream] = [
	preload("res://assets/audio/voices/monster_growl_0.wav"),
	preload("res://assets/audio/voices/monster_growl_1.wav"),
	preload("res://assets/audio/voices/monster_growl_2.wav"),
]
## The monster's voice goes to its own bus, sent into Effets (S-012, Q10).
const VOICE_BUS := &"Voix"
const EFFECTS_BUS := &"Effets"

var heard_count := 0
var audio: AudioSettings = preload("res://game/data/audio_settings.tres")

var _sounds := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _steps := FootstepSounds.new()
## One's own footsteps and breath, without a position (S-012, Q5).
var _own_step: AudioStreamPlayer
var _own_breath: AudioStreamPlayer
## The playable monster's own growl and cry (S-012, T-145).
var _own_voice: AudioStreamPlayer
var _last_growl := -1

@onready var _listener: Node3D = get_parent()


func _ready() -> void:
	_sounds[NoiseEvent.Type.BREATH] = SOUND_BREATH
	_sounds[NoiseEvent.Type.CAR_ALARM] = SOUND_CAR_ALARM
	_sounds[NoiseEvent.Type.CALL] = SOUND_CALL
	_sounds[NoiseEvent.Type.RESCUE] = SOUND_RESCUE
	_sounds[NoiseEvent.Type.SCREAM] = SOUND_SCREAM
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
	_own_voice = AudioStreamPlayer.new()
	_own_voice.name = "OwnVoice"
	_own_voice.bus = VOICE_BUS
	add_child(_own_voice)
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
	voice.bus = VOICE_BUS if is_voice(event) else EFFECTS_BUS
	voice.pitch_scale = _steps.pitch() if event.type == NoiseEvent.Type.FOOTSTEP else 1.0
	voice.max_distance = event.noise_range
	voice.global_position = event.position
	voice.set_meta(&"base_db", audio.level_db(event.type))  # The mix (T-147).
	SoundSpace.play(voice)  # Distance, walls and direction (S-012, T-142).


## The sound of a noise made by someone else: a footstep sounds of the floor
## it was made on, or of the monster's scrape (S-012, T-143).
func _stream_for(event: NoiseEvent) -> AudioStream:
	if event.type == NoiseEvent.Type.FOOTSTEP:
		if event.by_monster:
			return _steps.monster_step()
		return _steps.step(FloorSurface.at(get_tree(), event.position))
	if event.type == NoiseEvent.Type.BREATH and event.by_monster:
		return SOUND_MONSTER_BREATH
	if event.type == NoiseEvent.Type.GROWL:
		return _growl()
	return _sounds.get(event.type, _sounds[NoiseEvent.Type.BREATH])


## The monster's breath, growl and cry: its voice (S-012, Q10).
static func is_voice(event: NoiseEvent) -> bool:
	return (
		event.by_monster
		and (event.type in [NoiseEvent.Type.BREATH, NoiseEvent.Type.GROWL, NoiseEvent.Type.SCREAM])
	)


## One of the growls, never the same twice in a row.
func _growl() -> AudioStream:
	var index := randi() % SOUND_GROWLS.size()
	if index == _last_growl:
		index = (index + 1) % SOUND_GROWLS.size()
	_last_growl = index
	return SOUND_GROWLS[index]


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
			voice.stream = SOUND_MONSTER_BREATH if event.by_monster else SOUND_BREATH
		NoiseEvent.Type.GROWL, NoiseEvent.Type.SCREAM:
			voice = _own_voice
			voice.stream = _stream_for(event)
		_:
			return
	voice.volume_db = SoundMath.self_db(event.noise_range, NoiseBus.settings.walk_range, audio)
	voice.play()
