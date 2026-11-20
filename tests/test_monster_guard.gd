extends GutTest
## The AI monster in the game loop: drawn back to noisy buildings, guarding the
## tunnel once the exit is open, for a while at a time (spec S-007, T-057, T-060).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const LURE := Vector3(50, 0, 50)
const PLAYER_POS := Vector3(-3, 0, 2)

var _settings: MonsterSettings
var _brain: MonsterBrain
var _patrol: Array[Vector3] = [
	Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10), Vector3(0, 0, 10)
]
var _guard: Array[Vector3] = [Vector3(100, 0, 0), Vector3(110, 0, 0)]


func before_each() -> void:
	_settings = load("res://game/data/monster_settings.tres")
	_brain = MonsterBrain.new(_settings)
	_brain.set_patrol(_patrol)


func _step(arrived := false, delta := 0.1) -> void:
	_brain.update(delta, false, Vector3.ZERO, 0.0, false, arrived)


func test_settings_follow_the_spec() -> void:
	assert_eq(_settings.lure_memory_time, 120.0)
	assert_eq(_settings.lure_every, 3)


func test_it_comes_back_to_a_noisy_building_every_few_points() -> void:
	_brain.remember(LURE)
	for i in 2:
		_step(true)
		assert_ne(_brain.target, LURE)
	_step(true)
	assert_eq(_brain.target, LURE, "a detour after 3 points")
	assert_eq(_brain.state, MonsterBrain.State.PATROL)
	_step(true)
	assert_eq(_brain.target, _patrol[3], "then back to its round")


func test_it_forgets_the_building_after_a_while() -> void:
	_brain.remember(LURE)
	_step(false, _settings.lure_memory_time + 1.0)
	for i in 6:
		_step(true)
		assert_ne(_brain.target, LURE)


func test_without_a_noise_it_patrols_as_before() -> void:
	for i in 8:
		_step(true)
		assert_eq(_brain.target, _patrol[(i + 1) % _patrol.size()])


func test_once_the_exit_opens_it_guards_the_tunnel() -> void:
	_brain.guard(_guard)
	assert_eq(_brain.state, MonsterBrain.State.GUARD)
	assert_eq(_brain.target, _guard[0])
	assert_eq(_brain.get_pace(), MonsterBrain.Pace.WALK, "it hurries there")
	_step(true)
	assert_eq(_brain.target, _guard[1])
	_step(true)
	assert_eq(_brain.target, _guard[0], "to and fro")


func test_its_watch_ends_with_a_round_of_patrol_then_it_comes_back() -> void:
	assert_eq(_settings.guard_time, 60.0)
	assert_eq(_settings.guard_break, 45.0)
	_brain.guard(_guard)
	_step(false, _settings.guard_time - 1.0)
	assert_eq(_brain.state, MonsterBrain.State.GUARD)
	_step(false, 1.5)
	assert_eq(_brain.state, MonsterBrain.State.PATROL, "it leaves the tunnel")
	assert_false(_brain.guarding)
	assert_eq(_brain.target, _patrol[0], "back on its round")
	_step(false, _settings.guard_break + 0.5)
	assert_eq(_brain.state, MonsterBrain.State.GUARD, "and comes back")
	assert_eq(_brain.target, _guard[0])


func test_a_noise_or_a_chase_interrupts_the_guard_then_it_comes_back() -> void:
	_brain.guard(_guard)
	_brain.hear(LURE)
	assert_eq(_brain.state, MonsterBrain.State.INVESTIGATE)
	_step(true)
	_step(false, _settings.investigate_time + 0.1)
	assert_eq(_brain.state, MonsterBrain.State.GUARD)
	for i in 20:
		_brain.update(0.1, true, PLAYER_POS, 2.0, false, false)
	assert_eq(_brain.state, MonsterBrain.State.CHASE)
	_brain.guard(_guard)
	assert_eq(_brain.state, MonsterBrain.State.CHASE, "a chase goes on")


func test_in_the_cite_it_remembers_noises_made_inside_a_building() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	monster.player = null
	await wait_physics_frames(2)
	# A box out of the hospital's ventilation zones: there, a fuse's quiet noise
	# is lost in the roar by design (S-014, Q5), and the draw is random.
	var box: FuseBox = null
	for each: FuseBox in map.game_loop.fused_boxes:
		if box == null and not Ventilation.covers(get_tree(), each.global_position):
			box = each
	var outside := monster.global_position + Vector3(3, 1, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, outside, 10.0, null)
	assert_eq(monster.brain.lure_left, 0.0, "a noise in the street is not a building")
	monster.global_position = box.get_approach_point()
	NoiseBus.emit_noise(NoiseEvent.Type.FUSE, box.global_position, 3.0, null)
	assert_gt(monster.brain.lure_left, 0.0)
	assert_eq(monster.brain.lure, box.global_position)


func test_guard_points_are_on_the_navigation_mesh_by_the_tunnel() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var nav_map := map.get_world_3d().navigation_map
	var spawn: Vector3 = map.get_spawn_points()[0]
	await wait_until(
		func() -> bool:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, spawn)
			return closest.distance_to(spawn) < 0.5,
		5
	)
	var gate: Vector3 = map.get_node("ExitGate").global_position
	var points: Array = map.get_node("GuardPoints").get_children()
	assert_eq(points.size(), 3)
	for point: Node3D in points:
		var on_mesh := NavigationServer3D.map_get_closest_point(nav_map, point.global_position)
		assert_lt(on_mesh.distance_to(point.global_position), 0.5, point.name)
		assert_lt(point.global_position.distance_to(gate), 20.0)
