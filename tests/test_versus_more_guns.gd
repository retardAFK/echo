extends GutTest
## The guns of T-415 (spec S-025): the pulse pistol, the burst rifle (three
## shots a click, then a pause) and the neon minigun, all in the chests,
## with a model, a sound and a sight; and the chests inside the buildings.

const ROOM_SCENE := preload("res://game/maps/test_room/test_room.tscn")
const SETTINGS := preload("res://game/modes/versus/data/versus_settings.tres")
const NEW_GUNS: Array[StringName] = [&"pulse_pistol", &"burst_rifle", &"neon_minigun"]

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


func test_the_new_guns_are_in_the_chests_whole() -> void:
	for id in NEW_GUNS:
		var found := SETTINGS.items.filter(func(item: VersusItem) -> bool: return item.id == id)
		assert_eq(found.size(), 1, "%s listed" % id)
		var item: VersusItem = found[0]
		assert_eq(item.slot, VersusItem.Slot.WEAPON)
		assert_not_null(item.weapon, "%s shoots" % id)
		assert_gt(item.weight + item.phase_weight, 0.0, "%s can be drawn" % id)
		assert_ne(Text.t(item.name_key), item.name_key, "%s has a name" % id)
		assert_gt(item.weapon.zoom_fov, 0.0, "%s aims" % id)
		assert_true(GunModel.FORE_GRIPS.has(id) and GunModel.SIGHTS.has(id), "%s held" % id)
		assert_true(ViewModel.GUN_SCALES.has(id), "%s in first person" % id)
		assert_true(VersusSounds.GUN_SOUNDS.has(id), "%s has its shot" % id)
	var minigun: VersusWeapon = (
		SETTINGS
		. items
		. filter(func(item: VersusItem) -> bool: return item.id == &"neon_minigun")[0]
		. weapon
	)
	assert_true(minigun.automatic)
	assert_gt(minigun.clip, 60, "a big drum")


func test_the_burst_rifle_fires_three_shots_then_pauses() -> void:
	var versus := await _open()
	var hunter := versus.local_hunter()
	var rifle := versus.item(&"burst_rifle")
	var gun := rifle.weapon
	assert_eq(gun.burst, 3)
	hunter.equip(rifle)
	hunter.set_physics_process(false)  # Driven by hand.
	var clip := hunter.clip
	for shot in gun.burst:
		hunter._cooldown = 0.0
		assert_true(hunter.fire(), "shot %d" % (shot + 1))
		if shot < gun.burst - 1:
			assert_true(hunter._fires_now(), "the burst goes on by itself")
	assert_eq(hunter.clip, clip - gun.burst)
	assert_almost_eq(hunter._cooldown, gun.burst_pause, 0.001, "then a pause")
	assert_false(hunter._fires_now(), "the next burst waits for a click")


func test_a_one_shot_gun_has_no_burst() -> void:
	var versus := await _open()
	var hunter := versus.local_hunter()
	var pistol := versus.item(&"pulse_pistol")
	hunter.equip(pistol)
	hunter.set_physics_process(false)
	assert_true(hunter.fire())
	assert_almost_eq(hunter._cooldown, pistol.weapon.fire_interval, 0.001)
	assert_false(hunter._fires_now())


func test_there_are_chests_inside_the_buildings_from_the_start() -> void:
	var arena: VersusArena = SETTINGS.arenas[0]
	var start := arena.chest_spots.slice(0, SETTINGS.arena_chests)
	assert_gte(SETTINGS.arena_chests, 7)
	var indoors := 0
	for spot in start:
		if spot.y < -1.0 or _under_a_roof(spot):
			indoors += 1
	assert_gte(indoors, 3, "the tower, the social centre, the car park")
	var needed := SETTINGS.arena_chests + (SETTINGS.phases.size() - 1) * SETTINGS.phase_chests
	assert_gte(arena.chest_spots.size(), needed, "a spot for each chest")


## The tower's ground floor and the social centre (world x, z).
static func _under_a_roof(spot: Vector3) -> bool:
	var tower := Rect2(-18, -22, 24, 24)
	var centre := Rect2(30, -50, 38, 24)
	var flat := Vector2(spot.x, spot.z)
	return tower.has_point(flat) or centre.has_point(flat)
