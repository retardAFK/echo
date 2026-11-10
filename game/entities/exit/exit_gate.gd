class_name ExitGate
extends AnimatableBody3D
## The grille that closes the exit tunnel (spec S-007, Q4). It rises when the
## transformer is repaired, and the way north is open.

@export var settings: LoopSettings
## How high the grille rises, in meters.
@export var rise := 3.6

var is_open := false

var _closed_y := 0.0


func _ready() -> void:
	_closed_y = position.y


func open() -> void:
	if is_open:
		return
	is_open = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", _closed_y + rise, settings.gate_open_time)
