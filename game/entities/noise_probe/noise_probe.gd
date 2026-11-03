class_name NoiseProbe
extends Node3D
## Test microphone (spec S-002, T-011): lights up orange when it hears a noise.
## Stands in for the monster until S-003. Shown only in noise debug mode (F4).

const DEBUG_GROUP := "noise_debug"

var settings: NoiseSettings = NoiseBus.settings
var _lit_time := 0.0
var _heard_count := 0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _idle_material: StandardMaterial3D = _mesh.material_override
@onready var _lit_material: StandardMaterial3D = _idle_material.duplicate()


func _ready() -> void:
	add_to_group(DEBUG_GROUP)
	visible = false
	_lit_material.albedo_color = settings.noise_color
	NoiseBus.noise_emitted.connect(_on_noise_emitted)


func _process(delta: float) -> void:
	_lit_time = maxf(_lit_time - delta, 0.0)
	_mesh.material_override = _lit_material if is_lit() else _idle_material


func is_lit() -> bool:
	return _lit_time > 0.0


func get_heard_count() -> int:
	return _heard_count


func _on_noise_emitted(event: NoiseEvent) -> void:
	if NoiseBus.can_hear(event, global_position):
		_heard_count += 1
		_lit_time = settings.debug_probe_flash_time
