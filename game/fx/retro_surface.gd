class_name RetroSurface
extends RefCounted
## Turns the standard materials of a scene into the shared retro surface
## (spec S-005, T-031): wobbling vertices, nearest textures.
## Transparent materials (debug cones) are left as is. Unshaded ones (the
## sign, the monster's eyes) glow with their color, so the scan can dim them too.

const SHADER := preload("res://game/fx/retro_surface.gdshader")
const SHADER_DOUBLE := preload("res://game/fx/retro_surface_double.gdshader")

## One retro material per source material, so meshes keep sharing materials.
static var _cache: Dictionary = {}
## One retro copy per source mesh drawn by a MultiMesh.
static var _mesh_cache: Dictionary = {}


## Gives every lit opaque surface under root its retro material.
static func apply_to(root: Node, settings: VisualSettings) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		apply_to_mesh(mesh, settings)
	for batch: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		apply_to_multimesh(batch, settings)


static func apply_to_mesh(mesh: MeshInstance3D, settings: VisualSettings) -> void:
	if mesh.mesh == null:
		return
	for i in mesh.mesh.get_surface_count():
		var source := mesh.get_active_material(i) as BaseMaterial3D
		if source != null and can_convert(source):
			mesh.set_surface_override_material(i, make_material(source, settings))


## A MultiMesh has no per-surface override: its mesh is copied once with the
## retro materials, and the copy is shared by every batch of the same mesh.
static func apply_to_multimesh(batch: MultiMeshInstance3D, settings: VisualSettings) -> void:
	if batch.multimesh == null or batch.multimesh.mesh == null:
		return
	var source := batch.multimesh.mesh as ArrayMesh
	if source == null or source.has_meta(&"retro"):
		return
	var key := [source, settings]
	if not _mesh_cache.has(key):
		var copy := source.duplicate() as ArrayMesh
		copy.set_meta(&"retro", true)
		for i in copy.get_surface_count():
			var material := copy.surface_get_material(i) as BaseMaterial3D
			if material != null and can_convert(material):
				copy.surface_set_material(i, make_material(material, settings))
		_mesh_cache[key] = copy
	batch.multimesh.mesh = _mesh_cache[key]


static func can_convert(source: BaseMaterial3D) -> bool:
	return source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED


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
	material.set_shader_parameter(
		"unshaded", source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	material.set_shader_parameter("snap_grid", settings.vertex_snap)
	_cache[key] = material
	return material


## Sends the scan look to every retro material (T-032).
## building is the scanned one; amount fades it in and out; wave is the phase
## of the pale wave, from 0 (leaves the building) to 1 (fades out).
static func set_scan(
	building: Building, amount: float, wave: float, settings: VisualSettings
) -> void:
	var values := {"scan_amount": amount}
	if building != null:
		var box := building.get_box_transform()
		values["scan_center"] = box.origin
		values["scan_rotation"] = box.basis.orthonormalized().inverse()
		values["scan_half"] = building.size / 2.0
		values["scan_dim"] = settings.scan_dim
		values["scan_desaturation"] = settings.scan_desaturation
		values["scan_edge_color"] = settings.scan_edge_color
		values["scan_edge_width"] = settings.scan_edge_width
		values["scan_wave_radius"] = wave * settings.scan_wave_reach
		values["scan_wave_width"] = settings.scan_wave_width
		values["scan_wave_fade"] = 1.0 - wave
	for material: ShaderMaterial in _cache.values():
		for key: String in values:
			material.set_shader_parameter(key, values[key])
