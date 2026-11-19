extends GutTest
## Digicode and intercom of the online menu (spec S-013, T-169).


func _digicode() -> Digicode:
	var digicode := Digicode.new()
	add_child_autofree(digicode)
	return digicode


func _key(keycode: Key, unicode := 0) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.unicode = unicode
	event.pressed = true
	return event


func test_digicode_has_a_key_per_code_letter() -> void:
	var digicode := _digicode()
	var keys := digicode.find_children("", "Button", true, false)
	assert_eq(keys.size(), RoomCode.LETTERS.length() + 2, "letters, erase and OK")


func test_digicode_types_erases_and_shows_missing_letters() -> void:
	var digicode := _digicode()
	assert_eq(digicode.display_text(), "____")
	digicode.type_letter("K")
	digicode.type_letter("O")  # Not a code letter.
	digicode.type_letter("M")
	assert_eq(digicode.display_text(), "KM__")
	digicode.erase()
	assert_eq(digicode.code, "K")


func test_digicode_sends_the_fourth_letter() -> void:
	var digicode := _digicode()
	watch_signals(digicode)
	for letter in "KMRB":
		digicode.type_letter(letter)
	assert_signal_emitted_with_parameters(digicode, "submitted", ["KMRB"])
	digicode.type_letter("A")
	assert_eq(digicode.code, "KMRB", "no fifth letter")


func test_digicode_reads_the_keyboard() -> void:
	var digicode := _digicode()
	digicode._unhandled_key_input(_key(KEY_K, "k".unicode_at(0)))
	digicode._unhandled_key_input(_key(KEY_M, "m".unicode_at(0)))
	digicode._unhandled_key_input(_key(KEY_BACKSPACE))
	assert_eq(digicode.code, "K")
	watch_signals(digicode)
	digicode._unhandled_key_input(_key(KEY_ENTER))
	assert_signal_emitted_with_parameters(digicode, "submitted", ["K"])


func _state() -> LobbyState:
	var state := LobbyState.new()
	state.code = "KMRB"
	for player in [1, 2, 3]:
		state.add_player(player)
	state.seats = [1, 2, 3, 0] as Array[int]
	state.set_ready(2, true)
	return state


func test_intercom_tags_and_lamps() -> void:
	var intercom := Intercom.new()
	add_child_autofree(intercom)
	var state := _state()
	intercom.show_state(state, 2)
	assert_eq(
		Intercom.tag_text(state, 0, 2), tr("LOBBY_PLAYER") % 1 + " · " + tr("LOBBY_LEADER_TAG")
	)
	assert_eq(Intercom.tag_text(state, 1, 2), tr("LOBBY_YOU"))
	assert_eq(Intercom.tag_text(state, 3, 2), tr("LOBBY_AI"))
	assert_false(intercom.is_lamp_lit(0))
	assert_true(intercom.is_lamp_lit(1), "player 2 is ready")
	assert_false(intercom.is_lamp_lit(3), "an AI has no lamp")


func test_intercom_shows_every_seat_and_hides_roles_until_drawn() -> void:
	var intercom := Intercom.new()
	add_child_autofree(intercom)
	var state := _state()
	intercom.show_state(state, 2)
	for seat in LobbyState.SEATS:
		assert_true(intercom.is_seat_shown(seat))
	assert_eq(intercom.get_role_text(1), "?", "roles drawn at launch")
	state.game_size = 3
	intercom.show_state(state, 2)
	assert_true(intercom.is_seat_shown(3), "played by an AI (S-020, T-314)")
	state.started = true
	intercom.show_state(state, 2)
	assert_eq(intercom.get_role_text(0), LobbyMenu.seat_name(0).to_upper())


func test_lobby_menu_starts_on_create_or_join() -> void:
	var menu: LobbyMenu = preload("res://game/ui/lobby_menu.tscn").instantiate()
	menu.change_scene = false
	add_child_autofree(menu)
	assert_true(menu.get_node("%Entry").visible)
	assert_false(menu.get_node("%Room").visible)
	assert_true(menu.get_node("%EntryList").item("LOBBY_CREATE").has_focus())
	menu.get_node("%Digicode").type_letter("K")
	menu.get_node("%EntryList").item("LOBBY_JOIN").pressed.emit()
	assert_eq(menu.get_status(), LobbyMenu.error_text("bad_code"))
