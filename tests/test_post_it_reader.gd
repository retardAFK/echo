extends GutTest
## Reading the post-its of the code (S-018, Q13, T-271): a hunted in front of
## a post-it reads on the HUD what it says, and the code read comes back on
## the map screen's objective line and at the keypad.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const SPOT_SCENE := preload("res://game/entities/objectives/code_spot.tscn")
const SETTINGS := preload("res://game/data/loop_settings.tres")

var _before := ""


func before_each() -> void:
	_before = OS.get_environment("ECHO_OBJECTIVES")


func after_each() -> void:
	OS.set_environment("ECHO_OBJECTIVES", _before)
	GameSession.game_seed = 0


func _spot() -> CodeSpot:
	var spot: CodeSpot = SPOT_SCENE.instantiate()
	add_child_autofree(spot)
	return spot


func test_a_post_it_is_read_from_in_front_and_close() -> void:
	var spot := _spot()  # Front toward +Z, at the origin.
	var reach := SETTINGS.code_read_reach
	var angle := deg_to_rad(SETTINGS.code_read_angle)
	var eye := Vector3(0, 0, 1.5)
	assert_true(spot.readable_from(eye, Vector3.FORWARD, reach, angle), "in front, looking at it")
	assert_false(spot.readable_from(eye, Vector3.RIGHT, reach, angle), "looking aside")
	assert_false(
		spot.readable_from(Vector3(0, 0, -1.5), Vector3.BACK, reach, angle), "behind the wall"
	)
	assert_false(
		spot.readable_from(Vector3(0, 0, reach + 1.0), Vector3.FORWARD, reach, angle), "too far"
	)


func test_a_new_code_forgets_the_reading() -> void:
	var spot := _spot()
	spot.show_code("1234")
	spot.was_read = true
	spot.show_code("1234")
	assert_true(spot.was_read, "the same code, sent again online, stays read")
	spot.show_code("5678")
	assert_false(spot.was_read)


func test_the_hud_reads_the_post_it_and_the_map_reminds_it() -> void:
	OS.set_environment("ECHO_OBJECTIVES", "fuse,code")
	GameSession.game_seed = 7
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.get_node("Monster").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(2)
	var readers := map.find_children("*", "PostItReader", false, false)
	assert_eq(readers.size(), 1, "the hunted has a post-it reader")
	var reader: PostItReader = readers[0]
	var quests := map.game_loop.quests
	var spot := quests.code_spot
	var camera := Camera3D.new()
	map.add_child(camera)
	var eye := spot.global_position + spot.global_basis.z * 1.5
	camera.look_at_from_position(eye, spot.global_position)
	camera.make_current()
	assert_eq(reader.spot_in_view(), spot)
	assert_null(CodeSpot.read_code_spot(get_tree()), "not read yet")
	var lines_before := map.map_screen.objective_lines()
	assert_false("\n".join(lines_before).contains(quests.code), "the map does not give it")
	await wait_process_frames(2)
	assert_true(spot.was_read)
	var lines := map.map_screen.objective_lines()
	assert_true("\n".join(lines).contains(quests.code), "the map reminds the code read")
	var blank: CodeSpot = null
	for other: CodeSpot in get_tree().get_nodes_in_group(CodeSpot.GROUP):
		if other != spot:
			blank = other
			break
	eye = blank.global_position + blank.global_basis.z * 1.5
	camera.look_at_from_position(eye, blank.global_position)
	assert_eq(reader.spot_in_view(), blank)
	await wait_process_frames(1)
	assert_eq(reader.get_child(0).text, Text.t("HUD_POST_IT_ELSEWHERE"))
