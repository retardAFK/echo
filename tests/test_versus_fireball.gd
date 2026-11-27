extends GutTest
## The boss's fireball and its pace (spec S-025, T-413): BossFire,
## Fireball, BossKit.cast_fireball, the AI's choice, the copies online.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func _open(role := GameSession.Role.HUNTED) -> VersusMode:
	GameSession.role = role
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


## The boss out of the way, its AI off.
func _boss_away(versus: VersusMode) -> void:
	versus.boss.set_physics_process(false)
	versus.boss.body.set_physics_process(false)
	versus.boss.body.global_position = Vector3(0, -50, 0)


func test_the_ai_throws_at_range_when_ready() -> void:
	var brain := BossBrain.new(SETTINGS)
	var act := BossBrain.Act
	var far := (SETTINGS.fireball_min_distance + SETTINGS.fireball_range) * 0.5
	far = maxf(far, SETTINGS.charge_distance + 1.0)
	assert_eq(brain.choose(far, true, false, 0.0, true), act.FIREBALL)
	assert_eq(brain.choose(far, true, false, 0.0, false), act.WAIT, "not ready")
	assert_eq(brain.choose(far, false, false, 0.0, true), act.WAIT, "not in sight")
	assert_eq(brain.choose(SETTINGS.fireball_range + 5.0, true, false, 0.0, true), act.WAIT)
	assert_eq(brain.choose(SETTINGS.claw_reach * 0.5, true, false, 0.0, true), act.CLAW)


func test_a_fireball_bursts_on_a_hunted_and_throws_it_back() -> void:
	var versus := await _open()
	_boss_away(versus)
	var hunter := versus.local_hunter()
	var chest := hunter.body.global_position + Vector3.UP
	var health := hunter.vitals.health
	var from := chest + Vector3(0, 0, -8)
	versus.fire.cast(from, Vector3(0, 0, 1) * SETTINGS.fireball_speed)
	await wait_physics_frames(22)
	var bursts := versus.get_children().filter(func(node: Node) -> bool: return node is FlashBurst)
	assert_gt(bursts.size(), 0, "the burst shows")
	await wait_physics_frames(20)
	assert_eq(hunter.vitals.health, health - SETTINGS.fireball_damage, "burnt")
	assert_true(hunter.body.global_position.z > chest.z, "thrown back, away from the burst")


func test_a_roll_saves_from_the_burst() -> void:
	var versus := await _open()
	_boss_away(versus)
	var hunter := versus.local_hunter()
	var health := hunter.vitals.health
	hunter.vitals.shield(5.0)
	versus.fire.explode(hunter.body.global_position + Vector3.UP)
	assert_eq(hunter.vitals.health, health)


func test_the_played_boss_throws_with_right_click_then_waits() -> void:
	var versus := await _open(GameSession.Role.MONSTER)
	var boss := versus.boss
	assert_false((boss.body as MonsterAvatar).scan_enabled, "right click no longer scans")
	Input.action_press("scan")
	await wait_physics_frames(2)
	Input.action_release("scan")
	assert_eq(boss.move, BossKit.Move.CASTING, "the arm goes up")
	assert_almost_eq(boss.fire_wait, SETTINGS.fireball_cooldown, 0.2)
	await wait_seconds(SETTINGS.fireball_windup + 0.1)
	var balls := versus.get_children().filter(func(node: Node) -> bool: return node is Fireball)
	assert_eq(balls.size(), 1, "it flies")
	assert_false(boss.cast_fireball(Vector3.FORWARD), "not before its cooldown")


func test_the_boss_is_quicker() -> void:
	var versus := await _open()
	await wait_physics_frames(2)
	var settings: MonsterSettings = versus.boss.body.get(&"settings")
	var base := preload("res://game/data/monster_settings.tres").walk_speed
	var expected := base * versus.boss.health.speed_scale() * SETTINGS.boss_speed_scale
	assert_almost_eq(settings.walk_speed, expected, 0.01)
	assert_gt(SETTINGS.boss_speed_scale, 1.0)


func test_a_client_shows_a_harmless_copy_until_the_room_says_where_it_burst() -> void:
	var versus := await _open()
	_boss_away(versus)
	versus.mirror = true
	var hunter := versus.local_hunter()
	var health := hunter.vitals.health
	var chest := hunter.body.global_position + Vector3.UP
	var ball := versus.fire.cast(chest + Vector3(0, 0, -30), Vector3(0, 0, 1))
	assert_false(ball.harmful)
	versus.fire.burst(ball.global_position + Vector3(0, 0, 0.5))
	await wait_physics_frames(1)
	assert_false(is_instance_valid(ball), "the copy goes at the room's burst")
	assert_eq(hunter.vitals.health, health, "a copy hurts nobody")
	versus.mirror = false
