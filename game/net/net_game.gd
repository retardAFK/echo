class_name NetGame
extends Node
## The online part of a game on a map (S-010, T-097), added by GameMap.
## Room side: each physics frame, the commands of every place go to its
## avatar; snapshot_rate times a second, each player gets a snapshot with its
## own state and the others it sees (NetVisibility).
## Client side: the player's own avatar is predicted (Prediction) and nudged
## to the room's position; the others are NetPuppets moved between snapshots.
## Snapshot: {"ack": last command applied, "you": [position, velocity, yaw,
## gait, hidden, hold ratio, bottles, alarm clocks, hiding spot index],
## "others": [[seat, position, yaw, gait], ...]}.
## Events (T-098), sent reliably as they happen:
## - [NOISE, type, position, range]: to the monster, every noise but its own;
##   to a hunted, only those its ears hear (NoiseBus.can_hear), never its own,
##   never who made it. The client plays it through NoiseBus.
## - [SCAN, building index, scanned]: to the hunted, so the lights flicker.
## - [CAUGHT, seat]: to everyone, when the monster catches a hunted.
## - [WORLD, NetWorld.state()]: to everyone, when the map or the loop changes
##   (T-099); the client's map and loop only mirror the room's.
## - [BOTTLE, position, velocity] and [DECOY, position]: to everyone, a bottle
##   thrown or an alarm clock placed; the client plays its own copy.
## - [CRUSH, position]: to everyone, the monster crushed a ringing alarm clock.

## Room side: a human monster touched a hunted; GameMap puts it back.
signal hunted_caught(hunted: Node3D)
## Client side: the room says the hunted in a seat was caught.
signal caught_reported(seat: int)

enum Event { NOISE, SCAN, CAUGHT, WORLD, BOTTLE, DECOY, CRUSH }

## Layers that block sight between players: the ground and props, and walls.
const SIGHT_MASK := 1 | NoiseBus.WALLS_COLLISION_MASK
const BOTTLE_SCENE := preload("res://game/entities/bottle/thrown_bottle.tscn")
const DECOY_SCENE := preload("res://game/entities/decoy/decoy.tscn")

var settings: NetSettings = preload("res://game/data/net_settings.tres")
var is_room := false
## The scannable buildings of the map, in the same order on both sides.
var buildings: Array[Building] = []
## The things of the map that change, and the game loop (T-099).
var world: NetWorld
## Room side without network (tests): the events sent, as [place, event].
var sent_events := []
## Room side: avatar of each human place (Player or MonsterAvatar), by place.
var avatars := {}
## Room side: seat of each avatar, by place; and the AI monster, if any.
var seats := {}
var ai_monster: Node3D
## Client side: the avatar played here.
var own: Node3D
var prediction: Prediction
## Client side: the others, by seat.
var puppets := {}
## Client side: largest gap seen between prediction and room, for tests.
var worst_error := 0.0

var _send_left := 0.0
var _acked := {}
var _sent_world := []


func _ready() -> void:
	# Before the avatars on the room (commands first), after them on a client
	# (record where the frame left the player).
	process_physics_priority = -10 if is_room else 10
	if is_room:
		NoiseBus.noise_emitted.connect(_on_noise_emitted)
		for i in buildings.size():
			buildings[i].scan_changed.connect(_on_scan_changed.bind(i))
		get_parent().child_entered_tree.connect(_on_map_child_added)
	else:
		if own != null:
			own.mirror_world = true
			NoiseBus.mirror = true
			NoiseBus.local_source = own
		prediction = Prediction.new(settings)
		NetSession.snapshot_received.connect(apply_snapshot)
		NetSession.event_received.connect(apply_event)


func _exit_tree() -> void:
	for connection: Array in [
		[NoiseBus.noise_emitted, _on_noise_emitted],
		[NetSession.snapshot_received, apply_snapshot],
		[NetSession.event_received, apply_event],
	]:
		var event: Signal = connection[0]
		if event.is_connected(connection[1]):
			event.disconnect(connection[1])
	if not is_room:
		NoiseBus.mirror = false
		NoiseBus.local_source = null


## Room side: a human's avatar for a place, in a seat.
func add_avatar(place: int, seat: int, avatar: Node3D) -> void:
	avatars[place] = avatar
	seats[place] = seat


func _physics_process(delta: float) -> void:
	if is_room:
		if NetSession.link == null:
			return  # A room being set up, or a test without network.
		_apply_commands()
		_check_catches()
		_send_left -= delta
		if _send_left <= 0.0:
			_send_left = maxf(_send_left + 1.0 / settings.snapshot_rate, 0.0)
			send_world()
			_send_snapshots()
	elif own != null:
		prediction.record(own.commands.seq, own.global_position)
		own.global_position += prediction.step(delta)


func _process(_delta: float) -> void:
	if is_room:
		return
	var time := Time.get_ticks_msec() / 1000.0 - settings.interpolation_delay
	for puppet: NetPuppet in puppets.values():
		puppet.show_at(time, settings.max_extrapolation)


