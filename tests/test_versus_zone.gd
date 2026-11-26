extends GutTest
## The Versus zone and banners (spec S-025, Q4, Q6, T-406): it shrinks in
## steps on the clock, hurts who stays outside, and the banner says so.

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


func _open() -> VersusMode:
	var map: GameMap = CITE_SCENE.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(6)
	return map.get_node("VersusMode")


func test_it_shrinks_in_three_steps_on_the_clock() -> void:
	var zone := VersusZone.new(SETTINGS, Rect2(0, 0, 100, 100))
	assert_eq(zone.centre, Vector2(50, 50))
	var full := zone.start_radius
	assert_eq(zone.radius(0.0), full)
	assert_eq(zone.radius(SETTINGS.zone_step_times[0]), full, "not before its first step")
	var steps := SETTINGS.zone_step_times.size()
	assert_eq(steps, 3)
	for i in steps:
		var done := SETTINGS.zone_step_times[i] + SETTINGS.zone_shrink_time
		assert_almost_eq(zone.radius(done), full * SETTINGS.zone_step_ratios[i], 0.01)
	var halfway := SETTINGS.zone_step_times[0] + SETTINGS.zone_shrink_time * 0.5
	assert_lt(zone.radius(halfway), full, "it shrinks smoothly")
	assert_gt(zone.radius(halfway), full * SETTINGS.zone_step_ratios[0])
	assert_eq(zone.next_step(10.0), [0, SETTINGS.zone_step_times[0] - 10.0])
	assert_eq(zone.next_step(SETTINGS.zone_step_times[0] + 1.0), [0, 0.0], "shrinking")
	assert_eq(zone.next_step(SETTINGS.match_time), [steps, -1.0], "none left")
	assert_true(zone.is_outside(Vector3(50, 0, 50 + full + 1.0), 0.0))
	assert_false(zone.is_outside(Vector3(50, 0, 50), SETTINGS.match_time))
	assert_eq(SETTINGS.match_time, 480.0, "8 min (Q6)")


func test_outside_the_zone_the_hunted_and_the_boss_get_hurt() -> void:
	var versus: VersusMode = await _open()
	assert_not_null(versus.zone, "an arena has its zone")
	assert_not_null(versus.get_node("ZoneWall"))
	var last := SETTINGS.zone_step_times[-1] + SETTINGS.zone_shrink_time + 1.0
	versus.rules.clock = last
	var hunter := versus.local_hunter()
	var centre := versus.zone.centre
	var far := versus.zone.radius(last) + 10.0
	hunter.body.global_position = Vector3(centre.x + far, 0.5, centre.y)
	versus.boss.body.global_position = Vector3(centre.x - far, 0.5, centre.y)
	versus.boss.body.set_physics_process(false)
	var health := versus.boss.health.health
	await wait_seconds(SETTINGS.zone_hunted_tick + 0.3)
	assert_lt(hunter.vitals.health, SETTINGS.hunted_health, "a point lost")
	assert_lt(versus.boss.health.health, health, "the boss too")


func test_the_banner_warns_of_the_zone_and_shows_the_phases() -> void:
	var versus: VersusMode = await _open()
	versus.rules.clock = SETTINGS.zone_step_times[0] - SETTINGS.zone_warning + 0.5
	await wait_physics_frames(3)
	assert_string_contains(versus.hud._banner, "zone")
	var health := versus.boss.health
	health.take_hit(health.max_health * 0.4)
	assert_eq(versus.hud._banners.size(), 1, "the phase waits its turn")
	assert_string_contains(versus.hud._banners[0], "phase 2")
