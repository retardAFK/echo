extends GutTest
## The Versus guns (spec S-025, Q2, Q4, T-403): rays that hit at once,
## spread within the gun's cone, the light machine gun held down, its clip
## and reload, the damage numbers and tracers.

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
	var eyes: Vector3 = boss.body.get_eye_position()
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
