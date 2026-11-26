extends GutTest
## The clock and the end of a Versus game (spec S-024, Q1 to Q4, Q28,
## T-380): dawn near, the boss's last phase, the end screen with the best
## player, the camera around the fallen boss.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT
	Engine.time_scale = 1.0
	get_tree().paused = false


func _open() -> VersusMode:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


func test_the_best_player_counts_damage_revives_and_face_hits() -> void:
	var versus := await _open()
	var stats := VersusStats.new(SETTINGS)
	var kit := versus.local_hunter()
	assert_eq(stats.mvp(versus.hunters), kit)
	stats.on_hit(kit.body, true, 30.0)
	stats.on_hit(kit.body, false, 20.0)
	kit.revives_done = 1
	assert_eq(stats.damage_of(kit), 50.0)
	assert_eq(stats.faces_of(kit), 1)
	assert_eq(stats.score(kit), 50.0 + SETTINGS.mvp_revive_points + SETTINGS.mvp_face_points)
	var lines := stats.lines(versus.hunters)
	assert_string_contains(lines[0], Text.t("VERSUS_YOU"))
	assert_string_contains(lines[0], "50")


func test_the_titles_say_who_won_and_how() -> void:
	var hunted := VersusRules.Winner.HUNTED
	var boss := VersusRules.Winner.BOSS
	assert_eq(VersusEndScreen.title_key(hunted, false, true), "VERSUS_HUNTED_WIN")
	assert_eq(VersusEndScreen.title_key(boss, true, false), "VERSUS_END_DAWN")
	assert_eq(VersusEndScreen.title_key(boss, false, false), "VERSUS_BOSS_WIN")
	assert_eq(VersusEndScreen.title_key(boss, false, true), "VERSUS_BOSS_WIN_YOU")


func test_dawn_near_sounds_the_siren_and_enrages_the_boss() -> void:
	var versus := await _open()
	watch_signals(NoiseBus)
	versus.rules.clock = SETTINGS.match_time - SETTINGS.dawn_warning + 0.5
	await wait_physics_frames(2)
	assert_true(versus.dawn_announced)
	assert_signal_emitted(NoiseBus, "noise_emitted", "the siren")
	assert_eq(versus.boss.health.phase, SETTINGS.phases.size() - 1, "its last phase")


func test_the_boss_wins_at_dawn_and_the_end_screen_shows_it() -> void:
	var versus := await _open()
	for connection in versus.finished.get_connections():
		versus.finished.disconnect(connection["callable"])  # Not the room's replay.
	versus.end_screen.change_scene = false
	versus.stats.on_hit(versus.local_hunter().body, true, 42.0)
	versus.rules.clock = SETTINGS.match_time - 0.01
	await wait_physics_frames(2)
	assert_eq(versus.rules.winner, VersusRules.Winner.BOSS)
	versus._end_left = 0.01
	await wait_physics_frames(2)
	assert_true(versus.end_screen.visible)
	assert_eq(versus.end_screen.title.text, Text.t("VERSUS_END_DAWN"))
	assert_string_contains(versus.end_screen.stats.text, "42")
	assert_string_contains(versus.end_screen.mvp_label.text, Text.t("VERSUS_YOU"))
	assert_string_contains(versus.end_screen.card, Text.t("VERSUS_END_DAWN"))
	assert_true(get_tree().paused)
	versus.end_screen.replay()
	assert_false(get_tree().paused)


func test_the_killing_blow_turns_a_camera_around_the_boss() -> void:
	var versus := await _open()
	var boss := versus.boss
	boss.health.take_hit(boss.health.max_health * 2.0)
	await wait_physics_frames(2)
	assert_eq(versus.rules.winner, VersusRules.Winner.HUNTED)
	var orbit := versus.get_node("OrbitCamera") as Camera3D
	assert_true(orbit.current)
	var first := orbit.global_position
	await wait_physics_frames(5)
	assert_ne(orbit.global_position, first, "it turns")
	assert_almost_eq(
		Vector2(orbit.global_position.x, orbit.global_position.z).distance_to(
			Vector2(boss.body.global_position.x, boss.body.global_position.z)
		),
		SETTINGS.orbit_distance,
		0.5
	)
