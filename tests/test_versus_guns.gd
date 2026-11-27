extends GutTest
## The Versus guns (spec S-025, Q2, Q4, T-403): rays that hit at once,
## spread within the gun's cone, the light machine gun held down, its clip
## and reload, the damage numbers and tracers; the rarities, the precision
## rifle and its zoom, the sonic shotgun (T-404).

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
const SMG := preload("res://game/modes/versus/data/weapons/light_smg.tres")

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


## The hunted's gun, with no spread: every pellet where it aims.
func _steady_gun(hunter: HunterKit) -> VersusWeapon:
	var item: VersusItem = hunter.loadout.weapon.duplicate()
	item.weapon = item.weapon.duplicate()
	item.weapon.spread = 0.0
	hunter.equip(item)
	return item.weapon


## The player in first person, looking at point.
func _aim_at(versus: VersusMode, point: Vector3) -> void:
	versus.view.first_person = true
	var player: Player = versus.local_hunter().body
	var offset := point - player.get_eye_position()
	var flat := Vector2(offset.x, offset.z).length()
	player.set_look(atan2(-offset.x, -offset.z), atan2(offset.y, flat))


func test_rays_stay_within_the_spread() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var aim := Vector3(0.3, -0.2, -1.0).normalized()
	var rays := HitscanShot.directions(aim, 200, 5.0, rng)
	assert_eq(rays.size(), 200)
	var widest := 0.0
	for ray in rays:
		widest = maxf(widest, rad_to_deg(ray.angle_to(aim)))
	assert_lt(widest, 5.01, "within the cone")
	assert_gt(widest, 3.0, "and spread across it")
	assert_almost_eq(HitscanShot.directions(aim, 1, 0.0, rng)[0].angle_to(aim), 0.0, 0.0001)


func test_the_face_deals_more() -> void:
	var body := HitscanShot.hit_of(SMG, false)
	var face := HitscanShot.hit_of(SMG, true)
	assert_eq(body[0], SMG.damage)
	assert_eq(face[0], SMG.damage * SMG.face_multiplier)
	assert_gt(face[1], body[1], "more poise in the face")


func test_the_start_gun_is_the_light_machine_gun() -> void:
	var versus: VersusMode = await _open()
	var hunter := versus.local_hunter()
	assert_true(hunter.loadout.has_weapon(&"light_smg"))
	assert_true(hunter.loadout.gun().automatic)
	assert_eq(hunter.clip, hunter.loadout.gun().clip)
	assert_eq(hunter.loadout.spare_ammo, versus.settings.start_spare_ammo)


func test_a_shot_in_the_face_hits_at_once_with_a_yellow_number_and_a_tracer() -> void:
	var versus: VersusMode = await _open()
	var boss := versus.boss
	boss.body.set_physics_process(false)  # Stands still for the test.
	var hunter := versus.local_hunter()
	var gun := _steady_gun(hunter)
	var player: Player = hunter.body
	var toward := player.global_position - boss.body.global_position
	toward.y = 0.0
	player.global_position = boss.body.global_position + toward.normalized() * 6.0  # Open side.
	var eyes := boss.eyes()
	_aim_at(versus, eyes)
	await wait_physics_frames(1)
	var before := boss.health.health
	assert_true(hunter.fire())
	assert_almost_eq(before - boss.health.health, gun.damage * gun.face_multiplier, 0.01)
	assert_true(versus.hud._hit_face, "the red marker")
	assert_eq(versus.hud._numbers.size(), 1, "one number")
	assert_true(versus.hud._numbers[0][2], "yellow: the face")
	var tracers := versus.get_children().filter(func(node: Node) -> bool: return node is Tracer)
	assert_eq(tracers.size(), 1, "its tracer")
	await wait_seconds(Tracer.LIFE + 0.1)
	assert_false(is_instance_valid(tracers[0]), "gone in a blink")


func test_holding_fire_empties_the_clip_then_reloads_from_the_spares() -> void:
	var versus: VersusMode = await _open()
	var hunter := versus.local_hunter()
	var gun := hunter.loadout.gun()
	watch_signals(NoiseBus)
	assert_true(hunter.fire())
	assert_signal_emitted(NoiseBus, "noise_emitted", "a shot is heard by the boss")
	assert_false(hunter.fire(), "its rate")
	for i in gun.clip - 1:
		hunter._cooldown = 0.0
		assert_true(hunter.fire())
	assert_eq(hunter.clip, 0)
	assert_true(hunter.reloading, "an empty clip reloads by itself")
	var spare := hunter.loadout.spare_ammo
	await wait_seconds(gun.reload_time + 0.1)
	assert_false(hunter.reloading)
	assert_eq(hunter.clip, gun.clip)
	assert_eq(hunter.loadout.spare_ammo, spare - gun.clip)


