extends GutTest
## Retro screen filter and vertex wobble (spec S-005, T-031).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const SETTINGS := preload("res://game/data/visual_settings.tres")

var _map: Node3D


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	await wait_process_frames(2)


func _retro(mesh: MeshInstance3D) -> ShaderMaterial:
	return mesh.get_surface_override_material(0) as ShaderMaterial


func test_settings_hold_the_filter_values() -> void:
	assert_eq(SETTINGS.color_levels, 24)
	assert_eq(SETTINGS.grain_rate, 12.0)
	assert_eq(SETTINGS.vertex_snap, Vector2(320, 180))


func test_blocks_wobble_with_world_textures() -> void:
	var meshes := _map.get_node("Blocks").find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		var material := _retro(mesh)
		assert_not_null(material, mesh.get_parent().name)
		assert_eq(material.shader, RetroSurface.SHADER)
		assert_eq(material.get_shader_parameter("snap_grid"), SETTINGS.vertex_snap)
		assert_true(material.get_shader_parameter("world_triplanar"))


func test_blocks_share_their_retro_materials() -> void:
	var floor_mat := _retro(_map.get_node("Blocks/WallNorth/MeshInstance3D"))
	var wall_mat := _retro(_map.get_node("Blocks/WallSouth/MeshInstance3D"))
	assert_same(floor_mat, wall_mat, "one material per source material, for batching")


func test_props_stay_double_sided_and_textured() -> void:
	var tree: MeshInstance3D = (
		_map.get_node("Props/TreeCourt").find_children("*", "MeshInstance3D", true, false)[0]
	)
	var material := _retro(tree)
	assert_eq(material.shader, RetroSurface.SHADER_DOUBLE)
	assert_not_null(material.get_shader_parameter("albedo_texture"))
	assert_false(material.get_shader_parameter("world_triplanar"))


func test_lit_window_keeps_its_glow() -> void:
	var facade: MeshInstance3D = (
		_map
		. get_node("Props/BlockNorth/Panel11")
		. find_children("*", "MeshInstance3D", true, false)[0]
	)
	var glows := false
	for i in facade.mesh.get_surface_count():
		var material := facade.get_surface_override_material(i) as ShaderMaterial
		var color: Vector3 = material.get_shader_parameter("emission_color")
		glows = glows or color.length() > 0.0
	assert_true(glows)


func test_unshaded_sign_glows_with_its_color() -> void:
	var sign: MeshInstance3D = _map.get_node("HospitalSign")
	var material: ShaderMaterial = sign.get_surface_override_material(0)
	assert_true(material.get_shader_parameter("unshaded"), "dimmed by the scan like the rest")


func test_filter_sits_between_world_and_hud() -> void:
	var post: RetroPost = _map.get_node("RetroPost")
	var gauge: CanvasLayer = _map.get_node("NoiseGauge")
	assert_gt(post.layer, 0)
	assert_lt(post.layer, gauge.layer, "the HUD stays above the filter, orange stays sharp")
	var material: ShaderMaterial = post.get_node("Filter").material
	assert_eq(material.get_shader_parameter("color_levels"), float(SETTINGS.color_levels))
	assert_eq(material.get_shader_parameter("dither_strength"), SETTINGS.dither_strength)


func test_grain_changes_about_twelve_times_per_second() -> void:
	var post: RetroPost = _map.get_node("RetroPost")
	var material: ShaderMaterial = post.get_node("Filter").material
	var before: Variant = material.get_shader_parameter("grain_seed")
	post._process(0.5 / SETTINGS.grain_rate)
	assert_eq(material.get_shader_parameter("grain_seed"), before, "not every frame")
	post._process(0.6 / SETTINGS.grain_rate)
	assert_ne(material.get_shader_parameter("grain_seed"), before)