func _apply_commands() -> void:
	var link := NetSession.link
	for place in avatars:
		var avatar: Node3D = avatars[place]
		var received := link.commands_for(place)
		avatar.commands.copy_held(received)
		for action in received.take_actions():
			avatar.commands.push(action)
		_acked[place] = received.seq


## Room side: a human monster catches a hunted it touches, as in solo (not
## through a floor, not in a hiding spot).
func _check_catches() -> void:
	var monster := _human_monster()
	if monster == null:
		return
	for place in avatars:
		var hunted: Node3D = avatars[place]
		if hunted == monster or HidingSpot.is_hidden(hunted):
			continue
		var gap := hunted.global_position - monster.global_position
		if (
			Vector2(gap.x, gap.z).length() <= monster.settings.catch_distance
			and absf(gap.y) <= monster.settings.catch_height
		):
			monster.catch_count += 1
			report_caught(seats[place])
			hunted_caught.emit(hunted)


func _human_monster() -> MonsterAvatar:
	for place in avatars:
		if seats[place] == LobbyState.MONSTER_SEAT:
			return avatars[place]
	return null


## Room side: tells everyone the hunted in a seat was caught.
func report_caught(seat: int) -> void:
	_send_to_all([Event.CAUGHT, seat])


## Room side: the seat of an avatar, -1 if it is not a human's.
func seat_of(node: Node3D) -> int:
	for place in avatars:
		if avatars[place] == node:
			return seats[place]
	return -1


## Room side: what of a noise goes to a viewer, empty if nothing. The monster
## gets every noise but its own (its screen filters by hearing and scan, as in
## solo); a hunted only what its ears hear. Never who made it.
static func noise_message(event: NoiseEvent, viewer: Node3D, viewer_is_monster: bool) -> Array:
	if event.source == viewer or event.noise_range <= 0.0:
		return []
	if not viewer_is_monster and not NoiseBus.can_hear(event, viewer.get_eye_position()):
		return []
	return [Event.NOISE, event.type, event.position, event.noise_range]


func _on_noise_emitted(event: NoiseEvent) -> void:
	for place in avatars:
		var message := noise_message(event, avatars[place], seats[place] == LobbyState.MONSTER_SEAT)
		if not message.is_empty():
			_send_event(place, message)


## Only the hunted are told: the monster scans on its own screen already.
func _on_scan_changed(scanned: bool, index: int) -> void:
	for place in avatars:
		if seats[place] != LobbyState.MONSTER_SEAT:
			_send_event(place, [Event.SCAN, index, scanned])


func _send_event(place: int, event: Array) -> void:
	if NetSession.link == null:
		sent_events.append([place, event])
	else:
		NetSession.link.send_event(place, event)


## Room side: sends the state of the map and the loop to everyone, if it
## changed since the last time.
func send_world() -> void:
	if world == null:
		return
	var state := world.state()
	if state == _sent_world:
		return
	_sent_world = state.duplicate(true)
	_send_to_all([Event.WORLD, state])


func _send_to_all(event: Array) -> void:
	for place in avatars:
		_send_event(place, event)


## Room side: a bottle thrown or an alarm clock placed on the map, sent once
## the thrower has set where it starts (the same frame).
func _on_map_child_added(node: Node) -> void:
	if node is ThrownBottle or node is Decoy:
		_announce.call_deferred(node)


