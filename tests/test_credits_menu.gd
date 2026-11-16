extends GutTest
## The credits in game (spec S-013, T-167): CREDITS.md read and shown, from
## the home screen, without the repository paths or the development tools.

const START_MENU := preload("res://game/ui/start_menu.tscn")


func _menu() -> StartMenu:
	var menu: StartMenu = START_MENU.instantiate()
	menu.change_scene = false
	add_child_autofree(menu)
	return menu


func test_it_reads_the_tables_of_credits_md() -> void:
	var text := FileAccess.get_file_as_string(CreditsMenu.PATH)
	var entries := CreditsMenu.parse(text)
	var lines: Array = entries.map(func(entry: Array) -> String: return entry[1])
	assert_has(lines, "Assets faits par nous", "a section heading")
	assert_has(lines, "Moteur")
	assert_does_not_have(lines, "Outils de développement", "not in the game")
	var barlow := lines.filter(func(line: String) -> bool: return line.begins_with("Barlow"))
	assert_eq(barlow.size(), 1)
	assert_eq(
		barlow[0],
		(
			"Barlow et Barlow Condensed (polices des menus) · Jeremy Tribby, The Barlow Project"
			+ " Authors · SIL OFL 1.1"
		)
	)
	for line: String in lines:
		assert_false(line.contains("`"), "no path: %s" % line)
		assert_false(line.contains("GUT"), "no tool: %s" % line)
		assert_false(line.contains("|"))


func test_quaternius_and_godot_are_credited() -> void:
	var menu := _menu()
	menu.show_credits()
	var credits: CreditsMenu = menu.get_node("%Credits")
	assert_true(credits.visible)
	var text := "\n".join(credits.get_lines())
	assert_string_contains(text, "Quaternius · CC0")
	assert_string_contains(text, "Godot Engine")


func test_credits_is_on_the_home_screen_and_escape_goes_back() -> void:
	var menu := _menu()
	var list: MenuList = menu.get_node("%MainList")
	assert_not_null(list.item("MENU_CREDITS"))
	list.chosen.emit("MENU_CREDITS")
	var credits: CreditsMenu = menu.get_node("%Credits")
	assert_true(credits.visible)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	credits._unhandled_input(escape)
	assert_false(credits.visible)
	assert_true(menu.get_node("%Home").visible)
