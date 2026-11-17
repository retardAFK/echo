extends GutTest
## The mix (spec S-012, T-147): levels set from the measures in the browser.

const AUDIO := preload("res://game/data/audio_settings.tres")


func test_godot_does_not_fade_our_sounds_towards_their_range() -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = preload("res://assets/audio/steps/step_concrete_0.wav")
	player.max_distance = 14.0
	add_child_autofree(player)
	SoundSpace.play(player)
	assert_eq(player.max_distance, 0.0, "its own fade cut the sounds in the browser")
	assert_eq(SoundSpace.range_of(player), 14.0, "the range is kept aside")


func test_the_loudest_noises_are_turned_down() -> void:
	assert_lt(AUDIO.level_db(NoiseEvent.Type.CAR_ALARM), 0.0)
	assert_lt(AUDIO.level_db(NoiseEvent.Type.SCREAM), 0.0)
	assert_eq(AUDIO.level_db(NoiseEvent.Type.FOOTSTEP), 0.0)


func test_one_s_own_steps_stay_softer_than_the_others() -> void:
	var settings := NoiseBus.settings
	var own_run := SoundMath.self_db(settings.sprint_range, settings.walk_range, AUDIO)
	assert_lte(own_run, AUDIO.self_max_db)
	assert_lte(AUDIO.self_max_db, -12.0)


func test_the_mixing_bench_goes_through_its_moments() -> void:
	var role := GameSession.role
	var game_seed := GameSession.game_seed
	var bench: MixBench = load("res://game/bench/mix_bench.tscn").instantiate()
	add_child_autofree(bench)
	assert_eq(bench.get("_index"), 0)
	assert_eq(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Musique")),
		SoundMath.SILENT_DB,
		"the music is quiet while the footsteps are measured"
	)
	for i in MixBench.SCENES.size():
		bench.call("_next")
	assert_eq(bench.get("_index"), MixBench.SCENES.size(), "done")
	for bus in [&"Effets", &"Musique", &"Ambiance", &"Voix"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), 0.0)
	GameSession.role = role  # The bench plays the monster: not the next tests.
	GameSession.game_seed = game_seed
