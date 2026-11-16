extends GutTest
## The ventilation zones and the monitors of the hospital (spec S-014, Q5 and
## Q6, T-186).

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.scn")
const SETTINGS := preload("res://game/data/hospital_settings.tres")
const ORIGIN := Vector3(110, 0, 110)
## In the boiler room of the basement, and in the corridor next to it.
const BOILER_ROOM := Vector3(15, -2.7, 110)
const CORRIDOR := Vector3(21, -2.7, 110)

var _map: GameMap
var _heard: Array[NoiseEvent] = []


func before_each() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	_heard.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_on_noise)


func _on_noise(event: NoiseEvent) -> void:
	_heard.append(event)


func _world(plan: Vector3) -> Vector3:
	return Vector3(plan.x, plan.y, plan.z) - ORIGIN


func _monitors() -> Array[Monitor]:
	var found: Array[Monitor] = []
	for node in get_tree().get_nodes_in_group(Monitor.GROUP):
		found.append(node as Monitor)
	return found


func test_the_boiler_room_and_the_theatres_roar() -> void:
	assert_true(Ventilation.covers(get_tree(), _world(BOILER_ROOM)))
	assert_true(Ventilation.covers(get_tree(), _world(Vector3(15, 6.5, 85))), "operating theatre")
	assert_false(Ventilation.covers(get_tree(), _world(CORRIDOR)))
	assert_false(Ventilation.covers(get_tree(), _world(Vector3(15, 0.5, 110))), "above it")


func test_a_quiet_noise_in_the_roar_is_masked() -> void:
	var walk := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _world(BOILER_ROOM), 4.0)
	assert_true(walk.masked, "Q5: 4 m or less")
	var run := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _world(BOILER_ROOM), 14.0)
	assert_false(run.masked, "running is still heard")
	var outside := NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _world(CORRIDOR), 4.0)
	assert_false(outside.masked)


func test_the_monster_does_not_hear_a_masked_noise() -> void:
	var monster: Monster = _map.get_node("Monster")
	monster.global_position = _world(BOILER_ROOM + Vector3(0, 0, 1.5))
	await wait_physics_frames(2)
	var target_before: Vector3 = monster.brain.target
	NoiseBus.emit_noise(NoiseEvent.Type.FOOTSTEP, _world(BOILER_ROOM), 4.0)
	assert_eq(monster.brain.target, target_before, "masked: nothing heard")
	var masked := NoiseEvent.new(NoiseEvent.Type.FOOTSTEP, _world(BOILER_ROOM), 4.0)
	masked.masked = true
	assert_eq(NetGame.noise_message(masked, monster, true), [], "nor sent to a monster online")
	assert_false(NetGame.noise_message(masked, monster, false).is_empty(), "the hunted hear it")


func test_six_monitors_stand_in_the_hospital() -> void:
	var monitors := _monitors()
	assert_eq(monitors.size(), 6, "Q6")
	for monitor in monitors:
		var inside := false
		for building in _map.get_buildings():
			if building.get_complex() == "Hospital" and building.contains(monitor.global_position):
				inside = true
		assert_true(inside, "%s in the hospital" % monitor.name)


func test_a_monitor_beeps_once_then_falls_silent() -> void:
	var monitor := _monitors()[0]
	var player: Player = _map.get_node("Player")
	assert_true(monitor.wanted_by(player))
	assert_eq(monitor.get_prompt_for(player), "HUD_INTERACT_MONITOR")
	monitor.interact(player)
	assert_eq(monitor.state, Monitor.State.BEEPING)
	await wait_physics_frames(3)
	var beeps := _heard.filter(func(e: NoiseEvent) -> bool: return e.source == monitor)
	assert_eq(beeps.size(), 1)
	assert_eq(beeps[0].noise_range, SETTINGS.monitor_range)
	assert_eq(beeps[0].type, NoiseEvent.Type.MONITOR)
	monitor.beeping_left = 0.01
	await wait_physics_frames(2)
	assert_eq(monitor.state, Monitor.State.SPENT)
	assert_false(monitor.can_interact(monitor.global_position), "once per game")


func test_the_monster_switches_a_beeping_monitor_off() -> void:
	var monitor := _monitors()[1]
	var monster: Monster = _map.get_node("Monster")
	assert_false(monitor.wanted_by(monster), "nothing to switch off")
	monitor.interact(monster)
	assert_eq(monitor.state, Monitor.State.IDLE, "the monster does not switch it on")
	monitor.interact(_map.get_node("Player"))
	assert_true(monitor.wanted_by(monster))
	assert_eq(monitor.get_prompt_for(monster), "HUD_MONSTER_MONITOR_OFF")
	monitor.hold(monster, SETTINGS.monitor_off_hold + 0.01)
	assert_eq(monitor.state, Monitor.State.SPENT)


func test_monitors_are_mirrored_online() -> void:
	var world := NetWorld.new(_map)
	assert_eq(world.monitors.size(), 6)
	world.monitors[2].interact(_map.get_node("Player"))
	var state := world.state()
	world.monitors[2].switch_off()
	world.monitors[2].state = Monitor.State.IDLE
	world.monitors[2].mirror = true
	world.apply(state)
	assert_eq(world.monitors[2].state, Monitor.State.BEEPING)


