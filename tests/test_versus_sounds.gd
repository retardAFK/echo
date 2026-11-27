extends GutTest
## The sounds and the music of the Versus arcade (spec S-025, T-410).

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func _open() -> VersusMode:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


func test_each_gun_has_its_shot() -> void:
	for id: StringName in VersusSounds.GUN_SOUNDS:
		var sound: StringName = VersusSounds.GUN_SOUNDS[id]
		assert_true(VersusSounds.STREAMS.has(sound), "%s fires %s" % [id, sound])
	for path in DirAccess.get_files_at("res://game/modes/versus/data/items"):
		var item := load("res://game/modes/versus/data/items/" + path) as VersusItem
		if item != null and item.weapon != null:
			assert_true(VersusSounds.GUN_SOUNDS.has(item.id), "%s has a shot of its own" % item.id)


func test_the_pellets_of_one_shot_sound_once() -> void:
	var versus := await _open()
	var sounds := versus.sounds
	var playing := func() -> int:
		return (
			sounds
			. get_children()
			. filter(
				func(node: Node) -> bool: return node is AudioStreamPlayer3D and node.stream != null
			)
			. size()
		)
	for i in 8:
		versus.add_tracer(Vector3(0, 1, 0), Vector3(0, 1, -10), Color.WHITE, &"sonic_shotgun")
	assert_eq(playing.call(), 1, "eight pellets, one blast")
	await wait_process_frames(1)
	versus.add_tracer(Vector3(0, 1, 0), Vector3(0, 1, -10), Color.WHITE, &"sonic_shotgun")
	assert_eq(playing.call(), 2, "the next shot is heard")


func test_the_tension_music_gives_way_to_the_arcade_loop() -> void:
	var versus := await _open()
	await wait_process_frames(2)
	assert_null(versus.get_parent().get_node_or_null("TensionMusic"), "no horror music")
	assert_not_null(versus.music)
	var camera := versus.get_viewport().get_camera_3d()
	versus.boss.body.global_position = camera.global_position + Vector3(0, 0, 200)
	assert_false(versus.music.wants_rush(), "the boss far, the game young: the groove alone")
	versus.boss.body.global_position = camera.global_position + Vector3(0, 0, 5)
	assert_true(versus.music.wants_rush(), "the boss near")
	versus.boss.body.global_position = camera.global_position + Vector3(0, 0, 200)
	versus.rules.clock = versus.settings.match_time - versus.settings.dawn_warning + 1.0
	assert_true(versus.music.wants_rush(), "the last minute")
