extends GutTest
## The scan hears one level of the hospital, the one the monster aims at or
## stands in (spec S-014, Q4, T-184).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const ORIGIN := Vector3(110, 0, 110)

var _map: GameMap
var _avatar: MonsterAvatar


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.avatar
	_avatar.set_physics_process(false)  # Driven by hand.


func after_each() -> void:
	GameSession.role = GameSession.Role.HUNTED


func _level(level_name: String) -> Building:
	return _map.get_node("Buildings/%s" % level_name)


## Puts the monster's feet at a plan point (x, height, y), looking at another.
func _stand(feet: Vector3, target: Vector3) -> void:
	var at := Vector3(feet.x, feet.y, feet.z) - ORIGIN
	_avatar.global_position = at
	var look := Vector3(target.x, target.y, target.z) - ORIGIN
	var eye := at + (_avatar.get_node("Head") as Node3D).position
	_avatar.look_at(Vector3(look.x, at.y, look.z), Vector3.UP)
	var head := _avatar.get_node("Head") as Node3D
	head.rotation.x = atan2(look.y - eye.y, Vector2(look.x - eye.x, look.z - eye.z).length())
	await wait_physics_frames(2)


func test_from_outside_the_window_aimed_at_is_the_level() -> void:
	await _stand(Vector3(42, 0, 100), Vector3(32, 4.5, 100))
	assert_eq(_avatar.aim_building(), _level("HospitalFirst"))
	await _stand(Vector3(42, 0, 100), Vector3(32, 7.5, 100))
	assert_eq(_avatar.aim_building(), _level("HospitalSecond"))
	await _stand(Vector3(42, 0, 100), Vector3(32, 1.2, 100))
	assert_eq(_avatar.aim_building(), _level("HospitalGround"))


func test_the_basement_is_aimed_at_by_the_quay_or_the_foot_of_the_walls() -> void:
	await _stand(Vector3(8, -3, 92), Vector3(12, -2, 91))
	assert_eq(_avatar.aim_building(), _level("HospitalBasement"), "the quay doors")
	await _stand(Vector3(36, 0, 94), Vector3(32.2, -1.2, 94))
	assert_eq(_avatar.aim_building(), _level("HospitalBasement"), "a basement window")


func test_inside_it_scans_the_level_it_stands_in() -> void:
	# Looking up at the ceiling does not reach the storey above.
	await _stand(Vector3(21, 3, 94), Vector3(21, 9, 99))
	assert_eq(_avatar.aim_building(), _level("HospitalFirst"))
	await _stand(Vector3(21, -3, 94), Vector3(21, -5, 99))
	assert_eq(_avatar.aim_building(), _level("HospitalBasement"))


func test_a_noise_of_another_level_is_not_heard() -> void:
	var first := _level("HospitalFirst")
	assert_true(first.contains(Vector3(21, 3.5, 94) - ORIGIN))
	assert_false(first.contains(Vector3(21, 0.5, 94) - ORIGIN), "the ground floor")
	assert_false(first.contains(Vector3(21, 6.5, 94) - ORIGIN), "the 2nd floor")
