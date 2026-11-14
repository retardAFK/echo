extends GutTest
## Car alarms of the cité (spec S-006, T-042).

const CAR_SCENE := preload("res://game/entities/car_alarm/car_alarm.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const PROMPT_SCENE := preload("res://game/ui/interact_prompt.tscn")
const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")

var _car: CarAlarm
var _alarms: Array[NoiseEvent] = []


func before_each() -> void:
	_alarms.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)


func _record(event: NoiseEvent) -> void:
	if event.type == NoiseEvent.Type.CAR_ALARM:
		_alarms.append(event)


func _make_car() -> CarAlarm:
	var car: CarAlarm = CAR_SCENE.instantiate()
	var settings: CarAlarmSettings = car.settings.duplicate()
	settings.ring_time = 0.5
	settings.noise_interval = 0.2
	settings.rest_time = 0.3
	car.settings = settings
	add_child_autofree(car)
	return car


func test_settings_follow_the_reference_ranges() -> void:
	var settings: CarAlarmSettings = load("res://game/data/car_alarm_settings.tres")
	assert_eq(settings.alarm_range, 30.0, "section 6.2: car alarm, 30 m")


func test_alarm_rings_then_rests_then_can_ring_again() -> void:
	var car := _make_car()
	watch_signals(car)
	assert_true(car.can_interact(car.global_position + Vector3(1, 0, 0)))
	car.interact(null)
	assert_eq(car.state, CarAlarm.State.RINGING)
	assert_signal_emitted(car, "alarm_started")
	assert_false(car.can_interact(car.global_position), "no second alarm while it rings")
	await wait_seconds(0.7)
	assert_eq(car.state, CarAlarm.State.RESTING)
	assert_signal_emitted(car, "alarm_stopped")
	assert_between(_alarms.size(), 2, 4, "one noise every 0.2 s for 0.5 s")
	assert_eq(_alarms[0].noise_range, car.settings.alarm_range)
	assert_eq(_alarms[0].source, car)
	assert_false(car.can_interact(car.global_position), "resting")
	await wait_seconds(0.4)
	assert_eq(car.state, CarAlarm.State.IDLE)
	assert_true(car.can_interact(car.global_position))


func test_hazard_lights_blink_only_while_ringing() -> void:
	var car := _make_car()
	assert_false(car.get_node("HazardLeft").visible)
	car.interact(null)
	await wait_physics_frames(2)
	assert_true(car.get_node("HazardLeft").visible)
	await wait_seconds(0.7)
	assert_false(car.get_node("HazardLeft").visible)


func test_only_a_hunted_close_by_can_set_it_off() -> void:
	var car := _make_car()
	var reach := car.settings.trigger_distance
	assert_true(car.can_interact(car.global_position + Vector3(reach - 0.1, 0, 0)))
	assert_false(car.can_interact(car.global_position + Vector3(reach + 0.1, 0, 0)))


func test_player_sets_off_the_nearest_car_and_sees_the_hint() -> void:
	var car := _make_car()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = car.global_position + Vector3(10, 0, 0)
	var prompt: InteractPrompt = PROMPT_SCENE.instantiate()
	prompt.player = player
	add_child_autofree(prompt)
	await wait_process_frames(2)
	assert_null(player.get_interactable())
	assert_false(prompt.get_node("Label").visible)
	player.global_position = car.global_position + Vector3(1.5, 0, 0)
	await wait_process_frames(2)
	assert_null(player.get_interactable(), "in reach but behind the crosshair")
	assert_true(prompt.get_node("Crosshair").visible)
	player.rotation.y = PI / 2.0  # Looks toward -X, at the car.
	await wait_process_frames(2)
	assert_eq(player.get_interactable(), car)
	assert_true(prompt.get_node("Label").visible)
	assert_eq(prompt.get_node("Label").text, Settings.fill(tr("HUD_INTERACT_CAR_ALARM")))
	player.interact()
	assert_eq(car.state, CarAlarm.State.RINGING)


func test_the_cite_has_six_car_alarms() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var cars := map.get_node("CarAlarms").get_children()
	assert_eq(cars.size(), 6)
	for car in cars:
		assert_true(car is CarAlarm)


func test_alarm_draws_the_ai_monster() -> void:
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	monster.player = null
	var car: CarAlarm = map.get_node("CarAlarms/Car3")
	# The monster stands 20 m down the street from the car, nothing in between.
	monster.global_position = car.global_position + Vector3(0, 0, 20)
	await wait_physics_frames(2)
	car.interact(null)
	await wait_physics_frames(2)
	assert_eq(monster.get_state(), MonsterBrain.State.INVESTIGATE)
	assert_lt(monster.brain.target.distance_to(car.global_position), 2.0)
