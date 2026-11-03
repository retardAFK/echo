class_name FootstepEmitter
extends Node
## Emits one noise per footstep of its parent Player (spec S-002, T-010).
## Footsteps are counted on horizontal distance walked on the floor.

@export var settings: NoiseSettings

var _distance := 0.0
var _last_position := Vector3.ZERO

@onready var _player: Player = get_parent()


func _ready() -> void:
	_last_position = _player.global_position


func _physics_process(_delta: float) -> void:
	var position := _player.global_position
	var moved := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not _player.is_on_floor():
		return  # No footsteps in the air.
	_distance += moved
	var gait := _player.get_gait()
	var stride := NoiseMath.stride_for_gait(settings, gait)
	if _distance < stride:
		return
	_distance = fmod(_distance, stride)
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP,
		position + Vector3.UP * settings.emit_height,
		NoiseMath.range_for_gait(settings, gait),
		_player
	)
