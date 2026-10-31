extends GutTest
## Developer overlay with the frame rate (spec S-001, T-006).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _overlay: DebugOverlay


func before_each() -> void:
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	_overlay = map.get_node("DebugOverlay")


func test_overlay_is_wired_to_player() -> void:
	assert_not_null(_overlay.player)


func test_shows_fps_and_gait() -> void:
	_overlay.refresh()
	assert_string_contains(_overlay.get_text(), "FPS")
	assert_string_contains(_overlay.get_text(), "WALK")


func test_toggles_with_f3() -> void:
	var was_visible := _overlay.visible
	var press := InputEventAction.new()
	press.action = "toggle_debug"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(2)
	assert_ne(_overlay.visible, was_visible)
