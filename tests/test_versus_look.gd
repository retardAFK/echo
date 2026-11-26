extends GutTest
## The Versus by day (spec S-025, Q7, Q8, T-405): the day's sky and fog,
## neon bars on the arena's façades, the stealth gauges hidden, the boss
## bigger with glowing cracks and a hitbox of its size.

const CITE_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")

var _saved_role: GameSession.Role


func before_each() -> void:
	_saved_role = GameSession.role
	GameSession.mode = GameModes.VERSUS
	GameSession.role = GameSession.Role.HUNTED


func after_each() -> void:
	GameSession.role = _saved_role
	GameSession.mode = GameModes.HUNT


func _open(scene: PackedScene) -> VersusMode:
	var map: GameMap = scene.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(6)
	return map.get_node("VersusMode")


func test_the_cite_arena_is_by_day_with_neons() -> void:
	var versus: VersusMode = await _open(CITE_SCENE)
	var night := versus.get_parent().get_node("WorldEnvironment") as NightEnvironment
	assert_eq(night.settings, VersusDaylight.DAY, "the day's settings")
	assert_lt(night.environment.fog_density, 0.01, "a light fog")
	var daylight := versus.get_node("VersusDaylight") as VersusDaylight
	assert_gt(daylight.bars.size(), 10, "neon bars on the façades")
	assert_not_null(daylight.neons, "in one mesh")
	for node in versus.get_parent().find_children("*", "CanvasLayer", true, false):
		if node is NoiseGauge or node is BreathBar:
			assert_false((node as CanvasLayer).visible, "no stealth gauges")


func test_the_boss_is_bigger_and_glows_more_in_its_fury() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var boss := versus.boss
	var look := boss.look
	assert_not_null(look)
	var model := boss.body.get_node("Body") as Node3D
	assert_eq(model.scale, Vector3.ONE * versus.settings.boss_scale, "1.3 times bigger")
	assert_gt(boss.eyes().y, boss.body.get_eye_position().y, "its eyes higher")
	var capsule := look.hitbox.get_child(0).shape as CapsuleShape3D
	assert_almost_eq(capsule.height, BossLook.HEIGHT * versus.settings.boss_scale, 0.01)
	assert_eq(versus.boss_of(look.hitbox), boss, "the hitbox is the boss's")
	var calm := look.glow()
	boss.health.rage = 100.0
	boss.health.start_fury()
	assert_gt(look.glow(), calm, "brighter in its fury")
