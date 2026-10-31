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


func test_movement_actions_use_physical_keys() -> void:
	# Physical key codes give ZQSD on AZERTY and WASD on QWERTY (spec S-001).
	for action in [
		"move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "release_mouse"
	]:
		assert_true(InputMap.has_action(action), "Missing input action: %s" % action)
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_ne(event.physical_keycode, KEY_NONE, "%s must use a physical key" % action)


func test_internal_resolution_is_640_by_360() -> void:
	# Constitution 2.2: 640 x 360 internal resolution, scaled with sharp pixels.
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")
