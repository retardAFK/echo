extends GutTest
## Night, fog and pixel textures of the greybox (spec S-005, T-030).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const SETTINGS := preload("res://game/data/visual_settings.tres")

var _map: Node3D


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)


func test_settings_load_with_ambiance_a() -> void:
	assert_true(SETTINGS is VisualSettings)
	assert_gt(SETTINGS.fog_density, 0.0)
	assert_lt(SETTINGS.moon_energy, 1.0, "the moon stays faint")


func test_sky_and_fog_share_the_night_color() -> void:
	var env: Environment = (_map.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_true(env.fog_enabled)
	assert_almost_eq(env.fog_density, SETTINGS.fog_density, 0.0001)
	assert_eq(env.background_color, SETTINGS.fog_color)
	assert_eq(env.fog_light_color, SETTINGS.fog_color)
	assert_eq(env.ambient_light_color, SETTINGS.ambient_color)


func test_moon_is_faint_and_cold() -> void:
	var moon: DirectionalLight3D = _map.get_node("Moon")
	assert_almost_eq(moon.light_energy, SETTINGS.moon_energy, 0.0001)
	assert_eq(moon.light_color, SETTINGS.moon_color)
	assert_false(moon.shadow_enabled)


func test_blocks_have_sharp_pixel_textures() -> void:
	for mesh: MeshInstance3D in _map.get_node("Blocks").find_children(
		"*", "MeshInstance3D", true, false
	):
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		assert_not_null(material.albedo_texture, mesh.get_parent().name)
		assert_eq(material.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST)
		assert_true(material.uv1_world_triplanar, "textures follow the world, not the box size")
		var pixels_per_meter := material.albedo_texture.get_width() * material.uv1_scale.x
		assert_almost_eq(pixels_per_meter, 64.0, 0.01, "constitution 2.3: 64 px per meter")


func test_hospital_sign_is_green_not_orange() -> void:
	var glow: OmniLight3D = _map.get_node("HospitalSign/Glow")
	assert_gt(glow.light_color.g, glow.light_color.r)
	assert_false(glow.shadow_enabled)
