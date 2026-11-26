extends GutTest
## The AI boss's choices (spec S-024, Q12, T-382): its target, its blows,
## backing off before a kneel, leaping onto a lone shooter.

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


func test_it_claws_in_reach_charges_in_line_and_waits_else() -> void:
	var brain := BossBrain.new(SETTINGS)
	var act := BossBrain.Act
	assert_eq(brain.choose(SETTINGS.claw_reach * 0.5, true, false, 0.0), act.CLAW)
	assert_eq(brain.choose(SETTINGS.claw_reach * 0.5, true, true, 0.0), act.CLAW, "claw first")
	assert_eq(brain.choose(10.0, true, false, 0.0), act.CHARGE)
	assert_eq(brain.choose(10.0, false, false, 0.0), act.WAIT, "no clear line")
	assert_eq(brain.choose(10.0, true, true, 0.0), act.LEAP, "onto the lone shooter")
	assert_eq(brain.choose(30.0, true, false, 0.0), act.WAIT, "too far to charge")


func test_it_backs_off_when_its_poise_is_nearly_full() -> void:
	var brain := BossBrain.new(SETTINGS)
	var act := BossBrain.Act
	assert_eq(brain.choose(1.0, true, false, SETTINGS.brain_retreat_poise), act.RETREAT)
	assert_true(brain.is_retreating())
	assert_eq(brain.choose(1.0, true, false, 0.0), act.WAIT, "no blow while it backs off")
	brain.update(SETTINGS.brain_retreat_time + 0.1)
	assert_eq(brain.choose(1.0, true, false, 0.0), act.CLAW)
	assert_eq(brain.choose(40.0, false, false, 1.0), act.WAIT, "far away: nothing to flee")


func test_its_target_is_the_nearest_or_one_that_hurt_it_more() -> void:
	var brain := BossBrain.new(SETTINGS)
	var places: Array[Vector3] = [Vector3(0, 0, 5), Vector3(0, 0, 8), Vector3(0, 0, 30)]
	var damage: Array[float] = [0.0, 0.0, 500.0]
	assert_eq(brain.pick_target(Vector3.ZERO, places, damage), 0, "the nearest")
	damage = [0.0, 100.0, 500.0]
	assert_eq(brain.pick_target(Vector3.ZERO, places, damage), 1, "a grudge close enough")
	assert_eq(brain.pick_target(Vector3.ZERO, [] as Array[Vector3], [] as Array[float]), -1)


func test_a_shooter_is_lone_without_a_teammate_near() -> void:
	var brain := BossBrain.new(SETTINGS)
	var places: Array[Vector3] = [Vector3.ZERO, Vector3(3, 0, 0), Vector3(20, 0, 0)]
	assert_false(brain.is_lone(0, places))
	assert_true(brain.is_lone(2, places))


func test_the_ai_boss_leaps_onto_a_lone_shooter_it_heard() -> void:
	var map: GameMap = ROOM_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	var versus: VersusMode = map.get_node("VersusMode")
	var boss := versus.boss
	var player := versus.local_hunter().body as Player
	boss.body.global_position = player.global_position - player.global_basis.z * 10.0
	boss.health.take_hit(boss.health.health - boss.health.max_health * 0.6)
	boss.health.update(SETTINGS.phase_shield_time + 0.1)
	for kit in versus.hunters:
		if kit.body != player:
			kit.body.global_position = player.global_position + Vector3(0, 0, 40)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, player.global_position, 10.0, player)
	await wait_until(func() -> bool: return boss.move == BossKit.Move.LEAPING, 1.0)
	assert_eq(boss.move, BossKit.Move.LEAPING)
