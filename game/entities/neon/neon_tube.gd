class_name NeonTube
extends Node3D
## A fluorescent tube that buzzes and stutters (spec S-014, T-190): lit most
## of the time, now and then a burst of flickers, sometimes dead for a moment.
## Its light is a real one, not baked, so the walls flicker with it; it lights
## only while the camera is on its level, since it has no shadow and would
## shine through the slab above.

const GROUP := &"neon_tubes"

## Seconds between two fits, at random between these.
@export var calm := Vector2(3.0, 10.0)
## Length of a fit of flickers.
@export var fit := Vector2(0.2, 0.9)
## Chance that a fit ends with the tube dead for a while, and how long.
@export_range(0.0, 1.0, 0.05) var dead_chance := 0.35
@export var dead := Vector2(0.4, 2.5)
## Seconds between two flickers inside a fit.
@export var flicker := Vector2(0.03, 0.12)
## The lit and the dead look of the tube.
@export var lit_material: Material
@export var dead_material: Material

## Whether the tube shines right now.
var lit := true

var _rng := RandomNumberGenerator.new()
var _wait := 0.0
var _fit_left := 0.0

@onready var _light: OmniLight3D = $Light
@onready var _tube: MeshInstance3D = $Tube


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = hash(String(name))
	_wait = _rng.randf_range(calm.x, calm.y)
	_show(true)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var above := camera.global_position.y - global_position.y
		_light.visible = lit and above > -3.5 and above < 0.5
	step(delta)


## Moves the tube's fits on by delta seconds.
func step(delta: float) -> void:
	_wait -= delta
	while _wait <= 0.0:
		if _fit_left > 0.0:
			_show(not lit)
			var gap := _rng.randf_range(flicker.x, flicker.y)
			_fit_left -= gap
			_wait += gap
			if _fit_left <= 0.0:
				var dies := _rng.randf() < dead_chance
				_show(not dies)
				_wait += (
					_rng.randf_range(dead.x, dead.y) if dies else _rng.randf_range(calm.x, calm.y)
				)
		elif not lit:
			_show(true)
			_wait += _rng.randf_range(calm.x, calm.y)
		else:
			_fit_left = _rng.randf_range(fit.x, fit.y)


func _show(on: bool) -> void:
	lit = on
	if _light != null:
		_light.visible = on
	if _tube != null:
		_tube.material_override = lit_material if on else dead_material
