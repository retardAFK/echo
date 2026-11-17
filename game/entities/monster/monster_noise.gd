class_name MonsterNoise
extends RefCounted
## The monster's own noises (spec S-003, D-009), shared by the AI monster and
## the playable monster (S-004): a footstep every stride at the pace's range,
## silent when prowling, and a short-range breath at a fixed interval. Its
## voice (S-012, T-145): a growl on the first running step after a rest, and a
## cry when it catches a hunted.

var _settings: MonsterSettings
var _step_distance := 0.0
var _breath_timer := 0.0
## Seconds since its last running step.
var _rest := 0.0


func _init(settings: MonsterSettings) -> void:
	_settings = settings
	_rest = settings.growl_rest


## Call every physics frame with the horizontal distance walked since the last call.
func update(
	delta: float, moved: float, pace: MonsterBrain.Pace, feet: Vector3, ears: Vector3, source: Node
) -> void:
	_step_distance += moved
	_rest += delta
	if _step_distance >= _settings.stride:
		_step_distance = fmod(_step_distance, _settings.stride)
		var step_range := MonsterBrain.noise_range_for(pace, _settings)
		if step_range > 0.0:
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, feet, step_range, source)
		if pace == MonsterBrain.Pace.RUN:
			if _rest >= _settings.growl_rest:
				NoiseBus.emit_noise(NoiseEvent.Type.GROWL, ears, _settings.growl_range, source)
			_rest = 0.0
	_breath_timer += delta
	if _breath_timer >= _settings.breath_interval:
		_breath_timer = 0.0
		NoiseBus.emit_noise(NoiseEvent.Type.BREATH, ears, _settings.breath_range, source)


## Its cry when it catches a hunted (S-012, Q7), heard far around: the
## monster is anything with settings and get_ear_position().
static func scream(monster: Node3D) -> void:
	var settings: MonsterSettings = monster.get("settings")
	if settings != null and monster.has_method("get_ear_position"):
		NoiseBus.emit_noise(
			NoiseEvent.Type.SCREAM, monster.get_ear_position(), settings.scream_range, monster
		)
