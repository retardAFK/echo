extends GutTest
## First-time tips (S-020, T-329, piste U1): a bubble the first time the
## hunted sees a hiding spot, a terminal or a fuse box, saved so it shows once.

const TEST_PATH := "user://test_tips.cfg"
const SPOT_SCENE := preload("res://game/entities/hiding_spot/closet.tscn")
const BOX_SCENE := preload("res://game/entities/fuse_box/fuse_box.tscn")

var _saved_path := ""


func before_each() -> void:
	_saved_path = Settings.path
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	Settings.load_file()


func after_each() -> void:
	Settings.reset()
	DirAccess.remove_absolute(TEST_PATH)
	Settings.path = _saved_path
	Settings.load_file()


func _wall(at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = NoiseBus.WALLS_COLLISION_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 0.3)
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child_autofree(body)


func _camera() -> Camera3D:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0, 1.6, 0)
	camera.make_current()
	return camera


func _spot(at: Vector3) -> HidingSpot:
	var spot: HidingSpot = SPOT_SCENE.instantiate()
	spot.position = at
	add_child_autofree(spot)
	return spot


func test_settings_are_the_starting_points() -> void:
	var settings: TipSettings = FirstTips.SETTINGS
	assert_eq(settings.see_range, 8.0)
	assert_eq(settings.show_time, 7.0)


func test_each_kind_has_a_flag_and_a_text() -> void:
	for kind in FirstTips.KINDS:
		assert_true(UserSettings.FLAGS.has(FirstTips.flag_of(kind)), kind)
		assert_ne(tr(FirstTips.text_of(kind)), FirstTips.text_of(kind), kind)
	assert_eq(FirstTips.kind_of(BOX_SCENE.instantiate()), "fuse_box")
	assert_eq(FirstTips.kind_of(Node3D.new()), "")


func test_seen_only_close_in_view_and_not_behind_a_wall() -> void:
	var camera := _camera()
	await wait_physics_frames(2)
	var space := camera.get_world_3d().direct_space_state
	var settings: TipSettings = FirstTips.SETTINGS
	assert_true(FirstTips.sees(camera, Vector3(0, 1, -5), space, settings))
	assert_false(FirstTips.sees(camera, Vector3(0, 1, -12), space, settings), "too far")
	assert_false(FirstTips.sees(camera, Vector3(0, 1, 5), space, settings), "behind")
	_wall(Vector3(0, 2, -3))
	await wait_physics_frames(2)
	assert_false(FirstTips.sees(camera, Vector3(0, 1, -5), space, settings), "a wall between")


func test_a_tip_shows_once_and_is_saved() -> void:
	_camera()
	_spot(Vector3(0, 0, -4))
	await wait_physics_frames(2)
	var tips := FirstTips.new()
	add_child_autofree(tips)
	tips._process(0.0)
	assert_eq(tips.showing, "TIP_HIDING_SPOT")
	assert_true(FirstTips.was_seen("hiding_spot"))
	Settings.load_file()
	assert_true(FirstTips.was_seen("hiding_spot"), "saved with the settings")
	tips._process(FirstTips.SETTINGS.show_time + 0.1)
	assert_eq(tips.showing, "", "it goes away")
	var again := FirstTips.new()
	add_child_autofree(again)
	again._process(0.0)
	assert_eq(again.showing, "", "never twice, even in another game")
	Settings.reset()
	again._process(FirstTips.SETTINGS.check_interval + 0.01)
	assert_eq(again.showing, "TIP_HIDING_SPOT", "back after a reset of the options")


func test_the_hunted_s_screen_has_the_tips() -> void:
	var map: Node3D = preload("res://game/maps/greybox_test.tscn").instantiate()
	add_child_autofree(map)
	assert_eq(map.find_children("*", "FirstTips", false, false).size(), 1)
