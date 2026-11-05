class_name RetroPost
extends CanvasLayer
## Full screen retro filter over the world and under the HUD (spec S-005, T-031).
## The HUD layers sit above it, so the orange noise marks stay sharp.

@export var settings: VisualSettings = preload("res://game/data/visual_settings.tres")

var _grain_time := 0.0

@onready var _rect: ColorRect = $Filter
@onready var _material: ShaderMaterial = _rect.material


func _ready() -> void:
	_material.set_shader_parameter("color_levels", float(settings.color_levels))
	_material.set_shader_parameter("dither_strength", settings.dither_strength)
	_material.set_shader_parameter("grain_strength", settings.grain_strength)


func _process(delta: float) -> void:
	_grain_time += delta
	var step := 1.0 / settings.grain_rate
	if _grain_time >= step:
		_grain_time = fmod(_grain_time, step)
		_material.set_shader_parameter("grain_seed", randf())
