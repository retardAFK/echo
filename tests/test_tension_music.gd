extends GutTest
## The music's tension (spec S-012, Q9, T-146): levels by distance, kept a few
## seconds, layers slow to come and slower to go.

const AUDIO := preload("res://game/data/audio_settings.tres")


func test_levels_by_distance_without_direction() -> void:
	assert_eq(TensionMusic.target_level(-1.0, false, AUDIO), TensionMusic.Level.CALM, "no monster")
	assert_eq(TensionMusic.target_level(60.0, false, AUDIO), TensionMusic.Level.CALM)
	assert_eq(TensionMusic.target_level(35.0, false, AUDIO), TensionMusic.Level.UNEASE, "35 m")
	assert_eq(TensionMusic.target_level(20.0, false, AUDIO), TensionMusic.Level.UNEASE)
	assert_eq(TensionMusic.target_level(15.0, false, AUDIO), TensionMusic.Level.DREAD, "15 m")
	assert_eq(TensionMusic.target_level(3.0, false, AUDIO), TensionMusic.Level.DREAD)


func test_the_open_exit_brings_dread_for_everyone() -> void:
	assert_eq(TensionMusic.target_level(-1.0, true, AUDIO), TensionMusic.Level.DREAD)
	assert_eq(TensionMusic.target_level(80.0, true, AUDIO), TensionMusic.Level.DREAD)
	assert_eq(TensionMusic.monster_target(INF, true, AUDIO), TensionMusic.Level.DREAD)


func test_the_monster_hears_its_pulse_after_a_noise_nearby() -> void:
	assert_eq(TensionMusic.monster_target(INF, false, AUDIO), TensionMusic.Level.CALM)
	assert_eq(TensionMusic.monster_target(1.0, false, AUDIO), TensionMusic.Level.UNEASE)
	assert_eq(
		TensionMusic.monster_target(AUDIO.monster_heard_memory + 0.1, false, AUDIO),
		TensionMusic.Level.CALM
	)


func test_a_level_is_kept_a_few_seconds() -> void:
	assert_eq(
		TensionMusic.next_level(TensionMusic.Level.CALM, TensionMusic.Level.DREAD, 1.0, AUDIO),
		TensionMusic.Level.CALM
	)
	assert_eq(
		TensionMusic.next_level(
			TensionMusic.Level.CALM, TensionMusic.Level.DREAD, AUDIO.level_hold, AUDIO
		),
		TensionMusic.Level.DREAD
	)
	assert_eq(
		TensionMusic.next_level(TensionMusic.Level.UNEASE, TensionMusic.Level.UNEASE, 0.0, AUDIO),
		TensionMusic.Level.UNEASE
	)


func test_layers_come_in_4_s_and_go_in_10_s() -> void:
	assert_eq(AUDIO.layer_rise, 4.0)
	assert_eq(AUDIO.layer_fall, 10.0)
	assert_almost_eq(TensionMusic.fade(0.0, true, 2.0, AUDIO), 0.5, 0.001)
	assert_eq(TensionMusic.fade(0.9, true, 2.0, AUDIO), 1.0)
	assert_almost_eq(TensionMusic.fade(1.0, false, 5.0, AUDIO), 0.5, 0.001)
	assert_eq(TensionMusic.fade(0.1, false, 5.0, AUDIO), 0.0)


func test_the_three_layers_play_together_on_the_music_bus() -> void:
	var music := TensionMusic.new()
	add_child_autofree(music)
	assert_eq(music.get_child_count(), 3)
	for player: AudioStreamPlayer in music.get_children():
		assert_true(player.playing)
		assert_eq(player.bus, &"Musique")
		var wav := player.stream as AudioStreamWAV
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "a loop")
	assert_eq(music.gains, [1.0, 0.0, 0.0] as Array[float], "the background only")


func test_a_near_monster_raises_the_music_slowly() -> void:
	var music := TensionMusic.new()
	add_child_autofree(music)
	music.set_process(false)
	music.update(1.0, TensionMusic.Level.DREAD)
	assert_eq(music.level, TensionMusic.Level.CALM, "not before level_hold")
	music.update(AUDIO.level_hold, TensionMusic.Level.DREAD)
	assert_eq(music.level, TensionMusic.Level.DREAD)
	for i in 4:
		music.update(1.0, TensionMusic.Level.DREAD)
	assert_almost_eq(music.gains[1], 1.0, 0.001)
	assert_almost_eq(music.gains[2], 1.0, 0.001)
	var layer: AudioStreamPlayer = music.get_child(2)
	assert_almost_eq(layer.volume_db, AUDIO.layer_db.z, 0.01)
	music.update(AUDIO.level_hold, TensionMusic.Level.CALM)
	assert_eq(music.level, TensionMusic.Level.CALM)
	assert_gt(music.gains[2], 0.5, "slow to go away")
	assert_almost_eq(music.gains[0], 1.0, 0.001, "the background stays")


func test_the_map_starts_the_music() -> void:
	var map: GameMap = preload("res://game/maps/tilleuls/tilleuls.scn").instantiate()
	add_child_autofree(map)
	var music: TensionMusic = map.get_node("TensionMusic")
	assert_eq(music.game_loop, map.game_loop)
