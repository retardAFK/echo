class_name FootstepEmitter
extends Node
## Emits one noise per footstep of its parent (spec S-002, T-010): the hunted
## Player, or the AI prey (S-004), any body with get_gait().
## Footsteps are counted on horizontal distance walked on the floor. On a
## metal floor (S-016, Q9) they carry farther.

## A move longer than this in one frame is a jump in or out of a hiding spot,
## not a walk (S-008), in meters.
const MAX_STEP_MOVE := 0.5

@export var settings: NoiseSettings

var _distance := 0.0
var _last_position := Vector3.ZERO

@onready var _player: CharacterBody3D = get_parent()


func _ready() -> void:
	_last_position = _player.global_position


func _physics_process(_delta: float) -> void:
	var position := _player.global_position
	var moved := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not _player.is_on_floor():
		return  # No footsteps in the air.
	if HidingSpot.is_hidden(_player) or moved > MAX_STEP_MOVE:
		_distance = 0.0
		return  # Hidden (S-008), or moved in or out of a hiding spot at once.
	_distance += moved
	var gait: PlayerMotion.Gait = _player.call("get_gait")
	var stride := NoiseMath.stride_for_gait(settings, gait)
	if _distance < stride:
		return
	_distance = fmod(_distance, stride)
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP,
		position + Vector3.UP * settings.emit_height,
		NoiseMath.range_for_gait(settings, gait, MetalFloor.under(get_tree(), position)),
		_player
	)
