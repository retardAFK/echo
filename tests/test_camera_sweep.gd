extends GutTest
## Sweeping cameras (S-020, T-336, piste N3): the head turns ±35° in 8 s,
## and what the camera sees, on the room, follows where it looks now.

const CAMERA_SCENE := preload("res://game/entities/network/security_camera.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const SETTINGS := preload("res://game/data/network_settings.tres")


func _camera() -> SecurityCamera:
	var camera: SecurityCamera = CAMERA_SCENE.instantiate()
	add_child_autofree(camera)
	camera.set_physics_process(false)  # Driven by hand.
	return camera


## The sweep time at which the head is turned this much (radians).
func _time_at(camera: SecurityCamera, angle: float) -> float:
	var best := 0.0
	for i in 800:
		var t := i * SETTINGS.camera_sweep_period / 800.0
		camera.set_sweep_time(t)
		if absf(camera.sweep_angle() - angle) < absf(_angle_at(camera, best) - angle):
			best = t
	return best


func _angle_at(camera: SecurityCamera, t: float) -> float:
	camera.set_sweep_time(t)
	return camera.sweep_angle()


func test_settings_follow_the_roadmap() -> void:
	assert_eq(SETTINGS.camera_sweep_angle, 35.0)
	assert_eq(SETTINGS.camera_sweep_period, 8.0)


func test_the_head_sweeps_35_degrees_each_side_in_8_seconds() -> void:
	var camera := _camera()
	var widest := 0.0
	for i in 160:
		camera._physics_process(0.05)
		widest = maxf(widest, absf(camera.sweep_angle()))
	assert_almost_eq(widest, deg_to_rad(35.0), deg_to_rad(0.5))
	var now := camera.sweep_angle()
	assert_almost_eq(_angle_at(camera, camera.sweep_time + 8.0), now, 0.001, "back in 8 s")
	var forward := -camera.eye_transform().basis.z
	var turned := Vector2(forward.x, forward.z).angle_to(Vector2(0, -1))
	assert_almost_eq(absf(turned), absf(now), 0.01, "the lens turns with the head")


func test_what_it_sees_follows_where_it_looks_now() -> void:
	var camera := _camera()
	var reach := deg_to_rad(SETTINGS.camera_sweep_angle)
	# A point at the edge of the still camera's view, on the side of a full turn.
	var edge := deg_to_rad(SETTINGS.camera_fov) / 2.0 + reach * 0.8
	var point := Vector3(-sin(edge), 0, -cos(edge)) * 10.0
	camera.set_sweep_time(_time_at(camera, reach))
	assert_true(camera.sees(point), "turned toward it")
	camera.set_sweep_time(_time_at(camera, -reach))
	assert_false(camera.sees(point), "turned away")


func test_a_smashed_camera_stops_sweeping() -> void:
	var camera := _camera()
	camera.smash()
	var before := camera.sweep_time
	camera._physics_process(1.0)
	assert_eq(camera.sweep_time, before)


func test_the_room_s_sweep_reaches_the_clients() -> void:
	var camera := _camera()
	camera.set_sweep_time(3.25)
	var lens := camera.eye_transform()
	var copy := _camera()
	copy.global_position = camera.global_position
	copy.set_sweep_time(3.25)
	assert_almost_eq(copy.eye_transform().basis.z, lens.basis.z, Vector3.ONE * 0.0001)
