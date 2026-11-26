extends GutTest
## Chests, weapons and tools of the Versus (spec S-024, Q13, Q29 to Q32,
## T-377): what a hunted carries, what chests hold, opening one, the UV
## laser, the sonic cannon, the medkit, the firecracker under the boss, new
## chests at each phase.

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


func _item(id: StringName) -> VersusItem:
	for item in SETTINGS.items:
		if item.id == id:
			return item
	return null


func _open(scene: PackedScene) -> VersusMode:
	var map: GameMap = scene.instantiate()
	add_child_autofree(map)
	await wait_physics_frames(4)
	return map.get_node("VersusMode")


## The player turns to face point.
func _face(player: Player, point: Vector3) -> void:
	var offset := point - player.global_position
	player.set_look(atan2(-offset.x, -offset.z), 0.0)


func test_a_loadout_holds_one_weapon_and_two_tools() -> void:
	var loadout := VersusLoadout.new()
	assert_null(loadout.take(_item(&"flare_launcher")))
	assert_eq(loadout.take(_item(&"uv_laser")), _item(&"flare_launcher"), "the old one stays")
	assert_null(loadout.take(_item(&"medkit")))
	assert_null(loadout.take(_item(&"sonic_cannon")))
	assert_eq(loadout.take(_item(&"smoke")), _item(&"medkit"), "the oldest tool goes")
	assert_eq(loadout.tool_in(1), _item(&"smoke"))
	loadout.take(_item(&"flares"))
	assert_eq(loadout.spare_flares, _item(&"flares").uses)
	assert_eq(loadout.draw_flares(100), _item(&"flares").uses)
	for i in _item(&"smoke").uses:
		assert_true(loadout.spend(1))
	assert_null(loadout.tool_in(1), "an empty tool leaves its slot")


func test_chests_never_hold_the_launcher_and_phases_give_more_lasers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lasers := [0, 0]
	for phase in [false, true]:
		for i in 400:
			var item := VersusLoadout.draw(SETTINGS.items, rng, phase)
			assert_ne(item.id, &"flare_launcher", "only in the first chest (Q31)")
			if item.id == &"uv_laser":
				lasers[int(phase)] += 1
	assert_gt(lasers[1], lasers[0], "better chests at each phase (Q32)")


func test_the_hunted_starts_empty_handed_by_a_chest_and_opens_it() -> void:
	var versus: VersusMode = await _open(CITE_SCENE)
	var hunter := versus.local_hunter()
	assert_null(hunter.loadout.weapon, "no weapon at the start (Q29)")
	assert_false(hunter.fire())
	var chests := versus.get_tree().get_nodes_in_group(VersusChest.GROUP)
	assert_eq(chests.size(), 1 + versus.settings.arena_chests)
	var chest := hunter.chest_in_reach()
	assert_not_null(chest, "its chest is right in front")
	assert_eq(chest.item, versus.settings.first_weapon)
	watch_signals(NoiseBus)
	hunter.hold_chest(true, 1.0)
	assert_false(chest.is_open, "2 s to open it")
	hunter.hold_chest(true, 1.1)
	assert_true(chest.is_open)
	assert_signal_emitted(NoiseBus, "noise_emitted", "the lid bangs")
	hunter.hold_chest(true, versus.settings.chest_take_time + 0.01)
	assert_true(hunter.loadout.has_weapon(&"flare_launcher"))
	assert_null(chest.item, "empty now")
	assert_eq(hunter.clip, versus.settings.flare_clip)
	assert_eq(hunter.loadout.spare_flares, versus.settings.start_spare_flares)
	assert_eq(hunter.view_model.weapon, &"flare_launcher")


func test_new_chests_come_with_each_phase() -> void:
	var versus: VersusMode = await _open(CITE_SCENE)
	var before := versus.get_tree().get_nodes_in_group(VersusChest.GROUP).size()
	var health := versus.boss.health
	health.take_hit(health.max_health * 0.4)
	var after := versus.get_tree().get_nodes_in_group(VersusChest.GROUP).size()
	assert_eq(after, before + versus.settings.phase_chests)


func test_the_uv_laser_burns_slows_and_runs_on_a_battery() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var hunter := versus.local_hunter()
	hunter.equip(_item(&"uv_laser"))
	assert_not_null(hunter.laser)
	assert_false(hunter.fire(), "no flares with the laser")
	var boss := versus.boss
	var settings: MonsterSettings = boss.body.get(&"settings")
	var walk := settings.walk_speed
	boss.take_laser(hunter.body, boss.body.global_position + Vector3.UP, 1.0)
	assert_almost_eq(
		boss.health.max_health - boss.health.health, versus.settings.laser_damage_per_second, 0.01
	)
	await wait_physics_frames(1)
	assert_lt(settings.walk_speed, walk, "slowed")
	hunter.laser.update(true, versus.settings.laser_battery + 1.0)
	assert_eq(hunter.laser.battery, 0.0)
	hunter.laser.update(true, 0.1)
	assert_false(hunter.laser.firing, "flat battery")
	hunter.laser.update(false, versus.settings.laser_recharge)
	assert_almost_eq(hunter.laser.ratio(), 1.0, 0.001, "full again after its recharge")


func test_the_sonic_cannon_pushes_the_boss_back() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var hunter := versus.local_hunter()
	var boss := versus.boss
	boss.body.set_physics_process(false)
	var player := hunter.body as Player
	boss.body.global_position = player.global_position - player.global_basis.z * 6.0
	_face(player, boss.body.global_position)
	hunter.equip(_item(&"sonic_cannon"))
	var start := boss.body.global_position
	assert_true(hunter.use_tool(0))
	await wait_physics_frames(30)
	assert_gt(boss.body.global_position.distance_to(start), 2.0, "pushed back")
	assert_gt(boss.health.poise, 0.0)
	assert_eq(hunter.loadout.uses[0], _item(&"sonic_cannon").uses - 1)


func test_a_medkit_heals_and_is_kept_at_full_health() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var hunter := versus.local_hunter()
	hunter.equip(_item(&"medkit"))
	assert_false(hunter.use_tool(0), "full health: kept")
	hunter.take_blow(1)
	assert_true(hunter.use_tool(0))
	assert_eq(hunter.vitals.health, versus.settings.hunted_health)


func test_a_firecracker_under_the_boss_hurts_it() -> void:
	var versus: VersusMode = await _open(ROOM_SCENE)
	var boss := versus.boss
	NoiseBus.emit_noise(NoiseEvent.Type.FIRECRACKER, boss.body.global_position, 20.0)
	assert_almost_eq(
		boss.health.max_health - boss.health.health, versus.settings.firecracker_damage, 0.01
	)
