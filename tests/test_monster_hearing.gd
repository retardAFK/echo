extends GutTest
## Monster hearing and investigation in the greybox (spec S-003, T-016).

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
## Open ground in the north of the greybox, no wall between these points.
const OPEN_SPOT := Vector3(0, 0, -16)
## Inside the east room of the test building.
const ROOM_SPOT := Vector3(-11, 0, 13)
const WALK_FRAMES := 120

var _map: Node3D
var _monster: Monster
var _noise: NoiseSettings = NoiseBus.settings


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_monster = _map.get_node("Monster")
	await wait_physics_frames(2)


func _place(position: Vector3) -> void:
	_monster.global_position = position
	_monster.force_update_transform()


func _emit(position: Vector3, noise_range: float, source: Node = null) -> void:
	NoiseBus.emit_noise(
		NoiseEvent.Type.FOOTSTEP, position + Vector3.UP * _noise.emit_height, noise_range, source
	)


func test_hears_sprint_at_ten_meters_in_open() -> void:
	_place(OPEN_SPOT)
	_emit(OPEN_SPOT + Vector3(10, 0, 0), _noise.sprint_range)
	assert_eq(_monster.get_state(), MonsterBrain.State.INVESTIGATE)
	assert_eq(_monster.brain.get_pace(), MonsterBrain.Pace.WALK)


func test_does_not_hear_walk_at_six_meters() -> void:
	_place(OPEN_SPOT)
	_emit(OPEN_SPOT + Vector3(6, 0, 0), _noise.walk_range)
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL)


func test_hears_walk_close_by() -> void:
	_place(OPEN_SPOT)
	_emit(OPEN_SPOT + Vector3(2, 0, 0), _noise.walk_range)
	assert_eq(_monster.get_state(), MonsterBrain.State.INVESTIGATE)


func test_wall_halves_what_it_hears() -> void:
	_place(ROOM_SPOT)
	_emit(ROOM_SPOT + Vector3(10, 0, 0), _noise.sprint_range)
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL, "14 m behind a wall = 7 m")
	_emit(ROOM_SPOT + Vector3(5, 0, 0), _noise.sprint_range)
	assert_eq(_monster.get_state(), MonsterBrain.State.INVESTIGATE)


func test_ignores_its_own_noise() -> void:
	_place(OPEN_SPOT)
	_emit(OPEN_SPOT + Vector3(1, 0, 0), _noise.sprint_range, _monster)
	assert_eq(_monster.get_state(), MonsterBrain.State.PATROL)


func test_walks_to_the_noise() -> void:
	_place(OPEN_SPOT)
	var noise_spot := OPEN_SPOT + Vector3(10, 0, 0)
	_emit(noise_spot, _noise.sprint_range)
	await wait_physics_frames(WALK_FRAMES)
	var distance := Vector2(
		_monster.global_position.x - noise_spot.x, _monster.global_position.z - noise_spot.z
	)
	assert_lt(distance.length(), 6.0, "closer to the noise after 2 s of walking")
