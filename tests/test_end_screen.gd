extends GutTest
## End of a game and end screen (spec S-007, T-056).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")


func after_each() -> void:
	get_tree().paused = false
	GameSession.role = GameSession.Role.HUNTED


func _make_map() -> GameMap:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	map.end_screen.change_scene = false
	return map


func test_titles_and_duration() -> void:
	assert_eq(EndScreen.title_key(GameSession.Role.HUNTED, true), "END_ESCAPED")
	assert_eq(EndScreen.title_key(GameSession.Role.HUNTED, false), "END_CAUGHT")
	assert_eq(EndScreen.title_key(GameSession.Role.MONSTER, true), "END_PREY_ESCAPED")
	assert_eq(EndScreen.title_key(GameSession.Role.MONSTER, false), "END_PREY_CAUGHT")
	assert_eq(EndScreen.format_duration(545.7), "9 min 05 s")


func test_a_caught_hunted_loses_at_once() -> void:
	var map := _make_map()
	var player: Player = map.get_node("Player")
	var before := player.global_position
	map.get_node("Monster").player_caught.emit()
	assert_true(map.game_loop.is_over)
	assert_false(map.game_loop.hunted_won)
	assert_eq(player.global_position, before, "no respawn in solo (Q5)")
	assert_true(map.end_screen.visible)
	assert_true(get_tree().paused, "the game stops behind the end screen")
	assert_eq(map.end_screen.get_node("%Title").text, "END_CAUGHT")
	var stats: String = map.end_screen.get_node("%Stats").text
	assert_eq(stats.split("\n").size(), 5, "duration, fuses, noises, scans, ruses (S-008)")
	assert_string_contains(stats, "0/3")


func test_replay_and_menu_buttons() -> void:
	var map := _make_map()
	watch_signals(map.end_screen)
	map.game_loop.finish(true)
	assert_eq(map.end_screen.get_node("%Title").text, "END_ESCAPED")
	map.end_screen.get_node("%ReplayButton").pressed.emit()
	assert_signal_emitted(map.end_screen, "replay_requested")
	assert_false(get_tree().paused)
	map.end_screen.get_node("%MenuButton").pressed.emit()
	assert_signal_emitted(map.end_screen, "menu_requested")


func test_the_end_screen_counts_noises_and_scans() -> void:
	var map := _make_map()
	var player: Player = map.get_node("Player")
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, player.global_position, 4.0, player)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, player.global_position, 4.0, player)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, player.global_position, 4.0, null)
	var building: Building = map.get_buildings()[0]
	building.scan_changed.emit(true)
	building.scan_changed.emit(false)
	assert_eq(map.game_loop.noise_count, 2, "only the hunted's noises")
	assert_eq(map.game_loop.scan_count, 1)
	map.game_loop.finish(false)
	var stats: String = map.end_screen.get_node("%Stats").text
	assert_string_contains(stats, "2")
	assert_string_contains(stats, "1")


func test_in_the_monster_role_catching_the_prey_wins() -> void:
	GameSession.role = GameSession.Role.MONSTER
	var map := _make_map()
	assert_eq(map.game_loop.hunted, map.prey, "the AI prey looks for the fuses")
	assert_false(
		map.get_children().any(func(node: Node) -> bool: return node is LoopHud),
		"no fuse counter for the monster"
	)
	map.avatar.global_position = map.prey.global_position + Vector3(0.5, 0, 0)
	await wait_physics_frames(2)
	assert_true(map.game_loop.is_over)
	get_tree().paused = false
	assert_eq(map.end_screen.get_node("%Title").text, "END_PREY_CAUGHT")
	assert_eq(map.avatar.catch_count, 1)


func test_each_game_draws_new_fuses() -> void:
	var draws := {}
	for i in 4:
		var map: GameMap = MAP_SCENE.instantiate()
		add_child(map)
		var names := []
		for box: FuseBox in map.game_loop.fused_boxes:
			names.append(str(box.get_path()))
		names.sort()
		draws[str(names)] = true
		map.free()
	assert_gt(draws.size(), 1)


func test_summary_to_copy() -> void:
	var map := _make_map()
	map.game_loop.finish(false)
	var summary: String = map.end_screen.summary
	var lines := summary.split("\n")
	assert_eq(lines.size(), 9, "header, role, result, 5 figures, fps (S-009, Q7)")
	assert_string_contains(lines[0], RunSummary.build_version())
	assert_string_contains(summary, tr("MENU_PLAY_HUNTED"))
	assert_string_contains(summary, tr("END_CAUGHT"))
	assert_string_contains(summary, "0/3")
	map.end_screen.get_node("%CopyButton").pressed.emit()
	assert_eq(map.end_screen.get_node("%CopyButton").text, tr("END_COPIED"))


func test_build_version_defaults_to_dev() -> void:
	assert_eq(RunSummary.build_version(), "dev")


func test_average_fps_of_the_game() -> void:
	var loop := GameLoop.new()
	assert_eq(loop.get_average_fps(), 0.0)
	for i in 30:
		loop._process(1.0 / 30.0)
	assert_almost_eq(loop.get_average_fps(), 30.0, 0.01)
	loop.free()
