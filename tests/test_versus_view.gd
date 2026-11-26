extends GutTest
## The Versus seen from behind the shoulder (spec S-025, Q1, T-402): the
## camera, the body shown, V for the first person, the shot that goes where
## the crosshair points.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func _open() -> VersusMode:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


func _press_v(view: VersusView) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	key.pressed = true
	view._unhandled_key_input(key)


func test_the_camera_is_behind_the_shoulder_and_v_switches() -> void:
	var versus := await _open()
	var view := versus.view
	assert_not_null(view, "a view for the player here")
	var player := versus.local_hunter().body as Player
	assert_true(view.camera.current)
	var offset := view.camera.global_position - player.get_eye_position()
	assert_gt(offset.dot(player.global_basis.z), 1.0, "behind")
	assert_gt(offset.dot(player.global_basis.x), 0.2, "over the right shoulder")
	assert_false(versus.local_hunter().view_model.visible, "no arms from behind")
	_press_v(view)
	assert_true(versus.first_person())
	assert_false(view.camera.current)
	await wait_physics_frames(1)
	assert_true(versus.local_hunter().view_model.visible, "the arms again")


func test_the_shot_goes_where_the_crosshair_points() -> void:
	var versus := await _open()
	var kit := versus.local_hunter()
	var player := kit.body as Player
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 10, 0.5)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = player.get_eye_position() - player.global_basis.z * 15.0
	await wait_physics_frames(2)
	var view := versus.view
	var direction := kit.aim()
	var query := PhysicsRayQueryParameters3D.create(
		view.camera.global_position,
		view.camera.global_position - view.camera.global_basis.z * 100.0
	)
	var crosshair: Vector3 = (
		player.get_world_3d().direct_space_state.intersect_ray(query)["position"]
	)
	var expected := (crosshair - kit.eye()).normalized()
	assert_almost_eq(direction.angle_to(expected), 0.0, 0.02, "from the eyes to the crosshair")
