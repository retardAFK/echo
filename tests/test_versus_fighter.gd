extends GutTest
## Where an AI hunted goes in the Versus (spec S-024, Q17, T-383): a downed
## teammate when the boss is far, chests, rolling away from a blow.

const CITE_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func test_it_revives_first_when_the_boss_is_far() -> void:
	var fighter := PreyFighter.new(SETTINGS)
	var goal := PreyFighter.Goal
	var downed: Array[Vector3] = [Vector3(10, 0, 0)]
	var chests: Array[Vector3] = [Vector3(3, 0, 0)]
	var far := Vector3(60, 0, 0)
	assert_eq(fighter.choose(Vector3.ZERO, far, downed, chests, true), goal.REVIVE)
	assert_eq(fighter.point, downed[0])
	var near := Vector3(12, 0, 0)
	assert_eq(fighter.choose(Vector3.ZERO, near, downed, chests, false), goal.CHEST, "boss there")
	assert_eq(fighter.point, chests[0])


func test_armed_it_takes_only_near_and_safe_chests() -> void:
	var fighter := PreyFighter.new(SETTINGS)
	var goal := PreyFighter.Goal
	var none: Array[Vector3] = []
	var chests: Array[Vector3] = [Vector3(40, 0, 0)]
	var boss := Vector3(-60, 0, 0)
	assert_eq(fighter.choose(Vector3.ZERO, boss, none, chests, false), goal.CHEST, "unarmed")
	assert_eq(fighter.choose(Vector3.ZERO, boss, none, chests, true), goal.NONE, "too far")
	chests = [Vector3(10, 0, 0)]
	assert_eq(fighter.choose(Vector3.ZERO, boss, none, chests, true), goal.CHEST)
	assert_eq(fighter.choose(Vector3.ZERO, Vector3(12, 0, 0), none, chests, true), goal.NONE)


func test_a_goal_not_reached_in_time_is_given_up() -> void:
	var fighter := PreyFighter.new(SETTINGS)
	var none: Array[Vector3] = []
	var chests: Array[Vector3] = [Vector3(5, 0, 0)]
	var boss := Vector3(-60, 0, 0)
	fighter.choose(Vector3.ZERO, boss, none, chests, false)
	fighter.update(SETTINGS.ai_goal_time + 0.1)
	assert_eq(fighter.goal, PreyFighter.Goal.NONE)
	assert_eq(fighter.choose(Vector3.ZERO, boss, none, chests, false), PreyFighter.Goal.NONE)


func test_the_zone_comes_before_all() -> void:
	var fighter := PreyFighter.new(SETTINGS)
	var downed: Array[Vector3] = [Vector3(3, 0, 0)]
	var zone := VersusZone.new(SETTINGS, Rect2(-50, -50, 100, 100))
	var own := Vector3(60, 0, 0)
	var clock := SETTINGS.zone_step_times[0]
	assert_true(zone.must_move_in(own, clock), "outside soon")
	var inside := zone.inside_point(own, clock)
	assert_false(zone.is_outside(inside, clock + 30.0))
	assert_gt(inside.x, 0.0, "on its side")
	var goal := fighter.choose(own, Vector3(-40, 0, 0), downed, [], true, [], inside)
	assert_eq(goal, PreyFighter.Goal.ZONE)
	assert_eq(fighter.point, inside)
	assert_false(zone.must_move_in(Vector3.ZERO, 0.0), "the centre is safe")


func test_it_rolls_away_from_a_blow_wound_up_at_it() -> void:
	var fighter := PreyFighter.new(SETTINGS)
	assert_true(fighter.should_dodge(true, false, SETTINGS.claw_reach))
	assert_false(fighter.should_dodge(true, false, SETTINGS.claw_reach + 5.0))
	assert_true(fighter.should_dodge(false, true, 10.0))
	assert_false(fighter.should_dodge(false, false, 1.0))


func test_an_ai_hunted_walks_to_a_chest() -> void:
	GameSession.role = GameSession.Role.MONSTER  # The hunted are AI preys.
	var map: GameMap = CITE_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	var versus: VersusMode = map.get_node("VersusMode")
	var kit: HunterKit
	for each in versus.hunters:
		if each.body is Prey:
			kit = each
	assert_not_null(kit, "an AI hunted")
	versus.boss.body.global_position = kit.body.global_position + Vector3(0, 0, 80)
	var chest := versus.add_chest(kit.body.global_position + Vector3(6, 0, 0), SETTINGS.items[0])
	await wait_physics_frames(40)
	var prey := kit.body as Prey
	assert_eq(prey.brain.state, PreyBrain.State.SEARCH)
	assert_eq(kit.fighter.goal, PreyFighter.Goal.CHEST)
	await wait_until(func() -> bool: return chest.is_open, 20.0)
	assert_true(chest.is_open, "it opened it")
