class_name NightEnvironment
extends WorldEnvironment
## Night sky, depth fog and moonlight from the visual settings (spec S-005, T-030).
## The sky and the fog share one color, so the fog swallows the far end of the map.

@export var settings: VisualSettings = preload("res://game/data/visual_settings.tres")
## The map's only directional light, dimmed to a faint moonlight.
@export var moon: DirectionalLight3D

## How deep the camera is in an indoor fog zone, 0 to 1, eased (S-014, T-190).
var indoor := 0.0
var _scan := 0.0


func _ready() -> void:
	apply()
	Settings.changed.connect(_apply_brightness)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var inside := camera != null and IndoorFog.covers(get_tree(), camera.global_position)
	var target := 1.0 if inside else 0.0
	if is_equal_approx(indoor, target):
		return
	indoor = move_toward(indoor, target, delta / settings.indoor_fog_time)
	_update_fog()


## Brightness from the options (S-013, T-163); 1 is the night as designed.
func _apply_brightness(_key: String) -> void:
	environment.adjustment_enabled = true
	environment.adjustment_brightness = float(Settings.get_value("brightness"))


func apply() -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = settings.fog_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = settings.ambient_color
	environment.ambient_light_energy = settings.ambient_energy
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_energy = 1.0
	environment.fog_sky_affect = 1.0
	_update_fog()
	if moon != null:
		moon.light_color = settings.moon_color
		moon.light_energy = settings.moon_energy
		moon.shadow_enabled = false
	_apply_brightness("")


## Darkens the sky and the fog while the monster scans a building (T-032),
## like everything else outside the building. 0 is the normal night.
func set_scan_amount(amount: float) -> void:
	_scan = amount
	_update_fog()


## The fog from the night, the indoor fog and the scan.
func _update_fog() -> void:
	var dim := settings.scan_dim * _scan
	var eased := smoothstep(0.0, 1.0, indoor)
	environment.background_color = settings.fog_color.darkened(dim)
	environment.fog_light_color = (
		settings.fog_color.lerp(settings.indoor_fog_color, eased).darkened(dim)
	)
	environment.fog_density = lerpf(settings.fog_density, settings.indoor_fog_density, eased)
