class_name FlashBurst
extends MeshInstance3D
## The white burst of a flash grenade (spec S-025, Q2, T-404): an unshaded
## sphere that swells to the grenade's radius and is gone in LIFE seconds.
## VersusMode.show_flash adds it, here and on the clients. In another color
## and life: a fireball's burst and its embers (BossFire, Fireball, T-413).

const LIFE := 0.3

var radius := 6.0
var life := LIFE
var _age := 0.0
var _alpha := 0.8


func _init(p_radius: float, color := Color(1.0, 1.0, 0.95, 0.8), p_life := LIFE) -> void:
	radius = p_radius
	life = p_life
	_alpha = color.a
	name = "FlashBurst"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere.material = material
	mesh = sphere
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3.ONE * 0.1


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var t := _age / life
	scale = Vector3.ONE * maxf(radius * sqrt(t), 0.1)
	var material := (mesh as SphereMesh).material as StandardMaterial3D
	material.albedo_color.a = _alpha * (1.0 - t)
