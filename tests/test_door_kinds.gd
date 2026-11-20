extends GutTest
## Fire doors, emergency exits and metal floors (spec S-016, Q3 and Q9, T-234).

const DOOR_SCENE := preload("res://game/entities/door/door.tscn")
const METAL_SCENE := preload("res://game/entities/metal_floor/metal_floor.tscn")
const SETTINGS := preload("res://game/data/door_settings.tres")
const NOISE := preload("res://game/data/noise_settings.tres")
const DOORS_TEST := preload("res://tests/test_doors.gd")


## Someone standing somewhere, who does not sneak.
class Walker:
	extends Node3D


var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	NoiseBus.mirror = false


func _record(event: NoiseEvent) -> void:
	if event.type == NoiseEvent.Type.DOOR:
		_noises.append(event)


func _door(kind: Door.Kind) -> Door:
	var door: Door = DOOR_SCENE.instantiate()
	door.kind = kind
	add_child_autofree(door)
	return door


func _walker(at: Vector3) -> Walker:
	var walker := Walker.new()
	add_child_autofree(walker)
	walker.global_position = at
	return walker


func test_settings_follow_the_spec() -> void:
	assert_eq(SETTINGS.fire_close_delay, 3.0, "Q3: closes 3 s after")
	assert_eq(SETTINGS.slam_range, 5.0, "Q3: slams at 5 m")
	assert_eq(SETTINGS.emergency_range, 10.0, "Q3: crash bar at 10 m")
	assert_eq(NOISE.metal_walk_range, 6.0, "Q9: walking on metal, 6 m")
	assert_eq(NOISE.metal_sprint_range, 18.0, "Q9: running on metal, 18 m")


func test_a_fire_door_slams_shut_on_its_own() -> void:
	var door := _door(Door.Kind.FIRE)
	var walker := _walker(Vector3(0, 0, 1))
	assert_true(door.hold(walker, 0.016))
	assert_true(door.is_open)
	await wait_seconds(SETTINGS.fire_close_delay - 0.5)
	assert_true(door.is_open, "not yet")
	await wait_seconds(1.0)
	assert_false(door.is_open, "closed on its own")
	assert_eq(_noises.size(), 2)
	assert_eq(_noises[1].noise_range, 5.0, "the slam")
	assert_null(_noises[1].source.last_user, "nobody closed it")


func test_on_an_online_client_the_room_closes_it() -> void:
	var door := _door(Door.Kind.FIRE)
	NoiseBus.mirror = true
	door.mirror(true)
	await wait_seconds(SETTINGS.fire_close_delay + 0.5)
	assert_true(door.is_open, "the client waits for the room")


func test_a_normal_door_stays_open() -> void:
	var door := _door(Door.Kind.NORMAL)
	door.open_by(null)
	await wait_seconds(SETTINGS.fire_close_delay + 0.5)
	assert_true(door.is_open)


func test_an_emergency_exit_opens_from_inside_only_and_stays_open() -> void:
	var door := _door(Door.Kind.EMERGENCY)
	var outside := _walker(Vector3(0, 0, 1))
	var inside := _walker(Vector3(0, 0, -1))
	assert_eq(door.get_prompt_for(outside), "", "no handle outside")
	assert_false(door.hold(outside, 0.016))
	door.open_by(outside)
	assert_false(door.is_open, "the AI cannot open it from outside either")
	assert_eq(door.get_prompt_for(inside), "HUD_INTERACT_DOOR_OPEN")
	assert_true(door.hold(inside, 0.016))
	assert_true(door.is_open)
	assert_eq(_noises[0].noise_range, 10.0, "Q3: the crash bar")
	door.release(inside)
	assert_false(door.hold(inside, 0.016), "it stays open")
	assert_eq(door.get_prompt_for(inside), "")
	assert_true(door.is_open)


func test_the_monster_smashes_an_emergency_exit_from_outside() -> void:
	var door := _door(Door.Kind.EMERGENCY)
	var outside := _walker(Vector3(0, 0, 1))
	door.smash(outside)
	assert_true(door.is_open)
	assert_eq(_noises[0].noise_range, SETTINGS.smash_range)


func test_footsteps_on_metal_carry_farther() -> void:
	assert_eq(NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.WALK, FloorSurface.Kind.METAL), 6.0)
	assert_eq(
		NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.SPRINT, FloorSurface.Kind.METAL), 18.0
	)
	assert_eq(
		NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.CROUCH, FloorSurface.Kind.METAL),
		1.0,
		"crouched: silent"
	)
	assert_eq(NoiseMath.range_for_gait(NOISE, PlayerMotion.Gait.WALK), 4.0)


func test_metal_floor_covers_its_box() -> void:
	var metal: MetalFloor = METAL_SCENE.instantiate()
	metal.size = Vector3(2, 3, 4)
	add_child_autofree(metal)
	metal.global_position = Vector3(10, 0, 0)
	assert_true(MetalFloor.under(get_tree(), Vector3(10.5, 1, 1.5)))
	assert_false(MetalFloor.under(get_tree(), Vector3(11.5, 1, 0)), "beside")
	assert_false(MetalFloor.under(get_tree(), Vector3(10, 2, 0)), "above")


