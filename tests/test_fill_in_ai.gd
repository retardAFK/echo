extends GutTest
## Fill-in AI of an online game (S-010, T-101): an AI prey plays in each
## empty hunted seat, frees a captured teammate when it is safe and takes the
## fuses a captured hunted dropped; the AI monster plays when the monster
## seat is empty.

const MAP_SCENE := preload("res://game/maps/tilleuls/tilleuls.tscn")
const LOOP_SETTINGS := preload("res://game/data/loop_settings.tres")


func after_each() -> void:
	NetSession.mode = NetSession.Mode.SOLO
	GameSession.online_lobby = null
	GameSession.game_seed = 0


## The cité played by the room, with these players in the seats (0: an AI).
func _room(seats: Array[int]) -> GameMap:
	NetSession.mode = NetSession.Mode.ROOM
	var lobby := LobbyState.new()
	lobby.seats = seats
	GameSession.online_lobby = lobby
	GameSession.game_seed = 7
	var map: GameMap = MAP_SCENE.instantiate()
	add_child_autofree(map)
	return map


## A point this far from a body on open ground: the first direction without
## anything in the way at knee and eye height.
func _open_point(body: Node3D, distance: float) -> Vector3:
	var space := body.get_world_3d().direct_space_state
	for i in 16:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var clear := true
		for height: float in [0.4, 1.5]:
			var from := body.global_position + Vector3.UP * height
			var query := PhysicsRayQueryParameters3D.create(
				from, from + direction * (distance + 1.0)
			)
			query.exclude = [body.get_rid()]
			if not space.intersect_ray(query).is_empty():
				clear = false
		if clear:
			return body.global_position + direction * distance
	return body.global_position + Vector3(distance, 0, 0)


func test_ai_preys_fill_the_empty_hunted_seats() -> void:
	var map := _room([0, 11, 0, 0])
	var net: NetGame = map.get_node("NetGame")
	var monster: Monster = map.get_node("Monster")
	assert_eq(net.ai_hunted.keys(), [2, 3])
	assert_eq(net.ai_monster, monster, "the empty monster seat: the AI monster")
	for seat: int in net.ai_hunted:
		var prey: Prey = net.ai_hunted[seat]
		assert_not_null(prey.capture)
		assert_eq(prey.monster, monster)
		assert_eq(prey.game_loop, map.game_loop, "it plays the loop")
		assert_true(map.game_loop.is_hunted(prey))
		assert_has(monster.get_targets(), prey)
		assert_eq(net.seat_of(prey), seat)
	var seen := net._entities().map(func(entry: Array) -> int: return entry[0])
	assert_eq(seen, [1, 2, 3, LobbyState.MONSTER_SEAT], "everyone may be sent to the others")
	var a: Prey = net.ai_hunted[2]
	var b: Prey = net.ai_hunted[3]
	assert_gte(a.global_position.distance_to(b.global_position), 40.0, "far apart")


func test_a_human_monster_catches_an_ai_prey() -> void:
	var map := _room([5, 0, 0, 11])
	var net: NetGame = map.get_node("NetGame")
	var prey: Prey = net.ai_hunted[1]
	assert_eq(prey.monster, map.avatar)
	map.avatar.global_position = prey.global_position + Vector3(0.3, 0, 0)
	net._check_catches()
	assert_true(prey.held)
	assert_eq(prey.capture.state, CaptureState.State.CAPTURED)
	assert_has(net.sent_events, [11, [NetGame.Event.CAUGHT, 1, CaptureState.State.CAPTURED]])
	assert_eq(prey.get_gait(), PlayerMotion.Gait.CROUCH, "on its knees")
	assert_true(net._entry(1, prey)[4])


func test_an_ai_prey_frees_a_captured_teammate_when_it_is_safe() -> void:
	var map := _room([0, 11, 0, 0])
	var net: NetGame = map.get_node("NetGame")
	var monster: Monster = map.get_node("Monster")
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	monster.global_position = Vector3(0, -100, 0)
	var captured: Player = net.avatars[11]
	var prey: Prey = net.ai_hunted[2]
	_freeze(net.ai_hunted[3])
	await wait_physics_frames(3)  # The navigation map is ready.
	captured.global_position = _open_point(prey, 6.0)
	map._online_catch(captured)
	assert_true(captured.held)
	await wait_physics_frames(int((captured.settings.rescue_time + 6.0) * 60))
	assert_false(captured.held, "freed by the AI prey")
	assert_eq(captured.capture.state, CaptureState.State.FREE)
	assert_null(prey._errand, "then back to its goal")


func test_an_ai_prey_stays_away_when_the_monster_is_near() -> void:
	var map := _room([0, 11, 0, 0])
	var net: NetGame = map.get_node("NetGame")
	var monster: Monster = map.get_node("Monster")
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	var captured: Player = net.avatars[11]
	var prey: Prey = net.ai_hunted[2]
	_freeze(net.ai_hunted[3])
	await wait_physics_frames(3)
	captured.global_position = _open_point(prey, 30.0)
	monster.global_position = captured.global_position + Vector3(0, 0, 5)
	map._online_catch(captured)
	await wait_physics_frames(60)
	assert_null(prey._errand, "a trap: it does not go")
	assert_true(captured.held)


func test_an_ai_prey_takes_a_dropped_fuse() -> void:
	var map := _room([0, 11, 0, 0])
	var net: NetGame = map.get_node("NetGame")
	var monster: Monster = map.get_node("Monster")
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	monster.global_position = Vector3(0, -100, 0)
	var prey: Prey = net.ai_hunted[2]
	var human: Player = net.avatars[11]
	_freeze(net.ai_hunted[3])
	_freeze(human)
	await wait_physics_frames(3)
	human.global_position = _open_point(prey, 5.0)
	map.game_loop._on_fuse_taken(human)
	map.game_loop.drop_fuses(human)
	assert_eq(map.game_loop.drops.size(), 1)
	human.global_position = Vector3(0, -100, 0)
	await wait_physics_frames(int((LOOP_SETTINGS.pickup_time + 6.0) * 60))
	assert_eq(map.game_loop.carried_by(prey), 1, "taken back")
	assert_eq(map.game_loop.drops.size(), 0)


func _freeze(node: Node3D) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
