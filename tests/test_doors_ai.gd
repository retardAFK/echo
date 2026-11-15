extends GutTest
## Doors and the AIs, doors online (spec S-016, T-233): the AI monster and the
## AI prey open the doors on their way, the fleeing prey closes one behind
## it, the room sends the doors to the clients.

const MAP_SCENE := preload("res://game/maps/greybox_test.tscn")
const DOOR_SCENE := preload("res://game/entities/door/door.tscn")
const FAR_AWAY := Vector3(18, 0, -18)
## Doorways of the greybox test building (8 x 6 m, walls on X at z = 10 and 16).
const NORTH_DOORWAY := Vector3(-11, 0, 10)
const SOUTH_DOORWAY := Vector3(-15, 0, 16)
const INSIDE := Vector3(-13, 0, 13)

var _map: Node3D
var _noises: Array[NoiseEvent] = []


func before_each() -> void:
	_noises.clear()
	NoiseBus.noise_emitted.connect(_record)


func after_each() -> void:
	NoiseBus.noise_emitted.disconnect(_record)
	GameSession.role = GameSession.Role.HUNTED


func _record(event: NoiseEvent) -> void:
	if event.type == NoiseEvent.Type.DOOR:
		_noises.append(event)


func _greybox() -> void:
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	var player: Node3D = _map.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = FAR_AWAY


func _door_at(at: Vector3) -> Door:
	var door: Door = DOOR_SCENE.instantiate()
	_map.add_child(door)
	door.global_position = at
	return door


func test_the_ai_monster_opens_a_door_on_its_way() -> void:
	_greybox()
	var door := _door_at(NORTH_DOORWAY)
	var monster: Monster = _map.get_node("Monster")
	monster.global_position = NORTH_DOORWAY + Vector3(0, 0, -4)
	await wait_physics_frames(2)
	var inside: Array[Vector3] = [INSIDE]
	monster.guard_exit(inside)  # Sends it to stand inside.
	for i in 8 * Engine.physics_ticks_per_second:
		await wait_physics_frames(1)
		if monster.global_position.z > 11.0:
			break
	assert_true(door.is_open, "opened, not smashed: it was not chasing")
	assert_gt(monster.global_position.z, 10.5, "and went in")
	assert_eq(door.last_user, monster)
	assert_eq(_noises.size(), 1)
	assert_eq(_noises[0].noise_range, door.settings.open_range)


func test_the_ai_prey_opens_a_door_on_its_way() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	var avatar: Node3D = _map.get_node("MonsterAvatar")
	avatar.process_mode = Node.PROCESS_MODE_DISABLED
	avatar.global_position = FAR_AWAY
	var door := _door_at(SOUTH_DOORWAY)
	var prey: Prey = _map.prey
	prey.global_position = SOUTH_DOORWAY + Vector3(0, 0, 4)
	await wait_physics_frames(2)
	for i in 8 * Engine.physics_ticks_per_second:
		prey.brain.target = INSIDE
		await wait_physics_frames(1)
		if prey.global_position.z < 15.0:
			break
	assert_true(door.is_open)
	assert_eq(door.last_user, prey)
	assert_lt(prey.global_position.z, 15.5, "and went in")


func test_the_fleeing_prey_closes_the_door_behind_it_unseen() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	var avatar: Node3D = _map.get_node("MonsterAvatar")
	avatar.process_mode = Node.PROCESS_MODE_DISABLED
	avatar.global_position = FAR_AWAY
	var prey: Prey = _map.prey
	prey.process_mode = Node.PROCESS_MODE_DISABLED  # Placed by hand.
	var door := _door_at(SOUTH_DOORWAY)
	await wait_physics_frames(2)
	door.open_by(prey)
	prey.set("_opened_door", door)
	prey.global_position = SOUTH_DOORWAY + Vector3(0, 0, -1)
	prey.look_at(INSIDE + Vector3(0, 0, -5), Vector3.UP)  # Walking away, north.
	prey.call("_close_door_behind", true)
	assert_true(door.is_open, "still in the doorway: not yet")
	prey.global_position = SOUTH_DOORWAY + Vector3(0, 0, -2.5)
	prey.sees_monster = true
	prey.call("_close_door_behind", true)
	assert_true(door.is_open, "the monster sees it: closing gains nothing")
	prey.set("_opened_door", door)
	prey.sees_monster = false
	prey.call("_close_door_behind", true)
	assert_false(door.is_open, "fleeing, unseen, past it: closed")
	assert_eq(door.last_user, prey)


func test_the_prey_does_not_close_it_when_not_fleeing() -> void:
	GameSession.role = GameSession.Role.MONSTER
	_map = MAP_SCENE.instantiate()
	add_child_autofree(_map)
	var prey: Prey = _map.prey
	prey.process_mode = Node.PROCESS_MODE_DISABLED
	var door := _door_at(SOUTH_DOORWAY)
	await wait_physics_frames(2)
	door.open_by(prey)
	prey.set("_opened_door", door)
	prey.global_position = SOUTH_DOORWAY + Vector3(0, 0, -2.5)
	prey.look_at(INSIDE + Vector3(0, 0, -5), Vector3.UP)
	prey.call("_close_door_behind", false)
	assert_true(door.is_open)
	assert_null(prey.get("_opened_door"), "forgotten once past")


func test_the_room_sends_the_doors_to_the_clients() -> void:
	var room_map := Node3D.new()
	var client_map := Node3D.new()
	add_child_autofree(room_map)
	add_child_autofree(client_map)
	for map: Node3D in [room_map, client_map]:
		for x in 3:
			var door: Door = DOOR_SCENE.instantiate()
			map.add_child(door)
			door.position = Vector3(x * 3.0, 0, 0)
	var room := NetWorld.new(room_map)
	var client := NetWorld.new(client_map)
	assert_eq(room.doors.size(), 3)
	room.doors[1].open_by(null)
	_noises.clear()
	client.apply(room.state())
	assert_false(client.doors[0].is_open)
	assert_true(client.doors[1].is_open, "opened in the room: open here")
	assert_false(client.doors[2].is_open)
	assert_eq(_noises.size(), 0, "the client only shows it: the room made the noise")
