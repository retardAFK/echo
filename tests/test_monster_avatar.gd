extends GutTest
## The playable monster (spec S-004, Q6, T-021).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const OPEN_SPOT := Vector3(0, 0, -16)

var _map: Node3D
var _avatar: MonsterAvatar
var _heard: Array[NoiseEvent] = []


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.set_physics_process(false)  # Driven by hand, without keyboard input.
	_avatar.global_position = OPEN_SPOT
	_heard.clear()
	NoiseBus.noise_emitted.connect(_record)
	await wait_physics_frames(2)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	GameSession.role = GameSession.Role.HUNTED


func _record(event: NoiseEvent) -> void:
	if event.source == _avatar:
		_heard.append(event)


func _steps() -> Array[NoiseEvent]:
	return _heard.filter(func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.FOOTSTEP)


func _walk(seconds: float, sprinting := false) -> void:
	var delta := 1.0 / Engine.physics_ticks_per_second
	for i in int(seconds / delta):
		_avatar.move(Vector2(0, 1), sprinting, delta)  # Away from the north wall.
		await get_tree().physics_frame


func test_pace_from_controls() -> void:
	assert_eq(MonsterAvatar.resolve_pace(false, false, true), MonsterBrain.Pace.WALK)
	assert_eq(MonsterAvatar.resolve_pace(false, true, true), MonsterBrain.Pace.RUN)
	assert_eq(MonsterAvatar.resolve_pace(false, true, false), MonsterBrain.Pace.WALK)
	assert_eq(MonsterAvatar.resolve_pace(true, true, true), MonsterBrain.Pace.PROWL)


func test_eyes_at_ear_height() -> void:
	var expected := _avatar.global_position.y + _avatar.settings.ear_height
	assert_almost_eq(_avatar.get_camera().global_position.y, expected, 0.01)


func test_walking_is_heard_at_three_meters() -> void:
	await _walk(1.5)
	assert_almost_eq(_avatar.velocity.length(), _avatar.settings.walk_speed, 0.1)
	var steps := _steps()
	assert_gt(steps.size(), 0)
	assert_eq(steps[0].noise_range, _avatar.settings.walk_range)


func test_running_is_heard_at_twelve_meters() -> void:
	await _walk(1.0, true)
	assert_almost_eq(_avatar.velocity.length(), _avatar.settings.run_speed, 0.1)
	assert_eq(_steps().back().noise_range, _avatar.settings.run_range)


func test_prowling_is_silent_but_breathes() -> void:
	_avatar.toggle_prowl()
	await _walk(2.5)
	assert_eq(_avatar.get_pace(), MonsterBrain.Pace.PROWL)
	assert_almost_eq(_avatar.velocity.length(), _avatar.settings.prowl_speed, 0.1)
	assert_eq(_steps().size(), 0, "no footstep while prowling")
	var breaths := _heard.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.BREATH
	)
	assert_gt(breaths.size(), 0)
	assert_eq(breaths[0].noise_range, _avatar.settings.breath_range)


func test_monster_hears_through_its_ears() -> void:
	var ears: PlayerEars = _avatar.get_node("PlayerEars")
	var near := _avatar.global_position + Vector3(1, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, 4.0, self)
	assert_eq(ears.heard_count, 1)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, 4.0, _avatar)
	assert_eq(ears.heard_count, 1, "its own noises stay silent")
