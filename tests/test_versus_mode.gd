extends GutTest
## The Versus mode prototype in the test room (spec S-024, T-372 to T-374):
## kits, shots on the boss, claws and charge on the hunted, who wins.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = VersusMode.MODE


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = &"hunt"
	Engine.time_scale = 1.0


func _open(role: GameSession.Role) -> GameMap:
	GameSession.role = role
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	return map


func _versus(map: GameMap) -> VersusMode:
	return map.get_node("VersusMode") as VersusMode


func test_the_hunted_gets_a_kit_and_the_monster_a_boss_kit() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var versus := _versus(map)
	assert_not_null(versus.boss, "the AI monster is the boss")
	assert_eq(versus.boss.body, map.monster)
	assert_eq(versus.local_hunter().body, map.player)
	assert_not_null(versus.local_hunter().view_model, "first-person arms")
	assert_eq(versus.boss.health.max_health, versus.settings.boss_health_per_hunted)
	assert_eq(map.monster.settings.catch_distance, 0.0, "blows, not catches")


func test_the_traque_has_no_versus() -> void:
	GameSession.mode = &"hunt"
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	assert_null(map.get_node_or_null("VersusMode"))


func test_a_flare_in_the_face_hurts_more_and_shows_a_red_marker() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var versus := _versus(map)
	var boss := versus.boss
	map.monster.set_physics_process(false)  # Stands still for the test.
	var hunter := versus.local_hunter()
	var eyes: Vector3 = map.monster.get_eye_position()
	var toward := map.player.global_position - map.monster.global_position
	toward.y = 0.0
	var from := eyes + toward.normalized() * 6.0  # The open side, not a wall.
	var flare := Flare.new()
	flare.mode = versus
	flare.shooter = map.player
	flare.velocity = (eyes - from).normalized() * versus.settings.flare_speed
	versus.add_flare(flare, from)
	await wait_physics_frames(20)
	assert_eq(
		boss.health.max_health - boss.health.health, versus.settings.flare_face_damage, "face"
	)
	assert_eq(versus.hud._hit_face, true)
	assert_eq(hunter.clip, hunter.loadout.gun().clip, "not shot by the player's gun")


func test_firing_spends_a_shot_and_an_empty_gun_reloads() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var hunter := _versus(map).local_hunter()
	assert_true(hunter.fire())
	assert_eq(hunter.clip, hunter.loadout.gun().clip - 1)
	hunter.clip = 0
	await wait_seconds(hunter.loadout.gun().fire_interval + 0.05)
	assert_false(hunter.fire())
	assert_true(hunter.reloading)


func test_a_dodge_shields_and_costs_stamina() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var hunter := _versus(map).local_hunter()
	var start := map.player.global_position
	assert_true(hunter.dodge(Vector3.RIGHT))
	assert_false(hunter.take_blow(1), "untouchable at the start of the roll")
	await wait_seconds(_versus(map).settings.dodge_time + 0.1)
	assert_gt(map.player.global_position.distance_to(start), 1.5, "it rolled")
	assert_lt(hunter.stamina.value, 1.0)


func test_the_boss_claws_a_hunted_in_reach() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var versus := _versus(map)
	var hunter := versus.local_hunter()
	map.monster.global_position = map.player.global_position + Vector3(0, 0, 1.5)
	await wait_seconds(versus.settings.claw_windup + 0.3)
	assert_lt(hunter.vitals.health, versus.settings.hunted_health, "clawed")


func test_a_charge_into_a_wall_stuns_the_boss() -> void:
	var map := _open(GameSession.Role.MONSTER)
	await wait_physics_frames(3)
	var versus := _versus(map)
	var boss := versus.boss
	assert_true(boss.is_local(), "the played boss")
	assert_not_null(boss.view_model, "clawed arms")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	shape.shape = box
	wall.add_child(shape)
	map.add_child(wall)
	wall.global_position = map.avatar.global_position + Vector3(0, 1, -5)
	map.avatar.rotation = Vector3.ZERO
	assert_true(boss.charge(Vector3.FORWARD))
	await wait_seconds(versus.settings.charge_windup + 0.6)
	assert_eq(boss.move, BossKit.Move.STUNNED)


func test_the_hunted_win_when_the_boss_falls() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var versus := _versus(map)
	versus.boss.health.take_hit(versus.boss.health.max_health)
	await wait_physics_frames(2)
	assert_eq(versus.rules.winner, VersusRules.Winner.HUNTED)
	assert_lt(Engine.time_scale, 1.0, "slow motion on the killing blow")
	assert_ne(versus.hud._end_text, "")


func test_the_boss_wins_when_no_hunted_stands() -> void:
	var map := _open(GameSession.Role.MONSTER)
	await wait_physics_frames(3)
	var versus := _versus(map)
	assert_gt(versus.hunters.size(), 0, "the AI prey is a hunted")
	for hunter in versus.hunters:
		hunter.take_blow(versus.settings.hunted_health)
	await wait_physics_frames(2)
	assert_eq(versus.rules.winner, VersusRules.Winner.BOSS)


func test_a_fall_hurts_a_hunted_unless_it_rolls() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var hunter := _versus(map).local_hunter()
	var full := hunter.vitals.health
	hunter.land(4.3)
	assert_eq(hunter.vitals.health, full - 1, "off the social centre's roof")
	assert_true(hunter.dodge(Vector3.FORWARD))
	hunter.land(4.3)
	assert_eq(hunter.vitals.health, full - 1, "a roll at the landing saves it")
	hunter.land(12.0)
	assert_true(hunter.vitals.is_down(), "from the fire escape's top: down")


func test_a_long_fall_hurts_and_stuns_the_boss() -> void:
	var map := _open(GameSession.Role.HUNTED)
	await wait_physics_frames(3)
	var boss := _versus(map).boss
	boss.land(3.0)
	assert_eq(boss.health.health, boss.health.max_health, "a short fall: nothing")
	boss.land(9.0)
	assert_lt(boss.health.health, boss.health.max_health)
	assert_eq(boss.move, BossKit.Move.STUNNED)


func test_the_kits_see_presses_in_the_held_keys() -> void:
	var commands := PlayerCommands.new()
	commands.fire = true
	var keys := HeldKeys.new()
	keys.update(commands)
	assert_true(keys.pressed(PlayerCommands.FLAG_FIRE))
	keys.update(commands)
	assert_false(keys.pressed(PlayerCommands.FLAG_FIRE), "held, not pressed again")
	assert_true(keys.held(PlayerCommands.FLAG_FIRE))
