extends GutTest
## Player settings and the options screen (spec S-013, Q4 and Q5, T-163).

const TEST_PATH := "user://test_settings.cfg"
const OPTIONS_SCENE := preload("res://game/ui/options_menu.tscn")

var _saved_path := ""


func before_each() -> void:
	_saved_path = Settings.path
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	Settings.load_file()


func after_each() -> void:
	Settings.reset()
	DirAccess.remove_absolute(TEST_PATH)
	Settings.path = _saved_path
	Settings.load_file()


func test_values_survive_a_reload() -> void:
	Settings.set_value("volume_music", 0.3)
	Settings.set_value("invert_y", true)
	Settings.set_value("keyboard", "qwerty")
	Settings.set_key("interact", KEY_F)
	Settings.load_file()
	assert_almost_eq(float(Settings.get_value("volume_music")), 0.3, 0.001)
	assert_true(Settings.get_value("invert_y"))
	assert_eq(Settings.get_value("keyboard"), "qwerty")
	assert_eq(Settings.key_of("interact"), KEY_F)


func test_broken_values_go_back_to_their_default() -> void:
	var file := ConfigFile.new()
	file.set_value(UserSettings.SECTION, "fov", "large")
	file.set_value(UserSettings.SECTION, "brightness", 9.0)
	file.set_value(UserSettings.SECTION, "keyboard", "dvorak")
	file.set_value(UserSettings.KEYS_SECTION, "sprint", "Maj")
	file.save(TEST_PATH)
	Settings.load_file()
	assert_eq(Settings.get_value("fov"), UserSettings.default_of("fov"))
	assert_eq(Settings.get_value("brightness"), 1.6, "clamped to the highest value")
	assert_eq(Settings.get_value("keyboard"), "azerty")
	assert_eq(Settings.key_of("sprint"), KEY_SHIFT)


func test_numbers_snap_to_their_step() -> void:
	assert_almost_eq(float(UserSettings.sanitize("fov", 77.0)), 75.0, 0.001)
	assert_almost_eq(float(UserSettings.sanitize("volume_master", -2.0)), 0.0, 0.001)
	Settings.set_value("sensitivity", 1.0)
	Settings.step("sensitivity", 1)
	assert_almost_eq(float(Settings.get_value("sensitivity")), 1.25, 0.001)
	Settings.step("keyboard", 1)
	assert_eq(Settings.get_value("keyboard"), "qwerty")
	Settings.step("keyboard", 1)
	assert_eq(Settings.get_value("keyboard"), "azerty", "choices go round")


func test_volumes_set_their_bus() -> void:
	for bus in ["Master", "Effets", "Ambiance", "Musique"]:
		assert_gt(AudioServer.get_bus_index(bus), -1, bus)
	Settings.set_value("volume_ambience", 0.5)
	var index := AudioServer.get_bus_index("Ambiance")
	assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.5), 0.01)
	Settings.set_value("volume_ambience", 0.0)
	assert_true(AudioServer.is_bus_mute(index))


func test_sounds_go_to_their_bus() -> void:
	var ambience := Node.new()
	ambience.name = "Ambience"
	var wind := AudioStreamPlayer.new()
	ambience.add_child(wind)
	var bottle := AudioStreamPlayer3D.new()
	add_child_autofree(ambience)
	add_child_autofree(bottle)
	assert_eq(wind.bus, &"Ambiance")
	assert_eq(bottle.bus, &"Effets")


func test_a_new_key_moves_the_action_and_swaps_a_taken_key() -> void:
	var interact := Settings.key_of("interact")
	Settings.set_key("sprint", interact)
	assert_eq(Settings.key_of("sprint"), interact)
	assert_eq(Settings.key_of("interact"), KEY_SHIFT, "interact takes the old sprint key")
	var event := InputEventKey.new()
	event.physical_keycode = interact
	event.pressed = true
	assert_true(event.is_action("sprint"), "the input map follows")
	Settings.set_key("sprint", KEY_ESCAPE)
	assert_eq(Settings.key_of("sprint"), interact, "Escape stays the pause key")


func test_key_names_follow_the_keyboard() -> void:
	Settings.set_value("keyboard", "azerty")
	assert_eq(Settings.fill("{move} ou flèches"), "ZQSD ou flèches")
	Settings.set_value("keyboard", "qwerty")
	assert_eq(Settings.fill("{move} ou flèches"), "WASD ou flèches")
	Settings.set_key("interact", KEY_F)
	assert_eq(Settings.fill(tr("HUD_INTERACT_HIDE")), "Maintenir F : se cacher")
	assert_string_contains(ControlsText.controls(GameSession.Role.HUNTED), "F : ramasser")


func test_look_follows_sensitivity_and_inversion() -> void:
	Settings.set_value("sensitivity", 2.0)
	assert_eq(Settings.adjust_look(Vector2(1, 1)), Vector2(2, 2))
	Settings.set_value("invert_y", true)
	assert_eq(Settings.adjust_look(Vector2(1, 1)), Vector2(2, -2))


func test_options_screen_changes_values_with_the_keyboard() -> void:
	var options: OptionsMenu = OPTIONS_SCENE.instantiate()
	add_child_autofree(options)
	options.open()
	var row: OptionRow = options.get_rows()[0]
	assert_eq(row.setting, "volume_master")
	assert_true(row.has_focus())
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	row._gui_input(right)
	assert_almost_eq(float(Settings.get_value("volume_master")), 0.9, 0.001)
	options.show_tab(3)
	var key_row: OptionRow = options.get_rows()[1]
	assert_eq(key_row.setting, "move_forward")
	key_row._pressed()
	assert_true(key_row.waiting)
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.physical_keycode = KEY_UP
	key.pressed = true
	key_row._gui_input(key)
	assert_eq(Settings.key_of("move_forward"), KEY_UP)
	assert_false(key_row.waiting)


func test_options_from_the_home_screen_and_back() -> void:
	var menu: StartMenu = preload("res://game/ui/start_menu.tscn").instantiate()
	menu.change_scene = false
	add_child_autofree(menu)
	menu.get_node("%MainList").item("MENU_OPTIONS").pressed.emit()
	assert_true(menu.get_node("%Options").visible)
	assert_false(menu.get_node("%Home").visible)
	menu.get_node("%Options").close()
	assert_true(menu.get_node("%Home").visible)


func test_fullscreen_follows_the_window_and_is_never_saved() -> void:
	assert_true(InputMap.has_action("toggle_fullscreen"))
	watch_signals(Settings)
	Settings.set_value("fullscreen", true)
	assert_signal_emitted_with_parameters(Settings, "changed", ["fullscreen"])
	assert_eq(Settings.get_value("fullscreen"), Settings.is_fullscreen())
	var file := ConfigFile.new()
	file.load(TEST_PATH)
	assert_false(file.has_section_key(UserSettings.SECTION, "fullscreen"))
	Settings.set_value("fullscreen", false)
	assert_false(Settings.get_value("fullscreen"))


func test_the_image_tab_offers_fullscreen() -> void:
	var options: OptionsMenu = OPTIONS_SCENE.instantiate()
	add_child_autofree(options)
	options.show_tab(2)
	var settings: Array[String] = []
	for row in options.get_rows():
		settings.append(row.setting)
	assert_has(settings, "fullscreen")


func test_the_buses_come_from_the_project_layout() -> void:
	# Buses added while the game ran were silent in the browser (T-163).
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	for key: String in UserSettings.BUSES:
		if key != "volume_master":
			assert_eq(
				layout.get("bus/%d/name" % (UserSettings.BUSES.keys().find(key))),
				StringName(UserSettings.BUSES[key])
			)
