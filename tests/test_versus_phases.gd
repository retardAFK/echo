extends GutTest
## The boss's phases and leap (spec S-024, Q8, Q9, T-379): the leap onto a
## noise heard lately, its landing, the cry and the lights going out at
## phase 2, the double claw of phase 3.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
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
	Engine.time_scale = 1.0


func _open(scene: PackedScene) -> VersusMode:
	var map: GameMap = scene.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


## Takes the boss down to ratio of its health, then waits out the phase cry.
func _to_ratio(boss: BossKit, ratio: float) -> void:
	var health := boss.health
	health.take_hit(health.health - health.max_health * ratio)
	health.update(SETTINGS.phase_shield_time + 0.1)


func test_the_leap_picks_a_fresh_noise_in_range_and_in_sight() -> void:
	var leap := BossLeap.new(SETTINGS)
	leap.hear(Vector3(0, 0, -10))
	leap.hear(Vector3(0, 0, -60))
	assert_eq(leap.pick(Vector3.ZERO, Vector3.FORWARD), Vector3(0, 0, -10))
	assert_null(leap.pick(Vector3.ZERO, Vector3.BACK), "not behind")
	assert_eq(leap.pick(Vector3.ZERO, Vector3.ZERO, Vector3(1, 0, -9)), Vector3(0, 0, -10))
	leap.update(SETTINGS.leap_noise_memory + 0.1)
	assert_null(leap.pick(Vector3.ZERO, Vector3.FORWARD), "forgotten")
	leap.start(Vector3.ZERO, Vector3(0, 0, -10))
	var top := leap.fly(SETTINGS.leap_time * 0.5)
	assert_almost_eq(top.y, SETTINGS.leap_height, 0.01, "the arc")
	assert_eq(leap.fly(SETTINGS.leap_time), Vector3(0, 0, -10))
	assert_false(leap.leaping)


func test_the_boss_leaps_from_phase_2_and_its_landing_throws_the_hunted() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var boss := versus.boss
	var hunter := versus.local_hunter()
	var player := hunter.body as Player
	boss.body.global_position = player.global_position - player.global_basis.z * 10.0
	assert_false(boss.can_leap(), "not in phase 1")
	_to_ratio(boss, 0.6)
	assert_true(boss.can_leap())
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, player.global_position, 10.0, player)
	assert_eq(boss.leap.heard.size(), 1, "it heard the hunted")
	var target: Vector3 = boss.leap.pick(boss.body.global_position, Vector3.ZERO, player.position)
	assert_true(boss.leap_to(target + Vector3(1.0, 0, 0)))
	assert_true(versus.leap_shadow.visible, "its shadow where it lands")
	var start := player.global_position
	await wait_until(func() -> bool: return boss.move == BossKit.Move.NONE, 3.0)
	assert_false(versus.leap_shadow.visible)
	assert_eq(hunter.vitals.health, SETTINGS.hunted_health - SETTINGS.leap_damage)
	await wait_physics_frames(15)
	assert_gt(player.global_position.distance_to(start), 1.0, "thrown")
	assert_false(boss.can_leap(), "12 s to wait")


## The lamps of the map lit inside the arena (inside) or out of it, not
## counting the flares nor what the boss and the hunted carry.
func _lamps(versus: VersusMode, inside: bool) -> int:
	var carriers: Array[Node] = [versus, versus.boss.body]
	for kit in versus.hunters:
		carriers.append(kit.body)
	var count := 0
	for node in versus.get_parent().find_children("*", "OmniLight3D", true, false):
		var light := node as Light3D
		if not light.visible or versus.arena.contains(light.global_position) != inside:
			continue
		if not carriers.any(func(carrier: Node) -> bool: return carrier.is_ancestor_of(light)):
			count += 1
	return count


func test_phase_2_cries_and_the_boss_glows_brighter() -> void:
	var versus: VersusMode = await _open(CITE_SCENE)
	var lit := _lamps(versus, true)
	assert_gt(lit, 0, "lamps lit at the start")
	var glow := versus.boss.look.glow()
	watch_signals(NoiseBus)
	_to_ratio(versus.boss, 0.6)
	assert_signal_emitted(NoiseBus, "noise_emitted", "the cry")
	assert_eq(_lamps(versus, true), lit, "daylight: the lamps stay (S-025)")
	assert_gt(versus.boss.look.glow(), glow, "its cracks shine more")


func test_the_arena_lights_can_still_go_out() -> void:
	var versus: VersusMode = await _open(CITE_SCENE)
	var outside := _lamps(versus, false)
	versus.put_lights_out()
	assert_eq(_lamps(versus, true), 0, "the arena is dark")
	assert_eq(_lamps(versus, false), outside, "the rest of the cité keeps its lamps")


func test_the_enraged_boss_claws_twice() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var boss := versus.boss
	boss.set_physics_process(false)
	var hunter := versus.local_hunter()
	var player := hunter.body as Player
	boss.body.global_position = player.global_position - player.global_basis.z * 1.5
	boss.body.look_at(player.global_position, Vector3.UP)
	_to_ratio(boss, 0.3)
	assert_true(boss.health.current_phase().double_claw)
	assert_true(boss.claw())
	for i in 60:
		boss._physics_process(1.0 / 60.0)
	assert_eq(hunter.vitals.health, SETTINGS.hunted_health - 2 * SETTINGS.claw_damage)