func _gurneys() -> Array[Gurney]:
	var found: Array[Gurney] = []
	for node in get_tree().get_nodes_in_group(Gurney.GROUP):
		found.append(node as Gurney)
	return found


func _chairs() -> Array[Wheelchair]:
	var found: Array[Wheelchair] = []
	for node in get_tree().get_nodes_in_group(Wheelchair.GROUP):
		found.append(node as Wheelchair)
	return found


## The player standing in the ground floor corridor, facing south.
func _player_in_corridor(plan_y: float) -> Player:
	var player: Player = _map.get_node("Player")
	player.global_position = _world(Vector3(20.6, 0.1, plan_y))
	player.set("_controls", null)  # Driven by its commands, like online.
	player.rotation.y = PI  # Facing +z, south on the plan.
	player.commands.yaw = PI
	return player


func test_four_gurneys_and_four_wheelchairs() -> void:
	assert_eq(_gurneys().size(), 4, "Q7")
	assert_eq(_chairs().size(), 4, "Q7")


func test_a_hunted_pushes_a_gurney_and_lets_go() -> void:
	var gurney: Gurney = _map.get_node("Rolling/Gurney1")
	var player := _player_in_corridor(66.4)
	await wait_physics_frames(2)
	assert_true(gurney.can_interact(player.global_position))
	player.interact()
	assert_eq(player.pushing, gurney)
	assert_eq(player.get_interactable(), null, "interact lets go")
	player.commands.move = Vector2(0, -1)
	await wait_seconds(1.5)
	player.commands.move = Vector2.ZERO
	var lead := gurney.global_position - player.global_position
	assert_almost_eq(Vector2(lead.x, lead.z).length(), SETTINGS.gurney_lead, 0.3, "in front")
	assert_gt(gurney.global_position.z, _world(Vector3(0, 0, 70)).z, "it rolled south")
	var rolls := _heard.filter(
		func(e: NoiseEvent) -> bool: return e.type == NoiseEvent.Type.ROLL and e.source == gurney
	)
	assert_gt(rolls.size(), 0, "it rolls loud")
	player.interact()
	assert_null(player.pushing)
	assert_null(gurney.pusher)


func test_the_monster_shoves_a_gurney_over() -> void:
	var gurney: Gurney = _map.get_node("Rolling/Gurney1")
	var monster: Monster = _map.get_node("Monster")
	assert_true(gurney.wanted_by(monster))
	assert_eq(gurney.get_prompt_for(monster), "HUD_MONSTER_SHOVE_GURNEY")
	gurney.hold(monster, SETTINGS.gurney_shove_hold / 2.0)
	assert_false(gurney.tipped, "it takes a second")
	gurney.hold(monster, SETTINGS.gurney_shove_hold / 2.0 + 0.01)
	assert_true(gurney.tipped)
	assert_eq(gurney.collision_layer, 0, "out of the way")
	var shoves := _heard.filter(func(e: NoiseEvent) -> bool: return e.source == monster)
	assert_eq(shoves.size(), 1)
	assert_eq(shoves[0].noise_range, SETTINGS.gurney_shove_range)
	assert_false(gurney.can_interact(gurney.global_position), "nobody takes it any more")


func test_the_ai_monster_shoves_a_gurney_on_its_way() -> void:
	var gurney: Gurney = _map.get_node("Rolling/Gurney1")
	var at := gurney.global_position
	var found := Gurney.ahead(get_tree(), at + Vector3(0, 0, -1.2), Vector3.BACK, 1.4)
	assert_eq(found, gurney, "ahead")
	assert_null(Gurney.ahead(get_tree(), at + Vector3(0, 0, -1.2), Vector3.FORWARD, 1.4), "behind")


func test_a_wheelchair_rolls_about_eight_meters_squeaking() -> void:
	var chair: Wheelchair = _map.get_node("Rolling/Wheelchair3")
	var start := chair.global_position
	chair.launch(Vector3.BACK)  # South, down the corridor of the 1st floor.
	await wait_seconds(4.0)
	assert_false(chair.is_rolling(), "stopped")
	var gone := Vector2(chair.global_position.x - start.x, chair.global_position.z - start.z)
	assert_almost_eq(gone.length(), SETTINGS.wheelchair_distance, 1.0)
	var squeaks := _heard.filter(func(e: NoiseEvent) -> bool: return e.source == chair)
	assert_gt(squeaks.size(), 4)
	assert_eq(squeaks[0].noise_range, SETTINGS.wheelchair_range)


func test_gurneys_and_wheelchairs_are_mirrored_online() -> void:
	var world := NetWorld.new(_map)
	assert_eq(world.gurneys.size(), 4)
	assert_eq(world.chairs.size(), 4)
	var gurney := world.gurneys[0]
	var state := world.state()
	var was := gurney.global_position
	gurney.global_position += Vector3(2, 0, 0)
	world.apply(state)
	assert_almost_eq(gurney.global_position.x, was.x, 0.02)
