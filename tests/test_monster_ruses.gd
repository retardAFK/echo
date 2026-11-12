extends GutTest
## The AI monster against the ruses (spec S-008, T-066): it opens the hiding
## spot it saw the hunted get into, and sometimes the one next to where it
## lost a chase.

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const SETTINGS := preload("res://game/data/monster_settings.tres")


func _brain() -> MonsterBrain:
	var brain := MonsterBrain.new(SETTINGS)
	var points: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10, 0, 0)]
	brain.set_patrol(points)
	return brain


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.search_hide_radius, 8.0, "Q7: the spot next to where it lost the hunted")
	assert_eq(SETTINGS.search_open_chance, 0.5, "Q7: one time out of two")


func test_brain_goes_to_open_and_ignores_noises_meanwhile() -> void:
	var brain := _brain()
	var front := Vector3(4, 0, 4)
	brain.go_open(front)
	assert_eq(brain.state, MonsterBrain.State.OPEN)
	assert_eq(brain.target, front)
	assert_eq(brain.get_pace(), MonsterBrain.Pace.RUN)
	brain.hear(Vector3(20, 0, 20))
	assert_eq(brain.state, MonsterBrain.State.OPEN, "a bottle does not distract it now")
	assert_false(brain.is_opening(false))
	assert_true(brain.is_opening(true))


func test_after_opening_it_searches_then_patrols() -> void:
	var brain := _brain()
	brain.go_open(Vector3(4, 0, 4))
	brain.done_opening()
	assert_eq(brain.state, MonsterBrain.State.SEARCH)
	assert_true(brain.lingering)
	brain.update(SETTINGS.search_time + 0.1, false, Vector3.ZERO, 50.0, false, true)
	assert_eq(brain.state, MonsterBrain.State.PATROL)


func test_seeing_the_hunted_beats_opening() -> void:
	var brain := _brain()
	brain.go_open(Vector3(4, 0, 4))
	brain.spot_level = 1.0
	brain.update(0.1, true, Vector3(2, 0, 2), 3.0, false, false)
	assert_eq(brain.state, MonsterBrain.State.CHASE)


func test_losing_a_chase_tells_where() -> void:
	var brain := _brain()
	watch_signals(brain)
	brain.spot_level = 1.0
	brain.update(0.1, true, Vector3(3, 0, 1), 3.0, false, false)
	assert_eq(brain.state, MonsterBrain.State.CHASE)
	brain.update(SETTINGS.lose_sight_time + 0.1, false, Vector3.ZERO, 50.0, false, false)
	assert_eq(brain.state, MonsterBrain.State.SEARCH)
	assert_signal_emitted_with_parameters(brain, "chase_lost", [Vector3(3, 0, 1)])


func _setup_map() -> Array:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var closet: HidingSpot = map.get_node("Closet")
	var player: Player = map.get_node("Player")
	var monster: Monster = map.get_node("Monster")
	await wait_physics_frames(10)
	return [map, closet, player, monster]


func test_the_monster_opens_the_spot_and_catches_who_is_inside() -> void:
	var setup: Array = await _setup_map()
	var closet: HidingSpot = setup[1]
	var player: Player = setup[2]
	var monster: Monster = setup[3]
	player.global_position = closet.get_exit_point()
	await wait_physics_frames(3)
	closet.hold(player, 1.1)
	closet.release(player)
	assert_true(player.is_hidden())
	monster.global_position = closet.get_exit_point() + Vector3(0, 0, 4)
	watch_signals(closet)
	monster.go_open(closet)
	await wait_for_signal(closet.found, 6.0)
	assert_signal_emitted(closet, "found")
	assert_false(player.is_hidden(), "caught and out")


func test_the_monster_never_sees_nor_touches_a_hidden_hunted() -> void:
	var setup: Array = await _setup_map()
	var closet: HidingSpot = setup[1]
	var player: Player = setup[2]
	var monster: Monster = setup[3]
	player.global_position = closet.get_exit_point()
	await wait_physics_frames(3)
	closet.hold(player, 1.1)
	closet.release(player)
	watch_signals(monster)
	# Right next to the closet, looking at it, patrolling: no sight, no catch.
	monster.global_position = closet.global_position + Vector3(0, 0, 1.0)
	await wait_physics_frames(30)
	assert_false(monster.sees_player)
	assert_signal_not_emitted(monster, "player_caught")


func test_a_lost_chase_next_to_a_spot_may_open_it() -> void:
	var setup: Array = await _setup_map()
	var closet: HidingSpot = setup[1]
	var monster: Monster = setup[3]
	monster.rng.seed = 1
	var opened := 0
	for i in 20:
		monster.brain.set_patrol(monster.get_patrol_points())
		monster.open_target = null
		monster._on_chase_lost(closet.global_position + Vector3(2, 0, 2))
		if monster.open_target == closet:
			opened += 1
	assert_between(opened, 4, 16, "about one time out of two")
	monster.brain.set_patrol(monster.get_patrol_points())
	monster.open_target = null
	monster._on_chase_lost(closet.global_position + Vector3(30, 0, 0))
	assert_null(monster.open_target, "too far from any hiding spot")
