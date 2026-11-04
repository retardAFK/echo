extends GutTest
## Blender props in the game (spec S-005, T-033, T-034).

const LAMPPOST := preload("res://game/entities/props/lamppost.tscn")
const PROPS: Array[PackedScene] = [
	LAMPPOST,
	preload("res://game/entities/props/bench_dirty.tscn"),
	preload("res://game/entities/props/bench_broken.tscn"),
]
## Decorative object budget (constitution 2.3).
const MAX_PROP_TRIANGLES := 500


func _meshes(prop: Node) -> Array[Node]:
	return prop.find_children("*", "MeshInstance3D", true, false)


func test_props_stay_in_the_triangle_budget() -> void:
	for scene in PROPS:
		var prop: Node3D = scene.instantiate()
		add_child_autofree(prop)
		var triangles := 0
		for mesh: MeshInstance3D in _meshes(prop):
			for i in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3
		assert_gt(triangles, 0, scene.resource_path)
		assert_lt(triangles, MAX_PROP_TRIANGLES, scene.resource_path)


func test_props_have_sharp_pixels() -> void:
	for scene in PROPS:
		var prop: Node3D = scene.instantiate()
		add_child_autofree(prop)
		var mesh: MeshInstance3D = _meshes(prop)[0]
		var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		assert_not_null(material.albedo_texture, scene.resource_path)
		assert_eq(
			material.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, scene.resource_path
		)


func test_props_block_the_way() -> void:
	for scene in PROPS:
		var prop: Node3D = scene.instantiate()
		add_child_autofree(prop)
		var body: StaticBody3D = prop.get_node("Body")
		assert_eq(body.collision_layer, 1, "world layer: " + scene.resource_path)


func test_lamppost_light_is_sodium_and_without_shadow() -> void:
	var lamppost: Node3D = LAMPPOST.instantiate()
	add_child_autofree(lamppost)
	var light: OmniLight3D = lamppost.get_node("SodiumLight")
	assert_false(light.shadow_enabled, "dynamic shadows cost too much (2.2)")
	assert_gt(light.light_color.r, light.light_color.b, "ochre, not orange noise color")
	assert_gt(light.position.y, 4.0)