func test_laser_hits_add_up_into_one_number() -> void:
	var versus: VersusMode = await _open()
	for i in 10:
		versus.hud.show_damage(Vector3.ZERO, 0.3, false, true)
	assert_eq(versus.hud._numbers.size(), 1)
	assert_almost_eq(versus.hud._numbers[0][1], 3.0, 0.01)
	versus.hud.show_damage(Vector3.ZERO, 6.0, false)
	assert_eq(versus.hud._numbers.size(), 2, "a gun's shot has its own")
	versus.hud.show_damage(Vector3.ZERO, 6.0, false)
	assert_eq(versus.hud._numbers.size(), 2, "pellets of the same shot add up")
	assert_almost_eq(versus.hud._numbers[1][1], 12.0, 0.01)
	await wait_frames(2)
	versus.hud.show_damage(Vector3.ZERO, 6.0, false)
	assert_eq(versus.hud._numbers.size(), 3, "the next shot has its own")


func test_rarer_guns_deal_more_and_phase_chests_are_rarer() -> void:
	var versus: VersusMode = await _open()
	var settings := versus.settings
	var multipliers: Array[float] = []
	for rarity in settings.rarities:
		multipliers.append(rarity.damage_multiplier)
	assert_eq(multipliers, [1.0, 1.1, 1.2, 1.35] as Array[float], "Q3")
	var epic := versus.item(&"light_smg", 2)
	assert_eq(epic.rarity, 2)
	assert_eq(versus.item(&"light_smg", 2), epic, "one copy each")
	assert_eq(versus.item(&"light_smg"), settings.first_weapon, "common: the item itself")
	assert_eq(versus.item(&"medkit", 3).rarity, 0, "tools have no rarity")
	var hit := HitscanShot.hit_of(
		SMG, false, VersusRarity.of(epic, settings.rarities).damage_multiplier
	)
	assert_almost_eq(hit[0], SMG.damage * 1.2, 0.001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rare := [0, 0]
	for phase in [false, true]:
		for i in 400:
			if VersusRarity.draw(settings.rarities, rng, phase) > 0:
				rare[int(phase)] += 1
	assert_gt(rare[1], rare[0], "rare and better more often in phase chests")


func test_a_rare_gun_in_an_open_chest_shows_its_beam() -> void:
	var versus: VersusMode = await _open()
	var chest := versus.add_chest(Vector3(0, 0, 30), versus.item(&"sonic_shotgun", 3))
	assert_false(chest._beam.visible, "closed")
	chest.open(null, versus.settings)
	assert_true(chest._beam.visible)
	assert_eq(chest._label.modulate, versus.settings.rarities[3].color, "golden")
	chest.set_item(versus.item(&"medkit"))
	assert_false(chest._beam.visible, "no beam for a tool")


func test_the_precision_rifle_fires_a_straight_flare_that_hits_hard() -> void:
	var versus: VersusMode = await _open()
	var boss := versus.boss
	boss.body.set_physics_process(false)
	var hunter := versus.local_hunter()
	hunter.equip(versus.item(&"precision_rifle"))
	var gun := hunter.loadout.gun()
	assert_false(gun.automatic)
	assert_gt(gun.zoom_fov, 0.0, "it zooms")
	var player: Player = hunter.body
	boss.body.global_position = player.global_position - player.global_basis.z * 10.0
	_aim_at(versus, boss.body.global_position + Vector3.UP * 1.0)  # The body.
	await wait_physics_frames(1)
	var before := boss.health.health
	assert_true(hunter.fire())
	var flares := versus.get_children().filter(func(node: Node) -> bool: return node is Flare)
	assert_eq(flares.size(), 1, "a flare, not a ray")
	assert_eq((flares[0] as Flare).gravity, 0.0, "straight")
	await wait_physics_frames(10)
	assert_almost_eq(before - boss.health.health, gun.damage, 0.01, "its own damage")


func test_the_sonic_shotgun_hits_hard_up_close_and_pushes_the_boss_back() -> void:
	var versus: VersusMode = await _open()
	var boss := versus.boss
	boss.body.set_physics_process(false)
	var hunter := versus.local_hunter()
	hunter.equip(versus.item(&"sonic_shotgun"))
	var gun := hunter.loadout.gun()
	var player: Player = hunter.body
	boss.body.global_position = player.global_position - player.global_basis.z * 3.0
	_aim_at(versus, boss.body.global_position + Vector3.UP * 1.0)
	await wait_physics_frames(1)
	var start := boss.body.global_position
	var before := boss.health.health
	assert_true(hunter.fire())
	assert_gt(before - boss.health.health, gun.damage * 4.0, "most pellets hit")
	var tracers := versus.get_children().filter(func(node: Node) -> bool: return node is Tracer)
	assert_eq(tracers.size(), gun.pellets, "a tracer per pellet")
	await wait_physics_frames(30)
	assert_gt(boss.body.global_position.distance_to(start), 1.5, "pushed back")


func test_right_click_aims_every_gun_closer_steadier_and_slower() -> void:
	var versus: VersusMode = await _open()
	var hunter := versus.local_hunter()
	var player: Player = hunter.body
	var normal := versus.view.camera.fov
	var walk := player.settings.walk_speed
	var gun := hunter.loadout.gun()
	assert_gt(gun.spread, gun.spread_when(true), "the machine gun strays less aimed")
	Input.action_press("scan")
	await wait_seconds(0.5)
	assert_true(hunter.aiming)
	assert_almost_eq(versus.view.camera.fov, gun.zoom_fov, 0.5, "zoomed in")
	assert_almost_eq(versus.view.arm.spring_length, versus.settings.aim_view_distance, 0.05)
	assert_almost_eq(
		player.settings.walk_speed, walk * versus.settings.aim_speed_scale, 0.01, "walks slower"
	)
	versus.view.first_person = true
	await wait_seconds(0.1)
	var own: Camera3D = player.get_node("Head/Camera3D")
	assert_almost_eq(own.fov, gun.zoom_fov, 0.5, "the first person zooms too")
	Input.action_release("scan")
	await wait_seconds(0.5)
	assert_false(hunter.aiming)
	assert_almost_eq(versus.view.camera.fov, normal, 0.5)
	assert_almost_eq(player.settings.walk_speed, walk, 0.01, "its pace back")


func test_the_precision_rifle_aims_closest() -> void:
	var versus: VersusMode = await _open()
	var hunter := versus.local_hunter()
	hunter.equip(versus.item(&"precision_rifle"))
	var gun := hunter.loadout.gun()
	assert_eq(gun.spread_when(true), 0.0, "dead on")
	for id: StringName in [&"light_smg", &"assault_rifle", &"sonic_shotgun"]:
		assert_lt(gun.zoom_fov, versus.item(id).weapon.zoom_fov, "closer than %s" % id)
	versus.view.first_person = true
	Input.action_press("scan")
	await wait_seconds(0.5)
	assert_almost_eq(versus.view.camera.fov, gun.zoom_fov, 0.5)
	var arms := hunter.view_model.get_children().filter(
		func(node: Node) -> bool: return node is MeshInstance3D and node.visible
	)
	assert_eq(arms.size(), 2, "the gun stays in sight under the holographic sight")
	Input.action_release("scan")
	await wait_seconds(0.3)


func test_downed_while_aiming_it_crawls() -> void:
	var versus: VersusMode = await _open()
	var hunter := versus.local_hunter()
	var player: Player = hunter.body
	Input.action_press("scan")
	await wait_seconds(0.3)
	assert_true(hunter.aiming)
	hunter.take_blow(hunter.vitals.health)
	await wait_physics_frames(2)
	Input.action_release("scan")
	assert_false(hunter.aiming, "no aiming on the ground")
	assert_almost_eq(player.settings.walk_speed, versus.settings.crawl_speed, 0.01)
	hunter.vitals.revive()
	await wait_physics_frames(2)
	assert_gt(player.settings.walk_speed, versus.settings.crawl_speed * 2.0, "back on its feet")


func test_the_assault_rifle_is_an_automatic_gun_of_the_chests() -> void:
	var versus: VersusMode = await _open()
	var rifle := versus.item(&"assault_rifle")
	assert_not_null(rifle.weapon)
	assert_true(rifle.weapon.automatic)
	assert_true(
		versus.settings.items.any(
			func(item: VersusItem) -> bool: return item.id == &"assault_rifle"
		)
	)
	assert_gt(rifle.weight, 0.0, "found in the chests of the start")
	assert_lt(rifle.weapon.spread_when(true), versus.item(&"light_smg").weapon.spread_when(true))
