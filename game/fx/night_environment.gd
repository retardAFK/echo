class_name NightEnvironment
extends WorldEnvironment
## Night sky, depth fog and moonlight from the visual settings (spec S-005, T-030).
## The sky and the fog share one color, so the fog swallows the far end of the map.

@export var settings: VisualSettings = preload("res://game/data/visual_settings.tres")
## The map's only directional light, dimmed to a faint moonlight.
@export var moon: DirectionalLight3D


func _ready() -> void:
	apply()
	Settings.changed.connect(_apply_brightness)


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
	environment.fog_light_color = settings.fog_color
	environment.fog_light_energy = 1.0
	environment.fog_density = settings.fog_density
	environment.fog_sky_affect = 1.0
	if moon != null:
		moon.light_color = settings.moon_color
		moon.light_energy = settings.moon_energy
		moon.shadow_enabled = false
	_apply_brightness("")


## Darkens the sky and the fog while the monster scans a building (T-032),
## like everything else outside the building. 0 is the normal night.
func set_scan_amount(amount: float) -> void:
	var color := settings.fog_color.darkened(settings.scan_dim * amount)
	environment.background_color = color
	environment.fog_light_color = color
