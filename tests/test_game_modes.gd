extends GutTest
## The list of game modes (spec S-024, Q26, T-375).


func test_the_traque_and_the_versus_are_listed() -> void:
	assert_true(GameModes.has(GameModes.HUNT))
	assert_true(GameModes.has(GameModes.VERSUS))
	assert_false(GameModes.has(&"nope"))
	assert_eq(GameModes.name_key(GameModes.VERSUS), "MODE_VERSUS")


func test_every_mode_has_a_translated_name() -> void:
	for entry in GameModes.LIST:
		var key: String = entry["name_key"]
		assert_ne(tr(key), key, key + " is in strings.csv")


func test_online_modes_start_with_the_traque_and_loop() -> void:
	var modes := GameModes.online()
	assert_eq(modes[0], GameModes.HUNT)
	assert_eq(GameModes.next_online(modes[-1]), modes[0], "back to the first")
	assert_eq(GameModes.next_online(&"nope"), modes[0])


func test_sanitize_falls_back_to_the_traque() -> void:
	assert_eq(GameModes.sanitize("versus"), GameModes.VERSUS)
	assert_eq(GameModes.sanitize(null), GameModes.HUNT)
	assert_eq(GameModes.sanitize("nope"), GameModes.HUNT)
