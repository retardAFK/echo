extends GutTest
## NoiseBus autoload and wall counting with real physics (spec S-002, T-009).

const WALLS_LAYER := 1 << 1
const WORLD_LAYER := 1 << 0
const EAR := Vector3(0.0, 0.3, 0.0)


func _add_wall(center: Vector3, layer: int = WALLS_LAYER) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.2)
	shape.shape = box
	body.add_child(shape)
	body.position = center
	add_child_autofree(body)


func test_emit_noise_reaches_listeners() -> void:
	watch_signals(NoiseBus)
	var event: NoiseEvent = NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3.ONE, 4.0, self)
	assert_signal_emitted_with_parameters(NoiseBus, "noise_emitted", [event])
	assert_eq(event.noise_range, 4.0)
	assert_eq(event.source, self)


func test_no_wall_in_open_space() -> void:
	await wait_physics_frames(2)
	assert_eq(NoiseBus.walls_between(EAR, EAR + Vector3(0.0, 0.0, -10.0)), 0)


func test_counts_each_wall_once() -> void:
	_add_wall(Vector3(0.0, 1.5, -2.0))
	_add_wall(Vector3(0.0, 1.5, -4.0))
	await wait_physics_frames(2)
	assert_eq(NoiseBus.walls_between(EAR, EAR + Vector3(0.0, 0.0, -3.0)), 1)
	assert_eq(NoiseBus.walls_between(EAR, EAR + Vector3(0.0, 0.0, -10.0)), 2)


func test_floors_and_steps_do_not_muffle() -> void:
	_add_wall(Vector3(0.0, 1.5, -2.0), WORLD_LAYER)
	await wait_physics_frames(2)
	assert_eq(NoiseBus.walls_between(EAR, EAR + Vector3(0.0, 0.0, -10.0)), 0)


func test_sprint_behind_wall_heard_at_6m_not_8m() -> void:
	_add_wall(Vector3(0.0, 1.5, -1.0))
	await wait_physics_frames(2)
	var settings: NoiseSettings = NoiseBus.settings
	var event := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, EAR, settings.sprint_range)
	assert_almost_eq(NoiseBus.perceived_range(event, EAR + Vector3(0.0, 0.0, -6.0)), 7.0, 0.001)
	assert_true(NoiseBus.can_hear(event, EAR + Vector3(0.0, 0.0, -6.0)))
	assert_false(NoiseBus.can_hear(event, EAR + Vector3(0.0, 0.0, -8.0)))


func test_far_noise_is_not_heard() -> void:
	var event := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, EAR, 4.0)
	assert_false(NoiseBus.can_hear(event, EAR + Vector3(0.0, 0.0, -10.0)))
