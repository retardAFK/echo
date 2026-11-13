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

## Layers that block sight between players: the ground and props, and walls.
const SIGHT_MASK := 1 | NoiseBus.WALLS_COLLISION_MASK

var settings: NetSettings = preload("res://game/data/net_settings.tres")
var is_room := false
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
	if not is_room:
		prediction = Prediction.new(settings)
		NetSession.snapshot_received.connect(apply_snapshot)


func _exit_tree() -> void:
	if NetSession.snapshot_received.is_connected(apply_snapshot):
		NetSession.snapshot_received.disconnect(apply_snapshot)


## Room side: a human's avatar for a place, in a seat.
func add_avatar(place: int, seat: int, avatar: Node3D) -> void:
	avatars[place] = avatar
	seats[place] = seat


func _physics_process(delta: float) -> void:
	if is_room:
		if NetSession.link == null:
			return  # A room being set up, or a test without network.
		_apply_commands()
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
