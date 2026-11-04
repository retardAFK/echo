extends GutTest
## The AI prey in the greybox (spec S-004, Q4, T-025).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const FAR_AWAY := Vector3(18, 0, -18)

var _map: Node3D
var _avatar: MonsterAvatar
var _prey: Prey
var _steps: Array[NoiseEvent] = []


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.process_mode = Node.PROCESS_MODE_DISABLED
	_avatar.global_position = FAR_AWAY
	_prey = _map.prey
	_steps.clear()
	NoiseBus.noise_emitted.connect(_record)
	await wait_physics_frames(2)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	GameSession.role = GameSession.Role.HUNTED


func _record(event: NoiseEvent) -> void:
	if event.source == _prey and event.type == NoiseEvent.Type.FOOTSTEP:
		_steps.append(event)


func test_prey_starts_where_the_hunted_does() -> void:
	assert_almost_eq(_prey.global_position.x, 0.0, 0.5)
	assert_almost_eq(_prey.global_position.z, 8.0, 0.5)
	assert_eq(_prey.collision_layer, 1 << 2, "on the player layer")


func test_wandering_makes_walk_footsteps() -> void:
	await wait_seconds(2.0)
	assert_eq(_prey.get_state(), PreyBrain.State.WANDER)
	assert_gt(_steps.size(), 0)
	assert_eq(_steps[0].noise_range, NoiseBus.settings.walk_range)


func test_hearing_the_monster_run_makes_it_flee() -> void:
	var near := _prey.global_position + Vector3(6, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, _avatar.settings.run_range, _avatar)
	await wait_physics_frames(2)
	assert_eq(_prey.get_state(), PreyBrain.State.FLEE)
	await wait_seconds(1.0)
	assert_eq(_steps.back().noise_range, NoiseBus.settings.sprint_range)


func test_a_walking_monster_five_meters_away_is_not_heard() -> void:
	var near := _prey.global_position + Vector3(5, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, _avatar.settings.walk_range, _avatar)
	await wait_physics_frames(2)
	assert_eq(_prey.get_state(), PreyBrain.State.WANDER)


func test_sees_the_monster_in_front() -> void:
	_prey.process_mode = Node.PROCESS_MODE_DISABLED
	_prey.global_position = Vector3(12, 0, -16)
	_prey.look_at(Vector3(12, 0, -6), Vector3.UP)
	_avatar.global_position = Vector3(12, 0, -6)
	assert_true(_prey.can_see_monster())
	_prey.sees_monster = true
	_prey.process_mode = Node.PROCESS_MODE_INHERIT
	await wait_physics_frames(2)
	assert_eq(_prey.get_state(), PreyBrain.State.FLEE)


func test_does_not_see_the_monster_behind() -> void:
	_prey.process_mode = Node.PROCESS_MODE_DISABLED
	_prey.global_position = Vector3(12, 0, -16)
	_prey.look_at(Vector3(12, 0, -19), Vector3.UP)
	_avatar.global_position = Vector3(12, 0, -6)
	assert_false(_prey.can_see_monster())
	_prey.look_at(Vector3(12, 0, -6), Vector3.UP)
	_avatar.global_position = Vector3(12, 0, 2)
	assert_false(_prey.can_see_monster(), "too far: 18 m")
