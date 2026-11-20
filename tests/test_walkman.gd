extends GutTest
## The walkman (S-020, T-334, piste R3): put down, it plays footsteps that go
## away over 15 m, like a hunted running, to lure the monster.

const SETTINGS := preload("res://game/data/ruse_settings.tres")
const WALKMAN_SCENE := preload("res://game/entities/walkman/walkman.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")

var _steps: Array[NoiseEvent] = []


func before_each() -> void:
	_steps.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	for node in get_tree().get_nodes_in_group(Walkman.GROUP):
		node.free()


func _record(event: NoiseEvent) -> void:
	if event.source is Walkman:
		_steps.append(event)


func _walkman(at: Vector3, yaw := 0.0) -> Walkman:
	var walkman: Walkman = WALKMAN_SCENE.instantiate()
	add_child(walkman)
	walkman.global_position = at
	walkman.global_rotation = Vector3(0.0, yaw, 0.0)
	return walkman


## Plays the walkman to the end, by hand, in steps of 0.1 s.
func _play(walkman: Walkman) -> void:
	walkman.set_physics_process(false)
	for i in 400:
		if walkman.done:
			return
		walkman._physics_process(0.1)


func test_each_hunted_carries_one() -> void:
	var inventory := Inventory.new(SETTINGS)
	assert_eq(inventory.count(Inventory.Kind.WALKMAN), 1, "one per hunted, from the start")
	assert_false(inventory.can_take(Inventory.Kind.WALKMAN))
	assert_string_contains(CarryHud.describe(inventory), "Walkman")


func test_footsteps_go_away_over_the_path_after_the_delay() -> void:
	var walkman := _walkman(Vector3(0, 0, 0), PI / 2.0)  # Faces -X.
	walkman.set_physics_process(false)
	walkman._physics_process(SETTINGS.walkman_delay - 0.5)
	assert_eq(_steps.size(), 0, "silent first: time to get away")
	_play(walkman)
	assert_true(walkman.done)
	var expected := floori(SETTINGS.walkman_path_length / SETTINGS.walkman_stride) + 1
	assert_eq(_steps.size(), expected)
	for step in _steps:
		assert_eq(step.type, NoiseEvent.Type.FOOTSTEP)
		assert_eq(step.noise_range, SETTINGS.walkman_step_range)
		assert_false(step.by_monster)
	assert_almost_eq(_steps[0].position, Vector3.ZERO, Vector3.ONE * 0.01)
	var last := _steps[-1].position
	assert_lt(last.x, -SETTINGS.walkman_path_length + SETTINGS.walkman_stride, "away along -X")
	assert_almost_eq(last.z, 0.0, 0.01)
	_play(walkman)
	assert_eq(_steps.size(), expected, "it plays once")


func test_the_steps_take_the_time_of_a_run() -> void:
	var walkman := _walkman(Vector3.ZERO)
	walkman.set_physics_process(false)
	var time := 0.0
	while not walkman.done and time < 60.0:
		walkman._physics_process(0.1)
		time += 0.1
	var run := SETTINGS.walkman_delay + SETTINGS.walkman_path_length / SETTINGS.walkman_speed
	assert_almost_eq(time, run, 0.2)


func test_a_wall_stops_the_steps_before_it() -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = NoiseBus.WALLS_COLLISION_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = Vector3(0, 1.5, -6)
	var walkman := _walkman(Vector3.ZERO)  # Faces -Z, the wall 6 m ahead.
	await wait_physics_frames(2)
	_play(walkman)
	assert_almost_eq(walkman.path_length, 6.0 - 0.1 - Walkman.WALL_MARGIN, 0.05)
	for step in _steps:
		assert_gt(step.position.z, -6.0 + 0.1, "never through the wall")


func test_the_ai_monster_goes_to_its_steps() -> void:
	GameSession.role = GameSession.Role.HUNTED
	var map: Node3D = MAP_SCENE.instantiate()
	add_child_autofree(map)
	var monster: Monster = map.get_node("Monster")
	monster.set_physics_process(false)
	await wait_physics_frames(2)
	var walkman := _walkman(monster.global_position + Vector3(6, 0, 0))
	_play(walkman)
	assert_eq(monster.brain.state, MonsterBrain.State.INVESTIGATE, "it takes them for a hunted")


func test_the_player_puts_it_down_facing_ahead() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child_autofree(body)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0, 0.1, 0)
	player.rotation.y = 0.7
	await wait_physics_frames(2)
	watch_signals(player)
	player.commands.push(PlayerCommands.Action.WALKMAN)
	player.apply_actions()
	assert_eq(player.inventory.count(Inventory.Kind.WALKMAN), 0)
	assert_signal_emitted_with_parameters(player, "ruse_used", [&"walkman"])
	var walkmen := get_tree().get_nodes_in_group(Walkman.GROUP)
	assert_eq(walkmen.size(), 1)
	var facing := -player.global_basis.z
	facing.y = 0.0
	assert_almost_eq((walkmen[0] as Walkman).direction().dot(facing.normalized()), 1.0, 0.01)
	player.commands.push(PlayerCommands.Action.WALKMAN)
	player.apply_actions()
	assert_eq(get_tree().get_nodes_in_group(Walkman.GROUP).size(), 1, "only one per game")


func test_the_command_travels_online() -> void:
	var commands := PlayerCommands.new()
	commands.push(PlayerCommands.Action.WALKMAN)
	var copy := PlayerCommands.from_bytes(commands.to_bytes())
	assert_eq(copy.take_actions(), [PlayerCommands.Action.WALKMAN] as Array[PlayerCommands.Action])


func test_online_the_room_shows_it_and_the_client_copy_stays_silent() -> void:
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, Node3D.new())
	add_child_autofree(net)
	var walkman: Walkman = WALKMAN_SCENE.instantiate()
	net.get_parent().add_child(walkman)
	walkman.global_position = Vector3(3, 0, 4)
	walkman.global_rotation.y = 1.0
	await wait_physics_frames(1)
	assert_has(net.sent_events, [1, [NetGame.Event.WALKMAN, Vector3(3, 0, 4), 1.0]])
	walkman.free()
	var client := NetGame.new()
	add_child_autofree(client)
	client.apply_event([NetGame.Event.WALKMAN, Vector3(1, 0, 2), 0.5])
	var copy := get_tree().get_nodes_in_group(Walkman.GROUP)[0] as Walkman
	assert_true(copy.mirror)
	assert_almost_eq(copy.global_rotation.y, 0.5, 0.001)
	_play(copy)
	assert_eq(_steps.size(), 0, "the room plays the steps")


func test_the_carried_count_travels_in_the_snapshot() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, player)
	add_child_autofree(net)
	assert_eq(net.snapshot_for(1)["you"][16], 1)
	player.inventory.use(Inventory.Kind.WALKMAN)
	assert_eq(net.snapshot_for(1)["you"][16], 0)
