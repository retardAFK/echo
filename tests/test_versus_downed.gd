extends GutTest
## Down, revive, finish, out in the Versus (spec S-024, Q5, T-378): a downed
## hunted crawls, a teammate revives it by holding interact (faster with a
## medkit), the boss finishes it, a blow breaks the finish, the third fall
## is out at once.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT
	Engine.time_scale = 1.0


func _open() -> VersusMode:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


## A second hunted kit on a plain body next to the first one.
func _teammate(versus: VersusMode, at: Vector3) -> HunterKit:
	var body := CharacterBody3D.new()
	versus.add_child(body)
	body.global_position = at
	var kit := HunterKit.new(versus)
	body.add_child(kit)
	kit.set_physics_process(false)  # Driven by hand.
	versus.hunters.append(kit)
	versus.rules.hunted.append(kit.vitals)
	return kit


func _item(versus: VersusMode, id: StringName) -> VersusItem:
	for item in versus.settings.items:
		if item.id == id:
			return item
	return null


func test_the_hold_finds_the_nearest_downed_hunted_in_reach() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var near := _teammate(versus, player.body.global_position + Vector3(1.5, 0, 0))
	var far := _teammate(versus, player.body.global_position + Vector3(6, 0, 0))
	var reach := versus.settings.revive_reach
	var point := player.body.global_position
	assert_null(DownedHold.nearest(versus.hunters, point, reach, player), "nobody down")
	near.vitals.hurt(99)
	far.vitals.hurt(99)
	assert_eq(DownedHold.nearest(versus.hunters, point, reach, player), near)
	var hold := DownedHold.new()
	assert_null(hold.update(versus.hunters, point, true, 1.0, 2.0, reach, player))
	assert_almost_eq(hold.ratio(2.0), 0.5, 0.001)
	assert_null(hold.update(versus.hunters, point, false, 1.0, 2.0, reach, player), "let go")
	assert_eq(hold.held, 0.0, "starts over")


func test_a_teammate_revives_a_downed_player_who_crawled() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var body := player.body as Player
	var walk := body.settings.walk_speed
	player.take_blow(versus.settings.hunted_health)
	assert_true(player.vitals.is_down())
	assert_almost_eq(body.settings.walk_speed, versus.settings.crawl_speed, 0.001, "it crawls")
	assert_false(player.fire(), "no shot when down")
	var mate := _teammate(versus, body.global_position + Vector3(1.0, 0, 0))
	watch_signals(NoiseBus)
	mate._hold_interact(true, versus.settings.revive_time * 0.5)
	assert_signal_emitted(NoiseBus, "noise_emitted", "a revive is heard")
	assert_true(player.vitals.is_down())
	mate._hold_interact(true, versus.settings.revive_time * 0.5 + 0.01)
	assert_true(player.vitals.is_standing())
	assert_eq(player.vitals.health, versus.settings.revive_health)
	assert_eq(body.settings.walk_speed, walk, "back on its feet")
	assert_eq(mate.revives_done, 1)


func test_a_medkit_shortens_the_revive_and_is_spent() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var mate := _teammate(versus, player.body.global_position + Vector3(1.0, 0, 0))
	mate.equip(_item(versus, &"medkit"))
	var uses := mate.loadout.uses[0]
	assert_almost_eq(
		mate.revive_time(),
		versus.settings.revive_time * versus.settings.medkit_revive_factor,
		0.001
	)
	player.take_blow(versus.settings.hunted_health)
	mate._hold_interact(true, mate.revive_time() + 0.01)
	assert_true(player.vitals.is_standing())
	assert_eq(mate.loadout.uses[0], uses - 1)


func test_the_boss_finishes_a_downed_hunted_unless_hit() -> void:
	var versus := await _open()
	var boss := versus.boss
	boss.set_physics_process(false)
	var player := versus.local_hunter()
	boss.body.global_position = player.body.global_position + Vector3(1.5, 0, 0)
	player.take_blow(versus.settings.hunted_health)
	boss.hold_finish(true, versus.settings.finish_time * 0.5)
	boss.hit_taken.emit(false)
	assert_eq(boss.finish.held, 0.0, "a blow breaks the finish")
	boss.hold_finish(true, versus.settings.finish_time * 0.5)
	boss.hold_finish(true, versus.settings.finish_time * 0.5 + 0.01)
	assert_true(player.vitals.is_out())
	assert_true((player.body as Player).held, "it stays where it fell")


func test_the_third_fall_is_out_at_once() -> void:
	var versus := await _open()
	var player := versus.local_hunter()
	var mate := _teammate(versus, player.body.global_position + Vector3(1.0, 0, 0))
	for i in versus.settings.revives:
		player.take_blow(versus.settings.hunted_health)
		mate._hold_interact(true, versus.settings.revive_time + 0.01)
		mate._hold_interact(false, 0.0)
		player.vitals.update(versus.settings.dodge_shield_time + 1.0)
	player.take_blow(versus.settings.hunted_health)
	assert_true(player.vitals.is_out())
