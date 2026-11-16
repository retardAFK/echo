extends GutTest
## The loading screen (spec S-013, T-166): the map loads in steps with a
## progress, a tip of the role is shown, and the first steps of a role wait
## for Enter the first time only.

const SCENE := preload("res://game/ui/loading_screen.tscn")
const MAP_SCENE_PATH := "res://game/maps/tilleuls/tilleuls.tscn"
const SMALL_PATH := "res://game/ui/end_screen.tscn"

var _flags := {}


func before_each() -> void:
	for role in [GameSession.Role.HUNTED, GameSession.Role.MONSTER]:
		_flags[role] = Settings.get_value(LoadingScreen.flag_of(role))


func after_each() -> void:
	for role: GameSession.Role in _flags:
		Settings.set_value(LoadingScreen.flag_of(role), _flags[role])
	GameSession.role = GameSession.Role.HUNTED


func _screen(path: String, role: GameSession.Role, seen: bool) -> LoadingScreen:
	GameSession.role = role
	Settings.set_value(LoadingScreen.flag_of(role), seen)
	LoadingScreen.target = path
	var screen: LoadingScreen = SCENE.instantiate()
	screen.change_scene = false
	add_child_autofree(screen)
	return screen


func test_every_tip_is_written() -> void:
	for role in [GameSession.Role.HUNTED, GameSession.Role.MONSTER]:
		for first in [true, false]:
			var keys := LoadingScreen.tip_keys(role, first)
			assert_gt(keys.size(), 0)
			for key in keys:
				assert_ne(tr(key), key, "%s is translated" % key)
				assert_false(Settings.fill(tr(key)).contains("{"), "%s has its keys filled" % key)


func test_it_loads_the_map_in_steps_and_hands_it_over() -> void:
	var screen := _screen(MAP_SCENE_PATH, GameSession.Role.HUNTED, true)
	var seen: Array[float] = []
	screen.progressed.connect(func(value: float) -> void: seen.append(value))
	watch_signals(screen)
	await wait_until(func() -> bool: return get_signal_emit_count(screen, "loaded") > 0, 30)
	assert_signal_emitted(screen, "loaded")
	assert_has(seen, LoadingScreen.AFTER_DEPENDENCIES, "dependencies first: %s" % [seen])
	assert_has(seen, LoadingScreen.AFTER_SCENE, "then the scene")
	assert_eq(seen.back(), 1.0, "then its instance")
	for i in range(1, seen.size()):
		assert_gte(seen[i], seen[i - 1], "the bar never goes back")
	var map: Node = get_signal_parameters(screen, "loaded")[0]
	assert_true(map is GameMap)
	map.free()


func test_a_tip_of_the_role_once_its_first_steps_are_read() -> void:
	var screen := _screen(SMALL_PATH, GameSession.Role.MONSTER, true)
	var tips: Array = LoadingScreen.tip_keys(GameSession.Role.MONSTER, false).map(
		func(key: String) -> String: return Settings.fill(tr(key))
	)
	assert_has(tips, screen.get_tips())
	watch_signals(screen)
	await wait_process_frames(10)
	assert_signal_emitted(screen, "loaded", "no wait")
	assert_false(screen.is_waiting())
	(get_signal_parameters(screen, "loaded")[0] as Node).free()


func test_the_first_time_it_shows_the_first_steps_and_waits_for_enter() -> void:
	var screen := _screen(SMALL_PATH, GameSession.Role.HUNTED, false)
	var first := Settings.fill(tr("TIP_HUNTED_FIRST_1"))
	assert_true(screen.get_tips().begins_with(first))
	watch_signals(screen)
	await wait_process_frames(10)
	assert_true(screen.is_waiting())
	assert_signal_not_emitted(screen, "loaded")
	var enter := InputEventAction.new()
	enter.action = &"ui_accept"
	enter.pressed = true
	screen._unhandled_input(enter)
	assert_signal_emitted(screen, "loaded")
	assert_true(Settings.get_value(LoadingScreen.flag_of(GameSession.Role.HUNTED)), "read")
	(get_signal_parameters(screen, "loaded")[0] as Node).free()


func test_online_it_never_waits() -> void:
	GameSession.role = GameSession.Role.HUNTED
	Settings.set_value(LoadingScreen.flag_of(GameSession.Role.HUNTED), false)
	LoadingScreen.target = SMALL_PATH
	var screen: LoadingScreen = SCENE.instantiate()
	screen.change_scene = false
	screen.wait_first_time = false
	add_child_autofree(screen)
	watch_signals(screen)
	await wait_process_frames(10)
	assert_signal_emitted(screen, "loaded")
	assert_false(Settings.get_value(LoadingScreen.flag_of(GameSession.Role.HUNTED)))
	(get_signal_parameters(screen, "loaded")[0] as Node).free()
