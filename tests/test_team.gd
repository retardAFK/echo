extends GutTest
## Several hunted (S-010, T-100): one team for the fuses and the exit, far
## apart start points, an AI monster that chases the one it sees.

const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")
const GREYBOX := preload("res://game/maps/greybox_test.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")


func _loop(members: Array[Node]) -> GameLoop:
	var loop := GameLoop.new()
	loop.settings = LOOP_SETTINGS
	loop.hunted = members[0]
	loop.team = members
	add_child_autofree(loop)
	return loop


func _members(count: int) -> Array[Node]:
	var found: Array[Node] = []
	for i in count:
		var member := Node3D.new()
		add_child_autofree(member)
		found.append(member)
	return found


func test_any_hunted_takes_fuses_and_places_only_its_own() -> void:
	var team := _members(3)
	var loop := _loop(team)
	loop._on_fuse_taken(team[1])
	loop._on_fuse_taken(team[1])
	loop._on_fuse_taken(team[2])
	loop._on_fuse_taken(Node3D.new())  # Not a hunted: ignored.
	assert_eq(loop.rules.found(), 3)
	assert_eq([loop.carried_by(team[0]), loop.carried_by(team[1])], [0, 2])
	loop.place_fuse(team[0])
	assert_eq(loop.rules.placed, 0, "nothing in its pockets")
	loop.place_fuse(team[1])
	loop.place_fuse(team[2])
	assert_eq([loop.rules.placed, loop.carried_by(team[1]), loop.carried_by(team[2])], [2, 1, 0])


func test_alone_the_hunted_carries_every_fuse_found() -> void:
	var team := _members(1)
	var loop := _loop(team)
	loop.rules.carried = 2
	assert_eq(loop.carried_by(team[0]), 2, "as in solo, where tests set the count")
	loop.place_fuse()
	assert_eq(loop.rules.placed, 1)


func test_the_team_wins_as_soon_as_one_gets_out() -> void:
	var team := _members(3)
	var loop := _loop(team)
	loop.rules.placed = loop.rules.fuse_count
	loop._on_exit_reached(team[2])
	assert_true(loop.is_over)
	assert_true(loop.hunted_won)


func test_the_monster_wins_once_none_is_free() -> void:
	var team := _members(3)
	var loop := _loop(team)
	loop.hunted_out(team[0])
	loop.hunted_out(team[0])
	loop.hunted_out(team[2])
	assert_false(loop.is_over)
	assert_eq(loop.free_count(), 1)
	loop.rules.placed = loop.rules.fuse_count
	loop._on_exit_reached(team[0])
	assert_false(loop.is_over, "out of the game, it cannot get out")
	loop.hunted_out(team[1])
	assert_true(loop.is_over)
	assert_false(loop.hunted_won)


func test_noises_of_every_hunted_count() -> void:
	var team := _members(2)
	var loop := _loop(team)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, 5.0, team[1])
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, Vector3.ZERO, 5.0, null)
	assert_eq(loop.noise_count, 1)


func test_start_points_are_far_apart() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var spots := [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(50, 0, 0), Vector3(0, 0, 50)]
	for at: Vector3 in spots:
		var marker := Marker3D.new()
		marker.position = at
		parent.add_child(marker)
	var rng := RandomNumberGenerator.new()
	for i in 20:
		rng.seed = i + 1
		var chosen := GameMap.far_apart(parent.get_children(), 3, 40.0, rng)
		assert_eq(chosen.size(), 3)
		for a: Node3D in chosen:
			for b: Node3D in chosen:
				if a != b:
					assert_gte(a.global_position.distance_to(b.global_position), 40.0)
	var crowded := GameMap.far_apart(parent.get_children(), 4, 40.0, rng)
	assert_eq(crowded.size(), 4, "the rest anywhere when the map is too small")


func test_the_cite_has_three_far_apart_start_points() -> void:
	var map: GameMap = load("res://game/maps/tilleuls/tilleuls.tscn").instantiate()
	add_child_autofree(map)
	var chosen := GameMap.far_apart(
		map.get_node("PlayerSpawns").get_children(),
		3,
		LOOP_SETTINGS.spawn_spacing,
		RandomNumberGenerator.new()
	)
	for a: Node3D in chosen:
		for b: Node3D in chosen:
			if a != b:
				assert_gte(a.global_position.distance_to(b.global_position), 40.0)


func test_the_ai_monster_chases_the_hunted_it_sees() -> void:
	var map: Node3D = GREYBOX.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	var first: Player = map.get_node("Player")
	var second: Player = PLAYER_SCENE.instantiate()
	map.add_child(second)
	monster.others.append(second)
	await wait_physics_frames(2)
	monster.set_physics_process(false)
	monster.global_position = Vector3(0, 0, -16)
	monster.look_at(Vector3(14, 0, -16), Vector3.UP)
	first.global_position = Vector3(-10, 0, -16)  # Behind it.
	second.global_position = Vector3(14, 0, -16)  # In front, in the open.
	for node: Node3D in [monster, first, second]:
		node.force_update_transform()
	monster._update_sight(1.0)
	assert_eq(monster.player, second, "the one in sight")
	assert_true(monster.sees_player)
	assert_eq(monster.others, [first] as Array[Node3D])
	watch_signals(monster)
	first.global_position = monster.global_position + Vector3(0.3, 0, 0)
	monster._physics_process(0.016)
	assert_signal_emitted_with_parameters(monster, "hunted_caught", [first])
	monster.forget(first)
	assert_eq(monster.get_targets(), [second] as Array[Node3D])
