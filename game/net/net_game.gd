class_name NetGame
extends Node
## The online part of a game on a map (S-010, T-097), added by GameMap.
## Room side: each physics frame, the commands of every place go to its
## avatar; snapshot_rate times a second, each player gets a snapshot with its
## own state and the others it sees (NetVisibility).
## Client side: the player's own avatar is predicted (Prediction) and nudged
## to the room's position; the others are NetPuppets moved between snapshots.
## Snapshot: {"ack": last command applied, "you": [position, velocity, yaw,
## gait, hidden], "others": [[seat, position, yaw, gait], ...]}.
## Events (T-098), sent reliably as they happen:
## - [NOISE, type, position, range]: to the monster, every noise but its own;
##   to a hunted, only those its ears hear (NoiseBus.can_hear), never its own,
##   never who made it. The client plays it through NoiseBus.
## - [SCAN, building index, scanned]: to the hunted, so the lights flicker.
## - [CAUGHT, seat]: to everyone, when the monster catches a hunted.

## Room side: a human monster touched a hunted; GameMap puts it back.
signal hunted_caught(hunted: Node3D)
## Client side: the room says the hunted in a seat was caught.
signal caught_reported(seat: int)

enum Event { NOISE, SCAN, CAUGHT }

## Layers that block sight between players: the ground and props, and walls.
const SIGHT_MASK := 1 | NoiseBus.WALLS_COLLISION_MASK

var settings: NetSettings = preload("res://game/data/net_settings.tres")
var is_room := false
## The scannable buildings of the map, in the same order on both sides.
var buildings: Array[Building] = []
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


func _ready() -> void:
	# Before the avatars on the room (commands first), after them on a client
	# (record where the frame left the player).
	process_physics_priority = -10 if is_room else 10
	if is_room:
		NoiseBus.noise_emitted.connect(_on_noise_emitted)
		for i in buildings.size():
			buildings[i].scan_changed.connect(_on_scan_changed.bind(i))
	else:
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
	for place in avatars:
		_send_event(place, [Event.CAUGHT, seat])


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


func _send_snapshots() -> void:
	for place in avatars:
		NetSession.link.send_snapshot(place, snapshot_for(place))


## Room side: what the player in a place is sent.
func snapshot_for(place: int) -> Dictionary:
	var viewer: Node3D = avatars[place]
	var hidden: bool = viewer.has_method("is_hidden") and viewer.is_hidden()
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
		Event.SCAN when event.size() == 3:
			var index: int = event[1]
			if index >= 0 and index < buildings.size():
				buildings[index].scanned = event[2]
		Event.CAUGHT when event.size() == 2:
			caught_reported.emit(event[1])


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