func _announce(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	if node is ThrownBottle:
		_send_to_all([Event.BOTTLE, node.global_position, (node as ThrownBottle).linear_velocity])
	elif node is Decoy:
		_send_to_all([Event.DECOY, node.global_position])
		(node as Decoy).crushed.connect(
			func() -> void: _send_to_all([Event.CRUSH, node.global_position])
		)


func _send_snapshots() -> void:
	for place in avatars:
		NetSession.link.send_snapshot(place, snapshot_for(place))


## Room side: what the player in a place is sent.
func snapshot_for(place: int) -> Dictionary:
	var viewer: Node3D = avatars[place]
	var hidden: bool = viewer.has_method("is_hidden") and viewer.is_hidden()
	var inventory: Inventory = viewer.get("inventory")
	var spot: HidingSpot = viewer.get("hiding_in")
	var others := []
	for other in _entities():
		if other[1] == viewer:
			continue
		if sees(viewer, other[1]):
			others.append(
				[other[0], other[1].global_position, other[1].rotation.y, _gait(other[1])]
			)
	return {
		"ack": _acked.get(place, 0),
		"you":
		[
			viewer.global_position,
			viewer.velocity,
			viewer.rotation.y,
			_gait(viewer),
			hidden,
			viewer.get_hold_ratio(),
			inventory.count(Inventory.Kind.BOTTLE) if inventory != null else 0,
			inventory.count(Inventory.Kind.DECOY) if inventory != null else 0,
			world.spot_index(spot) if world != null else -1,
		],
		"others": others,
	}


## Room side: whether viewer sees target, walls and hiding spots included.
func sees(viewer: Node3D, target: Node3D) -> bool:
	var eye: Vector3 = viewer.get_eye_position()
	var aim: Vector3 = target.get_eye_position()
	var target_hidden := HidingSpot.is_hidden(target)
	if target_hidden or eye.distance_to(aim) > settings.sight_range:
		return false  # No ray needed.
	var query := PhysicsRayQueryParameters3D.create(eye, aim, SIGHT_MASK)
	query.exclude = [viewer.get_rid(), target.get_rid()]
	var clear := viewer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return NetVisibility.sees(eye, -viewer.global_basis.z, aim, false, clear, settings)


## Every player and AI on the room, as [seat, node].
func _entities() -> Array:
	var found := []
	for place in avatars:
		found.append([seats[place], avatars[place]])
	if ai_monster != null:
		found.append([LobbyState.MONSTER_SEAT, ai_monster])
	return found


func _gait(node: Node3D) -> int:
	if node.has_method("get_gait"):
		return node.get_gait()
	return 0


## Client side: reads a snapshot from the room.
func apply_snapshot(snapshot: Dictionary) -> void:
	if own == null:
		return
	var you: Array = snapshot.get("you", [])
	if you.size() >= 1:
		var server_position: Vector3 = you[0]
		var ack: int = snapshot.get("ack", 0)
		if not prediction.started or (ack > prediction.floor_seq and not prediction.knows(ack)):
			# First snapshot, or a frame too old to compare: go where the room has us.
			own.global_position = server_position
			prediction.restart(own.commands.seq)
		elif ack > prediction.floor_seq:
			worst_error = maxf(worst_error, prediction.error_at(ack, server_position).length())
			own.global_position += prediction.reconcile(ack, server_position)
		if you.size() >= 9:
			_apply_own_state(you)
	var now := Time.get_ticks_msec() / 1000.0
	var seen := {}
	for entry: Array in snapshot.get("others", []):
		var seat: int = entry[0]
		seen[seat] = true
		var puppet := _puppet(seat)
		if not puppet.visible:
			puppet.buffer = SnapshotBuffer.new()  # Back in sight: no slide from where it was lost.
			puppet.visible = true
		puppet.buffer.push(now, entry[1], entry[2])
	for seat in puppets:
		if not seen.has(seat):
			puppets[seat].visible = false


## Client side: plays an event from the room.
func apply_event(event: Array) -> void:
	if event.is_empty():
		return
	match event[0]:
		Event.NOISE when event.size() == 4:
			var type: NoiseEvent.Type = event[1]
			NoiseBus.emit_noise(type, event[2], event[3])
			if world != null:
				world.voice(type, event[2])
		Event.SCAN when event.size() == 3:
			var index: int = event[1]
			if index >= 0 and index < buildings.size():
				buildings[index].scanned = event[2]
		Event.CAUGHT when event.size() == 2:
			caught_reported.emit(event[1])
		Event.WORLD when event.size() == 2 and world != null:
			world.apply(event[1])
		Event.BOTTLE when event.size() == 3:
			var bottle: ThrownBottle = _spawn_copy(BOTTLE_SCENE, event[1])
			bottle.linear_velocity = event[2]
		Event.DECOY when event.size() == 2:
			_spawn_copy(DECOY_SCENE, event[1])
		Event.CRUSH when event.size() == 2:
			_crush_near(event[1])


## Client side: what the room says of the player's own avatar beyond where it
## is: progress of what it holds, what it carries, where it hides.
func _apply_own_state(you: Array) -> void:
	own.remote_hold_ratio = you[5]
	var inventory: Inventory = own.get("inventory")
	if inventory != null:
		inventory.set_count(Inventory.Kind.BOTTLE, you[6])
		inventory.set_count(Inventory.Kind.DECOY, you[7])
	if not own is Player or world == null:
		return
	var player := own as Player
	var index: int = you[8]
	var spot: HidingSpot = world.spots[index] if index >= 0 and index < world.spots.size() else null
	if spot == player.hiding_in:
		return
	if player.hiding_in != null:
		player.hiding_in.occupant = null
		player.leave_hiding()
	if spot != null:
		spot.occupant = player
		player.hide_in(spot)
	prediction.restart(player.commands.seq)  # Moved by the room, not by its steps.


func _spawn_copy(scene: PackedScene, at: Vector3) -> Node3D:
	var copy: Node3D = scene.instantiate()
	get_parent().add_child(copy)
	copy.global_position = at
	return copy


func _crush_near(at: Vector3) -> void:
	var nearest: Decoy = null
	var best := NetWorld.VOICE_REACH
	for node in get_tree().get_nodes_in_group(Decoy.GROUP):
		var decoy := node as Decoy
		if decoy != null and decoy.global_position.distance_to(at) <= best:
			nearest = decoy
			best = decoy.global_position.distance_to(at)
	if nearest != null:
		nearest.crush()


func _puppet(seat: int) -> NetPuppet:
	if not puppets.has(seat):
		var puppet := NetPuppet.new()
		puppet.name = "Puppet%d" % seat
		puppet.kind = (
			NetPuppet.Kind.MONSTER if seat == LobbyState.MONSTER_SEAT else NetPuppet.Kind.HUNTED
		)
		puppet.visible = false
		get_parent().add_child(puppet)
		puppets[seat] = puppet
	return puppets[seat]
