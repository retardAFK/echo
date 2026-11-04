class_name MonsterNoise
extends RefCounted
## The monster's own noises (spec S-003, D-009), shared by the AI monster and
## the playable monster (S-004): a footstep every stride at the pace's range,
## silent when prowling, and a short-range breath at a fixed interval.

var _settings: MonsterSettings
var _step_distance := 0.0
var _breath_timer := 0.0


func _init(settings: MonsterSettings) -> void:
	_settings = settings


## Call every physics frame with the horizontal distance walked since the last call.
func update(
	delta: float, moved: float, pace: MonsterBrain.Pace, feet: Vector3, ears: Vector3, source: Node
) -> void:
	_step_distance += moved
	if _step_distance >= _settings.stride:
		_step_distance = fmod(_step_distance, _settings.stride)
		var step_range := MonsterBrain.noise_range_for(pace, _settings)
		if step_range > 0.0:
			NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, feet, step_range, source)
	_breath_timer += delta
	if _breath_timer >= _settings.breath_interval:
		_breath_timer = 0.0
		NoiseBus.emit_noise(NoiseEvent.Type.BREATH, ears, _settings.breath_range, source)