func test_a_fire_door_waits_for_the_doorway_to_be_clear() -> void:
	var door := _door(Door.Kind.FIRE)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 2  # A hunted.
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(0, 1, 0)
	door.open_by(null)
	await wait_seconds(SETTINGS.fire_close_delay + 0.5)
	assert_true(door.is_open, "someone in the doorway: it waits")
	body.global_position = Vector3(0, 1, 3)
	await wait_seconds(0.3)
	assert_false(door.is_open, "clear: it shuts")


func test_a_shutter_rolls_up_loudly_even_crouched() -> void:
	var door := _door(Door.Kind.SHUTTER)
	var sneaker := Node3D.new()
	sneaker.set_script(DOORS_TEST.Sneaker)
	add_child_autofree(sneaker)
	sneaker.global_position = Vector3(0, 0, 1)
	assert_eq(door.get_prompt(), "HUD_INTERACT_SHUTTER_OPEN")
	assert_true(door.hold(sneaker, 0.016), "at once, no quiet way")
	assert_eq(_noises[0].noise_range, SETTINGS.shutter_range)
	assert_eq(SETTINGS.shutter_range, 12.0)
	await wait_seconds(SETTINGS.swing_time + 0.1)
	var hinge: Node3D = door.get_node("Hinge")
	assert_almost_eq(hinge.position.y, door.height - SETTINGS.shutter_hang, 0.01, "rolled up")
	assert_almost_eq(hinge.rotation.y, 0.0, 0.001, "it does not swing")


func test_a_bell_rings_when_the_door_opens_even_slowly() -> void:
	var door := _door(Door.Kind.NORMAL)
	door.bell = true
	var sneaker := Node3D.new()
	sneaker.set_script(DOORS_TEST.Sneaker)
	add_child_autofree(sneaker)
	sneaker.global_position = Vector3(0, 0, 1)
	door.hold(sneaker, 0.5)
	assert_true(door.hold(sneaker, 0.6))
	assert_eq(_noises[0].noise_range, SETTINGS.bell_range, "the bell, not the quiet 2 m")
	door.release(sneaker)
	door.hold(sneaker, 0.5)
	door.hold(sneaker, 0.6)
	assert_eq(_noises[1].noise_range, SETTINGS.quiet_range, "closing it slowly: no bell")


func test_each_way_of_moving_a_door_has_its_sound() -> void:
	var door := _door(Door.Kind.NORMAL)
	assert_eq(door.sound_for(true, SETTINGS.open_range), Door.SOUND_OPEN)
	assert_eq(door.sound_for(false, SETTINGS.open_range), Door.SOUND_CLOSE)
	assert_eq(door.sound_for(true, SETTINGS.quiet_range), Door.SOUND_QUIET, "crouched")
	assert_eq(door.sound_for(true, SETTINGS.smash_range), Door.SOUND_SMASH, "the monster running")
	assert_eq(
		_door(Door.Kind.EMERGENCY).sound_for(true, SETTINGS.emergency_range), Door.SOUND_CRASH_BAR
	)
	assert_eq(_door(Door.Kind.SHUTTER).sound_for(false, SETTINGS.shutter_range), Door.SOUND_SHUTTER)


func test_the_sound_played_follows_the_door() -> void:
	var door := _door(Door.Kind.FIRE)
	var creak: AudioStreamPlayer3D = door.get_node("Creak")
	var walker := _walker(Vector3(0, 0, 1))
	door.hold(walker, 0.016)
	assert_eq(creak.stream, Door.SOUND_OPEN)
	door.release(walker)
	await wait_seconds(SETTINGS.fire_close_delay + 0.2)
	assert_false(door.is_open)
	assert_eq(creak.stream, Door.SOUND_FIRE_SLAM, "it slams on its own")


func test_a_client_door_closing_on_its_player_does_not_sweep_it_away() -> void:
	# Online, the room shuts a fire door while the client's own player, a few
	# centimeters ahead of the room's, stands where the open leaf lies: the leaf
	# swinging shut used to sweep it across the corridor and through its wall
	# (net_match fall in the cellar corridor, S-020, T-330). It now only stops
	# bodies once shut, pushing them along the corridor at worst.
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	ground.add_child(plane)
	add_child_autofree(ground)
	var door := _door(Door.Kind.FIRE)
	NoiseBus.mirror = true
	door.mirror(true)  # The leaf swings to -Z, along the hinge side at x = -0.6.
	await wait_seconds(SETTINGS.swing_time + 0.1)
	var player: Player = load("res://game/entities/player/player.tscn").instantiate()
	player.local_controls = false
	player.position = Vector3(-0.1, 0, -0.6)
	add_child_autofree(player)
	await wait_physics_frames(3)
	var before := player.global_position
	door.mirror(false)
	await wait_seconds(SETTINGS.swing_time + 0.3)
	var across := absf(player.global_position.x - before.x)
	assert_lt(across, 0.1, "not swept across the doorway")
