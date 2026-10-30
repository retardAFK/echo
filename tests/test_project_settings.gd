extends GutTest

const MAIN_SCENE_SETTING := "application/run/main_scene"
const RENDERING_METHOD_SETTING := "rendering/renderer/rendering_method"
const RENDERING_METHOD_MOBILE_SETTING := "rendering/renderer/rendering_method.mobile"
const COMPATIBILITY_RENDERER := "gl_compatibility"


func test_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting(RENDERING_METHOD_SETTING), COMPATIBILITY_RENDERER)
	assert_eq(ProjectSettings.get_setting(RENDERING_METHOD_MOBILE_SETTING), COMPATIBILITY_RENDERER)


func test_main_scene_instantiates() -> void:
	var scene_path: String = ProjectSettings.get_setting(MAIN_SCENE_SETTING)
	var packed: PackedScene = load(scene_path)
	assert_not_null(packed, "Main scene must load: %s" % scene_path)
	if packed == null:
		return
	var root := packed.instantiate()
	add_child_autofree(root)
	assert_true(root is Node3D, "Main scene root must be a Node3D")
