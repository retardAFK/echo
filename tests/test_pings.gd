extends GutTest
## Team marks (S-020, T-328, piste A1): a hunted marks the monster or a spot,
## its teammates see it for a while, the monster never gets it, and an AI
## prey near a "monstre ici" mark runs.

const SETTINGS := preload("res://game/data/ping_settings.tres")
const PING_SCENE := preload("res://game/entities/ping/ping.tscn")
const PLAYER_SCENE := preload("res://game/entities/player/player.tscn")
const AVATAR_SCENE := preload("res://game/entities/monster/monster_avatar.tscn")
const PREY_SCENE := preload("res://game/entities/prey/prey.tscn")


func _wall(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = NoiseBus.WALLS_COLLISION_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child_autofree(body)


func _monster(at: Vector3) -> Node3D:
	var monster := Node3D.new()
	add_child_autofree(monster)
	monster.global_position = at
	return monster


func _space() -> PhysicsDirectSpaceState3D:
	return get_tree().root.get_world_3d().direct_space_state


func test_settings_are_the_starting_points() -> void:
	assert_eq(SETTINGS.time, 8.0)
	assert_eq(SETTINGS.cooldown, 2.0)
	assert_eq(SETTINGS.reach, 60.0)
	assert_eq(SETTINGS.ai_flee_range, 25.0)


func test_aiming_at_the_monster_marks_the_monster() -> void:
	_wall(Vector3(10, 4, 0.5), Vector3(0, 2, -30))
	var monster := _monster(Vector3(0.5, 0, -10))
	await wait_physics_frames(2)
	var eye := Vector3(0, 1.6, 0)
	var forward := Vector3(0, 0, -1)
	var aimed := Ping.aim(eye, forward, [monster], _space(), [], SETTINGS)
	assert_eq(aimed[0], Ping.Kind.MONSTER)
	assert_eq(aimed[1], monster.global_position)
	monster.global_position = Vector3(6, 0, -10)
	aimed = Ping.aim(eye, forward, [monster], _space(), [], SETTINGS)
	assert_eq(aimed[0], Ping.Kind.HERE, "aim far from the monster: the wall behind")
	assert_almost_eq((aimed[1] as Vector3).z, -29.75, 0.01)


func test_a_wall_hides_the_monster_from_the_mark() -> void:
	_wall(Vector3(10, 4, 0.5), Vector3(0, 2, -5))
	var monster := _monster(Vector3(0, 0, -10))
	await wait_physics_frames(2)
	var aimed := Ping.aim(Vector3(0, 1.6, 0), Vector3(0, 0, -1), [monster], _space(), [], SETTINGS)
	assert_eq(aimed[0], Ping.Kind.HERE, "the wall, not the monster behind it")


func test_aiming_at_the_sky_marks_nothing() -> void:
	var aimed := Ping.aim(Vector3(0, 1.6, 0), Vector3.UP, [], _space(), [], SETTINGS)
	assert_eq(aimed, [])


func test_a_mark_fades_after_its_time() -> void:
	var ping: Ping = PING_SCENE.instantiate()
	add_child(ping)
	assert_true(ping.is_in_group(Ping.GROUP))
	assert_eq(ping.left, SETTINGS.time)
	ping._process(SETTINGS.time - 0.1)
	assert_false(ping.is_queued_for_deletion())
	ping._process(0.2)
	assert_true(ping.is_queued_for_deletion())
	await wait_process_frames(1)


func test_a_hunted_marks_once_per_cooldown() -> void:
	_wall(Vector3(10, 4, 0.5), Vector3(0, 2, -20))
	var player: Player = PLAYER_SCENE.instantiate()
	player.local_controls = false
	add_child_autofree(player)
	await wait_physics_frames(2)
	player.commands.push(PlayerCommands.Action.PING)
	player.apply_actions()
	var pings := get_tree().get_nodes_in_group(Ping.GROUP)
	assert_eq(pings.size(), 1, "the wall in front is marked")
	assert_eq((pings[0] as Ping).kind, Ping.Kind.HERE)
	player.commands.push(PlayerCommands.Action.PING)
	player.apply_actions()
	assert_eq(get_tree().get_nodes_in_group(Ping.GROUP).size(), 1, "no spam")
	for ping in get_tree().get_nodes_in_group(Ping.GROUP):
		ping.free()


func test_a_monster_mark_warns_ai_preys_in_range() -> void:
	var near: Prey = PREY_SCENE.instantiate()
	var far: Prey = PREY_SCENE.instantiate()
	near.position = Vector3(10, 0, 0)
	far.position = Vector3(SETTINGS.ai_flee_range + 10, 0, 0)
	near.set_physics_process(false)
	far.set_physics_process(false)
	add_child_autofree(near)
	add_child_autofree(far)
	var ping: Ping = PING_SCENE.instantiate()
	ping.kind = Ping.Kind.MONSTER
	add_child_autofree(ping)
	assert_true(near.get("_heard_monster"), "it runs as if it heard the monster")
	assert_false(far.get("_heard_monster"))
	near.set("_heard_monster", false)
	var copy: Ping = PING_SCENE.instantiate()
	copy.kind = Ping.Kind.MONSTER
	copy.mirror = true
	add_child_autofree(copy)
	assert_false(near.get("_heard_monster"), "a client's copy warns nobody")


func test_the_room_sends_marks_to_the_hunted_only() -> void:
	var net := NetGame.new()
	net.settings = NetSettings.new()
	net.is_room = true
	net.add_avatar(1, 1, Node3D.new())
	net.add_avatar(2, LobbyState.MONSTER_SEAT, Node3D.new())
	add_child_autofree(net)
	var ping: Ping = PING_SCENE.instantiate()
	ping.kind = Ping.Kind.MONSTER
	ping.position = Vector3(3, 0, 4)
	add_child_autofree(ping)
	await wait_process_frames(1)
	var sent := net.sent_events.filter(func(s: Array) -> bool: return s[1][0] == NetGame.Event.PING)
	assert_eq(sent, [[1, [NetGame.Event.PING, Vector3(3, 0, 4), Ping.Kind.MONSTER]]])
	for avatar: Node in net.avatars.values():
		avatar.free()
	net.avatars.clear()


func test_a_client_shows_a_copy_of_the_room_s_mark() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var net := NetGame.new()
	parent.add_child(net)
	net.apply_event([NetGame.Event.PING, Vector3(1, 0, 2), Ping.Kind.HERE])
	var pings := get_tree().get_nodes_in_group(Ping.GROUP)
	assert_eq(pings.size(), 1)
	assert_true((pings[0] as Ping).mirror)
	assert_eq((pings[0] as Ping).global_position, Vector3(1, 0, 2))


func test_the_markers_say_what_and_how_far() -> void:
	assert_eq(PingMarkers.text_for(Ping.Kind.MONSTER, 12.4), "Monstre · 12 m")
	assert_eq(PingMarkers.text_for(Ping.Kind.HERE, 30.6), "Ici · 31 m")
	assert_has(ControlsText.keys_for(GameSession.Role.HUNTED), "CONTROLS_PING")
	assert_does_not_have(ControlsText.keys_for(GameSession.Role.MONSTER), "CONTROLS_PING")
	assert_true(UserSettings.REMAPPABLE.has("ping"))
	assert_true(InputMap.has_action("ping"))
