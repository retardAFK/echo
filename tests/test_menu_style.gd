extends GutTest
## Menu look and menu entries (spec S-013, T-162).

const THEME := preload("res://game/ui/theme/echo_theme.tres")
const NOISE := preload("res://game/data/noise_settings.tres")
const BUILDER := preload("res://tools/godot/build_menu_theme.gd")


func test_theme_never_uses_the_noise_orange() -> void:
	for type in THEME.get_type_list():
		for name in THEME.get_color_list(type):
			var color := THEME.get_color(name, type)
			assert_false(color.is_equal_approx(NOISE.noise_color), "%s/%s" % [type, name])
	for color in [MenuStyle.SODIUM, MenuStyle.CREAM, MenuStyle.TEXT]:
		assert_gt(_distance(color, NOISE.noise_color), 0.2, "sodium stays apart from the noise")


func test_theme_file_matches_the_style() -> void:
	var built := BUILDER.build()
	for type in ["MenuItem", "TitleLabel", "CodeLabel", "LcdLabel"]:
		assert_true(THEME.has_font_size("font_size", type), type)
		assert_eq(THEME.get_font_size("font_size", type), built.get_font_size("font_size", type))
	assert_eq(THEME.get_color("font_color", "MenuItem"), MenuStyle.TEXT)


func test_menu_list_builds_its_entries_and_goes_round() -> void:
	var list := MenuList.new()
	list.keys = PackedStringArray(["MENU_SOLO", "MENU_ONLINE", "MENU_BACK"])
	add_child_autofree(list)
	assert_eq(list.get_child_count(), 3)
	var first := list.item("MENU_SOLO")
	var last := list.item("MENU_BACK")
	assert_eq(first.get_node(first.focus_neighbor_top), last)
	assert_eq(last.get_node(last.focus_neighbor_bottom), first)
	list.set_item_visible("MENU_BACK", false)
	var online := list.item("MENU_ONLINE")
	assert_eq(online.get_node(online.focus_neighbor_bottom), first, "hidden entries are skipped")


func test_menu_list_says_which_entry_was_chosen() -> void:
	var list := MenuList.new()
	list.keys = PackedStringArray(["MENU_SOLO", "MENU_BACK"])
	add_child_autofree(list)
	watch_signals(list)
	list.item("MENU_BACK").pressed.emit()
	assert_signal_emitted_with_parameters(list, "chosen", ["MENU_BACK"])


func test_the_entry_with_the_focus_is_lit() -> void:
	var list := MenuList.new()
	list.theme = THEME
	list.keys = PackedStringArray(["MENU_SOLO", "MENU_BACK"])
	add_child_autofree(list)
	list.focus_first()
	assert_true(list.item("MENU_SOLO").is_lit())
	assert_false(list.item("MENU_BACK").is_lit())
	list.item("MENU_BACK").mouse_entered.emit()
	assert_true(list.item("MENU_BACK").has_focus(), "the mouse moves the choice")
	assert_false(list.item("MENU_SOLO").is_lit())


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
