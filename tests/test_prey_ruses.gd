extends GutTest
## The AI prey uses the ruses (spec S-008, Q9, T-068), in the greybox.

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const FAR_AWAY := Vector3(18, 0, -18)
const RUSES := preload("res://game/data/ruse_settings.tres")
const CAR_SCENE := preload("res://game/entities/car_alarm/car_alarm.tscn")

var _map: GameMap
var _avatar: MonsterAvatar
var _prey: Prey
var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_avatar = _map.get_node("MonsterAvatar")
	_avatar.process_mode = Node.PROCESS_MODE_DISABLED
	_avatar.global_position = FAR_AWAY
	_prey = _map.prey
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)
	await wait_physics_frames(2)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	GameSession.role = GameSession.Role.HUNTED


func _record(event: NoiseEvent) -> void:
	_noises.append(event)


func _of_type(type: NoiseEvent.Type) -> Array[NoiseEvent]:
	var found: Array[NoiseEvent] = []
	for event in _noises:
		if event.type == type:
			found.append(event)
	return found


func test_speed_for_range_hits_the_distance() -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	for distance in [6.0, 12.0, 15.0]:
		var speed := ThrownBottle.speed_for_range(distance, 10.0, 1.6, gravity, 30.0)
		assert_almost_eq(ThrownBottle.flat_range(speed, 10.0, 1.6, gravity), distance, 0.05)


func test_prey_throws_a_bottle_where_it_aims() -> void:
	_prey.process_mode = Node.PROCESS_MODE_DISABLED
	_prey.inventory.take(Inventory.Kind.BOTTLE)
	var aim := _prey.global_position + Vector3(-8, 0, 0)
	assert_not_null(_prey.throw_bottle_to(aim))
	await wait_seconds(2.0)
	var impacts := _of_type(NoiseEvent.Type.IMPACT)
	assert_eq(impacts.size(), 1)
	if impacts.is_empty():
		return
	assert_almost_eq(impacts[0].position.x, aim.x, 1.5, "lands about where it aimed")
	assert_eq(_prey.ruse_counts.get(&"bottle", 0), 1)


func test_prey_places_an_alarm_clock() -> void:
	_prey.inventory.take(Inventory.Kind.DECOY)
	var decoy := _prey.place_decoy()
	assert_not_null(decoy)
	assert_eq(_prey.inventory.count(Inventory.Kind.DECOY), 0)
	assert_eq(_prey.ruse_counts.get(&"decoy", 0), 1)


func test_fleeing_prey_throws_away_and_hides_in_the_closet_nearby() -> void:
	var closet: HidingSpot = _map.get_node("Closet")
	_prey.inventory.take(Inventory.Kind.BOTTLE)
	var near := _prey.global_position + Vector3(-9, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, _avatar.settings.run_range, _avatar)
	await wait_physics_frames(2)
	assert_eq(_prey.get_state(), PreyBrain.State.FLEE)
	assert_eq(_prey.inventory.count(Inventory.Kind.BOTTLE), 0, "it threw its bottle")
	assert_almost_eq(_prey.brain.target.x, closet.get_exit_point().x, 0.01, "runs to the closet")
	await wait_seconds(5.0)
	assert_true(_prey.is_hidden(), "inside the closet")
	assert_eq(closet.occupant, _prey)
	assert_eq(_prey.ruse_counts.get(&"hide", 0), 1)


func test_hidden_prey_is_not_caught_by_contact_but_by_opening() -> void:
	var closet: HidingSpot = _map.get_node("Closet")
	_prey.global_position = closet.get_exit_point()
	await wait_physics_frames(2)
	closet.hold(_prey, 1.1)
	closet.release(_prey)
	assert_true(_prey.is_hidden())
	_avatar.global_position = closet.global_position + Vector3(0, 0, 0.8)
	_avatar.process_mode = Node.PROCESS_MODE_INHERIT
	await wait_physics_frames(5)
	assert_eq(_avatar.catch_count, 0, "touching the closet catches nothing")
	closet.hold(_avatar, 1.1)
	await wait_physics_frames(2)
	assert_eq(_avatar.catch_count, 1, "opening it does")
	assert_false(_prey.is_hidden())


func test_prey_gets_out_once_it_stops_hiding() -> void:
	var closet: HidingSpot = _map.get_node("Closet")
	_prey.global_position = closet.get_exit_point()
	await wait_physics_frames(2)
	closet.hold(_prey, 1.1)
	closet.release(_prey)
	assert_true(_prey.is_hidden())
	# Wandering again, it holds the door 1 s and gets out.
	await wait_seconds(1.5)
	assert_false(_prey.is_hidden())
	assert_null(closet.occupant)


func test_prey_does_not_hide_where_the_monster_looks() -> void:
	var closet: HidingSpot = _map.get_node("Closet")
	_avatar.global_position = closet.get_exit_point() + Vector3(0, 0, 3)
	assert_null(_prey.pick_hiding_spot(_avatar.global_position), "the monster would see it")
	_avatar.global_position = FAR_AWAY
	assert_eq(_prey.pick_hiding_spot(_avatar.global_position), closet)


## T-071: a fleeing prey swerves to a resting car alarm a few steps away and
## sets it off in passing.
func test_fleeing_prey_swerves_to_set_off_a_car_alarm() -> void:
	_map.get_node("Closet").free()  # No hiding spot to run to.
	var car: CarAlarm = CAR_SCENE.instantiate()
	_map.add_child(car)
	car.global_position = _prey.global_position + Vector3(5, 0, 2)
	await wait_physics_frames(2)
	var near := _prey.global_position + Vector3(-9, 0, 0)
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, near, _avatar.settings.run_range, _avatar)
	await wait_physics_frames(2)
	assert_eq(_prey.get_state(), PreyBrain.State.FLEE)
	await wait_until(func() -> bool: return car.state != CarAlarm.State.IDLE, 5.0)
	assert_ne(car.state, CarAlarm.State.IDLE, "set off")
	assert_eq(_prey.ruse_counts.get(&"car_alarm", 0), 1)


## T-071: a hiding spot that comes within reach while it flees is taken, unless
## the monster is close behind.
func test_fleeing_prey_hides_in_a_closet_met_on_the_way_when_far_enough() -> void:
	var closet: HidingSpot = _map.get_node("Closet")
	_prey.brain.state = PreyBrain.State.FLEE
	var threat := _prey.global_position + Vector3(-30, 0, 0)
	_prey.call("_look_for_hiding_spot", 1.0, threat)
	assert_almost_eq(_prey.brain.target.x, closet.get_exit_point().x, 0.01, "turns to the closet")


func test_fleeing_prey_ignores_a_closet_with_the_monster_close_behind() -> void:
	_prey.brain.state = PreyBrain.State.FLEE
	var target := _prey.brain.target
	var threat := _prey.global_position + Vector3(-5, 0, 0)
	_prey.call("_look_for_hiding_spot", 1.0, threat)
	assert_eq(_prey.brain.target, target, "keeps running")
