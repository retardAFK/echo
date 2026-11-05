class_name RetroSurface
extends RefCounted
## Turns the standard materials of a scene into the shared retro surface
## (spec S-005, T-031): wobbling vertices, nearest textures.
## Unshaded and transparent materials (debug markers, the sign) are left as is.

const SHADER := preload("res://game/fx/retro_surface.gdshader")
const SHADER_DOUBLE := preload("res://game/fx/retro_surface_double.gdshader")

## One retro material per source material, so meshes keep sharing materials.
static var _cache: Dictionary = {}


## Gives every lit opaque surface under root its retro material.
static func apply_to(root: Node, settings: VisualSettings) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		apply_to_mesh(mesh, settings)


static func apply_to_mesh(mesh: MeshInstance3D, settings: VisualSettings) -> void:
	if mesh.mesh == null:
		return
	for i in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(i) as BaseMaterial3D
		if source != null and can_convert(source):
			mesh.set_surface_override_material(i, make_material(source, settings))


static func can_convert(source: BaseMaterial3D) -> bool:
	return (
		source.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
		and source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	)


static func make_material(source: BaseMaterial3D, settings: VisualSettings) -> ShaderMaterial:
	var key := [source, settings]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	var double := source.cull_mode == BaseMaterial3D.CULL_DISABLED
	material.shader = SHADER_DOUBLE if double else SHADER
	if source.albedo_texture != null:
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
	material.set_shader_parameter("albedo_color", source.albedo_color)
	material.set_shader_parameter("roughness", source.roughness)
	material.set_shader_parameter(
		"world_triplanar", source.uv1_triplanar and source.uv1_world_triplanar
	)
	material.set_shader_parameter("uv_scale", source.uv1_scale)
	var glow := Color.BLACK
	if source.emission_enabled:
		glow = source.emission * source.emission_energy_multiplier
		if source.emission_texture != null:
			material.set_shader_parameter("emission_texture", source.emission_texture)
	material.set_shader_parameter("emission_color", Vector3(glow.r, glow.g, glow.b))
	material.set_shader_parameter("snap_grid", settings.vertex_snap)
	_cache[key] = material
	return material
